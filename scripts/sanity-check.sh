#!/usr/bin/env bash
set -euo pipefail

echo "Running repository sanity checks..."

PATTERN='(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|api[_-]?key\s*[:=]\s*["\x27][^"\x27]+["\x27]|/Users/[A-Za-z0-9._-]+)'

if rg -n -S --glob '!build/**' --glob '!.build/**' "$PATTERN" PiChat README.md scripts Package.swift >/tmp/pichat_sanity_hits.txt; then
  echo "Potential sensitive entries found:"
  cat /tmp/pichat_sanity_hits.txt
  exit 1
fi

echo "✅ No obvious secrets or personal absolute paths found."
