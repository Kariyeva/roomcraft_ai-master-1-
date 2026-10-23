class ApiError extends Error {
  constructor(status, code, message, retryAfter) {
    super(message);
    this.status = status;
    this.code = code;
    this.retryAfter = retryAfter;
  }
}
const terminal = (status) => ['succeeded', 'failed', 'canceled'].includes(status);
module.exports = { ApiError, terminal };
