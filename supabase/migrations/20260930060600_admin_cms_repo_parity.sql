-- FineTime additive admin/CMS security migration.
-- Safe to apply after existing FineTime migrations. Existing tables, policies,
-- functions, Edge Functions, Telegram workflow, customer workflow, partner
-- workflow, and data are preserved. This migration is idempotent where possible.

create schema if not exists private;

create table if not exists public.admin_memberships (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'admin' check (role = 'admin'),
  created_at timestamptz not null default now()
);

alter table public.admin_memberships enable row level security;
revoke all on public.admin_memberships from anon, authenticated;
grant select on public.admin_memberships to authenticated;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='admin_memberships' and policyname='Users can read their own admin membership') then
    create policy "Users can read their own admin membership"
      on public.admin_memberships for select to authenticated
      using ((select auth.uid()) = user_id);
  end if;
end $$;

create or replace function public.is_finetime_admin()
returns boolean
language sql stable security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_memberships am
    where am.user_id = (select auth.uid())
      and am.role = 'admin'
  );
$$;

revoke execute on function public.is_finetime_admin() from public, anon;
grant execute on function public.is_finetime_admin() to authenticated;

create table if not exists public.news (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  summary text,
  body text,
  cover_url text,
  is_published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists news_published_at_desc_idx
  on public.news (published_at desc)
  where is_published = true;

alter table public.news enable row level security;
revoke all on public.news from anon, authenticated;
grant select on public.news to anon, authenticated;
grant insert, update, delete on public.news to authenticated;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='news' and policyname='Public can read published news') then
    create policy "Public can read published news"
      on public.news for select to anon, authenticated
      using (is_published = true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='news' and policyname='FineTime admins can manage news') then
    create policy "FineTime admins can manage news"
      on public.news for all to authenticated
      using ((select public.is_finetime_admin()))
      with check ((select public.is_finetime_admin()));
  end if;
end $$;

create table if not exists public.site_modules (
  id uuid primary key default gen_random_uuid(),
  placement text not null,
  title text not null,
  body text,
  cta_label text,
  cta_url text,
  sort_order integer not null default 0,
  is_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists site_modules_enabled_placement_idx
  on public.site_modules (placement, sort_order, created_at desc)
  where is_enabled = true;

alter table public.site_modules enable row level security;
revoke all on public.site_modules from anon, authenticated;
grant select on public.site_modules to anon, authenticated;
grant insert, update, delete on public.site_modules to authenticated;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='site_modules' and policyname='Public can read enabled site modules') then
    create policy "Public can read enabled site modules"
      on public.site_modules for select to anon, authenticated
      using (is_enabled = true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='site_modules' and policyname='FineTime admins can manage site modules') then
    create policy "FineTime admins can manage site modules"
      on public.site_modules for all to authenticated
      using ((select public.is_finetime_admin()))
      with check ((select public.is_finetime_admin()));
  end if;
end $$;

create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_logs_created_at_idx
  on public.admin_audit_logs (created_at desc);
create index if not exists admin_audit_logs_entity_idx
  on public.admin_audit_logs (entity_type, entity_id);
create index if not exists admin_audit_logs_admin_idx
  on public.admin_audit_logs (admin_user_id, created_at desc);

alter table public.admin_audit_logs enable row level security;
revoke all on public.admin_audit_logs from anon, authenticated;
grant select on public.admin_audit_logs to authenticated;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='admin_audit_logs' and policyname='FineTime admins can read audit logs') then
    create policy "FineTime admins can read audit logs"
      on public.admin_audit_logs for select to authenticated
      using ((select public.is_finetime_admin()));
  end if;
end $$;

-- Keep the existing public business read contract and add admin management only.
-- This does not remove or alter any existing business policy.
grant select, insert, update, delete on public.businesses to authenticated;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='businesses' and policyname='FineTime admins can manage businesses') then
    create policy "FineTime admins can manage businesses"
      on public.businesses for all to authenticated
      using ((select public.is_finetime_admin()))
      with check ((select public.is_finetime_admin()));
  end if;
end $$;

-- Cities remain public-readable and are not browser-writable.
revoke insert, update, delete on public.cities from anon, authenticated;

-- Activation codes remain server/business workflow data. Browser access is admin-only.
grant select, insert, update on public.activation_codes to authenticated;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='activation_codes' and policyname='FineTime admins can manage activation codes') then
    create policy "FineTime admins can manage activation codes"
      on public.activation_codes for all to authenticated
      using ((select public.is_finetime_admin()))
      with check ((select public.is_finetime_admin()));
  end if;
end $$;

create or replace function public.set_finetime_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke execute on function public.set_finetime_updated_at() from public, anon, authenticated;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname='news_set_updated_at' and tgrelid='public.news'::regclass) then
    create trigger news_set_updated_at before update on public.news
      for each row execute function public.set_finetime_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname='site_modules_set_updated_at' and tgrelid='public.site_modules'::regclass) then
    create trigger site_modules_set_updated_at before update on public.site_modules
      for each row execute function public.set_finetime_updated_at();
  end if;
