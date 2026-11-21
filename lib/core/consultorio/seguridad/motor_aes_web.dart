import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'motor_aes.dart';

MotorAes crearMotorAes() => MotorAesWeb();

class _LlaveWeb extends LlaveAes {
  _LlaveWeb(this.cryptoKey);

  final web.CryptoKey cryptoKey;
}

/// AES-256-GCM con la Web Cryptography API. La llave se importa como **no
/// extraíble** (`extractable: false`).
class MotorAesWeb implements MotorAes {
  web.SubtleCrypto get _sutil {
    if (!web.window.isSecureContext) {
      throw StateError(
        'El consultorio necesita una conexión segura (HTTPS) para cifrar.',
      );
    }
    return web.window.crypto.subtle;
  }

  JSObject _parametros(Uint8List nonce, Uint8List aad) => JSObject()
    ..setProperty('name'.toJS, 'AES-GCM'.toJS)
    ..setProperty('iv'.toJS, nonce.toJS)
    ..setProperty('additionalData'.toJS, aad.toJS)
    ..setProperty('tagLength'.toJS, 128.toJS);

  @override
  Future<LlaveAes> importar(Uint8List bytes) async {
    if (bytes.length != 32) {
      throw ArgumentError('La llave debe tener 32 bytes');
    }
    final llave = await _sutil
        .importKey(
          'raw',
          bytes.toJS,
          JSObject()..setProperty('name'.toJS, 'AES-GCM'.toJS),
          false,
          ['encrypt'.toJS, 'decrypt'.toJS].toJS,
        )
        .toDart;
    return _LlaveWeb(llave);
  }

  @override
  Future<Uint8List> cifrar(
    LlaveAes llave,
    Uint8List nonce,
    Uint8List claro, {
    required Uint8List aad,
  }) async {
    final r = await _sutil
        .encrypt(
          _parametros(nonce, aad),
          (llave as _LlaveWeb).cryptoKey,
          claro.toJS,
        )
        .toDart;
    return (r! as JSArrayBuffer).toDart.asUint8List();
  }

  @override
  Future<Uint8List> descifrar(
    LlaveAes llave,
    Uint8List nonce,
    Uint8List cifrado, {
    required Uint8List aad,
  }) async {
    try {
      final r = await _sutil
          .decrypt(
            _parametros(nonce, aad),
            (llave as _LlaveWeb).cryptoKey,
            cifrado.toJS,
          )
          .toDart;
      return (r! as JSArrayBuffer).toDart.asUint8List();
    } catch (_) {
      // WebCrypto rechaza con OperationError si la etiqueta no coincide.
      throw const ErrorDescifrado();
    }
  }
}
