-- PSG Padmashree Garments — Row-Level Security (RLS)
--
-- Defence-in-depth: even though the app enforces permissions in the UI, the
-- cloud enforces them too, so a compromised or modified client can never exceed
-- its role. Roles: 'owner' (full access) and 'staff' (billing + lookups only).
--
-- All access requires an authenticated session (auth.uid()). The acting user's
-- role is read from public.users.

-- ---------------------------------------------------------------------------
-- Helper: role of the currently authenticated user.
-- SECURITY DEFINER so the lookup itself isn't blocked by RLS on users.
-- ---------------------------------------------------------------------------
create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.users where id = auth.uid() and is_active and not is_deleted;
$$;

create or replace function public.is_owner()
returns boolean
language sql
stable
as $$
  select public.current_user_role() = 'owner';
$$;

create or replace function public.is_authenticated_staff()
returns boolean
language sql
stable
as $$
  select public.current_user_role() in ('owner', 'staff');
$$;

-- ---------------------------------------------------------------------------
-- Enable RLS on every table.
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'users','app_settings','products','inventory','inventory_movements',
    'customers','bills','bill_items'
  ] loop
    execute format('alter table public.%I enable row level security;', t);
  end loop;
end$$;

-- ---------------------------------------------------------------------------
-- OWNER: full access to everything.
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'users','app_settings','products','inventory','inventory_movements',
    'customers','bills','bill_items'
  ] loop
    execute format(
      'create policy owner_all on public.%I
         for all to authenticated
         using (public.is_owner()) with check (public.is_owner());', t);
  end loop;
end$$;

-- ---------------------------------------------------------------------------
-- STAFF / CASHIER: scoped permissions.
-- Read-only on catalog & stock; create (but not delete) bills, items,
-- customers and stock movements. No access to users/settings (owner-only).
-- ---------------------------------------------------------------------------

-- Read catalog, inventory and customers.
create policy staff_read_products on public.products
  for select to authenticated using (public.is_authenticated_staff());
create policy staff_read_inventory on public.inventory
  for select to authenticated using (public.is_authenticated_staff());
create policy staff_read_customers on public.customers
  for select to authenticated using (public.is_authenticated_staff());

-- Create customers (e.g. capture a phone at checkout).
create policy staff_insert_customers on public.customers
  for insert to authenticated with check (public.is_authenticated_staff());

-- Create bills and their line items.
create policy staff_read_bills on public.bills
  for select to authenticated using (public.is_authenticated_staff());
create policy staff_insert_bills on public.bills
  for insert to authenticated with check (public.is_authenticated_staff());

create policy staff_read_bill_items on public.bill_items
  for select to authenticated using (public.is_authenticated_staff());
create policy staff_insert_bill_items on public.bill_items
  for insert to authenticated with check (public.is_authenticated_staff());

-- Record stock movements (a sale decrements stock via the ledger).
create policy staff_read_moves on public.inventory_movements
  for select to authenticated using (public.is_authenticated_staff());
create policy staff_insert_moves on public.inventory_movements
  for insert to authenticated with check (public.is_authenticated_staff());

-- Voiding/updating a bill is allowed for staff who created it; deletes are not
-- (history is preserved via soft delete + the owner policy).
create policy staff_update_own_bills on public.bills
  for update to authenticated
  using (public.is_authenticated_staff() and cashier_id = auth.uid())
  with check (public.is_authenticated_staff() and cashier_id = auth.uid());

-- NOTE: products, app_settings, users have NO staff policies, so staff cannot
-- write them at all — only the owner_all policy applies. Staff also cannot
-- delete any row (no staff DELETE policies exist).
