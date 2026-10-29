  insert into storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
  )
  values (
    'listing-images',
    'listing-images',
    true,
    52428800,
    array['image/jpeg', 'image/png', 'image/webp', 'image/gif']::text[]
  )
  on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

  drop policy if exists "Public can read listing images" on storage.objects;
  create policy "Public can read listing images"
    on storage.objects for select to anon, authenticated
    using (bucket_id = 'listing-images');

  drop policy if exists "Public can upload listing images" on storage.objects;
  create policy "Public can upload listing images"
    on storage.objects for insert to anon, authenticated
    with check (bucket_id = 'listing-images');
