// Línea base de la capa 2 del gate (Fase 8). Solo dart:io y dart:convert.
//
//   dart tool/ihce/linea_base.dart extraer
//       Cuerpos de envío de la colección Postman v1.5 (copia saneada de
//       vendor/fhir/fuentes) → build/ihce/oficiales/postman-<op>.json.
//   dart tool/ihce/linea_base.dart generar
//       Escribe docs/ihce/validation-baseline.json: cada hallazgo `error` o
//       `fatal` de build/ihce/validation-report.json que se reproduce, con
//       el mismo mensaje y en la ruta equivalente, en el reporte de un
//       artefacto oficial (build/ihce/oficiales/*.report.json). Los que no
//       se reproducen NO entran y se listan.
//   dart tool/ihce/linea_base.dart comparar
//       Sale con código 1 si algún hallazgo `error`/`fatal` no está en la
//       línea base o si su evidencia ya no se reproduce en esta corrida.
//
// «Mismo mensaje y ruta equivalente»: se normalizan solo los índices de
// `entry` (por el tipo del recurso en esa posición), los demás índices, los
// comentarios `/*Tipo/id*/` del validador y los identificadores de las
// referencias (`'#CC-123'` → `'<ref>'`). El resto del texto debe coincidir.
import 'dart:convert';
import 'dart:io';

const _reporte = 'build/ihce/validation-report.json';
const _oficiales = 'build/ihce/oficiales';
const _lineaBase = 'docs/ihce/validation-baseline.json';
const _coleccion =
    'vendor/fhir/fuentes/postman_sandbox_prestadores_v1.5.saneada.json';

/// Operaciones de envío de la colección y el perfil Bundle de cada una.
const _envios = {
  'enviar-rda-consulta-externa': 'BundleAmbulatoryRDA',
  'enviar-rda-urgencias': 'BundleEmergencyRDA',
  'enviar-rda-hospitalizacion': 'BundleHospitalizationRDA',
  'enviar-rda-paciente': 'BundlePatientStatementRDA',
};

/// Clasificación de cada hallazgo para docs/ihce/DESVIACIONES.md. Solo
/// orienta la lectura: la exclusión la decide la evidencia oficial.
const _clases = <(String, String)>[
  ('Unable to resolve resource with reference', 'D1'),
  ('ref-1', 'D1'),
  ('fullUrl', 'D1'),
  ("isn't reachable by traversing links", 'D1'),
  ('a matching slice is required, but not found', 'D1'),
  ('Element matches more than one slice', 'G-SLICE-RESOURCE'),
  ('bdl-9', 'D3'),
  ('att-1', 'D7'),
  ('is not allowed to be used at this point', 'G-CONTEXTO-EXTENSION'),
  ('toDate is not a known function', 'G-FHIRPATH-TODATE'),
  ('Slicing cannot be evaluated', 'G-SLICE-PARTICIPANT'),
  ("matches for 'Organization/MinSalud'", 'G-MINSALUD-REF'),
];

/// Hallazgos atribuibles a `-tx n/a` (sin servidor terminológico).
final _txNa = [
  RegExp(r'terminology server', caseSensitive: false),
  RegExp(
    r'Unable to (check|validate) (whether )?the code',
    caseSensitive: false,
  ),
  RegExp(r'tx\.fhir\.org|-tx n/a|No terminology', caseSensitive: false),
];

void main(List<String> args) {
  final orden = args.isEmpty ? '' : args.first;
  switch (orden) {
    case 'extraer':
      _extraer();
    case 'generar':
      exit(_generar());
    case 'comparar':
      exit(_comparar());
    default:
      stderr.writeln(
        'uso: dart tool/ihce/linea_base.dart extraer|generar|comparar',
      );
      exit(64);
  }
}

// ───────────────────────── Extracción ─────────────────────────

