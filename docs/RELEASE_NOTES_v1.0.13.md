# PiChat v1.0.13

Runtime reconnect hotfix.

## Fixed

- Fixed a stale **Connected** state where the bundled `pi` process could stop in the background and the next prompt showed `pi is not running`.
- PiChat now marks the app disconnected when the `pi` RPC process terminates unexpectedly.
- Sending a message now runs a preflight check and automatically reconnects `pi` before prompting.
- If `pi` stops during prompt submission, PiChat reconnects and retries the prompt once.

## Notes

- macOS builds are currently ad-hoc signed.
