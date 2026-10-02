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

if (usarServiceWorker) {
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
