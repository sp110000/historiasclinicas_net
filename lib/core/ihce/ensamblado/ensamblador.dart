import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../config/config_ihce.dart';
import '../grafo/grafo_rda.dart';
import '../grafo/referencias.dart';
import '../identidad/validador_identidad.dart';
import '../mappers/condition_mapper.dart';
import '../mappers/contexto.dart';
import '../mappers/encounter_mapper.dart';
import '../mappers/estructurales_mapper.dart';
import '../mappers/medication_request_mapper.dart';
import '../mappers/observation_mapper.dart';
import '../mappers/patient_mapper.dart';
import '../mappers/practitioner_mapper.dart';
import '../mappers/procedure_mapper.dart';
import '../modelo/documento_rda.dart';
import '../modelo/dto.dart';
import '../perfiles/modelo_perfil.dart';
import '../perfiles/perfiles_rda.g.dart';
import '../terminologia/catalogo_terminologia.dart';

/// Datos que identifican el documento para D3.
class IdentidadDocumento {
  const IdentidadDocumento({
    required this.tenantId,
    required this.atencionId,
    required this.tipo,
    required this.version,
  });

  final String tenantId;
  final String atencionId;
  final TipoRda tipo;
  final int version;
}

class ResultadoEnsamblado {
  const ResultadoEnsamblado({
    required this.bundle,
    required this.grafo,
    required this.faltantes,
    required this.advertencias,
    required this.identidad,
  });

  final Map<String, Object?> bundle;
  final GrafoRda grafo;

  /// Datos obligatorios ausentes o códigos fuera de catálogo: si hay alguno,
  /// el documento queda `INVALIDO_LOCAL`.
  final List<FaltaDato> faltantes;
  final List<FaltaDato> advertencias;
  final ResultadoIdentidad identidad;

  bool get valido =>
      faltantes.isEmpty && identidad.nivel != NivelIdentidad.bloqueo;
}

/// Estrategia por tipo de RDA: `Composition`, secciones y `Bundle`.
abstract interface class EstrategiaRda {
  TipoRda get tipo;

  ResultadoEnsamblado ensamblar(AtencionRda a, IdentidadDocumento id);
}

/// El tipo de RDA no tiene datos de origen en el repositorio (P1).
class RdaNoSoportado implements Exception {
  const RdaNoSoportado(this.tipo, this.brecha);

  final TipoRda tipo;
  final String brecha;

  @override
  String toString() => 'RDA de ${tipo.name} no soportado: $brecha';
}

/// Puntos de extensión de P1: urgencias, hospitalización y paciente. El
/// producto no captura triage, ingreso/egreso ni antecedentes codificados
/// (MAPEO_REPOSITORIO §5).
class EstrategiaPendiente implements EstrategiaRda {
  const EstrategiaPendiente(this.tipo, this.brecha);

  @override
  final TipoRda tipo;
  final String brecha;

  @override
  ResultadoEnsamblado ensamblar(AtencionRda a, IdentidadDocumento id) =>
      throw RdaNoSoportado(tipo, brecha);
}

EstrategiaRda estrategiaPara(
  TipoRda tipo,
  ConfigIhce config,
  CatalogoTerminologia catalogo,
) => switch (tipo) {
  TipoRda.consulta => EstrategiaConsulta(config, catalogo),
  TipoRda.urgencias => const EstrategiaPendiente(
    TipoRda.urgencias,
    'sin triage, vía de ingreso ni egreso en el modelo',
  ),
  TipoRda.hospitalizacion => const EstrategiaPendiente(
    TipoRda.hospitalizacion,
    'el producto no registra hospitalizaciones',
  ),
  TipoRda.paciente => const EstrategiaPendiente(
    TipoRda.paciente,
    'antecedentes solo en texto libre',
  ),
};

/// RDA de consulta externa (P0): `BundleAmbulatoryRDA` +
/// `CompositionAmbulatoryRDA`. Construcción determinista: los mismos datos
/// producen el mismo Bundle (orden estable de entradas, numeración
/// `{Tipo}-{n}` estable, sin reloj).
class EstrategiaConsulta implements EstrategiaRda {
  EstrategiaConsulta(this.config, this.catalogo);

  final ConfigIhce config;
  final CatalogoTerminologia catalogo;

  static const perfilComposition = 'CompositionAmbulatoryRDA';

  @override
  TipoRda get tipo => TipoRda.consulta;

