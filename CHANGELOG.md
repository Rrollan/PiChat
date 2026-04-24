# Changelog

All notable changes to this project will be documented in this file.

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
