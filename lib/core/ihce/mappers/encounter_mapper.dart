import '../modelo/dto.dart';
import '../perfiles/perfiles_rda.g.dart';
import '../terminologia/equivalencias.dart';
import 'contexto.dart';

/// Diagnóstico ya convertido en `Condition`, con su `id` local.
typedef DiagnosticoEnGrafo = ({String idCondition, DiagnosticoDto dto});

/// `EncounterAmbulatoryRDA`: nodo raíz local. `subject`, `period`,
/// `serviceProvider` y `participant` determinan la unicidad ante la
/// plataforma (regla de duplicados): salen de datos sellados y de la
/// configuración, y son estables entre reintentos. El VIDA no va aquí:
/// `identifier:EncounterIdentifier` lleva el identificador de la atención.
Map<String, Object?> mapearEncuentro(
  EncuentroDto e,
  PrestadorDto prestador,
  ContextoMapeo c, {
  required String id,
  required String idPaciente,
  required String idProfesional,
  required String idPrestador,
  required DiagnosticoEnGrafo? principal,
  required List<DiagnosticoEnGrafo> relacionados,
  String perfil = 'EncounterAmbulatoryRDA',
}) {
  final f = Fijos(perfil);
  const tipo = 'Encounter.type';
  const participante = 'Encounter.participant:AttenderPhysician';

  if (e.fin.isBefore(e.inicio)) {
    c.falta('Encounter.period', 'La atención termina antes de empezar');
  }
  if (principal == null) {
    c.falta(
      'Encounter.diagnosis:MainDiagnosis',
      'Falta el diagnóstico principal con código CIE-10',
    );
  }
  if (e.tipoConsulta == null) {
    c.falta('Encounter.serviceType', 'Falta el tipo de consulta');
  } else if (prestador.cupsConsulta.isEmpty) {
    c.falta(
      'Encounter.serviceType',
      'Falta configurar el CUPS de este tipo de consulta',
    );
  }

  Map<String, Object?> diagnostico(String slice, DiagnosticoEnGrafo d) {
    final pre = 'Encounter.diagnosis:$slice';
    return {
      'id': f.texto('$pre.id'),
      if (slice == 'MainDiagnosis')
        'extension': [
          {
            'url': PerfilRda.extensionDiagnosisType,
            'valueCoding': c.coding(
              sistemaTipoDiagnostico,
              caracterATipoDiagnostico[d.dto.caracter],
              elemento: '$pre.extension:ExtensionDiagnosisType',
              dato: 'tipo de diagnóstico principal',
            ),
          },
        ],
      'condition': c.ref(d.idCondition),
      'use': {
        'coding': [f.coding('$pre.use.coding')],
      },
      'rank': f.valor('$pre.rank'),
    };
  }

  final comorbilidades = relacionados.take(3).toList();
  return {
    'resourceType': 'Encounter',
    'id': id,
    'meta': {
      'profile': [f.url],
    },
    'identifier': [
      {
        'id': f.texto('Encounter.identifier:EncounterIdentifier.id'),
        'use': f.texto('Encounter.identifier:EncounterIdentifier.use'),
        'system': f.texto('Encounter.identifier:EncounterIdentifier.system'),
        'value': e.id,
      },
    ],
    'status': f.texto('Encounter.status'),
    'class': f.coding('Encounter.class'),
    'type': [
      {
        'coding': [
          c.coding(
            f.texto('$tipo:encounterModality.coding.system'),
            prestador.modalidad,
            elemento: '$tipo:encounterModality',
            dato: 'modalidad de la atención',
          ),
        ],
      },
      {
        'coding': [f.coding('$tipo:encounterServiceGroup.coding')],
      },
      {
        'coding': [
          c.coding(
            f.texto('$tipo:encounterEnvironment.coding.system'),
            prestador.entorno,
            elemento: '$tipo:encounterEnvironment',
            dato: 'entorno de la atención',
          ),
        ],
      },
    ],
    'serviceType': {
      'coding': [
        c.coding(
          f.texto('Encounter.serviceType.coding.system'),
          prestador.cupsConsulta.isEmpty ? null : prestador.cupsConsulta,
          elemento: 'Encounter.serviceType',
          dato: 'CUPS de la consulta',
          valueSet: ConjuntoRda.cupsConsultationCodes,
        ),
      ],
    },
    'subject': c.ref(idPaciente),
    'participant': [
      {
        'id': f.texto('$participante.id'),
        'type': [
          {
            'coding': [f.coding('$participante.type.coding')],
          },
        ],
        'individual': c.ref(idProfesional),
      },
    ],
    'period': {'start': c.fechaHora(e.inicio), 'end': c.fechaHora(e.fin)},
    'reasonCode': [
      {
        'coding': [
          c.coding(
            f.texto('Encounter.reasonCode.coding.system'),
            e.causaExterna,
            elemento: 'Encounter.reasonCode',
            dato: 'causa externa',
          ),
        ],
      },
    ],
    'diagnosis': [
      if (principal != null) diagnostico('MainDiagnosis', principal),
      for (var i = 0; i < comorbilidades.length; i++)
        diagnostico('Comorbidity-${i + 1}', comorbilidades[i]),
    ],
    'serviceProvider': c.ref(idPrestador),
  };
}
