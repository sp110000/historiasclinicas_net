import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'derivacion.dart';
import 'motor_aes.dart';

/// La frase (o el código) no abre el llavero.
class SecretoIncorrecto implements Exception {
  const SecretoIncorrecto();

  @override
  String toString() => 'SecretoIncorrecto';
}

/// La llave de datos envuelta (cifrada) con una llave derivada de un
/// secreto.
class SobreLlave {
  const SobreLlave({
    required this.parametros,
    required this.sal,
    required this.nonce,
    required this.envuelta,
  });

  final ParametrosDerivacion parametros;
  final Uint8List sal;
  final Uint8List nonce;

  /// AES-256-GCM(llave derivada, llave de datos), con su etiqueta.
  final Uint8List envuelta;

  Map<String, Object?> aMapa() => {
    'derivacion': parametros.aMapa(),
    'sal': base64Encode(sal),
    'nonce': base64Encode(nonce),
    'envuelta': base64Encode(envuelta),
  };

  static SobreLlave desdeMapa(Map<String, Object?> m) => SobreLlave(
    parametros: ParametrosDerivacion.desdeMapa(
      (m['derivacion']! as Map).cast<String, Object?>(),
    ),
    sal: base64Decode(m['sal']! as String),
    nonce: base64Decode(m['nonce']! as String),
    envuelta: base64Decode(m['envuelta']! as String),
  );
}

/// Llave en sobre: una llave de datos aleatoria cifra todo el consultorio, y
/// se guarda envuelta dos veces, con la frase de acceso y con el código de
/// recuperación. Cambiar la frase solo vuelve a envolver la llave de datos.
///
/// El llavero se guarda en claro (en `meta`): no contiene secretos, solo
/// sales, parámetros y las llaves envueltas.
class Llavero {
  const Llavero({
    required this.creado,
    required this.frase,
    required this.codigo,
  });

  static const formato = 1;

  final DateTime creado;
  final SobreLlave frase;
  final SobreLlave codigo;

  Llavero conFrase(SobreLlave nueva) =>
      Llavero(creado: creado, frase: nueva, codigo: codigo);

  Llavero conCodigo(SobreLlave nuevo) =>
      Llavero(creado: creado, frase: frase, codigo: nuevo);

  Map<String, Object?> aMapa() => {
    'formato': formato,
    'creado': creado.toUtc().toIso8601String(),
    'frase': frase.aMapa(),
    'codigo': codigo.aMapa(),
  };

  Uint8List aBytes() => Uint8List.fromList(utf8.encode(jsonEncode(aMapa())));

  static Llavero desdeMapa(Map<String, Object?> m) {
    if (m['formato'] != formato) {
      throw FormatException('Formato de llavero no soportado: ${m['formato']}');
    }
    return Llavero(
      creado: DateTime.parse(m['creado']! as String),
      frase: SobreLlave.desdeMapa((m['frase']! as Map).cast()),
      codigo: SobreLlave.desdeMapa((m['codigo']! as Map).cast()),
    );
  }

  static Llavero desdeBytes(Uint8List b) =>
      desdeMapa((jsonDecode(utf8.decode(b)) as Map).cast());
}

/// Alfabeto Crockford base32 (sin I, L, O ni U para no confundirlas).
const _alfabetoCodigo = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Largo del código de recuperación: 24 caracteres, 120 bits al azar.
const largoCodigoRecuperacion = 24;

/// `ABCD-EFGH-…` en 6 grupos de 4.
String formatearCodigo(String codigo) {
  final n = normalizarCodigo(codigo);
  return [
    for (var i = 0; i < n.length; i += 4) n.substring(i, min(i + 4, n.length)),
  ].join('-');
}

/// Mayúsculas, sin guiones ni espacios, y con O → 0 e I/L → 1, como se
/// lee el alfabeto Crockford.
String normalizarCodigo(String codigo) => codigo
    .toUpperCase()
    .replaceAll(RegExp(r'[\s-]'), '')
    .replaceAll('O', '0')
    .replaceAll(RegExp('[IL]'), '1');

bool codigoBienFormado(String codigo) {
  final n = normalizarCodigo(codigo);
  return n.length == largoCodigoRecuperacion &&
      n.split('').every(_alfabetoCodigo.contains);
}

