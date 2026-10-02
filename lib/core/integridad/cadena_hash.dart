/// Sellado de la historia con SHA-256 encadenado.
///
/// * `hashBase = SHA-256("historiasclinicas.net|base|" + JSON canónico de
///   la historia inicial)`, sin `evoluciones` ni `hashBase`.
/// * `hash₁ = SHA-256(JSON canónico de la evolución 1 sin "hash" + "|" +
///   hashBase)`, y cada evolución siguiente encadena con la anterior.
///
/// Los hashes se calculan siempre sobre los mapas tal como están guardados
/// en el PDF; lo ya sellado nunca se vuelve a serializar desde el modelo.
///
/// Límite: sin servidor ni clave secreta, quien conozca el método puede
/// recalcular la cadena. Detecta alteraciones accidentales o ingenuas; no
/// prueba la autoría.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'json_canonico.dart';

const _prefijoBase = 'historiasclinicas.net|base|';

String _sha256(String texto) => sha256.convert(ascii.encode(texto)).toString();

Map<String, Object?> _sin(Map<String, Object?> m, Set<String> claves) => {
  for (final e in m.entries)
    if (!claves.contains(e.key)) e.key: e.value,
};

/// Hash de la historia inicial.
String calcularHashBase(Map<String, Object?> base) => _sha256(
  _prefijoBase + jsonCanonico(_sin(base, {'evoluciones', 'hashBase'})),
);

/// Hash de una evolución encadenado con el anterior.
String calcularHashEvolucion(Map<String, Object?> evolucion, String previo) =>
    _sha256('${jsonCanonico(_sin(evolucion, {'hash'}))}|$previo');

/// Sella la historia inicial: agrega `hashBase` y una lista de evoluciones
/// vacía.
Map<String, Object?> sellarBase(Map<String, Object?> base) {
  final limpia = _sin(base, {'evoluciones', 'hashBase'});
  return {
    ...limpia,
    'hashBase': calcularHashBase(limpia),
    'evoluciones': const <Object?>[],
  };
}

/// Agrega [nuevas] (mapas sin hash) al final de [datos] ya sellados.
Map<String, Object?> sellarEvoluciones(
  Map<String, Object?> datos,
  List<Map<String, Object?>> nuevas,
) {
  final anteriores = [
    for (final e in (datos['evoluciones'] as List?) ?? const [])
      (e as Map).cast<String, Object?>(),
  ];
  var previo = anteriores.isEmpty
      ? datos['hashBase']! as String
      : anteriores.last['hash']! as String;
  final selladas = <Map<String, Object?>>[];
  for (final e in nuevas) {
    final limpia = _sin(e, {'hash'});
    previo = calcularHashEvolucion(limpia, previo);
    selladas.add({...limpia, 'hash': previo});
  }
  return {
    ...datos,
    'evoluciones': [...anteriores, ...selladas],
  };
}

class ResultadoIntegridad {
  const ResultadoIntegridad({required this.sellos, this.primeraAlterada});

  /// Sellos revisados: la historia inicial más cada evolución.
  final int sellos;

  /// `null` si todo coincide; `0` si la historia inicial no coincide; `n`
  /// si la primera discrepancia está en la evolución `n` (desde 1).
  final int? primeraAlterada;

  bool get correcta => primeraAlterada == null;

  String get descripcion => switch (primeraAlterada) {
    null =>
      'Integridad verificada ($sellos ${sellos == 1 ? 'sello' : 'sellos encadenados'})',
    0 => 'Se detectaron alteraciones en la historia inicial',
    final n => 'Se detectaron alteraciones desde la evolución $n',
  };
}

/// Recalcula la cadena de [datos] y localiza la primera discrepancia.
ResultadoIntegridad verificarIntegridad(Map<String, Object?> datos) {
  final evoluciones = [
    for (final e in (datos['evoluciones'] as List?) ?? const [])
      (e as Map).cast<String, Object?>(),
  ];
  final sellos = evoluciones.length + 1;
  final hashBase = datos['hashBase'];
  if (hashBase is! String || calcularHashBase(datos) != hashBase) {
    return ResultadoIntegridad(sellos: sellos, primeraAlterada: 0);
  }
  var previo = hashBase;
  for (final (i, e) in evoluciones.indexed) {
    final esperado = calcularHashEvolucion(e, previo);
    if (e['hash'] != esperado) {
      return ResultadoIntegridad(sellos: sellos, primeraAlterada: i + 1);
    }
    previo = esperado;
  }
  return ResultadoIntegridad(sellos: sellos);
}

/// Huella corta para imprimir junto a cada entrada: `3f9a·c21e`.
String huella(String hash) => '${hash.substring(0, 4)}·${hash.substring(4, 8)}';
