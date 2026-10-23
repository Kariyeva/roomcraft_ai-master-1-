const { test } = require('node:test');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const { once } = require('node:events');
const { createApp } = require('../src/app');
const { loadConfig } = require('../src/config');
const { FirestoreLedger, quotaUpdate } = require('../src/ledger');
const { ReplicateProvider, RejectedPrediction, boundedBody, ROOM_MODEL } = require('../src/provider');
const { inputImage, outputImage } = require('../src/images');
const { FakeFirestore } = require('./fake-firestore');

const key = number => `test-operation-${String(number).padStart(6, '0')}`;
async function setup(t, overrides = {}) {
  const config = { ...loadConfig({ FIREBASE_PROJECT_ID: 'demo-roomcraft' }), enabled: true, ledgerRulesConfirmed: true,
    pollMs: 1, predictionMs: 50, ...overrides.config };
  const db = overrides.db || new FakeFirestore();
  db.seed('users/alice/savedWorks/project-1', { userId: 'alice' });
  db.seed('users/bob/savedWorks/bob-project', { userId: 'bob' });
  const ledger = new FirestoreLedger(db, config);
  const bytes = await sharp({ create: { width: 8, height: 8, channels: 3, background: '#e8e2d8' } }).png().toBuffer();
  let creates = 0;
  const provider = {
    create: async () => { creates++; return 'prediction-1'; },
    get: async () => ({ status: 'succeeded' }),
    output: async (_, kind) => outputImage(bytes, kind),
    cancel: async () => ({}), ...overrides.provider,
  };
  const logs = [];
  const auth = { verifyIdToken: async (token, revoked) => {
    assert.equal(revoked, true);
    if (!['alice-token', 'bob-token', 'guest-token'].includes(token)) throw Object.assign(new Error('secret provider error'), { code: 'auth/id-token-expired' });
    return { uid: token.split('-')[0], firebase: { sign_in_provider: token === 'guest-token' ? 'anonymous' : 'password' } };
  } };
  const { app, worker } = createApp({ auth, ledger, provider, config, logger: event => logs.push(event) });
  const server = app.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(async () => { await worker.drain(); server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); });
  const base = `http://127.0.0.1:${server.address().port}`;
  async function post({ id = key(1), token = 'alice-token', path = '/generate-room', projectId = 'project-1', prompt = '', extra = {}, image = bytes, origin, fieldName = 'image' } = {}) {
    const form = new FormData();
    if (path === '/generate-room') { form.set('prompt', prompt); form.set('style', 'Modern'); }
    if (projectId !== null) form.set('projectId', projectId);
    for (const [name, value] of Object.entries(extra)) form.set(name, value);
    form.set(fieldName, new Blob([image], { type: 'image/png' }), 'room.png');
    return fetch(base + path, { method: 'POST', headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), 'Idempotency-Key': id, ...(origin ? { Origin: origin } : {}) }, body: form });
  }
  const get = (id = key(1), token = 'alice-token') => fetch(base + `/operations/${id}`, { headers: { Authorization: `Bearer ${token}` } });
  return { config, db, ledger, bytes, worker, provider, post, get, base, logs, creates: () => creates };
}

