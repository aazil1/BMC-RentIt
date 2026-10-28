insert into storage.buckets (id, name, public)
values ('listing-images', 'listing-images', true)
on conflict (id) do update set public = true;

drop policy if exists "Public can read listing images" on storage.objects;
create policy "Public can read listing images"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'listing-images');

drop policy if exists "Public can upload listing images" on storage.objects;
create policy "Public can upload listing images"
  on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'listing-images');
