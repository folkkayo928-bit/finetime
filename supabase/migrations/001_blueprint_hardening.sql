-- FineTime blueprint hardening migration.
-- Additive: preserves existing IDs/data and extends the current production schema.
-- Apply this after supabase/schema.sql in the Supabase SQL editor/migration runner.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  reference_type text,
  reference_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_created_idx
  on public.notifications(user_id, created_at desc);

create table if not exists public.business_members (
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  role text not null default 'partner' check (role in ('owner','manager','staff','partner')),
  created_at timestamptz not null default now(),
  primary key (business_id, user_id)
);

create index if not exists business_members_user_idx
  on public.business_members(user_id);

create table if not exists public.activation_codes (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  code_hash text not null unique,
  expires_at timestamptz,
  used_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.partner_business_members (
  business_id uuid not null references public.businesses(id) on delete cascade,
  telegram_user_id text not null,
  role text not null default 'partner' check (role in ('owner','manager','staff','partner')),
  created_at timestamptz not null default now(),
  primary key (business_id, telegram_user_id)
);

create index if not exists partner_business_members_telegram_idx
  on public.partner_business_members(telegram_user_id);

create table if not exists public.telegram_connections (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  telegram_user_id text not null,
  telegram_chat_id text,
  connected_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (business_id, telegram_user_id)
);

create index if not exists telegram_connections_user_idx
  on public.telegram_connections(telegram_user_id);

create table if not exists public.room_inventory (
  room_type_id uuid not null references public.room_types(id) on delete cascade,
  inventory_date date not null,
  available_rooms int not null default 0 check (available_rooms >= 0),
  blocked boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (room_type_id, inventory_date)
);

create index if not exists room_inventory_date_idx
  on public.room_inventory(inventory_date, room_type_id);

alter table public.orders add column if not exists table_number text;
alter table public.orders add column if not exists customer_note text;

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  menu_item_id uuid references public.menu_items(id) on delete set null,
  item_name text not null,
  unit_price numeric(10,2),
  quantity int not null check (quantity > 0),
  options jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  body text,
  created_at timestamptz not null default now(),
  unique (user_id, business_id)
);

create index if not exists reviews_business_idx
  on public.reviews(business_id, created_at desc);

-- Make promotion visibility date-aware and prevent unpublished menu/room leakage.
drop policy if exists "Allow public read on promotions" on public.promotions;
create policy "Public can read live promotions"
on public.promotions for select
to anon, authenticated
using (
  status = 'active'
  and (starts_on is null or starts_on <= current_date)
  and (ends_on is null or ends_on >= current_date)
  and exists (
    select 1 from public.businesses b
    where b.id = promotions.business_id and b.is_published = true
  )
);

drop policy if exists "Allow public read on menu_categories" on public.menu_categories;
create policy "Public can read published menus"
on public.menu_categories for select
to anon, authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = menu_categories.business_id and b.is_published = true
  )
);

drop policy if exists "Allow public read on menu_items" on public.menu_items;
create policy "Public can read published menu items"
on public.menu_items for select
to anon, authenticated
using (
  is_available = true
  and exists (
    select 1
    from public.menu_categories c
    join public.businesses b on b.id = c.business_id
    where c.id = menu_items.category_id and b.is_published = true
  )
);

drop policy if exists "Allow public read on room_types" on public.room_types;
create policy "Public can read published room types"
on public.room_types for select
to anon, authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = room_types.business_id and b.is_published = true
  )
);

-- Public availability is read-only; writes stay with authorized partners/server functions.
alter table public.room_inventory enable row level security;
drop policy if exists "Public can read published room availability" on public.room_inventory;
create policy "Public can read published room availability"
on public.room_inventory for select
to anon, authenticated
using (
  exists (
    select 1
    from public.room_types rt
    join public.businesses b on b.id = rt.business_id
    where rt.id = room_inventory.room_type_id and b.is_published = true
  )
);

