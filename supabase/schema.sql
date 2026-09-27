-- FineTime Supabase schema (matches production database)

create table if not exists profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null,
  phone text,
  photo_url text,
  created_at timestamptz default now()
);

create table if not exists cities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  region text,
  is_live boolean default false
);

create table if not exists businesses (
  id uuid primary key default gen_random_uuid(),
  city_id uuid references cities(id) on delete set null,
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

create table if not exists menu_categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references businesses(id) on delete cascade,
  name text not null,
  sort_order int default 0
);

create table if not exists menu_items (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references menu_categories(id) on delete cascade,
  name text not null,
  description text,
  price numeric(10,2),
  photo_url text,
  is_available boolean default true
);

create table if not exists room_types (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references businesses(id) on delete cascade,
  name text not null,
  description text,
  capacity int,
  beds text,
  amenities text[],
  photo_url text,
  public_price numeric(10,2),
  total_rooms int default 0
);

create or replace function generate_booking_reference()
returns text as $$
begin
  return 'FT-' || upper(substr(md5(random()::text), 1, 8));
end;
$$ language plpgsql;

create table if not exists bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  business_id uuid references businesses(id) on delete cascade,
  room_type_id uuid references room_types(id) on delete set null,
  check_in date not null,
  check_out date not null,
  guests int not null,
  status text check (status in ('requested','confirmed','changed','cancelled','completed')) default 'requested',
  reference text unique default generate_booking_reference(),
  created_at timestamptz default now()
);

create table if not exists reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  business_id uuid references businesses(id) on delete cascade,
  reservation_date date not null,
  reservation_time time not null,
  party_size int not null,
  contact_phone text,
  special_request text,
  status text check (status in ('requested','confirmed','changed','cancelled','completed')) default 'requested',
  created_at timestamptz default now()
);

create table if not exists promotions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references businesses(id) on delete cascade,
  title text not null,
  description text,
  badge text check (badge in ('25% OFF','TODAY','NEW','FEATURED','LIMITED','FINE TIME PICK')),
  image_url text,
  terms text,
  starts_on date,
  ends_on date,
  status text default 'active'
);

create table if not exists saved_places (
  user_id uuid references profiles(id) on delete cascade,
  business_id uuid references businesses(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, business_id)
);

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  business_id uuid references businesses(id) on delete cascade,
  items jsonb not null,
  total numeric(10,2),
  status text check (status in ('placed','confirmed','preparing','ready','delivered','cancelled')) default 'placed',
  created_at timestamptz default now()
);

-- ===== ROW LEVEL SECURITY =====

alter table profiles enable row level security;
alter table bookings enable row level security;
alter table reservations enable row level security;
alter table saved_places enable row level security;
alter table orders enable row level security;
alter table cities enable row level security;
alter table businesses enable row level security;
alter table menu_categories enable row level security;
alter table menu_items enable row level security;
alter table room_types enable row level security;
alter table promotions enable row level security;

drop policy if exists "Allow public read on cities" on cities;
create policy "Allow public read on cities" on cities for select using (true);

drop policy if exists "Allow public read on businesses" on businesses;
create policy "Allow public read on businesses" on businesses for select using (is_published = true);

drop policy if exists "Allow public read on menu_categories" on menu_categories;
create policy "Allow public read on menu_categories" on menu_categories for select using (true);

drop policy if exists "Allow public read on menu_items" on menu_items;
create policy "Allow public read on menu_items" on menu_items for select using (true);

drop policy if exists "Allow public read on room_types" on room_types;
create policy "Allow public read on room_types" on room_types for select using (true);

drop policy if exists "Allow public read on promotions" on promotions;
create policy "Allow public read on promotions" on promotions for select using (true);

drop policy if exists "own profile" on profiles;
create policy "own profile" on profiles for all using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "own bookings" on bookings;
create policy "own bookings" on bookings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own reservations" on reservations;
create policy "own reservations" on reservations for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own saved" on saved_places;
create policy "own saved" on saved_places for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own orders" on orders;
create policy "own orders" on orders for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ===== SEED DATA =====

insert into cities (name, region, is_live) values
  ('Addis Ababa', 'Addis Ababa', true),
  ('Bahir Dar', 'Amhara', true),
  ('Hawassa', 'Sidama', true)
on conflict (name) do nothing;

insert into businesses (name, city_id, category, about, is_published)
select 'Sheraton Addis', id, 'hotel', 'Luxury hotel in the heart of Addis Ababa.', true
from cities where name = 'Addis Ababa'
and not exists (select 1 from businesses where name = 'Sheraton Addis');

insert into businesses (name, city_id, category, about, is_published)
select 'Skylight Hotel', id, 'hotel', 'Ethiopian Airlines flagship hotel near Bole Airport.', true
from cities where name = 'Addis Ababa'
and not exists (select 1 from businesses where name = 'Skylight Hotel');

insert into businesses (name, city_id, category, about, is_published)
select 'Kategna Restaurant', id, 'restaurant', 'Traditional Ethiopian cuisine, popular with locals.', true
from cities where name = 'Addis Ababa'
and not exists (select 1 from businesses where name = 'Kategna Restaurant');

insert into businesses (name, city_id, category, about, is_published)
select 'Kuriftu Resort', id, 'hotel', 'Lake Tana waterfront resort.', true
from cities where name = 'Bahir Dar'
and not exists (select 1 from businesses where name = 'Kuriftu Resort');

insert into businesses (name, city_id, category, about, is_published)
select 'Haile Resort', id, 'hotel', 'Lakeside resort on Lake Hawassa.', true
from cities where name = 'Hawassa'
and not exists (select 1 from businesses where name = 'Haile Resort');
