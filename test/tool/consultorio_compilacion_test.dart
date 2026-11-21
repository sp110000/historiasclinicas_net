import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/consultorio/verificar_compilacion.dart';

void main() {
  test('la publicación (pages.yml) no enciende el consultorio', () {
    final flujo = File('.github/workflows/pages.yml').readAsStringSync();
    expect(flujo, isNot(contains('CONSULTORIO_ENABLED')));
    expect(flujo, isNot(contains('dart-define')));
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
