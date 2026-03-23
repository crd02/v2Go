# v2Go

A cross-platform proxy client built with Flutter, powered by [Xray-core](https://github.com/XTLS/Xray-core) and [sing-box](https://github.com/SagerNet/sing-box).

<img width="884" height="639" alt="image" src="https://github.com/user-attachments/assets/ce58cbe6-233a-4f13-bcdd-ab539831e2a8" />

<img width="884" height="639" alt="image" src="https://github.com/user-attachments/assets/3e105c42-37f4-453f-9b5a-bd18187c36a7" />

<img width="884" height="639" alt="image" src="https://github.com/user-attachments/assets/9f6ef3c3-b372-4983-8c06-16e5d36d5fd5" />

## Features

- **Multiple proxy modes**: System proxy, TUN mode, or no proxy
- **Xray-core integration**: Supports VMess and other Xray protocols
- **TUN mode**: Full traffic routing via sing-box
- **Real-time statistics**: Live traffic speed chart, upload/download monitoring
- **Latency testing**: Per-server latency measurement with auto-refresh
- **IP location detection**: Displays current exit IP and geolocation after connecting
- **Server management**: Add, edit, and switch between multiple server configs
- **Auto-connect**: Remembers and reconnects to the last selected server on startup
- **Routing rules**: Configurable routing rules (proxy / direct / block)
- **System tray**: Minimize to tray, quick connect/disconnect
- **Fluent UI**: Windows-native look and feel using fluent_ui

## Supported Platforms

| Platform | Status |
|----------|--------|
| Windows  | ✅ Supported |
| Linux    | 🚧 Planned |
| macOS    | 🚧 Planned |
| Android  | 🚧 Planned |

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.10
- Windows 10/11 (for full feature support)

### Build

```bash
flutter pub get
flutter run -d windows
```

### Bundled Binaries

The `bin/` directory contains the required runtime binaries:

- `xray.exe` — Xray-core proxy engine
- `sing-box.exe` — sing-box for TUN mode
- `geoip.dat` / `geosite.dat` — routing rule data files

## Architecture

```
lib/
├── core/           # Database and config models
├── features/       # UI pages (home, server, routing, settings, logs)
├── managers/       # Business logic (ConnectManager, LogManager, etc.)
├── models/         # Data models (V2RayConfig, SingboxConfig, etc.)
├── services/       # System proxy, latency test, traffic stats, IP location
├── utils/          # Config generators and helpers
└── widgets/        # Reusable UI components
```

## Configuration

Server configurations are stored in a local SQLite database (`v2ray_servers.db`). The active running config is written to `config/config-running.json` before each connection.

## License

MIT
