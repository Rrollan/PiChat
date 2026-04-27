# PiChat Windows Version

Electron + React + TypeScript recreation of the macOS SwiftUI PiChat client for Windows.

## Implemented parity

- Same 3-column PiChat layout: model/session sidebar, central chat, activity/queue right panel.
- Same monochrome light/dark design tokens, rounded cards, PiChat logo assets, welcome suggestions, composer, tool cards, thinking blocks, toasts, and extension dialogs.
- `pi --mode rpc` process bridge with JSON-line protocol, streaming assistant text/thinking, tool events, queue events, compaction, auto-retry, stderr/error notifications.
- Model picker, thinking levels, model hide/show, session stats, commands/skills, MCP list.
- Prompt sending with pasted long text and image attachments encoded as base64 RPC images.
- File picker, folder/project switcher, drag-and-drop attachment ingestion.
- Settings window with runtime paths, CLI flags, accounts/auth.json editor, models/settings/auth raw JSON editors, custom model add, session actions, browser control.
- Pi-native OAuth helper for subscription providers using the installed `@mariozechner/pi-coding-agent` package.
- Windows Chrome native messaging installer for Browspi/PiBrowser resources, registry registration under `HKCU`, pairing config, and browser-tools extension wiring.
- NSIS/portable packaging config via `electron-builder`.

## Reliability hardening included

- Robust Windows process launch for `pi` including global npm PATH lookup and `.cmd` handling.
- Graceful process cleanup and Windows process-tree termination through `taskkill`.
- RPC request timeouts to prevent permanently hung commands.
- Packaged `file://` renderer URL generated with `pathToFileURL`, not brittle string concatenation.
- Quoted CLI extra argument parsing for Windows paths with spaces.
- Atomic writes for PiChat app settings and pi config JSON files.
- Config write allowlist for `settings.json`, `models.json`, `auth.json`, and `mcp.json` to prevent path traversal.
- Attachment ingestion skips inaccessible folders/files and only base64-encodes supported images up to a safety cap.
- OAuth runs through Electron's bundled runtime with `ELECTRON_RUN_AS_NODE=1`, so it is less dependent on a separate `node.exe` PATH entry.
- OAuth input/cancel IPC listeners are scoped and cleaned up per run.
- Browspi native host uses explicit Windows environment paths and `%LOCALAPPDATA%\PiChat\NativeHost`.
- Native messaging installer prefers a real `PiChatNativeHost.exe`; if a prebuilt exe is not available, it attempts to build one with .NET and only then falls back to `.cmd`.

## Requirements

### Release builds

1. Windows 10/11 x64.
2. No separate Node.js or global `pi` install is required for normal chat usage; the packaged app bundles the Pi coding agent runtime.

### Development builds

1. Node.js 20+.
2. Optional external Pi coding agent in PATH if you want to test against a global runtime instead of the bundled dependency:
   ```powershell
   npm install -g @mariozechner/pi-coding-agent
   ```
3. Optional but recommended for the most reliable Browspi native host: .NET 8 SDK, used to build `PiChatNativeHost.exe`.

## Development

```powershell
cd "windows version"
npm install
npm run dev
```

## Verify

```powershell
cd "windows version"
npm run verify:windows
```

## Build native host exe, recommended before release

```powershell
cd "windows version"
npm run build:native-host
```

This creates:

```text
resources/native-host/PiChatNativeHost.exe
```

If this file exists before packaging, the Browspi manifest will point to the `.exe` host instead of the `.cmd` fallback.

## Build app

```powershell
cd "windows version"
npm run build
npm run dist
```

Artifacts are written to:

```text
windows version/release/
```

## Windows-specific notes

- Chrome native messaging registration is written here:
  `HKCU\Software\Google\Chrome\NativeMessagingHosts\com.browspi.pi_bridge`.
- Native host runtime files are installed here:
  `%LOCALAPPDATA%\PiChat\NativeHost`.
- Release builds prefer the bundled Pi runtime. If the Settings → Pi Runtime field is changed from `pi` to a custom executable, the app uses that external runtime instead.
- The app assumes upstream `pi --mode rpc` works on Windows. If the upstream pi package has platform-specific issues, the Electron client will surface the error and the runtime layer/upstream package must be fixed.
