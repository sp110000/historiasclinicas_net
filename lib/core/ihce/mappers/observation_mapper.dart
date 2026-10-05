import '../modelo/dto.dart';
import '../perfiles/perfiles_rda.g.dart';
import 'contexto.dart';

/// `Observation`: no existe un perfil genérico. Cada variante instancia un
/// perfil de la guía:
///
/// * [OcupacionDto] → `PatientOccupationAtEncounterRDA`
/// * [IncapacidadDto] → `AttendanceAllowanceRDA`
///
/// `ObservationTriageRDA`, `ProcedureResultRDA` y
/// `ObservationClarificationNoteRDA` son de urgencias, hospitalización y
/// nota aclaratoria (P1): sin datos de origen en el repositorio. Lo que no
/// tiene perfil vigente (signos vitales) no entra al RDA.
({String perfil, Map<String, Object?> recurso}) mapearObservacion(
  ObservacionDto o,
  ContextoMapeo c, {
  required String id,
  required String idPaciente,
  required String idEncuentro,
}) => switch (o) {
  OcupacionDto() => (
    perfil: PerfilRda.patientOccupationAtEncounterRDA,
    recurso: _ocupacion(o, c, id, idPaciente),
  ),
  IncapacidadDto() => (
    perfil: PerfilRda.attendanceAllowanceRDA,
    recurso: _incapacidad(o, c, id, idPaciente, idEncuentro),
  ),
};

Map<String, Object?> _ocupacion(
  OcupacionDto o,
  ContextoMapeo c,
  String id,
  String idPaciente,
) {
  final f = Fijos('PatientOccupationAtEncounterRDA');
  return {
    'resourceType': 'Observation',
    'id': id,
    'meta': {
      'profile': [f.url],
    },
    'status': f.texto('Observation.status'),
    'code': {
      'coding': [f.coding('Observation.code.coding')],
      'text': f.texto('Observation.code.text'),
    },
    'subject': c.ref(idPaciente),
    'valueCodeableConcept': {
      'coding': [
        c.coding(
          SistemaRda.ciuo88AC,
          o.codigoCiuo,
          elemento: 'Observation.value[x]',
          dato: 'ocupación (CIUO-88 A.C.)',
        ),
      ],
    },
  };
}

Map<String, Object?> _incapacidad(
  IncapacidadDto o,
  ContextoMapeo c,
  String id,
  String idPaciente,
  String idEncuentro,
) {
  final f = Fijos('AttendanceAllowanceRDA');
  Map<String, Object?> codigo(String slice) => {
    'coding': [f.coding('Observation.component:$slice.code.coding')],
    'text': f.texto('Observation.component:$slice.code.text'),
  };
  Map<String, Object?> dias(String slice, int valor) => {
    'value': valor,
    'unit': f.texto('Observation.component:$slice.value[x]:valueQuantity.unit'),
    'system': f.texto(
      'Observation.component:$slice.value[x]:valueQuantity.system',
    ),
    'code': f.texto('Observation.component:$slice.value[x]:valueQuantity.code'),
  };
  return {
    'resourceType': 'Observation',
    'id': id,
    'meta': {
      'profile': [f.url],
    },
    'status': f.texto('Observation.status'),
    'code': {
      'coding': [f.coding('Observation.code.coding')],
      'text': f.texto('Observation.code.text'),
    },
    'subject': c.ref(idPaciente),
    'encounter': c.ref(idEncuentro),
    'component': [
      {
        'id': f.texto('Observation.component:LicenseScope.id'),
        'code': codigo('LicenseScope'),
        'valueCodeableConcept': {
          'coding': [
            c.coding(
              f.texto(
                'Observation.component:LicenseScope.value[x]:valueCodeableConcept.coding.system',
              ),
              o.alcance,
              elemento: 'Observation.component:LicenseScope',
              dato: 'alcance de la incapacidad',
            ),
          ],
        },
      },
      if (o.dias != null)
        {
          'id': f.texto('Observation.component:LicenseTime.id'),
          'code': codigo('LicenseTime'),
          'valueQuantity': dias('LicenseTime', o.dias!),
        },
      if (o.inicio != null && o.fin != null)
        {
          'id': f.texto('Observation.component:LicensePeriod.id'),
          'code': codigo('LicensePeriod'),
          'valuePeriod': {'start': c.fecha(o.inicio!), 'end': c.fecha(o.fin!)},
        },
      if (o.prospectiva != null)
        {
          'id': f.texto('Observation.component:Prospective.id'),
          'code': codigo('Prospective'),
          'valueBoolean': o.prospectiva,
        },
      if (o.retroactiva != null)
        {
          'id': f.texto('Observation.component:Retroactive.id'),
          'code': codigo('Retroactive'),
          'valueBoolean': o.retroactiva,
        },
      if (o.diasLicenciaMaternidad != null)
        {
          'id': f.texto('Observation.component:MaternityLicenseTime.id'),
          'code': codigo('MaternityLicenseTime'),
          'valueQuantity': dias(
            'MaternityLicenseTime',
            o.diasLicenciaMaternidad!,
          ),
        },
    ],
  };
}