  @override
  ResultadoEnsamblado ensamblar(AtencionRda a, IdentidadDocumento ident) {
    final refs = ReferenciasRda(config.estiloReferencia);
    final c = ContextoMapeo(
      config: config,
      catalogo: catalogo,
      referencias: refs,
    );
    final grafo = GrafoRda(refs);
    final identidad = ValidadorIdentidad(catalogo).validar(a.paciente);
    for (final h in identidad.hallazgos) {
      if (h.nivel == NivelIdentidad.advertencia) {
        c.advertir('Patient.${h.campo}', h.mensaje);
      }
    }

    // Identificadores (D1): personas por documento, IPS por habilitación.
    final idPaciente = ReferenciasRda.idPersona(
      a.paciente.tipoDocumento,
      a.paciente.numeroDocumento,
    );
    final idProfesional = ReferenciasRda.idPersona(
      a.profesional.tipoDocumento,
      a.profesional.numeroDocumento,
    );
    if (a.profesional.tipoDocumento.isEmpty) {
      c.falta(
        'Practitioner.identifier:NationalPersonIdentifier.type',
        'Falta el tipo de documento del médico',
      );
    }
    final idPrestador = ReferenciasRda.idOrganizacionIps(
      a.prestador.codigoHabilitacion,
    );
    if (a.prestador.codigoHabilitacion.isEmpty) {
      c.falta(
        'Composition.custodian',
        'Falta el código de habilitación del prestador',
      );
    }
    // La IPS ya existe en IHCE (REPS): referencia externa (Manual §5.3 c).
    grafo.externos.add(idPrestador);
    final idComposition = refs.nuevoId('Composition');
    final idEncuentro = refs.nuevoId('Encounter');
    if (!config.encounterComoEntrada) grafo.externos.add(idEncuentro);

    // Diagnósticos: el principal primero; los que no tienen código CIE-10
    // del catálogo: el principal bloquea, los relacionados se omiten.
    final ordenados = [
      ...a.diagnosticos.where((d) => d.principal),
      ...a.diagnosticos.where((d) => !d.principal),
    ];
    final condiciones = <DiagnosticoEnGrafo>[];
    final nodosCondicion = <NodoGrafo>[];
    for (final d in ordenados) {
      if (!diagnosticoCodificable(d, c)) {
        if (d.principal) {
          c.falta(
            'Condition.code.coding:ICD10',
            d.codigoCie10.isEmpty
                ? 'El diagnóstico principal no tiene código CIE-10'
                : 'El código CIE-10 del diagnóstico principal no está en el catálogo',
            categoria: d.codigoCie10.isEmpty ? 'DATO' : 'SEMANTICO',
          );
        } else {
          // Omitirlo dejaría la lista de problemas incompleta sin decirlo
          // (DESVIACIONES.md D8): el RDA no se envía.
          c.falta(
            'Condition.code.coding:ICD10',
            d.codigoCie10.isEmpty
                ? 'Un diagnóstico relacionado no tiene código CIE-10'
                : 'El código CIE-10 de un diagnóstico relacionado no está en el catálogo',
            categoria: d.codigoCie10.isEmpty ? 'DATO' : 'SEMANTICO',
          );
        }
        continue;
      }
      final id = refs.nuevoId('Condition');
      condiciones.add((idCondition: id, dto: d));
      nodosCondicion.add(
        NodoGrafo(
          idLocal: id,
          recurso: mapearDiagnostico(d, c, id: id, idPaciente: idPaciente),
          perfil: PerfilRda.conditionRDA,
          tablaOrigen: d.origen.tabla,
          pkOrigen: d.origen.pk,
        ),
      );
    }
    final principal = condiciones.where((x) => x.dto.principal).firstOrNull;

    final pacienteNodo = NodoGrafo(
      idLocal: idPaciente,
      recurso: mapearPaciente(a.paciente, c, id: idPaciente),
      perfil: PerfilRda.patientRDA,
      tablaOrigen: a.paciente.origen.tabla,
      pkOrigen: a.paciente.origen.pk,
    );
    final profesionalNodo = NodoGrafo(
      idLocal: idProfesional,
      recurso: mapearProfesional(a.profesional, c, id: idProfesional),
      perfil: PerfilRda.practitionerRDA,
      tablaOrigen: a.profesional.origen.tabla,
      pkOrigen: a.profesional.origen.pk,
    );
    final encuentroNodo = NodoGrafo(
      idLocal: idEncuentro,
      recurso: mapearEncuentro(
        a.encuentro,
        a.prestador,
        c,
        id: idEncuentro,
        idPaciente: idPaciente,
        idProfesional: idProfesional,
        idPrestador: idPrestador,
        principal: principal,
        relacionados: [
          for (final x in condiciones)
            if (!x.dto.principal) x,
        ],
      ),
      perfil: PerfilRda.encounterAmbulatoryRDA,
      tablaOrigen: a.encuentro.origen.tabla,
      pkOrigen: a.encuentro.origen.pk,
    );

    // Recursos clínicos opcionales (hoy sin datos codificados de origen).
    final otros = <NodoGrafo>[];
    for (final al in a.alergias) {
      final id = refs.nuevoId('AllergyIntolerance');
      otros.add(
        NodoGrafo(
          idLocal: id,
          recurso: mapearAlergia(
            al,
            c,
            id: id,
            idPaciente: idPaciente,
            idEncuentro: idEncuentro,
          ),
          perfil: PerfilRda.allergyIntoleranceRDA,
          tablaOrigen: al.origen.tabla,
          pkOrigen: al.origen.pk,
        ),
      );
    }
    for (final m in a.medicamentos) {
      final id = refs.nuevoId('MedicationRequest');
      final diag = condiciones
          .where((x) => x.dto.origen.pk == m.diagnosticoPk)
          .firstOrNull;
      otros.add(
        NodoGrafo(
          idLocal: id,
          recurso: mapearMedicamento(
            m,
            c,
            id: id,
            idPaciente: idPaciente,
            idEncuentro: idEncuentro,
            idProfesional: idProfesional,
            idDiagnostico: diag?.idCondition,
          ),
          perfil: PerfilRda.medicationRequestRDA,
          tablaOrigen: m.origen.tabla,
          pkOrigen: m.origen.pk,
        ),
      );
    }
    for (final o in a.observaciones) {
      final id = refs.nuevoId('Observation');
      final r = mapearObservacion(
        o,
        c,
        id: id,
        idPaciente: idPaciente,
        idEncuentro: idEncuentro,
      );
      otros.add(
        NodoGrafo(
          idLocal: id,
          recurso: r.recurso,
          perfil: r.perfil,
          tablaOrigen: o.origen.tabla,
          pkOrigen: o.origen.pk,
        ),
      );
    }
    for (final p in a.procedimientos.where((p) => !p.realizado)) {
      // En consulta externa solo hay sección para lo ordenado.
      final id = refs.nuevoId('ServiceRequest');
      final r = mapearProcedimiento(
        p,
        c,
        id: id,
        idPaciente: idPaciente,
        idEncuentro: idEncuentro,
        idProfesional: idProfesional,
      );
      otros.add(
        NodoGrafo(
          idLocal: id,
          recurso: r.recurso,
          perfil: r.perfil,
          tablaOrigen: p.origen.tabla,
          pkOrigen: p.origen.pk,
        ),
      );
    }
    if (a.procedimientos.any((p) => p.realizado)) {
      c.advertir(
        'Procedure',
        'Los procedimientos realizados no tienen sección en el RDA de consulta',
      );
    }

    final idDocumento = refs.nuevoId('DocumentReference');
    final documentoNodo = NodoGrafo(
      idLocal: idDocumento,
      recurso: mapearDocumentoSoporte(
        a.pdf,
        c,
        id: idDocumento,
        idPaciente: idPaciente,
        idEncuentro: idEncuentro,
        idAutor: idPrestador,
        fecha: a.encuentro.fin,
      ),
      perfil: PerfilRda.documentReferenceEPIRDA,
      tablaOrigen: 'pdf',
      pkOrigen: a.encuentro.id,
    );
    grafo.externos.add(
      Fijos(
        'DocumentReferenceEPIRDA',
      ).texto('DocumentReference.custodian.reference'),
    );

    final clinicos = [...nodosCondicion, ...otros, documentoNodo];
    final composition = _composition(
      c,
      a,
      secciones: seccionesPorComposition[perfilComposition]!,
      clinicos: clinicos,
      idPaciente: idPaciente,
      idEncuentro: idEncuentro,
      idProfesional: idProfesional,
      idPrestador: idPrestador,
    );
    // Sin `id`, como en la colección Postman (nadie lo referencia).
    final compositionNodo = NodoGrafo(
      idLocal: idComposition,
      recurso: composition,
      perfil: PerfilRda.compositionAmbulatoryRDA,
      tablaOrigen: 'datos',
      pkOrigen: a.encuentro.id,
    );

    // Orden estable de entradas: Composition, Patient, Practitioner,
    // Encounter (D2), clínicos en el orden de sus secciones, PDF al final.
    grafo
      ..agregar(compositionNodo)
      ..agregar(pacienteNodo)
      ..agregar(profesionalNodo)
      ..agregar(encuentroNodo);
    for (final n in clinicos) {
      grafo.agregar(n);
    }
    grafo
      ..cabeza = idComposition
      ..raiz = idEncuentro;

    // Con datos faltantes el RDA ya no se envía y los errores de integridad
    // serían su consecuencia (p. ej. una entrada que su sección bloqueada no
    // referencia): no se suman al motivo.
    if (c.faltantes.isEmpty) {
      for (final e in grafo.verificarIntegridad()) {
        c.falta('Bundle', e);
      }
    }

    final enBundle = [
      for (final n in grafo.nodos)
        if (n.idLocal != idEncuentro || config.encounterComoEntrada) n,
    ];
    final bundle = <String, Object?>{
      'resourceType': 'Bundle',
      if (config.identificadorBundle == IdentificadorBundle.uuid)
        'identifier': {
          'system': Fijos(tipo.perfilBundle).texto('Bundle.identifier.system'),
          'value': uuidDeterminista(ident),
        },
      'type': Fijos(tipo.perfilBundle).texto('Bundle.type'),
      // Instante de cierre de la atención, no el reloj: reintentos con los
      // mismos bytes.
      'timestamp': c.fechaHora(a.encuentro.fin),
      'entry': [
        for (final n in enBundle) {'resource': n.recurso},
      ],
    };
    return ResultadoEnsamblado(
      bundle: bundle,
      grafo: grafo,
      faltantes: List.unmodifiable(c.faltantes),
      advertencias: List.unmodifiable(c.advertencias),
      identidad: identidad,
    );
  }

