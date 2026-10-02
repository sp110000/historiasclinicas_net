// Genera build/web/sw.js: la lista de archivos de la app con su huella
// SHA-256, para que el service worker los guarde y la app funcione sin
// conexión. Se ejecuta después de `flutter build web` (tool/construir_web.sh):
//
//   dart run tool/pwa/generar_service_worker.dart [build/web]
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const plantillaPorDefecto = 'tool/pwa/sw.plantilla.js';

/// Lo que no se guarda: el propio service worker, el de Flutter (obsoleto,
/// no se registra), los símbolos de depuración y los archivos ocultos.
bool excluido(String ruta) =>
    ruta == 'sw.js' ||
    ruta == 'flutter_service_worker.js' ||
    ruta.endsWith('.symbols') ||
    ruta.split('/').any((parte) => parte.startsWith('.'));

class ServiceWorkerGenerado {
  const ServiceWorkerGenerado({
    required this.codigo,
    required this.version,
    required this.archivos,
    required this.motor,
    required this.bytesArchivos,
  });

  final String codigo;
  final String version;

  /// Ruta → huella de lo que se descarga al instalar.
  final Map<String, String> archivos;

  /// Ruta → huella de las variantes del motor (se guardan al usarse).
  final Map<String, String> motor;
  final int bytesArchivos;
}

ServiceWorkerGenerado generarServiceWorker(Directory web, String plantilla) {
  if (!File('${web.path}/index.html').existsSync()) {
    throw StateError(
      'No existe ${web.path}/index.html: ejecuta antes '
      '`flutter build web --release --no-web-resources-cdn`.',
    );
  }
  final archivos = <String, String>{};
  final motor = <String, String>{};
  var bytes = 0;
  final lista = web.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in lista) {
    final ruta = f.path
        .substring(web.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    if (excluido(ruta)) continue;
    final contenido = f.readAsBytesSync();
    final huella = sha256.convert(contenido).toString().substring(0, 16);
    if (ruta.startsWith('canvaskit/')) {
      motor[ruta] = huella;
    } else {
      archivos[ruta] = huella;
      bytes += contenido.length;
    }
  }
  final bootstrap = File('${web.path}/flutter_bootstrap.js');
  final revision = bootstrap.existsSync()
      ? RegExp(
          r'"engineRevision"\s*:\s*"(\w+)"',
        ).firstMatch(bootstrap.readAsStringSync())?.group(1)
      : null;
  String huellaDe(Object o) =>
      sha256.convert(utf8.encode(jsonEncode(o))).toString().substring(0, 12);
  final version = huellaDe({'archivos': archivos, 'motor': motor});
  String json(Map<String, String> m) =>
      const JsonEncoder.withIndent('  ').convert(m);
  final codigo = plantilla
      .replaceAll('__VERSION__', version)
      .replaceAll('__MOTOR__', (revision ?? huellaDe(motor)).substring(0, 12))
      .replaceAll('__ARCHIVOS_MOTOR__', json(motor))
      .replaceAll('__ARCHIVOS__', json(archivos));
  return ServiceWorkerGenerado(
    codigo: codigo,
    version: version,
    archivos: archivos,
    motor: motor,
    bytesArchivos: bytes,
  );
}

void main(List<String> args) {
  final web = Directory(args.isEmpty ? 'build/web' : args.first);
  final sw = generarServiceWorker(
    web,
    File(plantillaPorDefecto).readAsStringSync(),
  );
  File('${web.path}/sw.js').writeAsStringSync(sw.codigo);
  final mb = (sw.bytesArchivos / 1024 / 1024).toStringAsFixed(1);
  stdout.writeln(
    '${web.path}/sw.js: versión ${sw.version}, ${sw.archivos.length} '
    'archivos ($mb MB) y ${sw.motor.length} variantes del motor.',
  );
}
