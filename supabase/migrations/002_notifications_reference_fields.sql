-- FineTime notification compatibility fix.
-- Production may already have notifications without reference columns.
-- Add the columns required by the booking/reservation/order notification triggers.

alter table public.notifications
  add column if not exists reference_type text;

alter table public.notifications
  add column if not exists reference_id uuid;

create index if not exists notifications_reference_idx
  on public.notifications(reference_type, reference_id);
