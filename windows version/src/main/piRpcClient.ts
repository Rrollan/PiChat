import { EventEmitter } from 'node:events';
import { spawn, ChildProcessWithoutNullStreams, execFileSync } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';
import type { AgentModel, AgentCommand, PiEvent, RpcState } from '../shared/types';
import { bundledPiCliPath, expandHome } from './config';

interface PendingResponse {
  resolve: (value: any) => void;
  reject: (reason: Error) => void;
  timer: NodeJS.Timeout;
  commandType: string;
}

interface ResolvedPiCommand {
  executable: string;
  prefixArgs: string[];
  bundled: boolean;
}

export interface RPCResponseData extends RpcState {
  models?: AgentModel[];
  commands?: AgentCommand[];
  tokens?: { input?: number; output?: number; total?: number; cacheRead?: number; cacheWrite?: number };
  cost?: number;
  contextUsage?: { tokens?: number; contextWindow?: number; percent?: number };
  summary?: string;
}

export class PiRPCClient extends EventEmitter {
  private proc?: ChildProcessWithoutNullStreams;
  private pending = new Map<string, PendingResponse>();
  private stdoutBuffer = '';
  private requestCounter = 0;
  private shuttingDown = false;
  isRunning = false;
  isStreaming = false;
  piPath = 'pi';
  workingDirectory = os.homedir();
  launchArguments: string[] = ['--no-session'];
  enableDebugLogging = false;
  requestTimeoutMs = 90_000;

  async start(): Promise<void> {
    if (this.isRunning) return;
    this.shuttingDown = false;

    const command = this.resolvePiCommand(expandHome(this.piPath || 'pi'));
    const args = [...command.prefixArgs, '--mode', 'rpc', ...this.launchArguments];
    const executable = command.executable;
    const cwd = expandHome(this.workingDirectory || os.homedir());
    if (!fs.existsSync(cwd) || !fs.statSync(cwd).isDirectory()) {
      throw new Error(`Working directory does not exist or is not a folder: ${cwd}`);
    }

    const env = this.buildEnv(command.bundled);
    const needsShell = !command.bundled && process.platform === 'win32' && /\.(cmd|bat)$/i.test(executable);
    this.debug(`[PI START] ${executable} ${args.join(' ')}`);

    await new Promise<void>((resolve, reject) => {
      let settled = false;
      const settleResolve = () => { if (!settled) { settled = true; resolve(); } };
      const settleReject = (error: Error) => { if (!settled) { settled = true; reject(error); } };

      try {
        const child = spawn(executable, args, { cwd, env, shell: needsShell, windowsHide: true });
        this.proc = child;
        child.stdout.setEncoding('utf8');
        child.stderr.setEncoding('utf8');

        child.stdout.on('data', (chunk: string) => this.handleStdout(chunk));
        child.stderr.on('data', (chunk: string) => this.handleStderr(chunk));
        child.on('error', (error) => {
          this.cleanupProcess(error instanceof Error ? error : new Error(String(error)));
          this.emitEvent({ type: 'process_stderr', message: error.message });
          settleReject(error instanceof Error ? error : new Error(String(error)));
        });
        child.on('close', (code, signal) => {
          if (!this.shuttingDown) {
            this.cleanupProcess(new Error(`pi process exited (${code ?? signal ?? 'unknown'})`));
          } else {
            this.cleanupProcess(new Error('pi stopped'));
          }
        });

        this.isRunning = true;
        setImmediate(settleResolve);
      } catch (error: any) {
        this.cleanupProcess(error instanceof Error ? error : new Error(String(error)));
        settleReject(error instanceof Error ? error : new Error(String(error)));
      }
    });
  }

  stop(): void {
    this.shuttingDown = true;
    const proc = this.proc;
    if (proc?.pid && process.platform === 'win32') {
      try { execFileSync('taskkill.exe', ['/pid', String(proc.pid), '/t', '/f'], { windowsHide: true, stdio: 'ignore' }); }
      catch { try { proc.kill(); } catch { /* ignore */ } }
    } else {
      try { proc?.kill('SIGTERM'); } catch { /* ignore */ }
    }
    this.cleanupProcess(new Error('pi stopped'));
  }

  private cleanupProcess(error: Error): void {
    this.proc?.removeAllListeners();
    this.proc = undefined;
    this.stdoutBuffer = '';
    this.isRunning = false;
    this.isStreaming = false;
    this.rejectAll(error);
  }

  private resolvePiCommand(input: string): ResolvedPiCommand {
    const normalized = expandHome(input.trim() || 'pi');
    const looksLikePath = path.isAbsolute(normalized) || normalized.includes('/') || normalized.includes('\\');

    if (!looksLikePath && normalized.toLowerCase() === 'pi') {
      const bundledCli = bundledPiCliPath();
      if (bundledCli) {
        return { executable: process.execPath, prefixArgs: [bundledCli], bundled: true };
      }
    }

    return { executable: this.resolveExecutable(normalized), prefixArgs: [], bundled: false };
  }

