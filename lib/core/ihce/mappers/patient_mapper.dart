import '../modelo/dto.dart';
import '../perfiles/perfiles_rda.g.dart';
import '../terminologia/equivalencias.dart';
import 'contexto.dart';

/// `PatientRDA`. Origen: `datos.paciente` de la historia
/// (`lib/core/models/paciente.dart`). `id = {TipoDoc}-{NumDoc}`.
Map<String, Object?> mapearPaciente(
  PacienteDto p,
  ContextoMapeo c, {
  required String id,
}) {
  final f = Fijos('PatientRDA');
  const base = 'Patient';
  const ident = '$base.identifier:NationalPersonIdentifier';
  const nombre = '$base.name:OfficialPatientName';
  const direccion = '$base.address:HomeAddress';

  if (p.primerApellido.isEmpty) {
    c.falta('$nombre.family', 'Falta el primer apellido del paciente');
  }
  if (p.primerNombre.isEmpty) {
    c.falta('$nombre.given', 'Falta el nombre del paciente');
  }
  if (p.numeroDocumento.isEmpty) {
    c.falta('$ident.value', 'Falta el número de documento del paciente');
  }
  if (p.fechaNacimiento == null) {
    c.falta(
      '$base.birthDate',
      'Falta la fecha de nacimiento del paciente (solo hay edad aproximada)',
    );
  }
  if (p.ciudad.isEmpty) {
    c.falta('$direccion.city', 'Falta el municipio de residencia del paciente');
  }

  final genero = sexoAGenero[p.sexo];
  if (genero == null) {
    c.falta('$base.gender', 'Falta el sexo del paciente');
  }
  final pais = c.coding(
    SistemaRda.iso31661,
    p.paisResidencia,
    elemento: '$direccion.country.extension:ExtensionCountryCode',
    dato: 'país de residencia del paciente',
    valueSet: ConjuntoRda.iso31661N,
  );

  return {
    'resourceType': 'Patient',
    'id': id,
    'meta': {
      'profile': [f.url],
    },
    'extension': [
      {
        'url': PerfilRda.extensionPatientNationality,
        'valueCoding': c.coding(
          SistemaRda.iso31661,
          p.nacionalidad,
          elemento: '$base.extension:ExtensionPatientNationality',
          dato: 'nacionalidad del paciente',
          valueSet: ConjuntoRda.iso31661N,
        ),
      },
      {
        'url': PerfilRda.extensionPatientEthnicity,
        'valueCoding': c.coding(
          SistemaRda.colombianEthnicGroup,
          p.etnia,
          elemento: '$base.extension:ExtensionPatientEthnicity',
          dato: 'pertenencia étnica del paciente',
        ),
      },
      {
        'url': PerfilRda.extensionPatientDisability,
        'valueCoding': c.coding(
          SistemaRda.colombianDisabilityClassification,
          p.discapacidad,
          elemento: '$base.extension:ExtensionPatientDisability',
          dato: 'discapacidad del paciente',
        ),
      },
    ],
    'identifier': [
      {
        'id': f.texto('$ident.id'),
        'use': f.texto('$ident.use'),
        'type': {
          'coding': [
            f.coding('$ident.type.coding:InternationalCode'),
            c.coding(
              f.texto('$ident.type.coding:ColombianCode.system'),
              tipoDocumentoAColombianPersonIdentifier[p.tipoDocumento],
              elemento: '$ident.type.coding:ColombianCode',
              dato: 'tipo de documento del paciente',
              valueSet: ConjuntoRda.colombianPersonIdentifierCodes,
            ),
          ],
        },
        'system': f.texto('$ident.system'),
        'value': p.numeroDocumento,
      },
    ],
    'active': true,
    'name': [
      {
        'use': f.texto('$nombre.use'),
        'family': [
          p.primerApellido,
          p.segundoApellido,
        ].where((s) => s.isNotEmpty).join(' '),
        '_family': {
          'extension': [
            {
              'url': PerfilRda.extensionFathersFamilyName,
              'valueString': p.primerApellido,
            },
            if (p.segundoApellido.isNotEmpty)
              {
                'url': PerfilRda.extensionMothersFamilyName,
                'valueString': p.segundoApellido,
              },
          ],
        },
        'given': [
          p.primerNombre,
          if (p.segundoNombre.isNotEmpty) p.segundoNombre,
        ],
      },
    ],
    if (genero != null) 'gender': genero.$1,
    '_gender': {
      'extension': [
        {
          'url': PerfilRda.extensionBiologicalGender,
          'valueCoding': c.coding(
            sistemaSexoBiologico,
            genero?.$2,
            elemento: '$base.gender.extension:ExtensionBiologicalGender',
            dato: 'sexo biológico del paciente',
          ),
        },
      ],
    },
    if (p.fechaNacimiento != null) 'birthDate': c.fecha(p.fechaNacimiento!),
    'address': [
      {
        'id': f.texto('$direccion.id'),
        'extension': [
          {
            'url': PerfilRda.extensionResidenceZone,
            'valueCoding': c.coding(
              SistemaRda.colombianResidenceZone,
              p.zonaResidencia,
              elemento: '$direccion.extension:ExtensionResidenceZone',
              dato: 'zona de residencia del paciente',
            ),
          },
        ],
        'use': f.texto('$direccion.use'),
        'type': f.texto('$direccion.type'),
        'city': p.ciudad,
        'country': pais['display'] ?? '',
        '_country': {
          'extension': [
            {'url': PerfilRda.extensionCountryCode, 'valueCoding': pais},
          ],
        },
      },
    ],
  };
}
