import 'dart:convert';

import '../config/config_ihce.dart';
import '../grafo/referencias.dart';
import '../mappers/estructurales_mapper.dart';
import '../modelo/documento_rda.dart';
import '../perfiles/perfiles_rda.g.dart';

/// Regla local con identificador propio. La usan el validador previo al
/// envío y las pruebas. Fuentes: Manual de Operaciones §5.4 (reglas
/// obligatorias que el servidor ejecuta y que «el cliente debe validar
/// localmente antes de enviar») y Fase 4.4.
class ReglaLocal {
  const ReglaLocal(this.id, this.descripcion, this.evaluar);

  final String id;
  final String descripcion;
  final List<String> Function(Map<String, Object?> bundle, ContextoReglas c)
  evaluar;
}

class ContextoReglas {
  const ContextoReglas({
    required this.config,
    required this.tipo,
    required this.ahora,
    this.externos = const {},
  });

  final ConfigIhce config;
  final TipoRda tipo;
  final DateTime ahora;

  /// Referencias externas permitidas (IPS persistida, `Organization/MinSalud`,
  /// el Encounter cuando no viaja como entrada).
  final Set<String> externos;
}

List<Map<String, Object?>> _recursos(Map<String, Object?> b) => [
  for (final e in (b['entry'] as List?) ?? const [])
    ((e as Map)['resource'] as Map).cast<String, Object?>(),
];

Map<String, Object?>? _composition(Map<String, Object?> b) {
  final r = _recursos(b);
  return r.isEmpty || r.first['resourceType'] != 'Composition' ? null : r.first;
}

List<(String ruta, String referencia)> _referencias(Map<String, Object?> b) {
  final r = <(String, String)>[];
  void visitar(Object? v, String ruta) {
    if (v is Map) {
      if (v['reference'] is String) {
        r.add((ruta, v['reference'] as String));
      }
      for (final e in v.entries) {
        visitar(e.value, '$ruta.${e.key}');
      }
    } else if (v is List) {
      for (var i = 0; i < v.length; i++) {
        visitar(v[i], '$ruta[$i]');
      }
    }
  }

  final recursos = _recursos(b);
  for (var i = 0; i < recursos.length; i++) {
    visitar(recursos[i], 'Bundle.entry[$i].resource');
  }
  return r;
}

final _conZona = RegExp(r'T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$');
final _fechaCompleta = RegExp(r'^\d{4}-\d{2}-\d{2}');

