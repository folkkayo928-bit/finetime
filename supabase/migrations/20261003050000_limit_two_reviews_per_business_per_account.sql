create or replace function public.finetime_enforce_review_limit_two()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  review_count integer;
begin
  select count(*) into review_count
  from public.reviews
  where user_id = new.user_id
    and business_id = new.business_id;
  if review_count >= 2 then
    raise exception 'REVIEW_LIMIT_REACHED';
  end if;
  return new;
end;
$$;

revoke all on function public.finetime_enforce_review_limit_two() from public, anon, authenticated;
drop trigger if exists finetime_review_limit_two on public.reviews;
create trigger finetime_review_limit_two
before insert on public.reviews
for each row
execute function public.finetime_enforce_review_limit_two();
