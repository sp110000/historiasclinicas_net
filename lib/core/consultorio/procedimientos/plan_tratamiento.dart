import '../../models/mapa.dart';

/// Lo que cubre un consentimiento informado (pregunta 39): procedimiento,
/// zonas, número de sesiones y producto. Si cambian la técnica, el
/// producto o las zonas, hace falta uno nuevo.
class PlanTratamiento {
  const PlanTratamiento({
    required this.plantillaId,
    required this.version,
    required this.procedimiento,
    required this.zonas,
    required this.sesiones,
    required this.producto,
  });

  final String plantillaId;

  /// Versión de la plantilla del procedimiento con que se firmó.
  final int version;
  final String procedimiento;
  final List<String> zonas;
  final int sesiones;
  final String producto;

  String get textoZonas => zonas.join(', ');

  PlanTratamiento copyWith({
    List<String>? zonas,
    int? sesiones,
    String? producto,
  }) => PlanTratamiento(
    plantillaId: plantillaId,
    version: version,
    procedimiento: procedimiento,
    zonas: zonas ?? this.zonas,
    sesiones: sesiones ?? this.sesiones,
    producto: producto ?? this.producto,
  );

  Map<String, Object?> aMapa() => {
    'plantillaId': plantillaId,
    'version': version,
    'procedimiento': procedimiento,
    'zonas': zonas,
    'sesiones': sesiones,
    'producto': producto,
  };

  static PlanTratamiento desdeMapa(Map<String, Object?> m) => PlanTratamiento(
    plantillaId: m.texto('plantillaId'),
    version: m.entero('version') ?? 1,
    procedimiento: m.texto('procedimiento'),
    zonas: m.listaTextos('zonas'),
    sesiones: m.entero('sesiones') ?? 0,
    producto: m.texto('producto'),
  );
}
