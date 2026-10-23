const { ApiError, terminal } = require('./errors');

function checkProject(snapshot, uid) {
  if (!snapshot.exists || (snapshot.data().userId && snapshot.data().userId !== uid)) {
    throw new ApiError(404, 'PROJECT_NOT_FOUND', 'Проект не найден или недоступен.');
  }
}

// All counters live in admin-only collections, never in client-editable users.
function quotaUpdate(user = {}, global = {}, now, config) {
  const day = new Date(now).toISOString().slice(0, 10);
  const minute = Math.floor(now / 60000);
  const daily = user.day === day ? user.daily || 0 : 0;
  const minuteUsed = user.minute === minute ? user.minuteUsed || 0 : 0;
  const globalDaily = global.day === day ? global.daily || 0 : 0;
  if (daily >= config.userDaily) throw new ApiError(429, 'DAILY_LIMIT', 'Дневной лимит AI-запросов исчерпан.', Math.ceil((Date.parse(`${day}T00:00:00Z`) + 86400000 - now) / 1000));
  if (minuteUsed >= config.userMinute) throw new ApiError(429, 'RATE_LIMIT', 'Слишком много AI-запросов. Повторите позже.', 60 - Math.floor(now / 1000) % 60);
  if ((user.active || 0) >= 1) throw new ApiError(409, 'OPERATION_ACTIVE', 'Предыдущий AI-запрос ещё выполняется или требует проверки.');
  if (globalDaily >= config.globalDaily) throw new ApiError(429, 'GLOBAL_LIMIT', 'Общий дневной лимит AI исчерпан.', 3600);
  if ((global.active || 0) >= config.globalConcurrent) throw new ApiError(429, 'CAPACITY_LIMIT', 'AI-сервис занят. Повторите позже.', 15);
  return {
    user: { day, daily: daily + 1, minute, minuteUsed: minuteUsed + 1, active: 1 },
    global: { day, daily: globalDaily + 1, active: (global.active || 0) + 1 },
  };
}

class FirestoreLedger {
  constructor(db, config, now = Date.now) { this.db = db; this.config = config; this.now = now; }
  refs(uid, key, fingerprint) {
    const user = this.db.collection('_aiSecurityUsers').doc(uid);
    return { user, global: this.db.collection('_aiSecurityGlobal').doc('limits'),
      op: user.collection('operations').doc(key),
      dedup: fingerprint ? user.collection('fingerprints').doc(fingerprint) : null };
  }
  project(uid, id) { return this.db.collection('users').doc(uid).collection('savedWorks').doc(id); }
  async checkProject(uid, id) { if (id) checkProject(await this.project(uid, id).get(), uid); }
  async reserve({ uid, key, fingerprint, kind, projectId }) {
    const refs = this.refs(uid, key, fingerprint);
    return this.db.runTransaction(async tx => {
      const [op, user, global, dup] = await Promise.all([refs.op, refs.user, refs.global, refs.dedup].map(ref => tx.get(ref)));
      if (projectId) checkProject(await tx.get(this.project(uid, projectId)), uid);
      if (op.exists) {
        if (op.data().fingerprint !== fingerprint) throw new ApiError(409, 'IDEMPOTENCY_CONFLICT', 'Ключ запроса уже использован с другими данными.');
        if (op.data().canonicalKey) {
          const canonical = await tx.get(this.refs(uid, op.data().canonicalKey).op);
          if (!canonical.exists) throw new ApiError(409, 'REVIEW_REQUIRED', 'Исходный запрос требует проверки.');
          return { created: false, operation: canonical.data() };
        }
        return { created: false, operation: op.data() };
      }
      const now = this.now();
      if (dup.exists && now - dup.data().createdAtMs < this.config.dedupMs) {
        const canonical = await tx.get(this.refs(uid, dup.data().key).op);
        if (!canonical.exists) throw new ApiError(409, 'REVIEW_REQUIRED', 'Исходный запрос требует проверки.');
        // Bind the second key permanently to the original operation, without charging.
        tx.set(refs.op, { uid, key, fingerprint, canonicalKey: canonical.data().key });
        return { created: false, operation: canonical.data() };
      }
      const quotas = quotaUpdate(user.data(), global.data(), now, this.config);
      const operation = { key, uid, fingerprint, kind, projectId: projectId || null, status: 'reserved', createdAtMs: now, updatedAtMs: now };
      tx.set(refs.user, quotas.user);
      tx.set(refs.global, quotas.global);
      tx.set(refs.op, operation);
      tx.set(refs.dedup, { key, createdAtMs: now });
      return { created: true, operation };
    });
  }
  async get(uid, key) {
    const snapshot = await this.refs(uid, key).op.get();
    if (!snapshot.exists) return null;
    if (snapshot.data().canonicalKey) {
      const canonical = await this.refs(uid, snapshot.data().canonicalKey).op.get();
      return canonical.exists ? canonical.data() : null;
    }
    return snapshot.data();
  }
  async claim(uid, key) {
    const ref = this.refs(uid, key).op;
    return this.db.runTransaction(async tx => {
      const op = await tx.get(ref);
      if (!op.exists || op.data().status !== 'reserved') return false;
      tx.update(ref, { status: 'submitting', updatedAtMs: this.now() });
      return true;
    });
  }
  async prediction(uid, key, predictionId) {
    const ref = this.refs(uid, key).op;
    await this.db.runTransaction(async tx => {
      const op = await tx.get(ref);
      if (!op.exists || terminal(op.data().status)) return;
      tx.update(ref, { status: 'processing', predictionId, updatedAtMs: this.now() });
    });
  }
  async review(uid, key) {
    const ref = this.refs(uid, key).op;
    await this.db.runTransaction(async tx => {
      const op = await tx.get(ref);
      if (!op.exists || terminal(op.data().status)) return;
      tx.update(ref, { status: 'requires_review', error: { code: 'REVIEW_REQUIRED', message: 'Статус AI-запроса требует проверки. Новый платный запрос автоматически не запускается.' }, updatedAtMs: this.now() });
    });
  }
  async finish(uid, key, status, value) {
    if (!terminal(status)) throw new Error('Nonterminal finish');
    const refs = this.refs(uid, key);
    await this.db.runTransaction(async tx => {
      const [op, user, global] = await Promise.all([refs.op, refs.user, refs.global].map(ref => tx.get(ref)));
      if (!op.exists || terminal(op.data().status)) return;
      tx.update(refs.op, { status, ...(status === 'succeeded' ? { result: value } : { error: value }), updatedAtMs: this.now() });
      tx.update(refs.user, { active: Math.max(0, (user.data()?.active || 0) - 1) });
      tx.update(refs.global, { active: Math.max(0, (global.data()?.active || 0) - 1) });
    });
  }
}
module.exports = { FirestoreLedger, quotaUpdate };
