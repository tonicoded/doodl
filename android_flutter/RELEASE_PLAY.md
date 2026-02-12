# Google Play release (Android)

## 1) Version bump
Update `android_flutter/pubspec.yaml`:

`version: X.Y.Z+N`

- `X.Y.Z` = versionName
- `N` = versionCode (must increase every upload)

## 2) Signing (upload key)
You already created `android_flutter/android/app/upload-keystore.jks`.

Create `android_flutter/android/key.properties` (copy from `android_flutter/android/key.properties.example`) and fill in your passwords.

This file is gitignored and should never be committed.

## 3) Build AAB
From `android_flutter/android` (works even if `flutter build appbundle` fails on your machine):

`JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:bundleRelease`

Output:
- `android_flutter/build/app/outputs/bundle/release/app-release.aab`

## 4) Upload to Play Console
- Create app (if new) → enable **Play App Signing**
- Upload `app-release.aab` to **Testing → Internal testing** first
- Test install via Play link
- Promote to Production when OK
