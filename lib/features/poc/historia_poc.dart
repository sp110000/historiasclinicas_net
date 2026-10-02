/// Modelo reducido de la prueba de concepto (Fase 0).
///
/// En la Fase 1 lo reemplaza el modelo completo de la historia clínica. Se
/// conserva el formato de mapa (`aMapa`/`desdeMapa`) que viaja en el PDF.
library;

class EvolucionPoc {
  const EvolucionPoc({required this.fechaHora, required this.texto});

  factory EvolucionPoc.desdeMapa(Map<String, Object?> m) => EvolucionPoc(
    fechaHora: DateTime.parse(m['fechaHora']! as String),
    texto: m['texto']! as String,
  );

  /// Hora local de la consulta, tal como la ve el médico.
  final DateTime fechaHora;
  final String texto;

  Map<String, Object?> aMapa() => {
    'fechaHora': fechaHora.toIso8601String(),
    'texto': texto,
  };
}

class HistoriaPoc {
  const HistoriaPoc({
    required this.id,
    required this.creadaEn,
    required this.primerApellido,
    required this.segundoApellido,
    required this.nombres,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.motivoConsulta,
    this.evoluciones = const [],
  });

  factory HistoriaPoc.desdeMapa(Map<String, Object?> m) {
    final p = (m['paciente']! as Map).cast<String, Object?>();
    return HistoriaPoc(
      id: m['id']! as String,
      creadaEn: DateTime.parse(m['creadaEn']! as String),
      primerApellido: p['primerApellido']! as String,
      segundoApellido: p['segundoApellido']! as String,
      nombres: p['nombres']! as String,
      tipoDocumento: p['tipoDocumento']! as String,
      numeroDocumento: p['numeroDocumento']! as String,
      motivoConsulta: m['motivoConsulta']! as String,
      evoluciones: [
        for (final e in m['evoluciones']! as List)
          EvolucionPoc.desdeMapa((e as Map).cast<String, Object?>()),
      ],
    );
  }

  final String id;
  final DateTime creadaEn;
  final String primerApellido;
  final String segundoApellido;
  final String nombres;
  final String tipoDocumento;
  final String numeroDocumento;
  final String motivoConsulta;
  final List<EvolucionPoc> evoluciones;

  String get apellidos => [
    primerApellido,
    segundoApellido,
  ].where((s) => s.trim().isNotEmpty).join(' ');

  /// "PEÑA MUÑOZ, José Ángel"
  String get nombreCompleto => '${apellidos.toUpperCase()}, $nombres';

  HistoriaPoc conEvoluciones(List<EvolucionPoc> evoluciones) => HistoriaPoc(
    id: id,
    creadaEn: creadaEn,
    primerApellido: primerApellido,
    segundoApellido: segundoApellido,
    nombres: nombres,
    tipoDocumento: tipoDocumento,
    numeroDocumento: numeroDocumento,
    motivoConsulta: motivoConsulta,
    evoluciones: evoluciones,
  );

  Map<String, Object?> aMapa() => {
    'tipo': 'poc',
    'id': id,
    'creadaEn': creadaEn.toIso8601String(),
    'paciente': {
      'primerApellido': primerApellido,
      'segundoApellido': segundoApellido,
      'nombres': nombres,
      'tipoDocumento': tipoDocumento,
      'numeroDocumento': numeroDocumento,
    },
    'motivoConsulta': motivoConsulta,
    'evoluciones': [for (final e in evoluciones) e.aMapa()],
  };
}
