# PiChat Windows v1.0.0

Initial Windows release of PiChat.

## Downloads

- `PiChat-Windows-Setup-1.0.0-x64.exe` — recommended installer for Windows 10/11 x64.
- `PiChat-Windows-Portable-1.0.0-x64.exe` — portable app, no installer required.
- `PiChat-Windows-Unpacked-1.0.0-x64.zip` — unpacked build for debugging/manual distribution.
- `SHA256SUMS.txt` — release checksums.

## Highlights

- Windows desktop UI recreated from the macOS SwiftUI PiChat design.
- Runs `pi --mode rpc` behind the scenes.
- Real-time streaming chat, thinking blocks, tool execution cards, activity panel, and queue panel.
- Model picker, thinking controls, session stats, commands/skills list, and MCP list.
- Drag-and-drop/file picker attachments with image support.
- Settings UI for runtime paths, accounts, OAuth, custom models, CLI flags, and raw config JSON.
- Browser control integration for PiBrowser/Browspi using Windows Chrome Native Messaging.

## Requirements

- Windows 10/11 x64.
- Node.js 20+.
- Pi coding agent installed globally:

```powershell
npm install -g @mariozechner/pi-coding-agent
```

## Notes

This first Windows release is not code-signed yet, so Windows SmartScreen may warn on first launch.
