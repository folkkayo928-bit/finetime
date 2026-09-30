begin;

-- FineTime CMS: richer site-module cards.
-- Additive only. Preserve existing RLS policies, audit triggers,
-- workflows, and existing data.

alter table public.site_modules
  add column if not exists image_url text null;

-- Add site_modules to Supabase Realtime only when it is not already
-- included. Safe to run repeatedly.
do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  )
  and not exists (
    select 1
    from pg_publication p
    join pg_publication_rel pr
      on pr.prpubid = p.oid
    join pg_class c
      on c.oid = pr.prrelid
    join pg_namespace n
      on n.oid = c.relnamespace
    where p.pubname = 'supabase_realtime'
      and n.nspname = 'public'
      and c.relname = 'site_modules'
  )
  then
    execute 'alter publication supabase_realtime add table public.site_modules';
  end if;
end
$$;

commit;
