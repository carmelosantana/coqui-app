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
