# PiChat for Windows

PiChat for Windows is a native-feeling desktop app built with Electron. It runs the same `pi --mode rpc` agent backend as the macOS app.

## Download

Use the Windows installer from the Windows release:

- **Installer:** `PiChat-Windows-Setup-1.0.0-x64.exe`
- **Portable:** `PiChat-Windows-Portable-1.0.0-x64.exe`

Direct links after release publication:

- https://github.com/Rrollan/PiChat/releases/download/windows-v1.0.0/PiChat-Windows-Setup-1.0.0-x64.exe
- https://github.com/Rrollan/PiChat/releases/download/windows-v1.0.0/PiChat-Windows-Portable-1.0.0-x64.exe

## Requirements

1. Windows 10/11 x64.
2. Node.js 20 or newer.
3. Pi coding agent installed globally:

```powershell
npm install -g @mariozechner/pi-coding-agent
```

Check that `pi` is available:

```powershell
pi --version
```

## Simple installation

1. Download `PiChat-Windows-Setup-1.0.0-x64.exe`.
2. Open the installer.
3. Follow the installation steps.
4. Launch **PiChat** from Start Menu or Desktop.
5. If PiChat cannot find `pi`, open **Settings → Pi Runtime** and set the executable path.

Usually this works:

```text
pi
```

If your global npm path is unusual, use the full path to `pi.cmd`, for example:

```text
C:\Users\YOUR_NAME\AppData\Roaming\npm\pi.cmd
```

## Portable mode

If you do not want to install PiChat:

1. Download `PiChat-Windows-Portable-1.0.0-x64.exe`.
2. Place it anywhere, for example `Downloads` or `Desktop`.
3. Run it directly.

Portable mode still stores app settings in the normal Windows user data directory.

## First launch setup

1. Open PiChat.
2. Go to **Settings → Accounts**.
3. Add an API key account or use subscription authentication.
4. Press **Reconnect**.
5. Pick a model from the left sidebar.
6. Start chatting.

## Browser control with PiBrowser / Browspi

1. Install the PiBrowser Chrome extension.
2. Open the extension and copy the Browspi ID.
3. In PiChat open **Settings → Browser**.
4. Paste the Browspi ID.
5. Click **Connect Browser**.
6. Reload the extension page and press **Connect** inside the extension.

PiChat registers Chrome native messaging for the current Windows user under:

```text
HKCU\Software\Google\Chrome\NativeMessagingHosts\com.browspi.pi_bridge
```

Native host files are installed to:

```text
%LOCALAPPDATA%\PiChat\NativeHost
```

## Troubleshooting

### PiChat says `pi is not running` or cannot start pi

Run this in PowerShell:

```powershell
pi --version
```

If PowerShell cannot find `pi`, reinstall it:

```powershell
npm install -g @mariozechner/pi-coding-agent
```

Then restart PiChat.

### Set a manual pi path

Open **Settings → Pi Runtime** and set:

```text
C:\Users\YOUR_NAME\AppData\Roaming\npm\pi.cmd
```

Then click **Reconnect**.

### Browser connection does not work

1. Open **Settings → Browser**.
2. Click **Disconnect**.
3. Paste the Browspi ID again.
4. Click **Connect Browser**.
5. Restart Chrome.

### Windows Defender warning

The app is not code-signed yet. Windows may show SmartScreen for the first release. Click **More info → Run anyway** only if you downloaded the file from the official GitHub release.

## Build from source

```powershell
git clone https://github.com/Rrollan/PiChat.git
cd PiChat\"windows version"
npm install
npm run verify:windows
npm run dist
```

Artifacts are written to:

```text
windows version\release
```
