revoke execute on function public.set_admin_security_pin(text) from public, anon;
revoke execute on function public.verify_admin_security_pin(text) from public, anon;
grant execute on function public.set_admin_security_pin(text) to authenticated;
grant execute on function public.verify_admin_security_pin(text) to authenticated;
