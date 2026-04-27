# PiChat Windows v1.0.3

## Download

Download the single Windows installer:

- `PiChat-Windows-Setup-1.0.3-x64.exe`

## Fixed

- GitHub Copilot authentication now shows the device verification code in the PiChat settings UI.
- OAuth prompts can now be submitted empty when the provider supports defaults, such as using `github.com` for GitHub Copilot.
- `mcp.json` is now part of the loaded config state and raw JSON editor.

## Improved

- Added a clearer OAuth verification card with code display, copy-code action, and reopen-link action.
- Kept the simplified Windows distribution: one native installer `.exe`, no portable/unpacked variants.

## Notes

This Windows release is not code-signed yet, so Windows SmartScreen may warn on first launch. Click **More info → Run anyway** only if you downloaded the installer from the official GitHub release.
