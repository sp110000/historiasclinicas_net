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

  test('las demás formas que acepta flutter_tools', () {
    for (final args in const [
      ['-D', 'IHCE_ENABLED=true'],
      ['-DIHCE_ENABLED=true'],
      ['--DartDefines=IHCE_ENABLED=true'],
      ['--DartDefines', 'IHCE_ENABLED=true'],
      ['--dart-define=IHCE_ENABLED= true'],
    ]) {
      expect(ihceActivo(args), isTrue, reason: '$args');
    }
    final archivos = {
      'comentario.env': 'IHCE_ENABLED=true # encendido\n',
      'simples.env': "IHCE_ENABLED='true'\n",
      'invertidas.env': 'IHCE_ENABLED=`true`\n',
      'una-linea.json': '{"IHCE_ENABLED": "true", "IHCE_ENV": "produccion"}',
      'booleano.json': '{"IHCE_ENABLED": true}',
      'apagado.json': '{"IHCE_ENABLED": "false"}',
    };
    bool con(String f) =>
        ihceActivo(['--dart-define-from-file=$f'], leer: (r) => archivos[r]!);
    expect(con('comentario.env'), isTrue);
    expect(con('simples.env'), isTrue);
    expect(con('invertidas.env'), isTrue);
    expect(con('una-linea.json'), isTrue);
    expect(con('booleano.json'), isTrue);
    expect(con('apagado.json'), isFalse);
  });

  test('precedencia de Flutter: gana el último y --dart-define sobre los '
      'archivos', () {
    final archivos = {
      'on.env': 'IHCE_ENABLED=true\n',
      'off.env': 'IHCE_ENABLED=false\n',
      'dos.env': 'IHCE_ENABLED=true\nIHCE_ENABLED=false\n',
    };
    bool con(List<String> a) => ihceActivo(a, leer: (r) => archivos[r]!);
    expect(
      con([
        '--dart-define-from-file=on.env',
        '--dart-define=IHCE_ENABLED=false',
      ]),
      isFalse,
    );
    expect(
      con([
        '--dart-define=IHCE_ENABLED=true',
        '--dart-define-from-file=off.env',
      ]),
      isTrue,
    );
    expect(
      con([
        '--dart-define=IHCE_ENABLED=true',
        '--dart-define=IHCE_ENABLED=false',
      ]),
      isFalse,
    );
    expect(
      con([
        '--dart-define-from-file=on.env',
        '--dart-define-from-file=off.env',
      ]),
      isFalse,
    );
    expect(con(['--dart-define-from-file=dos.env']), isFalse);
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
