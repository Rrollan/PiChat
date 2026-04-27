# PiChat Windows v1.0.6

Renderer state tracking hotfix.

## Fixed

- Fixed stale assistant tracking in the Windows renderer so early text and tool updates stay attached to the active response.
- New sessions now clear assistant and active-tool UI state before the next response starts.
- Tool and message updates now target stable assistant IDs instead of stale render-time state.

## Install

Download and run:

- `PiChat-Windows-Setup-1.0.6-x64.exe`

## Security note

This Windows release is not code-signed yet, so Windows SmartScreen may warn on first launch. Click **More info → Run anyway** only if you downloaded the installer from the official GitHub release.
