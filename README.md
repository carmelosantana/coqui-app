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
