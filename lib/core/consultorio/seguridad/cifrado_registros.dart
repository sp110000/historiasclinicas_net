import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'motor_aes.dart';

/// Cifra cada registro y cada binario con la llave de datos.
///
/// Formato: `[formato 1 B][nonce 12 B][texto cifrado + etiqueta 16 B]`. La
/// AAD es `hcc1|<colección>|<id>` (o `hcc1|bin|<tipo>|<id>`): un registro
/// copiado sobre la clave de otro no se descifra.
class CifradoRegistros {
  CifradoRegistros(this._motor, this._llave, {Random? azar})
    : _azar = azar ?? Random.secure();

  static const formato = 1;
  static const _largoNonce = 12;

  final MotorAes _motor;
  final LlaveAes _llave;
  final Random _azar;

  static Uint8List aadDe(String texto) =>
      Uint8List.fromList(utf8.encode(texto));

  Future<Uint8List> cifrar(Uint8List claro, String aad) async {
    final nonce = Uint8List.fromList(
      List<int>.generate(_largoNonce, (_) => _azar.nextInt(256)),
    );
    final cifrado = await _motor.cifrar(_llave, nonce, claro, aad: aadDe(aad));
    return Uint8List.fromList([formato, ...nonce, ...cifrado]);
  }

  /// Lanza [ErrorDescifrado] si el contenido, la llave o la AAD no
  /// coinciden, y [FormatException] si el formato no es conocido.
  Future<Uint8List> descifrar(Uint8List sobre, String aad) {
    if (sobre.length < 1 + _largoNonce + 16) {
      throw const FormatException('Registro cifrado incompleto');
    }
    if (sobre[0] != formato) {
      throw FormatException('Formato de registro no soportado: ${sobre[0]}');
    }
    return _motor.descifrar(
      _llave,
      Uint8List.sublistView(sobre, 1, 1 + _largoNonce),
      Uint8List.sublistView(sobre, 1 + _largoNonce),
      aad: aadDe(aad),
    );
  }
}
