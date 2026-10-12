#!/usr/bin/env bash
# Builds build/Flower.app from the Swift package.
#
#   scripts/build-app.sh               # release build, signed with the first valid "Apple Development" identity
#   SIGN_IDENTITY=- scripts/build-app.sh   # ad-hoc signing (Screen Recording permission resets on every rebuild)
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${CONFIG:-release}"
APP="build/Flower.app"
WEB_SRC="Resources/WebServer"
ICON_SRC="Resources/AppIcon.png"  # regenerate with: swift scripts/make-icon.swift Resources/AppIcon.png

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Flower" "$APP/Contents/MacOS/Flower"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R "$WEB_SRC" "$APP/Contents/Resources/WebServer"

# App icon from the 1024px source.
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256; do
    sips -z "$size" "$size" "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
sips -z 512 512 "$ICON_SRC" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$ICON_SRC" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# A stable signing identity keeps the Screen Recording grant across rebuilds.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Apple Development/ && !/REVOKED/ { print $2; exit }')}"
IDENTITY="${IDENTITY:--}"
codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"

echo "Built $APP (signed with: $IDENTITY)"
