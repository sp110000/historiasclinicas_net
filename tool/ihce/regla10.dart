// Comprobación automática de la regla 10 (interfaz mínima) frente al commit
// base de la rama: sin dependencias de UI nuevas, sin cambios en archivos de
// tema o estilos, y todo archivo de presentación tocado figura en
// docs/ihce/CAMBIOS_UI.md. Solo dart:io.
//
//   dart tool/ihce/regla10.dart [commit-base]
import 'dart:io';

/// Dependencias nuevas admitidas (ninguna es de UI). Justificación en
/// docs/ihce/README.md («Dependencias»).
const _dependenciasPermitidas = {
  'cryptography', // AES-256-GCM de los datos en reposo
  'flutter_secure_storage', // credenciales y llave de cifrado (regla 3)
  'http', // transporte y MockClient de las pruebas
  'json_schema', // capa 1 del gate antes del envío
};

/// Archivos de tema y estilos: no se tocan.
const _estilos = [
  'lib/app/tema.dart',
  'lib/core/pdf/fuentes_pdf.dart',
  'web/',
  'assets/fonts/',
];

/// Archivos de presentación: si se tocan, van en CAMBIOS_UI.md.
const _presentacion = ['lib/features/', 'lib/core/widgets/', 'lib/app/'];

void main(List<String> args) {
  final base = args.isNotEmpty ? args.first : _base();
  final fallos = <String>[];

  // 1. Dependencias.
  final antes = _dependencias(_git(['show', '$base:pubspec.yaml']));
  final ahora = _dependencias(File('pubspec.yaml').readAsStringSync());
  final nuevas = ahora.difference(antes);
  for (final d in nuevas.difference(_dependenciasPermitidas)) {
    fallos.add('Dependencia nueva no permitida: $d');
  }
  stdout.writeln(
    'Dependencias nuevas: ${nuevas.isEmpty ? 'ninguna' : (nuevas.toList()..sort()).join(', ')}',
  );

  // 2. Tema y estilos.
  final estilos = _cambiados(base, _estilos);
  for (final f in estilos) {
    fallos.add('Archivo de tema o estilo modificado: $f');
  }
  stdout.writeln('Archivos de tema/estilo modificados: ${estilos.length}');

  // 3. Inventario de cambios de interfaz.
  final inventario = File('docs/ihce/CAMBIOS_UI.md');
  final texto = inventario.existsSync() ? inventario.readAsStringSync() : '';
  final presentacion = _cambiados(base, _presentacion);
  for (final f in presentacion) {
    if (!texto.contains(f)) fallos.add('$f no figura en CAMBIOS_UI.md');
  }
  stdout.writeln(
    'Archivos de presentación tocados: ${presentacion.length} '
    '(todos deben figurar en docs/ihce/CAMBIOS_UI.md)',
  );

  if (fallos.isEmpty) {
    stdout.writeln('Regla 10 en verde (base $base).');
    return;
  }
  stdout.writeln('Regla 10 en ROJO:');
  for (final f in fallos) {
    stdout.writeln('  $f');
  }
  exit(1);
}

String _base() {
  final r = Process.runSync('git', ['merge-base', 'HEAD', 'origin/main']);
  final b = (r.stdout as String).trim();
  return r.exitCode == 0 && b.isNotEmpty ? b : 'ecc16a4';
}

String _git(List<String> args) {
  final r = Process.runSync('git', args);
  if (r.exitCode != 0) {
    stderr.writeln('git ${args.join(' ')}: ${r.stderr}');
    exit(2);
  }
  return r.stdout as String;
}

List<String> _cambiados(String base, List<String> rutas) => _git([
  'diff',
  '--name-only',
  base,
  '--',
  ...rutas,
]).split('\n').where((l) => l.trim().isNotEmpty).toList();

/// Nombres bajo `dependencies:` y `dev_dependencies:` (dos espacios de
/// sangría) de un pubspec.yaml.
Set<String> _dependencias(String pubspec) {
  final r = <String>{};
  var dentro = false;
  for (final l in pubspec.split('\n')) {
    if (RegExp(r'^\S').hasMatch(l)) {
      dentro =
          l.startsWith('dependencies:') || l.startsWith('dev_dependencies:');
      continue;
    }
    final m = RegExp(r'^  ([a-z0-9_]+):').firstMatch(l);
    if (dentro && m != null) r.add(m.group(1)!);
  }
  return r;
}
