export type ChatRole = 'user' | 'assistant' | 'system' | 'tool';

export interface ToolCall {
  id: string;
  name: string;
  args?: string;
  output: string;
  isError: boolean;
  isRunning: boolean;
  isExpanded?: boolean;
}

export interface FileAttachment {
  id: string;
  path: string;
  name: string;
  mimeType: string;
  base64Data?: string;
}

export interface PastedContent {
  id: string;
  content: string;
  timestamp: number;
}

export interface ChatMessage {
  id: string;
  role: ChatRole;
  text: string;
  isStreaming?: boolean;
  thinkingText?: string;
  showThinking?: boolean;
  toolCalls?: ToolCall[];
  timestamp: number;
  attachments?: FileAttachment[];
}

export interface AgentModel {
  id: string;
  name: string;
  provider: string;
  api?: string | null;
  contextWindow?: number | null;
  maxTokens?: number | null;
  reasoning?: boolean | null;
  cost?: Record<string, number | null> | null;
}

export interface AgentCommand {
  name: string;
  description?: string | null;
  source?: string | null;
  path?: string | null;
}

export interface PiAuthEntry {
  id: string;
  provider: string;
  type: string;
  keyPreview: string;
}

export interface PiAccountProfile {
  id: string;
  name: string;
  provider: string;
  keyPreview: string;
  isEnabled: boolean;
}

export interface MCPServerEntry {
  id: string;
  name: string;
  description: string;
}

export interface RuntimeSettings {
  piPath: string;
  startupDirectory: string;
  piConfigDirectory: string;
  hiddenModelKeys: string[];
  browserExtensionId: string;
  activeAccountProfileId: string;
  autoAccountFailoverEnabled: boolean;
  cliNoSession: boolean;
  cliProvider: string;
  cliModel: string;
  cliApiKey: string;
  cliThinking: string;
  cliModels: string;
  cliSessionDir: string;
  cliSession: string;
  cliFork: string;
  cliTools: string;
  cliNoTools: boolean;
  cliNoExtensions: boolean;
  cliNoSkills: boolean;
  cliNoPromptTemplates: boolean;
  cliNoThemes: boolean;
  cliNoContextFiles: boolean;
  cliVerbose: boolean;
  cliSystemPrompt: string;
  cliAppendSystemPrompt: string;
  cliExtraArgs: string;
}

export interface ConfigState {
  settingsJSONText: string;
  modelsJSONText: string;
  authJSONText: string;
  mcpJSONText: string;
  authEntries: PiAuthEntry[];
  accountProfiles: PiAccountProfile[];
  mcpServers: MCPServerEntry[];
}

export interface SessionStats {
  tokenInput: number;
  tokenOutput: number;
  tokenTotal: number;
  sessionCost: number;
  contextPercent: number;
  contextTokens: number;
  contextWindow: number;
}

export interface RpcState {
  model?: AgentModel | null;
  thinkingLevel?: string | null;
  isStreaming?: boolean | null;
  isCompacting?: boolean | null;
  sessionFile?: string | null;
  sessionId?: string | null;
  sessionName?: string | null;
  autoCompactionEnabled?: boolean | null;
  steeringMode?: string | null;
  followUpMode?: string | null;
}

export interface BrowserStatus {
  statusText: string;
  manifestPath: string;
  allowedOrigin: string;
  lastSeenText: string;
  pairingStatusText: string;
  toolsStatusText: string;
}

export type NotificationType = 'info' | 'warning' | 'error' | 'success';

export interface AppNotification {
  id: string;
  message: string;
  type: NotificationType;
}

export interface ExtensionUIRequest {
  id: string;
  method: 'confirm' | 'select' | 'input' | 'editor' | 'notify' | string;
  title?: string;
  message?: string;
  options?: string[];
  placeholder?: string;
  notifyType?: string;
  prefill?: string;
}

export type PiEvent =
  | { type: 'agent_start' }
  | { type: 'agent_end' }
  | { type: 'message_update'; deltaType: string; delta?: string; contentIndex?: number }
  | { type: 'tool_execution_start'; toolCallId: string; toolName: string; args?: unknown }
  | { type: 'tool_execution_update'; toolCallId: string; toolName: string; partialText: string }
  | { type: 'tool_execution_end'; toolCallId: string; toolName: string; resultText: string; isError: boolean }
  | { type: 'queue_update'; steering: string[]; followUp: string[] }
  | { type: 'compaction_start'; reason: string }
  | { type: 'compaction_end'; reason: string; summary?: string }
  | { type: 'auto_retry_start'; attempt: number; maxAttempts: number; delayMs: number; errorMessage: string }
  | { type: 'auto_retry_end'; success: boolean; attempt: number; finalError?: string }
  | { type: 'extension_error'; extensionPath: string; event: string; error: string }
  | { type: 'extension_ui_request'; request: ExtensionUIRequest }
  | { type: 'process_stderr'; message: string }
  | { type: 'response'; command?: string; success: boolean; error?: string; data?: any };
