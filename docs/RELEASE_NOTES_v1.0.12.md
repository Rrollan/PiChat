# PiChat v1.0.12

Multi-account fallback and update UI refinement release.

## What's new

- Added **Account Profiles** in Settings → Accounts for multiple API-key accounts per provider (OpenAI/ChatGPT, Gemini/Google, Anthropic, GitHub Copilot, and custom providers).
- Added an active account selector so PiChat can launch the agent with a chosen account profile without editing CLI flags.
- Added automatic account failover for quota/rate-limit style failures (`429`, quota exceeded, resource exhausted): PiChat switches to the next enabled profile and retries the prompt.
- Account profile secrets are stored outside the app bundle in `pichat-accounts.json` with restrictive file permissions.
- The update card now appears automatically as an inline sidebar card and no longer renders clipped/off-position near the update button.

## Notes

- Account Profiles are for API-key based accounts. Provider-native OAuth logins still follow pi runtime provider support.
- macOS builds are currently ad-hoc signed.
