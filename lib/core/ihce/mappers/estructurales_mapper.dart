import 'dart:convert';

import '../modelo/dto.dart';
import '../perfiles/perfiles_rda.g.dart';
import 'contexto.dart';

/// `AllergyIntoleranceRDA`. Exige categoría `TipoAlergia` (binding
/// required) además del texto: el repositorio guarda etiquetas libres y no
/// se infieren códigos desde texto, así que hoy la sección va con
/// `emptyReason` y narrativa (MATRIZ_RDA §3).
Map<String, Object?> mapearAlergia(
  AlergiaDto a,
  ContextoMapeo c, {
  required String id,
  required String idPaciente,
  required String idEncuentro,
}) {
  final f = Fijos('AllergyIntoleranceRDA');
  final sistemaEstado = f.texto(
    'AllergyIntolerance.clinicalStatus.coding.system',
  );
  return {
    'resourceType': 'AllergyIntolerance',
    'id': id,
    'meta': {
      'profile': [f.url],
    },
    'clinicalStatus': {
      'coding': [
        c.coding(
          sistemaEstado,
          'active',
          elemento: 'AllergyIntolerance.clinicalStatus',
          dato: 'estado clínico de la alergia',
        ),
      ],
    },
    'verificationStatus': {
      'coding': [f.coding('AllergyIntolerance.verificationStatus.coding')],
    },
    'code': {
      'coding': [
        c.coding(
          f.texto('AllergyIntolerance.code.coding.system'),
          a.tipo,
          elemento: 'AllergyIntolerance.code',
          dato: 'tipo de alergia',
        ),
      ],
      'text': a.texto,
    },
    'patient': c.ref(idPaciente),
    'encounter': c.ref(idEncuentro),
  };
}

/// `DocumentReferenceEPIRDA`: PDF de soporte (con capa de texto, sin
/// contraseña). El perfil prohíbe `attachment.contentType` (0..0): el tipo
/// va en `content.format` (D7).
Map<String, Object?> mapearDocumentoSoporte(
  List<int> pdf,
  ContextoMapeo c, {
  required String id,
  required String idPaciente,
  required String idEncuentro,
  required String idAutor,
  required DateTime fecha,
}) {
  final f = Fijos('DocumentReferenceEPIRDA');
  const d = 'DocumentReference';
  if (pdf.isEmpty) c.falta('$d.content.attachment', 'Falta el PDF de soporte');
  if (pdf.length > c.config.adjuntoMaxBytes) {
    c.falta(
      '$d.content.attachment',
      'El PDF de soporte supera el tamaño permitido',
    );
  }
  return {
    'resourceType': 'DocumentReference',
    'id': id,
    'meta': {
      'profile': [f.url],
    },
    'status': f.texto('$d.status'),
    'type': {
      'coding': [
        f.coding('$d.type.coding:LOINC'),
        f.coding('$d.type.coding:R2284'),
      ],
    },
    'category': [
      {
        'coding': [f.coding('$d.category.coding')],
      },
    ],
    'subject': c.ref(idPaciente),
    'date': c.fechaHora(fecha),
    'author': [c.ref(idAutor)],
    // Patrón del perfil: referencia externa fija a MinSalud.
    'custodian': {'reference': f.texto('$d.custodian.reference')},
    'description': f.texto('$d.description'),
    'securityLabel': [
      {
        'coding': [f.coding('$d.securityLabel.coding')],
      },
    ],
    'content': [
      {
        'attachment': {'data': base64Encode(pdf)},
        'format': f.coding('$d.content.format'),
      },
    ],
    'context': {
      'encounter': [c.ref(idEncuentro)],
    },
  };
}

/// URL de perfil de un recurso ya mapeado.
String perfilDe(Map<String, Object?> recurso) =>
    ((recurso['meta'] as Map?)?['profile'] as List?)?.first as String? ?? '';

/// Perfiles que admiten `encounter` (regla «mismo Encounter»).
const perfilesConEncuentro = {
  PerfilRda.allergyIntoleranceRDA,
  PerfilRda.attendanceAllowanceRDA,
  PerfilRda.serviceRequestRDA,
  PerfilRda.procedureRDA,
  PerfilRda.medicationRequestRDA,
};
