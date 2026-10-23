const { resolve } = require('node:path');
const { readFileSync } = require('node:fs');
require('dotenv').config({ path: resolve(__dirname, '.env'), quiet: true });
const { initializeApp, cert, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { loadConfig } = require('./src/config');
const { FirestoreLedger } = require('./src/ledger');
const { ReplicateProvider } = require('./src/provider');
const { createApp } = require('./src/app');

function dependencies() {
  const config = loadConfig();
  if (!config.credentialPath && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error('Server Firebase credentials are required');
  }
  const account = config.credentialPath ? JSON.parse(readFileSync(config.credentialPath, 'utf8')) : null;
  if (account && account.project_id !== config.projectId) throw new Error('Firebase credential project mismatch');
  initializeApp({ projectId: config.projectId, credential: account ? cert(account) : applicationDefault() });
  return { auth: getAuth(), ledger: new FirestoreLedger(getFirestore(), config), provider: new ReplicateProvider(config), config };
}
function main() {
  const services = dependencies();
  const { config } = services;
  const { app, worker } = createApp(services);
  const server = app.listen(config.port, '0.0.0.0', () => console.log(JSON.stringify({ event: 'server_started', aiEnabled: config.enabled })));
  server.requestTimeout = 30000;
  server.headersTimeout = 15000;
  server.keepAliveTimeout = 5000;
  process.once('SIGTERM', () => {
    server.close();
    // Never resubmit after restart. Known prediction IDs can be reconciled on GET.
    worker.drain().finally(() => process.exit(0));
    setTimeout(() => process.exit(0), 10000).unref();
  });
}
if (require.main === module) {
  try { main(); }
  catch (_) { console.error(JSON.stringify({ event: 'startup_failed', message: 'Invalid or missing server configuration. See backend/.env.example and docs/SECURITY_STAGE_3.md.' })); process.exitCode = 1; }
}
module.exports = { main, dependencies };
