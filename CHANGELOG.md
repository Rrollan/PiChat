# Changelog

All notable changes to this project will be documented in this file.

## [1.0.14] - 2026-04-28

### Fixed
- Fixed a macOS crash when tool execution updates arrived after active tool rows were removed or after a session reset
- Rebuilt active tool lookup state after delayed cleanup and hardened assistant message access against stale indexes
- Cleared transient conversation state when starting a new session so late RPC events no longer hit stale UI state

## [Windows 1.0.6] - 2026-04-28

### Fixed
- Fixed stale assistant tracking across tool events in the Windows renderer so early text/tool updates are no longer dropped
- Cleared active tool and assistant UI state on new sessions so the next response renders correctly
- Switched Windows event updates to stable assistant IDs instead of stale render-time state

## [1.0.11] - 2026-04-27

### Added
- Added OAuth verification cards with copy-code and reopen-link actions
- Added Pi Resources settings for packages, skills, extensions, prompts, and themes
- Added `mcp.json` to the in-app raw JSON editor
- Highlighted likely skill/MCP/extension installs in tool cards and refresh resources after successful agent changes

### Fixed
- Fixed GitHub Copilot OAuth by showing the device verification code in PiChat
- Allowed empty OAuth prompt submission when providers support defaults
- Hardened pi config writes with file allowlisting, atomic writes, and private `auth.json` permissions

## [Windows 1.0.3] - 2026-04-27

### Fixed
- Fixed GitHub Copilot OAuth code display in the Windows settings UI
- Added empty/default OAuth prompt support for Windows
- Added `mcp.json` to Windows config state and raw JSON editing

## [Windows 1.0.2] - 2026-04-27

### Changed
- Simplified Windows distribution to a single native installer `.exe`
- Removed portable/compact and unpacked ZIP artifacts from Windows GitHub releases
- Updated Windows release workflow to derive artifact names and release notes from the package version

## [1.0.10] - 2026-04-27

### Added
- Bundled the macOS pi runtime into `PiChat.app` with a packaged Node.js runtime
- Added silent daily pi runtime auto-updates and a manual runtime update action in Settings
- Added an in-app PiChat update card above the sidebar update button when a new release is available

### Fixed
- Made macOS builds deterministic when `SKIP_PI_RUNTIME=1` is used
- Added bundled-runtime fallback if an updated runtime fails to start
- Hardened runtime packaging with Node archive checksum verification and npmjs registry pinning

## [1.0.9] - 2026-04-27

### Fixed
- Fixed macOS release crash at launch when SwiftPM resource bundles were missing from the `.app` package
- Made logo resource loading resilient by avoiding fatal `Bundle.module` initialization during app startup
- Updated macOS packaging to include the generated `PiChat_PiChat.bundle` under app resources in release builds

## [Windows 1.0.1] - 2026-04-27

### Fixed
- Bundled the Pi coding agent runtime with the Windows app so first launch no longer fails with `spawn pi ENOENT`
- Updated OAuth login to use the bundled Pi auth storage when available
- Disabled installer auto-run from the final page to avoid confusing `.lnk` association errors on affected Windows systems

## [1.0.8] - 2026-04-25

### Added
- Full-chat drag-and-drop overlay for attaching images and files
- Shared attachment ingress handling for pasteboard, paste commands, and drops

### Fixed
- Finder `Cmd+V` paste now attaches copied files and image files correctly
- Duplicate attachments are ignored
- MIME type detection now uses macOS Uniform Type Identifiers

## [1.0.5] - 2026-04-24

### Added
- In-settings OAuth status panel with live progress, manual code/redirect input, and cancel action

### Changed
- Reworked Settings UI to be sectioned and English-only for consistency
- Added built-in Pi OAuth authentication entries for Anthropic, GitHub Copilot, OpenAI Codex, Google Antigravity, and Google Gemini CLI
- Improved OAuth helper process handling to avoid silent hangs and show actionable status updates
- Unified Settings gear button hover/highlight behavior with other sidebar action icons

## [1.0.4] - 2026-04-24

### Added
- Global action feedback overlay for keyboard shortcuts (e.g. `⌘N`, `⌘⇧K`)
- Busy-state indicator with spinner and contextual status text for long UI actions

### Changed
- New Session and Compact actions now surface immediate visual feedback and explicit error notifications
- Improved perceived responsiveness during keyboard-triggered operations

## [1.0.3] - 2026-04-24

### Fixed
- Restored original PiChat logo in welcome screen
- Kept sparkle icon only for assistant messages
- Added subtle animation to assistant message sparkle icon

## [1.0.2] - 2026-04-24

### Added
- Persistent agent error logging to `~/Library/Logs/PiChat/agent-errors.log`
- Timeout watchdog for silent/limit-related agent failures with in-chat warning

### Changed
- Better RPC stderr handling to surface hidden runtime errors
- Aligned input controls (paperclip/send) with text input container
- Replaced in-chat small logo with sparkle icon variant

## [1.0.0] - 2026-04-24

### Added
- Public release packaging scripts (`build-app.sh`, `build-dmg.sh`)
- Repository sanity scanner (`sanity-check.sh`)
- GitHub Actions macOS build workflow
- Release documentation (`docs/RELEASE.md`)

### Changed
- MCP section now loads servers dynamically from `mcp.json` (no hardcoded entries)
- RPC debug logging made optional and disabled by default
- Cleaned default settings in app forms for safer public distribution
- Updated README with release-focused docs and screenshot sections

### Security
- Removed release-risk defaults and hardcoded values that could expose personal setup details
