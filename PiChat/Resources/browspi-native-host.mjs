#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import http from 'node:http';
import { spawn } from 'node:child_process';

const PI_BINARY = process.env.PI_BINARY || 'pi';
const DEFAULT_MODEL = process.env.PI_BRIDGE_MODEL || '';
const DEFAULT_PROVIDER = process.env.PI_BRIDGE_PROVIDER || '';
const REQUEST_TIMEOUT_MS = Number(process.env.BROWSPI_NATIVE_TIMEOUT_MS || 180000);
const MODEL_CACHE_TTL_MS = Number(process.env.BROWSPI_MODEL_CACHE_TTL_MS || 60000);
const HOST_DIR = process.env.BROWSPI_PAIRING_DIR || path.join(os.homedir(), 'Library/Application Support/PiChat/NativeHost');
const PAIRING_CONFIG_PATH = process.env.BROWSPI_PAIRING_CONFIG || path.join(HOST_DIR, 'pairing.json');
const BROWSER_TOOLS_EXTENSION_PATH = process.env.BROWSPI_BROWSER_TOOLS_EXTENSION || path.join(HOST_DIR, 'browser-tools/index.ts');
const BROWSER_TOOLS_ENABLED = process.env.BROWSPI_BROWSER_TOOLS_ENABLED !== '0';
const BROWSER_BROKER_HOST = process.env.BROWSPI_BROWSER_BROKER_HOST || '127.0.0.1';
const BROWSER_BROKER_PORT = Number(process.env.BROWSPI_BROWSER_BROKER_PORT || 8766);
const BROWSER_TOOL_TIMEOUT_MS = Number(process.env.BROWSPI_BROWSER_TOOL_TIMEOUT_MS || 120000);

let inputBuffer = Buffer.alloc(0);
let modelCache = { expiresAt: 0, payload: null };
const browserToolPending = new Map();

function log(...args) {
  console.error('[browspi-native-host]', ...args);
}

function writeFrame(payload) {
  const body = Buffer.from(JSON.stringify(payload), 'utf8');
  const header = Buffer.alloc(4);
  header.writeUInt32LE(body.length, 0);
  fs.writeSync(1, header);
  fs.writeSync(1, body);
}

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Access-Control-Allow-Origin': 'http://127.0.0.1',
    'Access-Control-Allow-Headers': 'content-type'
  });
  res.end(body);
}

async function readRequestJson(req) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 2 * 1024 * 1024) throw new Error('Request too large');
    chunks.push(chunk);
  }
  if (!chunks.length) return {};
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function callBrowserTool(action, params) {
  const id = `browser-tool-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      browserToolPending.delete(id);
      reject(new Error(`Browser tool timeout: ${action}`));
    }, BROWSER_TOOL_TIMEOUT_MS);
    browserToolPending.set(id, { resolve, reject, timer });
    writeFrame({ id, type: 'browser_tool_call', action, params: params || {} });
  });
}

function handleBrowserToolResult(frame) {
  const id = frame?.id;
  const pending = id ? browserToolPending.get(id) : null;
  if (!pending) return false;
  clearTimeout(pending.timer);
  browserToolPending.delete(id);
  if (frame.ok === false) pending.resolve(frame.json ?? { success: false, message: frame.error || 'Browser tool failed' });
  else pending.resolve(frame.json ?? frame);
  return true;
}

function startBrowserBroker() {
  const server = http.createServer(async (req, res) => {
    try {
      if (req.method === 'OPTIONS') {
        res.writeHead(204, {
          'Access-Control-Allow-Origin': 'http://127.0.0.1',
          'Access-Control-Allow-Headers': 'content-type',
          'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        });
        res.end();
        return;
      }
      const url = new URL(req.url || '/', `http://${BROWSER_BROKER_HOST}:${BROWSER_BROKER_PORT}`);
      if (req.method === 'GET' && url.pathname === '/health') {
        sendJson(res, 200, { ok: true, service: 'browspi-browser-broker', pending: browserToolPending.size });
        return;
      }
      if (req.method === 'POST' && url.pathname === '/browser-tools/call') {
        const body = await readRequestJson(req);
        const action = String(body.action || '');
        if (!action.startsWith('browser.')) {
          sendJson(res, 400, { success: false, message: 'Invalid browser tool action' });
          return;
        }
        const result = await callBrowserTool(action, body.params || {});
        sendJson(res, result?.success === false ? 400 : 200, result);
        return;
      }
      sendJson(res, 404, { success: false, message: `No broker route for ${req.method} ${url.pathname}` });
    } catch (error) {
      sendJson(res, 500, { success: false, message: error?.message || String(error) });
    }
  });

  server.on('error', error => {
    if (error.code === 'EADDRINUSE') log(`browser broker already running on ${BROWSER_BROKER_HOST}:${BROWSER_BROKER_PORT}`);
    else log('browser broker error:', error.message || error);
  });
  server.listen(BROWSER_BROKER_PORT, BROWSER_BROKER_HOST, () => {
    log(`browser broker listening on http://${BROWSER_BROKER_HOST}:${BROWSER_BROKER_PORT}`);
  });
}

