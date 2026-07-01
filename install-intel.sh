#!/usr/bin/env bash
#
# Orca installer for Intel Macs (x86_64). No Xcode required.
#
set -euo pipefail

REPO="FatihErtugral/orca"
ASSET="Orca-x86_64.tar.gz"
BIN_DIR="$HOME/.local/bin"
APP_DEST="/Applications/Orca.app"

[ "$(uname -s)" = "Darwin" ] || { echo "error: Orca is macOS only." >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Downloading $ASSET (Intel)"
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  gh release download --repo "$REPO" --pattern "$ASSET" --dir "$TMP" --clobber
else
  curl -fL --progress-bar "https://github.com/$REPO/releases/latest/download/$ASSET" -o "$TMP/$ASSET"
fi
tar -xzf "$TMP/$ASSET" -C "$TMP"

echo "==> App -> $APP_DEST"
rm -rf "$APP_DEST"
cp -R "$TMP/Orca.app" "$APP_DEST"
xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true

echo "==> Bridge -> $BIN_DIR/orca"
mkdir -p "$BIN_DIR"
cp "$TMP/orca" "$BIN_DIR/orca"
chmod +x "$BIN_DIR/orca"
xattr -d com.apple.quarantine "$BIN_DIR/orca" 2>/dev/null || true

echo "==> Installing Claude Code hooks"
"$BIN_DIR/orca" install-hooks || true

echo "==> Launching"
open "$APP_DEST"

echo ""
echo "==> Done. Look for the 🐬 Orca icon in the menu bar."
case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *) echo "    Add ~/.local/bin to PATH: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
echo "    Restart Claude Code so your sessions show up live."
