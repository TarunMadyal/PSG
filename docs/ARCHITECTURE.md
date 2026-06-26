# PSG Padmashree Garments — POS & Billing System
## Software Design Document (SDD) + Implementation Plan

> **Status:** Architecture proposal awaiting approval. **No application code will be written until you approve.**
> The repository is currently empty (greenfield). We are on branch `claude/psg-padmashree-pos-system-mrde8l`.

---

## Context — Why we are building this

PSG Padmashree Garments bills manually on pen and paper. The owner wants to **fully replace** that
manual process with a mobile-first POS he can trust as the shop's *primary* billing system for the
next decade. The single hardest constraint is **data safety**: once paper records stop, the digital
system becomes the only source of truth, so it must survive device loss, crashes, power cuts, and
internet outages without ever losing a sale. The secondary constraints are **fast touch billing**,
**reliable thermal printing**, and **working fully offline** with automatic cloud sync when the
internet returns. The deliverable is a production-grade app, not a prototype.

This document covers all 18 requested sections. Where a choice materially shapes the build, I state
my recommendation **and** the runner-up so you can override on approval.

---

## 1. Executive Summary

I recommend building a **native-feeling Flutter app** for Android tablets/phones (and optionally
iPad), architected **offline-first**: every action reads and writes a **local SQLite database
first**, so the app is always instant and works with zero internet. A background **sync engine**
mirrors that local data to a managed **Supabase (PostgreSQL)** cloud backend whenever a connection
is available. The cloud is the durable, backed-up source of record; the device is a fast, fully
functional cache.

Key recommendations (override any on approval):

| Decision | Recommendation | Why |
|---|---|---|
| App framework | **Flutter** | One codebase, native speed, best thermal-printer + offline libraries |
| Local DB | **SQLite via Drift** | Battle-tested, relational, type-safe, transactional |
| Cloud backend | **Supabase (Postgres)** | Real relational DB you own, auth + RLS + automated backups, no lock-in |
| Sync | **Outbox + pull/push delta sync** (optionally PowerSync) | Deterministic, debuggable, duplicate-safe |
| Printing | **ESC/POS over Bluetooth** (Wi-Fi & USB supported) | Standard for 58/80mm thermal printers |
| Deployment | **Signed APK + OTA updates (Shorebird)** | Simple, no store delays, auto-updates |
| Cost | **~$25–35/month** (Supabase Pro) | Daily backups + point-in-time recovery = "sleep at night" |

This gives the owner a premium, fast POS that **cannot lose data** short of simultaneous device +
cloud loss, and even then nightly off-site exports provide a third line of defense.

---

## 2. Recommended Architecture

**Pattern: Offline-first Clean Architecture.**

```
┌──────────────────────────────────────────────────────────┐
│                     Flutter App (device)                   │
│                                                            │
│  Presentation (screens, widgets, Riverpod state)           │
│        │                                                   │
│  Domain (entities, use-cases, repository interfaces)       │
│        │                                                   │
│  Data (repository impls)                                   │
│    ├── Local data source  ──►  SQLite (Drift)  ◄── SoT     │
│    └── Remote data source ──►  Supabase client            │
│                                                            │
│  Sync Engine (outbox queue, delta pull, retry, conflict)  │
│  Printer Service (ESC/POS: Bluetooth / Wi-Fi / USB)        │
└──────────────────────────────────────────────────────────┘
                    │ (when online)
                    ▼
┌──────────────────────────────────────────────────────────┐
│   Supabase Cloud:  PostgreSQL + Auth + Row-Level Security  │
│   + Storage (product images, logo) + Automated Backups     │
└──────────────────────────────────────────────────────────┘
                    │ (nightly)
                    ▼
        Off-site export (Google Drive / S3)  — 3rd backup tier
```

**Principles**
- **The UI never waits on the network.** All reads/writes hit local SQLite synchronously-fast.
- **Local DB is the working source of truth; cloud is the durable source of record.** They reconcile via the sync engine.
- **Clean layering** keeps printing, sync, and storage swappable (e.g. switch Supabase→self-host later without touching UI).
- **Feature-first folders** so billing, products, inventory, reports, auth evolve independently.
- **State management: Riverpod** (compile-safe, testable, great for async/offline state).

