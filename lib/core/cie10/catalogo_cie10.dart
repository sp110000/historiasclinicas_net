/// Catálogo CIE-10 que el médico importa una vez desde la fuente oficial de
/// su país (Colombia: tabla de referencia CIE-10 de SISPRO; España:
/// CIE-10-ES del Ministerio de Sanidad). VERIFICAR los términos de uso de
/// cada fuente. La app no incluye ningún catálogo.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../utils/texto.dart';

/// "J02.9" → "J029" (para comparar sin puntos ni espacios).
String normalizarCodigo(String codigo) =>
    codigo.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

final _patronCodigo = RegExp(r'^[A-Z][0-9]{2}(\.?[0-9A-Z]{1,4})?$');

/// `true` si [texto] tiene forma de código CIE-10 ("J02", "J02.9", "J029").
bool pareceCodigoCie10(String texto) =>
    _patronCodigo.hasMatch(texto.trim().toUpperCase());

String _normalizarTexto(String t) =>
    sinTildes(t.toLowerCase()).replaceAll(RegExp('[^a-z0-9]+'), ' ').trim();

class EntradaCie10 {
  EntradaCie10(this.codigo, this.descripcion)
    : _codigo = normalizarCodigo(codigo),
      _texto = ' ${_normalizarTexto(descripcion)}';

  /// Tal como viene en el catálogo ("J02.9" o "J029").
  final String codigo;
  final String descripcion;
  final String _codigo;
  final String _texto;

  Map<String, String> aMapa() => {'c': codigo, 'd': descripcion};
}

class CatalogoCie10 {
  CatalogoCie10(this.entradas);

  factory CatalogoCie10.desdeJson(String json) => CatalogoCie10([
    for (final e in jsonDecode(json) as List)
      EntradaCie10((e as Map)['c'] as String, e['d'] as String),
  ]);

  final List<EntradaCie10> entradas;

  int get length => entradas.length;

  String aJson() => jsonEncode([for (final e in entradas) e.aMapa()]);

  /// Por código ("J02", "j029", "J02.9") o por palabras de la descripción
  /// ("faring agud"), sin tildes ni mayúsculas.
  List<EntradaCie10> buscar(String consulta, {int maximo = 12}) {
    final q = consulta.trim();
    if (q.length < 2) return const [];
    if (RegExp(r'^[A-Za-z]\d').hasMatch(q) && !q.contains(' ')) {
      final c = normalizarCodigo(q);
      final r = [
        for (final e in entradas)
          if (e._codigo.startsWith(c)) e,
      ]..sort((a, b) => a._codigo.compareTo(b._codigo));
      return r.take(maximo).toList();
    }
    final palabras = _normalizarTexto(q).split(' ');
    final r = [
      for (final e in entradas)
        if (palabras.every((p) => e._texto.contains(' $p'))) e,
    ];
    // Primero las que empiezan por la primera palabra, luego las más cortas.
    int puntaje(EntradaCie10 e) =>
        (e._texto.startsWith(' ${palabras.first}') ? 0 : 1000) +
        e.descripcion.length;
    r.sort((a, b) => puntaje(a).compareTo(puntaje(b)));
    return r.take(maximo).toList();
  }
}

class LecturaCie10 {
  const LecturaCie10(this.catalogo, {required this.omitidas});

  final CatalogoCie10 catalogo;

  /// Líneas sin código reconocible (encabezados, notas…).
  final int omitidas;
}

/// Lee un catálogo en CSV, TSV, TXT (separado por `;`, `,`, tabulador o
/// `|`) o JSON. En cada fila toma el primer campo con forma de código y el
/// siguiente texto como descripción. Acepta UTF-8 o Windows-1252 (Excel).
/// Lanza [FormatException] si no encuentra un catálogo.
LecturaCie10 leerCatalogoCie10(Uint8List bytes) {
  var texto = _decodificar(bytes);
  if (texto.startsWith('﻿')) texto = texto.substring(1);
  final t = texto.trimLeft();
  final lectura = t.startsWith('[') || t.startsWith('{')
      ? _desdeJson(t)
      : _desdeTabla(texto);
  if (lectura.catalogo.length < 20) {
    throw const FormatException(
      'No se encontraron códigos CIE-10 en el archivo',
    );
  }
  return lectura;
}

