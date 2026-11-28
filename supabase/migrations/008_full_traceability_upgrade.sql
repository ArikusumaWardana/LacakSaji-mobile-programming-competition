-- LacakSaji Full-Scale Traceability Upgrade (9 Operational, Safety & Security Gaps)
-- Reference: PRD_lacaksaji.md v2.0.0 Section 3.8 & 7.1
-- Safe & idempotent additive migration preserving existing 001..007 schema and data.

-- 1. Extend profiles.role check constraint to include courier accounts
alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('kitchen', 'school', 'supervisor', 'courier'));

-- 2. Institution Members (Multi-PIC for SPPG/School + Courier accounts)
create table if not exists public.institution_members (
  id uuid primary key default gen_random_uuid(),
  institution_type text not null check (institution_type in ('sppg', 'school')),
  institution_id uuid not null,
  user_id uuid references public.profiles(id) on delete cascade,
  member_name text not null default '',
  member_email text not null default '',
  role text not null check (role in ('admin', 'staff', 'courier')),
  is_active boolean not null default true,
  invited_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint institution_members_type_role_check check (
    (institution_type = 'sppg' and role in ('admin', 'staff', 'courier'))
    or (institution_type = 'school' and role in ('admin', 'staff'))
  )
);

create index if not exists institution_members_user_active_idx
  on public.institution_members (user_id, is_active);
create index if not exists institution_members_scope_active_idx
  on public.institution_members (institution_type, institution_id, is_active);
create index if not exists institution_members_invited_by_idx
  on public.institution_members (invited_by);
create unique index if not exists institution_members_unique_user_uidx
  on public.institution_members (institution_type, institution_id, user_id)
  where user_id is not null;
create unique index if not exists institution_members_unique_email_uidx
  on public.institution_members (institution_type, institution_id, lower(member_email))
  where member_email <> '';

-- Backfill existing kitchen and school owners as active admins
insert into public.institution_members (
  institution_type,
  institution_id,
  user_id,
  member_name,
  member_email,
  role,
  is_active,
  invited_by
)
select
  'sppg',
  k.id,
  k.owner_user_id,
  coalesce(p.full_name, k.name),
  coalesce(lower(u.email), ''),
  'admin',
  true,
  k.owner_user_id
from public.sppg_kitchens k
left join public.profiles p on p.id = k.owner_user_id
left join auth.users u on u.id = k.owner_user_id
on conflict do nothing;

insert into public.institution_members (
  institution_type,
  institution_id,
  user_id,
  member_name,
  member_email,
  role,
  is_active,
  invited_by
)
select
  'school',
  s.id,
  s.owner_user_id,
  coalesce(p.full_name, s.name),
  coalesce(lower(u.email), ''),
  'admin',
  true,
  s.owner_user_id
from public.schools s
left join public.profiles p on p.id = s.owner_user_id
left join auth.users u on u.id = s.owner_user_id
on conflict do nothing;

-- 3. Update private RLS helper functions to support Multi-PIC & admin verification
create or replace function private.current_kitchen_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select k.id
      from public.sppg_kitchens k
      where k.owner_user_id = (select auth.uid())
      limit 1
    ),
    (
      select im.institution_id
      from public.institution_members im
      where im.user_id = (select auth.uid())
        and im.institution_type = 'sppg'
        and im.is_active = true
        and im.role in ('admin', 'staff')
      order by im.created_at asc
      limit 1
    )
  );
$$;

create or replace function private.current_courier_sppg_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select im.institution_id
  from public.institution_members im
  where im.user_id = (select auth.uid())
    and im.institution_type = 'sppg'
    and im.is_active = true
    and im.role = 'courier'
  order by im.created_at asc
  limit 1;
$$;

create or replace function private.current_school_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select s.id
      from public.schools s
      where s.owner_user_id = (select auth.uid())
      limit 1
    ),
    (
      select im.institution_id
      from public.institution_members im
      where im.user_id = (select auth.uid())
        and im.institution_type = 'school'
        and im.is_active = true
      order by im.created_at asc
      limit 1
    )
  );
$$;

create or replace function private.current_school_sppg_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.sppg_id
  from public.schools s
  where s.id = (select private.current_school_id())
  limit 1;
$$;

create or replace function private.current_school_status()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select s.verification_status
  from public.schools s
  where s.id = (select private.current_school_id())
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
  where s.id = (select private.current_school_id())
    and s.verification_status = 'approved'
  limit 1;
$$;

