import '../../models/mapa.dart';
import '../../utils/numeros.dart';
import 'catalogo_glp1.dart';

/// Respuesta a un ítem de la lista de contraindicaciones.
enum RespuestaContra {
  no('No'),
  si('Sí'),
  desconoce('No sabe');

  const RespuestaContra(this.etiqueta);

  final String etiqueta;
}

class RespuestaItem {
  const RespuestaItem(this.respuesta, [this.nota = '']);

  final RespuestaContra respuesta;
  final String nota;

  Map<String, Object?> aMapa() =>
      compacto({'respuesta': respuesta.name, 'nota': nota});

  static RespuestaItem desdeMapa(Map<String, Object?> m) => RespuestaItem(
    RespuestaContra.values.byName(m.texto('respuesta')),
    m.texto('nota'),
  );
}

/// Revisión de la lista de contraindicaciones, con la versión de la lista.
class RevisionContraindicaciones {
  const RevisionContraindicaciones({
    required this.fecha,
    required this.respuestas,
    this.version = versionContraindicacionesGlp1,
  });

  final DateTime fecha;
  final Map<String, RespuestaItem> respuestas;
  final int version;

  Map<String, Object?> aMapa() => {
    'fecha': fechaIso(fecha),
    'version': version,
    'respuestas': {for (final e in respuestas.entries) e.key: e.value.aMapa()},
  };

  static RevisionContraindicaciones desdeMapa(Map<String, Object?> m) =>
      RevisionContraindicaciones(
        fecha: m.fecha('fecha')!,
        version: m.entero('version') ?? 1,
        respuestas: {
          for (final e in m.mapa('respuestas').entries)
            e.key: RespuestaItem.desdeMapa(
              (e.value! as Map).cast<String, Object?>(),
            ),
        },
      );
}

/// Plan (nutricional o de ejercicio) tomado de una plantilla aprobada y
/// ajustado para el paciente.
class PlanAsignado {
  const PlanAsignado({
    required this.plantillaId,
    required this.version,
    required this.nombre,
    required this.texto,
  });

  final String plantillaId;
  final int version;
  final String nombre;
  final String texto;

  Map<String, Object?> aMapa() => {
    'plantillaId': plantillaId,
    'version': version,
    'nombre': nombre,
    'texto': texto,
  };

  static PlanAsignado desdeMapa(Map<String, Object?> m) => PlanAsignado(
    plantillaId: m.texto('plantillaId'),
    version: m.entero('version') ?? 1,
    nombre: m.texto('nombre'),
    texto: m.texto('texto'),
  );
}

class DosisGlp1 {
  const DosisGlp1({
    required this.fecha,
    required this.dosis,
    this.unidad = 'mg',
  });

  final DateTime fecha;
  final double dosis;
  final String unidad;

  String get texto => '${formatoNumero(dosis)} $unidad';

  Map<String, Object?> aMapa() => {
    'fecha': fechaIso(fecha),
    'dosis': dosis,
    'unidad': unidad,
  };

  static DosisGlp1 desdeMapa(Map<String, Object?> m) => DosisGlp1(
    fecha: m.fecha('fecha')!,
    dosis: m.decimal('dosis') ?? 0,
    unidad: m.texto('unidad').isEmpty ? 'mg' : m.texto('unidad'),
  );
}

enum Intensidad {
  leve('Leve'),
  moderada('Moderada'),
  intensa('Intensa');

  const Intensidad(this.etiqueta);

  final String etiqueta;
}

class RegistroTolerancia {
  const RegistroTolerancia({
    required this.fecha,
    required this.sintomas,
    required this.intensidad,
  });

  final DateTime fecha;
  final String sintomas;
  final Intensidad intensidad;

  Map<String, Object?> aMapa() => {
    'fecha': fechaIso(fecha),
    'sintomas': sintomas,
    'intensidad': intensidad.name,
  };

  static RegistroTolerancia desdeMapa(Map<String, Object?> m) =>
      RegistroTolerancia(
        fecha: m.fecha('fecha')!,
        sintomas: m.texto('sintomas'),
        intensidad: Intensidad.values.byName(m.texto('intensidad')),
      );
}

enum Gravedad {
  leve('Leve'),
  moderada('Moderada'),
  grave('Grave');

  const Gravedad(this.etiqueta);

  final String etiqueta;
}

class EventoAdverso {
  const EventoAdverso({
    required this.fecha,
    required this.descripcion,
    required this.gravedad,
    this.conducta = '',
    this.reportadoInvima = false,
  });

