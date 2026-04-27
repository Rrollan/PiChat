# PiChat v1.0.14

Tool event crash hotfix.

## Fixed

- Fixed a macOS crash caused by stale `activeTools` indexes during tool execution updates.
- PiChat now validates assistant message indexes before applying streaming and tool updates.
- Rebuilt active tool lookup state after delayed cleanup so out-of-order tool events no longer crash the app.
- Starting a new session now clears transient tool and assistant tracking state.

## Notes

- macOS builds are currently ad-hoc signed.
