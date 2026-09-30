-- Additive admin-only business profile fields used by the full FineTime business creation form.
-- Owner/contact metadata is deliberately kept out of public businesses so it is not exposed by public SELECT * queries.

create table if not exists public.business_admin_profiles (
  business_id uuid primary key references public.businesses(id) on delete cascade,
  menu_slug text unique,
  tagline text,
  currency text not null default 'ETB',
  address text,
  logo_url text,
  owner_name text,
  owner_email text,
  onboarding_status text not null default 'pending' check (onboarding_status = any (array['pending','active','suspended']::text[])),
  payment_status text not null default 'trial' check (payment_status = any (array['trial','pending','paid','overdue']::text[])),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.business_admin_profiles enable row level security;

revoke all on table public.business_admin_profiles from anon, authenticated;
grant select, insert, update, delete on table public.business_admin_profiles to authenticated;

drop policy if exists "Admins can view business admin profiles" on public.business_admin_profiles;
create policy "Admins can view business admin profiles"
on public.business_admin_profiles for select
to authenticated
using ((select public.is_finetime_admin()));

drop policy if exists "Admins can create business admin profiles" on public.business_admin_profiles;
create policy "Admins can create business admin profiles"
on public.business_admin_profiles for insert
to authenticated
with check ((select public.is_finetime_admin()));

drop policy if exists "Admins can update business admin profiles" on public.business_admin_profiles;
create policy "Admins can update business admin profiles"
on public.business_admin_profiles for update
to authenticated
using ((select public.is_finetime_admin()))
with check ((select public.is_finetime_admin()));

drop policy if exists "Admins can delete business admin profiles" on public.business_admin_profiles;
create policy "Admins can delete business admin profiles"
on public.business_admin_profiles for delete
to authenticated
using ((select public.is_finetime_admin()));

drop trigger if exists trg_business_admin_profiles_updated_at on public.business_admin_profiles;
create trigger trg_business_admin_profiles_updated_at
before update on public.business_admin_profiles
for each row execute function public.set_finetime_updated_at();

create index if not exists business_admin_profiles_owner_email_idx
on public.business_admin_profiles (owner_email)
where owner_email is not null;
