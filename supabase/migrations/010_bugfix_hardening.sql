-- Migration 010: End-to-end audit bugfix & security hardening
-- 1. Allow backup kitchen staff (role = staff) to register their own active Ed25519 key in signing_keys
-- 2. Allow backup school staff (role = staff) to delete/uncheck school_allergen_profiles rows
-- 3. Allow active SPPG couriers to read cluster_alerts & get_cluster_alert_details_v2 for O01 stop-delivery warnings
-- 4. Add claim_pending_institution_memberships() RPC to auto-link pre-invited staff/courier accounts on login

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'signing_keys'
      and policyname = 'signing_keys_insert_kitchen_member'
  ) then
    execute $p$
      create policy "signing_keys_insert_kitchen_member"
        on public.signing_keys
        for insert
        to authenticated
        with check (
          sppg_id = (select private.current_kitchen_id())
          and status = 'active'
        )
    $p$;
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'school_allergen_profiles'
      and policyname = 'school_allergen_profiles_delete_school_member'
  ) then
    execute $p$
      create policy "school_allergen_profiles_delete_school_member"
        on public.school_allergen_profiles
        for delete
        to authenticated
        using (school_id = (select private.current_school_id()))
    $p$;
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'cluster_alerts'
      and policyname = 'cluster_alerts_select_courier'
  ) then
    execute $p$
      create policy "cluster_alerts_select_courier"
        on public.cluster_alerts
        for select
        to authenticated
        using (sppg_id = (select private.current_courier_sppg_id()))
    $p$;
  end if;
end $$;

create or replace function public.claim_pending_institution_memberships()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_email text;
  v_linked_count integer := 0;
begin
  v_uid := (select auth.uid());
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select lower(trim(coalesce(u.email, '')))
  into v_email
  from auth.users u
  where u.id = v_uid
  limit 1;

  if v_email is null or v_email = '' then
    return jsonb_build_object('ok', true, 'linked_count', 0);
  end if;

  update public.institution_members im
  set user_id = v_uid,
      updated_at = now()
  where im.user_id is null
    and im.is_active = true
    and lower(trim(coalesce(im.member_email, ''))) = v_email;

  get diagnostics v_linked_count = row_count;

  return jsonb_build_object(
    'ok', true,
    'linked_count', v_linked_count
  );
end;
$$;

grant execute on function public.claim_pending_institution_memberships() to authenticated;

create or replace function public.get_cluster_alert_details_v2(p_alert_id uuid)
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
  active_reporter_count bigint,
  resolution_status text,
  resolution_note text,
  resolved_by uuid,
  resolved_by_name text,
  resolved_at timestamptz
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
    ) as active_reporter_count,
    coalesce(ca.resolution_status, 'active') as resolution_status,
    ca.resolution_note,
    ca.resolved_by,
    coalesce(nullif(trim(rp.full_name), ''), 'Admin SPPG / Sekolah Pelapor') as resolved_by_name,
    ca.resolved_at
  from public.cluster_alerts ca
  join public.sppg_kitchens sk on sk.id = ca.sppg_id
  join public.food_batches fb on fb.id = ca.batch_id
  join public.schools rs on rs.id = ca.reporter_school_id
  left join public.profiles rp on rp.id = ca.resolved_by
  where ca.id = p_alert_id
    and (
      ca.sppg_id = (select private.current_kitchen_id())
      or ca.sppg_id = (select private.current_approved_sppg_id())
      or ca.sppg_id = (select private.current_courier_sppg_id())
      or (select private.current_user_role()) = 'supervisor'
    )
  limit 1;
end;
$$;

grant execute on function public.get_cluster_alert_details_v2(uuid) to authenticated;
