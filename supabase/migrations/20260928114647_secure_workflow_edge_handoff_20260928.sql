-- FineTime secure workflow Edge Function handoff.
-- Client roles no longer execute the public workflow RPCs directly.
create or replace function public.create_food_order_internal(
  p_user_id uuid,
  p_business_id uuid,
  p_items jsonb,
  p_table_number text default null,
  p_customer_note text default null
)
returns table(id uuid, total numeric, status text)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := p_user_id;
  v_item jsonb;
  v_menu_item_id uuid;
  v_quantity int;
  v_name text;
  v_price numeric(10,2);
  v_total numeric(10,2) := 0;
  v_order_id uuid;
  v_normalized jsonb := '[]'::jsonb;
  v_options jsonb;
  v_table text := nullif(trim(p_table_number), '');
  v_note text := nullif(trim(p_customer_note), '');
begin
  if v_user is null then raise exception 'authentication required'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'order must contain at least one item'; end if;
  if v_table is not null and length(v_table) > 80 then raise exception 'table number is too long'; end if;
  if v_note is not null and length(v_note) > 1000 then raise exception 'customer note is too long'; end if;

  if not exists (
    select 1 from public.businesses b
    where b.id = p_business_id and b.is_published = true
      and b.category in ('restaurant','cafe','hotel')
  ) then raise exception 'business is not available for food orders'; end if;

  for v_item in select * from pg_catalog.jsonb_array_elements(p_items) loop
    begin
      v_menu_item_id := (v_item->>'menu_item_id')::uuid;
      v_quantity := (v_item->>'quantity')::int;
    exception when others then raise exception 'invalid order item'; end;
    if v_quantity is null or v_quantity < 1 or v_quantity > 99 then raise exception 'invalid item quantity'; end if;

    v_options := case
      when v_item ? 'options' and jsonb_typeof(v_item->'options') = 'object' then v_item->'options'
      else null
    end;

    select mi.name, mi.price into v_name, v_price
    from public.menu_items mi
    join public.menu_categories mc on mc.id = mi.category_id
    where mi.id = v_menu_item_id and mc.business_id = p_business_id
      and mi.is_available = true and mi.price is not null;
    if not found then raise exception 'one or more menu items are unavailable'; end if;

    v_total := v_total + (v_price * v_quantity);
    v_normalized := v_normalized || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'menu_item_id', v_menu_item_id,
        'name', v_name,
        'unit_price', v_price,
        'quantity', v_quantity,
        'options', v_options
      )
    );
  end loop;

  insert into public.orders(user_id,business_id,items,total,status,table_number,customer_note)
  values(v_user,p_business_id,v_normalized,v_total,'placed',v_table,v_note)
  returning public.orders.id into v_order_id;

  insert into public.order_items(order_id,menu_item_id,item_name,unit_price,quantity,options)
  select v_order_id,(x->>'menu_item_id')::uuid,x->>'name',
         (x->>'unit_price')::numeric,(x->>'quantity')::int,x->'options'
  from pg_catalog.jsonb_array_elements(v_normalized) x;

  id := v_order_id; total := v_total; status := 'placed'; return next;
end;
$function$;

create or replace function public.request_hotel_booking_internal(
  p_user_id uuid,
  p_business_id uuid,
  p_room_type_id uuid,
  p_check_in date,
  p_check_out date,
  p_guests integer
)
returns table(id uuid, reference text, status text)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := p_user_id;
  v_capacity int;
  v_total_rooms int;
  v_id uuid;
  v_reference text;
begin
  if v_user is null then raise exception 'authentication required'; end if;
  if p_check_out <= p_check_in then raise exception 'check-out must be after check-in'; end if;
  if p_check_in < current_date then raise exception 'check-in cannot be in the past'; end if;
  if p_guests < 1 then raise exception 'guest count must be at least 1'; end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_room_type_id::text,0));

  select rt.capacity,rt.total_rooms into v_capacity,v_total_rooms
  from public.room_types rt
  join public.businesses b on b.id=rt.business_id
  where rt.id=p_room_type_id and rt.business_id=p_business_id
    and b.category='hotel' and b.is_published=true
  for update;

  if not found then raise exception 'room type is not available'; end if;
  if v_capacity is not null and p_guests > v_capacity then raise exception 'guest count exceeds room capacity'; end if;
  if coalesce(v_total_rooms,0) < 1 then raise exception 'hotel has no inventory configured for this room type'; end if;

  insert into public.room_inventory(room_type_id,inventory_date,available_rooms)
  select p_room_type_id,gs::date,v_total_rooms
  from pg_catalog.generate_series(p_check_in,p_check_out-1,interval '1 day') gs
  on conflict(room_type_id,inventory_date) do nothing;

  if exists(
    select 1 from public.room_inventory ri
    where ri.room_type_id=p_room_type_id
      and ri.inventory_date>=p_check_in and ri.inventory_date<p_check_out
      and (ri.blocked or ri.available_rooms<1)
  ) then raise exception 'room is unavailable for one or more selected dates'; end if;

  update public.room_inventory
  set available_rooms=available_rooms-1,updated_at=now()
  where room_type_id=p_room_type_id
    and inventory_date>=p_check_in and inventory_date<p_check_out;

  insert into public.bookings(user_id,business_id,room_type_id,check_in,check_out,guests)
  values(v_user,p_business_id,p_room_type_id,p_check_in,p_check_out,p_guests)
  returning public.bookings.id,public.bookings.reference,public.bookings.status
  into v_id,v_reference,status;

  id:=v_id; reference:=v_reference; return next;
end;
$function$;

revoke execute on function public.create_food_order(uuid,jsonb,text,text) from public,anon,authenticated;
revoke execute on function public.request_hotel_booking(uuid,uuid,date,date,integer) from public,anon,authenticated;
revoke execute on function public.create_food_order_internal(uuid,uuid,jsonb,text,text) from public,anon,authenticated;
revoke execute on function public.request_hotel_booking_internal(uuid,uuid,uuid,date,date,integer) from public,anon,authenticated;

grant execute on function public.create_food_order_internal(uuid,uuid,jsonb,text,text) to service_role;
grant execute on function public.request_hotel_booking_internal(uuid,uuid,uuid,date,date,integer) to service_role;
