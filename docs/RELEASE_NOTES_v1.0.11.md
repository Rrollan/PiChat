## PiChat v1.0.11

### Fixed
- GitHub Copilot authentication now displays the device verification code inside PiChat.
- OAuth prompts can now be submitted empty when the provider supports defaults, such as using `github.com` for GitHub Copilot.
- Hardened pi config file writes with JSON validation, atomic writes, file-name allowlisting, and private `auth.json` permissions.

### Added
- Added a visual OAuth verification card with copy-code and reopen-link actions.
- Added `mcp.json` to the in-app raw config editor.
- Added a Pi Resources panel for managing packages, skills, extensions, prompts, and themes from `settings.json`.
- Tool cards now highlight likely skill, extension, MCP, and pi resource installation work, then refresh loaded resources after successful changes.
