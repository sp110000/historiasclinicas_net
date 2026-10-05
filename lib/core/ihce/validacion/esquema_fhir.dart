import 'dart:convert';

import 'package:json_schema/json_schema.dart';

import '../modelo/documento_rda.dart';

/// Capa 1 del gate: el JSON Schema oficial de FHIR R4 (`fhir.schema.json`,
/// 4.0.1, draft-06 con `discriminator` por `resourceType`). Se valida cada
/// recurso contra `#/definitions/{resourceType}` (mensajes legibles) y el
/// Bundle completo. Criterio: cero errores. Corre en las pruebas y en el
/// pipeline previo al envío: un Bundle inválido nunca llega a la red.
class ValidadorEsquemaFhir {
  ValidadorEsquemaFhir._(this._raiz);

  /// [esquema]: el contenido de `assets/ihce/fhir.schema.json`.
  factory ValidadorEsquemaFhir.desdeTexto(String esquema) =>
      ValidadorEsquemaFhir._(
        JsonSchema.create(
          jsonDecode(esquema) as Map<String, dynamic>,
          schemaVersion: SchemaVersion.draft6,
        ),
      );

  final JsonSchema _raiz;
  final _porTipo = <String, JsonSchema?>{};

  JsonSchema? _definicion(String tipo) => _porTipo.putIfAbsent(tipo, () {
    try {
      return _raiz.resolvePath(Uri.parse('#/definitions/$tipo'));
    } on Object {
      return null;
    }
  });

  /// Errores de un recurso suelto.
  List<IhceIssue> validarRecurso(Object? recurso, {String ruta = ''}) {
    if (recurso is! Map || recurso['resourceType'] is! String) {
      return [
        IhceIssue(
          severity: 'error',
          code: 'structure',
          diagnostics: 'No es un recurso FHIR (falta resourceType)',
          location: [ruta],
        ),
      ];
    }
    final tipo = recurso['resourceType'] as String;
    final esquema = _definicion(tipo);
    if (esquema == null) {
      return [
        IhceIssue(
          severity: 'error',
          code: 'structure',
          diagnostics: 'resourceType desconocido en FHIR R4: $tipo',
          location: [ruta],
        ),
      ];
    }
    final resultado = esquema.validate(recurso);
    return [
      for (final e in resultado.errors)
        IhceIssue(
          severity: 'error',
          code: 'structure',
          diagnostics: e.message,
          location: ['$ruta${e.instancePath}'],
        ),
    ];
  }

  /// Errores del Bundle: cada entrada contra su definición y el Bundle
  /// completo (estructura y `ResourceList`).
  List<IhceIssue> validarBundle(Map<String, Object?> bundle) {
    final errores = <IhceIssue>[];
    final entradas = (bundle['entry'] as List?) ?? const [];
    for (var i = 0; i < entradas.length; i++) {
      final recurso = entradas[i] is Map
          ? (entradas[i] as Map)['resource']
          : null;
      errores.addAll(
        validarRecurso(recurso, ruta: 'Bundle.entry[$i].resource'),
      );
    }
    if (errores.isEmpty) errores.addAll(validarRecurso(bundle, ruta: 'Bundle'));
    return errores;
  }
}
