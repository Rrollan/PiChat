#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  echo "Usage: $0 <tag>"
  echo "Example: $0 v1.0.0"
  exit 1
fi

NOTES_FILE="docs/RELEASE_NOTES_${TAG}.md"
DMG_PATH="build/PiChat-macOS.dmg"

if [[ ! -f "$NOTES_FILE" ]]; then
  echo "Release notes not found: $NOTES_FILE"
  exit 1
fi

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found: $DMG_PATH"
  echo "Run ./scripts/build-dmg.sh first"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run: gh auth login"
  exit 1
fi

git tag "$TAG"
git push origin main --tags

gh release create "$TAG" "$DMG_PATH" \
  --title "PiChat $TAG" \
  --notes-file "$NOTES_FILE"

echo "Release published: $TAG"