create or replace function private.is_kitchen_admin(p_sppg_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and (
      exists (
        select 1
        from public.sppg_kitchens k
        where k.id = p_sppg_id
          and k.owner_user_id = (select auth.uid())
      )
      or exists (
        select 1
        from public.institution_members im
        where im.institution_type = 'sppg'
          and im.institution_id = p_sppg_id
          and im.user_id = (select auth.uid())
          and im.is_active = true
          and im.role = 'admin'
      )
    );
$$;

create or replace function private.is_school_admin(p_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and (
      exists (
        select 1
        from public.schools s
        where s.id = p_school_id
          and s.owner_user_id = (select auth.uid())
      )
      or exists (
        select 1
        from public.institution_members im
        where im.institution_type = 'school'
          and im.institution_id = p_school_id
          and im.user_id = (select auth.uid())
          and im.is_active = true
          and im.role = 'admin'
      )
    );
$$;

revoke all on function private.current_courier_sppg_id() from public, anon, authenticated;
grant execute on function private.current_courier_sppg_id() to authenticated;
revoke all on function private.is_kitchen_admin(uuid) from public, anon, authenticated;
grant execute on function private.is_kitchen_admin(uuid) to authenticated;
revoke all on function private.is_school_admin(uuid) from public, anon, authenticated;
grant execute on function private.is_school_admin(uuid) to authenticated;

-- 4. Signing Keys (Ed25519 key rotation & revocation)
create table if not exists public.signing_keys (
  key_id text primary key,
  sppg_id uuid not null references public.sppg_kitchens(id) on delete cascade,
  public_key text not null,
  status text not null default 'active' check (status in ('active', 'retired', 'revoked')),
  device_label text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  retired_at timestamptz,
  revoked_at timestamptz
);

create index if not exists signing_keys_sppg_status_idx
  on public.signing_keys (sppg_id, status);
create index if not exists signing_keys_sppg_created_at_idx
  on public.signing_keys (sppg_id, created_at desc);
create index if not exists signing_keys_created_by_idx
  on public.signing_keys (created_by);

insert into public.signing_keys (
  key_id,
  sppg_id,
  public_key,
  status,
  device_label,
  created_by,
  created_at
)
select
  'legacy-' || left(replace(k.id::text, '-', ''), 8),
  k.id,
  k.public_key,
  'active',
  'Perangkat Utama Awal',
  k.owner_user_id,
  k.created_at
from public.sppg_kitchens k
where coalesce(k.public_key, '') <> ''
on conflict (key_id) do nothing;

alter table public.food_batches
  add column if not exists signing_key_id text references public.signing_keys(key_id) on delete set null;

create index if not exists food_batches_signing_key_id_idx
  on public.food_batches (signing_key_id);

-- 5. Upstream Ingredient Logs (Hulu Bahan Baku)
create table if not exists public.ingredient_logs (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.food_batches(id) on delete cascade,
  sppg_id uuid not null references public.sppg_kitchens(id) on delete cascade,
  ingredient_name text not null,
  supplier_name text not null,
  supplier_batch_no text not null,
  expiry_date date not null,
  received_at timestamptz not null default now(),
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists ingredient_logs_batch_id_idx
  on public.ingredient_logs (batch_id);
create index if not exists ingredient_logs_sppg_created_at_idx
  on public.ingredient_logs (sppg_id, created_at desc);
create index if not exists ingredient_logs_expiry_date_idx
  on public.ingredient_logs (expiry_date);
create index if not exists ingredient_logs_created_by_idx
  on public.ingredient_logs (created_by);

-- 6. Transit Handovers (Courier load/transit/arrival/handover chain)
create table if not exists public.transit_handovers (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.food_batches(id) on delete cascade,
  sppg_id uuid not null references public.sppg_kitchens(id) on delete cascade,
  school_id uuid references public.schools(id) on delete set null,
  courier_user_id uuid references public.profiles(id) on delete set null,
  courier_name text not null default '',
  loaded_at timestamptz not null default now(),
  departed_at timestamptz,
  arrived_at timestamptz,
  handed_over_at timestamptz,
  received_by_user_id uuid references public.profiles(id) on delete set null,
  status text not null default 'loaded' check (status in ('loaded', 'in_transit', 'arrived', 'handed_over')),
  handover_notes text,
  created_at timestamptz not null default now()
);

create index if not exists transit_handovers_batch_id_idx
  on public.transit_handovers (batch_id);
create index if not exists transit_handovers_sppg_created_at_idx
  on public.transit_handovers (sppg_id, created_at desc);
create index if not exists transit_handovers_school_id_idx
  on public.transit_handovers (school_id);
create index if not exists transit_handovers_courier_user_id_idx
  on public.transit_handovers (courier_user_id);
create index if not exists transit_handovers_received_by_user_id_idx
  on public.transit_handovers (received_by_user_id);

alter table public.transit_handovers
  add column if not exists load_lat double precision,
  add column if not exists load_lng double precision,
  add column if not exists arrive_lat double precision,
  add column if not exists arrive_lng double precision;

-- 7. Tray Return & Sanitization Logs (Reverse Logistics)
create table if not exists public.tray_return_logs (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.food_batches(id) on delete cascade,
  sppg_id uuid not null references public.sppg_kitchens(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  trays_sent integer not null check (trays_sent >= 0),
  trays_returned integer not null default 0 check (trays_returned >= 0),
  missing_trays integer generated always as (greatest(trays_sent - trays_returned, 0)) stored,
  return_status text not null default 'pending_return'
    check (return_status in ('pending_return', 'in_return_transit', 'received_sppg', 'sanitized')),
  sanitization_status text not null default 'pending'
    check (sanitization_status in ('pending', 'washed', 'sanitized_verified')),
  returned_at timestamptz,
  sanitized_at timestamptz,
  sanitized_by uuid references public.profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists tray_return_logs_batch_id_idx
  on public.tray_return_logs (batch_id);
create index if not exists tray_return_logs_sppg_created_at_idx
  on public.tray_return_logs (sppg_id, created_at desc);
create index if not exists tray_return_logs_school_created_at_idx
  on public.tray_return_logs (school_id, created_at desc);
create index if not exists tray_return_logs_sanitized_by_idx
  on public.tray_return_logs (sanitized_by);

alter table public.tray_return_logs
  add column if not exists sanitization_checklist jsonb not null default '{}'::jsonb;

-- 8. Allergen Tags (Zero-PII Student Safety)
alter table public.food_batches
  add column if not exists allergen_tags text[] not null default '{}'::text[];

create index if not exists food_batches_allergen_tags_gin_idx
  on public.food_batches using gin (allergen_tags);

create table if not exists public.school_allergen_profiles (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  allergen_tag text not null,
  student_count integer not null default 1 check (student_count > 0),
  severity_level text not null default 'moderate' check (severity_level in ('mild', 'moderate', 'severe')),
  handling_note text,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique (school_id, allergen_tag)
);

create index if not exists school_allergen_profiles_school_id_idx
  on public.school_allergen_profiles (school_id);
create index if not exists school_allergen_profiles_tag_idx
  on public.school_allergen_profiles (allergen_tag);
create index if not exists school_allergen_profiles_updated_by_idx
  on public.school_allergen_profiles (updated_by);

-- 9. Actual Food Core Temperature & BLE Readiness on school_inspections
alter table public.school_inspections
  add column if not exists actual_temp_celsius numeric(4,1);

alter table public.school_inspections
  add column if not exists temp_source text not null default 'bmkg_estimate'
    check (temp_source in ('bmkg_estimate', 'manual_thermometer', 'ble_sensor'));

-- 10. False-Alarm Resolution & Immutable Resolution Audit Trail
alter table public.cluster_alerts
  add column if not exists resolution_status text not null default 'active'
    check (resolution_status in ('active', 'clarified_safe', 'confirmed_klb'));

alter table public.cluster_alerts
  add column if not exists resolution_note text;

alter table public.cluster_alerts
  add column if not exists resolved_by uuid references public.profiles(id) on delete set null;

alter table public.cluster_alerts
  add column if not exists resolved_at timestamptz;

create index if not exists cluster_alerts_resolved_by_idx
  on public.cluster_alerts (resolved_by);

create table if not exists public.alert_resolution_audit_logs (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.cluster_alerts(id) on delete cascade,
  sppg_id uuid not null references public.sppg_kitchens(id) on delete cascade,
  previous_status text not null,
  new_status text not null check (new_status in ('active', 'clarified_safe', 'confirmed_klb')),
  resolution_note text not null default '',
  actor_user_id uuid references public.profiles(id) on delete set null,
  actor_role text not null default 'system',
  created_at timestamptz not null default now()
);

create index if not exists alert_resolution_audit_logs_alert_created_idx
  on public.alert_resolution_audit_logs (alert_id, created_at desc);
create index if not exists alert_resolution_audit_logs_sppg_idx
  on public.alert_resolution_audit_logs (sppg_id);
create index if not exists alert_resolution_audit_logs_actor_user_id_idx
  on public.alert_resolution_audit_logs (actor_user_id);

create or replace function private.log_cluster_alert_resolution()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (new.resolution_status is distinct from old.resolution_status)
     or (new.resolution_note is distinct from old.resolution_note) then
    insert into public.alert_resolution_audit_logs (
      alert_id,
      sppg_id,
      previous_status,
      new_status,
      resolution_note,
      actor_user_id,
      actor_role
    ) values (
      new.id,
      new.sppg_id,
      coalesce(old.resolution_status, 'active'),
      coalesce(new.resolution_status, 'active'),
      coalesce(new.resolution_note, ''),
      coalesce(new.resolved_by, (select auth.uid())),
      coalesce((select private.current_user_role()), 'system')
    );
  end if;
  return new;
end;
$$;

revoke all on function private.log_cluster_alert_resolution() from public, anon, authenticated;

drop trigger if exists trg_cluster_alerts_resolution_audit on public.cluster_alerts;
create trigger trg_cluster_alerts_resolution_audit
  after update of resolution_status, resolution_note on public.cluster_alerts
  for each row
  execute function private.log_cluster_alert_resolution();

-- Re-assert Realtime publication for cluster_alerts
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

-- 11. Privileges & Strict Tenant-Scoped RLS Policies
revoke all on public.signing_keys from anon, authenticated;
revoke all on public.institution_members from anon, authenticated;
revoke all on public.ingredient_logs from anon, authenticated;
revoke all on public.transit_handovers from anon, authenticated;
revoke all on public.tray_return_logs from anon, authenticated;
revoke all on public.school_allergen_profiles from anon, authenticated;
revoke all on public.alert_resolution_audit_logs from anon, authenticated;

grant select, insert, update on public.signing_keys to authenticated;
grant select, insert, update on public.institution_members to authenticated;
grant select, insert, update on public.ingredient_logs to authenticated;
grant select, insert, update on public.transit_handovers to authenticated;
grant select, insert, update on public.tray_return_logs to authenticated;
grant select, insert, update, delete on public.school_allergen_profiles to authenticated;
grant select on public.alert_resolution_audit_logs to authenticated;

alter table public.signing_keys enable row level security;
alter table public.institution_members enable row level security;
alter table public.ingredient_logs enable row level security;
alter table public.transit_handovers enable row level security;
alter table public.tray_return_logs enable row level security;
alter table public.school_allergen_profiles enable row level security;
alter table public.alert_resolution_audit_logs enable row level security;

-- Allow Multi-PIC staff & couriers to read their institution rows
drop policy if exists "sppg_kitchens_select_scoped" on public.sppg_kitchens;
create policy "sppg_kitchens_select_scoped"
  on public.sppg_kitchens
  for select
  to authenticated
  using (
    owner_user_id = (select auth.uid())
    or id = (select private.current_kitchen_id())
    or id = (select private.current_courier_sppg_id())
    or id = (select private.current_approved_sppg_id())
    or id = (select private.current_school_sppg_id())
    or (select private.current_user_role()) = 'supervisor'
  );

drop policy if exists "schools_select_scoped" on public.schools;
create policy "schools_select_scoped"
  on public.schools
  for select
  to authenticated
  using (
    owner_user_id = (select auth.uid())
    or id = (select private.current_school_id())
    or sppg_id = (select private.current_kitchen_id())
    or sppg_id = (select private.current_courier_sppg_id())
    or (select private.current_user_role()) = 'supervisor'
  );

-- Allow couriers to read food_batches belonging to their SPPG
drop policy if exists "food_batches_select_scoped" on public.food_batches;
create policy "food_batches_select_scoped"
  on public.food_batches
  for select
  to authenticated
  using (
    sppg_id = (select private.current_kitchen_id())
    or sppg_id = (select private.current_courier_sppg_id())
    or sppg_id = (select private.current_approved_sppg_id())
    or (select private.current_user_role()) = 'supervisor'
  );

-- Update sppg_kitchens update policy so Multi-PIC SPPG admins can also rotate keys
drop policy if exists "sppg_kitchens_update_owner" on public.sppg_kitchens;
create policy "sppg_kitchens_update_owner"
  on public.sppg_kitchens
  for update
  to authenticated
  using ((select private.is_kitchen_admin(id)))
  with check ((select private.is_kitchen_admin(id)));

-- Update cluster_alerts update policy so SPPG admin or reporter school admin can resolve alerts
drop policy if exists "cluster_alerts_update_reporter_school" on public.cluster_alerts;
create policy "cluster_alerts_update_reporter_school"
  on public.cluster_alerts
  for update
  to authenticated
  using (
    reporter_school_id = (select private.current_school_id())
    or (select private.is_kitchen_admin(sppg_id))
  )
  with check (
    (
      reporter_school_id = (select private.current_school_id())
      and sppg_id = (select private.current_approved_sppg_id())
    )
    or (select private.is_kitchen_admin(sppg_id))
  );

-- RLS: signing_keys
drop policy if exists "signing_keys_select_scoped" on public.signing_keys;
create policy "signing_keys_select_scoped"
  on public.signing_keys
  for select
  to authenticated
  using (
    sppg_id = (select private.current_kitchen_id())
    or sppg_id = (select private.current_approved_sppg_id())
    or sppg_id = (select private.current_school_sppg_id())
    or sppg_id = (select private.current_courier_sppg_id())
    or (select private.current_user_role()) = 'supervisor'
  );

drop policy if exists "signing_keys_insert_kitchen_admin" on public.signing_keys;
create policy "signing_keys_insert_kitchen_admin"
  on public.signing_keys
  for insert
  to authenticated
  with check ((select private.is_kitchen_admin(sppg_id)));

drop policy if exists "signing_keys_update_kitchen_admin" on public.signing_keys;
create policy "signing_keys_update_kitchen_admin"
  on public.signing_keys
  for update
  to authenticated
  using ((select private.is_kitchen_admin(sppg_id)))
  with check ((select private.is_kitchen_admin(sppg_id)));

-- RLS: institution_members
drop policy if exists "institution_members_select_scoped" on public.institution_members;
create policy "institution_members_select_scoped"
  on public.institution_members
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or (
      institution_type = 'sppg'
      and institution_id = (select private.current_kitchen_id())
    )
    or (
      institution_type = 'school'
      and institution_id = (select private.current_school_id())
    )
    or (select private.current_user_role()) = 'supervisor'
  );

drop policy if exists "institution_members_insert_admin" on public.institution_members;
create policy "institution_members_insert_admin"
  on public.institution_members
  for insert
  to authenticated
  with check (
    (institution_type = 'sppg' and (select private.is_kitchen_admin(institution_id)))
    or (institution_type = 'school' and (select private.is_school_admin(institution_id)))
  );

drop policy if exists "institution_members_update_admin" on public.institution_members;
create policy "institution_members_update_admin"
  on public.institution_members
  for update
  to authenticated
  using (
    (institution_type = 'sppg' and (select private.is_kitchen_admin(institution_id)))
    or (institution_type = 'school' and (select private.is_school_admin(institution_id)))
  )
  with check (
    (institution_type = 'sppg' and (select private.is_kitchen_admin(institution_id)))
    or (institution_type = 'school' and (select private.is_school_admin(institution_id)))
  );

-- RLS: ingredient_logs
drop policy if exists "ingredient_logs_select_scoped" on public.ingredient_logs;
create policy "ingredient_logs_select_scoped"
  on public.ingredient_logs
  for select
  to authenticated
  using (
    sppg_id = (select private.current_kitchen_id())
    or sppg_id = (select private.current_approved_sppg_id())
    or (select private.current_user_role()) = 'supervisor'
  );

drop policy if exists "ingredient_logs_insert_kitchen" on public.ingredient_logs;
create policy "ingredient_logs_insert_kitchen"
  on public.ingredient_logs
  for insert
  to authenticated
  with check (
    sppg_id = (select private.current_kitchen_id())
    and exists (
      select 1
      from public.food_batches fb
      where fb.id = ingredient_logs.batch_id
        and fb.sppg_id = ingredient_logs.sppg_id
    )
  );

drop policy if exists "ingredient_logs_update_kitchen" on public.ingredient_logs;
create policy "ingredient_logs_update_kitchen"
  on public.ingredient_logs
  for update
  to authenticated
  using (sppg_id = (select private.current_kitchen_id()))
  with check (
    sppg_id = (select private.current_kitchen_id())
    and exists (
      select 1
      from public.food_batches fb
      where fb.id = ingredient_logs.batch_id
        and fb.sppg_id = ingredient_logs.sppg_id
    )
  );

-- RLS: transit_handovers
drop policy if exists "transit_handovers_select_scoped" on public.transit_handovers;
create policy "transit_handovers_select_scoped"
  on public.transit_handovers
  for select
  to authenticated
  using (
    sppg_id = (select private.current_kitchen_id())
    or sppg_id = (select private.current_courier_sppg_id())
    or sppg_id = (select private.current_approved_sppg_id())
    or school_id = (select private.current_school_id())
    or (select private.current_user_role()) = 'supervisor'
  );

drop policy if exists "transit_handovers_insert_scoped" on public.transit_handovers;
create policy "transit_handovers_insert_scoped"
  on public.transit_handovers
  for insert
  to authenticated
  with check (
    (
      sppg_id = (select private.current_kitchen_id())
      or sppg_id = (select private.current_courier_sppg_id())
    )
    and exists (
      select 1
      from public.food_batches fb
      where fb.id = transit_handovers.batch_id
        and fb.sppg_id = transit_handovers.sppg_id
    )
  );

drop policy if exists "transit_handovers_update_scoped" on public.transit_handovers;
create policy "transit_handovers_update_scoped"
  on public.transit_handovers
  for update
  to authenticated
  using (
    sppg_id = (select private.current_kitchen_id())
    or sppg_id = (select private.current_courier_sppg_id())
    or (
      sppg_id = (select private.current_approved_sppg_id())
      and (school_id is null or school_id = (select private.current_school_id()))
    )
  )
  with check (
    sppg_id = (select private.current_kitchen_id())
    or sppg_id = (select private.current_courier_sppg_id())
    or (
      sppg_id = (select private.current_approved_sppg_id())
      and school_id = (select private.current_school_id())
    )
  );

-- RLS: tray_return_logs
drop policy if exists "tray_return_logs_select_scoped" on public.tray_return_logs;
create policy "tray_return_logs_select_scoped"
  on public.tray_return_logs
  for select
  to authenticated
  using (
    sppg_id = (select private.current_kitchen_id())
    or sppg_id = (select private.current_courier_sppg_id())
    or school_id = (select private.current_school_id())
    or (select private.current_user_role()) = 'supervisor'
  );

drop policy if exists "tray_return_logs_insert_scoped" on public.tray_return_logs;
create policy "tray_return_logs_insert_scoped"
  on public.tray_return_logs
  for insert
  to authenticated
  with check (
    (
      sppg_id = (select private.current_kitchen_id())
      or (
        school_id = (select private.current_school_id())
        and sppg_id = (select private.current_approved_sppg_id())
      )
    )
    and exists (
      select 1
      from public.food_batches fb
      where fb.id = tray_return_logs.batch_id
        and fb.sppg_id = tray_return_logs.sppg_id
    )
  );

drop policy if exists "tray_return_logs_update_scoped" on public.tray_return_logs;
create policy "tray_return_logs_update_scoped"
  on public.tray_return_logs
  for update
  to authenticated
  using (
    sppg_id = (select private.current_kitchen_id())
    or sppg_id = (select private.current_courier_sppg_id())
    or school_id = (select private.current_school_id())
  )
  with check (
    sppg_id = (select private.current_kitchen_id())
    or sppg_id = (select private.current_courier_sppg_id())
    or (
      school_id = (select private.current_school_id())
      and sppg_id = (select private.current_approved_sppg_id())
    )
  );

-- RLS: school_allergen_profiles (Zero PII)
drop policy if exists "school_allergen_profiles_select_scoped" on public.school_allergen_profiles;
create policy "school_allergen_profiles_select_scoped"
  on public.school_allergen_profiles
  for select
  to authenticated
  using (
    school_id = (select private.current_school_id())
    or exists (
      select 1
      from public.schools s
      where s.id = school_allergen_profiles.school_id
        and s.sppg_id = (select private.current_kitchen_id())
    )
    or (select private.current_user_role()) = 'supervisor'
  );

drop policy if exists "school_allergen_profiles_insert_school" on public.school_allergen_profiles;
create policy "school_allergen_profiles_insert_school"
  on public.school_allergen_profiles
  for insert
  to authenticated
  with check (school_id = (select private.current_school_id()));

drop policy if exists "school_allergen_profiles_update_school" on public.school_allergen_profiles;
create policy "school_allergen_profiles_update_school"
  on public.school_allergen_profiles
  for update
  to authenticated
  using (school_id = (select private.current_school_id()))
  with check (school_id = (select private.current_school_id()));

drop policy if exists "school_allergen_profiles_delete_school_admin" on public.school_allergen_profiles;
create policy "school_allergen_profiles_delete_school_admin"
  on public.school_allergen_profiles
  for delete
  to authenticated
  using ((select private.is_school_admin(school_id)));

-- RLS: alert_resolution_audit_logs
drop policy if exists "alert_resolution_audit_logs_select_scoped" on public.alert_resolution_audit_logs;
create policy "alert_resolution_audit_logs_select_scoped"
  on public.alert_resolution_audit_logs
  for select
  to authenticated
  using (
    sppg_id = (select private.current_kitchen_id())
    or sppg_id = (select private.current_approved_sppg_id())
    or (select private.current_user_role()) = 'supervisor'
  );

-- 12. Admin RPCs for Ed25519 Key Rotation / Revocation & Multi-PIC Team Management
create or replace function public.rotate_sppg_signing_key(
  p_sppg_id uuid,
  p_new_key_id text,
  p_new_public_key text,
  p_revoke_previous boolean default false,
  p_device_label text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid;
  v_now timestamptz := now();
  v_clean_key_id text := trim(coalesce(p_new_key_id, ''));
  v_clean_pub text := trim(coalesce(p_new_public_key, ''));
begin
  v_uid := (select auth.uid());
  if v_uid is null or not (select private.is_kitchen_admin(p_sppg_id)) then
    raise exception 'Permission denied';
  end if;

  if v_clean_key_id = '' or v_clean_pub = '' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;

  if p_revoke_previous then
    update public.signing_keys
    set status = 'revoked',
        revoked_at = coalesce(revoked_at, v_now)
    where sppg_id = p_sppg_id
      and status in ('active', 'retired')
      and key_id <> v_clean_key_id;
  else
    update public.signing_keys
    set status = 'retired',
        retired_at = coalesce(retired_at, v_now)
    where sppg_id = p_sppg_id
      and status = 'active'
      and key_id <> v_clean_key_id;
  end if;

  insert into public.signing_keys (
    key_id,
    sppg_id,
    public_key,
    status,
    device_label,
    created_by,
    created_at
  ) values (
    v_clean_key_id,
    p_sppg_id,
    v_clean_pub,
    'active',
    nullif(trim(coalesce(p_device_label, '')), ''),
    v_uid,
    v_now
  )
  on conflict (key_id) do update
  set public_key = excluded.public_key,
      status = 'active',
      revoked_at = null,
      retired_at = null;

  update public.sppg_kitchens
  set public_key = v_clean_pub
  where id = p_sppg_id;

  return jsonb_build_object(
    'ok', true,
    'key_id', v_clean_key_id,
    'rotated_at', v_now
  );
end;
$$;

create or replace function public.revoke_sppg_signing_key(
  p_sppg_id uuid,
  p_key_id text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_now timestamptz := now();
begin
  if (select auth.uid()) is null or not (select private.is_kitchen_admin(p_sppg_id)) then
    raise exception 'Permission denied';
  end if;

  update public.signing_keys
  set status = 'revoked',
      revoked_at = coalesce(revoked_at, v_now)
  where sppg_id = p_sppg_id
    and key_id = trim(coalesce(p_key_id, ''));

  return jsonb_build_object(
    'ok', true,
    'key_id', trim(coalesce(p_key_id, '')),
    'revoked_at', v_now
  );
end;
$$;

create or replace function public.add_institution_member(
  p_institution_type text,
  p_institution_id uuid,
  p_member_name text,
  p_member_email text,
  p_role text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_clean_type text := lower(trim(coalesce(p_institution_type, '')));
  v_clean_name text := trim(coalesce(p_member_name, ''));
  v_clean_email text := lower(trim(coalesce(p_member_email, '')));
  v_clean_role text := lower(trim(coalesce(p_role, 'staff')));
  v_target_user_id uuid;
  v_member_id uuid;
begin
  v_uid := (select auth.uid());
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if v_clean_type = 'sppg' then
    if not (select private.is_kitchen_admin(p_institution_id)) then
      raise exception 'Permission denied';
    end if;
    if v_clean_role not in ('admin', 'staff', 'courier') then
      return jsonb_build_object('ok', false, 'reason', 'invalid_role');
    end if;
  elsif v_clean_type = 'school' then
    if not (select private.is_school_admin(p_institution_id)) then
      raise exception 'Permission denied';
    end if;
    if v_clean_role not in ('admin', 'staff') then
      return jsonb_build_object('ok', false, 'reason', 'invalid_role');
    end if;
  else
    return jsonb_build_object('ok', false, 'reason', 'invalid_institution_type');
  end if;

  if v_clean_name = '' or v_clean_email = '' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;

  select u.id
  into v_target_user_id
  from auth.users u
  where lower(u.email) = v_clean_email
  limit 1;

  if v_target_user_id is not null then
    update public.institution_members
    set member_name = v_clean_name,
        member_email = v_clean_email,
        role = v_clean_role,
        is_active = true,
        updated_at = now()
    where institution_type = v_clean_type
      and institution_id = p_institution_id
      and user_id = v_target_user_id
    returning id into v_member_id;
  end if;

  if v_member_id is null then
    insert into public.institution_members (
      institution_type,
      institution_id,
      user_id,
      member_name,
      member_email,
      role,
      is_active,
      invited_by,
      updated_at
    ) values (
      v_clean_type,
      p_institution_id,
      v_target_user_id,
      v_clean_name,
      v_clean_email,
      v_clean_role,
      true,
      v_uid,
      now()
    )
    on conflict (institution_type, institution_id, lower(member_email))
    where member_email <> ''
    do update
    set user_id = coalesce(excluded.user_id, public.institution_members.user_id),
        member_name = excluded.member_name,
        role = excluded.role,
        is_active = true,
        updated_at = now()
    returning id into v_member_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'member_id', v_member_id,
    'linked_user_id', v_target_user_id
  );
end;
$$;

create or replace function public.set_institution_member_active(
  p_member_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_row public.institution_members%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_row
  from public.institution_members m
  where m.id = p_member_id
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if v_row.institution_type = 'sppg' then
    if not (select private.is_kitchen_admin(v_row.institution_id)) then
      raise exception 'Permission denied';
    end if;
  elsif not (select private.is_school_admin(v_row.institution_id)) then
    raise exception 'Permission denied';
  end if;

  update public.institution_members
  set is_active = coalesce(p_is_active, false),
      updated_at = now()
  where id = p_member_id;

  return jsonb_build_object(
    'ok', true,
    'member_id', p_member_id,
    'is_active', coalesce(p_is_active, false)
  );
end;
$$;

revoke execute on function public.rotate_sppg_signing_key(uuid, text, text, boolean, text) from public, anon;
grant execute on function public.rotate_sppg_signing_key(uuid, text, text, boolean, text) to authenticated;

revoke execute on function public.revoke_sppg_signing_key(uuid, text) from public, anon;
grant execute on function public.revoke_sppg_signing_key(uuid, text) to authenticated;

revoke execute on function public.add_institution_member(text, uuid, text, text, text) from public, anon;
grant execute on function public.add_institution_member(text, uuid, text, text, text) to authenticated;

revoke execute on function public.set_institution_member_active(uuid, boolean) from public, anon;
grant execute on function public.set_institution_member_active(uuid, boolean) to authenticated;

-- 13. Fase 3 RPCs: O01 Alert Resolution State Machine & Enriched v2 Lookup
create or replace function public.resolve_cluster_alert(
  p_alert_id uuid,
  p_new_status text,
  p_resolution_note text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid;
  v_now timestamptz := now();
  v_clean_status text := lower(trim(coalesce(p_new_status, '')));
  v_clean_note text := trim(coalesce(p_resolution_note, ''));
  v_alert public.cluster_alerts%rowtype;
  v_prev_status text;
  v_is_allowed boolean := false;
  v_resolver_name text := 'Admin SPPG / Sekolah Pelapor';
begin
  v_uid := (select auth.uid());
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if v_clean_status not in ('clarified_safe', 'confirmed_klb') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_status');
  end if;

  if length(v_clean_note) < 10 then
    return jsonb_build_object('ok', false, 'reason', 'note_too_short');
  end if;

  select *
  into v_alert
  from public.cluster_alerts ca
  where ca.id = p_alert_id
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  v_is_allowed :=
    (select private.is_kitchen_admin(v_alert.sppg_id))
    or (v_alert.reporter_school_id = (select private.current_school_id()));

  if not v_is_allowed then
    raise exception 'Permission denied';
  end if;

  v_prev_status := coalesce(v_alert.resolution_status, 'active');
  if v_prev_status = 'confirmed_klb' and v_clean_status <> 'confirmed_klb' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_transition');
  end if;

  select coalesce(nullif(trim(p.full_name), ''), 'Pejabat Terverifikasi')
  into v_resolver_name
  from public.profiles p
  where p.id = v_uid
  limit 1;

  update public.cluster_alerts
  set resolution_status = v_clean_status,
      resolution_note = v_clean_note,
      resolved_by = v_uid,
      resolved_at = v_now
  where id = p_alert_id;

  return jsonb_build_object(
    'ok', true,
    'alert_id', p_alert_id,
    'resolution_status', v_clean_status,
    'resolution_note', v_clean_note,
    'resolved_by', v_uid,
    'resolved_by_name', v_resolver_name,
    'resolved_at', v_now
  );
end;
$$;

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
      or (select private.current_user_role()) = 'supervisor'
    )
  limit 1;
end;
$$;

revoke execute on function public.resolve_cluster_alert(uuid, text, text) from public, anon;
grant execute on function public.resolve_cluster_alert(uuid, text, text) to authenticated;

revoke execute on function public.get_cluster_alert_details_v2(uuid) from public, anon;
grant execute on function public.get_cluster_alert_details_v2(uuid) to authenticated;
