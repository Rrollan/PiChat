#!/usr/bin/env node
import fs from 'node:fs';
import { spawn } from 'node:child_process';

const PI_BINARY = process.env.PI_BINARY || 'pi';
const DEFAULT_MODEL = process.env.PI_BRIDGE_MODEL || '';
const DEFAULT_PROVIDER = process.env.PI_BRIDGE_PROVIDER || '';
const REQUEST_TIMEOUT_MS = Number(process.env.BROWSPI_NATIVE_TIMEOUT_MS || 180000);
const MODEL_CACHE_TTL_MS = Number(process.env.BROWSPI_MODEL_CACHE_TTL_MS || 60000);

let inputBuffer = Buffer.alloc(0);
let modelCache = { expiresAt: 0, payload: null };

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
  if (message?.type === 'health') {
    return { ok: true, json: { ok: true, service: 'browspi-native-host', piBinary: PI_BINARY } };
  }

  const method = String(message?.method || 'POST').toUpperCase();
  const path = String(message?.path || '');

  if (method === 'GET' && path === '/v1/models') {
    return { ok: true, status: 200, json: await listPiModels() };
  }

  if (method === 'GET' && path === '/v1/providers') {
    const models = await listPiModels();
    return { ok: true, status: 200, json: { object: 'list', data: models.providers || [] } };
  }

  if (method === 'POST' && path === '/v1/chat/completions') {
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

  return { ok: false, status: 404, error: `No native route for ${method} ${path}` };
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

process.stdin.on('end', () => process.exit(0));
process.on('uncaughtException', error => {
  log('uncaught:', error.stack || error.message || error);
  writeFrame({ ok: false, error: error.message || String(error) });
});
