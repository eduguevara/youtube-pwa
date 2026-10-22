// Service worker mínimo: cachea el "lanzador" para que la app arranque sin el PC encendido.
// No intercepta nada de youtube.com (otro origen); solo los ficheros de esta carpeta.
const CACHE = 'yt-launcher-v1';
const ASSETS = [
  './',
  './index.html',
  './manifest.json',
  './icons/icon.svg',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/icon-maskable-512.png',
  './icons/apple-touch-icon.png'
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (url.origin !== self.location.origin) return;
  // Cache-first: el servidor del PC ya no existirá tras la instalación.
  e.respondWith(
    caches.match(e.request, { ignoreSearch: true }).then((hit) => hit || fetch(e.request))
  );
});
