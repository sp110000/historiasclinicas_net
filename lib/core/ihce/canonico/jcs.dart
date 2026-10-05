import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// JSON canónico según RFC 8785 (JCS): claves ordenadas por unidades
/// UTF-16, sin espacios, cadenas con el escape mínimo de JSON y números en
/// la forma de ECMAScript. Los mismos datos dan los mismos bytes y, por
/// tanto, el mismo `bundle_sha256`.
///
/// Distinto de `lib/core/integridad/json_canonico.dart`, que escapa todo a
/// ASCII para el adjunto del PDF.
String jcs(Object? valor) {
  final b = StringBuffer();
  _escribir(b, valor);
  return b.toString();
}

Uint8List jcsBytes(Object? valor) =>
    Uint8List.fromList(utf8.encode(jcs(valor)));

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

void _escribir(StringBuffer b, Object? v) {
  switch (v) {
    case null:
      b.write('null');
    case bool():
      b.write(v ? 'true' : 'false');
    case num():
      b.write(_numero(v));
    case String():
      _cadena(b, v);
    case List():
      b.write('[');
      for (var i = 0; i < v.length; i++) {
        if (i > 0) b.write(',');
        _escribir(b, v[i]);
      }
      b.write(']');
    case Map():
      // Las claves se comparan por unidades UTF-16 (String.compareTo).
      final claves = [for (final k in v.keys) k as String]..sort();
      b.write('{');
      for (var i = 0; i < claves.length; i++) {
        if (i > 0) b.write(',');
        _cadena(b, claves[i]);
        b.write(':');
        _escribir(b, v[claves[i]]);
      }
      b.write('}');
    default:
      throw ArgumentError('No se puede canonicalizar ${v.runtimeType}');
  }
}

String _numero(num n) {
  if (n is int) return n.toString();
  final d = n.toDouble();
  if (!d.isFinite) throw ArgumentError('Número no finito en JSON: $d');
  if (d == 0) return '0'; // también -0
  if (d == d.truncateToDouble() && d.abs() < 1e21) {
    return d.toInt().toString();
  }
  // El double.toString de Dart da la representación más corta que vuelve
  // al mismo valor, como Number.prototype.toString de ECMAScript.
  return d.toString();
}

void _cadena(StringBuffer b, String s) {
  b.write('"');
  for (final c in s.codeUnits) {
    switch (c) {
      case 0x22:
        b.write(r'\"');
      case 0x5C:
        b.write(r'\\');
      case 0x08:
        b.write(r'\b');
      case 0x0C:
        b.write(r'\f');
      case 0x0A:
        b.write(r'\n');
      case 0x0D:
        b.write(r'\r');
      case 0x09:
        b.write(r'\t');
      default:
        if (c < 0x20) {
          b.write('\\u${c.toRadixString(16).padLeft(4, '0')}');
        } else {
          b.writeCharCode(c);
        }
    }
  }
  b.write('"');
}
