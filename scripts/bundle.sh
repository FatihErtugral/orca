#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/app"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/Orca.app"

echo "==> Building Orca (release)..."
swift build --package-path "$APP_DIR" -c release

BIN_PATH="$(swift build --package-path "$APP_DIR" -c release --show-bin-path)/Orca"

echo "==> Assembling ${APP_BUNDLE}..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/Orca"
cp "$APP_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
[ -f "$APP_DIR/AppIcon.icns" ] && cp "$APP_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "==> Ad-hoc code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
echo "    Run with:  open \"$APP_BUNDLE\""
