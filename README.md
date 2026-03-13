# Coqui

Cross-platform Flutter client for the [Coqui](https://github.com/AgentCoqui/coqui) AI agent.

Connect to a Coqui API server, manage sessions, and chat with your agent in real-time via SSE streaming. Supports multiple server instances with role-based session creation.

## Platforms

- Linux
- macOS
- Windows
- Android
- iOS
- Web (WASM)

## Downloads

Download the latest release from [GitHub Releases](https://github.com/AgentCoqui/coqui-app/releases/latest):

| Platform | Download | Notes |
|----------|----------|-------|
| Android | `Coqui-*-android.apk` | Sideload APK |
| macOS | `Coqui-*-macos-arm64.dmg` | Signed and notarized |
| Windows | `Coqui-*-windows-x64.zip` | Extract and run `coqui.exe` |
| Linux | `Coqui-*-linux-x64.tar.gz` | Extract and run `./coqui` |
| iOS | `Coqui-*-ios.ipa` | Install via TestFlight |
| Web | [app.coquibot.ai](https://app.coquibot.ai) | No install needed |

All release artifacts include SHA-256 checksums in `SHA256SUMS.txt`.

## Getting Started

1. Make sure you have a running [Coqui API server](https://github.com/AgentCoqui/coqui).
2. Clone this repo and run the app:

```bash
flutter pub get
flutter run
```

3. Open **Settings**, add your Coqui server URL and API key, and test the connection.
4. Start a new chat by selecting a role.

## Building

```bash
# Linux
flutter build linux

# macOS
flutter build macos

# Windows
flutter build windows

# Android
flutter build apk

# iOS
flutter build ios

# Web (WASM)
flutter build web --wasm --release
```

## Web

The app runs in the browser as a WebAssembly (WASM) application. No server-side code — everything runs client-side.

### Quick Start

```bash
# Build and serve locally
make web-serve    # → http://localhost:8080

# Or build manually
flutter build web --wasm --release
cd build/web && python3 -m http.server 8080
```

### Docker Deployment

```bash
# Build and start (nginx:alpine, ~10MB image)
make docker-web-build
make docker-web-start    # → http://localhost:8080

# Custom port
COQUI_WEB_PORT=3000 docker compose -f compose.web.yaml up -d
```

### Vercel / Static Hosting

The build output (`build/web/`) is static files deployable to Vercel, Netlify, Cloudflare Pages, GitHub Pages, S3, or any static host.

```bash
flutter build web --wasm --release
cd build/web && vercel --prod
```

### Browser Requirements

WASM-GC required: Chrome 119+, Firefox 120+, Safari 18.2+, Edge 119+.

### Local Storage

All data stays in the browser:
- **SQLite WASM (OPFS)** — cached sessions and messages for offline viewing
- **Hive (IndexedDB)** — server configurations, API keys, user preferences

No cookies, no tracking, no server-side state. See [docs/WEB.md](docs/WEB.md) for full details.

## Unified Build Script

Use [scripts/build.sh](scripts/build.sh) to run icon prep, launcher icon generation, build, and artifact opening in one command.

```bash
# macOS debug build (default icon pipeline enabled)
./scripts/build.sh --platform macos --mode debug

# iOS release build (builds IPA and opens output folder)
./scripts/build.sh --platform ios --mode release

# Android release build (builds .aab and opens output folder)
./scripts/build.sh --platform android --mode release

# Run all targets possible from current host
./scripts/build.sh --platform all --mode debug

# Custom icon sizing before build
./scripts/build.sh --platform macos --mode release --inner-size 82%
```

Notes:
- `--platform all` skips unsupported targets on the current host with warnings.
- Windows desktop builds require a Windows host (or CI runner). Wine cross-build is not a reliable Flutter desktop release path.
- Use `--no-icons` to skip icon padding + launcher icon generation.

## Testing Android APK

Build Android debug APK:

```bash
./scripts/build.sh --platform android --mode debug --no-icons
```

Start emulator:

```bash
~/Library/Android/sdk/emulator/emulator -list-avds
~/Library/Android/sdk/emulator/emulator -avd Medium_Phone_API_36.1
```

Install APK to emulator/device:

```bash
~/Library/Android/sdk/platform-tools/adb devices
~/Library/Android/sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Launch app from terminal:

```bash
~/Library/Android/sdk/platform-tools/adb shell monkey -p ai.coquibot.app.debug -c android.intent.category.LAUNCHER 1
```

Tip: you can also drag `build/app/outputs/flutter-apk/app-debug.apk` onto a running emulator window.

## Testing iOS Build / IPA

Debug iOS app build (device-signed):

```bash
./scripts/build.sh --platform ios --mode debug --no-icons
```

This outputs `build/ios/iphoneos/Runner.app`.
To test on a physical iPhone, connect device and install via Xcode (`Window` → `Devices and Simulators`) or run directly with Flutter/Xcode.

Release IPA build:

```bash
./scripts/build.sh --platform ios --mode release --no-icons
```

This outputs to `build/ios/ipa`.

IPA testing options:
- Upload to TestFlight (recommended): use Transporter or Xcode Organizer, then install via TestFlight.
- Direct device install (ad hoc/dev signed IPA): use Apple Configurator 2.

Note: IPA files do not run on iOS Simulator.

## Icon Pipeline

Each platform uses a different source icon to meet platform-specific requirements:

| Platform | Source | Rationale |
|----------|--------|----------|
| macOS | `coqui-icon-macos.png` (auto-generated) | Padded to 83% inner size for Sequoia/Tahoe dock requirements |
| iOS | `coqui.png` | Square, no alpha (App Store rejects alpha) |
| Android | `coqui-icon.png` | Round corners; OS applies adaptive mask |
| Windows | `coqui.png` | Square .ico |
| Linux | `coqui-icon.png` | Round corners with alpha |

Regenerate all icons (pads macOS icon + runs flutter_launcher_icons):

```bash
make icons
```

The macOS padded icon is generated automatically and never overwrites the source `coqui-icon.png`.

### Icon Padding Script

Use [scripts/pad-icon.sh](scripts/pad-icon.sh) to generate a padded PNG (transparent padding around artwork). This is only needed for macOS icons.

```bash
# Generate macOS padded icon at 83% inner size (default for build pipeline)
./scripts/pad-icon.sh --image assets/images/coqui-icon.png --inner-size 83% --output assets/images/coqui-icon-macos.png

# Custom padding percentage
./scripts/pad-icon.sh --image assets/images/coqui-icon.png --padding 10 --output assets/images/coqui-icon-macos.png
```

## CI/CD

### Continuous Integration

Every push to `main` and every pull request runs the CI pipeline (`.github/workflows/ci.yml`):

1. **Analyze & Test** — `flutter analyze` + `flutter test`
2. **Build Android** (smoke test) — `flutter build apk --debug`
3. **Build iOS** (smoke test) — `flutter build ios --debug --no-codesign`
4. **Build Web** (smoke test) — `flutter build web --wasm --release`

Build jobs only run after analysis and tests pass.

### Releases

Pushing a `v*` tag triggers the release pipeline (`.github/workflows/release.yml`):

1. **Validate** — `flutter analyze` + `flutter test` (blocks all builds if failing)
2. **Build** — Android APK, macOS DMG (signed + notarized), iOS IPA, Linux tar.gz, Windows zip, Web WASM — all in parallel
3. **Release** — Creates a GitHub Release with all artifacts and SHA-256 checksums
4. **Deploy** — Deploys the web build to Vercel (`app.coquibot.ai`)

See [RELEASE.md](RELEASE.md) for the full release checklist.

## Troubleshooting

### iOS: "No such module 'Flutter'"

This occurs when Xcode's module cache is stale or CocoaPods artifacts are out of sync with the Flutter SDK.

```bash
make fix-ios
```

This runs: `flutter clean` → `flutter pub get` → reinstall CocoaPods → clear Xcode derived data.

After running, always open `ios/Runner.xcworkspace` (not `.xcodeproj`) in Xcode.

If the error persists:

1. Close Xcode completely
2. Run `make fix-ios` again
3. Reopen `ios/Runner.xcworkspace`
4. Product → Clean Build Folder (Shift+Cmd+K)
5. Build (Cmd+B)

### Android: Build failures after SDK update

```bash
make fix-android
```

This runs: `flutter clean` → `flutter pub get` → `./gradlew clean`.

Note: `android/key.properties` is only needed for release builds (CI creates it from secrets). Debug builds work without it.

### Web: WASM fails to load / blank screen

SQLite WASM requires `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers. If using a custom server, ensure these headers are set:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

The included `vercel.json`, `nginx.conf`, and Docker setup handle this automatically.

### General: Full clean rebuild

```bash
make rebuild    # flutter clean + full setup from scratch
```

Or with the build script:

```bash
./scripts/build.sh --platform macos --mode debug --clean
```

The `--clean` flag runs `flutter clean`, reinstalls dependencies, and cleans platform-specific caches before building.

## License

GPL-3.0
