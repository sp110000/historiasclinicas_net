// Con el módulo IHCE/RDA apagado (IHCE_ENABLED distinto de "true", el valor
// por defecto), quita de la compilación sus datos: el JSON Schema de FHIR
// (3,4 MB) y los catálogos derivados de la guía de MinSalud (CC BY-NC-SA).
// Así no se publican ni el service worker los precarga, y la app apagada
// descarga lo mismo que antes del módulo. Ningún código los pide con la
// bandera apagada. La usa `tool/construir_web.sh`, antes de generar el
// service worker.
//
//   dart run tool/pwa/datos_ihce.dart build/web [argumentos de flutter build]
import 'dart:io';

/// Carpeta de los datos del módulo dentro de la compilación web.
const carpetaDatosIhce = 'assets/assets/ihce';

/// ¿[argumentos] (los de `flutter build web`) encienden el módulo? Acepta
/// `--dart-define=IHCE_ENABLED=true`, `--dart-define IHCE_ENABLED=true` y
/// `--dart-define-from-file` (`.env` o JSON). [leer] devuelve el contenido
/// de un archivo (las pruebas lo sustituyen).
bool ihceActivo(List<String> argumentos, {String Function(String ruta)? leer}) {
  final lector = leer ?? (String r) => File(r).readAsStringSync();
  for (var i = 0; i < argumentos.length; i++) {
    final a = argumentos[i];
    final siguiente = i + 1 < argumentos.length ? argumentos[i + 1] : '';
    final define = a == '--dart-define'
        ? siguiente
        : a.startsWith('--dart-define=')
        ? a.substring('--dart-define='.length)
        : null;
    if (define != null && define.trim() == 'IHCE_ENABLED=true') return true;
    final archivo = a == '--dart-define-from-file'
        ? siguiente
        : a.startsWith('--dart-define-from-file=')
        ? a.substring('--dart-define-from-file='.length)
        : null;
    if (archivo != null && _enciende(lector(archivo))) return true;
  }
  return false;
}

/// `IHCE_ENABLED=true` (.env) o `"IHCE_ENABLED": "true"` / `true` (JSON).
bool _enciende(String contenido) => RegExp(
  r'^\s*"?IHCE_ENABLED"?\s*[:=]\s*"?true"?\s*,?\s*$',
  multiLine: true,
).hasMatch(contenido);

void main(List<String> args) {
  final web = args.isEmpty ? 'build/web' : args.first;
  final argumentos = args.length > 1 ? args.sublist(1) : const <String>[];
  if (ihceActivo(argumentos)) {
    stdout.writeln('IHCE_ENABLED=true: se publican los datos del módulo IHCE.');
    return;
  }
  final carpeta = Directory('$web/$carpetaDatosIhce');
  if (carpeta.existsSync()) carpeta.deleteSync(recursive: true);
  stdout.writeln('Módulo IHCE apagado: sin $carpetaDatosIhce en $web.');
}
