-- Internal workflow functions are reachable only from the Edge Functions' service role.
revoke execute on function public.create_food_order(uuid,jsonb,text,text) from public,anon,authenticated;
revoke execute on function public.request_hotel_booking(uuid,uuid,date,date,integer) from public,anon,authenticated;
grant execute on function public.create_food_order_internal(uuid,uuid,jsonb,text,text) to service_role;
grant execute on function public.request_hotel_booking_internal(uuid,uuid,uuid,date,date,integer) to service_role;