function readFrames() {
  const frames = [];
  while (inputBuffer.length >= 4) {
    const length = inputBuffer.readUInt32LE(0);
    if (length > 16 * 1024 * 1024) throw new Error(`Native message too large: ${length}`);
    if (inputBuffer.length < 4 + length) break;
    const raw = inputBuffer.subarray(4, 4 + length).toString('utf8');
    inputBuffer = inputBuffer.subarray(4 + length);
    frames.push(JSON.parse(raw));
  }
  return frames;
}

function sha256(value) {
  return crypto.createHash('sha256').update(String(value || ''), 'utf8').digest('hex');
}

function safeClient(raw) {
  const client = raw && typeof raw === 'object' ? raw : {};
  return {
    extensionId: String(client.extensionId || '').slice(0, 80),
    version: String(client.version || '').slice(0, 40),
    surface: String(client.surface || '').slice(0, 40)
  };
}

function readPairingConfig() {
  try {
    if (!fs.existsSync(PAIRING_CONFIG_PATH)) {
      return {
        pairingRequired: false,
        paired: true,
        tokenHash: '',
        lastSeenAt: null,
        lastPairedAt: null,
        client: null,
        devMode: true
      };
    }
    const parsed = JSON.parse(fs.readFileSync(PAIRING_CONFIG_PATH, 'utf8'));
    return {
      pairingRequired: parsed.pairingRequired !== false && !!parsed.tokenHash,
      paired: !!parsed.paired,
      tokenHash: typeof parsed.tokenHash === 'string' ? parsed.tokenHash : '',
      lastSeenAt: Number(parsed.lastSeenAt || 0) || null,
      lastPairedAt: Number(parsed.lastPairedAt || 0) || null,
      client: parsed.client && typeof parsed.client === 'object' ? safeClient(parsed.client) : null,
      updatedAt: Number(parsed.updatedAt || 0) || null,
      devMode: false
    };
  } catch (error) {
    log('pairing config read failed:', error.message || error);
    return { pairingRequired: true, paired: false, tokenHash: '', lastSeenAt: null, lastPairedAt: null, client: null, configError: true };
  }
}

function writePairingConfig(next) {
  try {
    fs.mkdirSync(path.dirname(PAIRING_CONFIG_PATH), { recursive: true });
    fs.writeFileSync(PAIRING_CONFIG_PATH, `${JSON.stringify({ ...next, updatedAt: Date.now() / 1000 }, null, 2)}\n`, { mode: 0o600 });
  } catch (error) {
    log('pairing config write failed:', error.message || error);
  }
}

function publicPairingStatus(config = readPairingConfig()) {
  return {
    pairingRequired: !!config.pairingRequired,
    paired: !config.pairingRequired || !!config.paired,
    pairingStatus: !config.pairingRequired ? 'not_required' : (config.paired ? 'paired' : 'pairing_required'),
    pairingTokenHash: config.tokenHash || undefined,
    lastSeenAt: config.lastSeenAt || null,
    lastPairedAt: config.lastPairedAt || null,
    client: config.client || null,
    devMode: !!config.devMode
  };
}

function markSeen(client) {
  const config = readPairingConfig();
  if (config.devMode || !config.pairingRequired || config.paired) {
    const next = {
      pairingRequired: !!config.pairingRequired,
      tokenHash: config.tokenHash || undefined,
      paired: !config.pairingRequired || !!config.paired,
      lastPairedAt: config.lastPairedAt || undefined,
      lastSeenAt: Date.now() / 1000,
      client: client || config.client || undefined
    };
    if (!config.devMode) writePairingConfig(next);
    return { ...config, ...next };
  }
  return config;
}

function tryPair(token, client) {
  const config = readPairingConfig();
  if (!config.pairingRequired) return markSeen(client);

  const supplied = String(token || '').trim();
  if (!supplied || !config.tokenHash || sha256(supplied) !== config.tokenHash) {
    return { ...config, paired: false, invalidToken: !!supplied };
  }

  const now = Date.now() / 1000;
  const next = {
    pairingRequired: true,
    tokenHash: config.tokenHash,
    paired: true,
    lastPairedAt: now,
    lastSeenAt: now,
    client: client || config.client || undefined
  };
  writePairingConfig(next);
  return { ...config, ...next };
}

