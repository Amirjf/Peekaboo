#!/bin/bash
# Installs (or updates) Peekaboo from the latest GitHub release.
#   curl -fsSL https://raw.githubusercontent.com/amirjf/peekaboo/main/install.sh | bash
set -euo pipefail

URL="https://github.com/amirjf/peekaboo/releases/latest/download/Peekaboo.zip"
DEST="/Applications"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Peekaboo…"
curl -fsSL "$URL" -o "$TMP/Peekaboo.zip"

pkill -x Peekaboo 2>/dev/null || true
rm -rf "$DEST/Peekaboo.app"
ditto -x -k "$TMP/Peekaboo.zip" "$DEST"
xattr -dr com.apple.quarantine "$DEST/Peekaboo.app" 2>/dev/null || true

open "$DEST/Peekaboo.app"
echo "Peekaboo is running. Look at your notch!"
echo "Restart any Claude Code sessions that were already open so they pick up the new hooks."
