/// AES-256-GCM con datos asociados (AAD).
///
/// En el navegador usa la Web Cryptography API con la llave importada como
/// **no extraíble**: el código de la página puede usarla, pero no leer sus
/// bytes. En la VM (pruebas) usa la implementación en Dart de
/// `cryptography`. Las dos producen el mismo formato (texto cifrado seguido
/// de la etiqueta de 16 bytes), así que lo cifrado en una se descifra en la
/// otra.
library;

import 'dart:typed_data';

export 'motor_aes_dart.dart'
    if (dart.library.js_interop) 'motor_aes_web.dart'
    show crearMotorAes;

/// Llave importada en el motor. Opaca: no da acceso a sus bytes.
abstract class LlaveAes {}

/// La etiqueta GCM no coincide: llave equivocada, datos alterados o AAD
/// distinta.
class ErrorDescifrado implements Exception {
  const ErrorDescifrado();

  @override
  String toString() => 'ErrorDescifrado: los datos no se pudieron verificar';
}

abstract interface class MotorAes {
  /// Importa 32 bytes como llave AES-256.
  Future<LlaveAes> importar(Uint8List bytes);

  /// Devuelve el texto cifrado seguido de la etiqueta (16 bytes).
  Future<Uint8List> cifrar(
    LlaveAes llave,
    Uint8List nonce,
    Uint8List claro, {
    required Uint8List aad,
  });

  /// Lanza [ErrorDescifrado] si la etiqueta no coincide.
  Future<Uint8List> descifrar(
    LlaveAes llave,
    Uint8List nonce,
    Uint8List cifrado, {
    required Uint8List aad,
  });
}
