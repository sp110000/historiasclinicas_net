/// Diferencias de formulario entre los países donde se usa la app.
///
/// Todo lo normativo es **VERIFICAR** (ver docs/PLAN.md, "Perfiles por
/// país"): son valores de partida para que el médico los valide.
library;

enum Pais {
  colombia('CO', 'Colombia'),
  espana('ES', 'España');

  const Pais(this.codigo, this.nombre);

  final String codigo;
  final String nombre;

  static Pais desdeCodigo(String? codigo) =>
      values.firstWhere((p) => p.codigo == codigo, orElse: () => colombia);

  PerfilPais get perfil => switch (this) {
    colombia => perfilColombia,
    espana => perfilEspana,
  };
}

class Opcion {
  const Opcion(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;
}

class PerfilPais {
  const PerfilPais({
    required this.pais,
    required this.tiposDocumento,
    required this.etiquetaSignosVitales,
    required this.etiquetaCiudad,
    required this.etiquetaAseguradora,
    required this.caracteresDiagnostico,
  });

  final Pais pais;

  /// VERIFICAR: tipos de documento admitidos por la norma de cada país.
  final List<Opcion> tiposDocumento;

  /// "Signos vitales" (CO) o "Constantes vitales" (ES).
  final String etiquetaSignosVitales;
  final String etiquetaCiudad;
  final String etiquetaAseguradora;

  /// VERIFICAR: en Colombia se usa la clasificación de RIPS.
  final List<Opcion> caracteresDiagnostico;

  String etiquetaTipoDocumento(String codigo) => tiposDocumento
      .firstWhere(
        (o) => o.codigo == codigo,
        orElse: () => Opcion(codigo, codigo),
      )
      .etiqueta;

  String etiquetaCaracter(String codigo) =>
      [...caracteresDiagnostico, ...perfilColombia.caracteresDiagnostico]
          .firstWhere(
            (o) => o.codigo == codigo,
            orElse: () => Opcion(codigo, codigo),
          )
          .etiqueta;
}

/// Sexo registrado. VERIFICAR las categorías exigidas por cada norma.
const opcionesSexo = [
  Opcion('F', 'Femenino'),
  Opcion('M', 'Masculino'),
  Opcion('I', 'Intersexual'),
];

const opcionesTipoConsulta = [
  Opcion('primera_vez', 'Primera vez'),
  Opcion('control', 'Control'),
  Opcion('urgencia', 'Urgencia'),
  Opcion('interconsulta', 'Interconsulta'),
];

const opcionesTipoDiagnostico = [
  Opcion('principal', 'Principal'),
  Opcion('relacionado', 'Relacionado'),
];

const perfilColombia = PerfilPais(
  pais: Pais.colombia,
  tiposDocumento: [
    Opcion('CC', 'Cédula de ciudadanía'),
    Opcion('TI', 'Tarjeta de identidad'),
    Opcion('RC', 'Registro civil'),
    Opcion('CE', 'Cédula de extranjería'),
    Opcion('PA', 'Pasaporte'),
    Opcion('PPT', 'Permiso por protección temporal'),
    Opcion('PE', 'Permiso especial de permanencia'),
    Opcion('CN', 'Certificado de nacido vivo'),
    Opcion('MS', 'Menor sin identificación'),
    Opcion('AS', 'Adulto sin identificación'),
  ],
  etiquetaSignosVitales: 'Signos vitales',
  etiquetaCiudad: 'Municipio',
  etiquetaAseguradora: 'EPS / aseguradora',
  caracteresDiagnostico: [
    Opcion('presuntivo', 'Impresión diagnóstica'),
    Opcion('confirmado_nuevo', 'Confirmado nuevo'),
    Opcion('confirmado_repetido', 'Confirmado repetido'),
  ],
);

const perfilEspana = PerfilPais(
  pais: Pais.espana,
  tiposDocumento: [
    Opcion('DNI', 'DNI'),
    Opcion('NIE', 'NIE'),
    Opcion('PAS', 'Pasaporte'),
    Opcion('TSI', 'Tarjeta sanitaria (CIP)'),
    Opcion('OTRO', 'Otro'),
  ],
  etiquetaSignosVitales: 'Constantes vitales',
  etiquetaCiudad: 'Localidad',
  etiquetaAseguradora: 'Aseguradora / mutua',
  caracteresDiagnostico: [
    Opcion('presuntivo', 'Sospecha diagnóstica'),
    Opcion('confirmado_nuevo', 'Confirmado'),
  ],
);
