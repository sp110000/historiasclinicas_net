import '../config/config_ihce.dart';
import '../grafo/referencias.dart';
import '../perfiles/perfiles_rda.g.dart';
import '../terminologia/catalogo_terminologia.dart';

/// Dato obligatorio ausente o código fuera de catálogo: bloquea el RDA
/// localmente (`INVALIDO_LOCAL`). Nunca se rellena con valores inventados.
class FaltaDato {
  const FaltaDato(this.elemento, this.mensaje, {this.categoria = 'DATO'});

  /// Elemento FHIR del perfil (`Patient.birthDate`, …).
  final String elemento;

  /// Mensaje en lenguaje llano, sin datos del paciente.
  final String mensaje;

  /// `DATO` (falta el dato) o `SEMANTICO` (código ausente o inactivo en el
  /// catálogo cargado).
  final String categoria;

  @override
  String toString() => '$categoria $elemento: $mensaje';
}

/// Valores fijos y patrones de un perfil, leídos de los artefactos de la
/// guía (`fijosPorPerfil`, generado). Ningún valor fijo se escribe a mano.
class Fijos {
  Fijos(this.perfil) : _valores = fijosPorPerfil[perfil] ?? const {};

  final String perfil;
  final Map<String, Object?> _valores;

  /// Valor `fixed[x]`/`pattern[x]` de [elemento] (id del snapshot).
  Object? valor(String elemento) => (_valores[elemento] as Map?)?['valor'];

  /// Igual que [valor], pero exige que exista (error de programación si no).
  String texto(String elemento) {
    final v = valor(elemento);
    if (v is! String) {
      throw StateError('$perfil no fija $elemento');
    }
    return v;
  }

  /// `Coding` armado con los valores fijos de `prefijo.system|code|display`.
  Map<String, Object?> coding(String prefijo) {
    final r = {
      'system': ?valor('$prefijo.system'),
      'code': ?valor('$prefijo.code'),
      'display': ?valor('$prefijo.display'),
    };
    if (r.isEmpty) throw StateError('$perfil no fija $prefijo');
    return r;
  }

  /// `meta.profile` (fixedCanonical) del perfil.
  String get url => texto('${_tipo()}.meta.profile');

  String _tipo() {
    for (final k in _valores.keys) {
      if (k.endsWith('.meta.profile')) return k.split('.').first;
    }
    throw StateError('$perfil no fija meta.profile');
  }
}

/// Lo que comparten los mappers: catálogo, referencias (D1), zona horaria y
/// el registro de datos faltantes. Los mappers son funciones puras: no
/// hacen I/O.
class ContextoMapeo {
  ContextoMapeo({
    required this.config,
    required this.catalogo,
    required this.referencias,
  });

  final ConfigIhce config;
  final CatalogoTerminologia catalogo;
  final ReferenciasRda referencias;
  final faltantes = <FaltaDato>[];
  final advertencias = <FaltaDato>[];

  void falta(String elemento, String mensaje, {String categoria = 'DATO'}) =>
      faltantes.add(FaltaDato(elemento, mensaje, categoria: categoria));

  void advertir(String elemento, String mensaje) =>
      advertencias.add(FaltaDato(elemento, mensaje));

  Map<String, Object?> ref(String idLocal) => referencias.referencia(idLocal);

  /// `Coding` con el `display` del catálogo cargado. Si falta el código o no
  /// está en el catálogo (o en [valueSet]) registra el faltante y devuelve
  /// un `Coding` sin `display` para seguir reportando el resto.
  Map<String, Object?> coding(
    String system,
    String? code, {
    required String elemento,
    required String dato,
    String? valueSet,
  }) {
    if (code == null || code.trim().isEmpty) {
      falta(elemento, 'Falta $dato');
      return {'system': system};
    }
    final display = catalogo.display(system, code);
    if (display == null) {
      falta(
        elemento,
        'El código de $dato no está en el catálogo cargado',
        categoria: 'SEMANTICO',
      );
      return {'system': system, 'code': code};
    }
    if (valueSet != null && !catalogo.enValueSet(valueSet, system, code)) {
      falta(
        elemento,
        'El código de $dato no pertenece al conjunto de valores del perfil',
        categoria: 'SEMANTICO',
      );
    }
    return {'system': system, 'code': code, 'display': display};
  }

  /// `AAAA-MM-DD`.
  String fecha(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-${_dos(f.month)}-${_dos(f.day)}';

  /// `dateTime`/`instant` con segundos y la zona del consultorio. La app
  /// guarda la hora local sin zona.
  String fechaHora(DateTime local) =>
      '${fecha(local)}T${_dos(local.hour)}:${_dos(local.minute)}:'
      '${_dos(local.second)}${config.zonaHoraria}';

  static String _dos(int n) => n.toString().padLeft(2, '0');

  /// Narrativa XHTML mínima (Manual §5.4.3b) con el texto escapado.
  static Map<String, Object?> narrativa(String texto) => {
    'status': 'generated',
    'div':
        '<div xmlns="http://www.w3.org/1999/xhtml">${escaparXhtml(texto)}</div>',
  };

  static String escaparXhtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('\n', '<br/>');
}
