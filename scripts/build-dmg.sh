#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PiChat"
BUILD_DIR="build"
DMG_NAME="${APP_NAME}-macOS.dmg"
STAGING_DIR="$BUILD_DIR/dmg-staging"

"$(dirname "$0")/build-app.sh"

APP_PATH="$BUILD_DIR/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$BUILD_DIR/$DMG_NAME"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$BUILD_DIR/$DMG_NAME"

echo "DMG created: $BUILD_DIR/$DMG_NAME"
