// Genera, desde los artefactos de la guía fijados en vendor/fhir/VERSIONS.lock
// (tool/ihce/fetch_fhir_tooling.sh), todo lo que el código y la
// documentación toman de los perfiles del RDA. Ninguna regla de perfil se
// escribe a mano:
//
//   docs/ihce/PERFILES_RDA.md            perfiles legibles
//   lib/core/ihce/perfiles/perfiles_rda.g.dart   URLs, sistemas, valores fijos,
//                                        secciones y entradas de cada RDA
//   assets/ihce/catalogos_guia.json      code → display de los CodeSystems
//
//   dart run tool/ihce/generar_perfiles.dart
import 'dart:convert';
import 'dart:io';

const dirGuia = 'vendor/fhir/minsalud.fhir.co.rda';
const dirR4 = 'vendor/fhir/hl7.fhir.r4.core';
const lock = 'vendor/fhir/VERSIONS.lock';
const salidaMd = 'docs/ihce/PERFILES_RDA.md';
const salidaDart = 'lib/core/ihce/perfiles/perfiles_rda.g.dart';
const salidaCatalogos = 'assets/ihce/catalogos_guia.json';
const baseRda = 'https://fhir.minsalud.gov.co/rda/';

/// Perfiles del RDA que este proyecto emite (P0 y P1). Los de Gestión
/// Farmacéutica quedan fuera de alcance.
const fueraDeAlcance = {
  'MedicationRequestAddressing',
  'MedicationRequestScheduling',
  'MedicationDispenseRDA',
  'PharmacyLocationGF',
  'PharmacyOrganizationGF',
  'PharmacyLocation',
};

late final Map<String, Map<String, Object?>> sds;

