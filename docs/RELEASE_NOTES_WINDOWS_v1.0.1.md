# PiChat Windows v1.0.1

## Which file to download

- `PiChat-Windows-Setup-1.0.1-x64.exe` — recommended normal installer. Use this for most users.
- `PiChat-Windows-Portable-1.0.1-x64.exe` — portable/no-install build. It runs directly from the downloaded file and is mainly useful when you do not want to install the app.
- `PiChat-Windows-Unpacked-1.0.1-x64.zip` — unpacked build for debugging/manual distribution.
- `SHA256SUMS.txt` — release checksums.

## Fixed

- The Windows app now bundles the Pi coding agent runtime and can start without requiring users to install `@mariozechner/pi-coding-agent` globally first.
- Fixed the startup error:
  `Error invoking remote method 'pi:connect': Error: spawn pi ENOENT`.
- OAuth authentication now also uses the bundled Pi runtime when available.
- The installer no longer auto-runs the Start Menu shortcut at the final step, avoiding the confusing Windows `.lnk` association dialog seen on some systems.

## Notes

This Windows release is not code-signed yet, so Windows SmartScreen may warn on first launch.
