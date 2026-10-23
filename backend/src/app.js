const express = require('express');
const cors = require('cors');
const multer = require('multer');
const { randomUUID, createHash } = require('node:crypto');
const { ApiError, terminal } = require('./errors');
const { inputImage } = require('./images');
const { OperationWorker } = require('./provider');
const validKey = value => typeof value === 'string' && /^[a-zA-Z0-9_-]{16,128}$/.test(value);
const validProject = value => typeof value === 'string' && /^[a-zA-Z0-9_-]{1,128}$/.test(value);
const styles = new Set(['', 'interior design', 'Minimalist', 'Modern', 'Scandi', 'Classic', 'Industrial', 'Boho', 'Loft', 'Zen']);
function publicOperation(op) {
  return { operationId: op.key, status: op.status,
    ...(op.status === 'succeeded' ? op.result : {}),
    ...(op.error && op.status !== 'succeeded' ? { error: op.error.message, code: op.error.code } : {}),
  };
}
function createApp({ auth, ledger, provider, config, logger = value => console.log(JSON.stringify(value)) }) {
  const app = express();
  const worker = new OperationWorker(ledger, provider, config, logger);
  const attempts = new Map();
  let uploads = 0;
  let imageJobs = 0;
  app.disable('x-powered-by');
  app.set('trust proxy', false);
  app.use((req, res, next) => {
    req.requestId = randomUUID();
    const timer = setTimeout(() => {
      if (!res.headersSent && !res.destroyed) res.status(503).json({ code: 'REQUEST_TIMEOUT', error: 'Время ожидания истекло. Повторите тот же запрос.', requestId: req.requestId });
    }, 30000);
    timer.unref();
    res.once('finish', () => clearTimeout(timer)); res.once('close', () => clearTimeout(timer));
    res.set({ 'X-Request-Id': req.requestId, 'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer' });
    next();
  });
  app.use(cors({
    origin(origin, callback) {
      if (!origin || config.allowedOrigins.includes(origin)) callback(null, true);
      else callback(new ApiError(403, 'ORIGIN_DENIED', 'Этот источник запросов не разрешён.'));
    }, methods: ['GET', 'POST', 'OPTIONS'], allowedHeaders: ['Authorization', 'Content-Type', 'Idempotency-Key'],
    exposedHeaders: ['Retry-After', 'X-Request-Id'], credentials: false, maxAge: 600,
  }));
  app.get(['/', '/healthz'], (_, res) => res.json({ status: 'ok', service: 'roomcraft-api' }));
  async function authenticate(req, _, next) {
    try {
      const match = /^Bearer ([^\s]{1,8192})$/.exec(req.headers.authorization || '');
      if (!match) throw new ApiError(401, 'AUTH_REQUIRED', 'Войдите в аккаунт.');
      let decoded;
      try {
        let timer;
        try {
          decoded = await Promise.race([
            auth.verifyIdToken(match[1], true),
            new Promise((_, reject) => { timer = setTimeout(() => reject(new ApiError(503, 'AUTH_UNAVAILABLE', 'Проверка входа недоступна. Повторите позже.')), 15000); }),
          ]);
        } finally { clearTimeout(timer); }
      }
      catch (error) {
        if (error instanceof ApiError) throw error;
        if (['auth/internal-error', 'app/network-error', 'auth/network-request-failed'].includes(error.code)) {
          throw new ApiError(503, 'AUTH_UNAVAILABLE', 'Не удалось проверить вход. Повторите позже.');
        }
        throw new ApiError(401, 'INVALID_TOKEN', 'Сессия истекла или недействительна. Войдите снова.');
      }
      if (!decoded.uid || typeof decoded.uid !== 'string' || decoded.uid.length > 128 || decoded.uid.includes('/')) throw new ApiError(401, 'INVALID_TOKEN', 'Недействительная сессия.');
      if (decoded.firebase?.sign_in_provider === 'anonymous') throw new ApiError(403, 'REGISTERED_ACCOUNT_REQUIRED', 'Для AI нужен зарегистрированный аккаунт.');
      req.uid = decoded.uid;
      // Fast pre-upload limit. Monetary limits are separately durable and transactional.
      const now = Date.now();
      if (attempts.size > 10000) for (const [uid, state] of attempts) if (state.until <= now) attempts.delete(uid);
      const current = attempts.get(req.uid);
      if (!current || current.until <= now) {
        if (attempts.size >= 11000) throw new ApiError(503, 'SERVICE_BUSY', 'Сервис занят. Повторите позже.');
        attempts.set(req.uid, { used: 1, until: now + 60000 });
      } else {
        if (++current.used > 120) throw new ApiError(429, 'REQUEST_RATE_LIMIT', 'Слишком много запросов.', 60);
      }
      next();
    } catch (error) { next(error); }
  }
  function enabled(_, __, next) {
    if (!config.enabled || !config.ledgerRulesConfirmed) return next(new ApiError(503, 'AI_DISABLED', 'AI-сервис пока не включён администратором.'));
    next();
  }
  function admitUpload(req, res, next) {
    if (res.writableEnded || res.destroyed) return;
    if (!req.is('multipart/form-data')) return next(new ApiError(415, 'MULTIPART_REQUIRED', 'Фотография должна быть передана как multipart/form-data.'));
    const boundary = /boundary=(?:"([^"]+)"|([^;]+))/i.exec(req.headers['content-type'] || '');
    if (!boundary || (boundary[1] || boundary[2]).length > 200) return next(new ApiError(400, 'INVALID_MULTIPART', 'Некорректная загрузка файла.'));
    if (uploads >= 4) return next(new ApiError(503, 'UPLOAD_BUSY', 'Обработка изображений занята. Повторите позже.', 5));
    uploads++;
    let released = false;
    const release = () => { if (!released) { released = true; uploads--; } };
    res.once('finish', release); res.once('close', release);
    next();
  }
  const upload = multer({ storage: multer.memoryStorage(), limits: {
    fileSize: config.maxUploadBytes, files: 1, fields: 5, fieldSize: 5000, parts: 6,
  } }).single('image');
  function validate(req, kind) {
    if (!validKey(req.headers['idempotency-key'])) throw new ApiError(400, 'IDEMPOTENCY_REQUIRED', 'Нужен корректный ключ запроса.');
    const allowed = kind === 'room' ? ['prompt', 'style', 'projectId', 'userId'] : ['projectId', 'userId'];
    if (Object.keys(req.body || {}).some(key => !allowed.includes(key)) || Object.values(req.body || {}).some(value => typeof value !== 'string')) {
      throw new ApiError(400, 'INVALID_FIELDS', 'Недопустимые поля запроса.');
    }
    if (req.body.userId && req.body.userId !== req.uid) throw new ApiError(403, 'USER_MISMATCH', 'Недопустимый пользователь запроса.');
    const projectId = req.body.projectId;
    if ((kind === 'room' || projectId !== undefined) && !validProject(projectId)) throw new ApiError(400, 'PROJECT_REQUIRED', 'Сначала создайте или откройте проект.');
    const prompt = req.body.prompt || '';
    const style = req.body.style || '';
    if (prompt.length > 4000 || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(prompt) || !styles.has(style)) throw new ApiError(400, 'INVALID_PROMPT', 'Проверьте стиль и текст пожеланий (до 4000 символов).');
    return { projectId: projectId || null, prompt: prompt.trim(), style };
  }
  for (const [path, kind] of [['/generate-room', 'room'], ['/remove-background', 'background']]) {
    app.post(path, authenticate, enabled, admitUpload, upload, async (req, res) => {
      const { projectId, prompt, style } = validate(req, kind);
      await ledger.checkProject(req.uid, projectId);
      if (imageJobs >= 2) throw new ApiError(503, 'IMAGE_BUSY', 'Обработка фотографий занята. Повторите позже.', 5);
      let image;
      imageJobs++;
      try { image = await inputImage(req.file, kind); } finally { imageJobs--; }
      if (res.writableEnded || res.destroyed) return;
      const fingerprint = createHash('sha256').update(JSON.stringify({ kind, projectId, prompt, style, image })).digest('hex');
      const { created, operation } = await ledger.reserve({ uid: req.uid, key: req.headers['idempotency-key'], fingerprint, kind, projectId });
      if (res.writableEnded || res.destroyed) return;
      if (created) worker.start(operation, { image, prompt, style });
      else if (operation.predictionId && !terminal(operation.status)) worker.start(operation);
      res.status(terminal(operation.status) || operation.status === 'requires_review' ? 200 : 202).json(publicOperation(operation));
    });
  }
  app.get('/operations/:key', authenticate, async (req, res) => {
    if (!validKey(req.params.key)) throw new ApiError(400, 'INVALID_OPERATION', 'Некорректный ID запроса.');
    const op = await ledger.get(req.uid, req.params.key);
    if (!op) throw new ApiError(404, 'OPERATION_NOT_FOUND', 'Запрос не найден.');
    await ledger.checkProject(req.uid, op.projectId);
    if (res.writableEnded || res.destroyed) return;
    if ((config.enabled || config.token) && op.predictionId && !terminal(op.status)) worker.start(op); // Read/cancel recovery only; never creates another prediction.
    const status = !op.predictionId && Date.now() - op.createdAtMs > config.predictionMs && !terminal(op.status)
      ? { ...op, status: 'requires_review', error: { code: 'REVIEW_REQUIRED', message: 'Запрос требует проверки администратором. Повторная отправка в AI заблокирована.' } } : op;
    res.json(publicOperation(status));
  });
  app.use((_, __, next) => next(new ApiError(404, 'NOT_FOUND', 'Ресурс не найден.')));
  app.use((error, req, res, _) => {
    if (res.headersSent || res.destroyed) return;
    const known = error instanceof ApiError;
    const uploadError = error instanceof multer.MulterError;
    const status = known ? error.status : uploadError ? 400 : 503;
    const code = known ? error.code : uploadError ? 'INVALID_UPLOAD' : 'SERVICE_UNAVAILABLE';
    if (error.retryAfter) res.set('Retry-After', String(error.retryAfter));
    logger({ event: 'request_rejected', requestId: req.requestId, code, status });
    res.status(status).json({ code, error: known ? error.message : uploadError ? 'Загрузите один JPG или PNG не больше 10 МБ.' : 'Сервис временно недоступен. Повторите тот же запрос позже.', requestId: req.requestId });
  });
  return { app, worker };
}
module.exports = { createApp, publicOperation };
