// historiasclinicas.net: service worker.
//
// Lo genera `tool/pwa/generar_service_worker.dart` después de
// `flutter build web` (ver tool/construir_web.sh). No editar build/web/sw.js.
//
// Guarda la app completa en este navegador para que funcione sin conexión:
// - Al instalarse descarga todos los archivos de la lista (con su huella
//   SHA-256). Si un archivo no cambió desde la versión anterior, lo reutiliza.
// - El motor gráfico (canvaskit) tiene varias variantes según el navegador;
//   se guarda la que la página usó de verdad.
// - Una versión nueva se instala en segundo plano y la app ofrece recargar.
'use strict';

const VERSION = '__VERSION__';
const MOTOR = '__MOTOR__';
/** Ruta → huella: se descargan al instalar. */
const ARCHIVOS = __ARCHIVOS__;
/** Ruta → huella: variantes del motor, se guardan cuando se usan. */
const ARCHIVOS_MOTOR = __ARCHIVOS_MOTOR__;

const CACHE_APP = `hc-app-${VERSION}`;
const CACHE_MOTOR = `hc-motor-${MOTOR}`;
const CABECERA_HUELLA = 'x-hc-huella';

const absoluta = (ruta) => new URL(ruta, self.registration.scope).href;
/** Ruta dentro del sitio, sin "?…" ("" es index.html); null si es de fuera. */
const relativa = (url) => {
  const u = new URL(url);
  const alcance = new URL(self.registration.scope);
  if (u.origin !== alcance.origin || !u.pathname.startsWith(alcance.pathname)) {
    return null;
  }
  return u.pathname.substring(alcance.pathname.length) || 'index.html';
};
const huellaDe = (ruta) => ARCHIVOS[ruta] ?? ARCHIVOS_MOTOR[ruta] ?? null;
const cacheDe = (ruta) => (ruta in ARCHIVOS_MOTOR ? CACHE_MOTOR : CACHE_APP);

async function sha256(buffer) {
  const digest = await crypto.subtle.digest('SHA-256', buffer);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Descarga [ruta] sin pasar por la caché HTTP y comprueba su huella: un
 * proxy o un CDN con archivos viejos no debe mezclar versiones.
 */
async function descargar(ruta) {
  const esperada = huellaDe(ruta);
  for (const sufijo of ['', `?v=${esperada}`]) {
    const respuesta = await fetch(new Request(absoluta(ruta) + sufijo, { cache: 'reload' }));
    if (!respuesta.ok) throw new Error(`${ruta}: HTTP ${respuesta.status}`);
    const cuerpo = await respuesta.arrayBuffer();
    if (esperada === null || (await sha256(cuerpo)).startsWith(esperada)) {
      const cabeceras = new Headers(respuesta.headers);
      if (esperada) cabeceras.set(CABECERA_HUELLA, esperada);
      return new Response(cuerpo, {
        status: respuesta.status,
        statusText: respuesta.statusText,
        headers: cabeceras,
      });
    }
  }
  throw new Error(`${ruta}: el servidor entregó otra versión del archivo`);
}

/** Copia de [ruta] con la misma huella en alguna caché anterior. */
async function reutilizable(ruta, anteriores) {
  const esperada = huellaDe(ruta);
  for (const nombre of anteriores) {
    const r = await (await caches.open(nombre)).match(absoluta(ruta));
    if (r && r.headers.get(CABECERA_HUELLA) === esperada) return r;
  }
  return null;
}

async function guardar(ruta, anteriores = []) {
  const cache = await caches.open(cacheDe(ruta));
  if (await cache.match(absoluta(ruta))) return;
  const respuesta = (await reutilizable(ruta, anteriores)) ?? (await descargar(ruta));
  await cache.put(absoluta(ruta), respuesta);
}

/** De a pocos, para no saturar conexiones lentas. */
async function enLotes(rutas, accion, tamano = 6) {
  for (let i = 0; i < rutas.length; i += tamano) {
    await Promise.all(rutas.slice(i, i + tamano).map(accion));
  }
}

self.addEventListener('install', (evento) => {
  evento.waitUntil(
    (async () => {
      const nombres = await caches.keys();
      const anteriores = nombres.filter((n) => n.startsWith('hc-') && n !== CACHE_APP);
      // Si el motor cambió (otra versión de Flutter), vuelve a descargar las
      // mismas variantes que este navegador ya usaba.
      const motor = [];
      for (const nombre of nombres.filter((n) => n.startsWith('hc-motor-'))) {
        for (const pedido of await (await caches.open(nombre)).keys()) {
          const ruta = relativa(pedido.url);
          if (ruta in ARCHIVOS_MOTOR && !motor.includes(ruta)) motor.push(ruta);
        }
      }
      await enLotes([...Object.keys(ARCHIVOS), ...motor], (ruta) => guardar(ruta, anteriores));
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (evento) => {
  evento.waitUntil(
    (async () => {
      for (const nombre of await caches.keys()) {
        if (nombre.startsWith('hc-') && nombre !== CACHE_APP && nombre !== CACHE_MOTOR) {
          await caches.delete(nombre);
        }
      }
      await self.clients.claim();
    })(),
  );
});

async function responder(pedido, ruta) {
  const enCache = await caches.match(absoluta(ruta), { ignoreVary: true });
  if (enCache) return enCache;
  const respuesta = await fetch(pedido);
  // Lo que no estaba en la lista (variantes del motor) queda guardado.
  if (respuesta.ok && respuesta.type === 'basic') {
    const copia = respuesta.clone();
    caches.open(cacheDe(ruta)).then((c) => c.put(absoluta(ruta), copia));
  }
  return respuesta;
}

self.addEventListener('fetch', (evento) => {
  const pedido = evento.request;
  if (pedido.method !== 'GET') return;
  const ruta = relativa(pedido.url);
  // De otro sitio o que no es de la app (sw.js, …): no se toca.
  if (ruta === null || huellaDe(ruta) === null) return;
  evento.respondWith(responder(pedido, ruta));
});

// La página avisa qué archivos usó al cargar (la primera vez carga antes de
// que este service worker la controle) y recibe "lista" cuando todo quedó
// guardado.
self.addEventListener('message', (evento) => {
  const datos = evento.data ?? {};
  if (datos.tipo !== 'guardarUsados') return;
  evento.waitUntil(
    (async () => {
      let completa = true;
      for (const url of datos.urls ?? []) {
        const ruta = relativa(url);
        if (ruta === null || huellaDe(ruta) === null) continue;
        try {
          await guardar(ruta);
        } catch (e) {
          completa = false;
        }
      }
      for (const ruta of Object.keys(ARCHIVOS)) {
        if (!(await caches.match(absoluta(ruta)))) completa = false;
      }
      evento.source?.postMessage({ tipo: 'lista', version: VERSION, completa });
    })(),
  );
});
