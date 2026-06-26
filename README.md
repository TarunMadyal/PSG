# PSG Padmashree Garments — POS & Billing System

An **offline-first, mobile-first Point of Sale** for PSG Padmashree Garments, a retail clothing
shop. Built with Flutter for Android tablets/phones (and iPad), designed to be the shop's primary
billing system — fast, reliable, and **safe against data loss**.

> Full design rationale lives in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) (the approved
> Software Design Document).

## Status

| Phase | Description | State |
|------:|-------------|-------|
| 1 | Architecture + project scaffold, theme, DI, app shell | ✅ Done |
| 2 | Database (Drift local + Supabase cloud schema, migrations) | ✅ Done |
| 3 | Authentication, PIN login, RBAC | ✅ Done |
| 4 | Products (catalog + stock) | ✅ Done |
| 5 | Billing | ⏳ Next |
| 6 | Printing (ESC/POS thermal) | ⬜ |
| 7 | Reports | ⬜ |
| 8 | Cloud sync | ⬜ |
| 9 | Testing & hardening | ⬜ |
| 10 | Deployment (signed APK + OTA) | ⬜ |

## Tech stack

- **Flutter** (Dart) — single codebase, native-feeling touch UI
- **Riverpod** — state management & dependency injection
- **go_router** — navigation (indexed stateful shell)
- **Drift / SQLite** — local offline-first database
- **Supabase (Postgres)** — cloud backend, auth, backups *(sync in Phase 8)*
- **ESC/POS** — Bluetooth/Wi-Fi thermal receipt printing *(Phase 6)*

## Project structure

```
lib/
  app/        # MaterialApp, router, responsive shell, nav destinations
  core/       # config, theme, error/Result, logging, money & date utils, enums
  data/
    local/    # Drift database, tables, DAOs (on-device source of truth)
  features/   # billing, products, inventory, customers, reports, settings
              #   each: presentation/ domain/ data/
  shared/     # reusable widgets (logo, sync chip, placeholders)
  main.dart
supabase/
  migrations/ # cloud Postgres schema + Row-Level Security
test/         # unit + widget + database tests mirroring lib/
```

### Code generation

Drift generates `*.g.dart` files. **These are committed** so a fresh clone
builds and tests without a codegen step. If you change any table/DAO, regenerate:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Money is stored everywhere as **integer paise** (never `double`) to avoid rounding errors — see
`lib/core/utils/money.dart`.

## Getting started

Requires the Flutter SDK (3.24+, Dart 3.5+).

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # on a connected device/emulator
```

Cloud features read Supabase credentials from `--dart-define` (never committed):

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=PSG_CLOUD_SYNC=true
```

## Quality

- Strict static analysis (`analysis_options.yaml`, `flutter_lints`)
- Errors returned as values via `Result` / `Failure` (no exceptions across layers)
- Unit + widget tests run in CI before each phase is signed off
