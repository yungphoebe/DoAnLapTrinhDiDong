importScripts('notification-store.js');
self.addEventListener('push', event => {
  event.waitUntil((async () => {
    let payload;
    try { payload = event.data.json(); } catch (_) { return; }
    const state = await gymNotificationStore.read();
    if (!state || !state.owner || state.sessionId !== payload.sessionId || !state.enabled?.[payload.kind]) return;
    if (!['workout', 'water', 'weekly'].includes(payload.kind)) return;
    await self.registration.showNotification(payload.title, {
      body: payload.body, tag: `aigym-${payload.id}`, icon: '../icons/Icon-192.png',
      data: { owner: state.owner, kind: payload.kind, id: payload.id, at: payload.scheduledAtUtc }
    });
  })());
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const link = event.notification.data;
    const state = await gymNotificationStore.read();
    if (!link || state?.owner !== link.owner) return;
    const base = new URL('../', self.registration.scope);
    const windows = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    const existing = windows.find(client => new URL(client.url).origin === base.origin && client.url.startsWith(base.href));
    if (existing) {
      await existing.focus();
      existing.postMessage({type: 'aigym-notification', link});
    } else {
      base.hash = `/notification-open?${new URLSearchParams(link)}`;
      await self.clients.openWindow(base.href);
    }
  })());
});