  private resolveExecutable(input: string): string {
    const normalized = expandHome(input.trim() || 'pi');
    const looksLikePath = path.isAbsolute(normalized) || normalized.includes('/') || normalized.includes('\\');
    if (looksLikePath) return normalized;

    const env = this.buildEnv(false);
    try {
      if (process.platform === 'win32') {
        const result = execFileSync('where.exe', [normalized], { env, encoding: 'utf8', windowsHide: true }).split(/\r?\n/).map(x => x.trim()).filter(Boolean)[0];
        return result || normalized;
      }
      const result = execFileSync('/bin/sh', ['-lc', `command -v ${JSON.stringify(normalized)}`], { env, encoding: 'utf8' }).trim();
      return result || normalized;
    } catch {
      return normalized;
    }
  }

  private buildEnv(useBundledPi = false): NodeJS.ProcessEnv {
    const env = { ...process.env };
    const home = os.homedir();
    const preferred = process.platform === 'win32'
      ? [
          path.join(process.env.APPDATA || path.join(home, 'AppData', 'Roaming'), 'npm'),
          path.join(home, 'AppData', 'Local', 'Programs', 'nodejs'),
          'C:\\Program Files\\nodejs',
          'C:\\Program Files (x86)\\nodejs'
        ]
      : ['/opt/homebrew/bin', '/usr/local/bin', path.join(home, '.npm-global', 'bin'), path.join(home, '.local', 'bin'), '/usr/bin', '/bin', '/usr/sbin', '/sbin'];
    const sep = path.delimiter;
    const current = (env.PATH || '').split(sep);
    env.PATH = [...new Set([...preferred, ...current].filter(Boolean))].join(sep);
    if (useBundledPi) {
      env.ELECTRON_RUN_AS_NODE = '1';
      env.PICHAT_BUNDLED_PI = '1';
    }
    return env;
  }

  private handleStdout(chunk: string): void {
    this.stdoutBuffer += chunk;
    let idx = this.stdoutBuffer.indexOf('\n');
    while (idx >= 0) {
      let line = this.stdoutBuffer.slice(0, idx);
      this.stdoutBuffer = this.stdoutBuffer.slice(idx + 1);
      if (line.endsWith('\r')) line = line.slice(0, -1);
      if (line.trim()) this.handleLine(line);
      idx = this.stdoutBuffer.indexOf('\n');
    }
  }

  private handleStderr(chunk: string): void {
    for (const raw of String(chunk).split(/\r?\n/)) {
      const line = raw.trim();
      if (!line) continue;
      this.debug(`[PI STDERR] ${line}`);
      this.emitEvent({ type: 'process_stderr', message: line });
    }
  }

  private handleLine(line: string): void {
    this.debug(`[RPC RX] ${line}`);
    let json: any;
    try { json = JSON.parse(line); } catch { return; }
    const eventType = json.type || '';
    switch (eventType) {
      case 'response': {
        const id = json.id as string | undefined;
        const command = json.command as string | undefined;
        const success = Boolean(json.success);
        const error = json.error as string | undefined;
        if (id && this.pending.has(id)) {
          const pending = this.pending.get(id)!;
          this.pending.delete(id);
          clearTimeout(pending.timer);
          if (success) pending.resolve(json.data ?? null);
          else pending.reject(new Error(error || 'Unknown RPC error'));
        }
        this.emitEvent({ type: 'response', command, success, error, data: json.data });
        break;
      }
      case 'agent_start': this.isStreaming = true; this.emitEvent({ type: 'agent_start' }); break;
      case 'agent_end': this.isStreaming = false; this.emitEvent({ type: 'agent_end' }); break;
      case 'message_update': {
        const evt = json.assistantMessageEvent || {};
        this.emitEvent({ type: 'message_update', deltaType: evt.type || '', delta: evt.delta, contentIndex: evt.contentIndex });
        break;
      }
      case 'tool_execution_start': this.emitEvent({ type: 'tool_execution_start', toolCallId: json.toolCallId || '', toolName: json.toolName || '', args: json.args }); break;
      case 'tool_execution_update': this.emitEvent({ type: 'tool_execution_update', toolCallId: json.toolCallId || '', toolName: json.toolName || '', partialText: this.extractToolText(json.partialResult) }); break;
      case 'tool_execution_end': this.emitEvent({ type: 'tool_execution_end', toolCallId: json.toolCallId || '', toolName: json.toolName || '', resultText: this.extractToolText(json.result), isError: Boolean(json.isError) }); break;
      case 'queue_update': this.emitEvent({ type: 'queue_update', steering: json.steering || [], followUp: json.followUp || [] }); break;
      case 'compaction_start': this.emitEvent({ type: 'compaction_start', reason: json.reason || '' }); break;
      case 'compaction_end': this.emitEvent({ type: 'compaction_end', reason: json.reason || '', summary: json.result?.summary }); break;
      case 'auto_retry_start': this.emitEvent({ type: 'auto_retry_start', attempt: json.attempt || 0, maxAttempts: json.maxAttempts || 0, delayMs: json.delayMs || 0, errorMessage: json.errorMessage || '' }); break;
      case 'auto_retry_end': this.emitEvent({ type: 'auto_retry_end', success: Boolean(json.success), attempt: json.attempt || 0, finalError: json.finalError }); break;
      case 'extension_error': this.emitEvent({ type: 'extension_error', extensionPath: json.extensionPath || '', event: json.event || '', error: json.error || '' }); break;
      case 'extension_ui_request': this.emitEvent({ type: 'extension_ui_request', request: { id: json.id || '', method: json.method || '', title: json.title, message: json.message, options: json.options, placeholder: json.placeholder, notifyType: json.notifyType, prefill: json.prefill } }); break;
    }
  }

