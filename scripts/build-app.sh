#!/bin/bash
# Builds Peekaboo.app (universal) and zips it into build/Peekaboo.zip.
# Usage: scripts/build-app.sh [version] [build-number]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
BUILD="${2:-1}"
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

APP=build/Peekaboo.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Peekaboo" "$APP/Contents/MacOS/Peekaboo"
cp "$BIN/peekaboo-hook" "$APP/Contents/MacOS/peekaboo-hook"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS will run it; no Apple developer account needed.
codesign --force --sign - "$APP/Contents/MacOS/peekaboo-hook"
codesign --force --sign - "$APP"

(cd build && ditto -c -k --keepParent Peekaboo.app Peekaboo.zip)
echo "Built $APP ($VERSION)"
