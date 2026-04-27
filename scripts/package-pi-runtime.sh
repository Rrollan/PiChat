#!/usr/bin/env bash
set -euo pipefail

# Builds a self-contained pi runtime for PiChat.app:
#   build/pi-runtime/node                         portable Node.js distribution
#   build/pi-runtime/node_modules/@mariozechner   pi coding agent and deps
#   build/pi-runtime/bin/pi                       relative wrapper for manual testing
#
# Overrides:
#   NODE_VERSION=22.14.0 PI_VERSION=0.70.2 ./scripts/package-pi-runtime.sh
#   PI_VERSION=latest ./scripts/package-pi-runtime.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CACHE_DIR="$BUILD_DIR/cache"
RUNTIME_DIR="$BUILD_DIR/pi-runtime"
NODE_VERSION="${NODE_VERSION:-22.14.0}"
PI_VERSION="${PI_VERSION:-0.70.2}"
PACKAGE_NAME="@mariozechner/pi-coding-agent"

case "$(uname -m)" in
  arm64) NODE_ARCH="arm64" ;;
  x86_64) NODE_ARCH="x64" ;;
  *) echo "Unsupported macOS architecture: $(uname -m)" >&2; exit 1 ;;
esac

NODE_DIST="node-v${NODE_VERSION}-darwin-${NODE_ARCH}"
NODE_ARCHIVE="${NODE_DIST}.tar.xz"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ARCHIVE}"
NODE_SHASUMS="SHASUMS256-${NODE_VERSION}.txt"
NODE_SHASUMS_URL="https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt"

mkdir -p "$CACHE_DIR"
rm -rf "$RUNTIME_DIR"
mkdir -p "$RUNTIME_DIR"

if [[ ! -f "$CACHE_DIR/$NODE_ARCHIVE" ]]; then
  echo "Downloading Node.js $NODE_VERSION ($NODE_ARCH)"
  curl -L --fail --output "$CACHE_DIR/$NODE_ARCHIVE" "$NODE_URL"
fi

if [[ ! -f "$CACHE_DIR/$NODE_SHASUMS" ]]; then
  echo "Downloading Node.js checksums"
  curl -L --fail --output "$CACHE_DIR/$NODE_SHASUMS" "$NODE_SHASUMS_URL"
fi

EXPECTED_SHA="$(awk -v archive="$NODE_ARCHIVE" '$2 == archive {print $1}' "$CACHE_DIR/$NODE_SHASUMS")"
if [[ -z "$EXPECTED_SHA" ]]; then
  echo "Checksum for $NODE_ARCHIVE not found in $NODE_SHASUMS" >&2
  exit 1
fi
ACTUAL_SHA="$(shasum -a 256 "$CACHE_DIR/$NODE_ARCHIVE" | awk '{print $1}')"
if [[ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]]; then
  echo "Checksum mismatch for $NODE_ARCHIVE" >&2
  echo "expected: $EXPECTED_SHA" >&2
  echo "actual:   $ACTUAL_SHA" >&2
  exit 1
fi

echo "Extracting Node.js"
rm -rf "$CACHE_DIR/$NODE_DIST"
tar -xJf "$CACHE_DIR/$NODE_ARCHIVE" -C "$CACHE_DIR"
cp -R "$CACHE_DIR/$NODE_DIST" "$RUNTIME_DIR/node"

NPM="$RUNTIME_DIR/node/bin/npm"
NODE="$RUNTIME_DIR/node/bin/node"
if [[ ! -x "$NODE" || ! -x "$NPM" ]]; then
  echo "Node/npm not executable after extraction" >&2
  exit 1
fi

echo "Installing $PACKAGE_NAME@$PI_VERSION"
PATH="$RUNTIME_DIR/node/bin:$PATH" "$NPM" install \
  --prefix "$RUNTIME_DIR" \
  --omit=dev \
  --ignore-scripts \
  --no-audit \
  --no-fund \
  --registry=https://registry.npmjs.org \
  "$PACKAGE_NAME@$PI_VERSION"

mkdir -p "$RUNTIME_DIR/bin"
cat > "$RUNTIME_DIR/bin/pi" <<'EOF'
#!/bin/sh
DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
exec "$DIR/node/bin/node" "$DIR/node_modules/@mariozechner/pi-coding-agent/dist/cli.js" "$@"
EOF
chmod 755 "$RUNTIME_DIR/bin/pi"

INSTALLED_VERSION="$($NODE -e "console.log(require(process.argv[1]).version)" "$RUNTIME_DIR/node_modules/@mariozechner/pi-coding-agent/package.json")"
cat > "$RUNTIME_DIR/pichat-runtime.json" <<EOF
{
  "package": "$PACKAGE_NAME",
  "version": "$INSTALLED_VERSION",
  "nodeVersion": "$NODE_VERSION"
}
EOF

chmod -R u+rwX,go+rX "$RUNTIME_DIR"
find "$RUNTIME_DIR/node/bin" -maxdepth 1 -type f -exec chmod 755 {} \;

echo "Built runtime: $RUNTIME_DIR"
echo "pi version: $INSTALLED_VERSION"
