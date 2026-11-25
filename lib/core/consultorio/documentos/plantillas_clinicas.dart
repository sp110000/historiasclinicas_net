// Plantillas de fábrica de los documentos clínicos (5.4): certificados,
// incapacidad, órdenes y remisión. Son borradores (VERIFICAR): la app no
// las deja usar hasta que las revises y apruebes en Ajustes. Los «______»
// se completan en el formulario antes de emitir.
//
// Los datos que cambian en cada documento (diagnóstico, días, fechas,
// finalidad, destino) no van en el texto: el formulario los pide aparte y
// el PDF los muestra en un bloque de datos, así cambiar uno no obliga a
// reescribir el texto.

import 'plantillas.dart';

Plantilla _p(
  TipoPlantilla tipo,
  String id,
  String nombre,
  String titulo,
  String cuerpo,
) => Plantilla(
  tipo: tipo,
  id: id == tipo.name ? null : id,
  nombre: nombre,
  versiones: [
    VersionPlantilla(version: 1, titulo: titulo, cuerpo: cuerpo.trim()),
  ],
);

/// Texto base de una plantilla nueva del tipo [tipo].
String cuerpoBaseClinico(TipoPlantilla tipo) => switch (tipo) {
  TipoPlantilla.certificado => _certificadoGeneral.trim(),
  TipoPlantilla.incapacidad => _incapacidad.trim(),
  TipoPlantilla.orden => _ordenEnBlanco.trim(),
  TipoPlantilla.remision => _remision.trim(),
  _ => '',
};

/// Plantillas de fábrica por id, en el orden en que se listan.
final Map<String, Plantilla> plantillasDeFabrica = {
  for (final p in [
    _p(
      TipoPlantilla.certificado,
      'certificado_general',
      'General',
      'Certificado médico',
      _certificadoGeneral,
    ),
    _p(
      TipoPlantilla.certificado,
      'certificado_laboral',
      'Laboral',
      'Certificado médico laboral',
      _certificadoLaboral,
    ),
    _p(
      TipoPlantilla.certificado,
      'certificado_deportivo',
      'Deportivo',
      'Certificado médico para actividad física y deporte',
      _certificadoDeportivo,
    ),
    _p(
      TipoPlantilla.certificado,
      'certificado_asistencia',
      'De asistencia',
      'Certificado de asistencia',
      _certificadoAsistencia,
    ),
    _p(
      TipoPlantilla.incapacidad,
      'incapacidad',
      'Incapacidad médica',
      'Certificado de incapacidad médica',
      _incapacidad,
    ),
    _p(
      TipoPlantilla.orden,
      'orden_perfil_metabolico',
      'Perfil metabólico',
      'Orden de laboratorio clínico',
      _ordenPerfilMetabolico,
    ),
    _p(
      TipoPlantilla.orden,
      'orden_tsh',
      'TSH',
      'Orden de laboratorio clínico',
      _ordenTsh,
    ),
    _p(
      TipoPlantilla.orden,
      'orden_hba1c',
      'HbA1c',
      'Orden de laboratorio clínico',
      _ordenHba1c,
    ),
    _p(
      TipoPlantilla.orden,
      'orden_perfil_lipidico',
      'Perfil lipídico',
      'Orden de laboratorio clínico',
      _ordenPerfilLipidico,
    ),
    _p(
      TipoPlantilla.orden,
      'orden_funcion_hepatica',
      'Función hepática',
      'Orden de laboratorio clínico',
      _ordenFuncionHepatica,
    ),
    _p(
      TipoPlantilla.orden,
      'orden_imagenes',
      'Imágenes diagnósticas',
      'Orden de imágenes diagnósticas',
      _ordenImagenes,
    ),
    _p(
      TipoPlantilla.remision,
      'remision',
      'Remisión o interconsulta',
      'Remisión / interconsulta',
      _remision,
    ),
  ])
    p.id: p,
};

