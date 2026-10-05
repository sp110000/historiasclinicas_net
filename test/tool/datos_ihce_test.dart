import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/pwa/datos_ihce.dart';

void main() {
  test('sin bandera, el módulo IHCE está apagado (valor por defecto)', () {
    expect(ihceActivo(const []), isFalse);
    expect(ihceActivo(const ['--base-href', '/']), isFalse);
    expect(ihceActivo(const ['--dart-define=IHCE_ENABLED=false']), isFalse);
    expect(ihceActivo(const ['--dart-define=IHCE_ENV=produccion']), isFalse);
  });

  test('--dart-define enciende el módulo, junto o separado', () {
    expect(ihceActivo(const ['--dart-define=IHCE_ENABLED=true']), isTrue);
    expect(ihceActivo(const ['--dart-define', 'IHCE_ENABLED=true']), isTrue);
  });

  test('--dart-define-from-file: .env y JSON', () {
    final archivos = {
      'apagado.env': File('config/ihce.env.example').readAsStringSync(),
      'encendido.env': 'IHCE_ENV=produccion\nIHCE_ENABLED=true\n',
      'encendido.json': '{\n  "IHCE_ENABLED": "true"\n}',
      'comentado.env': '# IHCE_ENABLED=true\nIHCE_ENABLED=false\n',
    };
    bool con(String f) =>
        ihceActivo(['--dart-define-from-file=$f'], leer: (r) => archivos[r]!);
    expect(con('apagado.env'), isFalse, reason: 'la plantilla viene apagada');
    expect(con('encendido.env'), isTrue);
    expect(con('encendido.json'), isTrue);
    expect(con('comentado.env'), isFalse);
    expect(
      ihceActivo(const [
        '--dart-define-from-file',
        'encendido.env',
      ], leer: (r) => archivos[r]!),
      isTrue,
    );
  });

  test('la compilación de producción (pages.yml) no enciende el módulo', () {
    final flujo = File('.github/workflows/pages.yml').readAsStringSync();
    expect(flujo, isNot(contains('IHCE_ENABLED')));
    expect(flujo, isNot(contains('dart-define')));
  });

  test('construir_web.sh quita los datos antes de generar el service '
      'worker', () {
    final script = File('tool/construir_web.sh').readAsStringSync();
    final quitar = script.indexOf('tool/pwa/datos_ihce.dart');
    expect(quitar, greaterThan(0));
    expect(quitar, lessThan(script.indexOf('generar_service_worker.dart')));
  });
}
