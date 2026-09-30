# FineTime

FineTime — Discover. Dine. Stay. Ethiopia hospitality platform (Flutter + Supabase).

## Live web entry points

- Customer app: https://folkkayo928-bit.github.io/finetime/
- Public website: https://folkkayo928-bit.github.io/finetime/website/
- News: https://folkkayo928-bit.github.io/finetime/website/news.html
- Partner Mini App: https://folkkayo928-bit.github.io/finetime/partner.html
- Admin console: https://folkkayo928-bit.github.io/finetime/admin/

## CI/CD

GitHub Actions builds and publishes the Flutter web app and packages the public website, Partner Mini App and admin console for GitHub Pages. A separate Android workflow builds an installable debug APK artifact.

The browser receives only the configured Supabase project URL and publishable/anon key. Server-side credentials and Telegram secrets stay in Supabase Edge Functions.

## Admin setup

The admin console requires a Supabase Auth user whose UUID is present in `public.admin_memberships` with role `admin`. Admin authorization is enforced by database RLS; the browser cannot grant itself admin access.

No production/demo records are seeded by the application or deployment workflows.
