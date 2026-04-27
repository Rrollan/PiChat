import { useEffect, useMemo, useRef, useState } from 'react';
import type { AgentCommand, AgentModel, AppNotification, BrowserStatus, ChatMessage, ConfigState, ExtensionUIRequest, FileAttachment, MCPServerEntry, PiEvent, PastedContent, RuntimeSettings, SessionStats, ToolCall } from '../shared/types';

type SettingsSection = 'general' | 'accounts' | 'project' | 'browser' | 'advanced';

const imageAsset = (name: string) => new URL(`../../public/images/${name}`, import.meta.url).href;
const LOGO_LIGHT = imageAsset('pilogo_light.png');
const LOGO_TRANSPARENT = imageAsset('pilogo_transparent.png');

const id = () => `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
const now = () => Date.now();
const modelKey = (m?: AgentModel | null) => m ? `${m.provider}/${m.id}` : '';
const wordCount = (s: string) => s.trim().split(/\s+/).filter(Boolean).length;
const fmtK = (n = 0) => n >= 1000 ? `${(n / 1000).toFixed(1)}k` : String(n);
const basename = (p = '') => p.split(/[\\/]/).filter(Boolean).pop() || p || 'Home';
const shortTime = (ts: number) => new Date(ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
const extractOAuthCode = (instructions = '') => instructions.match(/code:\s*([A-Z0-9-]{4,})/i)?.[1] || instructions.match(/\b([A-Z0-9]{4}-[A-Z0-9]{4})\b/)?.[1] || instructions.match(/\b([A-Z0-9]{8})\b/)?.[1] || '';

const defaultSettings: RuntimeSettings = {
  piPath: 'pi', startupDirectory: '', piConfigDirectory: '', hiddenModelKeys: [], browserExtensionId: '', activeAccountProfileId: '', autoAccountFailoverEnabled: true, cliNoSession: true,
  cliProvider: '', cliModel: '', cliApiKey: '', cliThinking: '', cliModels: '', cliSessionDir: '', cliSession: '', cliFork: '', cliTools: '',
  cliNoTools: false, cliNoExtensions: false, cliNoSkills: false, cliNoPromptTemplates: false, cliNoThemes: false, cliNoContextFiles: false, cliVerbose: false,
  cliSystemPrompt: '', cliAppendSystemPrompt: '', cliExtraArgs: ''
};
const emptyConfig: ConfigState = { settingsJSONText: '{}', modelsJSONText: '{\n  "providers": {}\n}', authJSONText: '{}', mcpJSONText: '{}', authEntries: [], accountProfiles: [], mcpServers: [] };
const emptyStats: SessionStats = { tokenInput: 0, tokenOutput: 0, tokenTotal: 0, sessionCost: 0, contextPercent: 0, contextTokens: 0, contextWindow: 0 };
const emptyBrowser: BrowserStatus = { statusText: 'Not configured', manifestPath: '', allowedOrigin: 'Not configured', lastSeenText: 'Never', pairingStatusText: 'Not paired', toolsStatusText: 'Browser control is on' };

export default function App() {
  const [settings, setSettings] = useState<RuntimeSettings>(defaultSettings);
  const [config, setConfig] = useState<ConfigState>(emptyConfig);
  const [browser, setBrowser] = useState<BrowserStatus>(emptyBrowser);
  const [connectedProviders, setConnectedProviders] = useState<string[]>([]);

  const [isConnected, setConnected] = useState(false);
  const [isStarting, setStarting] = useState(true);
  const [connectionError, setConnectionError] = useState('');
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [currentAssistantId, setCurrentAssistantId] = useState<string | null>(null);
  const [isStreaming, setStreaming] = useState(false);
  const [isWaiting, setWaiting] = useState(false);
  const [currentModel, setCurrentModel] = useState<AgentModel | null>(null);
  const [availableModels, setAvailableModels] = useState<AgentModel[]>([]);
  const [thinkingLevel, setThinkingLevelState] = useState('off');
  const [steeringMode, setSteeringModeState] = useState('one-at-a-time');
  const [followUpMode, setFollowUpModeState] = useState('one-at-a-time');
  const [autoCompactionEnabled, setAutoCompactionEnabled] = useState(true);
  const [autoRetryEnabled, setAutoRetryEnabled] = useState(true);
  const [sessionFile, setSessionFile] = useState<string | null>(null);
  const [sessionName, setSessionName] = useState<string | null>(null);
  const [stats, setStats] = useState<SessionStats>(emptyStats);
  const [commands, setCommands] = useState<AgentCommand[]>([]);
  const [steeringQueue, setSteeringQueue] = useState<string[]>([]);
  const [followUpQueue, setFollowUpQueue] = useState<string[]>([]);
  const [activeTools, setActiveTools] = useState<ToolCall[]>([]);
  const [isCompacting, setCompacting] = useState(false);
  const [isRetrying, setRetrying] = useState(false);
  const [retryMessage, setRetryMessage] = useState('');
  const [notification, setNotification] = useState<AppNotification | null>(null);
  const [pendingUIRequest, setPendingUIRequest] = useState<ExtensionUIRequest | null>(null);
  const [inputText, setInputText] = useState('');
  const [attachedFiles, setAttachedFiles] = useState<FileAttachment[]>([]);
  const [pastedContents, setPastedContents] = useState<PastedContent[]>([]);
  const [showRightPanel, setShowRightPanel] = useState(localStorage.getItem('ui.showRightPanel') !== 'false');
  const [showSettings, setShowSettings] = useState(false);
  const [themeMode, setThemeMode] = useState(localStorage.getItem('ui.themeMode') || 'system');
  const bottomRef = useRef<HTMLDivElement>(null);

  const notify = (message: string, type: AppNotification['type'] = 'info') => {
    const next = { id: id(), message, type };
    setNotification(next);
    window.setTimeout(() => setNotification(n => n?.id === next.id ? null : n), 3200);
  };

  const applyRpcState = (data: any) => {
    if (!data) return;
    if (data.model !== undefined) setCurrentModel(data.model);
    if (data.thinkingLevel) setThinkingLevelState(data.thinkingLevel);
    if (data.sessionFile !== undefined) setSessionFile(data.sessionFile);
    if (data.sessionName !== undefined) setSessionName(data.sessionName);
    if (data.isStreaming !== undefined) setStreaming(Boolean(data.isStreaming));
    if (data.isCompacting !== undefined) setCompacting(Boolean(data.isCompacting));
    if (data.steeringMode) setSteeringModeState(data.steeringMode);
    if (data.followUpMode) setFollowUpModeState(data.followUpMode);
    if (data.autoCompactionEnabled !== undefined) setAutoCompactionEnabled(Boolean(data.autoCompactionEnabled));
    if (data.autoRetryEnabled !== undefined) setAutoRetryEnabled(Boolean(data.autoRetryEnabled));
  };

  const applyStats = (data: any) => {
    if (!data) return;
    setStats({ tokenInput: data.tokens?.input || data.tokenInput || 0, tokenOutput: data.tokens?.output || data.tokenOutput || 0, tokenTotal: data.tokens?.total || data.tokenTotal || 0, sessionCost: data.cost || data.sessionCost || 0, contextPercent: data.contextUsage?.percent || data.contextPercent || 0, contextTokens: data.contextUsage?.tokens || data.contextTokens || 0, contextWindow: data.contextUsage?.contextWindow || data.contextWindow || 0 });
  };

  const boot = async () => {
    setStarting(true);
    setConnectionError('');
    try {
      const initial = await window.pichat.initial();
      setSettings({ ...defaultSettings, ...initial.settings });
      setConfig(initial.config || emptyConfig);
      setBrowser(initial.browser || emptyBrowser);
      setConnected(Boolean(initial.isConnected));
      const providers = await window.pichat.connectedProviders().catch(() => []);
      setConnectedProviders(providers);
      if (!initial.isConnected) {
        const result = await window.pichat.connect();
        setConnected(Boolean(result.isConnected));
        applyRpcState(result.state);
        setAvailableModels(result.models || []);
        setCommands(result.commands || []);
        applyStats(result.stats);
        setConfig(result.config || emptyConfig);
        setBrowser(result.browser || emptyBrowser);
      }
    } catch (e: any) {
      setConnectionError(e?.message || String(e));
      setConnected(false);
    } finally {
      setStarting(false);
    }
  };

  useEffect(() => { boot(); }, []);
  useEffect(() => {
    const off = window.pichat.onPiEvent((event: PiEvent) => handlePiEvent(event));
    return off;
  }, [currentAssistantId]);
  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' }); }, [messages, isWaiting, isRetrying, isCompacting]);
  useEffect(() => {
    document.documentElement.dataset.theme = themeMode === 'system' ? (matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark') : themeMode;
    localStorage.setItem('ui.themeMode', themeMode);
  }, [themeMode]);
  useEffect(() => { localStorage.setItem('ui.showRightPanel', String(showRightPanel)); }, [showRightPanel]);

  const updateAssistant = (fn: (m: ChatMessage) => ChatMessage) => setMessages(prev => prev.map(m => m.id === currentAssistantId ? fn(m) : m));
  const ensureAssistant = () => {
    let assistantId = currentAssistantId;
    if (!assistantId) {
      assistantId = id();
      setCurrentAssistantId(assistantId);
      setMessages(prev => [...prev, { id: assistantId!, role: 'assistant', text: '', thinkingText: '', toolCalls: [], isStreaming: true, timestamp: now() }]);
    }
    return assistantId;
  };

  const handlePiEvent = (event: PiEvent) => {
    switch (event.type) {
      case 'agent_start': {
        setWaiting(false); setStreaming(true); ensureAssistant();
        setMessages(prev => prev.map(m => m.id === currentAssistantId ? { ...m, isStreaming: true } : m));
        break;
      }
      case 'agent_end':
        setWaiting(false); setStreaming(false); setMessages(prev => prev.map(m => m.id === currentAssistantId ? { ...m, isStreaming: false } : m)); setCurrentAssistantId(null); window.pichat.refreshStats().then(applyStats).catch(() => {}); break;
      case 'message_update':
        ensureAssistant();
        if (event.deltaType === 'text_delta') updateAssistant(m => ({ ...m, text: (m.text || '') + (event.delta || '') }));
        if (event.deltaType === 'thinking_delta') updateAssistant(m => ({ ...m, thinkingText: (m.thinkingText || '') + (event.delta || ''), showThinking: true }));
        break;
      case 'tool_execution_start': {
        ensureAssistant();
        const tool: ToolCall = { id: event.toolCallId, name: event.toolName, args: event.args ? JSON.stringify(event.args) : '', output: '', isError: false, isRunning: true };
        setActiveTools(prev => [...prev, tool]);
        updateAssistant(m => ({ ...m, toolCalls: [...(m.toolCalls || []), tool] }));
        break;
      }
      case 'tool_execution_update':
        setActiveTools(prev => prev.map(t => t.id === event.toolCallId ? { ...t, output: event.partialText } : t));
        updateAssistant(m => ({ ...m, toolCalls: (m.toolCalls || []).map(t => t.id === event.toolCallId ? { ...t, output: event.partialText } : t) }));
        break;
      case 'tool_execution_end':
        setActiveTools(prev => prev.map(t => t.id === event.toolCallId ? { ...t, output: event.resultText, isError: event.isError, isRunning: false } : t));
        window.setTimeout(() => setActiveTools(prev => prev.filter(t => t.id !== event.toolCallId || t.isRunning)), 2000);
        updateAssistant(m => ({ ...m, toolCalls: (m.toolCalls || []).map(t => t.id === event.toolCallId ? { ...t, output: event.resultText, isError: event.isError, isRunning: false } : t) }));
        break;
      case 'queue_update': setSteeringQueue(event.steering); setFollowUpQueue(event.followUp); break;
      case 'compaction_start': setCompacting(true); setMessages(prev => [...prev, systemMessage('🗜 Compacting context…')]); break;
      case 'compaction_end': setCompacting(false); setMessages(prev => [...prev, systemMessage('✅ Compaction complete')]); break;
      case 'auto_retry_start': setRetrying(true); setRetryMessage(`Retrying (${event.attempt}/${event.maxAttempts}) in ${Math.round(event.delayMs / 1000)}s…`); break;
      case 'auto_retry_end': setRetrying(false); setRetryMessage(''); if (!event.success && event.finalError) setMessages(prev => [...prev, systemMessage(`❌ Failed after retries: ${event.finalError}`)]); break;
      case 'extension_ui_request':
        if (event.request.method === 'notify') notify(event.request.message || event.request.title || '', (event.request.notifyType as any) || 'info');
        else setPendingUIRequest(event.request);
        break;
      case 'extension_error': notify(`Extension error: ${event.error}`, 'warning'); break;
      case 'process_stderr': if (/error|failed|429|limit/i.test(event.message)) console.warn(event.message); break;
      case 'response':
        if (event.error) { notify(event.error, 'error'); if (event.command === 'prompt') setMessages(prev => [...prev, systemMessage(`❌ Agent response error: ${event.error}`)]); }
        if (event.command === 'set_model' || event.command === 'cycle_model') applyRpcState(event.data);
        break;
    }
  };

  const systemMessage = (text: string): ChatMessage => ({ id: id(), role: 'system', text, timestamp: now() });

  const sendMessage = async () => {
    const text = inputText.trim();
    if (!text && attachedFiles.length === 0 && pastedContents.length === 0) return;
    const pastedText = pastedContents.map(p => `\n\n--- Pasted content (${wordCount(p.content)} words) ---\n${p.content}`).join('');
    const promptText = text + pastedText;
    const displayText = text || (pastedContents.length ? 'Pasted content attached' : '');
    const userMsg: ChatMessage = { id: id(), role: 'user', text: displayText, attachments: attachedFiles, timestamp: now() };
    const assistantId = id();
    setMessages(prev => [...prev, userMsg, { id: assistantId, role: 'assistant', text: '', thinkingText: '', toolCalls: [], timestamp: now(), isStreaming: true }]);
    setCurrentAssistantId(assistantId);
    const images = attachedFiles.filter(a => a.mimeType.startsWith('image/') && a.base64Data).map(a => ({ type: 'image' as const, data: a.base64Data!, mimeType: a.mimeType }));
    setInputText(''); setAttachedFiles([]); setPastedContents([]); setWaiting(true);
    try { await window.pichat.prompt(promptText, images); } catch (e: any) { const message = e?.message || String(e); if (settings.autoAccountFailoverEnabled && /rate limit|ratelimit|too many requests|429|quota|insufficient_quota|resource_exhausted|limit exceeded|usage limit/i.test(message)) { const active = settings.activeAccountProfileId; const provider = (config.accountProfiles.find(p=>p.id===active)?.provider || currentModel?.provider || '').toLowerCase().replaceAll('_','-'); const candidates = config.accountProfiles.filter(p=>p.isEnabled && p.id!==active); const next = candidates.find(p=>p.provider.toLowerCase().replaceAll('_','-')===provider) || candidates[0]; if (next) { notify(`Switching account: ${next.name}`, 'warning'); setMessages(prev => [...prev, systemMessage(`↪️ Limit reached. Switching to ${next.name} (${next.provider}) and retrying…`)]); const nextSettings = await window.pichat.saveRuntime({activeAccountProfileId:next.id}); setSettings(nextSettings); const res = await window.pichat.reconnect(nextSettings); setConnected(true); applyRpcState(res.state); setAvailableModels(res.models || []); setCommands(res.commands || []); applyStats(res.stats); setConfig(res.config); if (currentModel && currentModel.provider.toLowerCase().replaceAll('_','-')===next.provider.toLowerCase().replaceAll('_','-')) await window.pichat.setModel(currentModel.provider,currentModel.id).catch(()=>{}); setWaiting(true); try { await window.pichat.prompt(promptText, images); return; } catch (retryError:any) { notify(retryError?.message || String(retryError), 'error'); } } } setWaiting(false); notify(message, 'error'); setMessages(prev => [...prev, systemMessage(`❌ ${message}`)]); }
  };

  const abort = async () => { setWaiting(false); await window.pichat.abort().catch(e => notify(e.message, 'error')); };
  const addAttachments = (files: FileAttachment[]) => { setAttachedFiles(prev => [...prev, ...files.filter(f => !prev.some(p => p.path === f.path))]); if (files.length) notify(`Files added: ${files.length}`, 'success'); };
  const chooseFiles = async () => addAttachments(await window.pichat.chooseFiles());
  const reconnect = async (patch?: Partial<RuntimeSettings>) => { setStarting(true); try { const res = await window.pichat.reconnect(patch); setConnected(true); applyRpcState(res.state); setAvailableModels(res.models || []); setCommands(res.commands || []); applyStats(res.stats); setConfig(res.config); setBrowser(res.browser); notify('Reconnected', 'success'); } catch (e: any) { setConnectionError(e.message); notify(e.message, 'error'); } finally { setStarting(false); } };
  const refreshConfig = async () => { setConfig(await window.pichat.loadConfig()); setConnectedProviders(await window.pichat.connectedProviders().catch(() => [])); };

  const connectedModels = useMemo(() => {
    const providers = new Set([...connectedProviders, ...config.authEntries.map(e => e.provider.toLowerCase()), ...config.accountProfiles.filter(p => p.isEnabled).map(p => p.provider.toLowerCase()), ...(currentModel ? [currentModel.provider.toLowerCase()] : [])].map(p => p.replaceAll('_', '-')));
    if (!providers.size) return availableModels;
    return availableModels.filter(m => providers.has(m.provider.toLowerCase().replaceAll('_', '-')));
  }, [availableModels, connectedProviders, config.authEntries, config.accountProfiles, currentModel]);
  const visibleModels = connectedModels.filter(m => !settings.hiddenModelKeys.includes(modelKey(m)) || modelKey(m) === modelKey(currentModel));
  const hiddenModels = connectedModels.filter(m => settings.hiddenModelKeys.includes(modelKey(m)) && modelKey(m) !== modelKey(currentModel));

  if (isStarting && !isConnected) return <LoadingView error={connectionError} retry={() => boot()} />;

  return <div className="app-shell" onDragOver={e => e.preventDefault()} onDrop={async e => { e.preventDefault(); const paths = Array.from(e.dataTransfer.files).map((f: any) => f.path).filter(Boolean); if (paths.length) addAttachments(await window.pichat.readAttachments(paths)); }}>
    {isConnected ? <>
      <Sidebar settings={settings} setSettings={setSettings} currentModel={currentModel} models={visibleModels} hiddenModels={hiddenModels} commands={commands} stats={stats} config={config} thinkingLevel={thinkingLevel} onModel={async m => { await window.pichat.setModel(m.provider, m.id); setCurrentModel(m); }} onThinking={async lvl => { await window.pichat.setThinkingLevel(lvl); setThinkingLevelState(lvl); }} onHideModel={async m => { const next = [...settings.hiddenModelKeys, modelKey(m)].sort(); setSettings({ ...settings, hiddenModelKeys: next }); await window.pichat.saveRuntime({ hiddenModelKeys: next }); }} onShowModel={async m => { const next = settings.hiddenModelKeys.filter(k => k !== modelKey(m)); setSettings({ ...settings, hiddenModelKeys: next }); await window.pichat.saveRuntime({ hiddenModelKeys: next }); }} onSettings={() => setShowSettings(true)} onNewSession={async () => { await window.pichat.newSession(); setMessages([]); notify('New session', 'success'); }} onCompact={async () => window.pichat.compact()} onReconnect={() => reconnect()} />
      <main className="chat-pane">
        <ChatHeader sessionName={sessionName} sessionFile={sessionFile} workingDirectory={settings.startupDirectory} queues={[steeringQueue.length, followUpQueue.length]} isStreaming={isStreaming} onAbort={abort} onChooseFolder={async () => { const folder = await window.pichat.chooseFolder(); if (folder) { setSettings({ ...settings, startupDirectory: folder }); await reconnect({ startupDirectory: folder }); } }} />
        <div className="messages-scroll">
          <div className="messages-inner">{messages.length === 0 && !isWaiting ? <Welcome currentModel={currentModel} onSuggestion={setInputText} /> : messages.map(m => <MessageView key={m.id} message={m} />)}{isRetrying && <Banner tone="warn">{retryMessage || 'Retrying…'}</Banner>}{isCompacting && <Banner tone="warn">Compacting context…</Banner>}<div ref={bottomRef} /></div>
        </div>
        <InputArea inputText={inputText} setInputText={setInputText} attachedFiles={attachedFiles} pastedContents={pastedContents} setAttachedFiles={setAttachedFiles} setPastedContents={setPastedContents} isBusy={isStreaming || isWaiting} onSend={isStreaming || isWaiting ? abort : sendMessage} onChooseFiles={chooseFiles} onReadAttachments={async paths => addAttachments(await window.pichat.readAttachments(paths))} />
      </main>
      {showRightPanel ? <RightPanel activeTools={activeTools} messages={messages} isStreaming={isStreaming} isCompacting={isCompacting} isRetrying={isRetrying} retryMessage={retryMessage} steeringQueue={steeringQueue} followUpQueue={followUpQueue} onClose={() => setShowRightPanel(false)} /> : <button className="open-right" onClick={() => setShowRightPanel(true)}>☰</button>}
    </> : <LoadingView error={connectionError} retry={() => boot()} />}
    {notification && <Toast notification={notification} />}
    {pendingUIRequest && <ExtensionDialog request={pendingUIRequest} onClose={() => setPendingUIRequest(null)} notify={notify} />}
    {showSettings && <SettingsModal settings={settings} setSettings={setSettings} themeMode={themeMode} setThemeMode={setThemeMode} config={config} setConfig={setConfig} browser={browser} setBrowser={setBrowser} currentModel={currentModel} models={visibleModels} hiddenModels={hiddenModels} authEntries={config.authEntries} mcpServers={config.mcpServers} steeringMode={steeringMode} followUpMode={followUpMode} autoCompactionEnabled={autoCompactionEnabled} autoRetryEnabled={autoRetryEnabled} setSteeringMode={async m => { await window.pichat.setSteeringMode(m); setSteeringModeState(m); }} setFollowUpMode={async m => { await window.pichat.setFollowUpMode(m); setFollowUpModeState(m); }} setAutoCompaction={async v => { await window.pichat.setAutoCompaction(v); setAutoCompactionEnabled(v); }} setAutoRetry={async v => { await window.pichat.setAutoRetry(v); setAutoRetryEnabled(v); }} onClose={() => setShowSettings(false)} onReconnect={reconnect} onRefreshConfig={refreshConfig} notify={notify} onModel={async m => { await window.pichat.setModel(m.provider, m.id); setCurrentModel(m); }} />}
  </div>;
}

function LoadingView({ error, retry }: { error: string; retry: () => void }) { return <div className="loading"><div className="hero-logo"><img src={LOGO_LIGHT} /></div><h1>Starting pi agent</h1>{error ? <><pre className="error-box">{error}</pre><button onClick={retry}>Retry</button></> : <p className="mono shimmer">Initializing RPC connection…</p>}</div>; }

function Sidebar(props: any) {
  const groups = groupModels(props.models);
  const [expanded, setExpanded] = useState(false);
  return <aside className="sidebar"><div className="sidebar-header"><div><b>PiChat</b><span><i className="dot green" /> Connected</span></div></div><div className="sidebar-scroll">
    <Section title="Model" icon="◉"><button className="model-current" onClick={() => setExpanded(!expanded)}>{props.currentModel ? <><span>{props.currentModel.name}</span><small>{props.currentModel.provider}</small></> : 'No model'}<b>{expanded ? '⌃' : '⌄'}</b></button><div className="segmented">{['off','low','medium','high'].map(l => <button key={l} className={props.thinkingLevel === l ? 'active' : ''} onClick={() => props.onThinking(l)}>{l}</button>)}</div>{expanded && <div className="model-list">{groups.length ? groups.map(g => <div key={g.provider} className="provider-group"><div className="provider-title">● {g.provider} <span>{g.models.length}</span></div>{g.models.map((m: AgentModel) => <button key={modelKey(m)} className={modelKey(m) === modelKey(props.currentModel) ? 'model-row selected' : 'model-row'} onClick={() => { props.onModel(m); setExpanded(false); }}><span>{m.name}<small>{m.provider}</small></span>{modelKey(m) === modelKey(props.currentModel) ? '✓' : <em onClick={(e) => { e.stopPropagation(); props.onHideModel(m); }}>hide</em>}</button>)}</div>) : <p className="muted small">No connected models. Add an account in Settings.</p>}{props.hiddenModels.length > 0 && <details><summary>Hidden models ({props.hiddenModels.length})</summary>{props.hiddenModels.map((m: AgentModel) => <button className="model-row dim" key={modelKey(m)} onClick={() => props.onShowModel(m)}>{m.name}<em>show</em></button>)}</details>}</div>}</Section>
    <Section title="Session" icon="▦"><ContextBar {...props.stats} /><div className="stats"><Stat label="In" value={fmtK(props.stats.tokenInput)} /><Stat label="Out" value={fmtK(props.stats.tokenOutput)} /><Stat label="Cost" value={`$${props.stats.sessionCost.toFixed(3)}`} /></div></Section>
    <Section title="Skills & Commands" icon="⌘">{props.commands.slice(0, 7).map((c: AgentCommand) => <div className="command" key={c.name}><b>{c.name}</b><small>{c.source || 'command'}</small></div>)}{props.commands.length === 0 && <p className="muted small">No commands loaded</p>}</Section>
    <Section title="MCP" icon="◌">{props.config.mcpServers.map((s: MCPServerEntry) => <div className="command" key={s.id}><b>{s.name}</b><small>{s.description}</small></div>)}{props.config.mcpServers.length === 0 && <p className="muted small">No MCP servers</p>}</Section>
  </div><div className="sidebar-actions"><button onClick={props.onNewSession}>New</button><button onClick={props.onCompact}>Compact</button><button onClick={props.onReconnect}>Reconnect</button><button className="primary" onClick={props.onSettings}>Settings</button></div></aside>;
}
function Section({ title, icon, children }: any) { return <section className="side-section"><h3><span>{icon}</span>{title}</h3>{children}</section>; }
function Stat({ label, value }: any) { return <div className="stat"><b>{value}</b><span>{label}</span></div>; }
function ContextBar(s: SessionStats) { const color = s.contextPercent > 85 ? 'var(--red)' : s.contextPercent > 65 ? 'var(--yellow)' : 'var(--accent)'; return <div className="context"><div><span>Context</span><b style={{ color }}>{Math.round(s.contextPercent)}%</b></div><i><em style={{ width: `${Math.min(s.contextPercent,100)}%`, background: color }} /></i><small>{fmtK(s.contextTokens)} tokens / {fmtK(s.contextWindow)}</small></div>; }
function groupModels(models: AgentModel[]) { const map = new Map<string, AgentModel[]>(); models.forEach(m => map.set(m.provider, [...(map.get(m.provider) || []), m])); return [...map.entries()].sort().map(([provider, ms]) => ({ provider, models: ms.sort((a,b)=>a.name.localeCompare(b.name)) })); }

function ChatHeader({ sessionName, sessionFile, workingDirectory, queues, isStreaming, onAbort, onChooseFolder }: any) { return <header className="chat-header"><div><b>{sessionName || 'New Session'}</b>{sessionFile && <small>{basename(sessionFile)}</small>}</div><span />{queues[0] > 0 && <Badge>↺ {queues[0]}</Badge>}{queues[1] > 0 && <Badge>⏭ {queues[1]}</Badge>}<button className="folder" onClick={onChooseFolder}>📁 {basename(workingDirectory)}</button>{isStreaming && <button className="danger" onClick={onAbort}>■ Stop</button>}</header>; }
function Badge({ children }: any) { return <b className="badge">{children}</b>; }
function Welcome({ currentModel, onSuggestion }: any) { const suggestions = [['🔎','Explore codebase','Analyze the project structure'], ['🛠','Fix a bug','Debug and resolve issues'], ['✨','Create feature','Build something new'], ['📄','Review code','Check for improvements']]; return <div className="welcome"><img src={LOGO_TRANSPARENT} /><h1>PiChat</h1><p>Powered by {currentModel?.name || 'pi agent'}</p><div className="suggestions">{suggestions.map(s => <button key={s[1]} onClick={() => onSuggestion(s[2])}><span>{s[0]}</span><b>{s[1]}</b><small>{s[2]}</small></button>)}</div></div>; }

function MessageView({ message }: { message: ChatMessage }) {
  if (message.role === 'system') return <div className="system-msg">{message.text}</div>;
  if (message.role === 'user') return <div className="user-msg"><div>{message.attachments?.length ? <div className="chips">{message.attachments.map(a => <Chip key={a.id}>{a.name}</Chip>)}</div> : null}<p>{message.text}</p><small>{shortTime(message.timestamp)}</small></div></div>;
  return <div className="assistant-msg"><div className="avatar"><img src={LOGO_LIGHT} /></div><div className="assistant-body">{message.isStreaming && <Thinking text={message.thinkingText || ''} streaming />}{!message.isStreaming && message.thinkingText && <details className="thinking"><summary>Thinking</summary><pre>{message.thinkingText}</pre></details>}{message.toolCalls?.map(t => <ToolCard key={t.id} tool={t} />)}{message.text && <Markdown text={message.text} />}{!message.isStreaming && <small>{shortTime(message.timestamp)}</small>}</div></div>;
}
function Thinking({ text, streaming }: { text: string; streaming?: boolean }) { return <div className="thinking active"><span className="typing"><i/><i/><i/></span><b>{streaming ? 'Pi is thinking' : 'Thinking'}</b>{text && <pre>{text}</pre>}</div>; }
function ToolCard({ tool }: { tool: ToolCall }) { const [open, setOpen] = useState(false); return <div className={`tool-card ${tool.isError ? 'error' : ''}`}><button onClick={() => setOpen(!open)}><span>{tool.isRunning ? '↻' : tool.isError ? '✕' : '✓'}</span><b>{tool.name}</b><em>{open ? '⌃' : '⌄'}</em></button>{open && <pre>{tool.output || 'Running…'}</pre>}</div>; }
function Markdown({ text }: { text: string }) { return <div className="markdown">{text.split(/(```[\s\S]*?```)/g).map((part, i) => part.startsWith('```') ? <pre key={i}><code>{part.replace(/^```\w*\n?|```$/g, '')}</code></pre> : part.split('\n').map((line, j) => line.startsWith('#') ? <h4 key={`${i}-${j}`}>{line.replace(/^#+\s*/, '')}</h4> : line.trim() ? <p key={`${i}-${j}`}>{line}</p> : <br key={`${i}-${j}`} />))}</div>; }
function Chip({ children, onRemove }: any) { return <span className="chip">{children}{onRemove && <button onClick={onRemove}>×</button>}</span>; }
function Banner({ children, tone }: any) { return <div className={`banner ${tone}`}>{children}</div>; }

