-- Give FineTime admins browser access to subscription metadata used by the admin business form.
-- Existing service-side access remains intact; this adds only authenticated-admin RLS paths.

drop policy if exists "Admins can view business subscriptions" on public.business_subscriptions;
create policy "Admins can view business subscriptions"
on public.business_subscriptions for select
to authenticated
using ((select public.is_finetime_admin()));

drop policy if exists "Admins can create business subscriptions" on public.business_subscriptions;
create policy "Admins can create business subscriptions"
on public.business_subscriptions for insert
to authenticated
with check ((select public.is_finetime_admin()));

drop policy if exists "Admins can update business subscriptions" on public.business_subscriptions;
create policy "Admins can update business subscriptions"
on public.business_subscriptions for update
to authenticated
using ((select public.is_finetime_admin()))
with check ((select public.is_finetime_admin()));
