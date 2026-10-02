import '../clinica/edad.dart';
import '../integridad/json_canonico.dart';
import '../pais/perfil_pais.dart';
import '../utils/ids.dart';
import 'antecedentes.dart';
import 'diagnostico.dart';
import 'mapa.dart';
import 'paciente.dart';
import 'revision_sistemas.dart';
import 'signos_vitales.dart';

export 'antecedentes.dart';
export 'diagnostico.dart';
export 'evolucion.dart';
export 'paciente.dart';
export 'revision_sistemas.dart';
export 'signos_vitales.dart';

/// Valor de `datos.tipo` en el `historia.json` incrustado.
const tipoHistoriaClinica = 'historia_clinica';

class ExamenFisico {
  const ExamenFisico({this.estadoGeneral = '', this.hallazgos = ''});

  factory ExamenFisico.desdeMapa(Map<String, Object?> m) => ExamenFisico(
    estadoGeneral: m.texto('estadoGeneral'),
    hallazgos: m.texto('hallazgos'),
  );

  final String estadoGeneral;
  final String hallazgos;

  ExamenFisico copyWith({String? estadoGeneral, String? hallazgos}) =>
      ExamenFisico(
        estadoGeneral: estadoGeneral ?? this.estadoGeneral,
        hallazgos: hallazgos ?? this.hallazgos,
      );

  Map<String, Object?> aMapa() =>
      compacto({'estadoGeneral': estadoGeneral, 'hallazgos': hallazgos});
}

class PlanTratamiento {
  const PlanTratamiento({
    this.planTerapeutico = '',
    this.examenesSolicitados = '',
    this.interconsultas = '',
    this.indicaciones = '',
    this.proximoControl,
  });

  factory PlanTratamiento.desdeMapa(Map<String, Object?> m) => PlanTratamiento(
    planTerapeutico: m.texto('planTerapeutico'),
    examenesSolicitados: m.texto('examenesSolicitados'),
    interconsultas: m.texto('interconsultas'),
    indicaciones: m.texto('indicaciones'),
    proximoControl: m.fecha('proximoControl'),
  );

  final String planTerapeutico;
  final String examenesSolicitados;
  final String interconsultas;

  /// Indicaciones al paciente y signos de alarma.
  final String indicaciones;
  final DateTime? proximoControl;

  PlanTratamiento copyWith({
    String? planTerapeutico,
    String? examenesSolicitados,
    String? interconsultas,
    String? indicaciones,
    Object? proximoControl = sin,
  }) => PlanTratamiento(
    planTerapeutico: planTerapeutico ?? this.planTerapeutico,
    examenesSolicitados: examenesSolicitados ?? this.examenesSolicitados,
    interconsultas: interconsultas ?? this.interconsultas,
    indicaciones: indicaciones ?? this.indicaciones,
    proximoControl: cambio(proximoControl, this.proximoControl),
  );

  Map<String, Object?> aMapa() => compacto({
    'planTerapeutico': planTerapeutico,
    'examenesSolicitados': examenesSolicitados,
    'interconsultas': interconsultas,
    'indicaciones': indicaciones,
    'proximoControl': proximoControl == null ? null : fechaIso(proximoControl!),
  });
}

/// Qué imágenes del médico se imprimen en la historia (Fase 2).
class OpcionesFirma {
  const OpcionesFirma({this.incluirFirma = true, this.incluirSello = true});

  factory OpcionesFirma.desdeMapa(Map<String, Object?> m) => OpcionesFirma(
    incluirFirma: m.booleano('incluirFirma', porDefecto: true),
    incluirSello: m.booleano('incluirSello', porDefecto: true),
  );

  final bool incluirFirma;
  final bool incluirSello;

  OpcionesFirma copyWith({bool? incluirFirma, bool? incluirSello}) =>
      OpcionesFirma(
        incluirFirma: incluirFirma ?? this.incluirFirma,
        incluirSello: incluirSello ?? this.incluirSello,
      );

  Map<String, Object?> aMapa() => {
    'incluirFirma': incluirFirma,
    'incluirSello': incluirSello,
  };
}

/// Historia clínica inicial (todo menos las evoluciones).
class HistoriaClinica {
  const HistoriaClinica({
    required this.id,
    required this.pais,
    required this.fechaAtencion,
    this.tipoConsulta,
    this.paciente = const Paciente(),
    this.motivoConsulta = '',
    this.enfermedadActual = '',
    this.antecedentes = const Antecedentes(),
    this.revisionSistemas = const RevisionSistemas(),
    this.signos = const SignosVitales(),
    this.examen = const ExamenFisico(),
    this.analisis = '',
    this.diagnosticos = const [],
    this.plan = const PlanTratamiento(),
    this.firma = const OpcionesFirma(),
  });

  factory HistoriaClinica.nueva({required Pais pais, DateTime? ahora}) =>
      HistoriaClinica(
        id: nuevoUuid(),
        pais: pais,
        fechaAtencion: alMinuto(ahora ?? DateTime.now()),
        paciente: Paciente(
          tipoDocumento: pais.perfil.tiposDocumento.first.codigo,
        ),
      );

