/// Dónde se guarda el catálogo CIE-10 importado: IndexedDB en la web (cabe
/// incluso la CIE-10-ES completa) y memoria en los tests.
library;

export 'almacen_cie10_memoria.dart'
    if (dart.library.js_interop) 'almacen_cie10_web.dart';