void _extraer() {
  final f = File(_coleccion);
  if (!f.existsSync()) {
    stderr.writeln('Falta $_coleccion (tool/ihce/fetch_fhir_tooling.sh)');
    exit(2);
  }
  final coleccion = jsonDecode(f.readAsStringSync()) as Map;
  Directory(_oficiales).createSync(recursive: true);
  void visitar(List<Object?> items) {
    for (final it in items.cast<Map>()) {
      if (it['item'] is List) {
        visitar(it['item'] as List);
        continue;
      }
      final nombre = it['name'] as String?;
      if (!_envios.containsKey(nombre)) continue;
      final crudo =
          ((it['request'] as Map?)?['body'] as Map?)?['raw'] as String?;
      if (crudo == null) continue;
      // Postman admite comentarios `//` en los cuerpos (JSONC).
      final cuerpo = jsonDecode(_sinComentarios(crudo));
      File(
        '$_oficiales/postman-$nombre.json',
      ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(cuerpo));
      stdout.writeln(
        'postman-$nombre.json '
        '(${_envios[nombre]}) ${(cuerpo as Map)['entry']?.length} entradas',
      );
    }
  }

  visitar(coleccion['item'] as List);
}

/// Quita comentarios `//…` y `/*…*/` fuera de las cadenas JSON.
String _sinComentarios(String t) {
  final r = StringBuffer();
  var enCadena = false;
  for (var i = 0; i < t.length; i++) {
    final c = t[i];
    if (enCadena) {
      r.write(c);
      if (c == r'\' && i + 1 < t.length) {
        r.write(t[++i]);
      } else if (c == '"') {
        enCadena = false;
      }
      continue;
    }
    if (c == '"') {
      enCadena = true;
      r.write(c);
    } else if (c == '/' && i + 1 < t.length && t[i + 1] == '/') {
      while (i < t.length && t[i] != '\n') {
        i++;
      }
      if (i < t.length) r.write('\n');
    } else if (c == '/' && i + 1 < t.length && t[i + 1] == '*') {
      i = t.indexOf('*/', i + 2);
      if (i < 0) break;
      i++;
    } else {
      r.write(c);
    }
  }
  return r.toString();
}

// ───────────────────────── Lectura de reportes ─────────────────────────

class Hallazgo {
  Hallazgo(this.archivo, this.severidad, this.ruta, this.mensaje, this.tipos);

  final String archivo;
  final String severidad;
  final String ruta;
  final String mensaje;
  final List<String> tipos;

  late final String rutaNormal = _normalizar(ruta, tipos, esRuta: true);
  late final String mensajeNormal = _normalizar(mensaje, tipos);
  String get clave => '$rutaNormal | $mensajeNormal';
}

String _normalizar(String t, List<String> tipos, {bool esRuta = false}) {
  var r = t.replaceAll(RegExp(r'/\*[^*]*\*/'), '');
  r = r.replaceAllMapped(RegExp(r'Bundle\.entry\[(\d+)\]'), (m) {
    final i = int.parse(m.group(1)!);
    return 'Bundle.entry[${i < tipos.length ? tipos[i] : '?'}]';
  });
  r = r
      .replaceAllMapped(RegExp(r'(\w)\[(\d+)\]'), (m) => '${m.group(1)}[*]')
      .replaceAll(RegExp(r"reference '#?[^']*'"), "reference '<ref>'")
      .replaceAll(
        RegExp(r'\(url: [^;]*; ids: [^)]*\)'),
        '(url: <ref>; ids: <ids>)',
      )
      .replaceAll(
        RegExp(r"Found \d+ matches for '(?!Organization/)[^']*'"),
        "Found <n> matches for '<ref>'",
      )
      .replaceAll(RegExp(r'Found \d+ matches'), 'Found <n> matches')
      .replaceAll(
        RegExp(r"Invalid Characters \('[^']*'\)"),
        "Invalid Characters ('<id>')",
      );
  return r.trim();
}

List<String> _tiposDe(String archivo) {
  final f = File(archivo);
  if (!f.existsSync()) return const [];
  final b = jsonDecode(f.readAsStringSync());
  if (b is! Map || b['entry'] is! List) return const [];
  return [
    for (final e in (b['entry'] as List).cast<Map>())
      ((e['resource'] as Map?)?['resourceType'] as String?) ?? '?',
  ];
}

