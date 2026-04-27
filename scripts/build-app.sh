#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PiChat"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RUNTIME_DIR="$BUILD_DIR/pi-runtime"

BUNDLE_PI_RUNTIME=1
if [[ "${SKIP_PI_RUNTIME:-0}" != "1" ]]; then
  echo "[1/6] Packaging bundled pi runtime"
  ./scripts/package-pi-runtime.sh
else
  BUNDLE_PI_RUNTIME=0
  echo "[1/6] Skipping bundled pi runtime (SKIP_PI_RUNTIME=1)"
fi

echo "[2/6] Building release binary"
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

echo "[3/6] Preparing .app bundle"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
cp "PiChat/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "[4/6] Copying bundled resources"
if [[ -d "PiChat/Resources" ]]; then
  cp -R "PiChat/Resources/." "$APP_DIR/Contents/Resources/"
fi
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
if [[ "$BUNDLE_PI_RUNTIME" == "1" ]]; then
  if [[ ! -d "$RUNTIME_DIR" ]]; then
    echo "Bundled pi runtime not found at $RUNTIME_DIR"
    exit 1
  fi
  ditto "$RUNTIME_DIR" "$APP_DIR/Contents/Resources/pi-runtime"

  if [[ -x "$APP_DIR/Contents/Resources/pi-runtime/bin/pi" ]]; then
    "$APP_DIR/Contents/Resources/pi-runtime/bin/pi" --version >/dev/null
  else
    echo "Bundled pi wrapper missing from app resources"
    exit 1
  fi
fi

echo "[5/6] Codesigning (ad-hoc)"
codesign --force --deep --sign - "$APP_DIR"

echo "[6/6] Done"
echo "App bundle: $APP_DIR"