  private extractToolText(value: any): string {
    const first = value?.content?.[0];
    if (typeof first?.text === 'string') return first.text;
    if (typeof value === 'string') return value;
    if (value == null) return '';
    try { return JSON.stringify(value, null, 2); } catch { return String(value); }
  }

  private emitEvent(event: PiEvent): void { this.emit('event', event); }
  private debug(message: string): void { if (this.enableDebugLogging) console.log(message); }
  private rejectAll(error: Error): void {
    for (const pending of this.pending.values()) {
      clearTimeout(pending.timer);
      pending.reject(error);
    }
    this.pending.clear();
  }
  private nextId(): string { return `req-${++this.requestCounter}`; }

  sendCommand(command: Record<string, unknown>, wait = true): Promise<RPCResponseData | null> {
    if (!this.isRunning || !this.proc) return Promise.reject(new Error('pi is not running'));
    const id = wait ? (command.id as string | undefined) || this.nextId() : undefined;
    const payload = { id, ...command };
    const line = JSON.stringify(payload) + '\n';
    this.debug(`[RPC TX] ${line.trim()}`);
    return new Promise((resolve, reject) => {
      if (id) {
        const commandType = String(command.type || 'unknown');
        const timer = setTimeout(() => {
          if (!this.pending.has(id)) return;
          this.pending.delete(id);
          const error = new Error(`RPC command timed out after ${Math.round(this.requestTimeoutMs / 1000)}s: ${commandType}`);
          this.emitEvent({ type: 'process_stderr', message: error.message });
          reject(error);
        }, this.requestTimeoutMs);
        this.pending.set(id, { resolve, reject, timer, commandType });
      }
      this.proc!.stdin.write(line, 'utf8', (error) => {
        if (!error) return;
        if (id) {
          const pending = this.pending.get(id);
          if (pending) clearTimeout(pending.timer);
          this.pending.delete(id);
        }
        reject(error);
      });
      if (!id) resolve(null);
    });
  }

  prompt(message: string, images: Array<{ type: 'image'; data: string; mimeType: string }> = []) { return this.sendCommand({ type: 'prompt', message, images: images.length ? images : undefined }); }
  abort() { return this.sendCommand({ type: 'abort' }); }
  getState() { return this.sendCommand({ type: 'get_state' }); }
  async getAvailableModels(): Promise<AgentModel[]> { return (await this.sendCommand({ type: 'get_available_models' }))?.models || []; }
  async getCommands(): Promise<AgentCommand[]> { return (await this.sendCommand({ type: 'get_commands' }))?.commands || []; }
  getSessionStats() { return this.sendCommand({ type: 'get_session_stats' }); }
  setModel(provider: string, modelId: string) { return this.sendCommand({ type: 'set_model', provider, modelId }); }
  setThinkingLevel(level: string) { return this.sendCommand({ type: 'set_thinking_level', level }); }
  setSteeringMode(mode: string) { return this.sendCommand({ type: 'set_steering_mode', mode }); }
  setFollowUpMode(mode: string) { return this.sendCommand({ type: 'set_follow_up_mode', mode }); }
  setAutoCompaction(enabled: boolean) { return this.sendCommand({ type: 'set_auto_compaction', enabled }); }
  setAutoRetry(enabled: boolean) { return this.sendCommand({ type: 'set_auto_retry', enabled }); }
  compact(customInstructions?: string) { return this.sendCommand({ type: 'compact', customInstructions }); }
  newSession() { return this.sendCommand({ type: 'new_session' }); }
  sendExtensionUIResponse(payload: Record<string, unknown>): Promise<null> { return this.sendCommand({ type: 'extension_ui_response', ...payload }, false) as Promise<null>; }
}
