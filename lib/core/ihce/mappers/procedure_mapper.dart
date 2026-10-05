import '../modelo/dto.dart';
import '../perfiles/perfiles_rda.g.dart';
import 'contexto.dart';

/// Procedimiento CUPS. Realizado → `ProcedureRDA`; ordenado →
/// `ServiceRequestRDA`. En consulta externa los procedimientos ordenados
/// viajan como `ServiceRequestRDA`; `ProcedureRDA` pertenece a urgencias y
/// hospitalización. Sin datos de origen en el repositorio (exámenes e
/// interconsultas son texto libre): el mapper queda listo para cuando los
/// haya.
({String perfil, Map<String, Object?> recurso}) mapearProcedimiento(
  ProcedimientoDto p,
  ContextoMapeo c, {
  required String id,
  required String idPaciente,
  required String idEncuentro,
  required String idProfesional,
  String? idDiagnosticoPrincipal,
  String? idDiagnosticoRelacionado,
}) => p.realizado
    ? (
        perfil: PerfilRda.procedureRDA,
        recurso: _realizado(
          p,
          c,
          id,
          idPaciente,
          idEncuentro,
          idProfesional,
          idDiagnosticoPrincipal,
          idDiagnosticoRelacionado,
        ),
      )
    : (
        perfil: PerfilRda.serviceRequestRDA,
        recurso: _ordenado(p, c, id, idPaciente, idEncuentro, idProfesional),
      );

Map<String, Object?> _realizado(
  ProcedimientoDto p,
  ContextoMapeo c,
  String id,
  String idPaciente,
  String idEncuentro,
  String idProfesional,
  String? idPrincipal,
  String? idRelacionado,
) {
  final f = Fijos('ProcedureRDA');
  if (idPrincipal == null || idRelacionado == null) {
    c.falta(
      'Procedure.reasonReference',
      'El procedimiento exige diagnóstico principal y relacionado',
    );
  }
  return {
    'resourceType': 'Procedure',
    'id': id,
    'meta': {
      'profile': [f.url],
    },
    'status': 'completed',
    'category': {
      'coding': [f.coding('Procedure.category.coding')],
    },
    'code': {
      'coding': [
        c.coding(
          f.texto('Procedure.code.coding.system'),
          p.cups,
          elemento: 'Procedure.code',
          dato: 'CUPS del procedimiento',
          valueSet: ConjuntoRda.coCUPSProcedures,
        ),
      ],
    },
    'subject': c.ref(idPaciente),
    'encounter': c.ref(idEncuentro),
    'performedDateTime': c.fechaHora(p.fecha),
    'performer': [
      {'actor': c.ref(idProfesional)},
    ],
    'reasonCode': [
      {
        'coding': [
          c.coding(
            f.texto('Procedure.reasonCode.coding.system'),
            p.finalidad,
            elemento: 'Procedure.reasonCode',
            dato: 'finalidad del procedimiento',
          ),
        ],
      },
    ],
    'reasonReference': [
      if (idPrincipal != null)
        {
          'id': f.texto('Procedure.reasonReference:MainDiagnosis.id'),
          ...c.ref(idPrincipal),
        },
      if (idRelacionado != null)
        {
          'id': f.texto('Procedure.reasonReference:Comobility.id'),
          ...c.ref(idRelacionado),
        },
    ],
  };
}

Map<String, Object?> _ordenado(
  ProcedimientoDto p,
  ContextoMapeo c,
  String id,
  String idPaciente,
  String idEncuentro,
  String idProfesional,
) {
  final f = Fijos('ServiceRequestRDA');
  return {
    'resourceType': 'ServiceRequest',
    'id': id,
    'meta': {
      'profile': [f.url],
    },
    'status': f.texto('ServiceRequest.status'),
    'intent': f.texto('ServiceRequest.intent'),
    'category': [
      {
        'coding': [f.coding('ServiceRequest.category.coding:R866')],
      },
    ],
    'code': {
      'coding': [
        c.coding(
          f.texto('ServiceRequest.code.coding.system'),
          p.cups,
          elemento: 'ServiceRequest.code',
          dato: 'CUPS de la orden',
          valueSet: ConjuntoRda.cupsProcedureCodes,
        ),
      ],
    },
    'subject': c.ref(idPaciente),
    'encounter': c.ref(idEncuentro),
    'authoredOn': c.fechaHora(p.fecha),
    'requester': c.ref(idProfesional),
    'reasonCode': [
      {
        'coding': [
          c.coding(
            f.texto('ServiceRequest.reasonCode.coding.system'),
            p.finalidad,
            elemento: 'ServiceRequest.reasonCode',
            dato: 'finalidad de la orden',
          ),
        ],
      },
    ],
  };
}
