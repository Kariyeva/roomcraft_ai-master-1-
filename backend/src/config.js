const { resolve } = require('node:path');
function loadConfig(env = process.env) {
  const production = env.NODE_ENV === 'production';
  function integer(key, fallback, min, max) {
    const value = env[key] === undefined ? fallback : Number(env[key]);
    if (!Number.isInteger(value) || value < min || value > max) throw new Error(`Invalid ${key}`);
    return value;
  }
  function flag(key) {
    if (env[key] !== undefined && !['true', 'false'].includes(env[key])) throw new Error(`Invalid ${key}`);
    return env[key] === 'true';
  }
  const allowedOrigins = (env.ALLOWED_ORIGINS || (production ? '' : 'http://localhost:7357,http://127.0.0.1:7357')).split(',').map(x => x.trim()).filter(Boolean);
  if (!allowedOrigins.length) throw new Error('ALLOWED_ORIGINS is required');
  for (const origin of allowedOrigins) {
    const url = new URL(origin);
    if (url.origin !== origin || url.username || url.password || !['http:', 'https:'].includes(url.protocol)
        || (production && url.protocol !== 'https:')) throw new Error('Invalid ALLOWED_ORIGINS');
  }
  if (!env.FIREBASE_PROJECT_ID) throw new Error('FIREBASE_PROJECT_ID is required');
  if (!/^[a-z][a-z0-9-]{4,62}$/.test(env.FIREBASE_PROJECT_ID)) throw new Error('Invalid FIREBASE_PROJECT_ID');
  if (production && (env.FIRESTORE_EMULATOR_HOST || env.FIREBASE_AUTH_EMULATOR_HOST)) throw new Error('Emulators forbidden in production');
  if (env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Auth emulator is forbidden in the protected runtime');
  const enabled = flag('AI_ENABLED');
  if (enabled && env.FIRESTORE_EMULATOR_HOST) throw new Error('Paid AI cannot use an emulated ledger');
  const ledgerRulesConfirmed = flag('AI_LEDGER_RULES_CONFIRMED');
  if (enabled && (!ledgerRulesConfirmed || !env.REPLICATE_API_TOKEN)) throw new Error('AI requires protected ledger rules and server token');
  return {
    production, enabled, ledgerRulesConfirmed, allowedOrigins,
    projectId: env.FIREBASE_PROJECT_ID,
    credentialPath: env.FIREBASE_SERVICE_ACCOUNT_PATH ? resolve(__dirname, '..', env.FIREBASE_SERVICE_ACCOUNT_PATH) : null,
    token: env.REPLICATE_API_TOKEN,
    port: integer('PORT', 3000, 1, 65535),
    userDaily: integer('AI_USER_DAILY_LIMIT', 10, 1, 1000),
    userMinute: integer('AI_USER_MINUTE_LIMIT', 3, 1, 60),
    globalDaily: integer('AI_GLOBAL_DAILY_LIMIT', 100, 1, 10000),
    globalConcurrent: integer('AI_GLOBAL_CONCURRENT_LIMIT', 3, 1, 10),
    dedupMs: integer('AI_DEDUP_SECONDS', 60, 1, 3600) * 1000,
    predictionMs: integer('AI_TIMEOUT_SECONDS', 180, 30, 300) * 1000,
    fetchMs: integer('AI_HTTP_TIMEOUT_SECONDS', 20, 1, 30) * 1000,
    pollMs: 1500, maxUploadBytes: 10 * 1024 * 1024,
  };
}
module.exports = { loadConfig };