-- Customer notifications are private.
alter table public.notifications enable row level security;
drop policy if exists "Users can read own notifications" on public.notifications;
create policy "Users can read own notifications"
on public.notifications for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can update own notifications" on public.notifications;
create policy "Users can update own notifications"
on public.notifications for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- Partner membership is private to the connected partner identity.
alter table public.business_members enable row level security;
drop policy if exists "Members can read their memberships" on public.business_members;
create policy "Members can read their memberships"
on public.business_members for select
to authenticated
using ((select auth.uid()) = user_id);

-- Partner access to operational rows is restricted to their business.
drop policy if exists "own bookings" on public.bookings;
create policy "Customers and authorized partners read bookings"
on public.bookings for select
to authenticated
using (
  (select auth.uid()) = user_id
  or exists (
    select 1 from public.business_members m
    where m.business_id = bookings.business_id and m.user_id = (select auth.uid())
  )
);

drop policy if exists "own reservations" on public.reservations;
create policy "Customers and authorized partners read reservations"
on public.reservations for select
to authenticated
using (
  (select auth.uid()) = user_id
  or exists (
    select 1 from public.business_members m
    where m.business_id = reservations.business_id and m.user_id = (select auth.uid())
  )
);

drop policy if exists "own orders" on public.orders;
create policy "Customers and authorized partners read orders"
on public.orders for select
to authenticated
using (
  (select auth.uid()) = user_id
  or exists (
    select 1 from public.business_members m
    where m.business_id = orders.business_id and m.user_id = (select auth.uid())
  )
);

drop policy if exists "Partners update bookings" on public.bookings;
create policy "Partners update bookings"
on public.bookings for update
to authenticated
using (
  exists (
    select 1 from public.business_members m
    where m.business_id = bookings.business_id and m.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.business_members m
    where m.business_id = bookings.business_id and m.user_id = (select auth.uid())
  )
);

drop policy if exists "Partners update reservations" on public.reservations;
create policy "Partners update reservations"
on public.reservations for update
to authenticated
using (
  exists (
    select 1 from public.business_members m
    where m.business_id = reservations.business_id and m.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.business_members m
    where m.business_id = reservations.business_id and m.user_id = (select auth.uid())
  )
);

drop policy if exists "Partners update orders" on public.orders;
create policy "Partners update orders"
on public.orders for update
to authenticated
using (
  exists (
    select 1 from public.business_members m
    where m.business_id = orders.business_id and m.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.business_members m
    where m.business_id = orders.business_id and m.user_id = (select auth.uid())
  )
);

-- Order item isolation follows the parent order ownership.
alter table public.order_items enable row level security;
drop policy if exists "Users read own order items" on public.order_items;
create policy "Users read own order items"
on public.order_items for select
to authenticated
using (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and (select auth.uid()) = o.user_id
  )
);

drop policy if exists "Users create own order items" on public.order_items;
create policy "Users create own order items"
on public.order_items for insert
to authenticated
with check (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and (select auth.uid()) = o.user_id
  )
);

-- Server-side order creation: prices and availability come from the database,
-- not from values supplied by the client.
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
as $
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
begin
  if v_user is null then raise exception 'authentication required'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'order must contain at least one item';
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
        'quantity', v_quantity
      )
    );
  end loop;

  insert into public.orders(user_id, business_id, items, total, status, table_number, customer_note)
  values (v_user, p_business_id, v_normalized, v_total, 'placed', nullif(trim(p_table_number), ''), nullif(trim(p_customer_note), ''))
  returning public.orders.id into v_order_id;

  insert into public.order_items(order_id, menu_item_id, item_name, unit_price, quantity)
  select v_order_id,
         (x->>'menu_item_id')::uuid,
         x->>'name',
         (x->>'unit_price')::numeric,
         (x->>'quantity')::int
  from pg_catalog.jsonb_array_elements(v_normalized) x;

  id := v_order_id;
  total := v_total;
  status := 'placed';
  return next;
end;
$;

revoke execute on function public.create_food_order(uuid,jsonb,text,text) from public, anon;
grant execute on function public.create_food_order(uuid,jsonb,text,text) to authenticated;

