import { app, BrowserWindow, dialog, ipcMain, shell, clipboard } from 'electron';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { spawn, ChildProcessWithoutNullStreams } from 'node:child_process';
import { PiRPCClient } from './piRpcClient';
import {
  addCustomModel,
  browserToolsExtensionPath,
  bundledPiAuthStoragePath,
  configuredModelProviderIDs,
  configFile,
  defaultPiConfigDir,
  loadConfigState,
  loadRuntimeSettings,
  normalizeProviderID,
  removeAuth,
  saveRuntimeSettings,
  upsertApiKey,
  writeRawFile,
  expandHome
} from './config';
import { browserStatus, generatePairingToken, installBrowserBridge, uninstallBrowserBridge, writePairingConfig } from './nativeMessaging';
import type { FileAttachment, RuntimeSettings, SessionStats } from '../shared/types';

let mainWindow: BrowserWindow | null = null;
let settings: RuntimeSettings;
let activeOAuthProcess: ChildProcessWithoutNullStreams | null = null;
const rpc = new PiRPCClient();
const MAX_ATTACHMENT_BYTES = 25 * 1024 * 1024;

function rendererUrl(): string {
  if (!app.isPackaged && process.env.VITE_DEV_SERVER_URL) return process.env.VITE_DEV_SERVER_URL;
  if (!app.isPackaged) return 'http://127.0.0.1:5173';
  return pathToFileURL(path.join(__dirname, '..', 'renderer', 'index.html')).toString();
}

function preloadPath(): string {
  return app.isPackaged ? path.join(__dirname, '..', 'preload.js') : path.join(app.getAppPath(), 'dist', 'preload.js');
}

function send(channel: string, payload: unknown): void {
  mainWindow?.webContents.send(channel, payload);
}

function createWindow(): void {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 900,
    minHeight: 600,
    title: 'PiChat',
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#20201D',
    webPreferences: {
      preload: preloadPath(),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false
    }
  });
  mainWindow.loadURL(rendererUrl());
  mainWindow.on('closed', () => { mainWindow = null; });
}

function buildRpcLaunchArguments(s: RuntimeSettings): string[] {
  const args: string[] = [];
  if (s.cliNoSession) args.push('--no-session');
  if (s.cliProvider.trim()) args.push('--provider', s.cliProvider.trim());
  if (s.cliModel.trim()) args.push('--model', s.cliModel.trim());
  if (s.cliApiKey.trim()) args.push('--api-key', s.cliApiKey.trim());
  if (s.cliThinking.trim()) args.push('--thinking', s.cliThinking.trim());
  if (s.cliModels.trim()) args.push('--models', s.cliModels.trim());
  if (s.cliSessionDir.trim()) args.push('--session-dir', s.cliSessionDir.trim());
  if (s.cliSession.trim()) args.push('--session', s.cliSession.trim());
  if (s.cliFork.trim()) args.push('--fork', s.cliFork.trim());
  if (s.cliTools.trim()) args.push('--tools', s.cliTools.trim());
  if (s.cliNoTools) args.push('--no-tools');
  if (s.cliNoExtensions) args.push('--no-extensions');
  if (s.cliNoSkills) args.push('--no-skills');
  if (s.cliNoPromptTemplates) args.push('--no-prompt-templates');
  if (s.cliNoThemes) args.push('--no-themes');
  if (s.cliNoContextFiles) args.push('--no-context-files');
  if (s.cliVerbose) args.push('--verbose');
  const browserTools = browserToolsExtensionPath();
  if (!s.cliNoExtensions && fs.existsSync(browserTools)) args.push('--extension', browserTools);
  if (s.cliSystemPrompt.trim()) args.push('--system-prompt', s.cliSystemPrompt.trim());
  if (s.cliAppendSystemPrompt.trim()) args.push('--append-system-prompt', s.cliAppendSystemPrompt.trim());
  args.push(...parseCommandLineArgs(s.cliExtraArgs));
  return args;
}

function parseCommandLineArgs(input: string): string[] {
  const args: string[] = [];
  let current = '';
  let quote: '"' | "'" | null = null;
  let escaping = false;
  for (const char of input) {
    if (escaping) { current += char; escaping = false; continue; }
    if (char === '\\') { escaping = true; continue; }
    if ((char === '"' || char === "'") && !quote) { quote = char; continue; }
    if (quote === char) { quote = null; continue; }
    if (!quote && /\s/.test(char)) {
      if (current) { args.push(current); current = ''; }
      continue;
    }
    current += char;
  }
  if (escaping) current += '\\';
  if (current) args.push(current);
  return args;
}