---

## 3. Technology Comparison

### App framework

| Criterion | **Flutter (recommended)** | React Native | PWA | Native Android |
|---|---|---|---|---|
| Reliability | Excellent (AOT compiled) | Good | Fair | Excellent |
| Offline | Excellent (Drift/SQLite) | Good (WatermelonDB) | Limited (IndexedDB, quota/eviction) | Excellent |
| Thermal printer | **Excellent** (mature ESC/POS BT/Wi-Fi/USB libs) | Inconsistent native modules | **Poor** (Web Bluetooth flaky on Android, none on iOS) | Excellent |
| Performance (touch) | Native 60fps | Near-native | Variable | Native |
| Maintainability | One codebase, strong typing (Dart) | One codebase, JS churn | One codebase | Android-only |
| Deployment | APK + OTA | APK + OTA | Instant (URL) | APK |
| iPad support | Yes | Yes | Yes | No |
| Long-term scale | Excellent | Good | Fair (printing ceiling) | Good (single-OS) |
| Dev complexity | Moderate | Moderate | Low | High |
| Cost | Free | Free | Free | Free |

**Recommendation: Flutter.** The decisive factor for a shop that prints every sale is that Flutter
has the most reliable thermal-printer ecosystem and the strongest offline DB story, while still being
a single codebase that runs on Android tablet/phone and iPad. PWA is eliminated by its printing
weakness (especially iOS) and storage-eviction risk — unacceptable when data safety is the top
priority.

### Cloud storage strategy

| Option | Advantages | Disadvantages | ~Monthly cost | Maintenance | Reliability | Scalability | Data-loss risk |
|---|---|---|---|---|---|---|---|
| **Local DB only** | Free, instant, zero infra | **No recovery if device lost/broken** | $0 | None | Device-bound | Single device | **Very High** ❌ |
| **Supabase (recommended)** | Real Postgres you own, auth+RLS, daily backups, PITR (paid), easy export | Paid tier for best backups | $0 free / **~$25 Pro** | Very low (managed) | High | High | **Low** ✅ |
| **Firebase (Firestore)** | Best-in-class offline SDK, auto-sync, generous free tier | NoSQL awkward for invoices/reports, export friction, lock-in, cost spikes | $0–variable | Very low | High | High | Low–Med |
| **PostgreSQL (self-managed)** | Full control, cheap at scale | You own backups/uptime/patching | ~$6–20 VPS | **High (your job)** | Depends on you | High | Med–High |
| **Self-hosted (own server)** | Total control | Single point of failure, no DR for a shop | hardware | **Very high** | Low | Low | **High** ❌ |
| **AWS (RDS/Amplify)** | Enterprise-grade | Complex, overkill, costly | $30–100+ | High | Very high | Very high | Low |
| **Azure** | Enterprise-grade | Complex, overkill | $30–100+ | High | Very high | Very high | Low |
| **Google Cloud (Cloud SQL)** | Enterprise-grade | Complex, overkill | $30–100+ | High | Very high | Very high | Low |

**Recommendation: offline-first SQLite on device + Supabase (Postgres) in the cloud.** This is the
"offline-first local database with cloud synchronization" option in your list, implemented with the
most trustworthy managed backend. Supabase gives a *real relational database the owner owns* (it's
just Postgres — exportable, no lock-in), managed auth, row-level security, and automated daily
backups with point-in-time recovery on the Pro tier. The hyperscalers (AWS/Azure/GCP) are more
powerful but add operational complexity a single-shop business shouldn't carry. Firebase is the
strong runner-up but its NoSQL model fights against invoice/report queries and makes data export
harder.

---

## 4. Database Design (conceptual)

Core entities and relationships:

- **users** — staff/owner accounts, roles, PIN/password hash.
- **products** — catalog (name, category, brand, size, color, SKU, barcode, price, images).
- **inventory** — stock levels per product (kept consistent via bill transactions).
- **customers** — optional; keyed by phone; enables purchase history.
- **bills (invoices)** — header: invoice no, datetime, cashier, customer, totals, payment method, status.
- **bill_items** — line items: product, qty, rate, discount, amount.
- **inventory_movements** — append-only ledger of stock changes (sale, return, adjustment, restock).
- **settings** — shop profile (name, address, phone, GST, logo, receipt config).
- **sync metadata** — per-row `updated_at`, `version`, `is_deleted` (soft delete), `device_id`, and a global **outbox** of pending changes.

