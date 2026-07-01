#!/usr/bin/env bash
#
# Maintainer release build. Produces a universal (arm64 + x86_64) app bundle and
# bridge binary, ad-hoc signs them, and packs dist/Orca.tar.gz — the artifact
# that install.sh downloads from a GitHub Release.
#
#   ./scripts/release.sh              # just build dist/Orca.tar.gz
#   ./scripts/release.sh v0.1.0       # also create the GitHub release (needs gh)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
ARCHS=(--arch arm64 --arch x86_64)

rm -rf "$DIST"; mkdir -p "$DIST"

echo "==> Building universal app..."
swift build --package-path "$ROOT/app" -c release "${ARCHS[@]}"
APPBIN="$(swift build --package-path "$ROOT/app" -c release "${ARCHS[@]}" --show-bin-path)/Orca"

echo "==> Building universal bridge..."
swift build --package-path "$ROOT/bridge" -c release "${ARCHS[@]}"
BRIDGEBIN="$(swift build --package-path "$ROOT/bridge" -c release "${ARCHS[@]}" --show-bin-path)/orca"

echo "==> Assembling app bundle..."
APP="$DIST/Orca.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$APPBIN" "$APP/Contents/MacOS/Orca"
cp "$ROOT/app/Info.plist" "$APP/Contents/Info.plist"
[ -f "$ROOT/app/AppIcon.icns" ] && cp "$ROOT/app/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"
cp "$BRIDGEBIN" "$DIST/orca"

echo "==> Packing tarball..."
( cd "$DIST" && tar -czf Orca.tar.gz Orca.app orca )
echo "    dist/Orca.tar.gz"
lipo -info "$APP/Contents/MacOS/Orca" 2>/dev/null || true

TAG="${1:-}"
if [ -n "$TAG" ]; then
  if command -v gh >/dev/null 2>&1; then
    echo "==> Creating GitHub release $TAG..."
    gh release create "$TAG" "$DIST/Orca.tar.gz" --title "$TAG" --generate-notes
  else
    echo "!! gh CLI not found. Run manually: gh release create $TAG dist/Orca.tar.gz"
  fi
else
  echo "==> To publish:  gh release create v0.1.0 dist/Orca.tar.gz --generate-notes"
fi
