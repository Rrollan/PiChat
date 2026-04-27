import { contextBridge, ipcRenderer } from 'electron';
import type { RuntimeSettings } from './shared/types';

const api = {
  onPiEvent: (callback: (event: any) => void) => {
    const listener = (_: unknown, payload: any) => callback(payload);
    ipcRenderer.on('pi:event', listener);
    return () => { ipcRenderer.removeListener('pi:event', listener); };
  },
  onOAuthEvent: (callback: (event: any) => void) => {
    const listener = (_: unknown, payload: any) => callback(payload);
    ipcRenderer.on('oauth:event', listener);
    return () => { ipcRenderer.removeListener('oauth:event', listener); };
  },
  initial: () => ipcRenderer.invoke('app:initial'),
  connect: (patch?: Partial<RuntimeSettings>) => ipcRenderer.invoke('pi:connect', patch),
  disconnect: () => ipcRenderer.invoke('pi:disconnect'),
  reconnect: (patch?: Partial<RuntimeSettings>) => ipcRenderer.invoke('pi:reconnect', patch),
  prompt: (message: string, images: any[]) => ipcRenderer.invoke('pi:prompt', { message, images }),
  abort: () => ipcRenderer.invoke('pi:abort'),
  newSession: () => ipcRenderer.invoke('pi:newSession'),
  compact: (custom?: string) => ipcRenderer.invoke('pi:compact', custom),
  setModel: (provider: string, modelId: string) => ipcRenderer.invoke('pi:setModel', provider, modelId),
  setThinkingLevel: (level: string) => ipcRenderer.invoke('pi:setThinkingLevel', level),
  setSteeringMode: (mode: string) => ipcRenderer.invoke('pi:setSteeringMode', mode),
  setFollowUpMode: (mode: string) => ipcRenderer.invoke('pi:setFollowUpMode', mode),
  setAutoCompaction: (enabled: boolean) => ipcRenderer.invoke('pi:setAutoCompaction', enabled),
  setAutoRetry: (enabled: boolean) => ipcRenderer.invoke('pi:setAutoRetry', enabled),
  extensionUIResponse: (payload: any) => ipcRenderer.invoke('pi:extensionUIResponse', payload),
  refreshStats: () => ipcRenderer.invoke('pi:refreshStats'),
  refreshCommands: () => ipcRenderer.invoke('pi:refreshCommands'),
  applyCustomModel: (provider: string, modelId: string) => ipcRenderer.invoke('pi:applyCustomModel', provider, modelId),
  saveRuntime: (patch: Partial<RuntimeSettings>) => ipcRenderer.invoke('runtime:save', patch),
  loadConfig: () => ipcRenderer.invoke('config:load'),
  saveRawConfig: (name: string, content: string) => ipcRenderer.invoke('config:saveRaw', name, content),
  upsertApiKey: (provider: string, key: string) => ipcRenderer.invoke('config:upsertApiKey', provider, key),
  removeAuth: (provider: string) => ipcRenderer.invoke('config:removeAuth', provider),
  upsertAccountProfile: (input: any) => ipcRenderer.invoke('config:upsertAccountProfile', input),
  setAccountProfileEnabled: (id: string, enabled: boolean) => ipcRenderer.invoke('config:setAccountProfileEnabled', id, enabled),
  removeAccountProfile: (id: string) => ipcRenderer.invoke('config:removeAccountProfile', id),
  addCustomModel: (input: any) => ipcRenderer.invoke('config:addCustomModel', input),
  connectedProviders: () => ipcRenderer.invoke('config:connectedProviders'),
  chooseFiles: () => ipcRenderer.invoke('dialog:chooseFiles'),
  chooseFolder: () => ipcRenderer.invoke('dialog:chooseFolder'),
  readAttachments: (paths: string[]) => ipcRenderer.invoke('files:readAttachments', paths),
  writeClipboardText: (text: string) => ipcRenderer.invoke('clipboard:writeText', text),
  openExternal: (url: string) => ipcRenderer.invoke('shell:openExternal', url),
  showItemInFolder: (path: string) => ipcRenderer.invoke('shell:showItemInFolder', path),
  browserStatus: () => ipcRenderer.invoke('browser:status'),
  installBrowser: (extensionId: string) => ipcRenderer.invoke('browser:install', extensionId),
  disconnectBrowser: () => ipcRenderer.invoke('browser:disconnect'),
  generatePairingToken: () => ipcRenderer.invoke('browser:generatePairingToken'),
  startOAuth: (provider: string) => ipcRenderer.invoke('oauth:start', provider),
  submitOAuthInput: (value: string) => ipcRenderer.send('oauth:input', value),
  cancelOAuth: () => ipcRenderer.send('oauth:cancel')
};

contextBridge.exposeInMainWorld('pichat', api);

export type PiChatAPI = typeof api;