  /// Lanza [FormatException] si el mapa no es una historia clínica.
  factory HistoriaClinica.desdeMapa(Map<String, Object?> m) {
    if (m['tipo'] != tipoHistoriaClinica) {
      throw FormatException('No es una historia clínica: ${m['tipo']}');
    }
    final atencion = m.mapa('atencion');
    final motivo = m.mapa('motivo');
    return HistoriaClinica(
      id: m.texto('id'),
      pais: Pais.desdeCodigo(m.textoONulo('pais')),
      fechaAtencion: atencion.fecha('fechaHora')!,
      tipoConsulta: atencion.textoONulo('tipoConsulta'),
      paciente: Paciente.desdeMapa(m.mapa('paciente')),
      motivoConsulta: motivo.texto('motivoConsulta'),
      enfermedadActual: motivo.texto('enfermedadActual'),
      antecedentes: Antecedentes.desdeMapa(m.mapa('antecedentes')),
      revisionSistemas: RevisionSistemas.desdeMapa(m.mapa('revisionSistemas')),
      signos: SignosVitales.desdeMapa(m.mapa('signosVitales')),
      examen: ExamenFisico.desdeMapa(m.mapa('examenFisico')),
      analisis: m.mapa('analisis').texto('texto'),
      diagnosticos: [
        for (final d in m.listaMapas('diagnosticos')) Diagnostico.desdeMapa(d),
      ],
      plan: PlanTratamiento.desdeMapa(m.mapa('plan')),
      firma: OpcionesFirma.desdeMapa(m.mapa('firma')),
    );
  }

  final String id;

  /// País con el que se creó: fija tipos de documento y etiquetas.
  final Pais pais;
  final DateTime fechaAtencion;
  final String? tipoConsulta;
  final Paciente paciente;
  final String motivoConsulta;
  final String enfermedadActual;
  final Antecedentes antecedentes;
  final RevisionSistemas revisionSistemas;
  final SignosVitales signos;
  final ExamenFisico examen;

  /// Análisis clínico: interpretación y razonamiento diagnóstico.
  final String analisis;
  final List<Diagnostico> diagnosticos;
  final PlanTratamiento plan;
  final OpcionesFirma firma;

  PerfilPais get perfil => pais.perfil;

  /// Edad exacta a la fecha de la atención (si se conoce la fecha de
  /// nacimiento).
  Edad? get edad => paciente.fechaNacimiento == null
      ? null
      : calcularEdad(paciente.fechaNacimiento!, fechaAtencion);

  /// Años cumplidos, exactos o aproximados.
  int? get edadAnios => edad?.anios ?? paciente.edadAproximada;

  /// "34 años", "1 año 3 meses 5 días", "≈ 60 años"
  String get edadTexto {
    final e = edad;
    if (e != null) return e.texto;
    final aprox = paciente.edadAproximada;
    return aprox == null ? '' : '≈ $aprox ${aprox == 1 ? 'año' : 'años'}';
  }

  bool get esFemenino => paciente.sexo == 'F';

  HistoriaClinica copyWith({
    Pais? pais,
    DateTime? fechaAtencion,
    Object? tipoConsulta = sin,
    Paciente? paciente,
    String? motivoConsulta,
    String? enfermedadActual,
    Antecedentes? antecedentes,
    RevisionSistemas? revisionSistemas,
    SignosVitales? signos,
    ExamenFisico? examen,
    String? analisis,
    List<Diagnostico>? diagnosticos,
    PlanTratamiento? plan,
    OpcionesFirma? firma,
  }) => HistoriaClinica(
    id: id,
    pais: pais ?? this.pais,
    fechaAtencion: fechaAtencion ?? this.fechaAtencion,
    tipoConsulta: cambio(tipoConsulta, this.tipoConsulta),
    paciente: paciente ?? this.paciente,
    motivoConsulta: motivoConsulta ?? this.motivoConsulta,
    enfermedadActual: enfermedadActual ?? this.enfermedadActual,
    antecedentes: antecedentes ?? this.antecedentes,
    revisionSistemas: revisionSistemas ?? this.revisionSistemas,
    signos: signos ?? this.signos,
    examen: examen ?? this.examen,
    analisis: analisis ?? this.analisis,
    diagnosticos: diagnosticos ?? this.diagnosticos,
    plan: plan ?? this.plan,
    firma: firma ?? this.firma,
  );

  Map<String, Object?> aMapa() => {
    'tipo': tipoHistoriaClinica,
    'id': id,
    'pais': pais.codigo,
    'atencion': compacto({
      'fechaHora': fechaHoraIso(fechaAtencion),
      'tipoConsulta': tipoConsulta,
    }),
    'paciente': paciente.aMapa(),
    'motivo': compacto({
      'motivoConsulta': motivoConsulta,
      'enfermedadActual': enfermedadActual,
    }),
    'antecedentes': antecedentes.aMapa(),
    'revisionSistemas': revisionSistemas.aMapa(),
    'signosVitales': signos.aMapa(),
    'examenFisico': examen.aMapa(),
    'analisis': compacto({'texto': analisis}),
    'diagnosticos': [for (final d in diagnosticos) d.aMapa()],
    'plan': plan.aMapa(),
    'firma': firma.aMapa(),
  };

  /// `true` si el médico aún no escribió nada propio de este paciente.
  bool get estaVacia {
    final vacia = HistoriaClinica(
      id: id,
      pais: pais,
      fechaAtencion: fechaAtencion,
      paciente: Paciente(tipoDocumento: paciente.tipoDocumento),
    );
    final a = Map.of(aMapa())..remove('atencion');
    final b = Map.of(vacia.aMapa())..remove('atencion');
    return jsonCanonico(a) == jsonCanonico(b) && tipoConsulta == null;
  }
}
