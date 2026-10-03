import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Ancho y alto de un PNG (cabecera IHDR).
(int, int) tamanoPng(Uint8List b) {
  final d = ByteData.sublistView(b);
  return (d.getUint32(16), d.getUint32(20));
}

void main() {
  final html = File('web/index.html').readAsStringSync();
  final manifest =
      jsonDecode(File('web/manifest.json').readAsStringSync())
          as Map<String, Object?>;

  test('los íconos de index.html existen y tienen el tamaño declarado', () {
    final enlaces = RegExp(
      r'<link rel="(?:icon|apple-touch-icon)"([^>]*)>',
    ).allMatches(html).map((m) => m.group(1)!).toList();
    expect(enlaces, isNotEmpty);
    for (final e in enlaces) {
      final ruta = RegExp(r'href="([^"]+)"').firstMatch(e)!.group(1)!;
      final archivo = File('web/$ruta');
      expect(archivo.existsSync(), isTrue, reason: ruta);
      if (!ruta.endsWith('.png')) continue;
      final lado = int.parse(
        RegExp(r'sizes="(\d+)x\d+"').firstMatch(e)!.group(1)!,
      );
      expect(tamanoPng(archivo.readAsBytesSync()), (lado, lado), reason: ruta);
    }
  });

  test('los íconos del manifest existen y tienen el tamaño declarado', () {
    final iconos = (manifest['icons']! as List).cast<Map<String, Object?>>();
    expect(iconos.map((i) => i['purpose']), containsAll(['any', 'maskable']));
    for (final i in iconos) {
      final archivo = File('web/${i['src']}');
      expect(archivo.existsSync(), isTrue, reason: '${i['src']}');
      final lado = int.parse((i['sizes']! as String).split('x').first);
      expect(tamanoPng(archivo.readAsBytesSync()), (
        lado,
        lado,
      ), reason: '${i['src']}');
    }
  });

  test('ningún ícono apunta a los nombres del logo anterior', () {
    // Los móviles guardan el ícono por su dirección: si el nombre no cambia
    // con el logo, siguen mostrando el viejo.
    for (final viejo in [
      'apple-touch-icon.png',
      'Icon-192.png',
      'favicon.png',
      'favicon-16.png',
    ]) {
      expect(html.contains(viejo), isFalse, reason: viejo);
      expect(jsonEncode(manifest).contains(viejo), isFalse, reason: viejo);
    }
  });
}