function InputArea(p: any) { const textarea = useRef<HTMLTextAreaElement>(null); const addPasted = (text: string) => p.setPastedContents((prev: PastedContent[]) => [...prev, { id: id(), content: text.trim(), timestamp: now() }]); return <footer className="input-area"><div className="preview-strip">{p.pastedContents.map((pc: PastedContent) => <div className="paste-card" key={pc.id}><pre>{pc.content.slice(0,260)}</pre><b>PASTED · {wordCount(pc.content)} words</b><button onClick={() => p.setPastedContents((xs: PastedContent[]) => xs.filter(x => x.id !== pc.id))}>×</button></div>)}{p.attachedFiles.map((a: FileAttachment) => <Chip key={a.id} onRemove={() => p.setAttachedFiles((xs: FileAttachment[]) => xs.filter(x => x.id !== a.id))}>{a.name}</Chip>)}</div><div className="composer" onDrop={async e => { e.preventDefault(); const paths = Array.from(e.dataTransfer.files).map((f: any) => f.path).filter(Boolean); if (paths.length) p.onReadAttachments(paths); }}><button onClick={p.onChooseFiles}>＋</button><textarea ref={textarea} value={p.inputText} placeholder="Message pi agent…  (Ctrl+Enter to send)" onPaste={e => { const files = Array.from(e.clipboardData.files); if (files.length) { p.onReadAttachments(files.map((f: any) => f.path).filter(Boolean)); return; } const text = e.clipboardData.getData('text'); if (text.length >= 200) { e.preventDefault(); addPasted(text); } }} onKeyDown={e => { if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); p.onSend(); } }} onChange={e => p.setInputText(e.target.value)} /><button className="send" onClick={p.onSend}>{p.isBusy ? '■' : '➤'}</button></div></footer>; }