String _decodificar(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    // Excel en Windows guarda los CSV en Windows-1252.
    return latin1.decode(bytes);
  }
}

LecturaCie10 _desdeJson(String texto) {
  final Object? json;
  try {
    json = jsonDecode(texto);
  } on FormatException {
    throw const FormatException('El archivo no es un JSON válido');
  }
  final entradas = <EntradaCie10>[];
  var omitidas = 0;
  void agregar(Object? codigo, Object? descripcion) {
    if (codigo is String &&
        descripcion is String &&
        pareceCodigoCie10(codigo) &&
        descripcion.trim().isNotEmpty) {
      entradas.add(
        EntradaCie10(codigo.trim().toUpperCase(), descripcion.trim()),
      );
    } else {
      omitidas++;
    }
  }

  switch (json) {
    case final List<Object?> lista:
      for (final e in lista) {
        if (e is! Map) {
          omitidas++;
          continue;
        }
        Object? campo(List<String> claves) {
          for (final c in claves) {
            if (e[c] != null) return e[c];
          }
          return null;
        }

        agregar(
          campo(['codigo', 'código', 'code', 'cod', 'c']),
          campo(['descripcion', 'descripción', 'description', 'nombre', 'd']),
        );
      }
    case final Map<String, Object?> mapa:
      mapa.forEach(agregar);
    default:
      throw const FormatException('Formato de catálogo no reconocido');
  }
  return LecturaCie10(_sinRepetidos(entradas), omitidas: omitidas);
}

LecturaCie10 _desdeTabla(String texto) {
  final lineas = const LineSplitter()
      .convert(texto)
      .where((l) => l.trim().isNotEmpty)
      .toList();
  final separador = _separador(lineas.take(50));
  final entradas = <EntradaCie10>[];
  var omitidas = 0;
  for (final linea in lineas) {
    final campos = _campos(linea, separador);
    final i = campos.indexWhere(pareceCodigoCie10);
    if (i < 0) {
      omitidas++;
      continue;
    }
    final descripcion = campos
        .skip(i + 1)
        .firstWhere(
          (c) =>
              RegExp(r'\p{L}.*\p{L}.*\p{L}', unicode: true).hasMatch(c) &&
              !pareceCodigoCie10(c),
          orElse: () => '',
        );
    if (descripcion.isEmpty) {
      omitidas++;
      continue;
    }
    entradas.add(EntradaCie10(campos[i].toUpperCase(), descripcion));
  }
  return LecturaCie10(_sinRepetidos(entradas), omitidas: omitidas);
}

String _separador(Iterable<String> muestra) {
  var mejor = '\t';
  var maximo = 0;
  for (final s in ['\t', ';', '|', ',']) {
    final n = muestra.where((l) => l.contains(s)).length;
    if (n > maximo) {
      maximo = n;
      mejor = s;
    }
  }
  return mejor;
}

/// Campos de una línea CSV (con comillas dobles opcionales).
List<String> _campos(String linea, String separador) {
  final campos = <String>[];
  final actual = StringBuffer();
  var entreComillas = false;
  for (var i = 0; i < linea.length; i++) {
    final c = linea[i];
    if (c == '"') {
      if (entreComillas && i + 1 < linea.length && linea[i + 1] == '"') {
        actual.write('"');
        i++;
      } else {
        entreComillas = !entreComillas;
      }
    } else if (c == separador && !entreComillas) {
      campos.add(actual.toString().trim());
      actual.clear();
    } else {
      actual.write(c);
    }
  }
  campos.add(actual.toString().trim());
  return campos;
}

CatalogoCie10 _sinRepetidos(List<EntradaCie10> entradas) {
  final vistos = <String>{};
  return CatalogoCie10([
    for (final e in entradas)
      if (vistos.add(e._codigo)) e,
  ]);
}
