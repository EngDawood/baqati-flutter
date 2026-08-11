# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter port of "باقتي" (Baqati) — a Yemen Mobile package/data-balance tracker. This root is a **fresh Flutter
scaffold** (`flutter create`, currently just the default counter app) that will become the real app. The app is
Arabic-first and **must be fully RTL** throughout.

This is a *separate git repo* from the reference implementation — see "Porting reference" below.

## Build & run

- Get packages: `flutter pub get`
- Run (debug, connected device/emulator): `flutter run`
- Run all tests: `flutter test`
- Run a single test file: `flutter test test/widget_test.dart`
- Static analysis (uses `analysis_options.yaml` / `flutter_lints`): `flutter analyze`
- Format: `dart format .`
- Build Android APK: `flutter build apk`
- Build iOS (macOS host only): `flutter build ios`

Platforms currently scaffolded: `android/` (package `com.example.baqati`) and `ios/`. No `windows/`, `macos/`,
`linux/`, or `web/` folders were generated — add via `flutter create --platforms <list> .` if a target is needed.

## Porting reference — read before implementing features

`baqati/` (sibling directory, `D:\flutter-projects\baqati\baqati\`) is a **separate git repo**: the original native
Kotlin/Jetpack Compose Android implementation of this same app. It has its own `CLAUDE.md` with full architecture
notes (data model, SMS-parsing regex rules, notification/alarm scheduling, screens, theming). Treat it as the
functional spec — read the relevant section there before building the equivalent Flutter feature, rather than
re-deriving behavior from scratch. It is gitignored from this repo (see `.gitignore`), so it won't show up in
`git status`/diffs here.

Key things the Kotlin reference establishes that must carry over:

- Full RTL layout, Arabic UI strings, Arabic-Indic digit normalization (`٠-٩` → `0-9`).
- Offline-only: no network calls for core tracking functionality.
- SMS auto-sync (reading Yemen Mobile "111" messages) is **Android-only** — there is no iOS equivalent, so plan
  the iOS experience as manual-entry-only.
- Exact-alarm-based expiry reminders need to survive process death and handle Android 12+ exact-alarm permission
  restrictions — likely needs `flutter_local_notifications` (or similar) plus native platform-channel work, not
  pure Dart.
- The SMS-parsing logic itself (`SmsParser` in the Kotlin repo) is pure string/regex parsing with no Android
  framework dependency and can port to Dart close to 1:1.

A design prototype also lives in this directory (all gitignored): `Package Tracker.dc.html`, plus the
`Simple app creation` / `Simple app creation-handoff` bundles — each present both as a `.zip` and as an
already-extracted folder of the same name. Use these for exact colors/spacing/screen flow when the Kotlin
Compose screens are ambiguous.

for Flutter Rules u can read @.claude\rules\Flutter\RULES.md
