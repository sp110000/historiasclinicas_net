/// Tablas de equivalencia de los códigos locales del repositorio a los
/// catálogos de la guía. Solo traducen códigos que el repositorio ya guarda
/// como dato estructurado: nunca se infiere un código desde texto libre.
/// Los `display` no están aquí: los da el [CatalogoTerminologia].
library;

import '../perfiles/perfiles_rda.g.dart';

/// Tipo de documento local (`perfilColombia.tiposDocumento`,
/// `lib/core/pais/perfil_pais.dart`) → `ColombianPersonIdentifier`. Los
/// códigos coinciden uno a uno con el CodeSystem de la guía.
const tipoDocumentoAColombianPersonIdentifier = <String, String>{
  'CC': 'CC',
  'TI': 'TI',
  'RC': 'RC',
  'CE': 'CE',
  'PA': 'PA',
  'PPT': 'PPT',
  'PE': 'PE',
  'CN': 'CN',
  'MS': 'MS',
  'AS': 'AS',
};

/// Documentos de extranjeros: el servidor no los valida contra el registro
/// nacional (Manual de Operaciones §5.4.4 b).
const documentosExtranjero = {
  'CE',
  'PA',
  'PPT',
  'PE',
  'CD',
  'SC',
  'PT',
  'DE',
  'PC',
};

/// Sin identificación (Manual §5.4.4 c).
const documentosSinIdentificacion = {'AS', 'MS', 'SI'};

/// Sexo local (`opcionesSexo`) → (`Patient.gender`, código
/// `ColombianGenderGroup` de `ExtensionBiologicalGender`).
const sexoAGenero = <String, (String administrativo, String biologico)>{
  'M': ('male', '01'),
  'F': ('female', '02'),
  'I': ('other', '03'),
};

/// Carácter del diagnóstico (`perfilColombia.caracteresDiagnostico`) →
/// `RIPSTipoDiagnosticoPrincipalVersion2` (01 Impresión diagnóstica,
/// 02 Confirmado nuevo, 03 Confirmado repetido).
const caracterATipoDiagnostico = <String, String>{
  'presuntivo': '01',
  'confirmado_nuevo': '02',
  'confirmado_repetido': '03',
};

/// Sistema de cada tabla anterior.
const sistemaTipoDocumento = SistemaRda.colombianPersonIdentifier;
const sistemaSexoBiologico = SistemaRda.colombianGenderGroup;
const sistemaTipoDiagnostico = SistemaRda.ripsTipoDiagnosticoPrincipalVersion2;
