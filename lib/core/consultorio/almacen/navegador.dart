/// Lo que el consultorio pide al navegador: almacenamiento persistente,
/// espacio usado y un candado para que una sola pestaña escriba a la vez.
/// En la VM (pruebas) todo responde como si estuviera concedido.
library;

export 'navegador_stub.dart' if (dart.library.js_interop) 'navegador_web.dart';

/// Espacio usado y disponible para este sitio, en bytes.
class EspacioAlmacen {
  const EspacioAlmacen({required this.usado, required this.cuota});

  final int usado;
  final int cuota;
}

/// Candado entre pestañas. [tomar] devuelve `false` si otra pestaña ya lo
/// tiene; quien lo tiene lo conserva hasta [soltar] o hasta cerrar la
/// pestaña.
abstract interface class CandadoPestanas {
  Future<bool> tomar();

  void soltar();
}
