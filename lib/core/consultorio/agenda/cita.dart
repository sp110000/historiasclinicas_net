import '../../models/mapa.dart';

/// Tipos de cita (pregunta 42), con su duración por defecto en minutos.
enum TipoCita {
  primeraVez('Primera vez', 30),
  control('Control', 20),
  programaPeso('Programa de peso', 30),
  valoracionEstetica('Valoración estética', 40),
  sesion('Sesión de procedimiento', 60),
  ecografia('Ecografía', 20);

  const TipoCita(this.etiqueta, this.duracionPorDefecto);

  final String etiqueta;
  final int duracionPorDefecto;

  /// La valoración estética y la sesión exigen mayor de edad (Ley 1799 de
  /// 2016, VERIFICAR) y llevan la plantilla del procedimiento.
  bool get estetica => this == valoracionEstetica || this == sesion;
}

enum EstadoCita {
  agendada('Agendada'),
  confirmada('Confirmada'),
  atendida('Atendida'),
  noAsistio('No asistió'),
  cancelada('Cancelada');

  const EstadoCita(this.etiqueta);

  final String etiqueta;

  /// Atendida, no asistió o cancelada: la cita ya no ocupa el horario
  /// (salvo atendida) ni espera recordatorio.
  bool get cerrada =>
      this == atendida || this == noAsistio || this == cancelada;

  /// Ocupa su espacio en el horario.
  bool get ocupa => this != cancelada && this != noAsistio;
}

/// Un cambio de estado, con su fecha (y motivo si lo hay).
class CambioEstadoCita {
  const CambioEstadoCita({
    required this.estado,
    required this.fecha,
    this.motivo = '',
  });

  final EstadoCita estado;
  final DateTime fecha;
  final String motivo;

  Map<String, Object?> aMapa() => compacto({
    'estado': estado.name,
    'fecha': fecha.toUtc().toIso8601String(),
    'motivo': motivo.trim(),
  });

  static CambioEstadoCita desdeMapa(Map<String, Object?> m) => CambioEstadoCita(
    estado: EstadoCita.values.byName(m.texto('estado')),
    fecha: DateTime.parse(m.texto('fecha')).toLocal(),
    motivo: m.texto('motivo'),
  );
}

/// Una cita de la agenda. Siempre es de una ficha: la de una primera vez se
/// crea con lo mínimo (nombre y teléfono) desde la misma cita.
class Cita {
  const Cita({
    required this.id,
    required this.pacienteId,
    required this.tipo,
    required this.inicio,
    required this.duracionMin,
    required this.creado,
    this.estado = EstadoCita.agendada,
    this.historial = const [],
    this.motivo = '',
    this.notas = '',
    this.plantillaId,
    this.recordatorioEnviado,
  });

  static const coleccion = 'citas';

  final String id;
  final String pacienteId;
  final TipoCita tipo;
  final DateTime inicio;
  final int duracionMin;
  final EstadoCita estado;

  /// Los cambios de estado, del primero al último.
  final List<CambioEstadoCita> historial;

  /// Motivo de la consulta (no va en el recordatorio ni en el `.ics`).
  final String motivo;
  final String notas;

  /// Procedimiento de una valoración estética o una sesión.
  final String? plantillaId;

  /// Cuándo se abrió el recordatorio por WhatsApp.
  final DateTime? recordatorioEnviado;
  final DateTime creado;

  DateTime get fin => inicio.add(Duration(minutes: duracionMin));

  /// Se cruza con [otra] (las dos ocupan su espacio y se solapan).
  bool cruzaCon(Cita otra) =>
      otra.id != id &&
      estado.ocupa &&
      otra.estado.ocupa &&
      inicio.isBefore(otra.fin) &&
      otra.inicio.isBefore(fin);

  Cita copyWith({
    String? pacienteId,
    TipoCita? tipo,
    DateTime? inicio,
    int? duracionMin,
    EstadoCita? estado,
    List<CambioEstadoCita>? historial,
    String? motivo,
    String? notas,
    Object? plantillaId = sin,
    Object? recordatorioEnviado = sin,
  }) => Cita(
    id: id,
    pacienteId: pacienteId ?? this.pacienteId,
    tipo: tipo ?? this.tipo,
    inicio: inicio ?? this.inicio,
    duracionMin: duracionMin ?? this.duracionMin,
    estado: estado ?? this.estado,
    historial: historial ?? this.historial,
    motivo: motivo ?? this.motivo,
    notas: notas ?? this.notas,
    plantillaId: cambio<String>(plantillaId, this.plantillaId),
    recordatorioEnviado: cambio<DateTime>(
      recordatorioEnviado,
      this.recordatorioEnviado,
    ),
    creado: creado,
  );

  Map<String, Object?> aMapa() => compacto({
    'pacienteId': pacienteId,
    'tipo': tipo.name,
    'inicio': fechaHoraIso(inicio),
    'duracionMin': duracionMin,
    'estado': estado.name,
    'historial': historial.isEmpty
        ? null
        : [for (final c in historial) c.aMapa()],
    'motivo': motivo.trim(),
    'notas': notas.trim(),
    'plantillaId': plantillaId,
    'recordatorioEnviado': recordatorioEnviado?.toUtc().toIso8601String(),
    'creado': creado.toUtc().toIso8601String(),
  });

  static Cita desdeMapa(String id, Map<String, Object?> m) => Cita(
    id: id,
    pacienteId: m.texto('pacienteId'),
    tipo: TipoCita.values.byName(m.texto('tipo')),
    inicio: m.fecha('inicio')!,
    duracionMin: m.entero('duracionMin')!,
    estado: EstadoCita.values.byName(m.texto('estado')),
    historial: [
      for (final c in m.listaMapas('historial')) CambioEstadoCita.desdeMapa(c),
    ],
    motivo: m.texto('motivo'),
    notas: m.texto('notas'),
    plantillaId: m.textoONulo('plantillaId'),
    recordatorioEnviado: m['recordatorioEnviado'] == null
        ? null
        : DateTime.parse(m.texto('recordatorioEnviado')).toLocal(),
    creado: DateTime.parse(m.texto('creado')).toLocal(),
  );
}
