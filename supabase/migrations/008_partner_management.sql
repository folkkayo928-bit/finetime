-- FineTime partner management fields and subscription state.
alter table public.businesses
  add column if not exists services text[];

create table if not exists public.business_subscriptions (
  business_id uuid primary key references public.businesses(id) on delete cascade,
  plan text not null default 'basic' check (plan in ('basic','premium')),
  status text not null default 'active' check (status in ('active','paused','expired','cancelled')),
  monthly_price numeric check (monthly_price >= 0),
  starts_on date,
  ends_on date,
  notes text,
  updated_at timestamptz not null default now()
);

alter table public.business_subscriptions enable row level security;
revoke all on public.business_subscriptions from anon, authenticated;

create index if not exists business_subscriptions_status_idx
  on public.business_subscriptions(status);