void main() {
  if (!File(lock).existsSync()) {
    stderr.writeln('Falta $lock: ejecuta tool/ihce/fetch_fhir_tooling.sh');
    exit(1);
  }
  final meta = <String, String>{
    for (final l in File(lock).readAsLinesSync())
      if (l.startsWith('# ') && l.contains(': '))
        l.substring(2, l.indexOf(': ')): l.substring(l.indexOf(': ') + 2),
  };
  sds = {
    for (final f in Directory(dirGuia).listSync().whereType<File>())
      if (f.path.contains('StructureDefinition-'))
        (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>()['id']
            as String: (jsonDecode(f.readAsStringSync()) as Map)
            .cast<String, Object?>(),
  };
  final codeSystems = [
    for (final f in [
      ...Directory(dirGuia).listSync().whereType<File>(),
      ...Directory(dirR4).listSync().whereType<File>(),
    ])
      if (f.path.contains('CodeSystem-'))
        (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>(),
  ]..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  final valueSets = [
    for (final f in Directory(dirGuia).listSync().whereType<File>())
      if (f.path.contains('ValueSet-'))
        (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>(),
  ]..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

  final ids = sds.keys.toList()..sort();
  final perfiles = [
    for (final id in ids)
      if (sds[id]!['type'] != 'Extension' && !fueraDeAlcance.contains(id)) id,
  ];
  final extensiones = [
    for (final id in ids)
      if (sds[id]!['type'] == 'Extension') id,
  ];

  _escribirMarkdown(meta, perfiles, extensiones, codeSystems);
  _escribirDart(meta, ids, perfiles, codeSystems, valueSets);
  _escribirCatalogos(meta, codeSystems, valueSets);
  final formato = Process.runSync(Platform.resolvedExecutable, [
    'format',
    salidaDart,
  ]);
  if (formato.exitCode != 0) {
    stderr.writeln(formato.stderr);
    exit(1);
  }
  stdout.writeln('Generados $salidaMd, $salidaDart y $salidaCatalogos');
}

// ───────────────────────── Lectura de perfiles ─────────────────────────

List<Map<String, Object?>> elementos(String id) => [
  for (final e
      in ((sds[id]!['snapshot'] as Map)['element'] as List).cast<Map>())
    e.cast<String, Object?>(),
];

String tipos(Map<String, Object?> e) {
  final t = (e['type'] as List?)?.cast<Map>() ?? const [];
  return t
      .map((x) {
        final code = (x['code'] as String).replaceFirst(
          'http://hl7.org/fhirpath/System.',
          '',
        );
        final perfiles = [
          ...((x['profile'] as List?) ?? const []),
          ...((x['targetProfile'] as List?) ?? const []),
        ].cast<String>().map((p) => p.split('/').last);
        return perfiles.isEmpty ? code : '$code(${perfiles.join(', ')})';
      })
      .join(' | ');
}

Iterable<MapEntry<String, Object?>> fijos(Map<String, Object?> e) => e.entries
    .where((x) => x.key.startsWith('fixed') || x.key.startsWith('pattern'));

/// Elementos de interés: los que no cuelgan de un elemento prohibido (0..0).
List<Map<String, Object?>> relevantes(String id) {
  final prohibidos = <String>[];
  final r = <Map<String, Object?>>[];
  for (final e in elementos(id)) {
    final eid = e['id'] as String;
    if (prohibidos.any((p) => eid.startsWith('$p.') || eid.startsWith('$p:'))) {
      continue;
    }
    if (e['max'] == '0') {
      prohibidos.add(eid);
      continue;
    }
    r.add(e);
  }
  return r;
}

/// Ruido heredado: `Extension.url` y `.id`, `.extension` de la base.
bool ruido(Map<String, Object?> e) {
  final eid = e['id'] as String;
  final ultimo = eid.split('.').last;
  return (ultimo == 'url' && fijos(e).isNotEmpty) ||
      (ultimo == 'id' && e['min'] == 0) ||
      ((ultimo == 'extension' || ultimo == 'modifierExtension') &&
          e['min'] == 0 &&
          e['slicing'] == null);
}

String card(Map<String, Object?> e) => '${e['min']}..${e['max']}';

String md(Object? v) =>
    jsonEncode(v).replaceAll('|', r'\|').replaceAll('\n', ' ');

// ───────────────────────── Markdown ─────────────────────────

void _escribirMarkdown(
  Map<String, String> meta,
  List<String> perfiles,
  List<String> extensiones,
  List<Map<String, Object?>> codeSystems,
) {
  final b = StringBuffer()
    ..writeln('# Perfiles del RDA (generado)')
    ..writeln()
    ..writeln(
      '> **No editar a mano.** Generado por `dart run tool/ihce/generar_perfiles.dart` '
      'desde los StructureDefinitions de la guía fijados en `vendor/fhir/VERSIONS.lock`.',
    )
    ..writeln('>')
    ..writeln(
      '> Guía `${meta['guia_paquete']}` (versión declarada '
      '${meta['guia_version_declarada']}), compilación `${meta['compilacion_guia']}`, '
      'último cambio rotulado ${meta['ultimo_cambio_guia']}. '
      'La versión no identifica el contenido (D5): vale la huella.',
    )
    ..writeln()
    ..writeln(
      'Por perfil: URL canónica, elementos con `min ≥ 1`, must-support, valores '
      'fijos y patrones, slices con su discriminador, bindings `required` e '
      'invariantes propias del perfil. Se omiten los elementos que cuelgan de '
      'uno prohibido (`0..0`) y el ruido heredado (`Extension.url` fijo, `id` y '
      '`extension` opcionales sin slicing).',
    )
    ..writeln()
    ..writeln(
      '**Slices discriminados por `id`** (marcados ⚑): obligan a emitir ese `id` '
      'dentro del elemento de la instancia.',
    )
    ..writeln()
    ..writeln('## Índice')
    ..writeln();
  for (final id in perfiles) {
    b.writeln('- [$id](#${id.toLowerCase()}) — `${sds[id]!['type']}`');
  }
  b
    ..writeln('- [Extensiones](#extensiones)')
    ..writeln('- [CodeSystems](#codesystems)')
    ..writeln();

  for (final id in perfiles) {
    final sd = sds[id]!;
    b
      ..writeln('## $id')
      ..writeln()
      ..writeln('- URL: `${sd['url']}`')
      ..writeln('- Tipo: `${sd['type']}`; base: `${sd['baseDefinition']}`');
    final desc = (sd['description'] as String?)?.trim();
    if (desc != null && desc.isNotEmpty) {
      b.writeln('- Descripción: ${desc.replaceAll('\n', ' ')}');
    }
    b.writeln();
    final rel = relevantes(id);

    final porId = {for (final e in elementos(id)) e['id'] as String: e};
    // Obligatorio efectivo: él y todos sus ancestros tienen min ≥ 1.
    String? padreOpcional(String eid) {
      // El primer segmento es la raíz del recurso: no cuenta.
      for (
        var i = eid.indexOf('.', eid.indexOf('.') + 1);
        i > 0;
        i = eid.indexOf('.', i + 1)
      ) {
        final ancestro = porId[eid.substring(0, i)];
        if (ancestro != null && (ancestro['min'] as int) == 0) {
          return eid.substring(0, i);
        }
      }
      return null;
    }

    final obligatorios = [
      for (final e in rel)
        if ((e['min'] as int) >= 1 && !ruido(e)) e,
    ];
    b
      ..writeln('### Obligatorios (min ≥ 1)')
      ..writeln()
      ..writeln(
        'Condicional: obligatorio solo si existe el ancestro opcional indicado.',
      )
      ..writeln()
      ..writeln('| Elemento | Card. | Tipo | Condicional |')
      ..writeln('| --- | --- | --- | --- |');
    for (final e in obligatorios) {
      final padre = padreOpcional(e['id'] as String);
      b.writeln(
        '| `${e['id']}` | ${card(e)} | ${tipos(e)} | '
        '${padre == null ? '' : 'si `$padre`'} |',
      );
    }
    b.writeln();

    final ms = [
      for (final e in rel)
        if (e['mustSupport'] == true && (e['min'] as int) == 0 && !ruido(e)) e,
    ];
    if (ms.isNotEmpty) {
      b
        ..writeln('### Must-support opcionales')
        ..writeln()
        ..writeln(ms.map((e) => '`${e['id']}` ${card(e)}').join(' · '))
        ..writeln();
    }

    final conFijos = [
      for (final e in rel)
        if (fijos(e).isNotEmpty && !ruido(e)) e,
    ];
    if (conFijos.isNotEmpty) {
      b
        ..writeln('### Valores fijos y patrones')
        ..writeln()
        ..writeln('| Elemento | Clave | Valor |')
        ..writeln('| --- | --- | --- |');
      for (final e in conFijos) {
        for (final f in fijos(e)) {
          b.writeln('| `${e['id']}` | `${f.key}` | `${md(f.value)}` |');
        }
      }
      b.writeln();
    }

    final cortes = [
      for (final e in rel)
        if (e['slicing'] != null &&
            !((e['id'] as String).endsWith('extension') &&
                e['min'] == 0 &&
                !rel.any(
                  (x) =>
                      (x['id'] as String).startsWith('${e['id']}:') &&
                      x['sliceName'] != null,
                )))
          e,
    ];
    if (cortes.isNotEmpty) {
      b
        ..writeln('### Slices')
        ..writeln()
        ..writeln('| Elemento | Discriminador | Reglas | Slices |')
        ..writeln('| --- | --- | --- | --- |');
      for (final e in cortes) {
        final s = (e['slicing'] as Map).cast<String, Object?>();
        final disc = ((s['discriminator'] as List?) ?? const [])
            .cast<Map>()
            .map((d) => '${d['type']}:${d['path']}')
            .join(', ');
        final porId = disc.contains(':id') ? ' ⚑' : '';
        final eid = e['id'] as String;
        final hijos = [
          for (final x in elementos(id))
            if (x['sliceName'] != null &&
                (x['id'] as String).startsWith('$eid:') &&
                !(x['id'] as String).substring(eid.length + 1).contains('.'))
              '`${x['sliceName']}` ${card(x)}'
                  '${tipos(x).isEmpty ? '' : ' ${tipos(x)}'}',
        ];
        b.writeln(
          '| `$eid` | $disc$porId | ${s['rules']}'
          '${s['ordered'] == true ? ', ordenado' : ''} | ${hijos.join('<br>')} |',
        );
      }
      b.writeln();
    }

    final bindings = <String>{};
    for (final e in rel) {
      final bnd = (e['binding'] as Map?)?.cast<String, Object?>();
      if (bnd == null || bnd['strength'] != 'required') continue;
      final vs = bnd['valueSet'] as String? ?? '';
      if (vs.startsWith('http://hl7.org/fhir/ValueSet/') &&
          !vs.startsWith(baseRda)) {
        continue; // bindings de la especificación base
      }
      bindings.add('| `${e['id']}` | `$vs` |');
    }
    if (bindings.isNotEmpty) {
      b
        ..writeln('### Bindings `required` de la guía')
        ..writeln()
        ..writeln('| Elemento | ValueSet |')
        ..writeln('| --- | --- |')
        ..writeAll(bindings, '\n')
        ..writeln()
        ..writeln();
    }

    final invariantes = <String>{};
    for (final e in rel) {
      for (final c
          in ((e['constraint'] as List?) ?? const []).cast<Map>().where(
            (c) => (c['source'] as String?)?.startsWith(baseRda) ?? false,
          )) {
        invariantes.add(
          '| `${c['key']}` | ${c['severity']} | `${e['id']}` | '
          '${(c['human'] as String).replaceAll('|', r'\|').replaceAll('\n', ' ')} | '
          '`${(c['expression'] as String? ?? '').replaceAll('|', r'\|').replaceAll('\n', ' ')}` |',
        );
      }
    }
    if (invariantes.isNotEmpty) {
      b
        ..writeln('### Invariantes del perfil')
        ..writeln()
        ..writeln('| Clave | Severidad | Elemento | Regla | Expresión |')
        ..writeln('| --- | --- | --- | --- | --- |')
        ..writeAll(invariantes, '\n')
        ..writeln()
        ..writeln();
    }
  }

  b
    ..writeln('## Extensiones')
    ..writeln()
    ..writeln('| Id | URL | Contexto | value[x] |')
    ..writeln('| --- | --- | --- | --- |');
  for (final id in extensiones) {
    final sd = sds[id]!;
    final contexto = ((sd['context'] as List?) ?? const [])
        .cast<Map>()
        .map((c) => c['expression'])
        .join(', ');
    final valor = elementos(
      id,
    ).where((e) => (e['id'] as String) == 'Extension.value[x]');
    final tipoValor = valor.isEmpty
        ? ''
        : '${tipos(valor.first)} ${card(valor.first)}';
    b.writeln('| $id | `${sd['url']}` | $contexto | $tipoValor |');
  }
  b
    ..writeln()
    ..writeln('## CodeSystems')
    ..writeln()
    ..writeln(
      '`content = fragment`: la guía no trae el catálogo completo; los códigos '
      'que falten se cargan por sincronización (`GET /CodeSystem/{id}`) o por '
      'importación de las tablas SISPRO.',
    )
    ..writeln()
    ..writeln('| Id | URL (`system`) | content | Conceptos |')
    ..writeln('| --- | --- | --- | --- |');
  for (final cs in codeSystems) {
    b.writeln(
      '| ${cs['id']} | `${cs['url']}` | ${cs['content']} | '
      '${_aplanar(cs).length} |',
    );
  }
  File(salidaMd)
    ..createSync(recursive: true)
    ..writeAsStringSync(b.toString());
}

// ───────────────────────── Dart ─────────────────────────

String _camel(String id) {
  final partes = id.split(RegExp(r'[^A-Za-z0-9]+')).where((p) => p.isNotEmpty);
  final unido = [
    for (final (i, p) in partes.indexed)
      i == 0 ? p : p[0].toUpperCase() + p.substring(1),
  ].join();
  // Sigla inicial en minúsculas: CUPS → cups, ICD10CO → icd10co,
  // CUPSConsultationCodes → cupsConsultationCodes.
  final sigla = RegExp(r'^[A-Z]+').firstMatch(unido)?.group(0) ?? '';
  final siguiente = unido.length > sigla.length ? unido[sigla.length] : '';
  final corte = sigla.length > 1 && RegExp('[a-z]').hasMatch(siguiente)
      ? sigla.length - 1
      : sigla.length;
  return unido.substring(0, corte).toLowerCase() + unido.substring(corte);
}

String _lit(Object? v) {
  if (v == null) return 'null';
  if (v is String) {
    final escapado = v
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\n', r'\n');
    return "'$escapado'";
  }
  if (v is num || v is bool) return '$v';
  if (v is List) return '[${v.map(_lit).join(', ')}]';
  if (v is Map) {
    return '{${v.entries.map((e) => '${_lit(e.key)}: ${_lit(e.value)}').join(', ')}}';
  }
  throw ArgumentError(v);
}

void _escribirDart(
  Map<String, String> meta,
  List<String> ids,
  List<String> perfiles,
  List<Map<String, Object?>> codeSystems,
  List<Map<String, Object?>> valueSets,
) {
  final b = StringBuffer()
    ..writeln(
      '// GENERADO por tool/ihce/generar_perfiles.dart desde los artefactos de la',
    )
    ..writeln(
      '// guía fijados en vendor/fhir/VERSIONS.lock. No editar: regenerar.',
    )
    ..writeln('// ignore_for_file: lines_longer_than_80_chars')
    ..writeln()
    ..writeln("import 'modelo_perfil.dart';")
    ..writeln()
    ..writeln('/// Identidad de la compilación de la guía usada para generar.')
    ..writeln('abstract final class GuiaRda {')
    ..writeln("  static const paquete = '${meta['guia_paquete']}';")
    ..writeln(
      "  static const versionDeclarada = '${meta['guia_version_declarada']}';",
    )
    ..writeln("  static const compilacion = '${meta['compilacion_guia']}';")
    ..writeln("  static const ultimoCambio = '${meta['ultimo_cambio_guia']}';")
    ..writeln("  static const fhirVersion = '4.0.1';")
    ..writeln('}')
    ..writeln()
    ..writeln('/// URL canónica de cada StructureDefinition de la guía.')
    ..writeln('abstract final class PerfilRda {');
  for (final id in ids) {
    b.writeln("  static const ${_camel(id)} = '${sds[id]!['url']}';");
  }
  b
    ..writeln('}')
    ..writeln()
    ..writeln(
      '/// `url` de cada CodeSystem de la guía (el `system` de un Coding).',
    )
    ..writeln('abstract final class SistemaRda {');
  for (final cs in codeSystems) {
    b.writeln("  static const ${_camel(cs['id'] as String)} = '${cs['url']}';");
  }
  b
    ..writeln('}')
    ..writeln()
    ..writeln('/// URL canónica de cada ValueSet de la guía.')
    ..writeln('abstract final class ConjuntoRda {');
  for (final vs in valueSets) {
    b.writeln("  static const ${_camel(vs['id'] as String)} = '${vs['url']}';");
  }
  b
    ..writeln('}')
    ..writeln()
    ..writeln(
      '/// Valores `fixed[x]`/`pattern[x]` de cada perfil, por id de elemento.',
    )
    ..writeln('const fijosPorPerfil = <String, Map<String, Object?>>{');
  for (final id in perfiles) {
    final entradas = <String>[];
    for (final e in relevantes(id)) {
      for (final f in fijos(e)) {
        entradas.add(
          "    ${_lit(e['id'])}: ${_lit({'clave': f.key, 'valor': f.value})},",
        );
      }
    }
    b
      ..writeln("  '$id': {")
      ..writeAll(entradas, '\n')
      ..writeln(entradas.isEmpty ? '' : '')
      ..writeln('  },');
  }
  b
    ..writeln('};')
    ..writeln()
    ..writeln(
      '/// Elementos con `min >= 1` de cada perfil (sin los que cuelgan de un',
    )
    ..writeln(
      '/// elemento prohibido ni el ruido heredado), con su cardinalidad.',
    )
    ..writeln('const obligatoriosPorPerfil = <String, Map<String, String>>{');
  for (final id in perfiles) {
    b.writeln("  '$id': {");
    for (final e in relevantes(id)) {
      if ((e['min'] as int) >= 1 && !ruido(e)) {
        b.writeln("    ${_lit(e['id'])}: '${card(e)}',");
      }
    }
    b.writeln('  },');
  }
  b
    ..writeln('};')
    ..writeln()
    ..writeln(
      '/// Entradas admitidas por cada perfil Bundle*RDA (slicing cerrado).',
    )
    ..writeln('const entradasPorBundle = <String, List<EntradaPerfil>>{');
  for (final id in perfiles.where((p) => sds[p]!['type'] == 'Bundle')) {
    b.writeln("  '$id': [");
    for (final e in elementos(id)) {
      final eid = e['id'] as String;
      if (e['sliceName'] == null || !eid.startsWith('Bundle.entry:')) continue;
      if (eid.substring('Bundle.entry:'.length).contains('.')) continue;
      final recurso = elementos(
        id,
      ).firstWhere((x) => x['id'] == '$eid.resource', orElse: () => const {});
      final t = ((recurso['type'] as List?) ?? const []).cast<Map>();
      final tipo = t.isEmpty ? '' : t.first['code'] as String;
      final perfil = t.isEmpty
          ? null
          : ((t.first['profile'] as List?)?.cast<String>().firstOrNull);
      b.writeln(
        "    EntradaPerfil(slice: ${_lit(e['sliceName'])}, tipo: ${_lit(tipo)}, "
        "perfil: ${_lit(perfil)}, min: ${e['min']}, max: ${_lit(e['max'])}),",
      );
    }
    b.writeln('  ],');
  }
  b
    ..writeln('};')
    ..writeln()
    ..writeln(
      '/// Secciones de cada perfil Composition*RDA, en el orden del perfil.',
    )
    ..writeln('const seccionesPorComposition = <String, List<SeccionPerfil>>{');
  for (final id in perfiles.where((p) => sds[p]!['type'] == 'Composition')) {
    b.writeln("  '$id': [");
    final todos = elementos(id);
    for (final e in todos) {
      final eid = e['id'] as String;
      if (e['sliceName'] == null || !eid.startsWith('Composition.section:')) {
        continue;
      }
      if (eid.substring('Composition.section:'.length).contains('.')) continue;
      Map<String, Object?> hijo(String sufijo) => todos.firstWhere(
        (x) => x['id'] == '$eid.$sufijo',
        orElse: () => const {},
      );
      final titulo = hijo('title');
      final codigo = hijo('code');
      final entrada = hijo('entry');
      final vacio = hijo('emptyReason');
      final codigoFijo = fijos(codigo).firstOrNull?.value as Map?;
      final coding = (codigoFijo?['coding'] as List?)?.cast<Map>().first;
      final destinos = <String>{};
      for (final x in todos) {
        final xid = x['id'] as String;
        if (xid == '$eid.entry' || xid.startsWith('$eid.entry:')) {
          for (final t in ((x['type'] as List?) ?? const []).cast<Map>()) {
            destinos.addAll(
              ((t['targetProfile'] as List?) ?? const []).cast<String>(),
            );
          }
        }
      }
      destinos.remove('http://hl7.org/fhir/StructureDefinition/Resource');
      b.writeln(
        '    SeccionPerfil(slice: ${_lit(e['sliceName'])}, '
        'min: ${e['min']}, max: ${_lit(e['max'])}, '
        'titulo: ${_lit(fijos(titulo).firstOrNull?.value)}, '
        'tituloMin: ${titulo['min'] ?? 0}, '
        'sistema: ${_lit(coding?['system'])}, codigo: ${_lit(coding?['code'])}, '
        'display: ${_lit(coding?['display'])}, '
        'entradaMin: ${entrada['min'] ?? 0}, entradaMax: ${_lit(entrada['max'] ?? '*')}, '
        'emptyReasonPermitido: ${vacio.isNotEmpty && vacio['max'] != '0'}, '
        'perfilesEntrada: ${_lit(destinos.toList()..sort())}),',
      );
    }
    b.writeln('  ],');
  }
  b.writeln('};');
  File(salidaDart)
    ..createSync(recursive: true)
    ..writeAsStringSync(b.toString());
}

// ───────────────────────── Catálogos ─────────────────────────

/// Conceptos de un CodeSystem, aplanando la jerarquía.
Map<String, String> _aplanar(Map<String, Object?> cs) {
  final r = <String, String>{};
  void visitar(List<Map> conceptos) {
    for (final c in conceptos) {
      r[c['code'] as String] = (c['display'] as String?) ?? '';
      visitar(((c['concept'] as List?) ?? const []).cast<Map>());
    }
  }

  visitar(((cs['concept'] as List?) ?? const []).cast<Map>());
  return r;
}

void _escribirCatalogos(
  Map<String, String> meta,
  List<Map<String, Object?>> codeSystems,
  List<Map<String, Object?>> valueSets,
) {
  final catalogos = {
    for (final cs in codeSystems)
      cs['url'] as String: {
        'id': cs['id'],
        'version': cs['version'],
        'content': cs['content'],
        'conceptos': _aplanar(cs),
      },
  };
  // ValueSets por extensión (include de sistemas enteros o de conceptos).
  final conjuntos = {
    for (final vs in valueSets)
      vs['url'] as String: {
        'id': vs['id'],
        'include': [
          for (final inc
              in (((vs['compose'] as Map?)?['include'] as List?) ?? const [])
                  .cast<Map>())
            {
              'system': inc['system'],
              if (inc['concept'] != null)
                'codigos': [
                  for (final c in (inc['concept'] as List).cast<Map>())
                    c['code'],
                ],
              if (inc['filter'] != null) 'filtro': inc['filter'],
              if (inc['valueSet'] != null) 'valueSet': inc['valueSet'],
            },
        ],
      },
  };
  final salida = {
    'guia': meta['guia_paquete'],
    'compilacion': meta['compilacion_guia'],
    'codeSystems': catalogos,
    'valueSets': conjuntos,
  };
  File(salidaCatalogos)
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(salida));
}
