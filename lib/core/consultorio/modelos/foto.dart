import '../../models/mapa.dart';

/// Vistas de las fotos (pregunta 19), en el orden de la secuencia.
enum VistaFoto {
  frontal('Frontal'),
  lateralDerecha('Lateral derecha'),
  lateralIzquierda('Lateral izquierda'),
  posterior('Posterior'),
  detalle('Detalle de zona');

  const VistaFoto(this.etiqueta);

  final String etiqueta;
}

/// Una foto clínica: el JPEG y su miniatura van cifrados en binarios.
class Foto {
  const Foto({
    required this.id,
    required this.pacienteId,
    required this.fecha,
    required this.vista,
    required this.ancho,
    required this.alto,
    required this.sha256,
    required this.consentimientoId,
    required this.creado,
    this.zona = '',
    this.notas = '',
  });

  static const coleccion = 'fotos';
  static const tipoBinario = 'foto';
  static const tipoMiniatura = 'miniatura';

  final String id;
  final String pacienteId;
  final DateTime fecha;
  final VistaFoto vista;

  /// Para la vista «detalle»: «abdomen», «flanco derecho»…
  final String zona;
  final int ancho;
  final int alto;

  /// SHA-256 del JPEG guardado (sin metadatos).
  final String sha256;

  /// Consentimiento de imagen con el que se tomó.
  final String consentimientoId;
  final String notas;
  final DateTime creado;

  String get titulo => vista == VistaFoto.detalle && zona.trim().isNotEmpty
      ? 'Detalle: ${zona.trim()}'
      : vista.etiqueta;

  Foto copyWith({String? pacienteId}) =>
      Foto.desdeMapa(id, {...aMapa(), 'pacienteId': ?pacienteId});

  Map<String, Object?> aMapa() => compacto({
    'pacienteId': pacienteId,
    'fecha': fechaHoraIso(fecha),
    'vista': vista.name,
    'zona': zona,
    'ancho': ancho,
    'alto': alto,
    'sha256': sha256,
    'consentimientoId': consentimientoId,
    'notas': notas,
    'creado': creado.toUtc().toIso8601String(),
  });

  static Foto desdeMapa(String id, Map<String, Object?> m) => Foto(
    id: id,
    pacienteId: m.texto('pacienteId'),
    fecha: m.fecha('fecha')!,
    vista: VistaFoto.values.byName(m.texto('vista')),
    zona: m.texto('zona'),
    ancho: m.entero('ancho') ?? 0,
    alto: m.entero('alto') ?? 0,
    sha256: m.texto('sha256'),
    consentimientoId: m.texto('consentimientoId'),
    notas: m.texto('notas'),
    creado: DateTime.parse(m['creado']! as String).toLocal(),
  );
}
