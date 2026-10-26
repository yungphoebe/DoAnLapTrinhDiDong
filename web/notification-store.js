/* Shared by the page and its push worker. Contains no JWT or private key. */
globalThis.gymNotificationStore = {
  async database() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('aigym-notifications', 1);
      request.onupgradeneeded = () => request.result.createObjectStore('state');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  },
  async read() {
    const db = await this.database();
    try { return await new Promise((resolve, reject) => {
      const request = db.transaction('state').objectStore('state').get('active');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    }); } finally { db.close(); }
  },
  async write(value) {
    const db = await this.database();
    try { await new Promise((resolve, reject) => {
      const tx = db.transaction('state', 'readwrite');
      tx.objectStore('state').put(value, 'active');
      tx.oncomplete = resolve; tx.onerror = () => reject(tx.error);
    }); } finally { db.close(); }
  }
};
