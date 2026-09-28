-- FineTime workflow hardening: reservation validation + order option preservation.
drop policy if exists "Customers create reservations" on public.reservations;
create policy "Customers create reservations"
on public.reservations for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and party_size between 1 and 50
  and reservation_date >= current_date
  and exists (
    select 1 from public.businesses b
    where b.id = reservations.business_id
      and b.is_published = true
      and b.category in ('restaurant','cafe')
  )
);

create or replace function public.create_food_order(
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
  v_user uuid := (select auth.uid());
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
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'order must contain at least one item';
  end if;
  if v_table is not null and length(v_table) > 80 then
    raise exception 'table number is too long';
  end if;
  if v_note is not null and length(v_note) > 1000 then
    raise exception 'customer note is too long';
  end if;

  if not exists (
    select 1 from public.businesses b
    where b.id = p_business_id
      and b.is_published = true
      and b.category in ('restaurant','cafe')
  ) then
    raise exception 'business is not available for food orders';
  end if;

  for v_item in select * from pg_catalog.jsonb_array_elements(p_items) loop
    begin
      v_menu_item_id := (v_item->>'menu_item_id')::uuid;
      v_quantity := (v_item->>'quantity')::int;
    exception when others then
      raise exception 'invalid order item';
    end;
    if v_quantity is null or v_quantity < 1 or v_quantity > 99 then
      raise exception 'invalid item quantity';
    end if;

    v_options := case
      when v_item ? 'options' and jsonb_typeof(v_item->'options') = 'object'
        then v_item->'options'
      else null
    end;

    select mi.name, mi.price
      into v_name, v_price
    from public.menu_items mi
    join public.menu_categories mc on mc.id = mi.category_id
    where mi.id = v_menu_item_id
      and mc.business_id = p_business_id
      and mi.is_available = true
      and mi.price is not null;

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

  insert into public.orders(user_id, business_id, items, total, status, table_number, customer_note)
  values (v_user, p_business_id, v_normalized, v_total, 'placed', v_table, v_note)
  returning public.orders.id into v_order_id;

  insert into public.order_items(order_id, menu_item_id, item_name, unit_price, quantity, options)
  select v_order_id,
         (x->>'menu_item_id')::uuid,
         x->>'name',
         (x->>'unit_price')::numeric,
         (x->>'quantity')::int,
         x->'options'
  from pg_catalog.jsonb_array_elements(v_normalized) x;

  id := v_order_id;
  total := v_total;
  status := 'placed';
  return next;
end;
$function$;

revoke execute on function public.create_food_order(uuid,jsonb,text,text) from anon;
grant execute on function public.create_food_order(uuid,jsonb,text,text) to authenticated;

revoke execute on function public.request_hotel_booking(uuid,uuid,date,date,integer) from anon;
grant execute on function public.request_hotel_booking(uuid,uuid,date,date,integer) to authenticated;
