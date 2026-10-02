import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cabeceras de `web/_headers` (formato de Netlify), la referencia.
Map<String, String> cabecerasNetlify() {
  final r = <String, String>{};
  for (final linea in File('web/_headers').readAsLinesSync()) {
    if (linea.startsWith('  ') && linea.contains(':')) {
      final i = linea.indexOf(':');
      r[linea.substring(0, i).trim()] = linea.substring(i + 1).trim();
    }
  }
  return r;
}

Map<String, String> cabecerasJson(String archivo, String origen) {
  final json = jsonDecode(File(archivo).readAsStringSync()) as Map;
  final reglas = (json['hosting'] ?? json) as Map;
  final regla = (reglas['headers'] as List).cast<Map>().singleWhere(
    (h) => h['source'] == origen,
  );
  return {
    for (final h in (regla['headers'] as List).cast<Map>())
      h['key'] as String: h['value'] as String,
  };
}

/// Ubicación de `package:[paquete]/[ruta]` según .dart_tool.
Uri archivoDePaquete(String paquete, String ruta) {
  final config = File('.dart_tool/package_config.json');
  final json = jsonDecode(config.readAsStringSync()) as Map;
  final p = (json['packages'] as List).cast<Map>().singleWhere(
    (p) => p['name'] == paquete,
  );
  final raiz = p['rootUri'] as String;
  return config.uri
      .resolve(raiz.endsWith('/') ? raiz : '$raiz/')
      .resolve('${p['packageUri']}$ruta');
}

void main() {
  final referencia = cabecerasNetlify();

  test('todas las configuraciones envían las mismas cabeceras', () {
    expect(referencia.keys, contains('Content-Security-Policy'));
    expect(cabecerasJson('firebase.json', '**'), referencia);
    expect(cabecerasJson('vercel.json', '/(.*)'), referencia);
    final apache = {
      for (final m in RegExp(
        r'^\s*Header set ([\w-]+) "(.*)"$',
        multiLine: true,
      ).allMatches(File('web/.htaccess').readAsStringSync()))
        m.group(1)!: m.group(2)!,
    };
    expect(apache, referencia);
    final nginx = {
      for (final m in RegExp(
        r'^\s*add_header ([\w-]+) "(.*)" always;$',
        multiLine: true,
      ).allMatches(File('docs/DESPLIEGUE.md').readAsStringSync()))
        m.group(1)!: m.group(2)!,
    };
    expect(nginx, referencia, reason: 'Nginx, en docs/DESPLIEGUE.md');
  });

  test('la CSP permite el script con el que printing imprime', () {
    // Si se actualiza el paquete y cambia el script, hay que actualizar la
    // huella en las cuatro configuraciones (imprimir seguiría funcionando
    // gracias a la copia de web/pdfjs/iniciar.js, pero con un aviso).
    final codigo = File.fromUri(
      archivoDePaquete('printing', 'printing_web.dart'),
    ).readAsStringSync();
    final plantilla = RegExp(
      r"'''(function \$\{_frameId\}_print\(\)\{.*?\})'''",
    ).firstMatch(codigo)!.group(1)!;
    final frame = RegExp(r"_frameId = '(\w+)'").firstMatch(codigo)!.group(1)!;
    final script = plantilla
        .replaceAll(r'${_frameId}', frame)
        .replaceAll(r'$_frameId', frame);
    final huella = base64.encode(sha256.convert(utf8.encode(script)).bytes);
    expect(referencia['Content-Security-Policy'], contains("'sha256-$huella'"));
    expect(
      File('web/pdfjs/iniciar.js').readAsStringSync(),
      contains('window.${frame}_print = function'),
    );
  });
}