function RightPanel({ activeTools, messages, isStreaming, isCompacting, isRetrying, retryMessage, steeringQueue, followUpQueue, onClose }: any) { const [tab, setTab] = useState<'activity'|'queue'>('activity'); const recent = messages.flatMap((m: ChatMessage)=>m.toolCalls||[]).filter((t: ToolCall)=>!t.isRunning).slice(-8); return <aside className="right-panel"><div className="tabs"><button className={tab==='activity'?'active':''} onClick={()=>setTab('activity')}>⚡ Activity</button><button className={tab==='queue'?'active':''} onClick={()=>setTab('queue')}>☷ Queue</button><button onClick={onClose}>×</button></div>{tab==='activity' ? <div className="right-content"><p className="statusline"><i className={`dot ${isStreaming||isCompacting?'pulse':'green'}`} /> {isStreaming ? 'Agent Running' : isCompacting ? 'Compacting' : 'Idle'}</p>{isRetrying && <Banner tone="warn">{retryMessage}</Banner>}{activeTools.length>0 && <><h3>Running</h3>{activeTools.map((t: ToolCall)=><ToolRow key={t.id} tool={t}/>)}</>}{recent.length>0 && <><h3>Recent</h3>{recent.map((t: ToolCall)=><ToolRow key={t.id} tool={t}/>)}</>}{activeTools.length===0&&recent.length===0&&<p className="empty">No activity yet</p>}</div> : <div className="right-content"><Queue title="Steering" items={steeringQueue}/><Queue title="Follow-up" items={followUpQueue}/>{steeringQueue.length===0&&followUpQueue.length===0&&<p className="empty">Queue is empty</p>}</div>}</aside>; }
function ToolRow({ tool }: { tool: ToolCall }) { return <div className="tool-row"><b>{tool.isRunning?'↻':tool.isError?'✕':'✓'}</b><span>{tool.name}<small>{tool.output?.slice(0,60)}</small></span></div>; }
function Queue({ title, items }: { title: string; items: string[] }) { return items.length ? <section><h3>{title} <Badge>{items.length}</Badge></h3>{items.map((x,i)=><div className="queue-item" key={i}><b>{i+1}</b><span>{x}</span></div>)}</section> : null; }

