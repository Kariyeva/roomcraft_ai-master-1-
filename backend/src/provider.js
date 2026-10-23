const { setTimeout: sleep } = require('node:timers/promises');
const { buildStrictPrompt } = require('./prompts');
const { outputImage } = require('./images');

const ROOM_MODEL = 'black-forest-labs/flux-kontext-pro';
const BACKGROUND_VERSION = 'a029dff38972b5fda4ec5d75d7d1cd25aeff621d2cf4946a41055d7db66b80bc';
class RejectedPrediction extends Error {}
async function boundedBody(response, maxBytes) {
  if (Number(response.headers.get('content-length')) > maxBytes) throw new Error('Response too large');
  const parts = [];
  let size = 0;
  if (!response.body) throw new Error('Empty response');
  try {
    for await (const part of response.body) {
      size += part.length;
      if (size > maxBytes) throw new Error('Response too large');
      parts.push(part);
    }
  } catch (error) { await response.body.cancel().catch(() => {}); throw error; }
  return Buffer.concat(parts);
}

class ReplicateProvider {
  constructor(config, fetchImpl = fetch) { this.config = config; this.fetch = fetchImpl; }
  async api(path, method = 'GET', body, extraHeaders = {}) {
    const response = await this.fetch(`https://api.replicate.com/v1/${path}`, {
      method, redirect: 'error', signal: AbortSignal.timeout(this.config.fetchMs),
      headers: { Authorization: `Bearer ${this.config.token}`, 'Content-Type': 'application/json', ...extraHeaders },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    if (!response.ok) {
      // Only explicit rejection statuses are considered safe terminal failures.
      // 5xx/network failures may have accepted a paid POST: never resubmit it.
      if (method === 'POST' && [400, 401, 402, 403, 404, 422, 429].includes(response.status)) {
        await response.body?.cancel();
        throw new RejectedPrediction('Provider rejected request');
      }
      await response.body?.cancel();
      throw new Error('Provider unavailable');
    }
    const bytes = await boundedBody(response, 2 * 1024 * 1024);
    return JSON.parse(bytes.toString('utf8'));
  }
  async create(kind, { image, prompt, style }) {
    const path = kind === 'room' ? `models/${ROOM_MODEL}/predictions` : 'predictions';
    const body = kind === 'room' ? {
      input: { prompt: buildStrictPrompt(prompt, style), input_image: image, output_format: 'png', aspect_ratio: 'match_input_image' },
    } : { version: BACKGROUND_VERSION, input: { image } };
    // Deliberately one HTTP attempt. No SDK or fetch retries around paid POST.
    const result = await this.api(path, 'POST', body, { 'Cancel-After': `${Math.ceil(this.config.predictionMs / 1000)}s` });
    if (!result || !/^[a-zA-Z0-9_-]{1,128}$/.test(result.id || '')) throw new Error('Invalid provider response');
    return result.id;
  }
  async get(id) { return this.api(`predictions/${id}`); }
  async cancel(id) { return this.api(`predictions/${id}/cancel`, 'POST'); }
  async output(prediction, kind) {
    const raw = Array.isArray(prediction.output) ? prediction.output[0] : prediction.output;
    const url = new URL(typeof raw === 'string' ? raw : raw?.image || '');
    if (url.protocol !== 'https:' || url.username || url.password || url.port ||
        !(url.hostname === 'replicate.delivery' || url.hostname.endsWith('.replicate.delivery'))) throw new Error('Disallowed output origin');
    const response = await this.fetch(url, { redirect: 'error', signal: AbortSignal.timeout(this.config.fetchMs) });
    if (!response.ok) { await response.body?.cancel(); throw new Error('Output unavailable'); }
    return outputImage(await boundedBody(response, 10 * 1024 * 1024), kind);
  }
}

class OperationWorker {
  constructor(ledger, provider, config, logger) {
    this.ledger = ledger; this.provider = provider; this.config = config; this.logger = logger;
    this.running = new Map();
  }
  start(operation, input) {
    const id = `${operation.uid}:${operation.key}`;
    if (this.running.has(id)) return;
    const task = this.run(operation, input).catch(() => {
      this.logger({ event: 'operation_storage_failure', operationId: operation.key });
    }).finally(() => this.running.delete(id));
    this.running.set(id, task);
  }
  async run(op, input) {
    let predictionId = op.predictionId;
    try {
      if (!predictionId) {
        if (!input || !await this.ledger.claim(op.uid, op.key)) return;
        predictionId = await this.provider.create(op.kind, input);
        await this.ledger.prediction(op.uid, op.key, predictionId);
      }
      const deadline = Date.now() + this.config.predictionMs;
      do {
        const prediction = await this.provider.get(predictionId);
        if (prediction.status === 'succeeded') {
          const result = await this.provider.output(prediction, op.kind);
          await this.ledger.finish(op.uid, op.key, 'succeeded', result);
          return;
        }
        if (['failed', 'canceled'].includes(prediction.status)) {
          await this.ledger.finish(op.uid, op.key, prediction.status, {
            code: 'GENERATION_FAILED', message: 'AI не смог обработать изображение. Запрос учтён в лимите.',
          });
          return;
        }
        if (!['starting', 'processing'].includes(prediction.status)) throw new Error('Unknown prediction status');
        await sleep(this.config.pollMs);
      } while (Date.now() < deadline);
      throw new Error('Prediction timeout');
    } catch (error) {
      if (error instanceof RejectedPrediction && !predictionId) {
        await this.ledger.finish(op.uid, op.key, 'failed', { code: 'PROVIDER_REJECTED', message: 'AI-сервис отклонил запрос. Обратитесь к администратору.' });
      } else {
        if (predictionId) await this.provider.cancel(predictionId).catch(() => {});
        await this.ledger.review(op.uid, op.key);
      }
      this.logger({ event: 'operation_interrupted', operationId: op.key });
    }
  }
  async drain() { await Promise.allSettled([...this.running.values()]); }
}
module.exports = { ReplicateProvider, OperationWorker, RejectedPrediction, boundedBody, ROOM_MODEL, BACKGROUND_VERSION };