// Ley 23 de 1981, arts. 50 a 52 (VERIFICAR): el certificado es claro,
// preciso, ceñido a la verdad e indica para qué se expide (la finalidad va
// en el bloque de datos).
const _certificadoGeneral = '''
El suscrito médico, {{medico}}, {{registroMedico}}, certifica que el {{fecha}} valoró a {{paciente}}, identificado(a) con {{documentoPaciente}}, de {{edad}}.

Hallazgos: ______

Concepto: ______
''';

// Las evaluaciones médicas ocupacionales (de ingreso, periódicas y de
// retiro) tienen su propia norma y pueden exigir licencia en seguridad y
// salud en el trabajo (VERIFICAR): este es un certificado médico general
// con destino laboral.
const _certificadoLaboral = '''
El suscrito médico, {{medico}}, {{registroMedico}}, certifica que el {{fecha}} valoró a {{paciente}}, identificado(a) con {{documentoPaciente}}, de {{edad}}, en relación con el cargo o la actividad de ______.

Hallazgos: ______

Concepto: ______

Restricciones o recomendaciones: ______
''';

const _certificadoDeportivo = '''
El suscrito médico, {{medico}}, {{registroMedico}}, certifica que el {{fecha}} valoró a {{paciente}}, identificado(a) con {{documentoPaciente}}, de {{edad}}, para la práctica de ______.

Hallazgos: ______

Concepto: al momento de la valoración, ______ contraindicación médica para la actividad descrita.

Recomendaciones: ______
''';

const _certificadoAsistencia = '''
El suscrito médico, {{medico}}, {{registroMedico}}, certifica que {{paciente}}, identificado(a) con {{documentoPaciente}}, asistió a consulta médica el {{fecha}}, de ______ a ______.
''';

// Decreto 1427 de 2022 (VERIFICAR): diagnóstico, días, fechas, prórroga y
// datos del prestador van en el bloque de datos del PDF.
const _incapacidad = '''
El suscrito médico, {{medico}}, {{registroMedico}}, certifica que {{paciente}}, identificado(a) con {{documentoPaciente}}, requiere incapacidad médica por el diagnóstico, los días y las fechas que se indican en este documento.

Recomendaciones: ______
''';

const _ordenPerfilMetabolico = '''
Solicito los siguientes exámenes:
- Glucosa en ayunas
- Hemoglobina glicosilada (HbA1c)
- Colesterol total, colesterol HDL, colesterol LDL y triglicéridos
- Creatinina
- Alanina aminotransferasa (ALT) y aspartato aminotransferasa (AST)

Observaciones: ______
''';

const _ordenTsh = '''
Solicito los siguientes exámenes:
- Hormona estimulante de la tiroides (TSH)

Observaciones: ______
''';

const _ordenHba1c = '''
Solicito los siguientes exámenes:
- Hemoglobina glicosilada (HbA1c)

Observaciones: ______
''';

const _ordenPerfilLipidico = '''
Solicito los siguientes exámenes:
- Colesterol total
- Colesterol HDL
- Colesterol LDL
- Triglicéridos

Observaciones: ______
''';

const _ordenFuncionHepatica = '''
Solicito los siguientes exámenes:
- Alanina aminotransferasa (ALT)
- Aspartato aminotransferasa (AST)
- Fosfatasa alcalina
- Gamma glutamil transferasa (GGT)
- Bilirrubina total y directa

Observaciones: ______
''';

const _ordenImagenes = '''
Solicito el siguiente estudio:
- Estudio: ______
- Región: ______

Información clínica para quien lo realiza: ______
''';

const _ordenEnBlanco = '''
Solicito los siguientes exámenes:
- ______

Observaciones: ______
''';

const _remision = '''
Remito al paciente para valoración y manejo por la especialidad o el servicio que se indica.

Motivo de la remisión: ______

Resumen de la historia clínica: ______

Tratamiento actual: ______

Pregunta o solicitud concreta: ______
''';
