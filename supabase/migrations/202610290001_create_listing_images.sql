create table if not exists public.rental_listings (
	id uuid primary key default gen_random_uuid(),
	name text not null check (char_length(trim(name)) between 1 and 100),
	category text not null,
	owner_name text not null,
	location text not null check (char_length(trim(location)) between 1 and 120),
	description text not null default '',
	condition text not null default 'Not specified',
	price_per_day numeric not null
		check (
			price_per_day > 0
			and price_per_day <= 1000000
			and price_per_day = trunc(price_per_day)
		),
	deposit numeric not null default 0
		check (
			deposit >= 0
			and deposit <= 10000000
			and deposit = trunc(deposit)
		),
	available boolean not null default true,
	rules jsonb not null default '[]'::jsonb
		check (jsonb_typeof(rules) = 'array'),
	image_url text,
	created_at timestamptz not null default now()
);

create table if not exists public.listing_images (
	id uuid primary key default gen_random_uuid(),
	listing_id uuid not null
		references public.rental_listings(id) on delete cascade,
	image_url text not null,
	storage_path text not null,
	position integer not null default 0 check (position >= 0),
	created_at timestamptz not null default now(),
	unique (listing_id, storage_path)
);

create index if not exists listing_images_listing_position_idx
	on public.listing_images (listing_id, position);

alter table public.rental_listings enable row level security;
alter table public.listing_images enable row level security;

grant select, insert on public.rental_listings to anon, authenticated;
grant select, insert on public.listing_images to anon, authenticated;

drop policy if exists "Allow public read access on rental listings"
	on public.rental_listings;
create policy "Allow public read access on rental listings"
	on public.rental_listings for select to anon, authenticated
	using (true);

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

drop policy if exists "Public can read listing images"
	on public.listing_images;
create policy "Public can read listing images"
	on public.listing_images for select to anon, authenticated
	using (true);

drop policy if exists "Public can add listing images"
	on public.listing_images;
create policy "Public can add listing images"
	on public.listing_images for insert to anon, authenticated
	with check (
		exists (
			select 1
			from public.rental_listings
			where id = listing_id
		)
	);
