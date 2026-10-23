// Test double only. Production uses Firebase Admin transactions exclusively.
class FakeFirestore {
  constructor() { this.documents = new Map(); this.queue = Promise.resolve(); }
  ref(path) {
    const db = this;
    return { path, doc: id => db.ref(`${path}/${id}`), collection: name => db.ref(`${path}/${name}`),
      get: async () => db.snapshot(path) };
  }
  collection(name) { return this.ref(name); }
  snapshot(path) {
    const value = this.documents.get(path);
    return { exists: value !== undefined, data: () => value === undefined ? undefined : structuredClone(value) };
  }
  seed(path, data) { this.documents.set(path, structuredClone(data)); }
  async runTransaction(callback) {
    const transaction = this.queue.then(async () => {
      const writes = [];
      const result = await callback({
        get: async ref => { if (writes.length) throw new Error('Read after write'); return this.snapshot(ref.path); },
        set: (ref, value) => writes.push(() => this.seed(ref.path, value)),
        update: (ref, value) => writes.push(() => {
          if (!this.documents.has(ref.path)) throw new Error('Missing document');
          this.seed(ref.path, { ...this.documents.get(ref.path), ...value });
        }),
      });
      for (const write of writes) write();
      return result;
    });
    this.queue = transaction.catch(() => {});
    return transaction;
  }
}
module.exports = { FakeFirestore };