Design choices that protect data:
- **UUID primary keys** generated on-device → no central counter, no sync collisions, duplicate-safe.
- **Soft deletes** (`is_deleted`) everywhere → deletions sync safely and are recoverable.
- **Append-only inventory ledger** → stock is always reconstructable; no destructive updates.
- **Monetary values stored as integer paise** (not floats) → no rounding errors in money.
- **Every row carries `updated_at` + `version`** → enables delta sync and conflict resolution.

(Full column-level schema in Section 11.)

---

## 5. Offline Strategy

The app is **offline-first**, meaning offline is the *normal* operating mode, not a fallback.

- All screens read from local SQLite; all writes commit to local SQLite inside a transaction **before** any network call.
- Creating a bill, searching products, viewing inventory, viewing recent transactions, and **printing** all work with zero internet — printing talks directly to the Bluetooth/Wi-Fi printer, no cloud needed.
- Each local write also appends an entry to an **outbox** table (the change to be pushed).
- A connectivity listener + periodic timer triggers the sync engine whenever the network is up.
- If the app is killed mid-operation, the local transaction either fully committed or fully rolled back (ACID), and the outbox is durable, so nothing is half-done.

This guarantees the shop keeps billing through any outage; the cloud simply catches up later.

---

## 6. Cloud Synchronization

**Model: bidirectional delta sync with an outbox (push) and a high-water-mark cursor (pull).**

- **Push:** Drain the outbox oldest-first. Each change is an **idempotent upsert keyed by UUID**, so retries can never create duplicates. On success, mark the outbox entry done.
- **Pull:** Ask Supabase for all rows where `updated_at > last_synced_cursor`, apply them locally, advance the cursor.
- **Conflict resolution:** **Last-Write-Wins by `updated_at`**, with `version` as tiebreaker, applied per-row. For the rare, important case of two devices editing the *same* bill, conflicts are logged for owner review rather than silently dropped. Inventory uses the **append-only movement ledger**, so concurrent stock changes *add up* correctly instead of overwriting.
- **Duplicate prevention:** UUID PKs + idempotent upserts + unique invoice numbers per device prefix.
- **Error recovery & retry:** Failed pushes stay in the outbox and retry with **exponential backoff + jitter**; transient errors never lose data; permanent errors (validation) are flagged for review. Sync is **resumable** — a crash mid-sync just re-runs from the durable outbox/cursor.
- **Optional upgrade:** If you prefer a turnkey engine over the custom one, **PowerSync** (Supabase-compatible) provides production-grade offline sync out of the box (adds a small monthly cost). The custom outbox approach is recommended first for simplicity and full control; PowerSync is a clean drop-in later.

---

## 7. Backup & Disaster Recovery

Three independent tiers — the shop survives losing any one (or two) of them:

1. **Device (local):** SQLite file + periodic on-device snapshot export to the device's own storage.
2. **Cloud (primary):** Supabase Postgres with **automated daily backups** and **point-in-time recovery** (Pro tier). This is the durable source of record.
3. **Off-site (tertiary):** A scheduled **nightly logical export** (SQL/CSV dump) pushed to Google Drive or S3, independent of Supabase, so even a catastrophic backend failure can't erase history.

**Recovery scenarios:**
- *Tablet lost/stolen/destroyed* → install app on a new device, log in, app pulls the full dataset from Supabase. Zero data loss for anything that had synced.
- *Unsynced sales on a dead device* → mitigated by syncing frequently (every few minutes when online) and the local snapshot; this window is the only residual risk and is minimized by design.
- *Accidental deletion* → soft deletes + backups make it reversible by the owner.
- *Backend disaster* → restore from nightly off-site export.

Backup cadence: **daily** (automated cloud + off-site), with **weekly** and **monthly** retained snapshots for long-horizon recovery.

---

## 8. Security Design