  final DateTime fecha;
  final String descripcion;
  final Gravedad gravedad;
  final String conducta;
  final bool reportadoInvima;

  Map<String, Object?> aMapa() => compacto({
    'fecha': fechaIso(fecha),
    'descripcion': descripcion,
    'gravedad': gravedad.name,
    'conducta': conducta,
    'reportadoInvima': reportadoInvima ? true : null,
  });

  static EventoAdverso desdeMapa(Map<String, Object?> m) => EventoAdverso(
    fecha: m.fecha('fecha')!,
    descripcion: m.texto('descripcion'),
    gravedad: Gravedad.values.byName(m.texto('gravedad')),
    conducta: m.texto('conducta'),
    reportadoInvima: m.booleano('reportadoInvima'),
  );
}

/// GLP-1 del programa, con una copia de lo que decía el catálogo al
/// iniciarlo (medicamento, registro Invima e indicación).
class TratamientoGlp1 {
  const TratamientoGlp1({
    required this.medicamentoId,
    required this.nombre,
    required this.inicio,
    this.registroInvima = '',
    this.indicacion = '',
    this.dosis = const [],
    this.tolerancia = const [],
    this.eventos = const [],
    this.suspendidoEn,
    this.motivoSuspension = '',
  });

  final String medicamentoId;
  final String nombre;
  final DateTime inicio;
  final String registroInvima;
  final String indicacion;
  final List<DosisGlp1> dosis;
  final List<RegistroTolerancia> tolerancia;
  final List<EventoAdverso> eventos;
  final DateTime? suspendidoEn;
  final String motivoSuspension;

  bool get activo => suspendidoEn == null;
  DosisGlp1? get dosisActual => dosis.isEmpty ? null : dosis.last;

  TratamientoGlp1 copyWith({
    List<DosisGlp1>? dosis,
    List<RegistroTolerancia>? tolerancia,
    List<EventoAdverso>? eventos,
    Object? suspendidoEn = sin,
    String? motivoSuspension,
  }) => TratamientoGlp1(
    medicamentoId: medicamentoId,
    nombre: nombre,
    inicio: inicio,
    registroInvima: registroInvima,
    indicacion: indicacion,
    dosis: dosis ?? this.dosis,
    tolerancia: tolerancia ?? this.tolerancia,
    eventos: eventos ?? this.eventos,
    suspendidoEn: cambio(suspendidoEn, this.suspendidoEn),
    motivoSuspension: motivoSuspension ?? this.motivoSuspension,
  );

  Map<String, Object?> aMapa() => compacto({
    'medicamentoId': medicamentoId,
    'nombre': nombre,
    'inicio': fechaIso(inicio),
    'registroInvima': registroInvima,
    'indicacion': indicacion,
    'dosis': [for (final d in dosis) d.aMapa()],
    if (tolerancia.isNotEmpty)
      'tolerancia': [for (final t in tolerancia) t.aMapa()],
    if (eventos.isNotEmpty) 'eventos': [for (final e in eventos) e.aMapa()],
    'suspendidoEn': suspendidoEn == null ? null : fechaIso(suspendidoEn!),
    'motivoSuspension': motivoSuspension,
  });

  static TratamientoGlp1 desdeMapa(Map<String, Object?> m) => TratamientoGlp1(
    medicamentoId: m.texto('medicamentoId'),
    nombre: m.texto('nombre'),
    inicio: m.fecha('inicio')!,
    registroInvima: m.texto('registroInvima'),
    indicacion: m.texto('indicacion'),
    dosis: [for (final d in m.listaMapas('dosis')) DosisGlp1.desdeMapa(d)],
    tolerancia: [
      for (final t in m.listaMapas('tolerancia'))
        RegistroTolerancia.desdeMapa(t),
    ],
    eventos: [
      for (final e in m.listaMapas('eventos')) EventoAdverso.desdeMapa(e),
    ],
    suspendidoEn: m.fecha('suspendidoEn'),
    motivoSuspension: m.texto('motivoSuspension'),
  );
}

enum EstadoPrograma {
  activo('Activo'),
  pausado('Pausado'),
  terminado('Terminado');

  const EstadoPrograma(this.etiqueta);

  final String etiqueta;
}

/// Recordatorio del programa y de sus indicaciones impresas (pregunta 26).
const recordatorioProteinaFuerza =
    'Proteína suficiente y entrenamiento de fuerza para conservar la masa '
    'muscular mientras baja el peso.';

