import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/pwa/csp_en_html.dart';

void main() {
  final csp = cspParaHtml(File('web/_headers').readAsStringSync());
  final html = File('web/index.html').readAsStringSync();

  test('la misma CSP de _headers, sin frame-ancestors', () {
    expect(csp, startsWith("default-src 'self'; script-src 'self'"));
    expect(csp, contains("'wasm-unsafe-eval'"));
    expect(csp, isNot(contains('frame-ancestors')));
  });

  test('va antes de cualquier script y no se repite', () {
    final una = insertarCsp(html, csp);
    final i = una.indexOf('http-equiv="Content-Security-Policy"');
    expect(i, greaterThan(una.indexOf('<meta charset')));
    expect(i, lessThan(una.indexOf('<script')));
    final dos = insertarCsp(una, csp);
    expect(
      RegExp('Content-Security-Policy').allMatches(dos).length,
      1,
      reason: 'compilar dos veces',
    );
  });
}
