import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Fuentes Inter empaquetadas con la app: los PDF no dependen de la red ni
/// de las fuentes instaladas en el equipo.
class FuentesPdf {
  FuentesPdf._(this.regular, this.media, this.seminegrita, this.negrita);

  final pw.Font regular;
  final pw.Font media;
  final pw.Font seminegrita;
  final pw.Font negrita;

  static FuentesPdf? _listas;
  static Future<FuentesPdf>? _cargando;

  /// Carga (una sola vez) las fuentes. Se llama al iniciar la app para que
  /// estén en memoria antes de que el usuario pierda la conexión. Si falla,
  /// el siguiente intento vuelve a cargarlas.
  ///
  /// Ya cargadas, cada llamada recibe un `Future` nuevo: un `Future`
  /// guardado queda ligado a la zona donde se creó (importa en los tests).
  static Future<FuentesPdf> cargar() {
    final listas = _listas;
    if (listas != null) return Future.value(listas);
    return _cargando ??= _cargar().then(
      (fuentes) {
        _listas = fuentes;
        _cargando = null;
        return fuentes;
      },
      onError: (Object error, StackTrace pila) {
        _cargando = null;
        Error.throwWithStackTrace(error, pila);
      },
    );
  }

  static Future<FuentesPdf> _cargar() async {
    Future<pw.Font> fuente(String peso) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-$peso.ttf'));
    return FuentesPdf._(
      await fuente('Regular'),
      await fuente('Medium'),
      await fuente('SemiBold'),
      await fuente('Bold'),
    );
  }

  pw.ThemeData get tema => pw.ThemeData.withFont(base: regular, bold: negrita);
}