function Toast({ notification }: { notification: AppNotification }) { return <div className={`toast ${notification.type}`}>{notification.type === 'success' ? '✓' : notification.type === 'error' ? '✕' : notification.type === 'warning' ? '⚠' : 'i'} {notification.message}</div>; }

function ExtensionDialog({ request, onClose }: { request: ExtensionUIRequest; onClose: () => void; notify: any }) { const [value, setValue] = useState(request.prefill || request.options?.[0] || ''); const reply = (payload: any) => { window.pichat.extensionUIResponse({ id: request.id, ...payload }); onClose(); }; return <div className="modal-backdrop" onMouseDown={() => reply({ cancelled: true })}><div className="dialog" onMouseDown={e => e.stopPropagation()}><h2>{request.title || request.method}</h2>{request.message && <p>{request.message}</p>}{request.method==='select' && <select value={value} onChange={e=>setValue(e.target.value)}>{request.options?.map(o=><option key={o}>{o}</option>)}</select>}{request.method==='input' && <input value={value} placeholder={request.placeholder} onChange={e=>setValue(e.target.value)} autoFocus />}{request.method==='editor' && <textarea value={value} onChange={e=>setValue(e.target.value)} autoFocus />}{request.method==='confirm' ? <div className="dialog-actions"><button onClick={()=>reply({ confirmed:false })}>Cancel</button><button className="primary" onClick={()=>reply({ confirmed:true })}>Confirm</button></div> : <div className="dialog-actions"><button onClick={()=>reply({ cancelled:true })}>Cancel</button><button className="primary" onClick={()=>reply({ value })}>OK</button></div>}</div></div>; }

