-- LacakSaji Initial Database Schema, Security, Storage & Realtime
-- Reference: PRD_lacaksaji.md Section 7 & 9

create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;

-- 1. Master Whitelist BGN/Dinkes
create table if not exists public.official_sppg_registry (
  reg_number text primary key,
  activation_pin_hash text not null,
  official_name text not null,
  region_name text not null,
  is_claimed boolean not null default false,
  claimed_at timestamptz
);

-- 2. User profiles mapped to auth.users
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('kitchen', 'school', 'supervisor')),
  full_name text not null,
  fcm_token text,
  created_at timestamptz not null default now()
);

-- 3. SPPG Kitchen profiles
create table if not exists public.sppg_kitchens (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  reg_number text not null unique references public.official_sppg_registry(reg_number),
  invite_code text not null unique,
  name text not null,
  adm4_code text not null,
  lat double precision not null,
  lng double precision not null,
  public_key text not null,
  is_verified boolean not null default true,
  created_at timestamptz not null default now()
);

-- 4. Schools linked to SPPG kitchens
create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  sppg_id uuid references public.sppg_kitchens(id) on delete set null,
  npsn text not null unique check (npsn ~ '^[0-9]{8}$'),
  name text not null,
  adm4_code text not null,
  lat double precision not null,
  lng double precision not null,
  puskesmas_wa text not null,
  verification_status text not null default 'pending' check (verification_status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

-- 5. Sealed food batches from kitchens
create table if not exists public.food_batches (
  id uuid primary key default gen_random_uuid(),
  sppg_id uuid not null references public.sppg_kitchens(id) on delete cascade,
  batch_code text not null unique,
  menu_name text not null,
  portion_count integer not null check (portion_count > 0),
  risk_category text not null check (risk_category in ('HIGH', 'MEDIUM', 'LOW')),
  sealed_at timestamptz not null,
  timestamp_source text not null check (timestamp_source in ('server_verified', 'offline_unverified')),
  packaging_photo_url text,
  signature_b64 text not null,
  created_at timestamptz not null default now()
);

-- 6. School receiving inspections (Danger-Zone + Hybrid Audit)
create table if not exists public.school_inspections (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.food_batches(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  scanned_at timestamptz not null,
  elapsed_minutes integer not null check (elapsed_minutes >= 0),
  bmkg_temp_c numeric(4,1) not null,
  bmkg_source text not null check (bmkg_source in ('live', 'cached', 'fallback_offline')),
  danger_status text not null check (danger_status in ('GREEN', 'YELLOW', 'RED')),
  gps_within_radius boolean not null default true,
  sample_photo_url text,
  tflite_label text,
  tflite_confidence numeric(4,3),
  gemini_summary_json jsonb,
  manual_smell_ok boolean not null,
  manual_visual_ok boolean not null,
  manual_pack_ok boolean not null,
  final_decision text not null check (final_decision in ('APPROVED', 'REJECTED')),
  created_at timestamptz not null default now(),
  unique (batch_id, school_id)
);

-- 7. Bank Sampel 2x24 jam
create table if not exists public.sample_vaults (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null references public.school_inspections(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  label_code text not null unique,
  stored_at timestamptz not null,
  expires_at timestamptz not null,
  status text not null default 'active' check (status in ('active', 'disposed', 'lab_submitted'))
);

-- 8. Cluster alerts
create table if not exists public.cluster_alerts (
  id uuid primary key default gen_random_uuid(),
  sppg_id uuid not null references public.sppg_kitchens(id) on delete cascade,
  batch_id uuid not null references public.food_batches(id) on delete cascade,
  reporter_school_id uuid not null references public.schools(id) on delete cascade,
  stage text not null check (stage in ('pre_consumption', 'post_consumption')),
  symptom_count integer not null default 0 check (symptom_count >= 0),
  notes text,
  broadcast_enabled boolean not null default true,
  sample_label_code text,
  pdf_dispatched boolean not null default false,
  created_at timestamptz not null default now()
);

-- 9. Alert acknowledgements
create table if not exists public.alert_acknowledgements (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.cluster_alerts(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  acknowledged_at timestamptz not null default now(),
  unique (alert_id, school_id)
);

-- 10. Plate-waste evaluation logs
create table if not exists public.plate_waste_logs (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.food_batches(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  sppg_id uuid not null references public.sppg_kitchens(id) on delete cascade,
  carb_waste_pct integer not null check (carb_waste_pct between 0 and 100),
  protein_waste_pct integer not null check (protein_waste_pct between 0 and 100),
  veg_waste_pct integer not null check (veg_waste_pct between 0 and 100),
  photo_urls jsonb not null default '[]'::jsonb,
  ai_assisted boolean not null default false,
  created_at timestamptz not null default now()
);

-- Foreign key and RLS query indexes
create index if not exists sppg_kitchens_owner_user_id_idx on public.sppg_kitchens (owner_user_id);
create index if not exists schools_owner_user_id_idx on public.schools (owner_user_id);
create index if not exists schools_sppg_id_status_idx on public.schools (sppg_id, verification_status);
create index if not exists food_batches_sppg_id_sealed_at_idx on public.food_batches (sppg_id, sealed_at desc);
create index if not exists school_inspections_batch_id_idx on public.school_inspections (batch_id);
create index if not exists school_inspections_school_id_created_at_idx on public.school_inspections (school_id, created_at desc);
create index if not exists sample_vaults_inspection_id_idx on public.sample_vaults (inspection_id);
create index if not exists sample_vaults_school_id_status_idx on public.sample_vaults (school_id, status);
create index if not exists cluster_alerts_sppg_id_created_at_idx on public.cluster_alerts (sppg_id, created_at desc);
create index if not exists cluster_alerts_batch_id_idx on public.cluster_alerts (batch_id);
create index if not exists cluster_alerts_reporter_school_id_idx on public.cluster_alerts (reporter_school_id);
create index if not exists alert_acknowledgements_alert_id_idx on public.alert_acknowledgements (alert_id);
create index if not exists alert_acknowledgements_school_id_idx on public.alert_acknowledgements (school_id);
create index if not exists plate_waste_logs_batch_id_idx on public.plate_waste_logs (batch_id);
create index if not exists plate_waste_logs_school_id_idx on public.plate_waste_logs (school_id);
create index if not exists plate_waste_logs_sppg_id_created_at_idx on public.plate_waste_logs (sppg_id, created_at desc);

-- Private helper functions for fast, non-recursive RLS evaluation
create or replace function private.current_user_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.role
  from public.profiles p
  where p.id = (select auth.uid())
  limit 1;
$$;

create or replace function private.current_kitchen_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select k.id
  from public.sppg_kitchens k
  where k.owner_user_id = (select auth.uid())
  limit 1;
$$;

create or replace function private.current_school_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id
  from public.schools s
  where s.owner_user_id = (select auth.uid())
  limit 1;
$$;

create or replace function private.current_approved_sppg_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.sppg_id
  from public.schools s
  where s.owner_user_id = (select auth.uid())
    and s.verification_status = 'approved'
  limit 1;
$$;

create or replace function private.can_access_audit_object(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    case
      when (select auth.uid()) is null then false
      when (select private.current_user_role()) = 'supervisor' then true
      when split_part(object_name, '/', 1) = 'batches'
        and split_part(object_name, '/', 2) <> ''
        and (
          split_part(object_name, '/', 2) = (select private.current_kitchen_id())::text
          or split_part(object_name, '/', 2) = (select private.current_approved_sppg_id())::text
        )
        then true
      when split_part(object_name, '/', 1) in ('inspections', 'plate_waste')
        and split_part(object_name, '/', 2) <> ''
        and (
          split_part(object_name, '/', 2) = (select private.current_school_id())::text
          or exists (
            select 1
            from public.schools s
            where s.id::text = split_part(object_name, '/', 2)
              and s.sppg_id = (select private.current_kitchen_id())
          )
        )
        then true
      else false
    end;
$$;

revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.current_user_role() to authenticated;
grant execute on function private.current_kitchen_id() to authenticated;
grant execute on function private.current_school_id() to authenticated;
grant execute on function private.current_approved_sppg_id() to authenticated;
grant execute on function private.can_access_audit_object(text) to authenticated;

-- Public RPCs
create or replace function public.get_server_time()
returns timestamptz
language sql
stable
security invoker
set search_path = ''
as $$
  select now() at time zone 'UTC';
$$;

create or replace function public.claim_sppg_registration(p_reg_number text, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_reg public.official_sppg_registry%rowtype;
  v_clean_reg text;
  v_invite_code text;
  v_suffix text;
begin
  v_uid := (select auth.uid());
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  v_clean_reg := upper(trim(coalesce(p_reg_number, '')));
  if v_clean_reg = '' or length(trim(coalesce(p_pin, ''))) < 4 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;

  select *
  into v_reg
  from public.official_sppg_registry r
  where r.reg_number = v_clean_reg
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if v_reg.is_claimed then
    return jsonb_build_object('ok', false, 'reason', 'already_claimed');
  end if;

  if extensions.crypt(trim(p_pin), v_reg.activation_pin_hash) <> v_reg.activation_pin_hash then
    return jsonb_build_object('ok', false, 'reason', 'invalid_pin');
  end if;

  update public.official_sppg_registry
  set is_claimed = true,
      claimed_at = now()
  where reg_number = v_reg.reg_number;

  v_suffix := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 4));
  v_invite_code := 'SPPG-' || v_suffix;

  return jsonb_build_object(
    'ok', true,
    'reg_number', v_reg.reg_number,
    'official_name', v_reg.official_name,
    'region_name', v_reg.region_name,
    'invite_code', v_invite_code
  );
end;
$$;

create or replace function public.lookup_sppg_by_invite_code(p_invite_code text)
returns table (
  id uuid,
  invite_code text,
  name text,
  adm4_code text,
  public_key text,
  is_verified boolean
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
  select k.id, k.invite_code, k.name, k.adm4_code, k.public_key, k.is_verified
  from public.sppg_kitchens k
  where upper(k.invite_code) = upper(trim(coalesce(p_invite_code, '')))
  limit 1;
end;
$$;

revoke execute on function public.get_server_time() from public, anon;
grant execute on function public.get_server_time() to authenticated;

revoke execute on function public.claim_sppg_registration(text, text) from public, anon;
grant execute on function public.claim_sppg_registration(text, text) to authenticated;

revoke execute on function public.lookup_sppg_by_invite_code(text) from public, anon;
grant execute on function public.lookup_sppg_by_invite_code(text) to authenticated;

-- Explicit minimal table privileges
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.sppg_kitchens to authenticated;
grant select, insert, update on public.schools to authenticated;
grant select, insert on public.food_batches to authenticated;
grant select, insert on public.school_inspections to authenticated;
grant select, insert, update on public.sample_vaults to authenticated;
grant select, insert, update on public.cluster_alerts to authenticated;
grant select, insert on public.alert_acknowledgements to authenticated;
grant select, insert on public.plate_waste_logs to authenticated;

-- Enable Row Level Security on every public table
alter table public.official_sppg_registry enable row level security;
alter table public.profiles enable row level security;
alter table public.sppg_kitchens enable row level security;
alter table public.schools enable row level security;
alter table public.food_batches enable row level security;
alter table public.school_inspections enable row level security;
alter table public.sample_vaults enable row level security;
alter table public.cluster_alerts enable row level security;
alter table public.alert_acknowledgements enable row level security;
alter table public.plate_waste_logs enable row level security;

-- RLS: official_sppg_registry (locked to RPC except read-only supervisor)
create policy "official_sppg_registry_select_supervisor"
  on public.official_sppg_registry
  for select
  to authenticated
  using ((select private.current_user_role()) = 'supervisor');

-- RLS: profiles
create policy "profiles_select_own_or_supervisor"
  on public.profiles
  for select
  to authenticated
  using (
    (select auth.uid()) = id
    or (select private.current_user_role()) = 'supervisor'
  );

create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check ((select auth.uid()) = id);

create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- RLS: sppg_kitchens
create policy "sppg_kitchens_select_scoped"
  on public.sppg_kitchens
  for select
  to authenticated
  using (
    owner_user_id = (select auth.uid())
    or id = (select private.current_approved_sppg_id())
    or id = (
      select s.sppg_id
      from public.schools s
      where s.owner_user_id = (select auth.uid())
      limit 1
    )
    or (select private.current_user_role()) = 'supervisor'
  );

create policy "sppg_kitchens_insert_owner"
  on public.sppg_kitchens
  for insert
  to authenticated
  with check (owner_user_id = (select auth.uid()));

create policy "sppg_kitchens_update_owner"
  on public.sppg_kitchens
  for update
  to authenticated
  using (owner_user_id = (select auth.uid()))
  with check (owner_user_id = (select auth.uid()));

-- RLS: schools
create policy "schools_select_scoped"
  on public.schools
  for select
  to authenticated
  using (
    owner_user_id = (select auth.uid())
    or sppg_id = (select private.current_kitchen_id())
    or (select private.current_user_role()) = 'supervisor'
  );

create policy "schools_insert_owner"
  on public.schools
  for insert
  to authenticated
  with check (owner_user_id = (select auth.uid()));

create policy "schools_update_owner_or_partner_kitchen"
  on public.schools
  for update
  to authenticated
  using (
    owner_user_id = (select auth.uid())
    or sppg_id = (select private.current_kitchen_id())
  )
  with check (
    owner_user_id = (select auth.uid())
    or sppg_id = (select private.current_kitchen_id())
  );

-- RLS: food_batches
create policy "food_batches_select_scoped"
  on public.food_batches
  for select
  to authenticated
  using (
    sppg_id = (select private.current_kitchen_id())
    or sppg_id = (select private.current_approved_sppg_id())
    or (select private.current_user_role()) = 'supervisor'
  );

create policy "food_batches_insert_kitchen"
  on public.food_batches
  for insert
  to authenticated
  with check (sppg_id = (select private.current_kitchen_id()));

-- RLS: school_inspections
create policy "school_inspections_select_scoped"
  on public.school_inspections
  for select
  to authenticated
  using (
    school_id = (select private.current_school_id())
    or exists (
      select 1
      from public.schools s
      where s.id = school_inspections.school_id
        and s.sppg_id = (select private.current_kitchen_id())
    )
    or (select private.current_user_role()) = 'supervisor'
  );

create policy "school_inspections_insert_school"
  on public.school_inspections
  for insert
  to authenticated
  with check (school_id = (select private.current_school_id()));

-- RLS: sample_vaults
create policy "sample_vaults_select_scoped"
  on public.sample_vaults
  for select
  to authenticated
  using (
    school_id = (select private.current_school_id())
    or exists (
      select 1
      from public.schools s
      where s.id = sample_vaults.school_id
        and s.sppg_id = (select private.current_kitchen_id())
    )
    or (select private.current_user_role()) = 'supervisor'
  );

create policy "sample_vaults_insert_school"
  on public.sample_vaults
  for insert
  to authenticated
  with check (school_id = (select private.current_school_id()));

create policy "sample_vaults_update_school"
  on public.sample_vaults
  for update
  to authenticated
  using (school_id = (select private.current_school_id()))
  with check (school_id = (select private.current_school_id()));

-- RLS: cluster_alerts (Realtime target)
create policy "cluster_alerts_select_scoped"
  on public.cluster_alerts
  for select
  to authenticated
  using (
    sppg_id = (select private.current_kitchen_id())
    or sppg_id = (select private.current_approved_sppg_id())
    or (select private.current_user_role()) = 'supervisor'
  );

create policy "cluster_alerts_insert_approved_school"
  on public.cluster_alerts
  for insert
  to authenticated
  with check (
    reporter_school_id = (select private.current_school_id())
    and sppg_id = (select private.current_approved_sppg_id())
    and exists (
      select 1
      from public.food_batches fb
      where fb.id = cluster_alerts.batch_id
        and fb.sppg_id = cluster_alerts.sppg_id
    )
  );

create policy "cluster_alerts_update_reporter_school"
  on public.cluster_alerts
  for update
  to authenticated
  using (reporter_school_id = (select private.current_school_id()))
  with check (reporter_school_id = (select private.current_school_id()));

-- RLS: alert_acknowledgements
create policy "alert_acknowledgements_select_scoped"
  on public.alert_acknowledgements
  for select
  to authenticated
  using (
    school_id = (select private.current_school_id())
    or exists (
      select 1
      from public.cluster_alerts ca
      where ca.id = alert_acknowledgements.alert_id
        and ca.sppg_id = (select private.current_kitchen_id())
    )
    or (select private.current_user_role()) = 'supervisor'
  );

create policy "alert_acknowledgements_insert_school"
  on public.alert_acknowledgements
  for insert
  to authenticated
  with check (
    school_id = (select private.current_school_id())
    and exists (
      select 1
      from public.cluster_alerts ca
      where ca.id = alert_acknowledgements.alert_id
        and ca.sppg_id = (select private.current_approved_sppg_id())
    )
  );

-- RLS: plate_waste_logs
create policy "plate_waste_logs_select_scoped"
  on public.plate_waste_logs
  for select
  to authenticated
  using (
    school_id = (select private.current_school_id())
    or sppg_id = (select private.current_kitchen_id())
    or (select private.current_user_role()) = 'supervisor'
  );

create policy "plate_waste_logs_insert_school"
  on public.plate_waste_logs
  for insert
  to authenticated
  with check (
    school_id = (select private.current_school_id())
    and sppg_id = (select private.current_approved_sppg_id())
  );

-- Storage bucket for compressed WebP audit photos
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'audit-photos',
  'audit-photos',
  false,
  524288,
  array['image/webp', 'image/jpeg', 'image/png']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "audit_photos_select_scoped"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'audit-photos'
    and (select private.can_access_audit_object(name))
  );

create policy "audit_photos_insert_owner_folder"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'audit-photos'
    and (
      (
        split_part(name, '/', 1) = 'batches'
        and split_part(name, '/', 2) = (select private.current_kitchen_id())::text
      )
      or (
        split_part(name, '/', 1) in ('inspections', 'plate_waste')
        and split_part(name, '/', 2) = (select private.current_school_id())::text
      )
    )
  );

create policy "audit_photos_update_owner_folder"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'audit-photos'
    and (
      (
        split_part(name, '/', 1) = 'batches'
        and split_part(name, '/', 2) = (select private.current_kitchen_id())::text
      )
      or (
        split_part(name, '/', 1) in ('inspections', 'plate_waste')
        and split_part(name, '/', 2) = (select private.current_school_id())::text
      )
    )
  )
  with check (
    bucket_id = 'audit-photos'
    and (
      (
        split_part(name, '/', 1) = 'batches'
        and split_part(name, '/', 2) = (select private.current_kitchen_id())::text
      )
      or (
        split_part(name, '/', 1) in ('inspections', 'plate_waste')
        and split_part(name, '/', 2) = (select private.current_school_id())::text
      )
    )
  );

create policy "audit_photos_delete_owner_folder"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'audit-photos'
    and (
      (
        split_part(name, '/', 1) = 'batches'
        and split_part(name, '/', 2) = (select private.current_kitchen_id())::text
      )
      or (
        split_part(name, '/', 1) in ('inspections', 'plate_waste')
        and split_part(name, '/', 2) = (select private.current_school_id())::text
      )
    )
  );

-- Enable Realtime Postgres Changes for cluster_alerts
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