  Map<String, Object?> _composition(
    ContextoMapeo c,
    AtencionRda a, {
    required List<SeccionPerfil> secciones,
    required List<NodoGrafo> clinicos,
    required String idPaciente,
    required String idEncuentro,
    required String idProfesional,
    required String idPrestador,
  }) {
    final f = Fijos(perfilComposition);
    return {
      'resourceType': 'Composition',
      'meta': {
        'profile': [f.url],
      },
      'status': 'final',
      'type': {
        'coding': [f.coding('Composition.type.coding')],
      },
      'subject': c.ref(idPaciente),
      'encounter': c.ref(idEncuentro),
      'date': c.fechaHora(a.encuentro.fin),
      'author': [c.ref(idProfesional)],
      'title': config.tituloComposition,
      'confidentiality': f.texto('Composition.confidentiality'),
      'attester': [
        {
          'mode': f.texto('Composition.attester.mode'),
          'party': c.ref(idProfesional),
        },
      ],
      'custodian': c.ref(idPrestador),
      'event': [
        {
          'period': {
            'start': c.fechaHora(a.encuentro.inicio),
            'end': c.fechaHora(a.encuentro.fin),
          },
        },
      ],
      'section': [
        for (final s in secciones)
          if (s.obligatoria || _entradas(s, clinicos).isNotEmpty)
            _seccion(c, s, _entradas(s, clinicos), a.textos),
      ],
    };
  }

