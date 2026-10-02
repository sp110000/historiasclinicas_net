/// Abrir, guardar y soltar archivos en el navegador.
///
/// En la VM (tests) se usa una implementación vacía.
library;

export 'archivo.dart';
export 'archivos_stub.dart' if (dart.library.js_interop) 'archivos_web.dart';