test('Firebase bearer verification is required on BOTH paid endpoints before upload or provider', async t => {
  const s = await setup(t);
  for (const path of ['/generate-room', '/remove-background']) {
    for (const [token, code] of [[null, 401], ['invalid-token', 401], ['guest-token', 403]]) {
      assert.equal((await s.post({ path, token })).status, code);
    }
  }
  assert.equal(s.creates(), 0);
});
test('UID spoofing, missing project and cross-user projects are rejected', async t => {
  const s = await setup(t);
  assert.equal((await s.post({ extra: { userId: 'bob' } })).status, 403);
  assert.equal((await s.post({ projectId: 'bob-project' })).status, 404);
  assert.equal((await s.post({ projectId: '../bob' })).status, 400);
  assert.equal((await s.post({ projectId: null })).status, 400);
  assert.equal((await s.post({ token: 'bob-token' })).status, 404);
  assert.equal(s.creates(), 0);
});
test('Successful result is private; same id across concurrent requests uses one provider-create call and one quota reservation', async t => {
  const s = await setup(t);
  const responses = await Promise.all([s.post(), s.post(), s.post()]);
  assert.ok(responses.every(r => [200, 202, 503].includes(r.status)));
  await s.worker.drain();
  const result = await (await s.get()).json();
  assert.equal(result.status, 'succeeded');
  assert.equal(result.mimeType, 'image/jpeg');
  assert.ok(result.imageBase64);
  assert.equal(result.imageUrl, undefined);
  assert.equal(result.uid, undefined);
  assert.equal(result.predictionId, undefined);
  assert.equal((await s.post()).status, 200);
  assert.equal(s.creates(), 1);
  assert.equal(s.db.documents.get('_aiSecurityUsers/alice').daily, 1);
  assert.equal(s.db.documents.get('_aiSecurityUsers/alice').active, 0);
  assert.equal((await s.get(key(1), 'bob-token')).status, 404);
  assert.equal((await fetch(s.base + '/generated/room.png')).status, 404);
});
test('Same key with changed payload and duplicate payload with a new key cannot trigger a second provider creation', async t => {
  const s = await setup(t);
  await s.post(); await s.worker.drain();
  assert.equal((await s.post({ prompt: 'different' })).status, 409);
  const duplicate = await s.post({ id: key(2) });
  assert.equal(duplicate.status, 200);
  assert.equal((await duplicate.json()).operationId, key(1));
  assert.equal((await s.post({ id: key(2), prompt: 'different payload' })).status, 409);
  assert.equal(s.creates(), 1);
});
test('Daily, per-minute and global limits apply server-side and do not call Replicate', async t => {
  for (const field of ['userDaily', 'userMinute', 'globalDaily']) {
    await t.test(field, async t => {
      const s = await setup(t, { config: { [field]: 1 } });
      await s.post(); await s.worker.drain();
      const response = await s.post({ id: key(2), prompt: 'new request' });
      assert.equal(response.status, 429);
      assert.ok(response.headers.get('retry-after'));
      assert.equal(s.creates(), 1);
    });
  }
});
test('Unknown create outcome retains the quota slot and does not automatically resubmit', async t => {
  let calls = 0;
  const s = await setup(t, { provider: { create: async () => { calls++; throw new Error('ambiguous timeout with secret token'); } } });
  await s.post(); await s.worker.drain();
  assert.equal((await (await s.get()).json()).status, 'requires_review');
  await s.post(); await s.worker.drain();
  assert.equal(calls, 1);
  assert.equal(s.db.documents.get('_aiSecurityUsers/alice').active, 1);
  assert.equal((await s.post({ id: key(2), prompt: 'new' })).status, 409);
  assert.ok(!JSON.stringify(s.logs).includes('secret token'));
});
test('Known prediction resumes with GET after a process restart, without another paid POST', async t => {
  const s = await setup(t);
  await s.ledger.reserve({ uid: 'alice', key: key(1), fingerprint: 'original', kind: 'room', projectId: 'project-1' });
  await s.ledger.claim('alice', key(1));
  await s.ledger.prediction('alice', key(1), 'prediction-known');
  await s.get(); await s.worker.drain();
  assert.equal(s.creates(), 0);
  assert.equal((await (await s.get()).json()).status, 'succeeded');
  await s.ledger.finish('alice', key(1), 'succeeded', {});
  assert.equal(s.db.documents.get('_aiSecurityGlobal/limits').active, 0);
});
test('Provider deadline attempts cancellation and leaves an unresolved slot for review', async t => {
  let canceled = 0;
  const s = await setup(t, { config: { predictionMs: 4 }, provider: { get: async () => ({ status: 'processing' }), cancel: async () => { canceled++; } } });
  await s.post(); await s.worker.drain();
  assert.equal(canceled, 1);
  assert.equal((await s.ledger.get('alice', key(1))).status, 'requires_review');
});
test('Explicit provider rejection releases concurrency but still consumes conservative request quota', async t => {
  const s = await setup(t, { provider: { create: async () => { throw new RejectedPrediction(); } } });
  await s.post(); await s.worker.drain();
  assert.equal((await s.ledger.get('alice', key(1))).status, 'failed');
  assert.equal(s.db.documents.get('_aiSecurityUsers/alice').active, 0);
  assert.equal(s.db.documents.get('_aiSecurityUsers/alice').daily, 1);
});
test('CORS allowlist, disabled rollout, fields, image data, and key validation fail closed', async t => {
  const s = await setup(t);
  assert.equal((await s.post({ origin: 'https://attacker.example' })).status, 403);
  const preflight = await fetch(s.base + '/generate-room', { method: 'OPTIONS', headers: { Origin: 'http://localhost:7357', 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'Authorization,Idempotency-Key' } });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), 'http://localhost:7357');
  assert.equal(preflight.headers.get('access-control-allow-credentials'), null);
  assert.equal((await s.post({ extra: { model: 'arbitrary-paid-model' } })).status, 400);
  assert.equal((await s.post({ image: Buffer.from('not an image') })).status, 400);
  assert.equal((await s.post({ prompt: 'a'.repeat(4001) })).status, 400);
  assert.equal((await s.post({ id: 'short' })).status, 400);
  assert.equal((await s.post({ fieldName: 'wrong' })).status, 400);
  assert.equal(s.creates(), 0);
  const disabled = await setup(t, { config: { enabled: false } });
  assert.equal((await disabled.post()).status, 503);
  assert.equal(disabled.creates(), 0);
});
test('Upload size limits are enforced and logging omits tokens, prompts and photos', async t => {
  const s = await setup(t, { config: { maxUploadBytes: 100 } });
  const response = await s.post({ image: Buffer.alloc(101), prompt: 'PRIVATE_CLIENT_DESCRIPTION' });
  assert.equal(response.status, 400);
  const logs = JSON.stringify(s.logs);
  assert.ok(!logs.includes('alice-token'));
  assert.ok(!logs.includes('PRIVATE_CLIENT_DESCRIPTION'));
  assert.ok(!logs.includes('imageBase64'));
});
test('UTC quota rollover retains unresolved concurrency; simultaneous reservations across instances are atomic', async () => {
  const config = { ...loadConfig({ FIREBASE_PROJECT_ID: 'demo-roomcraft' }), globalConcurrent: 1 };
  const state = quotaUpdate({ day: '2000-01-01', daily: 900, active: 0 }, { day: '2000-01-01', daily: 900, active: 0 }, Date.now(), config);
  assert.equal(state.user.daily, 1);
  assert.throws(() => quotaUpdate({ active: 1 }, {}, Date.now(), config), error => error.code === 'OPERATION_ACTIVE');
  const db = new FakeFirestore();
  db.seed('users/alice/savedWorks/p', { userId: 'alice' }); db.seed('users/bob/savedWorks/p', { userId: 'bob' });
  const a = new FirestoreLedger(db, config); const b = new FirestoreLedger(db, config);
  const outcomes = await Promise.allSettled([
    a.reserve({ uid: 'alice', key: key(1), fingerprint: 'a', kind: 'room', projectId: 'p' }),
    b.reserve({ uid: 'bob', key: key(2), fingerprint: 'b', kind: 'room', projectId: 'p' }),
  ]);
  assert.equal(outcomes.filter(x => x.status === 'fulfilled').length, 1);
  assert.equal(db.documents.get('_aiSecurityGlobal/limits').daily, 1);
});
test('Production configuration requires explicit origins, no emulator and confirmed private ledger before AI enable', () => {
  assert.throws(() => loadConfig({ NODE_ENV: 'production', FIREBASE_PROJECT_ID: 'demo-roomcraft' }));
  assert.throws(() => loadConfig({ FIREBASE_PROJECT_ID: 'demo-roomcraft', AI_ENABLED: 'true', REPLICATE_API_TOKEN: 'test-only' }));
  assert.throws(() => loadConfig({ NODE_ENV: 'production', FIREBASE_PROJECT_ID: 'demo-roomcraft', ALLOWED_ORIGINS: 'https://app.example', FIRESTORE_EMULATOR_HOST: 'localhost:8080' }));
  assert.throws(() => loadConfig({ FIREBASE_PROJECT_ID: 'demo-roomcraft', AI_USER_DAILY_LIMIT: '-1' }));
  assert.throws(() => loadConfig({ FIREBASE_PROJECT_ID: 'demo-roomcraft', FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099' }));
  assert.throws(() => loadConfig({ FIREBASE_PROJECT_ID: 'demo-roomcraft', AI_ENABLED: 'true', AI_LEDGER_RULES_CONFIRMED: 'true', REPLICATE_API_TOKEN: 'test-only', FIRESTORE_EMULATOR_HOST: 'localhost:8080' }));
  assert.equal(loadConfig({ FIREBASE_PROJECT_ID: 'demo-roomcraft' }).enabled, false);
});
test('Replicate transport sends one official-model POST with server deadline and no undocumented inputs', async () => {
  const calls = [];
  const provider = new ReplicateProvider({ token: 'test-only-secret', fetchMs: 100, predictionMs: 180000 }, async (url, options) => {
    calls.push({ url, options }); return Response.json({ id: 'prediction-1' });
  });
  await provider.create('room', { image: 'data:image/png;base64,AA==', prompt: 'test', style: 'Modern' });
  assert.equal(calls.length, 1);
  assert.ok(calls[0].url.includes(ROOM_MODEL));
  assert.equal(calls[0].options.headers['Cancel-After'], '180s');
  const input = JSON.parse(calls[0].options.body).input;
  assert.equal(input.prompt_strength, undefined); assert.equal(input.guidance_scale, undefined);
  assert.equal(calls[0].options.redirect, 'error');
  let failures = 0;
  const failing = new ReplicateProvider({ token: 'test-only', fetchMs: 100, predictionMs: 1000 }, async () => { failures++; return new Response('private diagnostics', { status: 500 }); });
  await assert.rejects(() => failing.create('room', { image: 'data:', prompt: '', style: '' }));
  assert.equal(failures, 1);
});
test('Provider outputs cannot fetch private hosts or follow redirects; streamed output size is bounded', async () => {
  let fetches = 0;
  const provider = new ReplicateProvider({ fetchMs: 100 }, async () => { fetches++; return Response.json({}); });
  for (const output of ['http://replicate.delivery/a', 'https://169.254.169.254/latest', 'https://replicate.delivery.attacker.example/a', 'https://user:pass@replicate.delivery/a']) {
    await assert.rejects(() => provider.output({ output }, 'room'));
  }
  assert.equal(fetches, 0);
  await assert.rejects(() => boundedBody(new Response('too big'), 2));
  await assert.rejects(() => inputImage({ buffer: Buffer.from('broken'), mimetype: 'image/png' }));
});

test('Real Firebase Admin SDK modular imports load and malformed tokens fail without a credential or API call', async () => {
  const { initializeApp, deleteApp } = require('firebase-admin/app');
  const { getAuth } = require('firebase-admin/auth');
  const { getFirestore } = require('firebase-admin/firestore');
  const app = initializeApp({ projectId: 'demo-roomcraft' }, 'security-unit-test');
  try {
    const db = getFirestore(app);
    assert.equal(db.collection('_aiSecurityUsers').doc('alice').path, '_aiSecurityUsers/alice');
    await assert.rejects(getAuth(app).verifyIdToken('not-a-jwt', true), error => error.code?.startsWith('auth/'));
    await db.terminate();
  } finally { await deleteApp(app); }
});
test('Wrong content type and deleted project never start a new generation', async t => {
  const s = await setup(t);
  const wrong = await fetch(s.base + '/generate-room', { method: 'POST', headers: { Authorization: 'Bearer alice-token', 'Content-Type': 'application/json' }, body: '{}' });
  assert.equal(wrong.status, 415);
  await s.post(); await s.worker.drain();
  s.db.documents.delete('users/alice/savedWorks/project-1');
  assert.equal((await s.get()).status, 404);
  assert.equal((await s.post()).status, 404);
  assert.equal(s.creates(), 1);
});
test('Background removal shares auth/quota ledger and returns a private PNG', async t => {
  const s = await setup(t);
  const accepted = await s.post({ path: '/remove-background', projectId: null });
  assert.equal(accepted.status, 202);
  await s.worker.drain();
  const result = await (await s.get()).json();
  assert.equal(result.status, 'succeeded'); assert.equal(result.mimeType, 'image/png');
  assert.equal(s.db.documents.get('_aiSecurityUsers/alice').daily, 1);
});
test('Startup and operator tool fail closed without secrets or explicit operation identity', () => {
  const { spawnSync } = require('node:child_process');
  const { resolve } = require('node:path');
  const env = { ...process.env, FIREBASE_PROJECT_ID: 'demo-roomcraft', AI_ENABLED: 'false' };
  // Empty explicit values cannot be overridden by a developer's real .env.
  for (const name of ['FIREBASE_SERVICE_ACCOUNT_PATH', 'GOOGLE_APPLICATION_CREDENTIALS', 'REPLICATE_API_TOKEN']) env[name] = '';
  const startup = spawnSync(process.execPath, [resolve(__dirname, '../server.js')], { env, encoding: 'utf8', timeout: 5000 });
  assert.equal(startup.status, 1);
  assert.ok(startup.stderr.includes('startup_failed'));
  assert.ok(!startup.stderr.includes('private_key'));
  const tool = spawnSync(process.execPath, [resolve(__dirname, '../scripts/review-operation.js')], { env, encoding: 'utf8', timeout: 5000 });
  assert.equal(tool.status, 2); assert.ok(tool.stderr.includes('Usage:'));
});
