# Android QA checklist (release)

Test on the Pixel 8 Pro emulator (or any Android 7.0+ device).

## Onboarding
- Fresh install → welcome screen renders, `start` works.
- Pick username → account created → no pairing code shown to user.
- Optional avatar pick → upload succeeds → avatar shows in app.
- Relaunch app → goes to dashboard (no onboarding loop).

## Inbox (Friends)
- Add friend search sheet opens (no overflow), search works (>=2 chars).
- Send friend request → receiver sees request card → accept/decline works.
- Direct thread row shows unread badge when a doodl arrives.
- Opening a thread:
  - Shows snap immediately (no black screen).
  - Progress bar runs ~10s per snap.
  - Tap advances to next snap (if multiple) and closes after last.
  - After viewing, thread no longer shows unread.

## Groups
- Create group → appears in list with member count.
- Invite works from group info screen.
- Group row shows “new” when there’s an unseen doodl.
- Opening a group:
  - Shows only doodls from other members (not your own).
  - Marks seen so it doesn’t keep re-opening the same snaps.

## Anonymous
- Switching to `anon` tab immediately loads the link + inbox (toggle state stays correct).
- Enable toggle persists after refresh/re-open.
- Anonymous inbox shows received doodls.
- `send anonymous` → search by username → send succeeds → receiver sees it in anon inbox.

## Doodle composer
- Canvas draws correctly for pen/pencil/marker/highlighter + eraser.
- Undo/redo/clear work.
- Send sheet opens full height and sending to friend/group succeeds.

## Push notifications + widget
- Push arrives for incoming doodl (Android).
- Widget shows the latest doodl + sender name.
- Background update:
  - Kill the app.
  - Receive a push.
  - Widget should update without opening the app (best-effort; depends on device/OS).

## Known
- `flutter analyze` reports deprecation *infos* (`withOpacity`, `WillPopScope`) but build is OK.
- Android 6 devices can’t install (`minSdkVersion` is 24 / Android 7.0+).