drop policy if exists "Customers create orders" on public.orders;

-- Customer writes for reservations. Food orders must use the server-side RPC
-- above so the database, not the client, controls prices and availability.
create policy "Customers create reservations"
on public.reservations for insert
to authenticated
with check ((select auth.uid()) = user_id);


create policy "Customers delete own reservations"
on public.reservations for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy "Customers delete own orders"
on public.orders for delete
to authenticated
using ((select auth.uid()) = user_id);

-- Partners may manage daily room inventory for their own business.
drop policy if exists "Partners update room inventory" on public.room_inventory;
create policy "Partners update room inventory"
on public.room_inventory for update
to authenticated
using (
  exists (
    select 1
    from public.room_types rt
    join public.business_members m on m.business_id = rt.business_id
    where rt.id = room_inventory.room_type_id
      and m.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.room_types rt
    join public.business_members m on m.business_id = rt.business_id
    where rt.id = room_inventory.room_type_id
      and m.user_id = (select auth.uid())
  )
);

-- Customer review policy: a review must be tied to a completed FineTime interaction.
alter table public.reviews enable row level security;
drop policy if exists "Public read reviews" on public.reviews;
create policy "Public can read reviews"
on public.reviews for select
to anon, authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = reviews.business_id and b.is_published = true
  )
);

drop policy if exists "Customers create reviews" on public.reviews;
create policy "Customers create reviews"
on public.reviews for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and (
    exists (
      select 1 from public.bookings b
      where b.user_id = reviews.user_id
        and b.business_id = reviews.business_id
        and b.status = 'completed'
    )
    or exists (
      select 1 from public.reservations r
      where r.user_id = reviews.user_id
        and r.business_id = reviews.business_id
        and r.status = 'completed'
    )
    or exists (
      select 1 from public.orders o
      where o.user_id = reviews.user_id
        and o.business_id = reviews.business_id
        and o.status in ('delivered','completed')
    )
  )
);

-- Atomically validate hotel capacity and reserve inventory.
create or replace function public.request_hotel_booking(
  p_business_id uuid,
  p_room_type_id uuid,
  p_check_in date,
  p_check_out date,
  p_guests int
)
returns table(id uuid, reference text, status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_capacity int;
  v_total_rooms int;
  v_id uuid;
  v_reference text;
begin
  if v_user is null then
    raise exception 'authentication required';
  end if;
  if p_check_out <= p_check_in then
    raise exception 'check-out must be after check-in';
  end if;
  if p_guests < 1 then
    raise exception 'guest count must be at least 1';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_room_type_id::text, 0)
  );

  select rt.capacity, rt.total_rooms
    into v_capacity, v_total_rooms
  from public.room_types rt
  join public.businesses b on b.id = rt.business_id
  where rt.id = p_room_type_id
    and rt.business_id = p_business_id
    and b.category = 'hotel'
    and b.is_published = true
  for update;

  if not found then
    raise exception 'room type is not available';
  end if;

  if v_capacity is not null and p_guests > v_capacity then
    raise exception 'guest count exceeds room capacity';
  end if;

  if coalesce(v_total_rooms, 0) < 1 then
    raise exception 'hotel has no inventory configured for this room type';
  end if;

  insert into public.room_inventory(room_type_id, inventory_date, available_rooms)
  select p_room_type_id, gs::date, v_total_rooms
  from pg_catalog.generate_series(
    p_check_in,
    p_check_out - 1,
    interval '1 day'
  ) gs
  on conflict (room_type_id, inventory_date) do nothing;

  if exists (
    select 1
    from public.room_inventory ri
    where ri.room_type_id = p_room_type_id
      and ri.inventory_date >= p_check_in
      and ri.inventory_date < p_check_out
      and (ri.blocked or ri.available_rooms < 1)
  ) then
    raise exception 'room is unavailable for one or more selected dates';
  end if;

  update public.room_inventory
  set available_rooms = available_rooms - 1,
      updated_at = now()
  where room_type_id = p_room_type_id
    and inventory_date >= p_check_in
    and inventory_date < p_check_out;

  insert into public.bookings(
    user_id, business_id, room_type_id, check_in, check_out, guests
  )
  values (
    v_user, p_business_id, p_room_type_id, p_check_in, p_check_out, p_guests
  )
  returning public.bookings.id, public.bookings.reference, public.bookings.status
    into v_id, v_reference, status;

  id := v_id;
  reference := v_reference;
  return next;
