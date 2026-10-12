# Flower

A native macOS port of [ScreenTask](https://github.com/EslaMx7/ScreenTask) by Eslam Hamouda: share your screen to any browser on the local network, no client software needed. Menu bar app, Swift 6, no third-party dependencies. Requires macOS 15+.

## Build & run

```bash
scripts/build-app.sh          # -> build/Flower.app
open build/Flower.app
swift scripts/make-icon.swift Resources/AppIcon.png   # regenerate the app icon
swift test                    # unit + loopback server tests, no network/API keys needed
```

On first **Start Server**, macOS asks for Screen Recording permission. Grant it in
System Settings → Privacy & Security → Screen & System Audio Recording, then relaunch the app.
The build script signs with your first valid "Apple Development" identity so the grant survives rebuilds
(`SIGN_IDENTITY=-` for ad-hoc signing, which loses the grant on every rebuild).

## Mapping from the Windows version

| Windows (WinForms / .NET) | macOS |
|---|---|
| GDI `CopyFromScreen` + `DrawIconEx` cursor | ScreenCaptureKit `SCStream` (`showsCursor`) |
| JPEG written to disk + `ReaderWriterLock` | Latest JPEG kept in memory (`FrameStore`) |
| `HttpListener` | `Network.framework` listener bound to the selected IP (`HTTPServer`) |
| `netsh` firewall rule (localsubnet / any) | `AccessPolicy`: only same-subnet + loopback clients unless "Allow access from outside the local subnet" |
| `appsettings.xml` next to the exe | `UserDefaults`; password in the Keychain |
| Tray icon + window | `MenuBarExtra` + settings window |
| Auto start / start minimized | Start server automatically / Launch at login (`SMAppService`) |

The web UI lives in `Resources/WebServer` (rebranded copy of the original) and is copied into the bundle at build time.
The menu bar icon is a single dot: solid while sharing, faint while stopped.
Dropped: GitHub update check, firewall elevation. Fixed along the way: path traversal in static file serving,
logging of attempted passwords on bad logins.

## Layout

- `Sources/FlowerCore` – HTTP parsing/serialization, routing, Basic auth, settings, interfaces, server
- `Sources/Flower` – SwiftUI app, ScreenCaptureKit capture, Keychain
- `Tests/FlowerCoreTests` – Swift Testing suites

License: GPL v3 (same as the original).