  List<NodoGrafo> _entradas(SeccionPerfil s, List<NodoGrafo> clinicos) => [
    for (final n in clinicos)
      if (s.perfilesEntrada.contains(n.perfil)) n,
  ];

  Map<String, Object?> _seccion(
    ContextoMapeo c,
    SeccionPerfil s,
    List<NodoGrafo> entradas,
    TextosLibresDto t,
  ) {
    final base = <String, Object?>{
      'title': ?s.titulo,
      'code': {
        'coding': [
          {'system': s.sistema, 'code': s.codigo, 'display': s.display},
        ],
      },
    };
    // Contenido sin codificar para la sección: sin entradas, el perfil solo
    // admite `emptyReason = nilknown` («nada conocido»), que sería falso; con
    // algunas entradas codificadas, la lista quedaría incompleta sin
    // decirlo. Ningún perfil de entrada admite ese contenido sin inventar
    // códigos (DESVIACIONES.md D8): el RDA no se envía.
    final motivo = contenidoSinCodificar(s.slice, t);
    if (motivo != null) {
      c.falta('Composition.section:${s.slice}', motivo);
      return base;
    }
    if (entradas.isNotEmpty) {
      return {
        ...base,
        'entry': [for (final n in entradas) c.ref(n.idLocal)],
      };
    }
    if (s.entradaMin > 0 || !s.emptyReasonPermitido) {
      c.falta(
        'Composition.section:${s.slice}',
        'La sección «${s.titulo ?? s.slice}» exige al menos una entrada',
      );
      return base;
    }
    // Código y display de `emptyReason`: fijos del perfil (nilknown en todas
    // las secciones de consulta); si un perfil no los fijara, el del ejemplo
    // del Manual §5.4.3b.
    final f = Fijos(perfilComposition);
    final pre = 'Composition.section:${s.slice}.emptyReason.coding';
    final codigo = f.valor('$pre.code') as String? ?? 'nilknown';
    return {
      ...base,
      'text': ContextoMapeo.narrativa(textoNadaConocido),
      'emptyReason': {
        'coding': [
          c.coding(
            f.valor('$pre.system') as String? ?? SistemaRda.listEmptyReason,
            codigo,
            elemento: '$pre.code',
            dato: 'razón de sección vacía',
          ),
        ],
      },
    };
  }
}

