import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import type { BrowserStatus } from '../shared/types';
import { resourcePath } from './config';

export const HOST_NAME = 'com.browspi.pi_bridge';

function localAppData(): string {
  return process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local');
}

export function nativeHostDir(): string {
  return path.join(localAppData(), 'PiChat', 'NativeHost');
}

export function manifestPath(): string {
  return path.join(nativeHostDir(), `${HOST_NAME}.json`);
}

export function pairingPath(): string {
  return path.join(nativeHostDir(), 'pairing.json');
}

export function browserToolsPath(): string {
  return path.join(nativeHostDir(), 'browser-tools', 'index.ts');
}

function hostCommandPath(): string {
  return path.join(nativeHostDir(), 'browspi-native-host.cmd');
}

function hostExePath(): string {
  return path.join(nativeHostDir(), 'PiChatNativeHost.exe');
}

function installedHostPath(): string {
  return fs.existsSync(hostExePath()) ? hostExePath() : hostCommandPath();
}

export function normalizeExtensionId(raw: string): string {
  const trimmed = raw.trim().replace(/[\s-]/g, '').toLowerCase();
  if (/^[a-p]{32}$/.test(trimmed)) return trimmed;
  if (/^[0-9]{64}$/.test(trimmed)) {
    let out = '';
    for (let i = 0; i < trimmed.length; i += 2) {
      const value = Number(trimmed.slice(i, i + 2));
      if (!Number.isInteger(value) || value < 0 || value > 15) throw new Error(`Invalid Browspi ID: ${raw}`);
      out += String.fromCharCode(97 + value);
    }
    return out;
  }
  throw new Error(`Invalid Browspi Browser UID or Chrome extension id: ${raw}`);
}

export function generatePairingToken(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  return Array.from(crypto.randomBytes(24)).map(b => alphabet[b % alphabet.length]).join('');
}

export function pairingTokenHash(token: string): string {
  return crypto.createHash('sha256').update(token, 'utf8').digest('hex');
}

function readJson(file: string): any | null {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return null; }
}

function atomicWriteJson(file: string, value: unknown): void {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.${process.pid}.${Date.now()}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(value, null, 2), 'utf8');
  fs.renameSync(tmp, file);
}

function writeTrustedPairingConfig(): void {
  const existing = readJson(pairingPath());
  atomicWriteJson(pairingPath(), {
    pairingRequired: false,
    tokenHash: null,
    paired: true,
    lastPairedAt: existing?.lastPairedAt,
    lastSeenAt: existing?.lastSeenAt,
    client: existing?.client,
    updatedAt: Date.now() / 1000
  });
}

export function writePairingConfig(token: string): void {
  const existing = readJson(pairingPath());
  const tokenHash = pairingTokenHash(token);
  const sameToken = existing?.tokenHash === tokenHash;
  atomicWriteJson(pairingPath(), {
    pairingRequired: true,
    tokenHash,
    paired: sameToken ? Boolean(existing?.paired) : false,
    lastPairedAt: sameToken ? existing?.lastPairedAt : null,
    lastSeenAt: sameToken ? existing?.lastSeenAt : null,
    client: sameToken ? existing?.client : null,
    updatedAt: Date.now() / 1000
  });
}

function installRegistry(): void {
  const key = `HKCU\\Software\\Google\\Chrome\\NativeMessagingHosts\\${HOST_NAME}`;
  execFileSync('reg.exe', ['add', key, '/ve', '/t', 'REG_SZ', '/d', manifestPath(), '/f'], { windowsHide: true });
}

function uninstallRegistry(): void {
  const key = `HKCU\\Software\\Google\\Chrome\\NativeMessagingHosts\\${HOST_NAME}`;
  try { execFileSync('reg.exe', ['delete', key, '/f'], { windowsHide: true }); } catch { /* ignore */ }
}

function copyIfExists(source: string, destination: string): boolean {
  if (!fs.existsSync(source)) return false;
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(source, destination);
  return true;
}

function tryBuildNativeHostExecutable(dir: string): boolean {
  const sourceDir = resourcePath('resources', 'native-host');
  const project = path.join(dir, 'native-host-src', 'PiChatNativeHost.csproj');
  try {
    if (!fs.existsSync(path.join(sourceDir, 'PiChatNativeHost.csproj'))) return false;
    fs.mkdirSync(path.dirname(project), { recursive: true });
    copyIfExists(path.join(sourceDir, 'PiChatNativeHost.csproj'), project);
    copyIfExists(path.join(sourceDir, 'Program.cs'), path.join(path.dirname(project), 'Program.cs'));
    execFileSync('dotnet.exe', ['publish', project, '-c', 'Release', '-r', 'win-x64', '--self-contained=true', '-o', path.join(dir, 'native-host-build'), '/p:PublishSingleFile=true', '/p:IncludeNativeLibrariesForSelfExtract=true'], { windowsHide: true, stdio: 'ignore', timeout: 180_000 });
    return copyIfExists(path.join(dir, 'native-host-build', 'PiChatNativeHost.exe'), hostExePath());
  } catch {
    return false;
  }
}