- **Authentication:** Supabase Auth (email/phone + password) for account identity; **fast PIN login** on the device for daily use so cashiers aren't typing passwords all day. PINs are hashed locally; full re-auth required to add/change users.
- **Roles & permissions (RBAC):** `owner` (full access) and `staff/cashier` (billing, printing, product search, optional stock view; **cannot** delete products, change settings, delete history, restore backups, or see sensitive reports). The permission model is **capability-based** so new roles (e.g. manager, accountant) drop in without rework.
- **Authorization enforced in two places:** in-app (UI/use-case guards) **and** in the cloud via **Postgres Row-Level Security**, so a compromised client still can't exceed its role.
- **Encryption:** TLS in transit; device DB encryption at rest (SQLCipher option) for sensitive data; secrets in secure storage (Android Keystore).
- **Cloud security:** RLS policies per table, least-privilege API keys, no service-role key on device.
- **Backup security:** encrypted off-site exports; access restricted to the owner.

---

## 9. Printer Integration

- **Standard:** **ESC/POS** command protocol — the universal language of 58mm and 80mm thermal receipt printers.
- **Connections supported:**
  - **Bluetooth (recommended default):** simplest for a mobile shop, no router needed; pair once, reconnect automatically. Libraries: `print_bluetooth_thermal` / `flutter_thermal_printer` + `esc_pos_utils`.
  - **Wi-Fi/LAN:** print over TCP to a fixed printer IP; great for a fixed counter; needs the printer and tablet on the same network. Library: `esc_pos_printer`.
  - **USB (Android OTG):** supported where the device allows USB host mode.
- **Bluetooth vs Wi-Fi:** Bluetooth = mobile, zero infra, slightly more pairing care; Wi-Fi = rock-solid at a fixed counter, needs a network. We support both; **default to Bluetooth** for flexibility.
- **Flow:** printer **discovery** → **pairing** (saved as default printer) → **offline printing** (no internet involved) → **error handling** (out of paper, disconnected, retry, "reprint last bill"). One tap on **"Print Bill"** renders the ESC/POS receipt and prints immediately.
- **Resilience:** every bill is saved *before* printing, so a printer failure never loses the sale; the cashier can reprint anytime.

---

## 10. UI/UX Design

Design language: **modern, premium, professional POS** — clean, spacious, icon-supported, *not*
childish or oversized. Optimized for **landscape tablet** with phone-responsive layouts. Goal: a new
employee is productive in **15–20 minutes**.

Primary screens:
1. **Login / PIN** — fast entry, user picker.
2. **Billing (home)** — split view: product search/grid on the left, live cart + totals on the right; add item, set qty/discount, pick payment, **Generate + Print** in minimal taps.
3. **Products** — list/grid, search/filter, add/edit (owner), images.
4. **Inventory** — stock levels, low-stock highlights, adjustments (owner).
5. **Customers** — optional lookup by phone, purchase history.
6. **Reports** — today/week/month/year, best sellers, low stock, inventory value.
7. **Settings** — shop profile, logo, GST, printer config, users, backups (owner).
8. **Sync/status indicator** — subtle, always-visible "synced / pending / offline" state for trust.

Principles: minimal clicks to bill, consistent components, clear labels, generous spacing,
keyboard/scanner-friendly search, instant feedback. *(I can produce Figma mockups via the Figma MCP
during the UI phase if you want visual sign-off before coding screens.)*

---

## 11. Database Schema (representative)

> Money stored as **integer paise**. All tables carry `id (uuid pk)`, `created_at`, `updated_at`,
> `version int`, `is_deleted bool`, `device_id`. Same schema mirrored in SQLite (local) and Postgres (cloud).

```sql
users(id, name, role, phone, email, pin_hash, password_hash, is_active, …meta)
settings(id, shop_name, address, phone, gst_number, logo_url, receipt_width, footer_text, …meta)

products(id, name, category, brand, size, color, sku, barcode UNIQUE,
         price_paise, cost_paise, image_url, is_active, …meta)

inventory(id, product_id FK, qty_on_hand, reorder_level, …meta)

inventory_movements(id, product_id FK, change_qty, reason ENUM('sale','return','adjust','restock'),
                    ref_bill_id NULL, note, …meta)   -- append-only ledger

customers(id, name, phone UNIQUE, notes, …meta)

bills(id, invoice_no, customer_id NULL, cashier_id FK,
      subtotal_paise, discount_paise, gst_paise, grand_total_paise,
      payment_method ENUM('cash','card','upi','other'),
      status ENUM('completed','void'), billed_at, …meta)

bill_items(id, bill_id FK, product_id FK, name_snapshot, qty,
           rate_paise, discount_paise, amount_paise, …meta)

-- local-only:
outbox(id, table_name, row_id, op ENUM('upsert','delete'), payload_json, created_at, attempts, last_error)
sync_state(id, last_pull_cursor, last_push_at)
```

