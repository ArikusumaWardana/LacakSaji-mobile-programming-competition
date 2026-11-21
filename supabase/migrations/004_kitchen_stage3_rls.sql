-- Tahap 3 RLS enhancement: allow SPPG kitchens to read school_inspections
-- linked either to their partner schools or directly to their own food_batches.

alter policy "school_inspections_select_scoped" on public.school_inspections
  using (
    school_id = (select private.current_school_id())
    or exists (
      select 1
      from public.schools s
      where s.id = school_inspections.school_id
        and s.sppg_id = (select private.current_kitchen_id())
    )
    or exists (
      select 1
      from public.food_batches fb
      where fb.id = school_inspections.batch_id
        and fb.sppg_id = (select private.current_kitchen_id())
    )
    or (select private.current_user_role()) = 'supervisor'
  );
