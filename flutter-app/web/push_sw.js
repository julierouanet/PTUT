// ── Service Worker : Web Push Notifications ───────────────────────────────────
// Ce fichier est enregistré séparément du service worker Flutter (flutter_service_worker.js).
// Il gère uniquement la réception et l'affichage des notifications push.

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { title: 'Kabutare Hospital', body: event.data ? event.data.text() : '' };
  }

  event.waitUntil(
    self.registration.showNotification(data.title || 'Kabutare Hospital', {
      body:  data.body  || '',
      icon:  data.icon  || '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      data:  data.data  || {},
      requireInteraction: false,
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const issueId = event.notification.data?.issueId;
  const url = issueId ? `/?issue=${issueId}` : '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      return clients.openWindow(url);
    })
  );
});
