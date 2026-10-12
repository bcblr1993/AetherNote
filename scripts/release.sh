#!/bin/bash
# Requires release authorization, a Developer ID identity, and a notarytool profile.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your keychain profile name}"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
ARCH="$(uname -m)"
APP="build/AetherNote.app"
mkdir -p dist work
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
ditto -c -k --keepParent "$APP" work/notary-app.zip
xcrun notarytool submit work/notary-app.zip --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > work/notary-app.json
python3 -c 'import json; assert json.load(open("work/notary-app.json"))["status"] == "Accepted"'
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
ditto -c -k --keepParent "$APP" "dist/AetherNote-${VERSION}-macos-${ARCH}.zip"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/AetherNote-dmg.XXXXXX")"
ditto "$APP" "$STAGE/AetherNote.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "AetherNote" -srcfolder "$STAGE" -ov -format UDZO "dist/AetherNote-${VERSION}-macos-${ARCH}.dmg"
xcrun notarytool submit "dist/AetherNote-${VERSION}-macos-${ARCH}.dmg" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > work/notary-dmg.json
python3 -c 'import json; assert json.load(open("work/notary-dmg.json"))["status"] == "Accepted"'
xcrun stapler staple "dist/AetherNote-${VERSION}-macos-${ARCH}.dmg"
xcrun stapler validate "dist/AetherNote-${VERSION}-macos-${ARCH}.dmg"
(cd dist && shasum -a 256 "AetherNote-${VERSION}-macos-${ARCH}.dmg" "AetherNote-${VERSION}-macos-${ARCH}.zip" > SHA256SUMS)
echo "Signed, notarized and stapled assets are in dist/."
