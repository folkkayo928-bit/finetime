create or replace function public.admin_save_business(
  p_business_id uuid,
  p_business jsonb,
  p_profile jsonb,
  p_subscription jsonb
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_id uuid := p_business_id;
begin
  if not public.is_finetime_admin() then
    raise exception 'Admin access required';
  end if;
  if v_id is null then raise exception 'Business id is required for edit'; end if;

  update public.businesses
  set
    name = coalesce(nullif(trim(p_business->>'name'), ''), name),
    category = coalesce(nullif(trim(p_business->>'category'), ''), category),
    city_id = case when p_business ? 'city_id' then nullif(p_business->>'city_id','')::uuid else city_id end,
    about = case when p_business ? 'about' then nullif(p_business->>'about','') else about end,
    is_published = case when p_business ? 'is_published' then (p_business->>'is_published')::boolean else is_published end,
    phone = case when p_business ? 'phone' then nullif(p_business->>'phone','') else phone end,
    lat = case when p_business ? 'lat' and nullif(p_business->>'lat','') is not null then (p_business->>'lat')::double precision when p_business ? 'lat' then null else lat end,
    lng = case when p_business ? 'lng' and nullif(p_business->>'lng','') is not null then (p_business->>'lng')::double precision when p_business ? 'lng' then null else lng end,
    opening_hours = case when p_business ? 'opening_hours' then coalesce(p_business->'opening_hours','{}'::jsonb) else opening_hours end,
    cover_url = case when p_business ? 'cover_url' then nullif(p_business->>'cover_url','') else cover_url end,
    gallery_urls = case when p_business ? 'gallery_urls' then array(select jsonb_array_elements_text(coalesce(p_business->'gallery_urls','[]'::jsonb))) else gallery_urls end,
    services = case when p_business ? 'services' then array(select jsonb_array_elements_text(coalesce(p_business->'services','[]'::jsonb))) else services end,
    highlights = case when p_business ? 'highlights' then array(select jsonb_array_elements_text(coalesce(p_business->'highlights','[]'::jsonb))) else highlights end,
    amenities = case when p_business ? 'amenities' then array(select jsonb_array_elements_text(coalesce(p_business->'amenities','[]'::jsonb))) else amenities end
  where id = v_id;

  if not found then raise exception 'Business record not found'; end if;

  insert into public.business_admin_profiles(
    business_id, menu_slug, tagline, currency, address, logo_url,
    owner_name, owner_email, onboarding_status, payment_status
  )
  values (
    v_id, nullif(trim(p_profile->>'menu_slug'),''), nullif(trim(p_profile->>'tagline'),''),
    coalesce(nullif(trim(p_profile->>'currency'),''),'ETB'), nullif(trim(p_profile->>'address'),''),
    nullif(trim(p_profile->>'logo_url'),''), nullif(trim(p_profile->>'owner_name'),''),
    nullif(trim(p_profile->>'owner_email'),''), coalesce(nullif(trim(p_profile->>'onboarding_status'),''),'pending'),
    coalesce(nullif(trim(p_profile->>'payment_status'),''),'trial')
  )
  on conflict (business_id) do update set
    menu_slug=excluded.menu_slug,tagline=excluded.tagline,currency=excluded.currency,
    address=excluded.address,logo_url=excluded.logo_url,owner_name=excluded.owner_name,
    owner_email=excluded.owner_email,onboarding_status=excluded.onboarding_status,payment_status=excluded.payment_status;

  insert into public.business_subscriptions(
    business_id, plan, status, monthly_price, starts_on, ends_on, notes
  )
  values (
    v_id, coalesce(nullif(trim(p_subscription->>'plan'),''),'basic'),
    coalesce(nullif(trim(p_subscription->>'status'),''),'active'),
    case when nullif(p_subscription->>'monthly_price','') is null then null else (p_subscription->>'monthly_price')::numeric end,
    case when nullif(p_subscription->>'starts_on','') is null then null else (p_subscription->>'starts_on')::date end,
    case when nullif(p_subscription->>'ends_on','') is null then null else (p_subscription->>'ends_on')::date end,
    nullif(trim(p_subscription->>'notes'),'')
  )
  on conflict (business_id) do update set
    plan=excluded.plan,status=excluded.status,monthly_price=excluded.monthly_price,
    starts_on=excluded.starts_on,ends_on=excluded.ends_on,notes=excluded.notes;

  return v_id;
end;
$$;

revoke all on function public.admin_save_business(uuid,jsonb,jsonb,jsonb) from public;
grant execute on function public.admin_save_business(uuid,jsonb,jsonb,jsonb) to authenticated;