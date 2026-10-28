create table if not exists public.rental_listings (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 100),
  category text not null,
  owner_name text not null,
  location text not null check (char_length(trim(location)) between 1 and 120),
  description text not null default '',
  condition text not null default 'Not specified',
  price_per_day numeric not null
    check (price_per_day > 0 and price_per_day <= 1000000 and price_per_day = trunc(price_per_day)),
  deposit numeric not null default 0
    check (deposit >= 0 and deposit <= 10000000 and deposit = trunc(deposit)),
  available boolean not null default true,
  rules jsonb not null default '[]'::jsonb
    check (jsonb_typeof(rules) = 'array'),
  image_url text,
  created_at timestamptz not null default now()
);

alter table public.rental_listings enable row level security;

grant select, insert on public.rental_listings to anon, authenticated;

drop policy if exists "Allow public read access on rental listings"
  on public.rental_listings;
create policy "Allow public read access on rental listings"
  on public.rental_listings for select to anon, authenticated using (true);

drop policy if exists "Allow public listing creation"
  on public.rental_listings;
create policy "Allow public listing creation"
  on public.rental_listings for insert to anon, authenticated
  with check (
    char_length(trim(name)) between 1 and 100
    and char_length(trim(location)) between 1 and 120
    and price_per_day > 0
    and deposit >= 0
    and jsonb_typeof(rules) = 'array'
  );
