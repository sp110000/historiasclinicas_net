{{flutter_js}}
{{flutter_build_config}}

// Sin CDN en ejecución: CanvasKit (--no-web-resources-cdn) y las fuentes de
// respaldo del motor (Roboto) se sirven desde el propio sitio.
const configuracion = { fontFallbackBaseUrl: 'fonts/' };

// Service worker (sw.js, lo genera tool/construir_web.sh): deja la app
// guardada en el navegador para usarla sin conexión. Solo en la versión
// compilada; con `flutter run` no se registra.
const usarServiceWorker =
  'serviceWorker' in navigator &&
  (_flutter.buildConfig.builds || []).some(
    (b) => b.compileTarget === 'dart2js' || b.compileTarget === 'dart2wasm',
  );

// Avisos para la app (lib/core/pwa/pwa_web.dart): se escuchan desde el
// principio y se guardan hasta que la app los pide, para no perder ninguno
// mientras arranca (en equipos lentos el service worker puede terminar antes).
const avisosPwa = { pendientes: [], alAvisar: null };
window.hcAvisosPwa = avisosPwa;
function avisar(tipo) {
  if (avisosPwa.alAvisar) avisosPwa.alAvisar(tipo);
  else avisosPwa.pendientes.push(tipo);
}

if (usarServiceWorker) {
  // Si al abrir ya había un service worker, uno nuevo es una versión nueva;
  // si no, es la primera instalación.
  const habiaControlador = navigator.serviceWorker.controller !== null;
  navigator.serviceWorker.addEventListener('message', (e) => {
    if (e.data?.tipo === 'lista' && e.data.completa && !habiaControlador) {
      avisar('listaSinConexion');
    }
  });
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (habiaControlador) avisar('versionNueva');
  });
  navigator.serviceWorker
    .register('sw.js', { updateViaCache: 'none' })
    .catch((e) => console.warn('La app no quedará disponible sin conexión:', e));
}

// La primera vez la página carga antes de que el service worker la controle:
// se le avisa qué archivos usó (la variante del motor de este navegador) para
// que también los guarde.
function informarArchivosUsados() {
  if (!usarServiceWorker) return;
  navigator.serviceWorker.ready.then((registro) => {
    const urls = performance
      .getEntriesByType('resource')
      .map((e) => e.name)
      .filter((u) => u.startsWith(location.origin));
    registro.active?.postMessage({ tipo: 'guardarUsados', urls });
  });
}

_flutter.loader.load({
  config: configuracion,
  onEntrypointLoaded: async (motor) => {
    const app = await motor.initializeEngine(configuracion);
    await app.runApp();
    informarArchivosUsados();
  },
});
