alter table public.orders
  add column if not exists rental_status text not null default 'Pending'
    check (rental_status in ('Pending', 'Confirmed', 'Completed', 'Refund requested')),
  add column if not exists activity_hidden boolean not null default false,
  add column if not exists review_rating smallint
    check (review_rating between 1 and 5),
  add column if not exists review_comment text;

revoke update on public.orders from anon, authenticated;
grant update (rental_status, activity_hidden, review_rating, review_comment)
  on public.orders to authenticated;

drop policy if exists "Owners update their order activity" on public.orders;
create policy "Owners update their order activity"
  on public.orders for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

notify pgrst, 'reload schema';