/// Hallazgos `error`/`fatal` (o todos con [todos]) de un reporte del
/// validador. [fuentePorDefecto] cuando el reporte es un único
/// OperationOutcome sin la extensión del archivo.
List<Hallazgo> leerReporte(
  String ruta, {
  String? fuentePorDefecto,
  bool todos = false,
}) {
  final d = jsonDecode(File(ruta).readAsStringSync()) as Map;
  final resultados = d['resourceType'] == 'Bundle'
      ? [for (final e in (d['entry'] as List).cast<Map>()) e['resource'] as Map]
      : [d];
  final r = <Hallazgo>[];
  for (final oo in resultados) {
    final archivo =
        [
          for (final x in ((oo['extension'] as List?) ?? const []).cast<Map>())
            if (x['valueString'] is String) x['valueString'] as String,
        ].firstOrNull ??
        fuentePorDefecto ??
        '?';
    final tipos = _tiposDe(archivo);
    for (final i in ((oo['issue'] as List?) ?? const []).cast<Map>()) {
      final sev = i['severity'] as String;
      if (!todos && sev != 'error' && sev != 'fatal') continue;
      final ruta =
          ((i['expression'] as List?) ?? (i['location'] as List?) ?? const [''])
                  .first
              as String;
      final texto =
          ((i['details'] as Map?)?['text'] as String?) ??
          (i['diagnostics'] as String?) ??
          '';
      r.add(Hallazgo(archivo, sev, ruta, texto, tipos));
    }
  }
  return r;
}

Map<String, Hallazgo> _evidencias() {
  final dir = Directory(_oficiales);
  final r = <String, Hallazgo>{};
  if (!dir.existsSync()) return r;
  final reportes =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.report.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in reportes) {
    final fuente = f.path.replaceFirst('.report.json', '.json');
    for (final h in leerReporte(f.path, fuentePorDefecto: fuente)) {
      r.putIfAbsent(h.clave, () => h);
    }
  }
  return r;
}

String? _clase(String mensaje) {
  for (final (patron, clase) in _clases) {
    if (mensaje.contains(patron)) return clase;
  }
  return null;
}

bool _esTxNa(String mensaje) => _txNa.any((r) => r.hasMatch(mensaje));

// ───────────────────────── generar / comparar ─────────────────────────

int _generar() {
  final propios = leerReporte(_reporte);
  final evidencias = _evidencias();
  final entradas = <String, Map<String, Object?>>{};
  final sinEvidencia = <Hallazgo>{};
  for (final h in propios) {
    final e = evidencias[h.clave];
    if (e != null) {
      entradas.putIfAbsent(
        h.clave,
        () => {
          'ruta': h.rutaNormal,
          'mensaje': h.mensajeNormal,
          'causa': 'artefacto-oficial',
          'clase': _clase(h.mensaje),
          'evidencia': {
            'artefacto': e.archivo.split('/').last,
            'ruta': e.ruta,
            'mensaje': e.mensaje,
          },
        },
      );
    } else if (_esTxNa(h.mensaje)) {
      entradas.putIfAbsent(
        h.clave,
        () => {
          'ruta': h.rutaNormal,
          'mensaje': h.mensajeNormal,
          'causa': 'tx-n/a',
          'clase': _clase(h.mensaje),
        },
      );
    } else {
      sinEvidencia.add(h);
    }
  }
  final ordenadas = entradas.values.toList()..sort(_porRuta);
  final pendientes = {
    for (final h in sinEvidencia)
      h.clave: {
        'ruta': h.rutaNormal,
        'mensaje': h.mensajeNormal,
        'clase': _clase(h.mensaje),
      },
  }.values.toList()..sort(_porRuta);
  final anterior = _leerLineaBase();
  File(_lineaBase).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'descripcion': 'Línea base de la capa 2 (validador HL7). Cada exclusión se '
          'reproduce en un artefacto oficial con el mismo comando o la causa '
          '-tx n/a. Generado por tool/ihce/linea_base.dart generar; ver '
          'docs/ihce/DESVIACIONES.md.',
      'normalizacion': 'Índices de entry → tipo de recurso; otros índices → [*]; sin '
          'comentarios /*Tipo/id*/; ids de referencias → <ref>.',
      'exclusiones': ordenadas,
      // Hallazgos sin evidencia oficial: NO se excluyen (rompen el gate).
      'sinEvidencia': pendientes,
      // Solo el propietario las agrega a mano (aprobadoPor, fecha, motivo);
      // `generar` las conserva y nunca las crea.
      'decisionesPropietario': anterior['decisionesPropietario'] ?? const [],
    })}\n',
  );
  stdout.writeln('${ordenadas.length} exclusiones con evidencia → $_lineaBase');
  // Sin evidencia oficial pero aceptados por decisión del propietario: no
  // rompen el gate (comparar los acepta), pero se siguen listando.
  final decididos = {
    for (final e
        in ((anterior['decisionesPropietario'] as List?) ?? const [])
            .cast<Map>())
      if (_decisionValida(e)) '${e['ruta']} | ${e['mensaje']}',
  };
  final abiertos = {
    for (final h in sinEvidencia)
      if (!decididos.contains(h.clave)) h.clave: h,
  };
  if (pendientes.isNotEmpty) {
    stdout.writeln(
      '${pendientes.length} hallazgos SIN evidencia oficial '
      '(${pendientes.length - abiertos.length} aceptados por decisión del '
      'propietario):',
    );
    for (final h in {for (final h in sinEvidencia) h.clave: h}.values) {
      final marca = decididos.contains(h.clave) ? '[decisión] ' : '';
      stdout.writeln('  $marca${h.archivo}: ${h.ruta} | ${h.mensaje}');
    }
  }
  return abiertos.isEmpty ? 0 : 1;
}

