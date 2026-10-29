alter table public.rental_listings
  add column if not exists owner_id uuid
    references auth.users(id) on delete set null;

create index if not exists rental_listings_owner_id_idx
  on public.rental_listings (owner_id);

grant select, insert, delete on public.rental_listings to authenticated;
grant select, insert, delete on public.listing_images to authenticated;
revoke insert, delete on public.rental_listings from anon;
revoke insert, delete on public.listing_images from anon;

drop policy if exists "Allow public listing creation"
  on public.rental_listings;
drop policy if exists "Authenticated users create their listings"
  on public.rental_listings;
create policy "Authenticated users create their listings"
  on public.rental_listings for insert to authenticated
  with check (owner_id = (select auth.uid()));

drop policy if exists "Owners delete their listings"
  on public.rental_listings;
create policy "Owners delete their listings"
  on public.rental_listings for delete to authenticated
  using (owner_id = (select auth.uid()));

drop policy if exists "Public can add listing images"
  on public.listing_images;
drop policy if exists "Owners add listing images"
  on public.listing_images;
create policy "Owners add listing images"
  on public.listing_images for insert to authenticated
  with check (
    exists (
      select 1
      from public.rental_listings
      where id = listing_id
        and owner_id = (select auth.uid())
    )
  );

drop policy if exists "Owners delete listing images"
  on public.listing_images;
create policy "Owners delete listing images"
  on public.listing_images for delete to authenticated
  using (
    exists (
      select 1
      from public.rental_listings
      where id = listing_id
        and owner_id = (select auth.uid())
    )
  );

drop policy if exists "Public can upload listing images" on storage.objects;
drop policy if exists "Listing owners upload listing images" on storage.objects;
create policy "Listing owners upload listing images"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'listing-images'
    and split_part(name, '/', 2) = (select auth.uid())::text
  );

drop policy if exists "Listing owners delete listing images" on storage.objects;
create policy "Listing owners delete listing images"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'listing-images'
    and exists (
      select 1
      from public.listing_images
      join public.rental_listings
        on rental_listings.id = listing_images.listing_id
      where listing_images.storage_path = storage.objects.name
        and rental_listings.owner_id = (select auth.uid())
    )
  );

notify pgrst, 'reload schema';