function requirePaired(message) {
  const client = safeClient(message?.client);
  const token = message?.token || message?.body?.token;
  const config = token ? tryPair(token, client) : readPairingConfig();
  if (!config.pairingRequired || config.paired) {
    markSeen(client);
    return true;
  }
  return false;
}

function contentToText(content) {
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content.map(part => {
      if (typeof part === 'string') return part;
      if (part?.type === 'text' && typeof part.text === 'string') return part.text;
      return '';
    }).join('\n').trim();
  }
  return '';
}

function buildPromptFromMessages(messages) {
  const transcript = (messages || [])
    .map(message => {
      const role = String(message?.role || 'user').toUpperCase();
      const text = contentToText(message?.content);
      return `${role}: ${text}`.trim();
    })
    .filter(Boolean)
    .join('\n\n');
  return `${transcript}\n\nASSISTANT:`;
}

function extractAssistantTextFromEventLine(line) {
  let parsed;
  try { parsed = JSON.parse(line); } catch { return null; }

  if (parsed?.type === 'turn_end') return contentToText(parsed?.message?.content);
  if (parsed?.type === 'message_end' && parsed?.message?.role === 'assistant') return contentToText(parsed?.message?.content);
  if (parsed?.type === 'message_update') {
    const delta = parsed?.assistantMessageEvent?.delta;
    if (typeof delta === 'string') return delta;
  }
  return null;
}

function parsePiModelsTable(output) {
  const rows = [];
  const lines = String(output || '').split('\n').map(line => line.trim()).filter(Boolean);
  for (const line of lines) {
    if (/^provider\s+model\s+/i.test(line)) continue;
    const parts = line.split(/\s+/);
    if (parts.length < 2) continue;
    const [provider, model, context = '', maxOutput = '', thinking = '', images = ''] = parts;
    if (!provider || !model || provider === '---') continue;
    rows.push({
      id: `${provider}/${model}`,
      object: 'model',
      owned_by: provider,
      provider,
      model,
      name: `${provider}/${model}`,
      context,
      maxOutput,
      thinking: /^yes$/i.test(thinking),
      images: /^yes$/i.test(images)
    });
  }
  return rows;
}

async function listPiModels() {
  const now = Date.now();
  if (modelCache.payload && modelCache.expiresAt > now) return modelCache.payload;

  const payload = await new Promise((resolve, reject) => {
    const child = spawn(PI_BINARY, ['--list-models'], { stdio: ['ignore', 'pipe', 'pipe'], env: process.env });
    let stdout = '';
    let stderr = '';
    const timeout = setTimeout(() => {
      child.kill('SIGTERM');
      reject(new Error('pi --list-models timeout'));
    }, 30000);
    child.stdout.on('data', chunk => { stdout += chunk.toString('utf8'); });
    child.stderr.on('data', chunk => { stderr += chunk.toString('utf8'); });
    child.on('error', error => { clearTimeout(timeout); reject(error); });
    child.on('close', code => {
      clearTimeout(timeout);
      if (code !== 0) return reject(new Error(stderr || `pi --list-models exited with code ${code}`));
      const parsed = parsePiModelsTable(stdout || stderr);
      const data = [
        { id: 'pi-agent', object: 'model', owned_by: 'local-pi', provider: 'local-pi', model: 'pi-agent', name: 'Pi default model' },
        ...parsed
      ];
      const providers = [...new Set(data.map(item => item.provider || item.owned_by).filter(Boolean))]
        .map(id => ({ id, object: 'provider', model_count: data.filter(item => (item.provider || item.owned_by) === id).length }));
      resolve({ object: 'list', data, providers });
    });
  });

  modelCache = { expiresAt: now + MODEL_CACHE_TTL_MS, payload };
  return payload;
}

async function runPi(prompt, model) {
  const args = ['--mode', 'json', '--print'];
  if (BROWSER_TOOLS_ENABLED && fs.existsSync(BROWSER_TOOLS_EXTENSION_PATH)) {
    args.push('--extension', BROWSER_TOOLS_EXTENSION_PATH);
  }
  if (DEFAULT_PROVIDER) args.push('--provider', DEFAULT_PROVIDER);
  const effectiveModel = model && model !== 'pi-agent' ? model : DEFAULT_MODEL;
  if (effectiveModel) args.push('--model', effectiveModel);
  args.push(prompt);

  return new Promise((resolve, reject) => {
    const child = spawn(PI_BINARY, args, { stdio: ['ignore', 'pipe', 'pipe'], env: process.env });
    let stdout = '';
    let stderr = '';
    let latestAssistant = '';
    const timeout = setTimeout(() => {
      child.kill('SIGTERM');
      reject(new Error(`Pi timeout (${REQUEST_TIMEOUT_MS}ms)`));
    }, REQUEST_TIMEOUT_MS);

    child.stdout.on('data', chunk => {
      const text = chunk.toString('utf8');
      stdout += text;
      for (const line of text.split('\n').map(s => s.trim()).filter(Boolean)) {
        const extracted = extractAssistantTextFromEventLine(line);
        if (extracted) latestAssistant = extracted;
      }
    });
    child.stderr.on('data', chunk => { stderr += chunk.toString('utf8'); });
    child.on('error', error => { clearTimeout(timeout); reject(error); });
    child.on('close', code => {
      clearTimeout(timeout);
      if (code !== 0) return reject(new Error(stderr || `pi exited with code ${code}`));
      if (latestAssistant) return resolve(latestAssistant);
      const lines = stdout.split('\n').map(s => s.trim()).filter(Boolean);
      for (let i = lines.length - 1; i >= 0; i -= 1) {
        const extracted = extractAssistantTextFromEventLine(lines[i]);
        if (extracted) return resolve(extracted);
      }
      resolve('');
    });
  });
}

