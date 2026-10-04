// T20: control del propio gate. La capa 1 (JSON Schema oficial de FHIR R4)
// acepta un recurso válido conocido y rechaza alteraciones; las reglas
// locales rechazan Bundles mal formados; los ejemplos oficiales de la guía
// pasan por la capa 1 y su resultado queda registrado en
// `build/ihce/ejemplos-capa1.json` (un ejemplo oficial que falle se
// documenta, no se corrige).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/ihce/ensamblado/ensamblador.dart';
import 'package:historiasclinicas_net/core/ihce/extraccion/entrada_atencion.dart';
import 'package:historiasclinicas_net/core/ihce/modelo/documento_rda.dart';
import 'package:historiasclinicas_net/core/ihce/validacion/reglas_locales.dart';

import 'ayudas_ihce.dart';

/// Recurso R4 válido (forma del `patient-example` de la especificación,
/// con datos sintéticos).
Map<String, Object?> _pacienteValido() => {
  'resourceType': 'Patient',
  'id': 'ejemplo-sintetico',
  'active': true,
  'name': [
    {
      'use': 'official',
      'family': 'SINTETICO',
      'given': ['PACIENTE'],
    },
  ],
  'gender': 'female',
  'birthDate': '1990-03-15',
};

ResultadoEnsamblado _ensamblado() {
  final a = const ExtractorAtencion().extraer(
    entradaSintetica(),
    pdf: pdfSintetico,
  );
  return EstrategiaConsulta(configDePrueba(), catalogoDePrueba()).ensamblar(
    a,
    const IdentidadDocumento(
      tenantId: '990000000001',
      atencionId: '0f5c2a1e-8d4b-4c7a-9e21-5a3b7c9d1e2f',
      tipo: TipoRda.consulta,
      version: 1,
    ),
  );
}

List<String> _reglas(Map<String, Object?> bundle, Set<String> externos) => [
  for (final i in validarReglasLocales(
    bundle,
    ContextoReglas(
      config: configDePrueba(),
      tipo: TipoRda.consulta,
      ahora: DateTime(2026, 1, 16, 9),
      externos: externos,
    ),
  ))
    i.detailsText!,
];

Map<String, Object?> _copia(Map<String, Object?> m) =>
    (jsonDecode(jsonEncode(m)) as Map).cast();

void main() {
  final esquema = esquemaDePrueba();

  group('T20 capa 1', () {
    test('acepta un recurso R4 válido conocido', () {
      expect(esquema.validarRecurso(_pacienteValido()), isEmpty);
    });

    test('rechaza una propiedad desconocida', () {
      final r = esquema.validarRecurso({..._pacienteValido(), 'apodo': 'x'});
      expect(r, isNotEmpty);
    });

    test('rechaza un tipo de dato erróneo', () {
      expect(
        esquema.validarRecurso({..._pacienteValido(), 'active': 'si'}),
        isNotEmpty,
      );
      expect(
        esquema.validarRecurso({
          ..._pacienteValido(),
          'birthDate': '15/03/1990',
        }),
        isNotEmpty,
      );
    });

    test('rechaza un resourceType inválido', () {
      final r = esquema.validarRecurso({
        ..._pacienteValido(),
        'resourceType': 'Pacient',
      });
      expect(r.single.diagnostics, contains('resourceType'));
      expect(esquema.validarRecurso({'id': 'x'}), isNotEmpty);
    });

    test('acepta el Bundle de consulta ensamblado', () {
      expect(esquema.validarBundle(_ensamblado().bundle), isEmpty);
    });

    test('rechaza un Bundle con una entrada alterada', () {
      final b = _copia(_ensamblado().bundle);
      (((b['entry']! as List)[1] as Map)['resource'] as Map)['gender'] = 3;
      final r = esquema.validarBundle(b);
      expect(r, isNotEmpty);
      expect(r.first.location.single, startsWith('Bundle.entry[1]'));
    });
  });

  group('T20 reglas locales', () {
    test('el Bundle ensamblado las cumple', () {
      final e = _ensamblado();
      expect(_reglas(e.bundle, e.grafo.externos), isEmpty);
    });

    test('type distinto de document', () {
      final e = _ensamblado();
      final b = _copia(e.bundle)..['type'] = 'collection';
      expect(_reglas(b, e.grafo.externos), contains('R01'));
    });

    test('Composition fuera de entry[0]', () {
      final e = _ensamblado();
      final b = _copia(e.bundle);
      final entradas = b['entry']! as List;
      entradas.add(entradas.removeAt(0));
      expect(_reglas(b, e.grafo.externos), contains('R02'));
    });

    test('referencia sin entrada', () {
      final e = _ensamblado();
      final b = _copia(e.bundle);
      (b['entry']! as List).removeWhere(
        (x) =>
            ((x as Map)['resource'] as Map)['resourceType'] == 'Practitioner',
      );
      expect(_reglas(b, e.grafo.externos), contains('R06'));
    });
  });

  test('T20 ejemplos oficiales de la guía por la capa 1 (se registran)', () {
    final dir = Directory('vendor/fhir/ejemplos');
    if (!dir.existsSync()) {
      markTestSkipped(
        'vendor/fhir/ejemplos no está aprovisionado '
        '(tool/ihce/fetch_fhir_tooling.sh)',
      );
      return;
    }
    final archivos =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(archivos, isNotEmpty);
    final resultados = <Map<String, Object?>>[];
    for (final f in archivos) {
      final recurso = (jsonDecode(f.readAsStringSync()) as Map)
          .cast<String, Object?>();
      final errores = recurso['resourceType'] == 'Bundle'
          ? esquema.validarBundle(recurso)
          : esquema.validarRecurso(recurso, ruta: '${recurso['resourceType']}');
      resultados.add({
        'archivo': f.uri.pathSegments.last,
        'resourceType': recurso['resourceType'],
        'errores': errores.length,
        if (errores.isNotEmpty)
          'detalle': [
            for (final i in errores.take(5))
              '${i.location.join(',')}: ${i.diagnostics}',
          ],
      });
    }
    final salida = File('build/ihce/ejemplos-capa1.json')
      ..createSync(recursive: true);
    salida.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'total': resultados.length,
        'conErrores': resultados.where((r) => r['errores'] != 0).length,
        'resultados': resultados,
      }),
    );
    // Solo se registra: un ejemplo oficial que falle no bloquea ni se corrige.
    expect(resultados, hasLength(archivos.length));
  });
}
