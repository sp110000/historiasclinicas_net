import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../ihce/extraccion/normalizacion.dart' show componerNfc;

/// Cómo se deriva una llave de 256 bits a partir de un secreto (la frase de
/// acceso o el código de recuperación). Se guarda junto a la llave envuelta,
/// así que cambiar los valores por defecto no invalida llaveros existentes.
class ParametrosDerivacion {
  const ParametrosDerivacion.pbkdf2(this.iteraciones)
    : algoritmo = idPbkdf2,
      memoriaKib = 0,
      paralelismo = 1;

  const ParametrosDerivacion.argon2id({
    required this.memoriaKib,
    required this.iteraciones,
    this.paralelismo = 1,
  }) : algoritmo = idArgon2id;

  static const idPbkdf2 = 'pbkdf2-sha256';
  static const idArgon2id = 'argon2id';

  /// PBKDF2-HMAC-SHA256 con 600.000 iteraciones: la cifra de OWASP (2023)
  /// para PBKDF2-SHA256. VERIFICAR la recomendación vigente.
  static const frasePorDefecto = ParametrosDerivacion.pbkdf2(600000);

  /// El código de recuperación tiene 120 bits al azar: no necesita tantas
  /// iteraciones como una frase elegida por una persona.
  static const codigoPorDefecto = ParametrosDerivacion.pbkdf2(100000);

  /// Argon2id con 19 MiB, 2 pasadas y 1 hilo (OWASP, 2023). En el
  /// navegador corre en Dart puro: se mide antes de proponerlo.
  static const argon2idOwasp = ParametrosDerivacion.argon2id(
    memoriaKib: 19456,
    iteraciones: 2,
  );

  final String algoritmo;
  final int iteraciones;
  final int memoriaKib;
  final int paralelismo;

  Map<String, Object?> aMapa() => {
    'algoritmo': algoritmo,
    'iteraciones': iteraciones,
    if (algoritmo == idArgon2id) 'memoriaKib': memoriaKib,
    if (algoritmo == idArgon2id) 'paralelismo': paralelismo,
  };

  static ParametrosDerivacion desdeMapa(Map<String, Object?> m) {
    final iteraciones = m['iteraciones'];
    if (iteraciones is! int || iteraciones < 1) {
      throw const FormatException('Parámetros de derivación no válidos');
    }
    return switch (m['algoritmo']) {
      idPbkdf2 => ParametrosDerivacion.pbkdf2(iteraciones),
      idArgon2id => ParametrosDerivacion.argon2id(
        memoriaKib: m['memoriaKib'] as int? ?? 0,
        iteraciones: iteraciones,
        paralelismo: m['paralelismo'] as int? ?? 1,
      ),
      _ => throw FormatException(
        'Algoritmo de derivación desconocido: ${m['algoritmo']}',
      ),
    };
  }

  String get descripcion => algoritmo == idArgon2id
      ? 'Argon2id · ${memoriaKib ~/ 1024} MiB · $iteraciones pasadas'
      : 'PBKDF2-HMAC-SHA256 · $iteraciones iteraciones';
}

/// Secreto tal como se deriva: sin espacios en los extremos y con las tildes
/// compuestas, para que la misma frase escrita en otro teclado dé la misma
/// llave.
List<int> normalizarSecreto(String secreto) =>
    utf8.encode(componerNfc(secreto.trim()));

/// Deriva 32 bytes. En el navegador, PBKDF2 usa la Web Cryptography API.
Future<Uint8List> derivarLlave(
  String secreto,
  List<int> sal,
  ParametrosDerivacion p,
) async {
  final KdfAlgorithm kdf = switch (p.algoritmo) {
    ParametrosDerivacion.idArgon2id => Argon2id(
      parallelism: p.paralelismo,
      memory: p.memoriaKib,
      iterations: p.iteraciones,
      hashLength: 32,
    ),
    _ => Pbkdf2.hmacSha256(iterations: p.iteraciones, bits: 256),
  };
  final llave = await kdf.deriveKey(
    secretKey: SecretKey(normalizarSecreto(secreto)),
    nonce: sal,
  );
  return Uint8List.fromList(await llave.extractBytes());
}
