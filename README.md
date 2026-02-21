# Coqui

Cross-platform Flutter client for the [Coqui](https://github.com/AgentCoqui/coqui) AI agent.

Connect to a Coqui API server, manage sessions, and chat with your agent in real-time via SSE streaming. Supports multiple server instances with role-based session creation.

## Platforms

- Linux
- macOS
- Windows
- Android
- iOS

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
```

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

## Icon Padding Script

Use [scripts/pad-icon.sh](scripts/pad-icon.sh) to shrink artwork inside a PNG canvas (transparent padding around it).

```bash
# Keep 84% inner artwork size and overwrite image
./scripts/pad-icon.sh --image assets/images/coqui-icon.png --inner-size 84%

# Or set explicit padding per side and keep a backup
./scripts/pad-icon.sh --image assets/images/coqui-icon.png --padding 10 --backup
```

After padding, regenerate app icons:

```bash
flutter pub run flutter_launcher_icons
```

## License

GPL-3.0
