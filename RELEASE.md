# Coqui App Release Guide

Complete release automation for iOS (TestFlight), macOS (signed DMG), Android (APK), Linux, Windows, and Web (Vercel WASM).

## Quick Start

```bash
# First time — set up all signing certificates and secrets
scripts/release.sh setup

# Release a new version
scripts/release.sh tag patch        # 0.0.1 → 0.0.2 → CI builds everything

# Upload iOS to TestFlight
scripts/release.sh publish
```

## First-Time Setup

The setup wizard walks you through everything interactively. Run it once on your Mac:

```bash
scripts/release.sh setup
```

This covers:

1. **Prerequisites check** — Xcode, Flutter, Java, GitHub CLI
2. **Apple Distribution certificate** — generates CSR, guides you through Apple Developer portal, imports cert, exports `.p12`
3. **App-specific password** — for notarization and TestFlight uploads
4. **Provisioning profiles** — iOS Distribution + macOS Developer ID
5. **Android keystore** — generates `.jks`, creates `key.properties`
6. **GitHub secrets** — pushes all 15 secrets via `gh secret set`
7. **Vercel tokens** — for web deployment to `app.coquibot.ai`

All signing artifacts are stored in `~/.coqui-release/` (outside the repo, survives clones). You can re-run any step independently:

```bash
scripts/release-setup.sh apple       # Apple certificates only
scripts/release-setup.sh profiles    # Provisioning profiles only
scripts/release-setup.sh android     # Android keystore only
scripts/release-setup.sh github      # Push secrets to GitHub
scripts/release-setup.sh vercel      # Vercel deployment setup
scripts/release-setup.sh verify      # Dashboard of all requirements
```

## Release Workflow

### 1. Tag a Release

```bash
scripts/release.sh tag patch         # 0.0.1 → 0.0.2
scripts/release.sh tag minor         # 0.0.2 → 0.1.0
scripts/release.sh tag major         # 0.1.0 → 1.0.0
scripts/release.sh tag 2.0.0         # Explicit version
```

This command:

- Validates the codebase (`flutter analyze` + `flutter test`)
- Bumps the version in `pubspec.yaml`
- Commits and tags `vX.Y.Z`
- Pushes to GitHub (triggers CI)

### 2. CI Builds Everything

Pushing a `v*` tag triggers `.github/workflows/release.yml`:

```
Tag push → Validate → Build 6 platforms (parallel) → GitHub Release → Vercel deploy
```

| Platform | Artifact | Distribution |
|----------|----------|-------------|
| Android | `Coqui-{ver}-android.apk` | GitHub Release (sideload) |
| macOS | `Coqui-{ver}-macos-arm64.dmg` | GitHub Release (signed + notarized) |
| iOS | `Coqui-{ver}-ios.ipa` | TestFlight (uploaded separately) |
| Linux | `Coqui-{ver}-linux-x64.tar.gz` | GitHub Release |
| Windows | `Coqui-{ver}-windows-x64.zip` | GitHub Release |
| Web | WASM | Vercel (`app.coquibot.ai`) |

All artifacts include SHA-256 checksums in `SHA256SUMS.txt`.

### 3. Publish iOS to TestFlight

After CI produces the IPA (or after a local build):

```bash
scripts/release.sh publish
```

This validates the IPA and uploads it to App Store Connect via `xcrun altool`. The script guides you through first-time App Store Connect setup if needed.

### 4. Check Status

```bash
scripts/release.sh status
```

Shows current version, signing readiness, git state, and next steps.

## Local Builds

Build signed artifacts locally without pushing to GitHub:

```bash
scripts/release.sh build --platform macos    # Signed + notarized DMG
scripts/release.sh build --platform ios      # Signed IPA
scripts/release.sh build --platform android  # Signed APK
scripts/release.sh build --platform web      # WASM build
scripts/release.sh build --platform all      # All supported on this OS
```

The build command validates signing prerequisites before building and provides clear remediation steps if anything is missing.

For local iOS builds, the script uses `ios/ExportOptions.plist` when an iOS provisioning profile is configured. If no local profile is configured, it falls back to automatic App Store export using your configured Apple team ID. CI still expects the provisioning profile secrets documented below.

## Required GitHub Secrets

The setup wizard (`scripts/release-setup.sh github`) pushes all of these automatically:

| Secret | Source | Purpose |
|--------|--------|---------|
| `APPLE_CERTIFICATE_P12` | `.p12` export from Keychain | Code signing (iOS + macOS) |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the `.p12` | Unlock cert in CI |
| `APPLE_TEAM_ID` | Apple Developer account | Certificate identity |
| `APPLE_ID` | Your Apple ID email | Notarization + TestFlight |
| `APPLE_APP_SPECIFIC_PASSWORD` | appleid.apple.com | Notarization + TestFlight |
| `KEYCHAIN_PASSWORD` | Auto-generated random | CI temp keychain |
| `IOS_PROVISIONING_PROFILE` | Apple Developer portal | iOS app signing |
| `MACOS_PROVISIONING_PROFILE` | Apple Developer portal | macOS DMG signing |
| `ANDROID_KEYSTORE_BASE64` | Generated `.jks` | Android APK signing |
| `ANDROID_KEYSTORE_PASSWORD` | Chosen during setup | Unlock keystore |
| `ANDROID_KEY_ALIAS` | `coqui` (default) | Key within keystore |
| `ANDROID_KEY_PASSWORD` | Chosen during setup | Unlock key |
| `VERCEL_TOKEN` | vercel.com/account/tokens | Web deployment |
| `VERCEL_ORG_ID` | Vercel project settings | Web deployment |
| `VERCEL_PROJECT_ID` | Vercel project settings | Web deployment |

