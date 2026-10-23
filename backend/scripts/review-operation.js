// Operator tool. Default is read-only; never calls predictions.create().
const { dependencies } = require('../server');
const { terminal } = require('../src/errors');
async function run() {
  const args = process.argv.slice(2);
  const value = flag => args[args.indexOf(flag) + 1];
  if (!args.includes('--uid') || !args.includes('--operation') ||
      !value('--uid') || value('--uid').length > 128 || value('--uid').includes('/') ||
      !/^[a-zA-Z0-9_-]{16,128}$/.test(value('--operation') || '') ||
      args.some(arg => arg.startsWith('--') && !['--uid', '--operation', '--apply', '--confirm-no-active-prediction'].includes(arg))) {
    console.error('Usage: npm run review:operation -- --uid USER_UID --operation OPERATION_ID [--apply] [--confirm-no-active-prediction]');
    process.exitCode = 2; return;
  }
  const { ledger, provider, config } = dependencies();
  try {
    const op = await ledger.get(value('--uid'), value('--operation'));
    if (!op) throw new Error('Missing operation');
    if (terminal(op.status)) { console.log(JSON.stringify({ operationId: op.key, status: op.status, changed: false })); return; }
    let prediction;
    if (op.predictionId) {
      if (!config.token) throw new Error('Provider token required for inspection');
      prediction = await provider.get(op.predictionId);
    }
    if (!args.includes('--apply')) {
      console.log(JSON.stringify({ operationId: op.key, status: op.status, hasPrediction: Boolean(op.predictionId), providerStatus: prediction?.status || 'unknown', changed: false }));
      return;
    }
    if (config.enabled) throw new Error('Disable new AI submissions before applying operator resolution');
    if (prediction) {
      if (!terminal(prediction.status)) throw new Error('Prediction is still active');
      if (prediction.status === 'succeeded') {
        await ledger.finish(op.uid, op.key, 'succeeded', await provider.output(prediction, op.kind));
      } else {
        await ledger.finish(op.uid, op.key, prediction.status, { code: 'GENERATION_FAILED', message: 'AI-запрос завершился без результата.' });
      }
    } else {
      const minAge = config.predictionMs + config.fetchMs + 60000;
      if (!args.includes('--confirm-no-active-prediction') || Date.now() - op.createdAtMs < minAge) throw new Error('Manual provider-history review and grace period required');
      // This flag is a human attestation, not a technical proof of no charge.
      // Daily quota is not refunded; only the blocked concurrency slot is released.
      await ledger.finish(op.uid, op.key, 'failed', { code: 'MANUALLY_REVIEWED', message: 'Запрос закрыт администратором после проверки.' });
    }
    console.log(JSON.stringify({ operationId: op.key, changed: true }));
  } finally { await ledger.db.terminate(); }
}
if (require.main === module) run().catch(() => {
  console.error('Operator review failed. Check configuration, operation state and required confirmations. No paid prediction was submitted.');
  process.exitCode = 1;
});
module.exports = { run };
