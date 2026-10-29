alter table public.orders
  add column if not exists listing_id text,
  add column if not exists product_id bigint references public.products(id);

alter table public.orders
  add column if not exists owner_id uuid
    references auth.users(id) on delete set null;

create index if not exists orders_owner_id_created_at_idx
  on public.orders (owner_id, created_at desc);

alter table public.orders enable row level security;
revoke all on public.orders from anon, authenticated;
grant select on public.orders to authenticated;

drop policy if exists "Owners read their orders" on public.orders;
create policy "Owners read their orders"
  on public.orders for select to authenticated
  using (owner_id = (select auth.uid()));

notify pgrst, 'reload schema';