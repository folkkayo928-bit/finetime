-- Remove the temporary duplicate review INSERT policy introduced during hardening.
drop policy if exists "Customers can create eligible reviews" on public.reviews;
