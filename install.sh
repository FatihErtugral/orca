#!/usr/bin/env bash
#
# Orca one-line installer (no Xcode required — downloads a prebuilt release).
#
#   curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh | bash
#
# Pin the repo in the REPO variable below, or run with:
#   ORCA_REPO="owner/repo" bash install.sh
#
set -euo pipefail

REPO="${ORCA_REPO:-FatihErtugral/orca}"     # <-- set to your owner/repo
BIN_DIR="$HOME/.local/bin"
APP_DEST="/Applications/Orca.app"

if [ "$REPO" = "FatihErtugral/orca" ]; then
  echo "error: REPO is not set. Edit REPO in install.sh or run with" >&2
  echo "       ORCA_REPO=\"owner/repo\" bash install.sh" >&2
  exit 1
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo "error: Orca is macOS only." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

URL="https://github.com/$REPO/releases/latest/download/Orca.tar.gz"
echo "==> Downloading: $URL"
curl -fL --progress-bar "$URL" -o "$TMP/Orca.tar.gz"
tar -xzf "$TMP/Orca.tar.gz" -C "$TMP"

echo "==> App -> $APP_DEST"
[ -d "$APP_DEST" ] && rm -rf "$APP_DEST"
cp -R "$TMP/Orca.app" "$APP_DEST"
# Clear the Gatekeeper quarantine on the downloaded (ad-hoc signed) app.
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
echo "==> Done."
case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *) echo "    Note: $BIN_DIR is not on PATH. Add to your shell rc:"
     echo "          export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
echo "    Look for the 🐬 Orca icon in the menu bar. Grant the notification prompt."
echo "    Restart Claude Code so your sessions show up live."
