insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'business-media',
  'business-media',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp','image/gif']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can read FineTime business media" on storage.objects;
create policy "Public can read FineTime business media"
on storage.objects for select
to public
using (bucket_id = 'business-media');

alter publication supabase_realtime add table public.businesses;
alter publication supabase_realtime add table public.room_types;
alter publication supabase_realtime add table public.menu_categories;
alter publication supabase_realtime add table public.menu_items;
alter publication supabase_realtime add table public.promotions;