function SettingsModal(props: any) { const [section, setSection] = useState<SettingsSection>('general'); const [localSettings, setLocalSettings] = useState<RuntimeSettings>(props.settings); const [json, setJson] = useState(props.config); const [provider, setProvider] = useState('anthropic'); const [key, setKey] = useState(''); const [customProvider, setCustomProvider] = useState(''); const [profileName, setProfileName] = useState(''); const [profileKey, setProfileKey] = useState(''); const [customModel, setCustomModel] = useState({ providerId:'', baseUrl:'', api:'openai-completions', apiKey:'', modelId:'', modelName:'', reasoning:false, supportsImages:false }); const [oauthStatus, setOauthStatus] = useState(''); const [oauthPrompt, setOauthPrompt] = useState(''); const [oauthPlaceholder, setOauthPlaceholder] = useState(''); const [oauthAllowEmpty, setOauthAllowEmpty] = useState(false); const [oauthInput, setOauthInput] = useState(''); const [oauthCode, setOauthCode] = useState(''); const [oauthUrl, setOauthUrl] = useState(''); const [oauthInstructions, setOauthInstructions] = useState(''); useEffect(()=>window.pichat.onOAuthEvent((e:any)=>{ if(e.type==='auth'){ const code = extractOAuthCode(e.instructions || ''); setOauthUrl(e.url || ''); setOauthInstructions(e.instructions || ''); setOauthCode(code); setOauthStatus(code ? `Browser opened. Enter code ${code}.` : (e.instructions || 'Browser opened. Complete authentication.')); } if(e.type==='progress') setOauthStatus(e.message); if(e.type==='prompt'||e.type==='manual'){setOauthPrompt(e.message); setOauthPlaceholder(e.placeholder || ''); setOauthAllowEmpty(Boolean(e.allowEmpty)); setOauthStatus(e.message);} if(e.type==='done'){ setOauthStatus('Authentication completed'); setOauthCode(''); setOauthUrl(''); setOauthInstructions(''); } if(e.type==='error') setOauthStatus(e.message); }), []); const saveRuntime = async () => { props.setSettings(await window.pichat.saveRuntime(localSettings)); props.notify('Runtime settings saved','success'); }; const saveRaw = async (name: string, content: string) => { const next = await window.pichat.saveRawConfig(name, content); setJson(next); props.setConfig(next); props.notify(`${name} saved`, 'success'); }; const loginProviders = ['anthropic','github-copilot','openai-codex','google-antigravity','google-gemini-cli']; return <div className="modal-backdrop"><div className="settings"><header><div><h2>PiChat Settings</h2><p>Structured for fast setup and easy daily use</p></div><button onClick={props.onClose}>×</button></header><div className="settings-body"><nav>{(['general','accounts','project','browser','advanced'] as SettingsSection[]).map(s=><button key={s} className={section===s?'active':''} onClick={()=>setSection(s)}>{s}</button>)}</nav><main>{section==='general'&&<><Card title="Appearance"><label>Theme<select value={props.themeMode} onChange={e=>props.setThemeMode(e.target.value)}><option>system</option><option>light</option><option>dark</option></select></label></Card><Card title="Pi Runtime"><Input label="Pi executable" value={localSettings.piPath} onChange={v=>setLocalSettings({...localSettings,piPath:v})}/><Input label="Startup project directory" value={localSettings.startupDirectory} onChange={v=>setLocalSettings({...localSettings,startupDirectory:v})}/><Input label="Pi config directory" value={localSettings.piConfigDirectory} onChange={v=>setLocalSettings({...localSettings,piConfigDirectory:v})}/><button onClick={saveRuntime}>Save</button><button className="primary" onClick={()=>props.onReconnect(localSettings)}>Reconnect</button></Card><Card title="Current Model"><select value={modelKey(props.currentModel)} onChange={e=>{const m=props.models.find((x:AgentModel)=>modelKey(x)===e.target.value); if(m) props.onModel(m);}}>{props.models.map((m:AgentModel)=><option value={modelKey(m)} key={modelKey(m)}>{m.name} · {m.provider}</option>)}</select></Card></>}{section==='accounts'&&<><Card title="Subscription Authentication"><p className="muted">Runs Pi-native OAuth login and writes auth.json.</p>{oauthStatus&&<p className="status-card">{oauthStatus}</p>}{(oauthCode||oauthInstructions)&&<div className="oauth-code-card"><small>Verification step</small>{oauthCode&&<><b>{oauthCode}</b><button onClick={()=>{navigator.clipboard?.writeText(oauthCode); props.notify('Verification code copied','success');}}>Copy code</button></>}{oauthInstructions&&<p>{oauthInstructions}</p>}{oauthUrl&&<button onClick={()=>window.pichat.openExternal(oauthUrl)}>Open again</button>}</div>}{oauthPrompt&&<p><input placeholder={oauthPlaceholder || "Paste code or redirect URL"} value={oauthInput} onChange={e=>setOauthInput(e.target.value)}/>{oauthAllowEmpty&&<small className="muted">Leave empty and press Continue for default.</small>}<button onClick={()=>{window.pichat.submitOAuthInput(oauthInput);setOauthInput('');}}>{oauthAllowEmpty?'Continue':'Submit'}</button></p>}{loginProviders.map(p=><p className="row" key={p}><b>{p}</b><button onClick={async()=>{setOauthStatus(`Starting ${p}…`); setOauthCode(''); setOauthInstructions(''); setOauthUrl(''); await window.pichat.startOAuth(p).catch((e:any)=>setOauthStatus(e.message)); props.onRefreshConfig();}}>Authenticate</button></p>)}</Card><Card title="Account Profiles"><p className="muted">Add several OpenAI/ChatGPT, Gemini, Anthropic or custom API-key accounts. PiChat can launch with the active profile and use enabled profiles for fallback.</p><label><input type="checkbox" checked={localSettings.autoAccountFailoverEnabled} onChange={e=>setLocalSettings({...localSettings,autoAccountFailoverEnabled:e.target.checked})}/> Auto-switch on quota / 429 errors</label><p><select value={localSettings.activeAccountProfileId} onChange={async e=>{const nextSettings=await window.pichat.saveRuntime({activeAccountProfileId:e.target.value}); setLocalSettings(nextSettings); props.setSettings(nextSettings);}}><option value="">Use native auth / CLI flags</option>{json.accountProfiles.map((p:any)=><option value={p.id} key={p.id}>{p.name} · {p.provider}</option>)}</select><button onClick={saveRuntime}>Save behavior</button></p><p><input placeholder="Profile name (Work, Personal, Backup…)" value={profileName} onChange={e=>setProfileName(e.target.value)}/><select value={provider} onChange={e=>setProvider(e.target.value)}>{['anthropic','openai','google','azure-openai-responses','mistral','groq','cerebras','xai','openrouter','github-copilot'].map(p=><option key={p}>{p}</option>)}</select><input placeholder="or custom provider id" value={customProvider} onChange={e=>setCustomProvider(e.target.value)}/><input type="password" placeholder="API key" value={profileKey} onChange={e=>setProfileKey(e.target.value)}/><button className="primary" onClick={async()=>{const next=await window.pichat.upsertAccountProfile({name:profileName, provider:customProvider||provider, apiKey:profileKey}); props.setConfig(next); setJson(next); setProfileName(''); setProfileKey(''); props.notify('Account profile added','success');}}>Add profile</button></p>{json.accountProfiles.length===0?<p className="muted small">No account profiles yet</p>:json.accountProfiles.map((a:any)=><p className="row" key={a.id}><span><b>{a.name}</b><small>{a.provider}: {a.keyPreview}</small></span><span><button onClick={async()=>{const r=await window.pichat.setAccountProfileEnabled(a.id,!a.isEnabled); props.setConfig(r.config); setJson(r.config); props.setSettings(r.settings);}}>{a.isEnabled?'Enabled':'Disabled'}</button><button onClick={async()=>{const nextSettings=await window.pichat.saveRuntime({activeAccountProfileId:a.id}); setLocalSettings(nextSettings); props.setSettings(nextSettings);}}>Use</button><button onClick={async()=>{const r=await window.pichat.removeAccountProfile(a.id); props.setConfig(r.config); setJson(r.config); props.setSettings(r.settings);}}>Delete</button></span></p>)}</Card><Card title="Accounts (auth.json)"><p><select value={provider} onChange={e=>setProvider(e.target.value)}>{['anthropic','openai','google','azure-openai-responses','mistral','groq','cerebras','xai','openrouter','github-copilot'].map(p=><option key={p}>{p}</option>)}</select><input placeholder="or custom provider id" value={customProvider} onChange={e=>setCustomProvider(e.target.value)}/><input type="password" placeholder="API key / env var / !command" value={key} onChange={e=>setKey(e.target.value)}/><button onClick={async()=>{const next=await window.pichat.upsertApiKey(customProvider||provider,key); props.setConfig(next); setJson(next); setKey('');}}>Save</button></p>{props.authEntries.map((a:any)=><p className="row" key={a.id}><span><b>{a.provider}</b><small>{a.type}: {a.keyPreview}</small></span><button onClick={async()=>{const next=await window.pichat.removeAuth(a.provider); props.setConfig(next); setJson(next);}}>Delete</button></p>)}</Card><Card title="Custom Provider / Model">{(['providerId','baseUrl','apiKey','modelId','modelName'] as const).map(k=><Input key={k} label={k} value={(customModel as any)[k]} onChange={v=>setCustomModel({...customModel,[k]:v})}/>) }<label>API<select value={customModel.api} onChange={e=>setCustomModel({...customModel,api:e.target.value})}><option>openai-completions</option><option>openai-responses</option><option>anthropic-messages</option><option>google-generative-ai</option></select></label><label><input type="checkbox" checked={customModel.reasoning} onChange={e=>setCustomModel({...customModel,reasoning:e.target.checked})}/> Reasoning</label><label><input type="checkbox" checked={customModel.supportsImages} onChange={e=>setCustomModel({...customModel,supportsImages:e.target.checked})}/> Supports images</label><button onClick={async()=>{const next=await window.pichat.addCustomModel(customModel); props.setConfig(next); setJson(next); props.notify('Model added','success');}}>Add model</button></Card></>}{section==='project'&&<Card title="Project & Session"><p className="row"><span>Current folder</span><code>{localSettings.startupDirectory}</code></p><button onClick={async()=>{const f=await window.pichat.chooseFolder(); if(f) setLocalSettings({...localSettings,startupDirectory:f});}}>Change folder</button><button onClick={()=>window.pichat.newSession()}>New session</button><button onClick={()=>window.pichat.compact()}>Compact</button></Card>}{section==='browser'&&<Card title="Browser Control"><p className="status-card"><b>Status:</b> {props.browser.statusText}<br/><b>Last seen:</b> {props.browser.lastSeenText}<br/><b>Tools:</b> {props.browser.toolsStatusText}</p><Input label="Browspi ID" value={localSettings.browserExtensionId} onChange={v=>setLocalSettings({...localSettings,browserExtensionId:v})}/><button className="primary" onClick={async()=>{const r=await window.pichat.installBrowser(localSettings.browserExtensionId); props.setBrowser(r.status); props.setSettings(await window.pichat.saveRuntime({browserExtensionId:localSettings.browserExtensionId}));}}>Connect Browser</button><button onClick={async()=>props.setBrowser(await window.pichat.disconnectBrowser())}>Disconnect</button><button onClick={()=>window.pichat.openExternal('chrome://extensions/')}>Open Chrome Extensions</button><p className="muted">Manifest: {props.browser.manifestPath}</p><p className="muted">Origin: {props.browser.allowedOrigin}</p></Card>}{section==='advanced'&&<><Card title="RPC Behavior"><label>Steering<select value={props.steeringMode} onChange={e=>props.setSteeringMode(e.target.value)}><option>one-at-a-time</option><option>all</option></select></label><label>Follow-up<select value={props.followUpMode} onChange={e=>props.setFollowUpMode(e.target.value)}><option>one-at-a-time</option><option>all</option></select></label><label><input type="checkbox" checked={props.autoCompactionEnabled} onChange={e=>props.setAutoCompaction(e.target.checked)}/> Auto compaction</label><label><input type="checkbox" checked={props.autoRetryEnabled} onChange={e=>props.setAutoRetry(e.target.checked)}/> Auto retry</label></Card><Card title="CLI Flags">{(['cliProvider','cliModel','cliApiKey','cliThinking','cliModels','cliSessionDir','cliSession','cliFork','cliTools','cliSystemPrompt','cliAppendSystemPrompt','cliExtraArgs'] as const).map(k=><Input key={k} label={k} value={(localSettings as any)[k]} onChange={v=>setLocalSettings({...localSettings,[k]:v})}/>) }{(['cliNoSession','cliNoTools','cliNoExtensions','cliNoSkills','cliNoPromptTemplates','cliNoThemes','cliNoContextFiles','cliVerbose'] as const).map(k=><label key={k}><input type="checkbox" checked={(localSettings as any)[k]} onChange={e=>setLocalSettings({...localSettings,[k]:e.target.checked})}/> {k}</label>)}<button onClick={saveRuntime}>Save flags</button></Card><Card title="Raw JSON editor">{(['settings.json','models.json','auth.json','mcp.json'] as const).map(name=>{ const key = name==='settings.json'?'settingsJSONText':name==='models.json'?'modelsJSONText':name==='auth.json'?'authJSONText':'mcpJSONText'; return <div key={name} className="json-editor"><h4>{name}</h4><textarea value={(json as any)[key]} onChange={e=>setJson({...json,[key]:e.target.value})}/><button onClick={()=>saveRaw(name,(json as any)[key])}>Save {name}</button></div>; })}</Card></>}</main></div></div></div>; }
function Card({ title, children }: any) { return <section className="settings-card"><h3>{title}</h3>{children}</section>; }
function Input({ label, value, onChange }: any) { return <label>{label}<input value={value || ''} onChange={e=>onChange(e.target.value)} /></label>; }
