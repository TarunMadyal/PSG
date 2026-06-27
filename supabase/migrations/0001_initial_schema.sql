-- PSG Padmashree Garments — cloud schema (Supabase / PostgreSQL)
-- Mirrors the on-device Drift/SQLite schema so the sync engine can upsert rows
-- 1:1. Enums are stored as TEXT (matching the local `textEnum` storage) with
-- CHECK constraints. Money is integer paise. Every table carries the sync
-- metadata columns (updated_at drives delta sync; is_deleted is a soft delete).

-- gen_random_uuid()
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Shared trigger: keep updated_at fresh on every write (sync high-water mark).
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- users — staff/owner accounts (id matches Supabase auth.users.id for real
-- logins; role drives RLS).
-- ---------------------------------------------------------------------------
create table if not exists public.users (
  id            uuid primary key default gen_random_uuid(),
  name          text        not null,
  role          text        not null default 'staff' check (role in ('owner', 'staff')),
  phone         text,
  email         text,
  pin_hash      text,
  password_hash text,
  is_active     boolean     not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  version       integer     not null default 1,
  is_deleted    boolean     not null default false,
  device_id     text
);

create table if not exists public.app_settings (
  id              uuid primary key default gen_random_uuid(),
  shop_name       text        not null default 'PSG Padmashree Garments',
  address         text,
  phone           text,
  receipt_width   integer     not null default 80,
  footer_text     text,
  printer_name    text,
  printer_address text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  version         integer     not null default 1,
  is_deleted      boolean     not null default false,
  device_id       text
);

create table if not exists public.products (
  id          uuid primary key default gen_random_uuid(),
  name        text        not null,
  category    text,
  brand       text,
  size        text,
  color       text,
  price_paise bigint      not null default 0,
  is_active   boolean     not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  version     integer     not null default 1,
  is_deleted  boolean     not null default false,
  device_id   text
);

create table if not exists public.customers (
  id         uuid primary key default gen_random_uuid(),
  name       text,
  phone      text,
  notes      text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version    integer     not null default 1,
  is_deleted boolean     not null default false,
  device_id  text
);

create table if not exists public.bills (
  id               uuid primary key default gen_random_uuid(),
  invoice_no       text        not null,
  customer_id      uuid        references public.customers (id),
  cashier_id       uuid        not null references public.users (id),
  subtotal_paise   bigint      not null default 0,
  discount_paise   bigint      not null default 0,
  gst_paise        bigint      not null default 0,
  grand_total_paise bigint     not null default 0,
  payment_method   text        not null check (payment_method in ('cash', 'card', 'upi', 'other')),
  status           text        not null default 'completed' check (status in ('completed', 'voided')),
  billed_at        timestamptz not null default now(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  version          integer     not null default 1,
  is_deleted       boolean     not null default false,
  device_id        text
);

create table if not exists public.bill_items (
  id             uuid primary key default gen_random_uuid(),
  bill_id        uuid        not null references public.bills (id),
  product_id     uuid        not null references public.products (id),
  name_snapshot  text        not null,
  qty            integer     not null default 1,
  rate_paise     bigint      not null default 0,
  discount_paise bigint      not null default 0,
  amount_paise   bigint      not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  version        integer     not null default 1,
  is_deleted     boolean     not null default false,
  device_id      text
);

-- ---------------------------------------------------------------------------
-- Indexes — fast search and delta sync.
-- ---------------------------------------------------------------------------
create index if not exists idx_products_updated_at  on public.products (updated_at);
create index if not exists idx_customers_phone      on public.customers (phone);
create index if not exists idx_bills_billed_at      on public.bills (billed_at);
create index if not exists idx_bills_updated_at     on public.bills (updated_at);
create index if not exists idx_bill_items_bill_id   on public.bill_items (bill_id);

-- ---------------------------------------------------------------------------
-- updated_at triggers on every table.
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'users','app_settings','products',
    'customers','bills','bill_items'
  ] loop
    execute format(
      'create trigger trg_%1$s_updated_at before update on public.%1$s
         for each row execute function public.set_updated_at();', t);
  end loop;
end$$;
