// NICKEL — service worker
//
// Deux raisons d'être :
//  1. Chrome n'autorise l'installation sur l'écran d'accueil que si un
//     service worker est enregistré et intercepte les requêtes réseau.
//  2. L'app doit afficher quelque chose même sans réseau, sinon Chrome
//     peut refuser de proposer l'installation.
//
// Stratégie : RÉSEAU D'ABORD, cache en secours.
// C'est délibéré. La stratégie inverse (cache d'abord) provoque le pire
// symptôme possible sur un pilote : une mise à jour déployée que les
// téléphones continuent d'ignorer sans qu'on comprenne pourquoi.
//
// Le mode hors connexion des DONNÉES est assuré par Firestore
// (cache local natif), pas par ce fichier. Voir PROJET_CONTEXTE.md § 5.

const CACHE = 'nickel-secours-v1';

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
        // Réseau OK : on sert la version fraîche et on garde une copie
        // uniquement comme filet de sécurité hors connexion.
        const copie = reponse.clone();
        caches.open(CACHE).then(function (cache) {
          cache.put(event.request, copie);
        });
        return reponse;
      })
      .catch(function () {
        // Pas de réseau : on ressort la dernière version connue.
        return caches.match(event.request).then(function (enCache) {
          return enCache || caches.match('/');
        });
      })
  );
});