async function connect(next?: Partial<RuntimeSettings>) {
  settings = saveRuntimeSettings({ ...settings, ...next });
  rpc.piPath = settings.piPath.trim() || 'pi';
  rpc.workingDirectory = expandHome(settings.startupDirectory || os.homedir());
  rpc.launchArguments = buildRpcLaunchArguments(settings);
  rpc.enableDebugLogging = settings.cliVerbose;
  await rpc.start();
  await new Promise(r => setTimeout(r, 800));
  const [state, models, commands, stats] = await Promise.all([
    rpc.getState().catch(() => null),
    rpc.getAvailableModels().catch(() => []),
    rpc.getCommands().catch(() => []),
    rpc.getSessionStats().catch(() => null)
  ]);
  return { isConnected: rpc.isRunning, state, models, commands, stats, config: loadConfigState(settings.piConfigDirectory), settings, browser: browserStatus(settings.browserExtensionId) };
}

function refreshStatsFromData(data: any): SessionStats {
  return {
    tokenInput: data?.tokens?.input || 0,
    tokenOutput: data?.tokens?.output || 0,
    tokenTotal: data?.tokens?.total || 0,
    sessionCost: data?.cost || 0,
    contextPercent: data?.contextUsage?.percent || 0,
    contextTokens: data?.contextUsage?.tokens || 0,
    contextWindow: data?.contextUsage?.contextWindow || 0
  };
}

function mimeType(filePath: string): string {
  const ext = path.extname(filePath).toLowerCase().slice(1);
  const map: Record<string, string> = {
    jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', gif: 'image/gif', webp: 'image/webp', bmp: 'image/bmp', svg: 'image/svg+xml', heic: 'image/heic',
    pdf: 'application/pdf', txt: 'text/plain', md: 'text/markdown', json: 'application/json', js: 'text/javascript', ts: 'text/typescript', tsx: 'text/typescript', html: 'text/html', css: 'text/css'
  };
  return map[ext] || 'application/octet-stream';
}

function readAttachments(paths: string[]): FileAttachment[] {
  const attachments: FileAttachment[] = [];
  for (const rawPath of paths.filter(Boolean)) {
    try {
      const filePath = path.resolve(expandHome(rawPath));
      const stat = fs.statSync(filePath);
      if (!stat.isFile()) continue;
      const mime = mimeType(filePath);
      let base64Data: string | undefined;
      if (mime.startsWith('image/') && stat.size <= MAX_ATTACHMENT_BYTES) {
        base64Data = fs.readFileSync(filePath).toString('base64');
      }
      attachments.push({ id: cryptoRandomId(), path: filePath, name: path.basename(filePath), mimeType: mime, base64Data });
    } catch (error: any) {
      send('pi:event', { type: 'process_stderr', message: `Attachment skipped: ${error?.message || String(error)}` });
    }
  }
  return attachments;
}

