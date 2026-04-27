## PiChat v1.0.10

### Added
- PiChat for macOS now ships with a bundled pi coding-agent runtime and Node.js runtime.
- Settings → Pi Runtime includes runtime status, a manual **Update pi Runtime** action, and silent daily auto-update support for the bundled runtime.
- PiChat now checks for app updates in the background and shows a compact update card above the sidebar update button when a new release is available.

### Fixed
- The app can fall back to the bundled runtime if a user-updated runtime fails to start.
- macOS packaging no longer copies a stale `build/pi-runtime` when `SKIP_PI_RUNTIME=1` is used.
- Runtime packaging verifies the downloaded Node.js archive checksum and pins npm installs to the npmjs registry.

### Notes
- A global `npm install -g @mariozechner/pi-coding-agent` is no longer required for the distributed macOS app.
- Advanced users can still point **Settings → Pi Runtime** to an external `pi` executable.