Notes: `name_snapshot`/`rate` on `bill_items` freeze the price at sale time (historical accuracy
even if product price changes later). Invoice numbers use a per-device prefix to stay unique offline.

---

## 12. API Design

With Supabase, most CRUD goes through its auto-generated, RLS-protected REST/Realtime API, consumed
by the Flutter data layer behind **repository interfaces** (so the backend is swappable). The app's
*internal* contract is the set of repository methods, e.g.:

```
AuthRepository:      login(pin), currentUser(), users CRUD (owner)
ProductRepository:   search(query), getById, upsert, softDelete, list(filters)
InventoryRepository: stockFor(productId), recordMovement(...), lowStock()
BillRepository:      create(bill+items) [tx: writes bill, items, inventory movement, outbox], list, getById, void
CustomerRepository:  findByPhone, upsert, historyFor(customerId)
ReportRepository:    salesSummary(range), bestSellers(range), inventoryValue(), lowStock()
SyncService:         push(), pull(), fullSync(), status()
PrinterService:      discover(), connect(printer), printBill(bill), reprint(billId), status()
SettingsRepository:  get(), update() [owner], backupNow(), restore()
```

Custom server-side logic (e.g. nightly off-site export, advanced reports) runs as **Supabase Edge
Functions** when needed.

---

## 13. Folder Structure (feature-first Clean Architecture)

```
lib/
  core/            # config, theme, errors, logging, result types, di
  data/            # db (drift), supabase client, sync engine, printer service
  features/
    auth/          # presentation/ domain/ data/
    billing/
    products/
    inventory/
    customers/
    reports/
    settings/
    sync/
  shared/          # reusable widgets, formatters (money/date), constants
  main.dart
test/              # unit + widget + integration tests mirroring features/
```

Each feature has its own `presentation/ domain/ data/` so features are independently buildable and
testable. Standards: TypeScript-equivalent strict typing in **Dart**, reusable components, explicit
**error handling** (Result/Either), structured **logging**, and **tests** at each layer.

---

## 14. Development Roadmap (phased, each independently testable)

| Phase | Deliverable | Independently testable outcome |
|---|---|---|
| **1. Architecture** | This SDD approved; project scaffold, CI, theme, DI | App boots to a styled shell |
| **2. Database** | Drift schema + Supabase schema + RLS + migrations | CRUD works locally & in cloud |
| **3. Authentication** | Accounts, PIN login, RBAC, RLS enforcement | Owner vs staff access verified |
| **4. Products** | Product CRUD, search, images, categories | Manage 1000s of products smoothly |
| **5. Billing** | Cart, discounts, payment, invoice generation, inventory auto-decrement (tx) | Create a correct bill offline |
| **6. Printing** | ESC/POS Bluetooth/Wi-Fi, bill format, reprint, error handling | One-tap print on real 58/80mm printer |
| **7. Reports** | Sales (day/week/month/year), best sellers, low stock, inventory value | Reports match seeded data |
| **8. Cloud Sync** | Outbox push, delta pull, conflict resolution, retry, status UI | Two devices converge; survives offline |
| **9. Testing & Hardening** | Unit/widget/integration tests, crash reporting, backup/restore, off-site export | Backup→wipe→restore recovers all data |
| **10. Deployment** | Signed APK, OTA updates, install on shop devices, owner training | Live on the shop's tablet |

We build, verify, and sign off **one phase at a time** before moving on.

---

## 15. Hardware Recommendations

