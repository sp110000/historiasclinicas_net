import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import 'motor_aes.dart';

MotorAes crearMotorAes() => MotorAesDart();

class _LlaveDart extends LlaveAes {
  _LlaveDart(this.secreta);

  final SecretKey secreta;
}

/// AES-256-GCM en Dart puro (VM y pruebas).
class MotorAesDart implements MotorAes {
  final _aes = DartAesGcm.with256bits();

  static const _largoEtiqueta = 16;

  @override
  Future<LlaveAes> importar(Uint8List bytes) async {
    if (bytes.length != 32) {
      throw ArgumentError('La llave debe tener 32 bytes');
    }
    return _LlaveDart(SecretKey(Uint8List.fromList(bytes)));
  }

  @override
  Future<Uint8List> cifrar(
    LlaveAes llave,
    Uint8List nonce,
    Uint8List claro, {
    required Uint8List aad,
  }) async {
    final caja = await _aes.encrypt(
      claro,
      secretKey: (llave as _LlaveDart).secreta,
      nonce: nonce,
      aad: aad,
    );
    return Uint8List.fromList([...caja.cipherText, ...caja.mac.bytes]);
  }

  @override
  Future<Uint8List> descifrar(
    LlaveAes llave,
    Uint8List nonce,
    Uint8List cifrado, {
    required Uint8List aad,
  }) async {
    if (cifrado.length < _largoEtiqueta) throw const ErrorDescifrado();
    final corte = cifrado.length - _largoEtiqueta;
    try {
      final claro = await _aes.decrypt(
        SecretBox(
          cifrado.sublist(0, corte),
          nonce: nonce,
          mac: Mac(cifrado.sublist(corte)),
        ),
        secretKey: (llave as _LlaveDart).secreta,
        aad: aad,
      );
      return Uint8List.fromList(claro);
    } on SecretBoxAuthenticationError {
      throw const ErrorDescifrado();
    }
  }
}
