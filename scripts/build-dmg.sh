#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PiChat"
BUILD_DIR="build"
FINAL_DMG="$BUILD_DIR/${APP_NAME}-macOS.dmg"
TEMP_DMG="$BUILD_DIR/${APP_NAME}-temp.dmg"
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

rm -f "$TEMP_DMG" "$FINAL_DMG"

# Create writable DMG first so we can style the Finder window.
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  "$TEMP_DMG"

ATTACH_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG")
MOUNT_LINE=$(echo "$ATTACH_OUTPUT" | awk '/\/Volumes\// {print; exit}')
DEVICE=$(echo "$MOUNT_LINE" | awk '{print $1}')
MOUNT_POINT=$(echo "$MOUNT_LINE" | sed -E 's/.*[[:space:]](\/Volumes\/.*)$/\1/')

if [[ -z "${DEVICE:-}" || -z "${MOUNT_POINT:-}" ]]; then
  echo "Failed to mount temporary DMG"
  echo "$ATTACH_OUTPUT"
  exit 1
fi

# Style installer window: icon size, positions, simple drag-and-drop layout.
DISK_NAME=$(basename "$MOUNT_POINT")
if ! osascript <<EOF
on run
  tell application "Finder"
    tell disk "${DISK_NAME}"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {120, 120, 980, 640}
      set opts to the icon view options of container window
      set arrangement of opts to not arranged
      set icon size of opts to 128
      set text size of opts to 14
      set position of item "${APP_NAME}.app" of container window to {260, 280}
      set position of item "Applications" of container window to {620, 280}
      close
      open
      update without registering applications
      delay 1
    end tell
  end tell
end run
EOF
then
  echo "Warning: failed to style DMG Finder window, continuing with default layout."
fi

sync
hdiutil detach "$MOUNT_POINT" -quiet

# Convert to compressed distribution DMG.
hdiutil convert "$TEMP_DMG" -ov -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"

rm -f "$TEMP_DMG"
rm -rf "$STAGING_DIR"

echo "DMG created: $FINAL_DMG"
