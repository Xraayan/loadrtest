create table if not exists public.driver_profiles (
  driver_uid text primary key references public.profiles(firebase_uid) on delete cascade,
  vehicle_number text,
  selected_vehicle_type text,
  license_status text default 'pending',
  preferences jsonb not null default '{}'::jsonb,
  current_status text default 'offline',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_profiles (
  customer_uid text primary key references public.profiles(firebase_uid) on delete cascade,
  business_name text,
  current_location jsonb,
  saved_locations jsonb not null default '[]'::jsonb,
  preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_driver_profiles_vehicle_type
  on public.driver_profiles(selected_vehicle_type);

create index if not exists idx_profiles_role
  on public.profiles(role);

insert into public.driver_profiles (
  driver_uid,
  selected_vehicle_type,
  preferences,
  updated_at
)
select
  firebase_uid,
  preferences->>'selected_vehicle_type',
  coalesce(preferences, '{}'::jsonb),
  now()
from public.profiles
where role = 'driver'
on conflict (driver_uid) do update set
  selected_vehicle_type = coalesce(
    excluded.selected_vehicle_type,
    public.driver_profiles.selected_vehicle_type
  ),
  preferences = case
    when excluded.preferences <> '{}'::jsonb then excluded.preferences
    else public.driver_profiles.preferences
  end,
  updated_at = now();

insert into public.customer_profiles (
  customer_uid,
  current_location,
  updated_at
)
select
  firebase_uid,
  preferences->'customer_location',
  now()
from public.profiles
where role = 'user'
on conflict (customer_uid) do update set
  current_location = coalesce(
    excluded.current_location,
    public.customer_profiles.current_location
  ),
  updated_at = now();