- **Best Android tablet:** **Samsung Galaxy Tab A9+ (11", 4–8GB RAM)** — reliable, good screen, long
  software support, sturdy for retail. (Or Tab S6 Lite for a step up.)
- **Budget Android tablet:** **Samsung Galaxy Tab A9 (8.7")** or a current **Lenovo Tab M-series** —
  prioritize a known brand with OS updates over the cheapest no-name unit (reliability matters daily).
- **Thermal printer:** A reputable **80mm Bluetooth+Wi-Fi ESC/POS** desktop printer for a fixed
  counter (e.g. **Epson TM-series** for premium reliability, or a quality **TVS/Rugtek 3-inch**
  for value). For a mobile/handheld setup, a **58mm Bluetooth** pocket printer.
- **Receipt paper:** **80mm** thermal rolls for the main counter (more room for itemized clothing
  bills); **58mm** if you choose a compact printer. Standardize on one width and configure it in Settings.
- **Recommendation:** 80mm Bluetooth+Wi-Fi printer + Galaxy Tab A9+ — the best reliability-per-rupee
  for daily commercial use, with a UPS/power bank so a power cut never interrupts billing.

---

## 16. Monthly Cost Estimate

| Item | Free start | Recommended (paperless-ready) |
|---|---|---|
| Supabase backend + daily backups + PITR | $0 (free tier) | **~$25/mo (Pro)** |
| Off-site nightly export (Drive/S3) | $0–~$2 | ~$2/mo |
| OTA updates (Shorebird) | $0 (free tier) | $0 |
| Optional PowerSync (turnkey sync) | — | ~$0–$35/mo if adopted |
| **Total** | **~$0/mo** | **~$25–35/mo** |

One-time: ~$25 Google Play developer account *only if* you later distribute via Play Store. Given
data safety is the priority, I recommend starting on or upgrading to the **~$25–35/mo Pro tier**
before going fully paperless.

---

## 17. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Device lost with unsynced sales | Frequent auto-sync when online + local snapshot; minimal residual window by design |
| Backend outage / data loss | Daily cloud backups + PITR + **independent** nightly off-site export |
| Printer fails mid-sale | Bill is saved **before** printing; reprint anytime; clear error UI |
| Sync conflicts / duplicates | UUID keys + idempotent upserts + LWW + append-only inventory ledger + conflict log |
| Money rounding errors | Store integer paise everywhere; format only at display |
| Owner not highly technical | Premium-but-simple UX, 15–20 min learnability, owner training in Phase 10 |
| Vendor lock-in | Supabase is plain Postgres — full export anytime; repository pattern isolates backend |
| Accidental deletion | Soft deletes + backups make deletions recoverable |
| Power failure | ACID local transactions + recommended UPS/power bank |
| Scaling to thousands of products | Indexed search, pagination, lazy image loading — no code changes needed |

---

## 18. Future Enhancements (architected to drop in without rewrites)

Barcode scanning, QR/UPI payments, GST support, WhatsApp/SMS invoices, customer loyalty,
multi-store, supplier management, purchase orders, analytics dashboard, AI sales insights. The
feature-first structure, capability-based RBAC, relational schema, and swappable repositories mean
each of these is an additive module, not a rewrite. (E.g. multi-store = add `store_id` scoping +
RLS; UPI = add a payment provider behind the existing payment method enum.)

---

## Verification Strategy (how we prove each phase works)

- **Unit tests** for use-cases (totals, discounts, tax, money math) and the sync conflict resolver.
- **Widget tests** for billing flow and key screens.
- **Integration tests** for the offline→online sync round-trip and the **backup → wipe → restore** drill.
- **Real-device verification** of one-tap thermal printing on an actual 58mm and 80mm printer.
- **Two-device convergence test** to prove sync + conflict handling.
- Phase sign-off only when its tests pass and the outcome in §14 is demonstrated.

---

## Open Decisions for Your Approval (defaults chosen; override any)

1. **App framework** → default **Flutter** (vs React Native / PWA / Native).
2. **Backend** → default **Supabase/Postgres** (vs Firebase / self-host).
3. **Monthly budget** → default **~$25–35/mo Pro** (vs $0 free start).
4. **Deployment** → default **signed APK + Shorebird OTA** (vs Play Store).
5. **Sync engine** → default **custom outbox** first (vs adopt PowerSync now).

> On approval, we begin **Phase 1 (scaffold)** and build module-by-module, verifying each phase
> before the next. **No code is written until you approve this architecture.**