function installHostWrapper(dir: string): string {
  const prebuiltExe = resourcePath('resources', 'native-host', 'PiChatNativeHost.exe');
  if (copyIfExists(prebuiltExe, hostExePath()) || tryBuildNativeHostExecutable(dir)) {
    return hostExePath();
  }

  const cmd = `@echo off\r\nsetlocal\r\nset "BROWSPI_PAIRING_DIR=%~dp0"\r\nset "BROWSPI_PAIRING_CONFIG=%~dp0pairing.json"\r\nset "BROWSPI_BROWSER_TOOLS_EXTENSION=%~dp0browser-tools\\index.ts"\r\nset "PATH=%APPDATA%\\npm;%LOCALAPPDATA%\\Programs\\nodejs;C:\\Program Files\\nodejs;C:\\Program Files (x86)\\nodejs;%PATH%"\r\nnode "%~dp0browspi-native-host.mjs" %*\r\n`;
  fs.writeFileSync(hostCommandPath(), cmd, 'utf8');
  return hostCommandPath();
}

export function installBrowserBridge(rawExtensionId: string, pairingToken?: string): { manifestPath: string; hostPath: string; allowedOrigin: string } {
  const extensionId = normalizeExtensionId(rawExtensionId);
  const dir = nativeHostDir();
  fs.mkdirSync(path.join(dir, 'browser-tools'), { recursive: true });

  const sourceHost = resourcePath('resources', 'browspi-native-host.mjs');
  const sourceTools = resourcePath('resources', 'browser-tools', 'index.ts');
  if (!fs.existsSync(sourceHost)) throw new Error(`Bundled Browspi native host is missing: ${sourceHost}`);
  fs.copyFileSync(sourceHost, path.join(dir, 'browspi-native-host.mjs'));
  if (fs.existsSync(sourceTools)) fs.copyFileSync(sourceTools, browserToolsPath());

  const hostPath = installHostWrapper(dir);
  const allowedOrigin = `chrome-extension://${extensionId}/`;
  atomicWriteJson(manifestPath(), {
    name: HOST_NAME,
    description: 'Browspi native Pi bridge installed by PiChat for Windows',
    path: hostPath,
    type: 'stdio',
    allowed_origins: [allowedOrigin]
  });
  if (pairingToken?.trim()) writePairingConfig(pairingToken.trim());
  else writeTrustedPairingConfig();
  installRegistry();
  return { manifestPath: manifestPath(), hostPath, allowedOrigin };
}

export function uninstallBrowserBridge(): void {
  uninstallRegistry();
  for (const file of [manifestPath(), pairingPath(), hostCommandPath(), hostExePath()]) {
    try { if (fs.existsSync(file)) fs.rmSync(file); } catch { /* ignore */ }
  }
}

function formatRelative(seconds?: number): string {
  if (!seconds) return 'Never';
  const diff = Date.now() - seconds * 1000;
  const minutes = Math.round(diff / 60000);
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes} minute${minutes === 1 ? '' : 's'} ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours} hour${hours === 1 ? '' : 's'} ago`;
  const days = Math.round(hours / 24);
  return `${days} day${days === 1 ? '' : 's'} ago`;
}

export function browserStatus(rawExtensionId = ''): BrowserStatus {
  const manifest = readJson(manifestPath());
  const pairing = readJson(pairingPath());
  const id = rawExtensionId.trim();
  let allowedOrigin = manifest?.allowed_origins?.[0] || (id ? 'Not installed' : 'Not configured');
  let statusText = manifest ? 'Native host installed · add Browspi ID to connect' : 'Not configured';

  if (id) {
    try {
      const normalized = normalizeExtensionId(id);
      const expected = `chrome-extension://${normalized}/`;
      allowedOrigin = manifest?.allowed_origins?.[0] || expected;
      const currentHost = installedHostPath();
      const installed = manifest?.path === currentHost && manifest?.allowed_origins?.includes(expected);
      const recent = pairing?.lastSeenAt ? (Date.now() / 1000 - pairing.lastSeenAt < 120) : false;
      const wrapperKind = fs.existsSync(hostExePath()) ? 'native host exe' : 'cmd fallback';
      statusText = installed ? (recent ? 'Connected' : `Installed (${wrapperKind}) — open Browspi and press Connect`) : (manifest ? 'Installed for another extension — press Connect again' : 'Not connected');
    } catch {
      statusText = 'Paste Browspi ID from the extension';
    }
  }

  const tokenHash = String(pairing?.tokenHash || '').slice(0, 12);
  let pairingStatusText = 'Pairing token not installed yet';
  if (pairing) {
    if (!pairing.pairingRequired) pairingStatusText = 'Trusted origin mode';
    else if (pairing.paired) pairingStatusText = pairing.client?.extensionId ? `Paired with ${pairing.client.extensionId}` : 'Paired';
    else pairingStatusText = tokenHash ? `Pairing required · token hash ${tokenHash}…` : 'Pairing required';
  }
  return {
    statusText,
    manifestPath: manifestPath(),
    allowedOrigin,
    lastSeenText: formatRelative(pairing?.lastSeenAt),
    pairingStatusText,
    toolsStatusText: fs.existsSync(browserToolsPath()) ? 'Browser control is on' : 'Browser tool file is missing'
  };
}
