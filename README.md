# TxnVault

Track every transaction from payment to refund.

TxnVault is an Android, offline-first app that automatically captures transaction
SMS from banks and UPI apps, parses them into structured records, and tracks the
full lifecycle of a transaction — including refunds, reversals, and failed
payments — which most expense trackers ignore.

## Status

Sprint 1 (project foundation) complete: app scaffolded, local database created,
navigation working. SMS capture is not implemented yet.

## Tech Stack

- **Flutter** + **Riverpod** (state management)
- **go_router** (navigation)
- **Drift** (SQLite ORM, local-only storage)
- **get_it** (dependency injection)
- Android only, no backend, no login (V1)

## Project Structure

```
lib/
├── app/            # routing, theme, app-level config
├── core/           # database, SMS parsing, notifications, shared infra
├── shared/         # reusable widgets, enums, extensions
├── features/       # dashboard, transactions, refunds, analytics, cards, settings
└── bootstrap/       # service locator setup
```

Each feature follows `data / domain / presentation / providers`.

## Getting Started

Requirements: Flutter SDK, Android SDK (command-line tools are enough, no
Android Studio required), and an Android device or emulator.

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Roadmap

- **Now**: SMS capture, transaction parsing, refund tracking, search, dashboard
- **Later**: CSV export, credit card due tracking, cloud sync, AI insights
