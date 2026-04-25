# PiChat ⚡️

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/pichat-logo-light.png" />
    <source media="(prefers-color-scheme: light)" srcset="docs/images/pichat-logo.png" />
    <img src="docs/images/pichat-logo-light.png" alt="PiChat Logo" width="220" />
  </picture>
</p>

<p align="center">
  <strong>Native macOS client for the <a href="https://github.com/badlogic/pi-mono">pi coding agent</a></strong>
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-111827" />
  <img alt="Swift" src="https://img.shields.io/badge/swift-5.9-orange" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-10b981" />
</p>

PiChat is a clean, production-ready SwiftUI desktop app that runs `pi --mode rpc` behind the scenes and gives you a modern GUI for everyday agentic coding.

PiChat also pairs with **PiBrowser**, a Chrome extension that lets the Pi agent inspect pages, open tabs, click, type, scroll, and answer questions about the current browser page through real `browser_*` tools.

---

## ⬇️ Download

👉 **[Download PiChat for macOS (DMG)](https://github.com/Rrollan/PiChat/releases/latest/download/PiChat-macOS.dmg)**

---

## 🧩 Install (macOS)

1. Download `PiChat-macOS.dmg`
2. Open the DMG file
3. Drag **PiChat.app** to **Applications**
4. Open **Applications → PiChat**
5. If macOS shows a security warning: right-click the app → **Open**

---

## 🚀 First launch

1. Install pi coding agent (source: https://github.com/badlogic/pi-mono):
   ```bash
   npm install -g @mariozechner/pi-coding-agent
   ```
2. Open PiChat
3. If needed, set `pi` path in Settings (`pi` works by default)
4. Start chatting

---

## ✨ Features

- Native SwiftUI UX for macOS
- Real-time chat with tool streaming
- Model and thinking controls
- Session stats (tokens / context / cost)
- Queue visibility (steering + follow-up)
- Drag & drop file and image attachments
- Extension dialogs (`confirm`, `select`, `input`, `editor`)
- Full config editing (`settings.json`, `models.json`, `auth.json`)
- Dynamic MCP list loaded from local `mcp.json`
- PiBrowser pairing for local browser automation
- Browser tool support: open tab, page context, click, type, press keys, scroll, screenshot, wait
- Native bridge installer for Chrome Native Messaging

---

## 🌐 PiBrowser extension

PiBrowser is the companion Chrome extension for browser control from PiChat.

- Repository: **https://github.com/Rrollan/PiBrowser**
- Install without Chrome Web Store: download the latest PiBrowser release ZIP, unzip it, then load the folder in `chrome://extensions` with Developer Mode enabled.
- Pairing flow: open PiBrowser, copy the Browspi/PiBrowser ID, paste it in PiChat → Settings → Browser, then press **Connect Browser**.

When connected, the Pi agent can use real browser tools while the extension shows a small visual cursor and page highlight so you can see what is being controlled.

---

## 🖼 Screenshots

<p align="center">
  <img src="docs/images/screenshot-chat.png" alt="PiChat Dark Theme" width="88%" />
</p>

<p align="center">
  <img src="docs/images/screenshot-light.png" alt="PiChat Light Theme" width="88%" />
</p>

---

## 🔐 Privacy & Release Readiness

This repository is prepared for public distribution:

- No hardcoded account keys
- No hardcoded personal model IDs
- No hardcoded MCP servers
- No hardcoded personal absolute paths
- RPC debug logs disabled by default

Run sanity scan before each release:

```bash
./scripts/sanity-check.sh
```

---

## 📦 Requirements

1. macOS 14+
2. Xcode Command Line Tools
3. Installed pi coding agent (source: https://github.com/badlogic/pi-mono):

```bash
npm install -g @mariozechner/pi-coding-agent
```

---

## 🚀 Build and Run

```bash
swift build -c release
./scripts/build-app.sh
open build/PiChat.app
```

---

## 💿 Build DMG

```bash
./scripts/build-dmg.sh
```

Artifacts:

- `build/PiChat.app`
- `build/PiChat-macOS.dmg`

---

## 🧭 Release Flow (GitHub)

```bash
# 1) sanity + build
./scripts/sanity-check.sh
./scripts/build-dmg.sh

# 2) commit + tag
git add .
git commit -m "chore(release): prepare public launch"
git tag v1.0.0

# 3) push
git push origin main --tags

# 4) create release (optional via GH CLI)
gh release create v1.0.0 build/PiChat-macOS.dmg --title "PiChat v1.0.0" --notes-file docs/RELEASE_NOTES_v1.0.0.md
```

---

## 📁 Project Layout

- `PiChat/` — app source
- `scripts/` — build + release scripts
- `docs/images/` — logos and screenshots
- `.github/workflows/` — CI workflow for macOS build

---

## 📄 License

MIT
