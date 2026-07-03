// ── Service Worker : Web Push Notifications + fallback hors-ligne ─────────────
// Ce fichier est injecté dans flutter_service_worker.js par les DEUX pipelines :
//   - Jenkinsfile (famille domaine)
//   - build_and_push.sh (famille IP-only)
// Le pipeline patche également le handler activate de Flutter (qui appelle
// unregister() par défaut) pour que le SW reste actif : push ET page offline
// en dépendent. Ne pas renommer ce fichier (référencé par les deux pipelines).

// Prend le contrôle de tous les clients existants dès l'activation
self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim());
});

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

// ── Page hors-ligne : précache + fallback de navigation ───────────────────────
// Depuis Flutter ~3.35, flutter_service_worker.js n'est plus qu'un stub sans
// cache (plus de map RESOURCES ni de handler fetch) : c'est donc CE fichier
// qui précache offline.html (autonome : CSS + icône SVG inline) et le sert
// quand une navigation échoue faute de réseau.
const OFFLINE_CACHE = 'kabutare-offline-v1';

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(OFFLINE_CACHE).then((cache) => cache.addAll(['offline.html']))
  );
});

// try/catch : si un autre handler fetch (ancien SW Flutter avec cache) a déjà
// répondu, notre respondWith lèverait une InvalidStateError — on l'ignore.
self.addEventListener('fetch', (event) => {
  if (event.request.mode !== 'navigate') return;
  try {
    event.respondWith(
      fetch(event.request).catch(() => caches.match('offline.html'))
    );
  } catch (_) { /* navigation déjà servie par un autre handler — ignorer */ }
});
