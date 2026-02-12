# DOODL. Android (Flutter)

This folder contains the Flutter source for the Android app.

## Prereqs

- Install Flutter: `https://docs.flutter.dev/get-started/install`
- Install Android Studio + Android SDK

## Create the Android project files

From this folder, run:

```bash
flutter create . --platforms=android --org com.anthonyverruijt --project-name doodl
```

This will generate the `android/` folder and Flutter tooling files while keeping the existing `lib/` structure.

## Configure keys

Copy `lib/config.example.dart` → `lib/config.dart` and fill in:

- Supabase URL + anon key (required)
- RevenueCat API key (Android public SDK key) (optional for MVP)

Note:
- A placeholder `lib/config.dart` is checked in so the project compiles; replace it with your real values.
- If you later `git init`, remove `lib/config.dart` from tracking once, then keep it ignored (see `android_flutter/.gitignore`).

## Run

```bash
flutter pub get
flutter run
```

## Scope (initial)

- Implemented:
  - Onboarding: create + recover (username + recovery code)
  - Dashboard: group picker (list/join/new) + group member counts
  - Share: draw canvas (send/export TODO)
- Next:
  - Inbox: list senders + thread viewer (group + anonymous)
  - Anonymous: enable link + anonymous inbox
  - Pro: RevenueCat gating + UI
  - Push: FCM + backend support