## App Store Connect First Submission

The very first iOS release requires creating an app record:

1. Go to [App Store Connect](https://appstoreconnect.apple.com/apps)
2. Click **+** → **New App**
3. Fill in:
   - Platform: **iOS**
   - Name: **Coqui**
   - Primary Language: **English (US)**
   - Bundle ID: **ai.coquibot.app**
   - SKU: **coqui-app**
4. Complete the app information:
   - **Privacy**: describe data collection (Coqui stores all data locally — no server-side tracking)
   - **Age Rating**: complete the questionnaire
   - **Category**: Developer Tools
5. On the Version page:
   - Add screenshots for required device sizes
   - Write description, keywords, support URL
   - Set pricing

The `scripts/release.sh publish` command prints this checklist and provides the direct URLs.

### Screenshots

Take screenshots from the iOS Simulator (`Simulator → File → Save Screen` or `⌘S`):

| Device | Size | Required |
|--------|------|----------|
| iPhone 15 Pro Max (6.7") | 1290 × 2796 | Yes |
| iPhone 14 Plus (6.5") | 1284 × 2778 | Yes (or use 6.7") |
| iPad Pro 12.9" | 2048 × 2732 | If iPad-compatible |

## CI/CD Pipeline

### Continuous Integration (`ci.yml`)

Every push to `main` and every PR:

1. **Analyze & Test** — `flutter analyze` + `flutter test`
2. **Build Android** (smoke) — debug APK
3. **Build iOS** (smoke) — debug build, no codesign
4. **Build Web** (smoke) — WASM release

### Release Pipeline (`release.yml`)

Triggered by `v*` tag:

1. **Validate** — analyze + test (gates all builds)
2. **Build** — 6 platforms in parallel (Android, macOS, iOS, Linux, Windows, Web)
3. **Release** — GitHub Release with all artifacts + checksums
4. **Deploy** — Web build to Vercel production

## Icon Pipeline

Each platform uses a different source icon:

| Platform | Source | Rationale |
|----------|--------|-----------|
| macOS | `coqui-icon-macos.png` (auto-padded) | Sequoia/Tahoe dock sizing |
| iOS | `coqui.png` | No alpha (App Store requirement) |
| Android | `coqui-icon.png` | Round corners, adaptive mask |
| Windows | `coqui.png` | Square `.ico` |
| Linux | `coqui-icon.png` | Round corners with alpha |

Regenerate all icons: `make icons`

## Build Recovery

When builds break after updates:

```bash
make fix-ios       # Clean + reinstall CocoaPods + clear Xcode cache
make fix-android   # Clean + Gradle clean
make rebuild       # Full clean rebuild from scratch
```

Or use the build script with `--clean`:

```bash
./scripts/build.sh --platform macos --mode debug --clean
```

## Troubleshooting

### "No signing identity found"

Run `scripts/release-setup.sh apple` to create or select a certificate. If you have a certificate but it's not detected, open Keychain Access and verify it's in "My Certificates" with a green checkmark.

### "Provisioning profile doesn't match"

The profile must match both the bundle ID (`ai.coquibot.app`) and the signing certificate. Download a new profile from the Apple Developer portal that references your current certificate: `scripts/release-setup.sh profiles`

### "keytool not found"

Install Java JDK 17+: `brew install openjdk@17`

### iOS build fails with "No such module 'Flutter'"

```bash
make fix-ios
```

### Android signing fails locally

Verify `android/key.properties` exists and points to a valid keystore:

```bash
cat android/key.properties
```

If missing, run: `scripts/release-setup.sh android`

### CI build fails

1. Check that all GitHub secrets are set: `scripts/release-setup.sh verify`
2. Look at the specific failing job in GitHub Actions for error details
3. Common issue: expired certificates — re-run `scripts/release-setup.sh apple` and `scripts/release-setup.sh github`

### TestFlight upload fails

- **Authentication error**: regenerate app-specific password at [appleid.apple.com](https://appleid.apple.com/account/manage)
- **Bundle ID mismatch**: ensure App Store Connect app record uses `ai.coquibot.app`
- **Version already exists**: bump the version with `scripts/release.sh tag patch`
- **Alternative upload**: use Transporter (free on Mac App Store) — drag and drop the `.ipa` file

## Makefile Targets

```bash
make release-setup    # Run setup wizard
make release-status   # Show release readiness
make release-verify   # Verify all signing requirements
make release-build    # Build all platforms
make release-tag      # Tag and push (prompts for version)
make release-publish  # Upload iOS to TestFlight
```