end;
$$;

revoke execute on function public.request_hotel_booking(uuid,uuid,date,date,int) from public, anon;
grant execute on function public.request_hotel_booking(uuid,uuid,date,date,int) to authenticated;

-- Restore room inventory when a requested/confirmed booking is cancelled.
create or replace function public.restore_cancelled_booking_inventory()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status is distinct from 'cancelled' and new.status = 'cancelled' then
    update public.room_inventory
    set available_rooms = available_rooms + 1,
        updated_at = now()
    where room_type_id = new.room_type_id
      and inventory_date >= new.check_in
      and inventory_date < new.check_out;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_restore_cancelled_booking_inventory on public.bookings;
create trigger trg_restore_cancelled_booking_inventory
after update of status on public.bookings
for each row execute function public.restore_cancelled_booking_inventory();

-- Operational state changes become customer notifications.
create or replace function public.notify_booking_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.notifications(user_id,type,title,body,reference_type,reference_id)
    values (new.user_id,'booking_submitted','Booking submitted',
      'Your hotel booking request has been submitted.','booking',new.id);
  elsif old.status is distinct from new.status then
    insert into public.notifications(user_id,type,title,body,reference_type,reference_id)
    values (
      new.user_id,
      'booking_' || new.status,
      'Booking ' || initcap(new.status),
      'Your hotel booking status is now ' || initcap(new.status) || '.',
      'booking',new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_booking_notifications on public.bookings;
create trigger trg_booking_notifications
after insert or update of status on public.bookings
for each row execute function public.notify_booking_change();

create or replace function public.notify_reservation_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.notifications(user_id,type,title,body,reference_type,reference_id)
    values (new.user_id,'reservation_submitted','Reservation submitted',
      'Your table reservation request has been submitted.','reservation',new.id);
  elsif old.status is distinct from new.status then
    insert into public.notifications(user_id,type,title,body,reference_type,reference_id)
    values (
      new.user_id,
      'reservation_' || new.status,
      'Reservation ' || initcap(new.status),
      'Your table reservation status is now ' || initcap(new.status) || '.',
      'reservation',new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_reservation_notifications on public.reservations;
create trigger trg_reservation_notifications
after insert or update of status on public.reservations
for each row execute function public.notify_reservation_change();

create or replace function public.notify_order_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.notifications(user_id,type,title,body,reference_type,reference_id)
    values (new.user_id,'order_received','Order received',
      'Your food order was sent to the business.','order',new.id);
  elsif old.status is distinct from new.status then
    insert into public.notifications(user_id,type,title,body,reference_type,reference_id)
    values (
      new.user_id,
      'order_' || new.status,
      'Order ' || initcap(new.status),
      'Your order status is now ' || initcap(new.status) || '.',
      'order',new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_order_notifications on public.orders;
create trigger trg_order_notifications
after insert or update of status on public.orders
for each row execute function public.notify_order_change();

-- Do not expose partner credentials/codes through the client Data API.
alter table public.activation_codes enable row level security;
alter table public.telegram_connections enable row level security;
alter table public.partner_business_members enable row level security;
revoke all on public.partner_business_members from anon, authenticated;
drop policy if exists "No client activation code access" on public.activation_codes;
drop policy if exists "No client telegram connection access" on public.telegram_connections;

-- Explicitly prevent anonymous access to private operational tables.
revoke all on public.notifications from anon;
revoke all on public.business_members from anon;
revoke all on public.activation_codes from anon, authenticated;
revoke all on public.telegram_connections from anon, authenticated;

-- Keep authenticated customers able to submit their own reservations/orders.
-- Partner updates are already restricted above.
