#!/usr/bin/env bash
#
# Install from source (for a cloned repo — requires Xcode/Swift).
# Builds, installs the binary and app, adds hooks, and launches.
#
#   ./scripts/dev-install.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$HOME/.local/bin"
APP_DEST="/Applications/Orca.app"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: 'swift' not found. Install Xcode / Command Line Tools: xcode-select --install" >&2
  exit 1
fi

echo "==> Building..."
make -C "$ROOT" all

echo "==> Bridge -> $BIN_DIR/orca"
mkdir -p "$BIN_DIR"
cp "$ROOT/build/orca" "$BIN_DIR/orca"

echo "==> App -> $APP_DEST"
rm -rf "$APP_DEST"
cp -R "$ROOT/build/Orca.app" "$APP_DEST"

echo "==> Installing hooks"
"$BIN_DIR/orca" install-hooks

echo "==> Launching"
open "$APP_DEST"
echo "==> Done. (ensure $BIN_DIR is on PATH)"