/// Programa de peso de una ficha (uno por paciente; se puede pausar,
/// terminar y reabrir).
class ProgramaPeso {
  const ProgramaPeso({
    required this.id,
    required this.pacienteId,
    required this.inicio,
    required this.creado,
    required this.actualizado,
    this.metaPeso,
    this.metaCintura,
    this.metaFecha,
    this.proteina = '',
    this.planNutricional,
    this.planEjercicio,
    this.contraindicaciones,
    this.glp1,
    this.estado = EstadoPrograma.activo,
    this.notas = '',
  });

  static const coleccion = 'programasPeso';

  final String id;
  final String pacienteId;
  final DateTime inicio;
  final DateTime creado;
  final DateTime actualizado;
  final double? metaPeso;
  final double? metaCintura;
  final DateTime? metaFecha;

  /// Cuánta proteína (la fija el médico, p. ej. «1,2 g/kg/día»).
  final String proteina;
  final PlanAsignado? planNutricional;
  final PlanAsignado? planEjercicio;
  final RevisionContraindicaciones? contraindicaciones;
  final TratamientoGlp1? glp1;
  final EstadoPrograma estado;
  final String notas;

  ProgramaPeso copyWith({
    String? id,
    String? pacienteId,
    DateTime? inicio,
    DateTime? actualizado,
    Object? metaPeso = sin,
    Object? metaCintura = sin,
    Object? metaFecha = sin,
    String? proteina,
    Object? planNutricional = sin,
    Object? planEjercicio = sin,
    Object? contraindicaciones = sin,
    Object? glp1 = sin,
    EstadoPrograma? estado,
    String? notas,
  }) => ProgramaPeso(
    id: id ?? this.id,
    pacienteId: pacienteId ?? this.pacienteId,
    inicio: inicio ?? this.inicio,
    creado: creado,
    actualizado: actualizado ?? this.actualizado,
    metaPeso: cambio(metaPeso, this.metaPeso),
    metaCintura: cambio(metaCintura, this.metaCintura),
    metaFecha: cambio(metaFecha, this.metaFecha),
    proteina: proteina ?? this.proteina,
    planNutricional: cambio(planNutricional, this.planNutricional),
    planEjercicio: cambio(planEjercicio, this.planEjercicio),
    contraindicaciones: cambio(contraindicaciones, this.contraindicaciones),
    glp1: cambio(glp1, this.glp1),
    estado: estado ?? this.estado,
    notas: notas ?? this.notas,
  );

  Map<String, Object?> aMapa() => compacto({
    'pacienteId': pacienteId,
    'inicio': fechaIso(inicio),
    'creado': creado.toUtc().toIso8601String(),
    'actualizado': actualizado.toUtc().toIso8601String(),
    'metaPeso': metaPeso,
    'metaCintura': metaCintura,
    'metaFecha': metaFecha == null ? null : fechaIso(metaFecha!),
    'proteina': proteina,
    'planNutricional': planNutricional?.aMapa(),
    'planEjercicio': planEjercicio?.aMapa(),
    'contraindicaciones': contraindicaciones?.aMapa(),
    'glp1': glp1?.aMapa(),
    'estado': estado.name,
    'notas': notas,
  });

  static ProgramaPeso desdeMapa(
    String id,
    Map<String, Object?> m,
  ) => ProgramaPeso(
    id: id,
    pacienteId: m.texto('pacienteId'),
    inicio: m.fecha('inicio')!,
    creado: DateTime.parse(m.texto('creado')).toLocal(),
    actualizado: DateTime.parse(m.texto('actualizado')).toLocal(),
    metaPeso: m.decimal('metaPeso'),
    metaCintura: m.decimal('metaCintura'),
    metaFecha: m.fecha('metaFecha'),
    proteina: m.texto('proteina'),
    planNutricional: m['planNutricional'] == null
        ? null
        : PlanAsignado.desdeMapa(m.mapa('planNutricional')),
    planEjercicio: m['planEjercicio'] == null
        ? null
        : PlanAsignado.desdeMapa(m.mapa('planEjercicio')),
    contraindicaciones: m['contraindicaciones'] == null
        ? null
        : RevisionContraindicaciones.desdeMapa(m.mapa('contraindicaciones')),
    glp1: m['glp1'] == null ? null : TratamientoGlp1.desdeMapa(m.mapa('glp1')),
    estado: EstadoPrograma.values.byName(
      m.texto('estado').isEmpty ? 'activo' : m.texto('estado'),
    ),
    notas: m.texto('notas'),
  );
}
