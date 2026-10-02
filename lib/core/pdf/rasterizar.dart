/// Dibuja las páginas de un PDF como PNG: en la web con pdf.js (servido desde
/// el propio sitio, sin eval); en otras plataformas con `printing`.
library;

export 'rasterizar_otras.dart'
    if (dart.library.js_interop) 'rasterizar_web.dart';
