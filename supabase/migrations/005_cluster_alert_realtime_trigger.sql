-- Tahap 5: Cluster Alert Realtime, Peer Alert Lookup RPC, and pg_net Dispatch Trigger
-- Reference: PRD_lacaksaji.md Section 3.6 & 7.2

create extension if not exists pg_net;

-- 1. Partial index for recipient device FCM token lookups
create index if not exists profiles_fcm_token_nonnull_idx
  on public.profiles (id)
  where fcm_token is not null;

-- 2. Re-assert Realtime publication and replica identity for cluster_alerts
alter table public.cluster_alerts replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cluster_alerts'
  ) then
    alter publication supabase_realtime add table public.cluster_alerts;
  end if;
end $$;

-- 3. Tenant-scoped RPC returning full O01 Cluster Alert context without exposing peer school rows
create or replace function public.get_cluster_alert_details(p_alert_id uuid)
returns table (
  id uuid,
  sppg_id uuid,
  sppg_name text,
  batch_id uuid,
  batch_code text,
  menu_name text,
  reporter_school_id uuid,
  reporter_school_name text,
  stage text,
  symptom_count integer,
  notes text,
  broadcast_enabled boolean,
  sample_label_code text,
  pdf_dispatched boolean,
  created_at timestamptz,
  active_reporter_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  return query
  select
    ca.id,
    ca.sppg_id,
    sk.name as sppg_name,
    ca.batch_id,
    fb.batch_code,
    fb.menu_name,
    ca.reporter_school_id,
    rs.name as reporter_school_name,
    ca.stage,
    ca.symptom_count,
    ca.notes,
    ca.broadcast_enabled,
    ca.sample_label_code,
    ca.pdf_dispatched,
    ca.created_at,
    (
      select count(distinct ca2.reporter_school_id)
      from public.cluster_alerts ca2
      where ca2.batch_id = ca.batch_id
    ) as active_reporter_count
  from public.cluster_alerts ca
  join public.sppg_kitchens sk on sk.id = ca.sppg_id
  join public.food_batches fb on fb.id = ca.batch_id
  join public.schools rs on rs.id = ca.reporter_school_id
  where ca.id = p_alert_id
    and (
      ca.sppg_id = (select private.current_kitchen_id())
      or ca.sppg_id = (select private.current_approved_sppg_id())
      or (select private.current_user_role()) = 'supervisor'
    )
  limit 1;
end;
$$;

revoke execute on function public.get_cluster_alert_details(uuid) from public, anon;
grant execute on function public.get_cluster_alert_details(uuid) to authenticated;

-- 4. Trigger function invoking dispatch-cluster-alert Edge Function asynchronously via pg_net
create or replace function private.notify_cluster_alert_edge()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.broadcast_enabled, false) then
    begin
      perform net.http_post(
        url := 'https://ngkvhwxkhrsgnflftjhw.supabase.co/functions/v1/dispatch-cluster-alert',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-lacak-trigger', 'cluster_alerts_insert'
        ),
        body := jsonb_build_object(
          'type', 'INSERT',
          'table', 'cluster_alerts',
          'record', to_jsonb(new)
        )
      );
    exception
      when others then
        -- Never fail an alert insert if async webhook dispatch errors.
        null;
    end;
  end if;
  return new;
end;
$$;

revoke all on function private.notify_cluster_alert_edge() from public, anon, authenticated;

drop trigger if exists trg_cluster_alerts_dispatch on public.cluster_alerts;

create trigger trg_cluster_alerts_dispatch
  after insert on public.cluster_alerts
  for each row
  when (new.broadcast_enabled = true)
  execute function private.notify_cluster_alert_edge();
