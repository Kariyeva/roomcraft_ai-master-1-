const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { FirestoreLedger } = require('../src/ledger');
const { loadConfig } = require('../src/config');

test('Actual Firestore emulator transactions enforce shared quota and private ledger rules', {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
}, async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  assert.match(host, /^(localhost|127\.0\.0\.1):\d+$/, 'Local emulator only: never write test data to production');
  const { initializeApp, deleteApp } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  const projectId = 'demo-roomcraft';
  const app = initializeApp({ projectId }, randomUUID());
  const db = getFirestore(app);
  const suffix = randomUUID();
  const uid = `integration-${suffix}`;
  const config = loadConfig({ FIREBASE_PROJECT_ID: projectId });
  const ledger = new FirestoreLedger(db, config);
  try {
    await db.collection('users').doc(uid).collection('savedWorks').doc('project').set({ userId: uid });
    const a = { uid, key: `operation-a-${suffix}`, fingerprint: 'a', kind: 'room', projectId: 'project' };
    const b = { ...a, key: `operation-b-${suffix}`, fingerprint: 'b' };
    const outcomes = await Promise.allSettled([ledger.reserve(a), ledger.reserve(b)]);
    assert.equal(outcomes.filter(result => result.status === 'fulfilled').length, 1);
    const denied = await fetch(`http://${host}/v1/projects/${projectId}/databases/(default)/documents/_aiSecurityUsers/${uid}`);
    assert.equal(denied.status, 403);
  } finally {
    await db.recursiveDelete(db.collection('users').doc(uid));
    await db.recursiveDelete(db.collection('_aiSecurityUsers').doc(uid));
    // Dedicated demo emulator only; no production configuration is read here.
    await db.collection('_aiSecurityGlobal').doc('limits').delete();
    await db.terminate(); await deleteApp(app);
  }
});
