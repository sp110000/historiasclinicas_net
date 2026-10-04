import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../secretos/almacen_secretos.dart';

/// Cifrado en reposo de los documentos RDA, de sus entradas y de las
/// respuestas: AES-256-GCM con el paquete `cryptography` (en el navegador
/// usa la Web Cryptography API). La llave se genera en el equipo y se
/// guarda solo en el [AlmacenSecretos], nunca junto a los datos.
class CifradorDatos {
  CifradorDatos(this._secretos, {AesGcm? algoritmo})
    : _algoritmo = algoritmo ?? AesGcm.with256bits();

  final AlmacenSecretos _secretos;
  final AesGcm _algoritmo;
  Future<SecretKey>? _llave;

  Future<SecretKey> _obtenerLlave() => _llave ??= () async {
    final guardada = await _secretos.leer(ClavesSecretas.llaveDatos);
    if (guardada != null) return SecretKey(base64Decode(guardada));
    final nueva = await _algoritmo.newSecretKey();
    await _secretos.escribir(
      ClavesSecretas.llaveDatos,
      base64Encode(await nueva.extractBytes()),
    );
    return nueva;
  }();

  /// `{"v":1,"n":nonce,"c":cifrado,"m":mac}` en base64.
  Future<String> cifrar(List<int> claro) async {
    final caja = await _algoritmo.encrypt(
      claro,
      secretKey: await _obtenerLlave(),
    );
    return jsonEncode({
      'v': 1,
      'n': base64Encode(caja.nonce),
      'c': base64Encode(caja.cipherText),
      'm': base64Encode(caja.mac.bytes),
    });
  }

  /// Lanza [SecretBoxAuthenticationError] si el contenido fue alterado.
  Future<Uint8List> descifrar(String sobre) async {
    final m = (jsonDecode(sobre) as Map).cast<String, Object?>();
    if (m['v'] != 1) throw const FormatException('Versión de sobre no válida');
    final claro = await _algoritmo.decrypt(
      SecretBox(
        base64Decode(m['c']! as String),
        nonce: base64Decode(m['n']! as String),
        mac: Mac(base64Decode(m['m']! as String)),
      ),
      secretKey: await _obtenerLlave(),
    );
    return Uint8List.fromList(claro);
  }

  Future<String> cifrarTexto(String texto) => cifrar(utf8.encode(texto));

  Future<String> descifrarTexto(String sobre) async =>
      utf8.decode(await descifrar(sobre));
}
