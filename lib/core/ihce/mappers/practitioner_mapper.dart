import '../modelo/dto.dart';
import '../perfiles/perfiles_rda.g.dart';
import '../terminologia/equivalencias.dart';
import 'contexto.dart';

/// `PractitionerRDA`. Origen: «Datos del médico» (`localStorage`,
/// `lib/core/models/medico.dart`). `id = {TipoDoc}-{NumDoc}`.
Map<String, Object?> mapearProfesional(
  ProfesionalDto p,
  ContextoMapeo c, {
  required String id,
}) {
  final f = Fijos('PractitionerRDA');
  const ident = 'Practitioner.identifier:NationalPersonIdentifier';
  const rethus = 'Practitioner.qualification:Rethus';

  if (p.numeroDocumento.isEmpty) {
    c.falta('$ident.value', 'Falta el documento de identidad del médico');
  }
  if (p.primerApellido.isEmpty) {
    c.falta('Practitioner.name.family', 'Falta el primer apellido del médico');
  }
  if (p.nombres.isEmpty) {
    c.falta('Practitioner.name.given', 'Faltan los nombres del médico');
  }

  return {
    'resourceType': 'Practitioner',
    'id': id,
    'meta': {
      'profile': [f.url],
    },
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
              dato: 'tipo de documento del médico',
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
        'use': f.texto('Practitioner.name.use'),
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
        'given': p.nombres,
      },
    ],
    'qualification': [
      {
        if (p.registro.isNotEmpty)
          'identifier': [
            {
              'use': f.texto('$rethus.identifier.use'),
              'type': {
                'coding': [f.coding('$rethus.identifier.type.coding')],
              },
              'system': f.texto('$rethus.identifier.system'),
              'value': p.registro,
            },
          ],
        'code': {
          'coding': [
            c.coding(
              f.texto('$rethus.code.coding.system'),
              p.codigoRethus,
              elemento: '$rethus.code',
              dato: 'profesión RETHUS del médico',
            ),
          ],
        },
      },
    ],
  };
}
