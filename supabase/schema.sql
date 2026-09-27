-- Run in Supabase SQL editor
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null,
  phone text,
  photo_url text,
  created_at timestamptz default now()
);

create table cities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  region text,
  is_live boolean default false
);

create table businesses (
  id uuid primary key default gen_random_uuid(),
  city_id uuid references cities(id),
  name text not null,
  category text check (category in ('hotel','restaurant','cafe')) not null,
  about text,
  highlights text[],
  amenities text[],
  phone text,
  lat double precision,
  lng double precision,
  opening_hours jsonb,
  cover_url text,
  gallery_urls text[],
  is_published boolean default false,
  created_at timestamptz default now()
);

create table menu_categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references businesses(id) on delete cascade,
  name text not null, sort_order int default 0
);

create table menu_items (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references menu_categories(id) on delete cascade,
  name text not null,
  description text,
  price numeric(10,2),
  photo_url text,
  is_available boolean default true
);

create table room_types (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references businesses(id) on delete cascade,
  name text not null,
  description text,
  capacity int, beds text, amenities text[],
  photo_url text,
  public_price numeric(10,2),       -- null = "Contact hotel for current rate"
  total_rooms int default 0
);

create table bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id),
  business_id uuid references businesses(id),
  room_type_id uuid references room_types(id),
  check_in date not null,
  check_out date not null,
  guests int not null,
  status text check (status in ('requested','confirmed','changed','cancelled','completed')) default 'requested',
  reference text unique default 'FT-' || upper(substr(md5(random()::text),1,8)),
  created_at timestamptz default now()
);

create table reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id),
  business_id uuid references businesses(id),
  reservation_date date not null,
  reservation_time time not null,
  party_size int not null,
  contact_phone text,
  special_request text,
  status text check (status in ('requested','confirmed','changed','cancelled','completed')) default 'requested',
  created_at timestamptz default now()
);

create table promotions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references businesses(id) on delete cascade,
  title text not null, description text,
  badge text check (badge in ('25% OFF','TODAY','NEW','FEATURED','LIMITED','FINE TIME PICK')),
  image_url text, terms text,
  starts_on date, ends_on date,
  status text default 'active'
);

create table saved_places (
  user_id uuid references profiles(id),
  business_id uuid references businesses(id),
  created_at timestamptz default now(),
  primary key (user_id, business_id)
);

create table orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id),
  business_id uuid references businesses(id),
  items jsonb not null,
  total numeric(10,2),
  status text check (status in ('placed','confirmed','preparing','ready','delivered','cancelled')) default 'placed',
  created_at timestamptz default now()
);

-- Availability guard: prevents overbooking server-side
create or replace function check_room_availability()
returns trigger as $$
declare remaining int;
begin
  select rt.total_rooms - coalesce((
    select count(*) from bookings b
    where b.room_type_id = new.room_type_id
      and b.status in ('requested','confirmed')
      and daterange(b.check_in, b.check_out) && daterange(new.check_in, new.check_out)
  ),0) into remaining;
  if remaining < 1 then
    raise exception 'No rooms available for these dates';
  end if;
  return new;
end $$ language plpgsql;

create trigger booking_availability before insert on bookings
for each row execute function check_room_availability();

-- RLS
alter table profiles enable row level security;
alter table bookings enable row level security;
alter table reservations enable row level security;
alter table saved_places enable row level security;
alter table orders enable row level security;
create policy "own profile" on profiles for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "own bookings" on bookings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own reservations" on reservations for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own saved" on saved_places for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own orders" on orders for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- Public catalog tables (businesses, cities, menus, room_types, promotions) are open reads; add is_published policies in production.
