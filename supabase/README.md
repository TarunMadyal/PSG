# Supabase (cloud) — PSG POS

The durable cloud source of record. The on-device SQLite database is the working
source of truth; the sync engine (Phase 8) mirrors it here. This schema is a
1:1 mirror of the local Drift schema so rows upsert cleanly by UUID.

## Contents

| File | Purpose |
|------|---------|
| `migrations/0001_initial_schema.sql` | Tables, indexes, `updated_at` triggers |
| `migrations/0002_row_level_security.sql` | RLS: owner (full) vs staff (billing + lookups) |

## Design notes

- **UUID primary keys**, client-generated — duplicate-safe offline creation.
- **Soft deletes** (`is_deleted`) — deletions sync and stay recoverable.
- **`updated_at`** (auto-maintained by trigger) drives delta sync + last-write-wins.
- **Money** stored as integer **paise** (`bigint`).
- **Enums** stored as TEXT with CHECK constraints, matching the local `textEnum`
  storage exactly.
- **RLS** enforced in the cloud as defence-in-depth, independent of the app.

## Applying

### Option A — Supabase CLI (recommended)
```bash
supabase link --project-ref <your-project-ref>
supabase db push          # applies migrations/ in order
```

### Option B — SQL editor
Paste `0001_initial_schema.sql` then `0002_row_level_security.sql` into the
Supabase dashboard SQL editor and run in order.

## Roles

After creating an auth user, insert a matching row in `public.users` with the
same `id` and the desired `role` (`owner` or `staff`). RLS reads the role from
there. The first account should be the **owner**.

> Daily backups + point-in-time recovery are enabled on the Supabase **Pro**
> tier — recommended before the shop goes paperless (see `docs/ARCHITECTURE.md`
> §7 Backup & Disaster Recovery).
