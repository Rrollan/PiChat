# PiChat Windows v1.0.4

Multi-account fallback release for Windows.

## What's new

- Added **Account Profiles** in Settings → Accounts for multiple API-key accounts per provider (OpenAI/ChatGPT, Gemini/Google, Anthropic, GitHub Copilot, and custom providers).
- Added an active account selector that launches pi with the selected profile.
- Added automatic account switching on quota/rate-limit style failures (`429`, quota exceeded, resource exhausted), then retries the prompt with the next enabled profile.
- Account profile secrets are stored in `pichat-accounts.json` under the pi config directory rather than in the app source.

## Install

Download and run:

- `PiChat-Windows-Setup-1.0.4-x64.exe`

## Security note

This Windows release is not code-signed yet, so Windows SmartScreen may warn on first launch. Click **More info → Run anyway** only if you downloaded the installer from the official GitHub release.
