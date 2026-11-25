import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/consultorio/verificar_compilacion.dart';

void main() {
  test('la publicación (pages.yml) enciende el consultorio, y solo eso', () {
    final flujo = File('.github/workflows/pages.yml').readAsStringSync();
    final compilar = RegExp(
      r'construir_web\.sh[^\n]*',
    ).allMatches(flujo).map((m) => m.group(0)!).toList();
    expect(compilar, hasLength(1));
    expect(compilar.single, contains('--csp-en-html'));
    expect(compilar.single, contains('--dart-define=CONSULTORIO_ENABLED=true'));
    // El módulo IHCE/RDA sigue apagado.
    expect(flujo, isNot(contains('IHCE_ENABLED')));
    expect(
      RegExp('--dart-define=').allMatches(flujo).length,
      2,
      reason: 'la compilación y las pruebas con el consultorio encendido',
    );
    expect(
      flujo,
      contains('verificar_compilacion.dart build/web --con-modulo'),
    );
  });

  test('la CI comprueba las dos compilaciones', () {
    final ci = File('.github/workflows/ci.yml').readAsStringSync();
    expect(ci, contains('verificar_compilacion.dart build/web --sin-modulo'));
    expect(ci, contains('--dart-define=CONSULTORIO_ENABLED=true'));
    expect(ci, contains('--con-modulo'));
  });

  test('la marca del módulo se detecta en el JS compilado', () {
    expect(contieneModulo('var a="historiasclinicas_consultorio";'), isTrue);
    expect(contieneModulo('var a="historiasclinicas_ihce";'), isFalse);
  });

  test('construir_web.sh acepta una carpeta de salida y la usa en todos los '
      'pasos', () {
    final script = File('tool/construir_web.sh').readAsStringSync();
    expect(script, contains('--output "\$salida_absoluta"'));
    expect(script, contains('datos_ihce.dart "\$salida"'));
    expect(script, contains('generar_service_worker.dart "\$salida"'));
  });
}
