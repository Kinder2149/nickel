// NICKEL V2 — service worker (même stratégie que la V1, voir public/sw.js)
// Réseau d'abord, cache en secours — pour ne jamais bloquer une mise à jour déployée.

const CACHE = 'nickel-v2-secours-v1';

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys()
      .then(function (noms) {
        return Promise.all(
          noms.filter(function (n) { return n !== CACHE; })
              .map(function (n) { return caches.delete(n); })
        );
      })
      .then(function () { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function (event) {
  if (event.request.method !== 'GET') return;

  event.respondWith(
    fetch(event.request)
      .then(function (reponse) {
        const copie = reponse.clone();
        caches.open(CACHE).then(function (cache) {
          cache.put(event.request, copie);
        });
        return reponse;
      })
      .catch(function () {
        return caches.match(event.request).then(function (enCache) {
          return enCache || caches.match('/v2/');
        });
      })
  );
});