/// Reglas en el orden en que se evalúan.
final reglasLocales = <ReglaLocal>[
  ReglaLocal(
    'R01',
    'Bundle.type = document (Manual §5.4.1)',
    (b, c) => [if (b['type'] != 'document') 'Bundle.type debe ser document'],
  ),
  ReglaLocal(
    'R02',
    'entry[0] es el Composition (Manual §5.4.2)',
    (b, c) => [
      if (_composition(b) == null) 'Bundle.entry[0] debe ser el Composition',
    ],
  ),
  ReglaLocal('R03', 'Un solo Composition (Manual §5.4.3a)', (b, c) {
    final n = _recursos(
      b,
    ).where((r) => r['resourceType'] == 'Composition').length;
    return [if (n != 1) 'El Bundle debe tener exactamente un Composition ($n)'];
  }),
  ReglaLocal('R04', 'Todas las secciones del perfil (Manual §5.4.3b)', (b, c) {
    final comp = _composition(b);
    if (comp == null) return const [];
    final perfil = (comp['meta'] as Map?)?['profile'] as List?;
    final id = (perfil?.first as String?)?.split('/').last;
    final secciones = seccionesPorComposition[id];
    if (secciones == null) return ['Composition sin perfil conocido'];
    final codigos = [
      for (final s in (comp['section'] as List?) ?? const [])
        (((s as Map)['code'] as Map)['coding'] as List).first['code'],
    ];
    return [
      for (final s in secciones)
        if (s.obligatoria && !codigos.contains(s.codigo))
          'Falta la sección ${s.slice} (${s.codigo})',
    ];
  }),
  ReglaLocal(
    'R05',
    'Sección sin entradas: emptyReason y text (Manual §5.4.3b)',
    (b, c) {
      final comp = _composition(b);
      final r = <String>[];
      final secciones = (comp?['section'] as List?) ?? const [];
      for (var i = 0; i < secciones.length; i++) {
        final s = (secciones[i] as Map).cast<String, Object?>();
        final entradas = (s['entry'] as List?) ?? const [];
        if (entradas.isEmpty) {
          if (s['emptyReason'] == null) {
            r.add('section[$i] vacía sin emptyReason');
          }
          if (s['text'] == null) {
            r.add('section[$i] vacía sin text');
          }
        } else if (s['emptyReason'] != null) {
          r.add('section[$i] con entradas y emptyReason');
        }
      }
      return r;
    },
  ),
  ReglaLocal(
    'R06',
    'Toda referencia #Tipo-n tiene su entrada (Manual §5.4.6)',
    (b, c) {
      final ids = {
        for (final r in _recursos(b))
          if (r['id'] != null) r['id'] as String,
      };
      final refs = ReferenciasRda(c.config.estiloReferencia);
      return [
        for (final (ruta, ref) in _referencias(b))
          if (!c.externos.contains(ref) &&
              !(refs.idDe(ref) != null &&
                  c.externos.contains(refs.idDe(ref))) &&
              !(refs.idDe(ref) != null && ids.contains(refs.idDe(ref))))
            '$ruta: referencia sin entrada',
      ];
    },
  ),
  ReglaLocal('R07', 'Adjunto PDF: base64 válido y tamaño (Manual §5.4.7)', (
    b,
    c,
  ) {
    final r = <String>[];
    for (final d in _recursos(
      b,
    ).where((x) => x['resourceType'] == 'DocumentReference')) {
      for (final ct in (d['content'] as List?) ?? const []) {
        final adjunto = ((ct as Map)['attachment'] as Map?) ?? const {};
        final formato = (ct['format'] as Map?)?['code'];
        if (formato != 'application/pdf') {
          r.add('Adjunto sin formato application/pdf');
        }
        final datos = adjunto['data'];
        if (datos is! String) {
          r.add('Adjunto sin datos');
          continue;
        }
        try {
          final bytes = base64.decode(datos);
          if (bytes.length > c.config.adjuntoMaxBytes) {
            r.add(
              'Adjunto de ${bytes.length} bytes supera ${c.config.adjuntoMaxBytes}',
            );
          }
          if (bytes.length < 5 ||
              ascii.decode(bytes.sublist(0, 5), allowInvalid: true) !=
                  '%PDF-') {
            r.add('El adjunto no es un PDF');
          }
        } on FormatException {
          r.add('Adjunto con base64 inválido');
        }
      }
    }
    return r;
  }),
  ReglaLocal('R08', 'Fechas con zona horaria y periodos con fecha completa', (
    b,
    c,
  ) {
    final r = <String>[];
    void visitar(Object? v, String ruta) {
      if (v is Map) {
        for (final e in v.entries) {
          visitar(e.value, '$ruta.${e.key}');
        }
      } else if (v is List) {
        for (var i = 0; i < v.length; i++) {
          visitar(v[i], '$ruta[$i]');
        }
      } else if (v is String && ruta.endsWith('div') == false) {
        final esFechaHora = RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(v);
        if (esFechaHora && !_conZona.hasMatch(v)) {
          r.add('$ruta: fecha y hora sin zona');
        }
      }
    }

    visitar(b, 'Bundle');
    for (final x in _recursos(b)) {
      final periodos = [
        if (x['resourceType'] == 'Encounter') x['period'],
        if (x['resourceType'] == 'Composition')
          for (final e in (x['event'] as List?) ?? const [])
            (e as Map)['period'],
      ];
      for (final p in periodos.whereType<Map>()) {
        for (final k in const ['start', 'end']) {
          if (p[k] is String && !_fechaCompleta.hasMatch(p[k] as String)) {
            r.add('${x['resourceType']}.period.$k sin fecha completa');
          }
        }
      }
    }
    return r;
  }),
  ReglaLocal(
    'R09',
    'Composition.subject, encounter y author resuelven a nodos',
    (b, c) {
      final comp = _composition(b);
      if (comp == null) return const [];
      final refs = ReferenciasRda(c.config.estiloReferencia);
      final ids = {for (final r in _recursos(b)) r['id']};
      String? id(Object? ref) =>
          ref is Map ? refs.idDe(ref['reference'] as String? ?? '') : null;
      final r = <String>[];
      if (!ids.contains(id(comp['subject']))) {
        r.add('Composition.subject no resuelve');
      }
      final enc = id(comp['encounter']);
      if (!ids.contains(enc) && !c.externos.contains(enc)) {
        r.add('Composition.encounter no resuelve');
      }
      for (final a in (comp['author'] as List?) ?? const []) {
        if (!ids.contains(id(a))) {
          r.add('Composition.author no resuelve');
        }
      }
      return r;
    },
  ),
  ReglaLocal('R10', 'Los recursos clínicos referencian el mismo Encounter', (
    b,
    c,
  ) {
    final comp = _composition(b);
    final enc = ((comp?['encounter'] as Map?)?['reference']) as String?;
    return [
      for (final x in _recursos(b))
        if (perfilesConEncuentro.contains(perfilDe(x)) &&
            (x['encounter'] as Map?)?['reference'] != enc)
          '${x['resourceType']}/${x['id']} no referencia el Encounter del documento',
    ];
  }),
  ReglaLocal('R11', 'Identificadores de Patient y Practitioner', (b, c) {
    bool sinValor(Map<String, Object?> x) {
      final ids = (x['identifier'] as List?) ?? const [];
      if (ids.isEmpty) return true;
      final v = (ids.first as Map)['value'];
      return v is! String || v.isEmpty;
    }

    return [
      for (final x in _recursos(b))
        if ((x['resourceType'] == 'Patient' ||
                x['resourceType'] == 'Practitioner') &&
            sinValor(x))
          '${x['resourceType']} sin identificador',
    ];
  }),
  ReglaLocal(
    'R12',
    'Encounter.period: inicio ≤ fin ≤ ahora y no más de un año',
    (b, c) {
      final r = <String>[];
      for (final x in _recursos(
        b,
      ).where((x) => x['resourceType'] == 'Encounter')) {
        final p = (x['period'] as Map?) ?? const {};
        final ini = DateTime.tryParse('${p['start']}');
        final fin = DateTime.tryParse('${p['end']}');
        if (ini == null || fin == null) {
          r.add('Encounter.period incompleto');
          continue;
        }
        if (fin.isBefore(ini)) {
          r.add('Encounter.period: fin antes del inicio');
        }
        if (fin.isAfter(c.ahora)) {
          r.add('Encounter.period: fin en el futuro');
        }
        final haceUnAnio = DateTime(
          c.ahora.year - 1,
          c.ahora.month,
          c.ahora.day,
        );
        if (ini.isBefore(haceUnAnio)) {
          r.add('Encounter.period: más de un año');
        }
      }
      return r;
    },
  ),
  ReglaLocal(
    'R13',
    'Entradas admitidas por el slicing cerrado del Bundle (D2)',
    (b, c) {
      final entradas = entradasPorBundle[c.tipo.perfilBundle] ?? const [];
      final r = <String>[];
      for (final x in _recursos(b)) {
        final tipo = x['resourceType'];
        // D2: el Encounter viaja como entrada aunque el perfil no tenga slice.
        if (tipo == 'Encounter' && c.config.encounterComoEntrada) continue;
        final perfil = perfilDe(x);
        final admitida = entradas.any(
          (e) => e.tipo == tipo && (e.perfil == null || e.perfil == perfil),
        );
        if (!admitida) {
          r.add('$tipo ($perfil) no está entre las entradas del perfil');
        }
      }
      for (final e in entradas.where((e) => e.min > 0)) {
        final n = _recursos(b)
            .where(
              (x) =>
                  x['resourceType'] == e.tipo &&
                  (e.perfil == null || perfilDe(x) == e.perfil),
            )
            .length;
        if (n < e.min) {
          r.add('Falta la entrada ${e.slice}');
        }
      }
      return r;
    },
  ),
];

/// Evalúa todas las reglas. Cada hallazgo es una `IhceIssue` con el `id` de
/// la regla en `code` de detalle.
List<IhceIssue> validarReglasLocales(
  Map<String, Object?> bundle,
  ContextoReglas c,
) => [
  for (final regla in reglasLocales)
    for (final m in regla.evaluar(bundle, c))
      IhceIssue(
        severity: 'error',
        code: 'invariant',
        detailsText: regla.id,
        diagnostics: m,
      ),
];
