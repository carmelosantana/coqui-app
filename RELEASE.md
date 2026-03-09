# Coqui App Release Guide

This guide covers final checks and release steps for iOS, Android, macOS, and Windows.

## 0) Unified Builder (Recommended)

Use [scripts/build.sh](scripts/build.sh) to standardize icon prep + build + open steps.

```bash
# macOS debug
./scripts/build.sh --platform macos --mode debug

# iOS release (IPA)
./scripts/build.sh --platform ios --mode release

# Android release (AAB)
./scripts/build.sh --platform android --mode release

# All possible targets on current host
./scripts/build.sh --platform all --mode debug
```

Notes:
- `build.sh` removes previous platform artifact outputs before rebuilding to avoid stale executable confusion.
- `--platform all` skips unsupported targets on the current host with warnings.
- Windows desktop builds should run on a Windows host (or Windows CI runner). Wine automation is not a reliable Flutter desktop release path.

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
- Confirm launcher icons and splash assets are correct (see Icon Pipeline below).
- Run static checks and tests:

```bash
flutter analyze
flutter test
```

- Run at least one smoke test per platform target you ship.
- Confirm production API URL/auth behavior in app settings flow.

## 2.1) Icon Pipeline

Each platform uses a different source icon. The build script (`build.sh`) and `make icons` handle this automatically.

| Platform | Source file | Notes |
|----------|-------------|-------|
| macOS | `coqui-icon-macos.png` | Auto-generated from `coqui-icon.png` at 83% inner size. Sequoia/Tahoe applies its own rounded-rect mask; without padding the icon appears oversized vs system apps. |
| iOS | `coqui.png` | Square, no alpha channel. App Store rejects icons with alpha. iOS clips its own rounded rect. |
| Android | `coqui-icon.png` | Primary icon with round corners and alpha. Android applies adaptive mask (circle/squircle). |
| Windows | `coqui.png` | Square .ico, no transparency. Standard Windows convention. |
| Linux | `coqui-icon.png` | Round-corner icon with alpha. |

To regenerate all platform icons:

```bash
make icons
```

Or manually:

```bash
./scripts/pad-icon.sh --image assets/images/coqui-icon.png --inner-size 83% --output assets/images/coqui-icon-macos.png
dart run flutter_launcher_icons
```

The per-platform source mapping is defined in the `flutter_launcher_icons` section of `pubspec.yaml`.

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

## 3.1) Apple Security & Compliance Checklist

Before uploading to TestFlight/App Store, verify:

- **Signing and identity**
   - Distribution certificate and provisioning profiles are valid.
   - Bundle identifier and Team ID match App Store Connect app record.

- **Privacy and permissions**
   - `Info.plist` usage strings are present for every permission your app touches.
   - App Privacy answers in App Store Connect match actual data behavior.

- **Binary hardening and integrity**
   - Release build only (`flutter build ipa --release`).
   - No debug flags/logging toggles enabled for production.
   - Dependencies are up-to-date and from trusted sources.

- **App icon / asset validation**
   - No alpha channel in iOS app icons if App Store validation rejects it (`remove_alpha_ios: true`).
   - Launch screen assets render correctly on light/dark mode.

- **Runtime trust and warnings**
   - For App Store distribution, Apple signing avoids Gatekeeper warnings on user devices.
   - For direct macOS distribution outside App Store, sign with Developer ID and notarize (`notarytool`) to avoid security warnings.

- **Submission hygiene**
   - TestFlight smoke test on real devices before review submission.
   - Crash-free startup and core chat flow validated.

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

## 7) Web Release (WASM)

The web build produces static files served by any web server. No server-side code.

Steps:
1. Build release with WASM:

```bash
flutter build web --wasm --release
```

2. Test locally:

```bash
cd build/web && python3 -m http.server 8080
# → Open http://localhost:8080 and verify app loads
```

3. Deploy via Docker:

```bash
docker compose -f compose.web.yaml build
docker compose -f compose.web.yaml up -d
```

4. Or deploy to Vercel (pre-built, no server-side build):

```bash
cd build/web && npx vercel --prod
```

The project includes a `vercel.json` that handles SPA routing, COOP/COEP headers, and caching — no additional configuration needed. Do NOT build on Vercel (Flutter is not available there). Always deploy the pre-built `build/web/` output.

5. Or deploy to other static hosting (Cloudflare Pages, Netlify, etc.):

```bash
cd build/web && vercel --prod
```

Notes:
- Ensure `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers are set (required for SQLite WASM / OPFS).
- CORS must be configured on the Coqui API server (`--cors-origin`).
- See [docs/WEB.md](docs/WEB.md) for full deployment documentation.

## 8) Final Verification Matrix

Before publishing, validate:
- Fresh install works.
- Existing-user upgrade works.
- API connectivity and auth errors are user-friendly.
- Role selection and chat flow work.
- Tool output rendering and session persistence work.
- App icon and splash assets render correctly on device.
- Web: WASM loads in Chrome, Firefox, Safari.
- Web: SQLite WASM storage persists across page reloads.
- Web: PWA install works ("Add to Home Screen").

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
flutter build web --wasm --release # Web (WASM)
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
