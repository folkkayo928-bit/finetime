-- FineTime status-transition guards.
create or replace function public.guard_booking_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if old.status = new.status then return new; end if;
  if not (
    (old.status = 'requested' and new.status in ('confirmed','changed','cancelled'))
    or (old.status = 'confirmed' and new.status in ('changed','cancelled','completed'))
    or (old.status = 'changed' and new.status in ('confirmed','cancelled'))
  ) then
    raise exception 'invalid booking status transition: % -> %', old.status, new.status;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_guard_booking_status_transition on public.bookings;
create trigger trg_guard_booking_status_transition
before update of status on public.bookings
for each row execute function public.guard_booking_status_transition();

create or replace function public.guard_reservation_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if old.status = new.status then return new; end if;
  if not (
    (old.status = 'requested' and new.status in ('confirmed','changed','cancelled'))
    or (old.status = 'confirmed' and new.status in ('changed','cancelled','completed'))
    or (old.status = 'changed' and new.status in ('confirmed','cancelled'))
  ) then
    raise exception 'invalid reservation status transition: % -> %', old.status, new.status;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_guard_reservation_status_transition on public.reservations;
create trigger trg_guard_reservation_status_transition
before update of status on public.reservations
for each row execute function public.guard_reservation_status_transition();

create or replace function public.guard_order_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if old.status = new.status then return new; end if;
  if not (
    (old.status = 'placed' and new.status in ('confirmed','cancelled'))
    or (old.status = 'confirmed' and new.status in ('preparing','cancelled'))
    or (old.status = 'preparing' and new.status in ('ready','cancelled'))
    or (old.status = 'ready' and new.status in ('delivered','cancelled'))
  ) then
    raise exception 'invalid order status transition: % -> %', old.status, new.status;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_guard_order_status_transition on public.orders;
create trigger trg_guard_order_status_transition
before update of status on public.orders
for each row execute function public.guard_order_status_transition();
