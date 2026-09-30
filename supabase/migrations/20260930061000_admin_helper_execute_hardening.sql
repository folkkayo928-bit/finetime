-- Additive live hardening migration already applied to FineTime.
-- Prevent anonymous/PUBLIC callers from executing the admin authorization helper.
revoke execute on function public.is_finetime_admin() from public;
grant execute on function public.is_finetime_admin() to authenticated;
