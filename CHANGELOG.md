# Changelog

All notable changes to this project will be documented in this file.

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
