-- Review RLS hardening: preserve completed-experience eligibility and allow owners to manage their own review.
alter table public.reviews enable row level security;

drop policy if exists "Public can read reviews" on public.reviews;
create policy "Public can read reviews"
on public.reviews for select
to anon, authenticated
using (
  exists (
    select 1
    from public.businesses b
    where b.id = reviews.business_id
      and b.is_published = true
  )
);

drop policy if exists "Customers can update own reviews" on public.reviews;
create policy "Customers can update own reviews"
on public.reviews for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Customers can delete own reviews" on public.reviews;
create policy "Customers can delete own reviews"
on public.reviews for delete
to authenticated
using ((select auth.uid()) = user_id);

create index if not exists reviews_user_business_idx
  on public.reviews(user_id, business_id);
