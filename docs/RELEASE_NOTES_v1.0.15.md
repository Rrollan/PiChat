# PiChat v1.0.15

Project switching hotfix.

## Fixed

- Fixed an infinite **Starting pi agent / Initializing RPC connection** loading screen after switching projects.
- PiChat now ignores stale termination callbacks from the previous `pi` RPC process when a new project connection is already starting.
- Project reconnects are now generation-aware so old async startup/state-load work cannot overwrite the active connection.
- Stopping `pi` now completes pending RPC requests instead of leaving startup tasks suspended.

## Notes

- macOS builds are currently ad-hoc signed.
