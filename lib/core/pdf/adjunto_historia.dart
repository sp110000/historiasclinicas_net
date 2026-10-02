import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../integridad/json_canonico.dart';

/// Nombre del archivo incrustado en cada PDF de historia.
const String nombreAdjuntoHistoria = 'historia.json';

/// Identifica los datos generados por esta aplicación.
const String identificadorApp = 'historiasclinicas.net';

/// Versión del esquema que escribe esta versión de la app.
const int schemaVersionActual = 1;

/// Envoltura de los datos estructurados que viajan dentro del PDF.
///
/// `datos` es el contenido de la historia (paciente, secciones, evoluciones).
/// `sha256` es el hash del JSON canónico de `datos` y permite detectar
/// adjuntos dañados o truncados.
class PaqueteHistoria {
  PaqueteHistoria({
    required this.revision,
    required this.guardadoEn,
    required this.datos,
    this.schemaVersion = schemaVersionActual,
  });

  /// Interpreta un mapa ya decodificado. No valida el hash: de eso se
  /// encarga el lector.
  factory PaqueteHistoria.desdeMapa(Map<String, Object?> mapa) {
    return PaqueteHistoria(
      schemaVersion: mapa['schemaVersion']! as int,
      revision: mapa['revision']! as int,
      guardadoEn: DateTime.parse(mapa['guardadoEn']! as String),
      datos: (mapa['datos']! as Map).cast<String, Object?>(),
    );
  }

  final int schemaVersion;

  /// Número de guardados de la historia: 1 al finalizarla y +1 en cada
  /// descarga de una versión actualizada.
  final int revision;
  final DateTime guardadoEn;
  final Map<String, Object?> datos;

  String get hashDatos => sha256Canonico(datos);

  Map<String, Object?> aMapa() => {
    'app': identificadorApp,
    'schemaVersion': schemaVersion,
    'revision': revision,
    'guardadoEn': guardadoEn.toUtc().toIso8601String(),
    'datos': datos,
    'sha256': hashDatos,
  };

  /// JSON canónico (solo ASCII) tal como se incrusta en el PDF.
  String aJson() => jsonCanonico(aMapa());
}

/// Incrusta [paquete] como `historia.json` en [documento].
///
/// Usa el mecanismo estándar de archivos incrustados (`/EmbeddedFiles` y
/// `/AF`), visible en el panel de adjuntos de Acrobat y otros visores.
/// Debe llamarse antes de `documento.save()`.
void incrustarHistoria(pw.Document documento, PaqueteHistoria paquete) {
  PdfaAttachedFiles(documento.document, [
    PdfaAttachedFile(
      name: nombreAdjuntoHistoria,
      // Solo ASCII: el paquete `pdf` declara /Size contando caracteres, que
      // así coincide con los bytes escritos.
      data: paquete.aJson(),
      subType: '/application/json',
      // Nombre del parámetro en pdf 3.12 (Flutter 3.38); en 3.13+ pasa a
      // llamarse `afRelationship`.
      AFRelationship: '/Data',
    ),
  ]);
}
