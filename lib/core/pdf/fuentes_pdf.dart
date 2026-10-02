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

  static Future<FuentesPdf>? _cargando;

  /// Carga (una sola vez) las fuentes. Se llama al iniciar la app para que
  /// estén en memoria antes de que el usuario pierda la conexión. Si falla,
  /// el siguiente intento vuelve a cargarlas.
  static Future<FuentesPdf> cargar() => _cargando ??= _cargar().then(
    (fuentes) => fuentes,
    onError: (Object error, StackTrace pila) {
      _cargando = null;
      Error.throwWithStackTrace(error, pila);
    },
  );

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
