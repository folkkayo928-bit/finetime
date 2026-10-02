# FineTime — Discover. Dine. Stay.

FineTime is an Ethiopia-focused hospitality discovery and booking platform connecting guests with hotels, restaurants, and cafés.

## Core Features & Business Logic

- **Discover & Explore**:
  - Live discovery feed with featured places, real-time promotional banners, and admin site modules.
  - Category filtering across Hotels, Restaurants, and Cafés with city filtering.
  - Real-time search across published businesses with live debounce.
- **Detailed Business Profile**:
  - Cover banners and horizontal gallery previews.
  - Operating hours, location details with map deep links, and direct phone contact.
  - Highlights, amenities, and hotel room types with real-time room inventory availability checks.
  - Digital restaurant/café menus with QR code integration.
  - Customer review display, aggregated rating calculation, and verified-experience review submission guards.
- **Stays & Bookings**:
  - Room type selection, check-in and check-out date picker with night count and total ETB calculation.
  - Authoritative hotel booking request flow via Supabase Edge Functions with reference tracking.
- **Table Reservations**:
  - Date, time, party size, contact phone auto-fill from user profile, and special requests.
- **Digital Food Ordering**:
  - Interactive multi-item cart calculation, dine-in table number specification, and custom order notes.
- **Trips & Saved Places**:
  - Segregated Upcoming, Active, and Past history for hotel stays, table reservations, and food orders.
  - Bookmark favorite businesses with quick profile navigation.
- **Account & Security**:
  - Full guest exploration mode with zero friction.
  - Profile management (name, contact phone), secure authentication, and unread notification tracking.

## Backend & Integration

- Powered by Supabase Auth, PostgreSQL with Row Level Security (RLS), and Realtime Postgres change channels.
- Authoritative Edge Functions:
  - `request-hotel-booking`
  - `request-restaurant-reservation`
  - `create-food-order`
  - `partner-api`
- Connected to live backend at `https://atewcbkuzrnfnmzsylze.supabase.co`.