const _aadFrase = 'hcc1|llavero|frase';
const _aadCodigo = 'hcc1|llavero|codigo';

/// Crea, abre y cambia llaveros.
class FabricaLlavero {
  FabricaLlavero(
    this._motor, {
    this.parametrosFrase = ParametrosDerivacion.frasePorDefecto,
    this.parametrosCodigo = ParametrosDerivacion.codigoPorDefecto,
    Random? azar,
  }) : _azar = azar ?? Random.secure();

  final MotorAes _motor;
  final ParametrosDerivacion parametrosFrase;
  final ParametrosDerivacion parametrosCodigo;
  final Random _azar;

  Uint8List _bytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _azar.nextInt(256)));

  String _codigoNuevo() => List.generate(
    largoCodigoRecuperacion,
    (_) => _alfabetoCodigo[_azar.nextInt(_alfabetoCodigo.length)],
  ).join();

  Future<SobreLlave> _envolver(
    Uint8List llaveDatos,
    String secreto,
    ParametrosDerivacion p,
    String aad,
  ) async {
    final sal = _bytes(16);
    final nonce = _bytes(12);
    final derivada = await derivarLlave(secreto, sal, p);
    try {
      final envuelta = await _motor.cifrar(
        await _motor.importar(derivada),
        nonce,
        llaveDatos,
        aad: Uint8List.fromList(utf8.encode(aad)),
      );
      return SobreLlave(
        parametros: p,
        sal: sal,
        nonce: nonce,
        envuelta: envuelta,
      );
    } finally {
      derivada.fillRange(0, derivada.length, 0);
    }
  }

  Future<Uint8List> _abrir(SobreLlave s, String secreto, String aad) async {
    final derivada = await derivarLlave(secreto, s.sal, s.parametros);
    try {
      return await _motor.descifrar(
        await _motor.importar(derivada),
        s.nonce,
        s.envuelta,
        aad: Uint8List.fromList(utf8.encode(aad)),
      );
    } on ErrorDescifrado {
      throw const SecretoIncorrecto();
    } finally {
      derivada.fillRange(0, derivada.length, 0);
    }
  }

  /// Llavero nuevo con una llave de datos al azar. Devuelve también el
  /// código de recuperación (se muestra una sola vez) y la llave de datos.
  Future<({Llavero llavero, String codigo, Uint8List llaveDatos})> crear(
    String frase, {
    required DateTime ahora,
  }) async {
    final llaveDatos = _bytes(32);
    final codigo = _codigoNuevo();
    final llavero = Llavero(
      creado: ahora,
      frase: await _envolver(llaveDatos, frase, parametrosFrase, _aadFrase),
      codigo: await _envolver(llaveDatos, codigo, parametrosCodigo, _aadCodigo),
    );
    return (llavero: llavero, codigo: codigo, llaveDatos: llaveDatos);
  }

  /// Lanza [SecretoIncorrecto] si la frase no es la del llavero.
  Future<Uint8List> abrirConFrase(Llavero l, String frase) =>
      _abrir(l.frase, frase, _aadFrase);

  /// Lanza [SecretoIncorrecto] si el código no es el del llavero.
  Future<Uint8List> abrirConCodigo(Llavero l, String codigo) =>
      _abrir(l.codigo, normalizarCodigo(codigo), _aadCodigo);

  /// El mismo llavero con la llave de datos envuelta con [nuevaFrase].
  Future<Llavero> cambiarFrase(
    Llavero l,
    Uint8List llaveDatos,
    String nuevaFrase,
  ) async => l.conFrase(
    await _envolver(llaveDatos, nuevaFrase, parametrosFrase, _aadFrase),
  );

  /// El mismo llavero con un código de recuperación nuevo (el anterior deja
  /// de servir). Devuelve también el código, que se muestra una sola vez.
  Future<({Llavero llavero, String codigo})> cambiarCodigo(
    Llavero l,
    Uint8List llaveDatos,
  ) async {
    final codigo = _codigoNuevo();
    final sobre = await _envolver(
      llaveDatos,
      codigo,
      parametrosCodigo,
      _aadCodigo,
    );
    return (llavero: l.conCodigo(sobre), codigo: codigo);
  }
}
