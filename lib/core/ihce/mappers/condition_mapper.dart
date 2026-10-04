import '../modelo/dto.dart';
import '../perfiles/perfiles_rda.g.dart';
import 'contexto.dart';

/// `ConditionRDA`: diagnóstico de la atención. Origen:
/// `datos.diagnosticos[]` (`lib/core/models/diagnostico.dart`). El `display`
/// sale del catálogo cargado (D6), nunca de `Diagnostico.descripcion`.
/// `Condition.encounter` está prohibido (0..0) en el perfil.
///
/// `ConditionStatementRDA` (antecedente) queda como punto de extensión: el
/// repositorio guarda los antecedentes como texto libre.
Map<String, Object?> mapearDiagnostico(
  DiagnosticoDto d,
  ContextoMapeo c, {
  required String id,
  required String idPaciente,
}) {
  final f = Fijos('ConditionRDA');
  return {
    'resourceType': 'Condition',
    'id': id,
    'meta': {
      'profile': [f.url],
    },
    'clinicalStatus': {
      'coding': [f.coding('Condition.clinicalStatus.coding')],
    },
    'verificationStatus': {
      'coding': [f.coding('Condition.verificationStatus.coding')],
    },
    'code': {
      'coding': [
        c.coding(
          f.texto('Condition.code.coding:ICD10.system'),
          d.codigoCie10,
          elemento: 'Condition.code.coding:ICD10',
          dato: 'diagnóstico CIE-10',
        ),
      ],
    },
    'subject': c.ref(idPaciente),
  };
}

/// ¿Se puede emitir este diagnóstico? (código presente y en el catálogo).
bool diagnosticoCodificable(DiagnosticoDto d, ContextoMapeo c) =>
    d.codigoCie10.isNotEmpty &&
    c.catalogo.contiene(SistemaRda.icd10CO, d.codigoCie10);
