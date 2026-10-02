// Copia la Content-Security-Policy de web/_headers dentro de index.html
// (<meta http-equiv>), para hostings que no permiten cabeceras propias, como
// GitHub Pages. La usa `tool/construir_web.sh --csp-en-html`, antes de
// generar el service worker.
//
//   dart run tool/pwa/csp_en_html.dart [build/web]
import 'dart:io';

/// La CSP de [headers] (formato de Netlify) sin `frame-ancestors`, que en un
/// <meta> no se admite (el navegador la ignora y lo avisa en la consola).
String cspParaHtml(String headers) {
  final linea = headers
      .split('\n')
      .map((l) => l.trim())
      .firstWhere(
        (l) => l.startsWith('Content-Security-Policy:'),
        orElse: () => throw StateError('web/_headers no tiene CSP'),
      );
  return linea
      .substring('Content-Security-Policy:'.length)
      .split(';')
      .map((d) => d.trim())
      .where((d) => d.isNotEmpty && !d.startsWith('frame-ancestors'))
      .join('; ');
}

/// [html] con la CSP justo después de `<meta charset>`, antes de cualquier
/// script. Si ya la tenía, la reemplaza.
String insertarCsp(String html, String csp) {
  final meta = '<meta http-equiv="Content-Security-Policy" content="$csp">';
  final previa = RegExp(r'\s*<meta http-equiv="Content-Security-Policy"[^>]*>');
  final limpio = html.replaceAll(previa, '');
  final charset = RegExp(r'<meta charset="[^"]*">').firstMatch(limpio);
  if (charset == null) throw StateError('index.html sin <meta charset>');
  return '${limpio.substring(0, charset.end)}\n  $meta'
      '${limpio.substring(charset.end)}';
}

void main(List<String> args) {
  final web = args.isEmpty ? 'build/web' : args.first;
  final index = File('$web/index.html');
  final csp = cspParaHtml(File('web/_headers').readAsStringSync());
  index.writeAsStringSync(insertarCsp(index.readAsStringSync(), csp));
  stdout.writeln('${index.path}: Content-Security-Policy incluida.');
}
