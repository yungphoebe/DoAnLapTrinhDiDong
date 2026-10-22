globalThis.gymNotifications = (() => {
  let registrationPromise;
  async function registration() {
    if (!('serviceWorker' in navigator) || !('PushManager' in window) || !isSecureContext)
      throw new Error('Trình duyệt cần HTTPS hoặc localhost để nhận thông báo.');
    if (!registrationPromise) registrationPromise = (async () => {
      const reg = await navigator.serviceWorker.register('notification-worker.js', {scope: './notification-push/'});
      if (!reg.active) await new Promise((resolve, reject) => {
        const worker = reg.installing || reg.waiting;
        if (!worker) return reject(new Error('Không thể khởi tạo thông báo.'));
        const timer = setTimeout(() => reject(new Error('Khởi tạo thông báo quá hạn.')), 15000);
        worker.addEventListener('statechange', () => {
          if (worker.state === 'activated') {clearTimeout(timer); resolve();}
          if (worker.state === 'redundant') {clearTimeout(timer); reject(new Error('Không thể khởi tạo thông báo.'));}
        });
      });
      return reg;
    })().catch(error => {registrationPromise = null; throw error;});
    return registrationPromise;
  }
  return {
    init(callback) {
      navigator.serviceWorker?.addEventListener('message', event => {
        if (event.data?.type === 'aigym-notification') callback(JSON.stringify(event.data.link));
      });
    },
    timezone() { return Intl.DateTimeFormat().resolvedOptions().timeZone; },
    async permission(request) {
      if (!('Notification' in window)) return 'unsupported';
      return request ? Notification.requestPermission() : Notification.permission;
    },
    async activate(owner, publicKey) {
      const reg = await registration();
      const previous = await gymNotificationStore.read();
      const sessionId = previous?.owner === owner ? previous.sessionId : crypto.randomUUID();
      const encoded = publicKey.replace(/-/g, '+').replace(/_/g, '/');
      const bytes = Uint8Array.from(atob(encoded.padEnd(Math.ceil(encoded.length / 4) * 4, '=')), c => c.charCodeAt(0));
      const subscription = await reg.pushManager.getSubscription() || await reg.pushManager.subscribe({userVisibleOnly: true, applicationServerKey: bytes});
      await gymNotificationStore.write({owner, sessionId, enabled: previous?.owner === owner ? previous.enabled : {}});
      const json = subscription.toJSON();
      return JSON.stringify({endpoint: json.endpoint, p256dh: json.keys.p256dh, auth: json.keys.auth, sessionId});
    },
    async apply(owner, value) {
      const state = await gymNotificationStore.read();
      if (state?.owner !== owner) return;
      const settings = JSON.parse(value);
      await gymNotificationStore.write({...state, enabled: {workout: settings.workoutEnabled, water: settings.waterEnabled, weekly: settings.weeklyEnabled}});
      if (!settings.workoutEnabled || !settings.waterEnabled || !settings.weeklyEnabled) {
        const reg = await registration();
        for (const notification of await reg.getNotifications())
          if (!settings[`${notification.data?.kind}Enabled`]) notification.close();
      }
    },
    async deactivate() {
      await gymNotificationStore.write(null);
      const reg = registrationPromise ? await registration() : await navigator.serviceWorker?.getRegistration(new URL('notification-push/', document.baseURI));
      if (!reg) return null;
      for (const notification of await reg.getNotifications()) notification.close();
      const subscription = await reg.pushManager.getSubscription();
      const endpoint = subscription?.endpoint;
      if (subscription) await subscription.unsubscribe();
      return endpoint || null;
    }
  };
})();
