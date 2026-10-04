import 'dart:convert';

import '../modelo/documento_rda.dart';
import 'resultado.dart';

/// Cuerpo de respuesta interpretado de forma tolerante: acepta
/// `OperationOutcome` puro, anidado en un `Bundle`, JSON que no es FHIR,
/// HTML, vacío y JSON truncado. Nunca lanza.
class CuerpoInterpretado {
  const CuerpoInterpretado({
    required this.tipo,
    this.json,
    this.issues = const [],
  });

  /// `OperationOutcome`, `Bundle`, `json`, `html`, `vacio` o `ilegible`.
  final String tipo;
  final Map<String, Object?>? json;
  final List<IhceIssue> issues;
}

CuerpoInterpretado interpretarCuerpo(String cuerpo) {
  final t = cuerpo.trim();
  if (t.isEmpty) return const CuerpoInterpretado(tipo: 'vacio');
  if (t.startsWith('<')) return const CuerpoInterpretado(tipo: 'html');
  Object? decodificado;
  try {
    decodificado = jsonDecode(t);
  } on FormatException {
    return const CuerpoInterpretado(tipo: 'ilegible');
  }
  if (decodificado is! Map) return const CuerpoInterpretado(tipo: 'json');
  final m = decodificado.cast<String, Object?>();
  switch (m['resourceType']) {
    case 'OperationOutcome':
      return CuerpoInterpretado(
        tipo: 'OperationOutcome',
        json: m,
        issues: issuesDe(m),
      );
    case 'Bundle':
      final issues = <IhceIssue>[];
      for (final e in (m['entry'] as List?) ?? const []) {
        if (e is! Map) continue;
        final r = e['resource'];
        if (r is Map && r['resourceType'] == 'OperationOutcome') {
          issues.addAll(issuesDe(r.cast()));
        }
        final o = (e['response'] as Map?)?['outcome'];
        if (o is Map && o['resourceType'] == 'OperationOutcome') {
          issues.addAll(issuesDe(o.cast()));
        }
      }
      return CuerpoInterpretado(tipo: 'Bundle', json: m, issues: issues);
    default:
      return CuerpoInterpretado(tipo: 'json', json: m);
  }
}

List<IhceIssue> issuesDe(Map<String, Object?> oo) => [
  for (final i in (oo['issue'] as List?) ?? const [])
    if (i is Map)
      IhceIssue(
        severity: i['severity'] as String? ?? 'error',
        code: i['code'] as String? ?? 'unknown',
        detailsText: (i['details'] as Map?)?['text'] as String?,
        diagnostics: i['diagnostics'] as String?,
        location: [for (final l in (i['location'] as List?) ?? const []) '$l'],
        expression: [
          for (final l in (i['expression'] as List?) ?? const []) '$l',
        ],
      ),
];

const _codigosSintacticos = {
  'structure',
  'required',
  'value',
  'invalid',
  'invariant',
};
const _codigosSemanticos = {
  'code-invalid',
  'business-rule',
  'not-supported',
  'processing',
};
const _codigosIdentidad = {'not-found', 'multiple-matches'};
const _codigosDuplicado = {'duplicate', 'conflict'};
const _codigosAuth = {'login', 'expired', 'forbidden', 'security'};
const _codigosTransitorios = {
  'transient',
  'timeout',
  'throttled',
  'lock-error',
  'too-costly',
};
const _recursosIdentidad = {
  'Patient',
  'Practitioner',
  'Organization',
  'Location',
};

/// Categoría de una `issue` (señal secundaria: `issue.code`,
/// `location`/`expression` y el diagnóstico).
CategoriaError? categoriaDeIssue(
  IhceIssue i, {
  List<String> tiposPorEntrada = const [],
}) {
  final texto = '${i.diagnostics ?? ''} ${i.detailsText ?? ''}'.toLowerCase();
  final rutas = [...i.location, ...i.expression];
  final recurso = rutas
      .map((r) => recursoDeRuta(r, tiposPorEntrada))
      .whereType<String>()
      .firstOrNull;
  final textoIdentidad = const [
    'evol',
    'maestro persona',
    'registro nacional',
    'reps',
    'rethus',
    'habilitad',
  ].any(texto.contains);
  if (_codigosAuth.contains(i.code)) return CategoriaError.auth;
  if (_codigosDuplicado.contains(i.code)) return CategoriaError.duplicado;
  if (_codigosTransitorios.contains(i.code)) return CategoriaError.transitorio;
  if (_codigosIdentidad.contains(i.code) || textoIdentidad) {
    return CategoriaError.identidad;
  }
  if (i.code == 'code-invalid' ||
      texto.contains('codesystem') ||
      texto.contains('display')) {
    return CategoriaError.semantico;
  }
  if (_recursosIdentidad.contains(recurso) &&
      (i.code == 'business-rule' || i.code == 'processing')) {
    return CategoriaError.identidad;
  }
  if (_codigosSemanticos.contains(i.code)) return CategoriaError.semantico;
  if (_codigosSintacticos.contains(i.code)) return CategoriaError.sintactico;
  return null;
}

/// Tipo de recurso al que apunta una ruta FHIRPath o de `location`
/// (`Bundle.entry[4].resource.code` → el tipo de la entrada 4;
/// `Patient.name[0]` → `Patient`).
String? recursoDeRuta(String ruta, List<String> tiposPorEntrada) {
  final m = RegExp(r'^Bundle\.entry\[(\d+)\]').firstMatch(ruta);
  if (m != null) {
    final i = int.parse(m.group(1)!);
    return i < tiposPorEntrada.length ? tiposPorEntrada[i] : null;
  }
  final primero = RegExp(r'^([A-Z][A-Za-z]+)').firstMatch(ruta)?.group(1);
  return primero == 'Bundle' ? null : primero;
}

/// Prioridad de la categoría global, entre las `issue` fatal o error:
/// AUTH > IDENTIDAD > SEMANTICO > SINTACTICO.
const _prioridad = [
  CategoriaError.auth,
  CategoriaError.duplicado,
  CategoriaError.identidad,
  CategoriaError.semantico,
  CategoriaError.sintactico,
  CategoriaError.transitorio,
];

/// Clasificación de una respuesta no exitosa. Señal primaria: el estado
/// HTTP; secundaria: las `issue`.
CategoriaError clasificar(
  int status,
  List<IhceIssue> issues, {
  List<String> tiposPorEntrada = const [],
}) {
  if (status == 401 || status == 403) return CategoriaError.auth;
  if (status == 409) return CategoriaError.duplicado;
  if (status == 408 || status == 429 || status >= 500) {
    // 5xx con issues no transitorias: igual se reintenta (tabla).
    return CategoriaError.transitorio;
  }
  final categorias = {
    for (final i in issues.where((i) => i.esError))
      ?categoriaDeIssue(i, tiposPorEntrada: tiposPorEntrada),
  };
  for (final c in _prioridad) {
    if (categorias.contains(c)) {
      if (c == CategoriaError.transitorio) continue;
      return c;
    }
  }
  if (status == 400 || status == 422) {
    return issues.isEmpty
        ? CategoriaError.desconocido
        : CategoriaError.sintactico;
  }
  if (status == 404) return CategoriaError.identidad;
  return CategoriaError.desconocido;
}
