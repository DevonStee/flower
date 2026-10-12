<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="Flower icon">
</p>

<h1 align="center">Flower</h1>

<p align="center">
  Share your Mac's screen to any browser on your local network.<br>
  No client app, no account, no internet connection.
</p>

<p align="center">
  <a href="README.zh-CN.md">中文</a> ·
  <a href="https://github.com/DevonStee/flower/actions/workflows/ci.yml"><img src="https://github.com/DevonStee/flower/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-15%2B-blue" alt="macOS 15+">
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6">
  <img src="https://img.shields.io/badge/license-GPLv3-green" alt="GPL v3">
</p>

---

Flower runs quietly in your menu bar. Start the server, and anyone on the same Wi-Fi can open the URL on a phone, tablet, or another computer to watch your screen live. It's handy for showing slides in a meeting room, mirroring a demo to a TV browser, or letting a colleague follow along without installing anything.

## Features

- **Browser-only viewers.** Any modern browser works; the page adapts to phones.
- **Works offline.** Traffic stays on your local network and never touches the internet.
- **Private sessions.** Optionally require a username and password (HTTP Basic auth).
- **Local subnet only by default.** Clients outside your subnet are rejected unless you allow them.
- **Multiple displays.** Pick which display to share, with or without the mouse pointer.
- **Tunable.** Capture interval and JPEG quality are adjustable while sharing.
- **Stays out of the way.** A single small dot in the menu bar (or no icon at all), plus optional launch at login and auto-start.
- **Native and lightweight.** Swift, ScreenCaptureKit, and Network.framework, with no third-party dependencies.

## Requirements

- macOS 15 Sequoia or later
- To build: Xcode 16+ (Swift 6 toolchain)

## Install

There are no prebuilt releases yet, so you build from source:

```bash
git clone https://github.com/DevonStee/flower.git
cd flower
scripts/build-app.sh
mv build/Flower.app /Applications/
open /Applications/Flower.app
```

`build-app.sh` signs the app with the first valid **Apple Development** certificate in your keychain. If you don't have one, it falls back to ad-hoc signing, which works but means macOS asks for Screen Recording permission again after every rebuild (see [FAQ](#faq)).

## Usage

1. Click the **dot** in the menu bar and choose **Start Server**.
2. The first time, macOS asks for **Screen Recording** permission. Enable Flower in
   *System Settings → Privacy & Security → Screen & System Audio Recording*, then quit and reopen Flower.
3. Start the server again. The menu shows a URL like `http://192.168.1.20:7070`.
4. Open that URL in a browser on any device on the same network.

The dot is solid while sharing and faint while stopped.

### Settings

| Setting | Description |
|---|---|
| IP address / Port | Interface and port to serve on (default port `7070`) |
| Allow access from outside the local subnet | Off by default; when off, only same-subnet and localhost clients can connect |
| Display | Which screen to share |
| Capture every (ms) | Frame interval; lower is smoother but uses more CPU |
| Image quality | JPEG quality, from 10% to 100% |
| Show mouse pointer | Include the cursor in the stream |
| Require username and password | Private session; the password is stored in the Keychain |
| Start server automatically | Start sharing as soon as Flower launches |
| Launch at login | Open Flower when you log in |
| Show icon in menu bar | Hide the menu bar icon entirely |

**Hidden the icon?** Open Flower again from Spotlight, Launchpad, or the Applications folder, and the settings window appears.

## Security notes

- Flower serves plain **HTTP**. Basic auth credentials and the image stream are **not encrypted**, so use it only on networks you trust.
- With the subnet restriction on (the default), connections from other subnets are dropped before any request is read.
- Static files are served only from the bundled web UI folder; path traversal is rejected.

## FAQ

**I granted Screen Recording permission but the screen is still blank.**
macOS only applies the permission after a relaunch. Quit Flower from its menu and open it again.

**Do I need to grant permission again after rebuilding?**
Not if the app is signed with a real certificate. macOS ties the permission to the app's *signing identity* (bundle ID `com.jiaqi.flower` plus your certificate), not to the binary itself. With ad-hoc signing (`SIGN_IDENTITY=-`), the identity is a hash of the binary, so every rebuild counts as a new app.

**Other devices can't connect.**
- Make sure both devices are on the same network and you picked the right interface in Settings.
- If the macOS firewall is on, allow incoming connections for Flower when prompted.
- Guest Wi-Fi networks often isolate clients from each other.

**Port already in use?**
Flower offers to switch to a random free port.

## Development

```bash
swift build                                          # debug build
swift test                                           # unit tests plus a loopback HTTP server test
scripts/build-app.sh                                 # release .app bundle in build/
swift scripts/make-icon.swift Resources/AppIcon.png  # regenerate the app icon
```

You don't need network access or API keys to run the tests.

### Project layout

```
Sources/FlowerCore/    Platform-agnostic core: HTTP parsing, routing, Basic auth,
                       access policy, settings, Network.framework server
Sources/Flower/        Menu bar app: SwiftUI, ScreenCaptureKit capture, Keychain
Tests/FlowerCoreTests/ Swift Testing suites
Resources/             Info.plist, app icon, web viewer (WebServer/)
scripts/               build-app.sh, make-icon.swift
```

### How it works

ScreenCaptureKit streams the selected display at the configured interval. Each complete frame is encoded to JPEG and kept in memory. A small HTTP/1.1 server built on Network.framework, bound to the chosen interface, serves the web viewer and the latest frame at `/frame.jpg`. The viewer polls that image in a loop.

## Credits

Flower is a macOS rewrite of [**ScreenTask**](https://github.com/EslaMx7/ScreenTask) by Eslam Hamouda and Wagih ElBedeawi, originally a Windows/.NET app. The web viewer is adapted from the original project.

## License

[GNU General Public License v3.0](LICENSE), the same license as the original ScreenTask.
