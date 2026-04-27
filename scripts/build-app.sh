#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PiChat"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"

echo "[1/5] Building release binary"
swift build -c release

BIN_PATH=".build/release/$APP_NAME"
RESOURCE_BUNDLE=".build/release/${APP_NAME}_${APP_NAME}.bundle"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "Release binary not found at $BIN_PATH"
  exit 1
fi
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "Resource bundle not found at $RESOURCE_BUNDLE"
  exit 1
fi

echo "[2/5] Preparing .app bundle"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
cp "PiChat/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "[3/5] Copying bundled resources"
if [[ -d "PiChat/Resources" ]]; then
  cp -R "PiChat/Resources/." "$APP_DIR/Contents/Resources/"
fi
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"

echo "[4/5] Codesigning (ad-hoc)"
codesign --force --deep --sign - "$APP_DIR"

echo "[5/5] Done"
echo "App bundle: $APP_DIR"
