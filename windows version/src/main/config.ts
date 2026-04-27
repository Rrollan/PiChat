import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { app } from 'electron';
import type { ConfigState, MCPServerEntry, PiAccountProfile, PiAuthEntry, RuntimeSettings } from '../shared/types';

const APP_SETTINGS_FILE = 'windows-settings.json';
const ACCOUNT_PROFILES_FILE = 'pichat-accounts.json';
const CONFIG_FILE_ALLOWLIST = new Set(['settings.json', 'models.json', 'auth.json', 'mcp.json']);

export function expandHome(input: string): string {
  if (!input) return input;
  if (input === '~') return os.homedir();
  if (input.startsWith('~/') || input.startsWith('~\\')) return path.join(os.homedir(), input.slice(2));
  return input.replace(/%USERPROFILE%/gi, os.homedir());
}

export function defaultPiConfigDir(): string {
  return process.env.PI_CODING_AGENT_DIR ? expandHome(process.env.PI_CODING_AGENT_DIR) : path.join(os.homedir(), '.pi', 'agent');
}

function appSettingsPath(): string {
  return path.join(app.getPath('userData'), APP_SETTINGS_FILE);
}

function readJSON<T>(file: string, fallback: T): T {
  try {
    if (!fs.existsSync(file)) return fallback;
    const text = fs.readFileSync(file, 'utf8').trim();
    if (!text) return fallback;
    return JSON.parse(text) as T;
  } catch {
    return fallback;
  }
}

