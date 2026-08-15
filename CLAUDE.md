# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter port of "باقتي" (Baqati) — a Yemen Mobile package/data-balance tracker. The app is Arabic-first and
**must be fully RTL** throughout.

This is a *separate git repo* from the reference implementation — see "Porting reference" below.

### Layout

- `lib/data/` — sqflite persistence: `AppDatabase`, `PackageEventDao`, `PackageRepository` (a `ChangeNotifier`).
- `lib/services/` — `SmsParser` (pure regex, the core business logic), `SmsService` (native bridge),
  `SmsSyncService` (read → parse → dedupe-hash → insert → schedule), `NotificationService`, `SettingsService`.
- `lib/viewmodels/PackageViewModel` — one app-scoped `ChangeNotifier` shared by the dashboard, history and
  details screens; re-queries whenever the repository notifies.
- `lib/app/app_dependencies.dart` — the composition root. Everything is constructed once in `main()` and passed
  down by constructor; there is no service locator.
- `lib/screens/`, `lib/widgets/`, `lib/theme/`, `lib/utils/`.
- Android native: `android/app/src/main/kotlin/com/dawood/baqati/` — `SmsBridge` (method + event channels),
  `SmsReceiver`.

### Conventions

- **`PORT-FIX:` comments** mark every deliberate divergence from the Kotlin reference, naming the original defect
  and why the behavior changed. Keep writing them — they are the record of what was intentionally *not* copied.
- **Arabic-Indic digits everywhere.** All user-facing numbers and dates go through `lib/utils/formatters.dart`.
  Do not call `DateFormat` or `toString()` on a number from a screen.
- Note the direction asymmetry: `ArabicText.normalizeForParsing` converts the carrier's `٠-٩` **to** `0-9` so the
  parser's regexes match; `Formatters` converts back for display only.
- State management is `ChangeNotifier` + `ListenableBuilder` with manual constructor DI, per
  `.claude/rules/Flutter/RULES.md`. No Riverpod/Bloc/GetX.

## Build & run

- Get packages: `flutter pub get`
- Run (debug, connected device/emulator): `flutter run`
- Run all tests: `flutter test`
- Run a single test file: `flutter test test/sms_parser_test.dart`
- Static analysis (uses `analysis_options.yaml` / `flutter_lints`): `flutter analyze`
- Format: `dart format .`
- Build Android APK: `flutter build apk`
- Build iOS (macOS host only): `flutter build ios`

Platforms scaffolded: `android/` (application id `com.dawood.baqati`) and `ios/`. No `windows/`, `macos/`,
`linux/`, or `web/` folders were generated — add via `flutter create --platforms <list> .` if a target is needed.

Tests are logic-only (parser, DAO, sync, formatters, view model); there are no widget tests. DAO and sync tests
run against a real in-memory SQLite via `sqflite_common_ffi` using `AppDatabase.onCreate`, which is exposed for
exactly that. Shared fakes live in `test/support/fakes.dart` and `extend` the real services rather than
implementing them.

## Porting reference — read before implementing features

`D:\flutter-projects\baqati-kotlen\` is a **separate git repo**: the original native Kotlin/Jetpack Compose
Android implementation of this same app. It has its own `CLAUDE.md` with full architecture notes (data model,
SMS-parsing regex rules, notification/alarm scheduling, screens, theming), and the screens themselves are under
`app/src/main/java/com/example/ui/screens/`. Treat it as the functional spec — read the relevant section there
before changing an equivalent Flutter feature, rather than re-deriving behavior from scratch. It lives outside
this repo, so it won't show up in `git status`/diffs here.

**The reference is not authoritative where it is wrong.** The port deliberately diverges from it in a number of
places, each marked with a `PORT-FIX:` comment naming the original defect (mock history cards, decorative
switches, usage bars that always read 100%, manual entries masking real activations, missing dedupe, and more).
Read those comments before "restoring" anything to match the Kotlin.

Where the Kotlin and the design prototype disagree, **the prototype wins** — it is the more complete of the two.
Its Settings screen, for example, specifies lead-time and alert-type controls the Kotlin never built.

Key things the Kotlin reference establishes that must carry over:

- Full RTL layout, Arabic UI strings, Arabic-Indic digit normalization (`٠-٩` → `0-9`).
- Offline-only: no network calls for core tracking functionality.
- SMS auto-sync (reading Yemen Mobile "111" messages) is **Android-only** — there is no iOS equivalent, so the
  iOS experience is manual-entry-only. `SmsService` and `NotificationService` already degrade to no-ops off
  Android, and `PackageViewModel.supportsSmsSync` gates the SMS-specific UI.
- Expiry reminders survive process death via `flutter_local_notifications`' own boot receiver plus
  `RECEIVE_BOOT_COMPLETED`; `NotificationService` returns a `ReminderOutcome` rather than failing silently when
  the Android 12+ exact-alarm permission is withheld. Surface that outcome — do not assume success.

The design prototype lives in this directory (all gitignored): `Package Tracker.dc.html`, plus the
`Simple app creation` / `Simple app creation-handoff` bundles — each present both as a `.zip` and as an
already-extracted folder of the same name. It contains six numbered screens (`١ · الترحيب والأذونات` through
`٦ · تنبيه يدوي`). Use it for exact colors/spacing/screen flow.

for Flutter Rules u can read @.claude\rules\Flutter\RULES.md
