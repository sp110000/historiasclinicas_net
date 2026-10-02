import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/pwa/generar_service_worker.dart';

void main() {
  late Directory web;
  final plantilla = File(plantillaPorDefecto).readAsStringSync();

  void escribir(String ruta, String contenido) => (File(
    '${web.path}/$ruta',
  )..createSync(recursive: true)).writeAsStringSync(contenido);

  setUp(() {
    web = Directory.systemTemp.createTempSync('sw_');
    addTearDown(() => web.deleteSync(recursive: true));
    escribir('index.html', '<html></html>');
    escribir(
      'flutter_bootstrap.js',
      '_flutter.buildConfig = {"engineRevision":"cafcda5721a78a7884db92f1"};',
    );
    escribir('main.dart.js', 'main()');
    escribir('assets/assets/cie10/cie10_sispro.txt', 'A000\tCOLERA');
    escribir('canvaskit/canvaskit.wasm', 'wasm');
    escribir('canvaskit/chromium/canvaskit.js', 'js');
    escribir('canvaskit/canvaskit.js.symbols', 'símbolos');
    escribir('flutter_service_worker.js', 'obsoleto');
    escribir('sw.js', 'anterior');
    escribir('.last_build_id', 'x');
    escribir('.htaccess', 'Header set X-Content-Type-Options nosniff');
    escribir('_headers', '/*');
    escribir('vercel.json', '{}');
  });

  test('lista de archivos, motor aparte y exclusiones', () {
    final sw = generarServiceWorker(web, plantilla);
    expect(sw.archivos.keys, [
      'assets/assets/cie10/cie10_sispro.txt',
      'flutter_bootstrap.js',
      'index.html',
      'main.dart.js',
    ]);
    expect(sw.motor.keys, [
      'canvaskit/canvaskit.wasm',
      'canvaskit/chromium/canvaskit.js',
    ]);
    expect(sw.archivos['index.html'], hasLength(16));
    expect(sw.codigo, isNot(contains('__')), reason: 'sin marcadores');
    expect(sw.codigo, contains("const MOTOR = 'cafcda5721a7';"));
    expect(sw.codigo, contains("const VERSION = '${sw.version}';"));
    expect(
      sw.codigo,
      contains('"main.dart.js": "${sw.archivos['main.dart.js']}"'),
    );
  });

  test('la versión cambia solo si cambia algún archivo', () {
    final v1 = generarServiceWorker(web, plantilla).version;
    expect(generarServiceWorker(web, plantilla).version, v1);
    escribir('canvaskit/canvaskit.js.symbols', 'otros símbolos');
    expect(generarServiceWorker(web, plantilla).version, v1);
    escribir('main.dart.js', 'main() // v2');
    expect(generarServiceWorker(web, plantilla).version, isNot(v1));
  });

  test('sin compilar antes avisa qué hacer', () {
    File('${web.path}/index.html').deleteSync();
    expect(
      () => generarServiceWorker(web, plantilla),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'mensaje',
          contains('flutter build web'),
        ),
      ),
    );
  });
}
