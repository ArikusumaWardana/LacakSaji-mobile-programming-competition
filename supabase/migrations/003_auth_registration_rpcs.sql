-- Pre-registration validation RPCs for SPPG whitelist and school NPSN/invite code.

create or replace function public.verify_sppg_whitelist(p_reg_number text, p_pin text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_clean_reg text;
  v_clean_pin text;
  v_reg public.official_sppg_registry%rowtype;
begin
  v_clean_reg := upper(trim(coalesce(p_reg_number, '')));
  v_clean_pin := trim(coalesce(p_pin, ''));

  if v_clean_reg = '' or length(v_clean_pin) < 4 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;

  select *
  into v_reg
  from public.official_sppg_registry r
  where r.reg_number = v_clean_reg;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if v_reg.is_claimed then
    return jsonb_build_object('ok', false, 'reason', 'already_claimed');
  end if;

  if extensions.crypt(v_clean_pin, v_reg.activation_pin_hash) <> v_reg.activation_pin_hash then
    return jsonb_build_object('ok', false, 'reason', 'invalid_pin');
  end if;

  return jsonb_build_object(
    'ok', true,
    'reg_number', v_reg.reg_number,
    'official_name', v_reg.official_name,
    'region_name', v_reg.region_name
  );
end;
$$;

create or replace function public.precheck_school_registration(p_npsn text, p_invite_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_clean_npsn text;
  v_clean_invite text;
  v_kitchen record;
begin
  v_clean_npsn := trim(coalesce(p_npsn, ''));
  v_clean_invite := upper(trim(coalesce(p_invite_code, '')));

  if v_clean_npsn !~ '^[0-9]{8}$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_npsn');
  end if;

  if v_clean_invite = '' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_invite');
  end if;

  if exists (select 1 from public.schools s where s.npsn = v_clean_npsn) then
    return jsonb_build_object('ok', false, 'reason', 'npsn_exists');
  end if;

  select k.id, k.name, k.invite_code, k.public_key
  into v_kitchen
  from public.sppg_kitchens k
  where upper(k.invite_code) = v_clean_invite
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'sppg_not_found');
  end if;

  return jsonb_build_object(
    'ok', true,
    'sppg_id', v_kitchen.id,
    'sppg_name', v_kitchen.name,
    'sppg_invite_code', v_kitchen.invite_code,
    'sppg_public_key', v_kitchen.public_key
  );
end;
$$;

revoke execute on function public.verify_sppg_whitelist(text, text) from public;
grant execute on function public.verify_sppg_whitelist(text, text) to anon, authenticated;

revoke execute on function public.precheck_school_registration(text, text) from public;
grant execute on function public.precheck_school_registration(text, text) to anon, authenticated;
