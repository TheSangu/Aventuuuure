/*
 * Service worker — Destination Mystère
 * Stratégie : cache-first sur l'app shell pour un fonctionnement 100 % hors-ligne.
 * Aucun backend, aucune donnée envoyée sur le réseau.
 *
 * Pour publier une mise à jour : incrémenter CACHE_VERSION ci-dessous.
 * L'ancien cache est alors purgé lors de l'activation du nouveau worker.
 */

const CACHE_VERSION = 'v1';
const CACHE_NAME = `destination-mystere-${CACHE_VERSION}`;

// App shell : tout ce qu'il faut pour démarrer l'app sans réseau.
// Chemins relatifs pour rester compatible avec GitHub Pages (sous-dossier /repo/).
const APP_SHELL = [
  './',
  './index.html',
  './css/styles.css',
  './js/app.js',
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/icon-512-maskable.png'
];

// Installation : on précharge l'app shell.
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
  );
  // Active immédiatement le nouveau worker sans attendre la fermeture des onglets.
  self.skipWaiting();
});

// Activation : on supprime les anciens caches de versions précédentes.
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key.startsWith('destination-mystere-') && key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

// Récupération : cache-first.
// 1) On sert depuis le cache si présent.
// 2) Sinon on tente le réseau et on met en cache la réponse pour la prochaine fois.
// 3) En dernier recours hors-ligne, on renvoie index.html pour les navigations.
self.addEventListener('fetch', (event) => {
  const request = event.request;

  // On ne gère que les requêtes GET de même origine.
  if (request.method !== 'GET') return;
  if (new URL(request.url).origin !== self.location.origin) return;

  event.respondWith(
    caches.match(request).then((cached) => {
      if (cached) return cached;

      return fetch(request)
        .then((response) => {
          // Met en cache les réponses valides pour le hors-ligne futur.
          if (response && response.status === 200 && response.type === 'basic') {
            const copy = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, copy));
          }
          return response;
        })
        .catch(() => {
          // Hors-ligne et ressource non cachée : on retombe sur l'app shell.
          if (request.mode === 'navigate') {
            return caches.match('./index.html');
          }
          return new Response('', { status: 504, statusText: 'Hors-ligne' });
        });
    })
  );
});
