#!/bin/bash
# Baut die Release-Version und erzeugt dist/SevenZipGUI.dmg
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="SevenZipGUI"
DIST_DIR="dist"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

echo "==> Baue Release…"
xcodebuild -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -destination "platform=macOS" \
  -configuration Release \
  -derivedDataPath "$DIST_DIR/DerivedData" \
  build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

APP_PATH="$DIST_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
[ -d "$APP_PATH" ] || { echo "FEHLER: $APP_PATH nicht gefunden"; exit 1; }

echo "==> Bereite DMG-Inhalt vor…"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Programme"

echo "==> Erzeuge DMG…"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"
echo "==> Fertig: $DMG_PATH"
hdiutil verify "$DMG_PATH" >/dev/null && echo "DMG verifiziert ✓"
