## PiChat v1.0.2

Release focused on reliability and chat input polish.

### What's improved

- Added persistent agent error logging to:
  `~/Library/Logs/PiChat/agent-errors.log`
- Added response timeout watchdog so silent failures (e.g. quota/limit) are visible
- Added stderr-based error capture for RPC runtime issues
- Improved user feedback: errors now surface in notifications and chat system messages
- Aligned paperclip/send controls with the text input frame
- Updated small in-chat logo to sparkle style

### Installation

Download `PiChat-macOS.dmg`, drag `PiChat.app` into `Applications`, and choose **Replace** if prompted.
