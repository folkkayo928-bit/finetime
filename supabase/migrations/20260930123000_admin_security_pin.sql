create table if not exists public.admin_security_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  pin_hash text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  failed_attempts integer not null default 0,
  locked_until timestamptz null
);

alter table public.admin_security_settings enable row level security;
revoke all on table public.admin_security_settings from anon, authenticated;

create or replace function public.set_admin_security_pin(p_pin text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_finetime_admin() then raise exception 'Admin access required'; end if;
  if p_pin is null or p_pin !~ '^[0-9]{6,12}$' then raise exception 'PIN must contain 6 to 12 digits'; end if;
  insert into public.admin_security_settings(user_id,pin_hash,failed_attempts,locked_until)
  values (auth.uid(),extensions.crypt(p_pin,extensions.gen_salt('bf',10)),0,null)
  on conflict (user_id) do update set pin_hash=excluded.pin_hash,failed_attempts=0,locked_until=null,updated_at=now();
  insert into public.admin_audit_logs(admin_user_id,action,entity_type,entity_id,metadata)
  values (auth.uid(),'admin_security_pin_set','admin_security',auth.uid(),jsonb_build_object('method','bcrypt'));
  return true;
end;
$$;

create or replace function public.verify_admin_security_pin(p_pin text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare row_data public.admin_security_settings%rowtype; ok boolean;
begin
  if auth.uid() is null or not public.is_finetime_admin() then return false; end if;
  if p_pin is null or p_pin !~ '^[0-9]{6,12}$' then return false; end if;
  select * into row_data from public.admin_security_settings where user_id=auth.uid() for update;
  if row_data.pin_hash is null then return false; end if;
  if row_data.locked_until is not null and row_data.locked_until > now() then return false; end if;
  ok := extensions.crypt(p_pin,row_data.pin_hash)=row_data.pin_hash;
  if ok then
    update public.admin_security_settings set failed_attempts=0,locked_until=null,updated_at=now() where user_id=auth.uid();
    return true;
  end if;
  update public.admin_security_settings
    set failed_attempts=failed_attempts+1,
        locked_until=case when failed_attempts+1>=5 then now()+interval '15 minutes' else locked_until end,
        updated_at=now()
    where user_id=auth.uid();
  return false;
end;
$$;

revoke execute on function public.set_admin_security_pin(text) from public;
revoke execute on function public.verify_admin_security_pin(text) from public;
grant execute on function public.set_admin_security_pin(text) to authenticated;
grant execute on function public.verify_admin_security_pin(text) to authenticated;

drop trigger if exists admin_security_settings_updated_at on public.admin_security_settings;
create trigger admin_security_settings_updated_at before update on public.admin_security_settings
for each row execute function public.set_finetime_updated_at();