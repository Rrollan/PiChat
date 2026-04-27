# PiChat Windows v1.0.2

## Download

Download the single Windows installer:

- `PiChat-Windows-Setup-1.0.2-x64.exe`

This is the recommended native Windows install path. The release no longer publishes portable/unpacked ZIP variants, so users do not need to choose between multiple packages.

## What changed

- Simplified the Windows release to one clear installer `.exe`.
- Removed the portable/compact and unpacked ZIP release artifacts from GitHub releases.
- Kept the bundled pi runtime so PiChat starts without requiring a global `pi` installation.
- Kept installer auto-run disabled to avoid Windows shortcut association issues on affected systems.

## Install

1. Download `PiChat-Windows-Setup-1.0.2-x64.exe`.
2. Run the installer.
3. Open PiChat from the Start Menu or Desktop shortcut.
4. Use **Settings → Pi Runtime** only if you intentionally want an external/global `pi` executable.

## Notes

This Windows release is not code-signed yet, so Windows SmartScreen may warn on first launch. Click **More info → Run anyway** only if you downloaded the installer from the official GitHub release.