function cryptoRandomId(): string { return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`; }

function setupIpc(): void {
  rpc.on('event', (event) => send('pi:event', event));

  ipcMain.handle('app:initial', () => ({ settings, config: loadConfigState(settings.piConfigDirectory), browser: browserStatus(settings.browserExtensionId), isConnected: rpc.isRunning }));
  ipcMain.handle('pi:connect', (_e, patch?: Partial<RuntimeSettings>) => connect(patch));
  ipcMain.handle('pi:disconnect', () => { rpc.stop(); return { ok: true }; });
  ipcMain.handle('pi:reconnect', async (_e, patch?: Partial<RuntimeSettings>) => { rpc.stop(); return connect(patch); });
  ipcMain.handle('pi:prompt', (_e, payload: { message: string; images?: any[] }) => rpc.prompt(payload.message, payload.images || []));
  ipcMain.handle('pi:abort', () => rpc.abort());
  ipcMain.handle('pi:newSession', () => rpc.newSession());
  ipcMain.handle('pi:compact', (_e, custom?: string) => rpc.compact(custom));
  ipcMain.handle('pi:setModel', (_e, provider: string, modelId: string) => rpc.setModel(provider, modelId));
  ipcMain.handle('pi:setThinkingLevel', (_e, level: string) => rpc.setThinkingLevel(level));
  ipcMain.handle('pi:setSteeringMode', (_e, mode: string) => rpc.setSteeringMode(mode));
  ipcMain.handle('pi:setFollowUpMode', (_e, mode: string) => rpc.setFollowUpMode(mode));
  ipcMain.handle('pi:setAutoCompaction', (_e, enabled: boolean) => rpc.setAutoCompaction(enabled));
  ipcMain.handle('pi:setAutoRetry', (_e, enabled: boolean) => rpc.setAutoRetry(enabled));
  ipcMain.handle('pi:extensionUIResponse', (_e, payload: Record<string, unknown>) => rpc.sendExtensionUIResponse(payload));
  ipcMain.handle('pi:refreshStats', async () => refreshStatsFromData(await rpc.getSessionStats()));
  ipcMain.handle('pi:refreshCommands', () => rpc.getCommands());
  ipcMain.handle('pi:applyCustomModel', async (_e, provider: string, modelId: string) => rpc.setModel(provider, modelId));

  ipcMain.handle('runtime:save', (_e, patch: Partial<RuntimeSettings>) => { settings = saveRuntimeSettings({ ...settings, ...patch }); return settings; });
  ipcMain.handle('config:load', () => loadConfigState(settings.piConfigDirectory));
  ipcMain.handle('config:saveRaw', (_e, name: string, content: string) => { writeRawFile(settings.piConfigDirectory, name, content); return loadConfigState(settings.piConfigDirectory); });
  ipcMain.handle('config:upsertApiKey', (_e, provider: string, key: string) => { upsertApiKey(settings.piConfigDirectory, provider, key); return loadConfigState(settings.piConfigDirectory); });
  ipcMain.handle('config:removeAuth', (_e, provider: string) => { removeAuth(settings.piConfigDirectory, provider); return loadConfigState(settings.piConfigDirectory); });
  ipcMain.handle('config:addCustomModel', (_e, input: any) => { addCustomModel(settings.piConfigDirectory, input); return loadConfigState(settings.piConfigDirectory); });
  ipcMain.handle('config:connectedProviders', () => Array.from(new Set([...loadConfigState(settings.piConfigDirectory).authEntries.map(e => normalizeProviderID(e.provider)), ...configuredModelProviderIDs(settings.piConfigDirectory)])));

  ipcMain.handle('dialog:chooseFiles', async () => {
    const res = await dialog.showOpenDialog(mainWindow!, { properties: ['openFile', 'multiSelections'] });
    return res.canceled ? [] : readAttachments(res.filePaths);
  });
  ipcMain.handle('dialog:chooseFolder', async () => {
    const res = await dialog.showOpenDialog(mainWindow!, { properties: ['openDirectory'] });
    return res.canceled ? null : res.filePaths[0];
  });
  ipcMain.handle('files:readAttachments', (_e, paths: string[]) => readAttachments(paths));
  ipcMain.handle('clipboard:writeText', (_e, text: string) => clipboard.writeText(text));
  ipcMain.handle('shell:openExternal', (_e, url: string) => shell.openExternal(url));
  ipcMain.handle('shell:showItemInFolder', (_e, filePath: string) => shell.showItemInFolder(filePath));

  ipcMain.handle('browser:status', () => browserStatus(settings.browserExtensionId));
  ipcMain.handle('browser:install', (_e, extensionId: string) => { settings = saveRuntimeSettings({ ...settings, browserExtensionId: extensionId }); const result = installBrowserBridge(extensionId); return { result, status: browserStatus(extensionId) }; });
  ipcMain.handle('browser:disconnect', () => { uninstallBrowserBridge(); return browserStatus(settings.browserExtensionId); });
  ipcMain.handle('browser:generatePairingToken', () => { const token = generatePairingToken(); writePairingConfig(token); return { token, status: browserStatus(settings.browserExtensionId) }; });

  ipcMain.handle('oauth:start', (_e, provider: string) => runOAuthLogin(provider));
}

async function runOAuthLogin(provider: string): Promise<{ ok: true }> {
  if (activeOAuthProcess) throw new Error('OAuth login is already running');
  const providerId = provider.trim();
  if (!providerId) throw new Error('Provider is required');

  const authPath = configFile(settings.piConfigDirectory || defaultPiConfigDir(), 'auth.json');
  const script = `
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
import readline from 'node:readline';
const require = createRequire(import.meta.url);
const providerId = process.argv[1];
const authPath = process.argv[2];
function resolveAuthStorage() {
  const candidates = [];
  if (process.env.PI_AUTH_STORAGE_MODULE) candidates.push(process.env.PI_AUTH_STORAGE_MODULE);
  try { candidates.push(require.resolve('@mariozechner/pi-coding-agent/dist/core/auth-storage.js')); } catch {}
  try { const root = execFileSync(process.platform === 'win32' ? 'npm.cmd' : 'npm', ['root', '-g'], { encoding: 'utf8' }).trim(); candidates.push(require.resolve('@mariozechner/pi-coding-agent/dist/core/auth-storage.js', { paths: [root] })); } catch {}
  for (const c of candidates) if (c) return c;
  throw new Error('Cannot resolve @mariozechner/pi-coding-agent AuthStorage. Install pi globally with npm.');
}
const send = (obj) => process.stdout.write(JSON.stringify(obj) + '\\n');
const rl = readline.createInterface({ input: process.stdin, output: process.stdout, terminal: false });
const readInputLine = () => new Promise(resolve => rl.once('line', line => resolve((line ?? '').trim())));
try {
  const modulePath = resolveAuthStorage();
  const { AuthStorage } = await import(modulePath.startsWith('file:') ? modulePath : pathToFileURL(modulePath).href);
  const storage = AuthStorage.create(authPath);
  await storage.login(providerId, {
    onAuth: (info) => send({ type: 'auth', url: info?.url ?? '', instructions: info?.instructions ?? '' }),
    onProgress: (message) => send({ type: 'progress', message: message ?? '' }),
    onPrompt: async (prompt) => { send({ type: 'prompt', message: prompt?.message ?? 'Enter the requested value', placeholder: prompt?.placeholder ?? '' }); return await readInputLine(); },
    onManualCodeInput: async () => { send({ type: 'manual', message: 'Paste the authorization code or full redirect URL.' }); return await readInputLine(); }
  });
  send({ type: 'done' });
  rl.close();
} catch (error) { send({ type: 'error', message: error?.message ?? String(error) }); rl.close(); process.exit(1); }
`;
  return await new Promise((resolve, reject) => {
    const bundledAuthStorage = bundledPiAuthStoragePath();
    const proc = spawn(process.execPath, ['--input-type=module', '-e', script, providerId, authPath], {
      windowsHide: true,
      env: { ...process.env, ELECTRON_RUN_AS_NODE: '1', ...(bundledAuthStorage ? { PI_AUTH_STORAGE_MODULE: bundledAuthStorage } : {}) }
    });
    activeOAuthProcess = proc;
    proc.stdout.setEncoding('utf8');
    proc.stderr.setEncoding('utf8');
    let buf = '';

    const inputHandler = (_event: Electron.IpcMainEvent, value: string) => {
      if (activeOAuthProcess !== proc || proc.killed || !proc.stdin.writable) return;
      proc.stdin.write(`${String(value || '').trim()}\n`);
    };
    const cancelHandler = () => {
      if (activeOAuthProcess === proc && !proc.killed) proc.kill();
    };
    const cleanup = () => {
      ipcMain.removeListener('oauth:input', inputHandler);
      ipcMain.removeListener('oauth:cancel', cancelHandler);
      if (activeOAuthProcess === proc) activeOAuthProcess = null;
    };

    ipcMain.on('oauth:input', inputHandler);
    ipcMain.on('oauth:cancel', cancelHandler);

    proc.stdout.on('data', chunk => {
      buf += chunk;
      let i = buf.indexOf('\n');
      while (i >= 0) {
        const line = buf.slice(0, i).trim();
        buf = buf.slice(i + 1);
        if (line) {
          try {
            const event = JSON.parse(line);
            send('oauth:event', event);
            if (event.type === 'auth' && event.url) shell.openExternal(event.url);
          } catch {}
        }
        i = buf.indexOf('\n');
      }
    });
    proc.stderr.on('data', chunk => send('oauth:event', { type: 'progress', message: String(chunk).trim() }));
    proc.on('error', error => { cleanup(); reject(error); });
    proc.on('exit', code => {
      cleanup();
      code === 0 ? resolve({ ok: true }) : reject(new Error(`OAuth helper failed (${code})`));
    });
  });
}

app.whenReady().then(() => {
  settings = loadRuntimeSettings();
  setupIpc();
  createWindow();
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});

app.on('window-all-closed', () => {
  rpc.stop();
  if (process.platform !== 'darwin') app.quit();
});
