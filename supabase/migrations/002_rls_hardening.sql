-- Corrective hardening for server time RPC and privilege/verification RLS policies.

create or replace function public.get_server_time()
returns timestamptz
language sql
stable
security invoker
set search_path = ''
as $$
  select now();
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
  where s.owner_user_id = (select auth.uid())
  limit 1;
$$;

revoke all on function private.current_school_status() from public, anon, authenticated;
grant execute on function private.current_school_status() to authenticated;

alter policy "profiles_insert_own" on public.profiles
  with check (
    (select auth.uid()) = id
    and role in ('kitchen', 'school')
  );

alter policy "profiles_update_own" on public.profiles
  using ((select auth.uid()) = id)
  with check (
    (select auth.uid()) = id
    and role = (select private.current_user_role())
  );

alter policy "schools_insert_owner" on public.schools
  with check (
    owner_user_id = (select auth.uid())
    and verification_status = 'pending'
  );

alter policy "schools_update_owner_or_partner_kitchen" on public.schools
  using (
    owner_user_id = (select auth.uid())
    or sppg_id = (select private.current_kitchen_id())
  )
  with check (
    sppg_id = (select private.current_kitchen_id())
    or (
      owner_user_id = (select auth.uid())
      and (
        verification_status <> 'approved'
        or verification_status = (select private.current_school_status())
      )
    )
  );

grant select on public.official_sppg_registry to authenticated;