/// Texto estándar del Manual de Operaciones §5.4.3b (ejemplo «nilknown»).
const textoNadaConocido =
    'No existen elementos conocidos para esta lista y/o el paciente no '
    'declara información';

/// Motivo, en lenguaje llano y sin datos del paciente, por el que la
/// sección [slice] no puede ir vacía: la atención tiene texto sin codificar
/// para ella. `null` si de verdad no hay nada (MATRIZ_RDA §3).
String? contenidoSinCodificar(String slice, TextosLibresDto t) {
  bool hay(String x) => x.trim().isNotEmpty;
  return switch (slice) {
    'sectionAllergies' when !t.niegaAlergias && t.alergias.isNotEmpty =>
      'Las alergias registradas no tienen tipo de alergia codificado; '
          'el RDA no puede declarar «sin alergias conocidas»',
    'sectionPayers' when hay(t.aseguradora) =>
      'La aseguradora (EAPB) está registrada solo como texto; el RDA exige '
          'su código y no puede declarar «sin aseguradora conocida»',
    'sectionHistoryOfOccupation' when hay(t.ocupacion) =>
      'La ocupación está registrada solo como texto; el RDA exige su código '
          'CIUO-88 y no puede declarar «sin ocupación conocida»',
    'sectionMedications'
        when hay(t.planTerapeutico) || hay(t.medicacionActual) =>
      'La medicación actual o el plan terapéutico (fórmula) tienen texto que '
          'puede incluir medicamentos; el RDA exige medicamentos codificados '
          'y no puede declarar «sin medicamentos conocidos»',
    'sectionRiskFactors' when hay(t.habitos) =>
      'Los hábitos están registrados solo como texto; el RDA exige factores '
          'de riesgo codificados y no puede declarar «sin factores de riesgo '
          'conocidos»',
    'sectionServiceRequests' when hay(t.examenes) || hay(t.interconsultas) =>
      'Los exámenes o interconsultas están registrados solo como texto; el '
          'RDA exige su código CUPS y no puede declarar «sin órdenes '
          'conocidas»',
    _ => null,
  };
}

/// UUID v5 (RFC 4122, espacio de nombres URL) de la identidad del
/// documento: el mismo documento da siempre el mismo valor (D3).
String uuidDeterminista(IdentidadDocumento d) {
  const espacioUrl = [
    0x6b, 0xa7, 0xb8, 0x11, 0x9d, 0xad, 0x11, 0xd1, //
    0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8,
  ];
  final nombre =
      'urn:historiasclinicas.net:ihce:${d.tenantId}:${d.atencionId}:'
      '${d.tipo.name}:${d.version}';
  final h = sha1.convert([...espacioUrl, ...utf8.encode(nombre)]).bytes;
  final b = h.sublist(0, 16);
  b[6] = (b[6] & 0x0f) | 0x50;
  b[8] = (b[8] & 0x3f) | 0x80;
  final x = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${x.substring(0, 8)}-${x.substring(8, 12)}-${x.substring(12, 16)}-'
      '${x.substring(16, 20)}-${x.substring(20)}';
}
