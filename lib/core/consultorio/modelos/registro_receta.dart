import '../../models/mapa.dart';

const nombreAdjuntoReceta = 'receta.json';

/// Receta emitida con el consultorio encendido: su resumen en el índice y
/// su PDF exacto (con `receta.json` incrustado).
class RegistroReceta {
  const RegistroReceta({
    required this.id,
    required this.pacienteId,
    required this.fecha,
    required this.actualizado,
    this.numero,
    this.historiaId = '',
    this.items = const [],
    this.indicaciones = '',
    this.sha256Pdf = '',
    this.nombreArchivo = '',
    this.tienePdf = false,
  });

  static const coleccion = 'recetas';
  static const tipoBinarioPdf = 'pdfreceta';

  /// El `id` de la receta (una receta reimpresa no se duplica).
  final String id;
  final String pacienteId;
  final DateTime fecha;
  final String? numero;
  final String historiaId;

  /// Una línea por medicamento («METFORMINA 850 mg · 1 tableta …»).
  final List<String> items;
  final String indicaciones;
  final String sha256Pdf;
  final String nombreArchivo;
  final bool tienePdf;
  final DateTime actualizado;

  RegistroReceta copyWith({String? pacienteId}) => RegistroReceta(
    id: id,
    pacienteId: pacienteId ?? this.pacienteId,
    fecha: fecha,
    actualizado: actualizado,
    numero: numero,
    historiaId: historiaId,
    items: items,
    indicaciones: indicaciones,
    sha256Pdf: sha256Pdf,
    nombreArchivo: nombreArchivo,
    tienePdf: tienePdf,
  );

  Map<String, Object?> aMapa() => compacto({
    'pacienteId': pacienteId,
    'fecha': fechaHoraIso(fecha),
    'numero': numero,
    'historiaId': historiaId,
    'items': items.isEmpty ? null : items,
    'indicaciones': indicaciones,
    'sha256Pdf': sha256Pdf,
    'nombreArchivo': nombreArchivo,
    'tienePdf': tienePdf ? true : null,
    'actualizado': actualizado.toUtc().toIso8601String(),
  });

  static RegistroReceta desdeMapa(String id, Map<String, Object?> m) =>
      RegistroReceta(
        id: id,
        pacienteId: m.texto('pacienteId'),
        fecha: m.fecha('fecha')!,
        numero: m.textoONulo('numero'),
        historiaId: m.texto('historiaId'),
        items: [for (final i in (m['items'] as List?) ?? const []) i as String],
        indicaciones: m.texto('indicaciones'),
        sha256Pdf: m.texto('sha256Pdf'),
        nombreArchivo: m.texto('nombreArchivo'),
        tienePdf: m.booleano('tienePdf'),
        actualizado: DateTime.parse(m['actualizado']! as String).toLocal(),
      );
}
