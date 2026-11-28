-- Phase 4: Demo Courier account seeded cleanly in Auth, Profiles, and SPPG Institution Members
-- Connected to SPPG Purwokerto Utara (a1000000-0000-4000-8000-000000000001)

do $$
declare
  v_courier_id uuid := '40000000-0000-4000-8000-000000000001';
  v_sppg_id uuid := 'a1000000-0000-4000-8000-000000000001';
  v_sppg_owner_id uuid := '10000000-0000-4000-8000-000000000001';
  v_email text := 'kurir.a@lacaksaji.id';
  v_full_name text := 'Bapak Dedi (Kurir SPPG Purwokerto Utara)';
begin
  if not exists (
    select 1 from auth.users u where u.id = v_courier_id or lower(u.email) = v_email
  ) then
    insert into auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      confirmation_token,
      recovery_token,
      email_change_token_new,
      email_change,
      email_change_token_current,
      phone_change,
      phone_change_token,
      reauthentication_token,
      raw_app_meta_data,
      raw_user_meta_data,
      is_super_admin,
      created_at,
      updated_at,
      is_sso_user,
      is_anonymous
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_courier_id,
      'authenticated',
      'authenticated',
      v_email,
      extensions.crypt('LacakSaji2026!', extensions.gen_salt('bf')),
      now(),
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('full_name', v_full_name),
      false,
      now(),
      now(),
      false,
      false
    );
  else
    update auth.users
    set instance_id = '00000000-0000-0000-0000-000000000000',
        is_super_admin = coalesce(is_super_admin, false),
        updated_at = now()
    where id = v_courier_id
      and lower(email) = v_email
      and (
        instance_id is distinct from '00000000-0000-0000-0000-000000000000'
        or is_super_admin is null
      );
  end if;

  if not exists (
    select 1 from auth.identities i where i.user_id = v_courier_id and i.provider = 'email'
  ) then
    insert into auth.identities (
      id,
      user_id,
      provider_id,
      identity_data,
      provider,
      last_sign_in_at,
      created_at,
      updated_at
    ) values (
      v_courier_id,
      v_courier_id,
      v_courier_id::text,
      jsonb_build_object(
        'sub', v_courier_id::text,
        'email', v_email,
        'email_verified', true,
        'phone_verified', false
      ),
      'email',
      now(),
      now(),
      now()
    );
  end if;

  insert into public.profiles (id, role, full_name)
  values (v_courier_id, 'courier', v_full_name)
  on conflict (id) do update
  set role = 'courier',
      full_name = excluded.full_name;

  if exists (select 1 from public.sppg_kitchens k where k.id = v_sppg_id) then
    insert into public.institution_members (
      institution_type,
      institution_id,
      user_id,
      member_name,
      member_email,
      role,
      is_active,
      invited_by
    ) values (
      'sppg',
      v_sppg_id,
      v_courier_id,
      v_full_name,
      v_email,
      'courier',
      true,
      v_sppg_owner_id
    )
    on conflict do nothing;
  end if;
end $$;
