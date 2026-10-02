-- FineTime additive site media storage for admin-managed homepage/news/module images.
-- Preserve the existing business-media bucket and all existing policies.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'site-media',
  'site-media',
  true,
  10485760,
  array['image/jpeg','image/png','image/webp','image/gif']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='Public can read FineTime site media'
  ) then
    create policy "Public can read FineTime site media"
      on storage.objects
      for select
      to public
      using (bucket_id = 'site-media');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='FineTime admins can upload site media'
  ) then
    create policy "FineTime admins can upload site media"
      on storage.objects
      for insert
      to authenticated
      with check (
        bucket_id = 'site-media'
        and (select public.is_finetime_admin())
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='FineTime admins can update site media'
  ) then
    create policy "FineTime admins can update site media"
      on storage.objects
      for update
      to authenticated
      using (
        bucket_id = 'site-media'
        and (select public.is_finetime_admin())
      )
      with check (
        bucket_id = 'site-media'
        and (select public.is_finetime_admin())
      );
  end if;
end $$;