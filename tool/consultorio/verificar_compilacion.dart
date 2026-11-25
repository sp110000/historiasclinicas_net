// Comprueba en una compilación web si el módulo del consultorio quedó
// dentro de main.dart.js. Con la bandera apagada (el sitio público) no debe
// estar: la constante CONSULTORIO_ENABLED hace que el compilador descarte
// todo el código del consultorio.
//
//   dart run tool/consultorio/verificar_compilacion.dart build/web --sin-modulo
//   dart run tool/consultorio/verificar_compilacion.dart build/web-consultorio --con-modulo
import 'dart:io';

/// Nombre de la base de IndexedDB del consultorio
/// (`lib/core/consultorio/config.dart`): solo aparece si el módulo se
/// compiló.
const marcaModulo = 'historiasclinicas_consultorio';

/// `true` si [js] contiene el módulo del consultorio.
bool contieneModulo(String js) => js.contains(marcaModulo);

void main(List<String> args) {
  if (args.length != 2 || !{'--sin-modulo', '--con-modulo'}.contains(args[1])) {
    stderr.writeln(
      'Uso: dart run tool/consultorio/verificar_compilacion.dart '
      '<carpeta> --sin-modulo|--con-modulo',
    );
    exit(2);
  }
  final archivo = File('${args[0]}/main.dart.js');
  if (!archivo.existsSync()) {
    stderr.writeln('No existe ${archivo.path}: compila primero.');
    exit(2);
  }
  final esperaModulo = args[1] == '--con-modulo';
  final tiene = contieneModulo(archivo.readAsStringSync());
  final kb = (archivo.lengthSync() / 1024).round();
  if (tiene != esperaModulo) {
    stderr.writeln(
      tiene
          ? 'ERROR: ${archivo.path} ($kb KB) contiene el módulo del '
                'consultorio, y la bandera debería estar apagada.'
          : 'ERROR: ${archivo.path} ($kb KB) no contiene el módulo del '
                'consultorio, y la bandera debería estar encendida.',
    );
    exit(1);
  }
  stdout.writeln(
    '${archivo.path} ($kb KB): '
    '${tiene ? 'con' : 'sin'} el módulo del consultorio, como se esperaba.',
  );
}
