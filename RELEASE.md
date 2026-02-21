# Coqui App Release Guide

This guide covers final checks and release steps for iOS, Android, macOS, and Windows.

## 1) Repo Cleanup Before Release

Run these commands from project root:

```bash
git status --short
flutter clean
flutter pub get
```

Then verify no local-only artifacts are staged:

```bash
git status --short
```

Expected tracked changes should be source/config/assets only (no `build/`, no platform ephemerals, no temporary backups).

## 2) Global Pre-Release Checklist

- Confirm app version in `pubspec.yaml` (`version: x.y.z+build`).
- Confirm app name/bundle identifiers are final for each platform.
- Confirm launcher icons and splash assets are correct.
- Run static checks and tests:

```bash
flutter analyze
flutter test
```

- Run at least one smoke test per platform target you ship.
- Confirm production API URL/auth behavior in app settings flow.

## 3) iOS Release (TestFlight / App Store)

Prerequisites:
- Apple Developer Program membership (required for App Store and TestFlight).
- Valid signing certificate + provisioning profile in Xcode.

Steps:
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Set Team, Bundle Identifier, Version, Build Number.
3. In Flutter project:

```bash
flutter build ipa --release
```

4. Upload using Xcode Organizer or Transporter.
5. In App Store Connect:
   - Add build to TestFlight.
   - Complete metadata, privacy details, screenshots.
   - Submit for review when ready.

Notes:
- If icon validation fails due alpha channel, set `remove_alpha_ios: true` in `flutter_launcher_icons` config and regenerate icons.

## 4) Android Release (Play Store)

Prerequisites:
- Release keystore and secure key properties setup.

Steps:
1. Configure signing (`android/key.properties` and Gradle signing config).
2. Build app bundle:

```bash
flutter build appbundle --release
```

3. Upload `.aab` in Google Play Console.
4. Complete release notes, store listing, and staged rollout.

Optional APK build:

```bash
flutter build apk --release
```

## 5) macOS Release

Prerequisites:
- Apple signing identity for Developer ID (outside Mac App Store) or Mac App Store certs.

Steps:
1. Build release app:

```bash
flutter build macos --release
```

2. Archive/sign/notarize using Xcode tooling (`xcodebuild`, `notarytool`) based on distribution method.
3. Validate app launch on a clean macOS machine/profile.

## 6) Windows Release

Steps:
1. Build release bundle:

```bash
flutter build windows --release
```

2. Package installer (MSIX/Inno Setup/etc.) per your distribution channel.
3. Code-sign installer and binaries.
4. Validate install/upgrade/uninstall on a clean Windows VM.

## 7) Final Verification Matrix

Before publishing, validate:
- Fresh install works.
- Existing-user upgrade works.
- API connectivity and auth errors are user-friendly.
- Role selection and chat flow work.
- Tool output rendering and session persistence work.
- App icon and splash assets render correctly on device.

## 8) Recommended Release Commands (Quick Sequence)

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build ipa --release        # macOS host, iOS release
flutter build appbundle --release  # Android release
flutter build macos --release      # macOS desktop
flutter build windows --release    # Windows desktop (on Windows host)
```

## 9) GitHub Release Hygiene

- Commit only source/config/docs/assets required by runtime.
- Do not commit local environment files, build output, or temp artifacts.
- Tag release after CI/local verification.

Example:

```bash
git add .
git commit -m "chore: prepare release vX.Y.Z"
git tag vX.Y.Z
git push origin main --tags
```
