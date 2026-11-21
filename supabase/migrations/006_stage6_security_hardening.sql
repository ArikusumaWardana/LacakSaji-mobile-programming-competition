-- Tahap 6: Security & Cross-Tenant RLS Hardening Migration
-- Addresses cross-SPPG escalation in schools update policy and strengthens
-- cross-tenant foreign-key ownership checks in child operational tables.

create or replace function private.current_school_sppg_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.sppg_id
  from public.schools s
  where s.owner_user_id = (select auth.uid())
  limit 1;
$$;

revoke all on function private.current_school_sppg_id() from public, anon, authenticated;
grant execute on function private.current_school_sppg_id() to authenticated;

drop policy if exists "schools_update_owner_or_partner_kitchen" on public.schools;
create policy "schools_update_owner_or_partner_kitchen"
  on public.schools
  for update
  to authenticated
  using (
    owner_user_id = (select auth.uid())
    or sppg_id = (select private.current_kitchen_id())
  )
  with check (
    sppg_id = (select private.current_kitchen_id())
    or (
      owner_user_id = (select auth.uid())
      and (
        verification_status = 'pending'
        or (
          sppg_id is not distinct from (select private.current_school_sppg_id())
          and verification_status = (select private.current_school_status())
        )
      )
    )
  );

drop policy if exists "school_inspections_insert_school" on public.school_inspections;
create policy "school_inspections_insert_school"
  on public.school_inspections
  for insert
  to authenticated
  with check (
    school_id = (select private.current_school_id())
    and exists (
      select 1
      from public.food_batches fb
      where fb.id = school_inspections.batch_id
        and fb.sppg_id = (select private.current_approved_sppg_id())
    )
  );

drop policy if exists "plate_waste_logs_insert_school" on public.plate_waste_logs;
create policy "plate_waste_logs_insert_school"
  on public.plate_waste_logs
  for insert
  to authenticated
  with check (
    school_id = (select private.current_school_id())
    and sppg_id = (select private.current_approved_sppg_id())
    and exists (
      select 1
      from public.food_batches fb
      where fb.id = plate_waste_logs.batch_id
        and fb.sppg_id = plate_waste_logs.sppg_id
    )
  );

drop policy if exists "sample_vaults_insert_school" on public.sample_vaults;
create policy "sample_vaults_insert_school"
  on public.sample_vaults
  for insert
  to authenticated
  with check (
    school_id = (select private.current_school_id())
    and exists (
      select 1
      from public.school_inspections si
      where si.id = sample_vaults.inspection_id
        and si.school_id = sample_vaults.school_id
    )
  );

drop policy if exists "cluster_alerts_update_reporter_school" on public.cluster_alerts;
create policy "cluster_alerts_update_reporter_school"
  on public.cluster_alerts
  for update
  to authenticated
  using (
    reporter_school_id = (select private.current_school_id())
  )
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