async function handleMessage(message) {
  const type = String(message?.type || '').toLowerCase();
  const client = safeClient(message?.client);

  if (type === 'health') {
    const pairedConfig = message?.token ? tryPair(message.token, client) : markSeen(client);
    return {
      ok: true,
      json: {
        ok: true,
        service: 'browspi-native-host',
        piBinary: PI_BINARY,
        ...publicPairingStatus(pairedConfig)
      }
    };
  }

  if (type === 'pair') {
    const pairedConfig = tryPair(message?.token, client);
    if (pairedConfig.pairingRequired && !pairedConfig.paired) {
      return { ok: false, status: 401, code: 'pairing_required', error: pairedConfig.invalidToken ? 'Invalid pairing token' : 'Pairing token required', json: publicPairingStatus(pairedConfig) };
    }
    return { ok: true, status: 200, json: { ok: true, ...publicPairingStatus(pairedConfig) } };
  }

  if (type === 'get_pairing_status') {
    return { ok: true, status: 200, json: publicPairingStatus(readPairingConfig()) };
  }

  if (!requirePaired(message)) {
    return { ok: false, status: 401, code: 'pairing_required', error: 'Pairing required. Open PiChat → Settings → Browser and enter the pairing token in Browspi.' };
  }

  const method = String(message?.method || (type === 'get_models' ? 'GET' : 'POST')).toUpperCase();
  const pathName = String(message?.path || (type === 'get_models' ? '/v1/models' : type === 'chat_completion' ? '/v1/chat/completions' : ''));

  if (method === 'GET' && pathName === '/v1/models') {
    return { ok: true, status: 200, json: await listPiModels() };
  }

  if (method === 'GET' && pathName === '/v1/providers') {
    const models = await listPiModels();
    return { ok: true, status: 200, json: { object: 'list', data: models.providers || [] } };
  }

  if (method === 'POST' && pathName === '/v1/chat/completions') {
    const body = message?.body || {};
    if (body.stream) return { ok: false, status: 400, error: 'stream=true is not supported by Browspi native host yet' };
    if (!Array.isArray(body.messages) || body.messages.length === 0) return { ok: false, status: 400, error: 'messages[] is required' };
    const model = typeof body.model === 'string' ? body.model : 'pi-agent';
    const answer = await runPi(buildPromptFromMessages(body.messages), model);
    return {
      ok: true,
      status: 200,
      json: {
        id: `chatcmpl_native_${Date.now()}`,
        object: 'chat.completion',
        created: Math.floor(Date.now() / 1000),
        model,
        choices: [{ index: 0, message: { role: 'assistant', content: answer }, finish_reason: 'stop' }],
        usage: { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 }
      }
    };
  }

  return { ok: false, status: 404, error: `No native route for ${method} ${pathName}` };
}

process.stdin.on('data', async chunk => {
  inputBuffer = Buffer.concat([inputBuffer, chunk]);
  let frames;
  try { frames = readFrames(); } catch (error) {
    log('frame error:', error.message || error);
    writeFrame({ ok: false, error: error.message || String(error) });
    return;
  }

  for (const frame of frames) {
    if (frame?.type === 'browser_tool_result' && handleBrowserToolResult(frame)) continue;
    const id = frame?.id;
    try {
      const result = await handleMessage(frame);
      writeFrame({ id, ...result });
    } catch (error) {
      log('request failed:', error.message || error);
      writeFrame({ id, ok: false, error: error.message || String(error) });
    }
  }
});

startBrowserBroker();

process.stdin.on('end', () => process.exit(0));
process.on('uncaughtException', error => {
  log('uncaught:', error.stack || error.message || error);
  writeFrame({ ok: false, error: error.message || String(error) });
});