end $$;

-- Audit is generated by database triggers, never by a browser-supplied admin id.
-- Metadata intentionally records only safe operational fields, not activation-code hashes.
create or replace function private.write_finetime_admin_audit()
returns trigger
language plpgsql security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := (select auth.uid());
  action_name text;
  entity_uuid uuid;
  meta jsonb;
begin
  if not exists (
    select 1 from public.admin_memberships am
    where am.user_id = actor and am.role = 'admin'
  ) then
    raise exception 'Only FineTime admins may write admin audit records';
  end if;

  entity_uuid := case when tg_op = 'DELETE' then old.id else new.id end;

  if tg_table_name = 'businesses' then
    action_name := case
      when tg_op = 'INSERT' then 'business_create'
      when tg_op = 'DELETE' then 'business_delete'
      when coalesce(old.is_published,false) is distinct from coalesce(new.is_published,false)
        and coalesce(new.is_published,false) = true then 'business_publish'
      when coalesce(old.is_published,false) is distinct from coalesce(new.is_published,false)
        and coalesce(new.is_published,false) = false then 'business_hide'
      else 'business_edit'
    end;
    meta := case when tg_op = 'DELETE' then jsonb_build_object('name',old.name,'category',old.category,'city_id',old.city_id)
      else jsonb_build_object('name',new.name,'category',new.category,'city_id',new.city_id,'is_published',new.is_published) end;
  elsif tg_table_name = 'activation_codes' then
    action_name := case when tg_op='INSERT' then 'activation_code_create' when tg_op='DELETE' then 'activation_code_delete'
      when coalesce(old.revoked_at is not null,false) is distinct from coalesce(new.revoked_at is not null,false)
        and new.revoked_at is not null then 'activation_code_revoke' else 'activation_code_edit' end;
    meta := case when tg_op='DELETE' then jsonb_build_object('business_id',old.business_id,'expires_at',old.expires_at,'used_at',old.used_at,'revoked_at',old.revoked_at)
      else jsonb_build_object('business_id',new.business_id,'expires_at',new.expires_at,'used_at',new.used_at,'revoked_at',new.revoked_at) end;
  elsif tg_table_name = 'news' then
    action_name := case when tg_op='INSERT' then 'news_create' when tg_op='DELETE' then 'news_delete'
      when old.is_published is distinct from new.is_published and new.is_published then 'news_publish'
      when old.is_published is distinct from new.is_published and not new.is_published then 'news_hide'
      else 'news_edit' end;
    meta := case when tg_op='DELETE' then jsonb_build_object('title',old.title,'slug',old.slug)
      else jsonb_build_object('title',new.title,'slug',new.slug,'is_published',new.is_published) end;
  elsif tg_table_name = 'site_modules' then
    action_name := case when tg_op='INSERT' then 'future_module_create' when tg_op='DELETE' then 'future_module_delete'
      when old.is_enabled is distinct from new.is_enabled and new.is_enabled then 'future_module_enable'
      when old.is_enabled is distinct from new.is_enabled and not new.is_enabled then 'future_module_disable'
      else 'future_module_edit' end;
    meta := case when tg_op='DELETE' then jsonb_build_object('placement',old.placement,'title',old.title)
      else jsonb_build_object('placement',new.placement,'title',new.title,'is_enabled',new.is_enabled) end;
  else
    raise exception 'Unsupported audit table: %', tg_table_name;
  end if;

  insert into public.admin_audit_logs(admin_user_id,action,entity_type,entity_id,metadata)
  values(actor,action_name,tg_table_name,entity_uuid,meta);

  return case when tg_op='DELETE' then old else new end;
end;
$$;

revoke all on function private.write_finetime_admin_audit() from public, anon, authenticated;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname='businesses_admin_audit' and tgrelid='public.businesses'::regclass) then
    create trigger businesses_admin_audit after insert or update or delete on public.businesses
      for each row execute function private.write_finetime_admin_audit();
  end if;
  if not exists (select 1 from pg_trigger where tgname='activation_codes_admin_audit' and tgrelid='public.activation_codes'::regclass) then
    create trigger activation_codes_admin_audit after insert or update or delete on public.activation_codes
      for each row execute function private.write_finetime_admin_audit();
  end if;
  if not exists (select 1 from pg_trigger where tgname='news_admin_audit' and tgrelid='public.news'::regclass) then
    create trigger news_admin_audit after insert or update or delete on public.news
      for each row execute function private.write_finetime_admin_audit();
  end if;
  if not exists (select 1 from pg_trigger where tgname='site_modules_admin_audit' and tgrelid='public.site_modules'::regclass) then
    create trigger site_modules_admin_audit after insert or update or delete on public.site_modules
      for each row execute function private.write_finetime_admin_audit();
  end if;
end $$;

-- No seed/test data is inserted by this migration.