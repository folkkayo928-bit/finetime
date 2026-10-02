-- FineTime additive security hardening: keep existing workflows intact.
-- 1) Replace "RLS enabled, no policy" findings with explicit deny-by-default policies.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='admin_security_settings'
      and policyname='No direct client access to admin security settings'
  ) then
    create policy "No direct client access to admin security settings"
      on public.admin_security_settings
      for all to authenticated
      using (false)
      with check (false);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='partner_business_members'
      and policyname='No direct client access to partner business memberships'
  ) then
    create policy "No direct client access to partner business memberships"
      on public.partner_business_members
      for all to authenticated
      using (false)
      with check (false);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='telegram_connections'
      and policyname='No direct client access to Telegram connections'
  ) then
    create policy "No direct client access to Telegram connections"
      on public.telegram_connections
      for all to authenticated
      using (false)
      with check (false);
  end if;
end $$;

-- 2) admin_save_business already has complete admin RLS policies on every table
-- it writes. Give authenticated users the existing table privileges and let
-- RLS perform the authorization instead of bypassing it with SECURITY DEFINER.
grant select, insert, update on public.business_subscriptions to authenticated;

alter function public.admin_save_business(uuid,jsonb,jsonb,jsonb)
  security invoker;

-- Explicitly preserve the intended RPC caller contract.
revoke execute on function public.admin_save_business(uuid,jsonb,jsonb,jsonb) from anon, public;
grant execute on function public.admin_save_business(uuid,jsonb,jsonb,jsonb) to authenticated;