function atomicWrite(file: string, content: string): void {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.${process.pid}.${Date.now()}.tmp`;
  fs.writeFileSync(tmp, content, 'utf8');
  fs.renameSync(tmp, file);
}

function writeJSON(file: string, value: unknown): void {
  atomicWrite(file, JSON.stringify(value, null, 2));
}

export function loadRuntimeSettings(): RuntimeSettings {
  const saved = readJSON<Partial<RuntimeSettings>>(appSettingsPath(), {});
  return {
    piPath: saved.piPath || 'pi',
    startupDirectory: saved.startupDirectory || os.homedir(),
    piConfigDirectory: saved.piConfigDirectory || defaultPiConfigDir(),
    hiddenModelKeys: saved.hiddenModelKeys || [],
    browserExtensionId: saved.browserExtensionId || '',
    activeAccountProfileId: saved.activeAccountProfileId || '',
    autoAccountFailoverEnabled: saved.autoAccountFailoverEnabled ?? true,
    cliNoSession: saved.cliNoSession ?? true,
    cliProvider: saved.cliProvider || '',
    cliModel: saved.cliModel || '',
    cliApiKey: saved.cliApiKey || '',
    cliThinking: saved.cliThinking || '',
    cliModels: saved.cliModels || '',
    cliSessionDir: saved.cliSessionDir || '',
    cliSession: saved.cliSession || '',
    cliFork: saved.cliFork || '',
    cliTools: saved.cliTools || '',
    cliNoTools: saved.cliNoTools ?? false,
    cliNoExtensions: saved.cliNoExtensions ?? false,
    cliNoSkills: saved.cliNoSkills ?? false,
    cliNoPromptTemplates: saved.cliNoPromptTemplates ?? false,
    cliNoThemes: saved.cliNoThemes ?? false,
    cliNoContextFiles: saved.cliNoContextFiles ?? false,
    cliVerbose: saved.cliVerbose ?? false,
    cliSystemPrompt: saved.cliSystemPrompt || '',
    cliAppendSystemPrompt: saved.cliAppendSystemPrompt || '',
    cliExtraArgs: saved.cliExtraArgs || ''
  };
}

export function saveRuntimeSettings(settings: RuntimeSettings): RuntimeSettings {
  writeJSON(appSettingsPath(), settings);
  return settings;
}

export function assertSafeConfigName(name: string): void {
  if (path.basename(name) !== name || !CONFIG_FILE_ALLOWLIST.has(name)) {
    throw new Error(`Unsupported config file name: ${name}`);
  }
}

export function configFile(configDir: string, name: string): string {
  assertSafeConfigName(name);
  return path.join(expandHome(configDir), name);
}

export function readRawFile(configDir: string, name: string, fallback = '{}'): string {
  try {
    const file = configFile(configDir, name);
    if (!fs.existsSync(file)) return fallback;
    const text = fs.readFileSync(file, 'utf8');
    return text.trim() ? text : fallback;
  } catch {
    return fallback;
  }
}

export function writeRawFile(configDir: string, name: string, content: string): void {
  const file = configFile(configDir, name);
  JSON.parse(content);
  atomicWrite(file, content);
}

export function loadConfigState(configDir: string): ConfigState {
  const settingsJSONText = readRawFile(configDir, 'settings.json', '{}');
  const modelsJSONText = readRawFile(configDir, 'models.json', '{\n  "providers": {}\n}');
  const authJSONText = readRawFile(configDir, 'auth.json', '{}');
  const mcpJSONText = readRawFile(configDir, 'mcp.json', '{}');
  return {
    settingsJSONText,
    modelsJSONText,
    authJSONText,
    mcpJSONText,
    authEntries: loadAuthEntries(configDir),
    accountProfiles: loadAccountProfiles(configDir),
    mcpServers: loadMCPServers(configDir)
  };
}

export function maskSecret(secret: string): string {
  if (!secret) return '(empty)';
  if (secret.length <= 8) return '•'.repeat(Math.max(secret.length, 4));
  return `${secret.slice(0, 4)}••••${secret.slice(-4)}`;
}

interface StoredPiAccountProfile {
  id: string;
  name: string;
  provider: string;
  apiKey: string;
  isEnabled: boolean;
}

function accountProfilesFile(configDir: string): string {
  return path.join(expandHome(configDir), ACCOUNT_PROFILES_FILE);
}

function storedAccountProfiles(configDir: string): StoredPiAccountProfile[] {
  return readJSON<StoredPiAccountProfile[]>(accountProfilesFile(configDir), []);
}

function writeAccountProfiles(configDir: string, profiles: StoredPiAccountProfile[]): void {
  const file = accountProfilesFile(configDir);
  fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
  atomicWrite(file, JSON.stringify(profiles.sort((a, b) => a.name.localeCompare(b.name)), null, 2));
  try { fs.chmodSync(file, 0o600); } catch {}
}

export function loadAccountProfiles(configDir: string): PiAccountProfile[] {
  return storedAccountProfiles(configDir).map(p => ({
    id: p.id,
    name: p.name,
    provider: p.provider,
    keyPreview: maskSecret(p.apiKey),
    isEnabled: p.isEnabled !== false
  }));
}

export function accountProfileSecret(configDir: string, id: string): string {
  return storedAccountProfiles(configDir).find(p => p.id === id)?.apiKey || '';
}

export function upsertAccountProfile(configDir: string, input: { name: string; provider: string; apiKey: string; id?: string; isEnabled?: boolean }): PiAccountProfile {
  const name = input.name.trim();
  const provider = input.provider.trim();
  const apiKey = input.apiKey.trim();
  if (!name || !provider || !apiKey) throw new Error('Name, provider, and API key are required');
  const profiles = storedAccountProfiles(configDir);
  const id = input.id || randomUUID();
  const stored: StoredPiAccountProfile = { id, name, provider, apiKey, isEnabled: input.isEnabled ?? true };
  const idx = profiles.findIndex(p => p.id === id);
  if (idx >= 0) profiles[idx] = stored;
  else profiles.push(stored);
  writeAccountProfiles(configDir, profiles);
  return { id, name, provider, keyPreview: maskSecret(apiKey), isEnabled: stored.isEnabled };
}

export function setAccountProfileEnabled(configDir: string, id: string, isEnabled: boolean): void {
  const profiles = storedAccountProfiles(configDir);
  const idx = profiles.findIndex(p => p.id === id);
  if (idx < 0) return;
  profiles[idx].isEnabled = isEnabled;
  writeAccountProfiles(configDir, profiles);
}

export function removeAccountProfile(configDir: string, id: string): void {
  writeAccountProfiles(configDir, storedAccountProfiles(configDir).filter(p => p.id !== id));
}

export function loadAuthEntries(configDir: string): PiAuthEntry[] {
  const auth = readJSON<Record<string, any>>(configFile(configDir, 'auth.json'), {});
  return Object.entries(auth).map(([provider, value]) => ({
    id: provider,
    provider,
    type: value?.type || 'unknown',
    keyPreview: maskSecret(value?.key || value?.apiKey || '')
  })).sort((a, b) => a.provider.localeCompare(b.provider));
}

export function upsertApiKey(configDir: string, provider: string, key: string, type = 'api_key'): void {
  const file = configFile(configDir, 'auth.json');
  const auth = readJSON<Record<string, any>>(file, {});
  auth[provider] = { type, key };
  writeJSON(file, auth);
}

export function removeAuth(configDir: string, provider: string): void {
  const file = configFile(configDir, 'auth.json');
  const auth = readJSON<Record<string, any>>(file, {});
  delete auth[provider];
  writeJSON(file, auth);
}

export function addCustomModel(configDir: string, input: {
  providerId: string;
  baseUrl: string;
  api: string;
  apiKey: string;
  modelId: string;
  modelName?: string;
  reasoning: boolean;
  supportsImages: boolean;
}): void {
  const file = configFile(configDir, 'models.json');
  const root = readJSON<Record<string, any>>(file, { providers: {} });
  root.providers = root.providers || {};
  const provider = root.providers[input.providerId] || {};
  provider.baseUrl = input.baseUrl;
  provider.api = input.api;
  provider.apiKey = input.apiKey;
  const models = Array.isArray(provider.models) ? provider.models : [];
  const nextModel: Record<string, any> = {
    id: input.modelId,
    reasoning: input.reasoning,
    input: input.supportsImages ? ['text', 'image'] : ['text']
  };
  if (input.modelName?.trim()) nextModel.name = input.modelName.trim();
  const idx = models.findIndex((m: any) => m?.id === input.modelId);
  if (idx >= 0) models[idx] = { ...models[idx], ...nextModel };
  else models.push(nextModel);
  provider.models = models;
  root.providers[input.providerId] = provider;
  writeJSON(file, root);
}

export function loadMCPServers(configDir: string): MCPServerEntry[] {
  const root = readJSON<Record<string, any>>(configFile(configDir, 'mcp.json'), {});
  const servers = root.mcpServers || root.mcp?.servers || {};
  return Object.entries(servers).map(([name, value]: [string, any]) => ({
    id: name,
    name,
    description: value?.description?.trim?.() || 'MCP server'
  })).sort((a, b) => a.name.localeCompare(b.name));
}

export function configuredModelProviderIDs(configDir: string): Set<string> {
  const root = readJSON<Record<string, any>>(configFile(configDir, 'models.json'), {});
  return new Set(Object.keys(root.providers || {}).map(normalizeProviderID));
}

export function normalizeProviderID(provider: string): string {
  return provider.trim().toLowerCase().replaceAll('_', '-');
}

export function resourcePath(...parts: string[]): string {
  if (app.isPackaged) return path.join(process.resourcesPath, ...parts);
  return path.join(app.getAppPath(), ...parts);
}

function bundledPiFile(relativeDistPath: string): string | null {
  const relative = path.join('node_modules', '@mariozechner', 'pi-coding-agent', 'dist', relativeDistPath);
  const candidates = app.isPackaged
    ? [
        path.join(process.resourcesPath, 'app.asar.unpacked', relative),
        path.join(process.resourcesPath, 'app.asar', relative),
        path.join(app.getAppPath(), relative)
      ]
    : [path.join(app.getAppPath(), relative)];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

export function bundledPiCliPath(): string | null {
  return bundledPiFile('cli.js');
}

export function bundledPiAuthStoragePath(): string | null {
  return bundledPiFile(path.join('core', 'auth-storage.js'));
}

export function browserToolsExtensionPath(): string {
  const packaged = resourcePath('resources', 'browser-tools', 'index.ts');
  return packaged;
}
