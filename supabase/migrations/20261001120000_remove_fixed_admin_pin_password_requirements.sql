-- FineTime additive hardening: remove fixed 6-12 digit security PIN requirement.
-- PIN remains non-empty and is still bcrypt-hashed server-side.
-- No existing rows, tables, policies, or workflows are removed.

create or replace function public.set_admin_security_pin(p_pin text)
returns boolean
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if auth.uid() is null or not public.is_finetime_admin() then
    raise exception 'Admin access required';
  end if;
  if p_pin is null or length(trim(p_pin)) = 0 then
    raise exception 'PIN cannot be empty';
  end if;

  insert into public.admin_security_settings(user_id, pin_hash, failed_attempts, locked_until)
  values (auth.uid(), extensions.crypt(p_pin, extensions.gen_salt('bf', 10)), 0, null)
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash,
        failed_attempts = 0,
        locked_until = null,
        updated_at = now();

  insert into public.admin_audit_logs(admin_user_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'admin_security_pin_set', 'admin_security', auth.uid(), jsonb_build_object('method','bcrypt'));

  return true;
end;
$function$;

create or replace function public.verify_admin_security_pin(p_pin text)
returns boolean
language plpgsql
security definer
set search_path to ''
as $function$
declare
  row_data public.admin_security_settings%rowtype;
  ok boolean;
begin
  if auth.uid() is null or not public.is_finetime_admin() then
    return false;
  end if;
  if p_pin is null or length(trim(p_pin)) = 0 then
    return false;
  end if;

  select * into row_data
  from public.admin_security_settings
  where user_id = auth.uid()
  for update;

  if row_data.pin_hash is null then
    return false;
  end if;

  if row_data.locked_until is not null and row_data.locked_until > now() then
    return false;
  end if;

  ok := extensions.crypt(p_pin, row_data.pin_hash) = row_data.pin_hash;

  if ok then
    update public.admin_security_settings
      set failed_attempts = 0, locked_until = null, updated_at = now()
      where user_id = auth.uid();
    return true;
  end if;

  update public.admin_security_settings
    set failed_attempts = failed_attempts + 1,
        locked_until = case
          when failed_attempts + 1 >= 5 then now() + interval '15 minutes'
          else locked_until
        end,
        updated_at = now()
    where user_id = auth.uid();

  return false;
end;
$function$;

revoke execute on function public.set_admin_security_pin(text) from public;
grant execute on function public.set_admin_security_pin(text) to authenticated;
revoke execute on function public.verify_admin_security_pin(text) from public;
grant execute on function public.verify_admin_security_pin(text) to authenticated;
