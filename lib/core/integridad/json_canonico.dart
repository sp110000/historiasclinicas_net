import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Serializa [valor] como JSON canónico:
///
/// * claves de los mapas ordenadas por unidades de código,
/// * sin espacios,
/// * solo caracteres ASCII (todo lo demás se escapa como `\uXXXX`),
/// * números enteros sin parte decimal, aunque vengan como `double`.
///
/// El resultado es idéntico en la VM de Dart y en el navegador, por lo que
/// sirve para calcular hashes reproducibles.
String jsonCanonico(Object? valor) {
  final buffer = StringBuffer();
  _escribir(buffer, valor);
  return buffer.toString();
}

/// SHA-256 en hexadecimal (minúsculas) del JSON canónico de [valor].
String sha256Canonico(Object? valor) =>
    sha256.convert(ascii.encode(jsonCanonico(valor))).toString();

void _escribir(StringBuffer b, Object? valor) {
  switch (valor) {
    case null:
      b.write('null');
    case bool v:
      b.write(v ? 'true' : 'false');
    case num v:
      _escribirNumero(b, v);
    case String v:
      _escribirTexto(b, v);
    case Map<Object?, Object?> v:
      final claves = v.keys.map((k) {
        if (k is! String) {
          throw ArgumentError('Las claves JSON deben ser texto: $k');
        }
        return k;
      }).toList()..sort();
      b.write('{');
      for (var i = 0; i < claves.length; i++) {
        if (i > 0) b.write(',');
        _escribirTexto(b, claves[i]);
        b.write(':');
        _escribir(b, v[claves[i]]);
      }
      b.write('}');
    case Iterable<Object?> v:
      b.write('[');
      var primero = true;
      for (final e in v) {
        if (!primero) b.write(',');
        primero = false;
        _escribir(b, e);
      }
      b.write(']');
    default:
      throw ArgumentError('Tipo no serializable en JSON: ${valor.runtimeType}');
  }
}

void _escribirNumero(StringBuffer b, num v) {
  if (v.isNaN || v.isInfinite) {
    throw ArgumentError('Número no representable en JSON: $v');
  }
  // En el navegador 72.0 y 72 son el mismo número; en la VM no. Se unifican.
  if (v == v.truncateToDouble() && v.abs() < 9007199254740992) {
    b.write(v.toInt().toString());
  } else {
    b.write(v.toString());
  }
}

void _escribirTexto(StringBuffer b, String s) {
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
        if (c < 0x20 || c > 0x7E) {
          b.write(r'\u');
          b.write(c.toRadixString(16).padLeft(4, '0'));
        } else {
          b.writeCharCode(c);
        }
    }
  }
  b.write('"');
}
