-- Stage 7: Grant UPDATE privilege & scoped RLS policy on school_inspections
-- Required so school_inspections can safely update existing (batch_id, school_id)
-- rows during re-inspection or offline sync replay.

grant update on public.school_inspections to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'school_inspections'
      and policyname = 'school_inspections_update_school'
  ) then
    create policy "school_inspections_update_school"
      on public.school_inspections
      for update
      to authenticated
      using (school_id = (select private.current_school_id()))
      with check (
        school_id = (select private.current_school_id())
        and exists (
          select 1
          from public.food_batches fb
          where fb.id = school_inspections.batch_id
            and fb.sppg_id = (select private.current_approved_sppg_id())
        )
      );
  end if;
end $$;
