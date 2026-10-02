/// Catálogo CIE-10: el incluido en la app (tabla de referencia de SISPRO,
/// ver `catalogo_incluido.dart`) o el que el médico importe (una versión
/// más reciente de SISPRO, la CIE-10-ES…).
///
/// Sin dependencias de Flutter: también lo usa
/// `tool/cie10/generar_catalogo.dart`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

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

  /// Formato del catálogo incluido: una línea por código, con el código, un
  /// tabulador y la descripción. Las líneas que empiezan por `#` son
  /// comentarios.
  factory CatalogoCie10.desdeTexto(String texto) => CatalogoCie10([
    for (final linea in const LineSplitter().convert(texto))
      if (linea.isNotEmpty && !linea.startsWith('#'))
        if (linea.indexOf('\t') case final i when i > 0)
          EntradaCie10(linea.substring(0, i), linea.substring(i + 1)),
  ]);

  final List<EntradaCie10> entradas;

  int get length => entradas.length;

  String aJson() => jsonEncode([for (final e in entradas) e.aMapa()]);

  /// Inverso de [CatalogoCie10.desdeTexto], con [encabezado] como
  /// comentarios al principio.
  String aTexto({List<String> encabezado = const []}) {
    final b = StringBuffer();
    for (final l in encabezado) {
      b.writeln('# $l');
    }
    for (final e in entradas) {
      b.writeln('${e.codigo}\t${e.descripcion}');
    }
    return b.toString();
  }

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

/// Lee un catálogo en Excel (.xlsx, como la tabla de referencia de SISPRO),
/// CSV, TSV, TXT (separado por `;`, `,`, tabulador o `|`) o JSON. En cada
/// fila toma el primer campo con forma de código y el siguiente texto como
/// descripción, y omite las filas con "Habilitado" = NO. Acepta UTF-8 o
/// Windows-1252 (los CSV de Excel). Lanza [FormatException] si no encuentra
/// un catálogo.
LecturaCie10 leerCatalogoCie10(Uint8List bytes) {
  if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
    // "PK": un ZIP, es decir, un .xlsx.
    return _comprobar(_desdeFilas(_filasDeXlsx(bytes)));
  }
  var texto = _decodificar(bytes);
  if (texto.startsWith('\uFEFF')) texto = texto.substring(1);
  final t = texto.trimLeft();
  return _comprobar(
    t.startsWith('[') || t.startsWith('{') ? _desdeJson(t) : _desdeTabla(texto),
  );
}

LecturaCie10 _comprobar(LecturaCie10 lectura) {
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
  return _desdeFilas([for (final l in lineas) _campos(l, separador)]);
}

final _conLetras = RegExp(r'\p{L}.*\p{L}.*\p{L}', unicode: true);

LecturaCie10 _desdeFilas(List<List<String>> filas) {
  // Columna "Habilitado" (SISPRO): se omiten los códigos deshabilitados.
  int? habilitado;
  final entradas = <EntradaCie10>[];
  var omitidas = 0;
  for (final campos in filas) {
    final i = campos.indexWhere(pareceCodigoCie10);
    if (i < 0) {
      habilitado ??= _indiceHabilitado(campos);
      omitidas++;
      continue;
    }
    if (habilitado != null &&
        habilitado < campos.length &&
        campos[habilitado].trim().toUpperCase() == 'NO') {
      omitidas++;
      continue;
    }
    final descripcion = campos
        .skip(i + 1)
        .firstWhere(
          (c) => _conLetras.hasMatch(c) && !pareceCodigoCie10(c),
          orElse: () => '',
        );
    if (descripcion.isEmpty) {
      omitidas++;
      continue;
    }
    entradas.add(EntradaCie10(campos[i].trim().toUpperCase(), descripcion));
  }
  return LecturaCie10(_sinRepetidos(entradas), omitidas: omitidas);
}

int? _indiceHabilitado(List<String> encabezado) {
  final i = encabezado.indexWhere((c) => _normalizarTexto(c) == 'habilitado');
  return i < 0 ? null : i;
}

/// Filas de la primera hoja de un .xlsx, con las celdas vacías en su
/// columna para que los encabezados coincidan.
List<List<String>> _filasDeXlsx(Uint8List bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const FormatException('El archivo no es un Excel (.xlsx) válido');
  }
  String? xml(String nombre) {
    final f = zip.findFile(nombre);
    return f == null ? null : utf8.decode(f.content, allowMalformed: true);
  }

  final hojas =
      zip.files
          .map((f) => f.name)
          .where((n) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(n))
          .toList()
        ..sort();
  final hoja = hojas.isEmpty ? null : xml(hojas.first);
  if (hoja == null) {
    throw const FormatException('El Excel no tiene hojas con datos');
  }
  // Textos compartidos: <si><t>…</t></si> (o varios <r><t>…</t></r>).
  final compartidos = [
    for (final si in _etiqueta(
      'si',
    ).allMatches(xml('xl/sharedStrings.xml') ?? ''))
      _textoDe(si.group(1)!),
  ];
  final filas = <List<String>>[];
  for (final fila in _etiqueta('row').allMatches(hoja)) {
    final campos = <String>[];
    for (final celda in _celda.allMatches(fila.group(1)!)) {
      final atributos = celda.group(1)!;
      final contenido = celda.group(2) ?? '';
      final columna = _columna(atributos);
      final tipo = RegExp(r'\bt="(\w+)"').firstMatch(atributos)?.group(1);
      final v = _etiqueta('v').firstMatch(contenido)?.group(1);
      final valor = switch (tipo) {
        's' => compartidos.elementAtOrNull(int.tryParse(v ?? '') ?? -1) ?? '',
        'inlineStr' => _textoDe(contenido),
        _ => _entidades(v ?? ''),
      };
      while (columna != null && campos.length < columna) {
        campos.add('');
      }
      campos.add(valor.trim());
    }
    filas.add(campos);
  }
  return filas;
}

/// `<x:etiqueta …>contenido</x:etiqueta>`, con o sin prefijo.
RegExp _etiqueta(String nombre) => RegExp(
  '<(?:\\w+:)?$nombre(?:\\s[^>]*)?>(.*?)</(?:\\w+:)?$nombre>',
  dotAll: true,
);

final _celda = RegExp(
  r'<(?:\w+:)?c\b([^>]*?)(?:/>|>(.*?)</(?:\w+:)?c>)',
  dotAll: true,
);

/// Índice de columna de `r="AB12"` (A = 0).
int? _columna(String atributos) {
  final letras = RegExp(r'\br="([A-Z]+)\d+"').firstMatch(atributos)?.group(1);
  if (letras == null) return null;
  var n = 0;
  for (final c in letras.codeUnits) {
    n = n * 26 + (c - 64);
  }
  return n - 1;
}

String _textoDe(String xml) =>
    _entidades(_etiqueta('t').allMatches(xml).map((m) => m.group(1)!).join());

String _entidades(String t) => t.replaceAllMapped(
  RegExp(r'&(#x[0-9A-Fa-f]+|#\d+|amp|lt|gt|quot|apos);'),
  (m) => switch (m.group(1)!) {
    'amp' => '&',
    'lt' => '<',
    'gt' => '>',
    'quot' => '"',
    'apos' => "'",
    final n when n.startsWith('#x') => String.fromCharCode(
      int.parse(n.substring(2), radix: 16),
    ),
    final n => String.fromCharCode(int.parse(n.substring(1))),
  },
);

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