int _porRuta(Map<String, Object?> a, Map<String, Object?> b) =>
    '${a['ruta']}${a['mensaje']}'.compareTo('${b['ruta']}${b['mensaje']}');

Map<String, Object?> _leerLineaBase() {
  final f = File(_lineaBase);
  if (!f.existsSync()) return const {};
  return (jsonDecode(f.readAsStringSync()) as Map).cast();
}

/// Una decisión del propietario vale solo con quién la aprobó, cuándo y
/// por qué.
bool _decisionValida(Map e) => [
  'aprobadoPor',
  'fecha',
  'motivo',
].every((k) => (e[k] as String?)?.trim().isNotEmpty ?? false);

int _comparar() {
  if (!File(_lineaBase).existsSync()) {
    stderr.writeln('Falta $_lineaBase');
    return 2;
  }
  final lineaBase = _leerLineaBase();
  final base = {
    for (final e
        in ((lineaBase['exclusiones'] as List?) ?? const []).cast<Map>())
      '${e['ruta']} | ${e['mensaje']}': e,
  };
  final decisiones = {
    for (final e
        in ((lineaBase['decisionesPropietario'] as List?) ?? const [])
            .cast<Map>())
      if (_decisionValida(e)) '${e['ruta']} | ${e['mensaje']}': e,
  };
  final evidencias = _evidencias();
  final propios = leerReporte(_reporte, todos: true);
  final errores = propios.where(
    (h) => h.severidad == 'error' || h.severidad == 'fatal',
  );
  final advertencias = propios.where((h) => h.severidad == 'warning').length;
  final fuera = <Hallazgo>[];
  var excluidos = 0;
  var porDecision = 0;
  for (final h in errores) {
    final e = base[h.clave];
    final vigente =
        e != null &&
        (e['causa'] == 'tx-n/a' || evidencias.containsKey(h.clave));
    if (vigente) {
      excluidos++;
    } else if (decisiones.containsKey(h.clave)) {
      porDecision++;
    } else {
      fuera.add(h);
    }
  }
  final archivos = {for (final h in propios) h.archivo}.length;
  stdout.writeln(
    'Capa 2: $archivos Bundles, ${errores.length} error/fatal '
    '($excluidos en la línea base con evidencia, $porDecision por decisión '
    'del propietario), $advertencias advertencias.',
  );
  if (fuera.isEmpty) {
    stdout.writeln(
      'Capa 2 en verde: cero hallazgos error/fatal fuera de la línea base.',
    );
    return 0;
  }
  stdout.writeln(
    'Capa 2 en ROJO: ${fuera.length} hallazgos fuera de la línea base:',
  );
  for (final h in fuera) {
    stdout.writeln('  ${h.archivo}: ${h.ruta} | ${h.mensaje}');
  }
  return 1;
}
