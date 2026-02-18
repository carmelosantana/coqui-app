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

## License

GPL-3.0
