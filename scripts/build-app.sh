#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="build/AetherNote.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/AppIcon.iconset
cp "$BIN_DIR/AetherNote" "$APP/Contents/MacOS/AetherNote"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/icon.swift build/AppIcon.png
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" build/AppIcon.png --out "build/AppIcon.iconset/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z "$DOUBLE" "$DOUBLE" build/AppIcon.png --out "build/AppIcon.iconset/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "$APP"
