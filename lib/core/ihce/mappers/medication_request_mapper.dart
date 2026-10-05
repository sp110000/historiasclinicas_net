import '../modelo/dto.dart';
import '../perfiles/perfiles_rda.g.dart';
import 'contexto.dart';

/// `MedicationRequestRDA` (prescripción), según los slices vigentes de
/// `medication[x].coding` (DCI de MIPRES, IUM de primer nivel) y la
/// Especificación Técnica de Prescripción de Medicamentos RDA. Las
/// preparaciones magistrales llevan el texto del medicamento.
///
/// Sin datos de origen hoy: la receta del repositorio es texto libre y no
/// entra a la historia (MATRIZ_RDA §3). `MedicationAdminRequestRDA` (orden
/// de administración) es de hospitalización (P1).
///
/// TODO(IHCE-VERIFICAR): semántica de `doseAndRate:UMM.rate[x]` (la
/// colección Postman usa una cantidad con unidad `MedicationTime`); se
/// emite la frecuencia como tasa por unidad de tiempo.
Map<String, Object?> mapearMedicamento(
  MedicamentoDto m,
  ContextoMapeo c, {
  required String id,
  required String idPaciente,
  required String idEncuentro,
  required String idProfesional,
  String? idDiagnostico,
}) {
  final f = Fijos('MedicationRequestRDA');
  const med = 'MedicationRequest.medication[x].coding';
  const dosis = 'MedicationRequest.dosageInstruction';
  if (m.dci.isEmpty && m.iumPrimerNivel == null && m.textoMagistral == null) {
    c.falta(
      'MedicationRequest.medication[x]',
      'Falta la codificación del medicamento (DCI o IUM)',
    );
  }
  final unidad = c.coding(
    f.texto('$dosis.doseAndRate:UMM.dose[x].system'),
    m.unidadDosis,
    elemento: '$dosis.doseAndRate:UMM.dose[x]',
    dato: 'unidad de la dosis',
  );
  final frecuencia = c.coding(
    f.texto('$dosis.timing.code.coding.system'),
    m.frecuencia,
    elemento: '$dosis.timing.code',
    dato: 'frecuencia',
  );
  return {
    'resourceType': 'MedicationRequest',
    'id': id,
    'meta': {
      'profile': [f.url],
    },
    'status': f.texto('MedicationRequest.status'),
    'intent': f.texto('MedicationRequest.intent'),
    'category': [
      {
        'coding': [
          c.coding(
            f.texto('MedicationRequest.category.coding:R866.system'),
            m.categoria,
            elemento: 'MedicationRequest.category',
            dato: 'categoría de la tecnología',
            valueSet: ConjuntoRda.colombianHealthTechnologyMedicationCodes,
          ),
        ],
      },
    ],
    // Prescripción primaria del prestador, no reportada por terceros.
    'reportedBoolean': false,
    'medicationCodeableConcept': {
      'coding': [
        for (final dci in m.dci)
          c.coding(
            f.texto('$med:DCI.system'),
            dci,
            elemento: '$med:DCI',
            dato: 'DCI del medicamento',
          ),
        if (m.iumPrimerNivel != null)
          c.coding(
            f.texto('$med:IUMPrimerNivel.system'),
            m.iumPrimerNivel,
            elemento: '$med:IUMPrimerNivel',
            dato: 'IUM de primer nivel',
          ),
      ],
      'text': ?m.textoMagistral,
    },
    'subject': c.ref(idPaciente),
    'encounter': c.ref(idEncuentro),
    'authoredOn': c.fechaHora(m.fecha),
    'requester': c.ref(idProfesional),
    'reasonCode': [
      {
        'coding': [
          c.coding(
            f.texto('MedicationRequest.reasonCode.coding.system'),
            m.finalidad,
            elemento: 'MedicationRequest.reasonCode',
            dato: 'finalidad de la prescripción',
          ),
        ],
      },
    ],
    if (idDiagnostico != null) 'reasonReference': [c.ref(idDiagnostico)],
    'dosageInstruction': [
      {
        'text': ?m.instrucciones,
        if (m.indicacionEspecial != null)
          'additionalInstruction': [
            {
              'coding': [
                c.coding(
                  f.texto('$dosis.additionalInstruction.coding.system'),
                  m.indicacionEspecial,
                  elemento: '$dosis.additionalInstruction',
                  dato: 'indicación especial',
                ),
              ],
            },
          ],
        'timing': {
          'repeat': {'duration': m.duracionDias, 'durationUnit': 'd'},
          'code': {
            'coding': [frecuencia],
          },
        },
        'route': {
          'coding': [
            c.coding(
              f.texto('$dosis.route.coding.system'),
              m.via,
              elemento: '$dosis.route',
              dato: 'vía de administración',
            ),
          ],
        },
        'doseAndRate': [
          {
            'doseQuantity': {
              'value': m.dosis,
              'unit': ?unidad['display'],
              'system': unidad['system'],
              'code': ?unidad['code'],
            },
            'rateQuantity': {
              'value': 1,
              'unit': ?frecuencia['display'],
              'system': f.texto('$dosis.doseAndRate:UMM.rate[x].system'),
              'code': ?frecuencia['code'],
            },
          },
        ],
      },
    ],
  };
}
