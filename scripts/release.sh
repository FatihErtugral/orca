#!/usr/bin/env bash
#
# Maintainer release build. Produces a per-architecture app bundle and bridge
# binary for arm64 (Apple Silicon) and x86_64 (Intel), ad-hoc signs them, and
# packs dist/Orca-<arch>.tar.gz — the assets the per-arch installers download.
#
#   ./scripts/release.sh              # build dist/Orca-{arm64,x86_64}.tar.gz
#   ./scripts/release.sh v0.1.1       # also create the GitHub release (needs gh)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
rm -rf "$DIST"; mkdir -p "$DIST"

build_arch() {
  local arch="$1"
  echo "==> Building app ($arch)..."
  swift build --package-path "$ROOT/app" -c release --arch "$arch"
  local appbin
  appbin="$(swift build --package-path "$ROOT/app" -c release --arch "$arch" --show-bin-path)/Orca"

  echo "==> Building bridge ($arch)..."
  swift build --package-path "$ROOT/bridge" -c release --arch "$arch"
  local bridgebin
  bridgebin="$(swift build --package-path "$ROOT/bridge" -c release --arch "$arch" --show-bin-path)/orca"

  local stage="$DIST/$arch"
  local app="$stage/Orca.app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$appbin" "$app/Contents/MacOS/Orca"
  cp "$ROOT/app/Info.plist" "$app/Contents/Info.plist"
  [ -f "$ROOT/app/AppIcon.icns" ] && cp "$ROOT/app/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
  codesign --force --deep --sign - "$app"
  cp "$bridgebin" "$stage/orca"

  ( cd "$stage" && tar -czf "$DIST/Orca-$arch.tar.gz" Orca.app orca )
  echo "    dist/Orca-$arch.tar.gz"
}

build_arch arm64
build_arch x86_64

TAG="${1:-}"
if [ -n "$TAG" ]; then
  CODE_VERSION="$(grep -o 'current = "[0-9.]*"' "$ROOT/bridge/Sources/OrcaBridgeCore/OrcaVersion.swift" | grep -o '[0-9.]*')"
  PLIST_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/app/Info.plist")"
  if [ "$TAG" != "v$CODE_VERSION" ] || [ "$TAG" != "v$PLIST_VERSION" ]; then
    echo "error: tag $TAG != code v$CODE_VERSION / plist v$PLIST_VERSION — bump OrcaVersion.current and Info.plist first" >&2
    exit 1
  fi
fi

if [ -n "$TAG" ]; then
  if command -v gh >/dev/null 2>&1; then
    echo "==> Creating GitHub release $TAG..."
    gh release create "$TAG" "$DIST/Orca-arm64.tar.gz" "$DIST/Orca-x86_64.tar.gz" --title "$TAG" --generate-notes
  else
    echo "!! gh CLI not found. Run manually: gh release create $TAG dist/Orca-arm64.tar.gz dist/Orca-x86_64.tar.gz"
  fi
else
  echo "==> To publish:  gh release create v0.1.1 dist/Orca-arm64.tar.gz dist/Orca-x86_64.tar.gz --generate-notes"
fi
