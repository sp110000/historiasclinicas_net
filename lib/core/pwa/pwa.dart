/// Comunicación con el service worker: en la web, los avisos reales; en los
/// tests, ninguno.
library;

export 'pwa_stub.dart' if (dart.library.js_interop) 'pwa_web.dart';
