// Con el módulo IHCE/RDA apagado (IHCE_ENABLED distinto de "true", el valor
// por defecto), quita de la compilación sus datos: el JSON Schema de FHIR
// (3,4 MB) y los catálogos derivados de la guía de MinSalud (CC BY-NC-SA).
// Así no se publican ni el service worker los precarga. Ningún código los
// pide con la bandera apagada. La usa `tool/construir_web.sh`, antes de
// generar el service worker.
//
//   dart run tool/pwa/datos_ihce.dart build/web [argumentos de flutter build]
import 'dart:convert';
import 'dart:io';

/// Carpeta de los datos del módulo dentro de la compilación web.
const carpetaDatosIhce = 'assets/assets/ihce';

/// ¿[argumentos] (los de `flutter build web`) encienden el módulo? Calcula
/// el valor efectivo de `IHCE_ENABLED` como lo hace `flutter_tools`
/// (`flutter_command.dart`): los `--dart-define-from-file` se leen en orden
/// y gana la última clave; los `--dart-define` (`-D`, `--DartDefines`)
/// prevalecen sobre los archivos y entre ellos gana el último. La app lo
/// compara con `trim() == 'true'` (`ConfigIhce.desdeMapa`). [leer] devuelve
/// el contenido de un archivo (las pruebas lo sustituyen).
bool ihceActivo(List<String> argumentos, {String Function(String ruta)? leer}) {
  final lector = leer ?? (String r) => File(r).readAsStringSync();
  String? deArchivos;
  String? deDefines;
  for (var i = 0; i < argumentos.length; i++) {
    final a = argumentos[i];
    final siguiente = i + 1 < argumentos.length ? argumentos[i + 1] : '';
    final define = _valorDeOpcion(a, siguiente, const [
      '--dart-define',
      '--DartDefines',
    ], corta: '-D');
    if (define != null && define.startsWith('IHCE_ENABLED=')) {
      deDefines = define.substring('IHCE_ENABLED='.length);
    }
    final archivo = _valorDeOpcion(a, siguiente, const [
      '--dart-define-from-file',
    ]);
    if (archivo != null) {
      deArchivos = valorEnArchivo(lector(archivo)) ?? deArchivos;
    }
  }
  return (deDefines ?? deArchivos)?.trim() == 'true';
}

/// Valor de una opción en sus formas `--opcion valor`, `--opcion=valor` y,
/// con [corta], `-D valor` y `-Dvalor`.
String? _valorDeOpcion(
  String a,
  String siguiente,
  List<String> largas, {
  String? corta,
}) {
  for (final o in largas) {
    if (a == o) return siguiente;
    if (a.startsWith('$o=')) return a.substring(o.length + 1);
  }
  if (corta != null && !a.startsWith('--')) {
    if (a == corta) return siguiente;
    if (a.startsWith(corta)) return a.substring(corta.length);
  }
  return null;
}

/// Valor de `IHCE_ENABLED` en un archivo de `--dart-define-from-file`, con
/// las reglas de Flutter: JSON si el contenido empieza por `{`; si no,
/// `.env` (comillas simples, dobles o invertidas y comentario `#` al final;
/// gana la última línea). `null` si no la define.
String? valorEnArchivo(String contenido) {
  if (contenido.trim().startsWith('{')) {
    final v = (jsonDecode(contenido) as Map)['IHCE_ENABLED'];
    return v?.toString();
  }
  String? r;
  for (final l in const LineSplitter().convert(contenido)) {
    final m = RegExp(r'^\s*IHCE_ENABLED\s*=\s*(.*)$').firstMatch(l);
    if (m == null) continue;
    final crudo = m[1]!;
    final entreComillas = RegExp(
      r'''^(["'`])(.*)\1\s*(#.*)?$''',
    ).firstMatch(crudo);
    r = entreComillas != null
        ? entreComillas[2]!
        : crudo.replaceFirst(RegExp(r'\s*#.*$'), '');
  }
  return r;
}

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
