import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'adjunto_historia.dart';

/// Motivo por el que no se pudo reabrir un PDF.
enum FalloLectura { noEsPdf, sinDatosDeLaApp, danado, versionNoSoportada }

class LecturaHistoriaException implements Exception {
  const LecturaHistoriaException(this.fallo, [this.detalle]);

  final FalloLectura fallo;

  /// Información técnica para el registro; no se muestra al usuario.
  final String? detalle;

  /// Mensaje para el usuario, en español.
  String get mensaje => switch (fallo) {
    FalloLectura.noEsPdf => 'El archivo seleccionado no es un PDF.',
    FalloLectura.sinDatosDeLaApp =>
      'Este PDF no contiene datos de historiasclinicas.net. Solo se pueden '
          'reabrir los PDF generados por esta aplicación. Si el archivo se '
          'volvió a guardar o a imprimir con otro programa, es posible que '
          'los datos incrustados se hayan perdido.',
    FalloLectura.danado =>
      'Los datos de la historia incrustados en este PDF están dañados o '
          'incompletos. Prueba con una copia de respaldo del archivo.',
    FalloLectura.versionNoSoportada =>
      'Este PDF se creó con una versión más reciente de la aplicación. '
          'Recarga la página para actualizarla e inténtalo de nuevo.',
  };

  @override
  String toString() =>
      'LecturaHistoriaException($fallo${detalle == null ? '' : ': $detalle'})';
}

/// Extrae el `historia.json` incrustado en un PDF generado por la app.
///
/// No depende de la tabla de referencias cruzadas: recorre los flujos
/// (`stream … endstream`) del archivo, primero los marcados como
/// `/EmbeddedFile`, los descomprime si usan `/FlateDecode` y se queda con el
/// que lleva la marca de la app. Así tolera PDF que otro programa reescribió
/// (flujos comprimidos, flujos de objetos) siempre que conserve el adjunto.
/// Si hay varias copias (actualizaciones incrementales), gana la de mayor
/// revisión.
PaqueteHistoria leerHistoriaDePdf(Uint8List bytes) {
  // latin1 conserva la posición de cada byte: 1 carácter = 1 byte.
  final texto = latin1.decode(bytes);
  final cabecera = texto.length < 1024 ? texto : texto.substring(0, 1024);
  if (!cabecera.contains('%PDF-')) {
    throw const LecturaHistoriaException(FalloLectura.noEsPdf);
  }

  final flujos = _extraerFlujos(texto, bytes);
  LecturaHistoriaException? primerError;

  PaqueteHistoria? buscarEn(Iterable<_Flujo> candidatos) {
    PaqueteHistoria? mejor;
    for (final flujo in candidatos) {
      final contenido = flujo.decodificar();
      if (contenido == null || !_tieneMarca(contenido)) continue;
      try {
        final paquete = _interpretar(contenido);
        if (mejor == null || paquete.revision > mejor.revision) {
          mejor = paquete;
        }
      } on LecturaHistoriaException catch (e) {
        primerError ??= e;
      }
    }
    return mejor;
  }

  final paquete =
      buscarEn(flujos.where((f) => f.esArchivoIncrustado)) ??
      buscarEn(flujos.where((f) => !f.esArchivoIncrustado));
  if (paquete != null) return paquete;
  if (primerError != null) throw primerError!;
  if (texto.contains(_marca)) {
    // La marca aparece, pero en ningún flujo completo: archivo truncado.
    throw const LecturaHistoriaException(
      FalloLectura.danado,
      'adjunto incompleto',
    );
  }
  throw const LecturaHistoriaException(FalloLectura.sinDatosDeLaApp);
}

const _marca = '"app":"$identificadorApp"';

bool _tieneMarca(Uint8List contenido) {
  final inicio = contenido.length < 256
      ? contenido
      : Uint8List.sublistView(contenido, 0, 256);
  return latin1.decode(inicio).contains(_marca);
}

PaqueteHistoria _interpretar(Uint8List contenido) {
  final Object? mapa;
  try {
    mapa = jsonDecode(utf8.decode(contenido));
  } on FormatException catch (e) {
    throw LecturaHistoriaException(FalloLectura.danado, 'JSON: ${e.message}');
  }
  if (mapa is! Map<String, Object?> || mapa['app'] != identificadorApp) {
    throw const LecturaHistoriaException(FalloLectura.danado, 'estructura');
  }
  final version = mapa['schemaVersion'];
  if (version is! int) {
    throw const LecturaHistoriaException(FalloLectura.danado, 'schemaVersion');
  }
  if (version > schemaVersionActual) {
    throw LecturaHistoriaException(
      FalloLectura.versionNoSoportada,
      'schemaVersion $version',
    );
  }
  final PaqueteHistoria paquete;
  try {
    paquete = PaqueteHistoria.desdeMapa(mapa);
  } on Object catch (e) {
    throw LecturaHistoriaException(FalloLectura.danado, 'campos: $e');
  }
  if (mapa['sha256'] != paquete.hashDatos) {
    throw const LecturaHistoriaException(
      FalloLectura.danado,
      'el hash de los datos no coincide',
    );
  }
  return paquete;
}

class _Flujo {
  _Flujo(this.diccionario, this.datos);

  final String diccionario;
  final Uint8List datos;

  static final _tipoIncrustado = RegExp(r'/Type\s*/EmbeddedFile\b');
  static final _filtro = RegExp(r'/Filter\s*(?:\[([^\]]*)\]|/(\w+))');
  static final _nombre = RegExp(r'/(\w+)');

  bool get esArchivoIncrustado => _tipoIncrustado.hasMatch(diccionario);

  /// Contenido sin filtros, o `null` si usa un filtro no soportado o
  /// los datos comprimidos no son válidos.
  Uint8List? decodificar() {
    final m = _filtro.firstMatch(diccionario);
    final filtros = m == null
        ? const <String>[]
        : m.group(2) != null
        ? [m.group(2)!]
        : _nombre.allMatches(m.group(1)!).map((x) => x.group(1)!).toList();
    var resultado = datos;
    for (final filtro in filtros) {
      if (filtro != 'FlateDecode' && filtro != 'Fl') return null;
      try {
        resultado = ZLibDecoder().decodeBytes(resultado);
      } on Object {
        return null;
      }
    }
    return resultado;
  }
}

final _longitud = RegExp(r'/Length\s+(\d+)(?:\s+(\d+)\s+R)?');

List<_Flujo> _extraerFlujos(String texto, Uint8List bytes) {
  final flujos = <_Flujo>[];
  var desde = 0;
  while (true) {
    final i = texto.indexOf('stream', desde);
    if (i < 0) break;
    desde = i + 6;
    // Descarta "endstream" y apariciones que no son la palabra clave.
    if (i >= 3 && texto.startsWith('end', i - 3)) continue;
    final inicioObj = texto.lastIndexOf('obj', i);
    if (inicioObj < 0) continue;
    final diccionario = texto.substring(inicioObj + 3, i);
    if (!diccionario.contains('<<')) continue;

    var inicioDatos = i + 6;
    if (texto.startsWith('\r\n', inicioDatos)) {
      inicioDatos += 2;
    } else if (inicioDatos < texto.length &&
        (texto[inicioDatos] == '\n' || texto[inicioDatos] == '\r')) {
      inicioDatos += 1;
    } else {
      continue;
    }

    final fin = _finDeDatos(texto, diccionario, inicioDatos);
    if (fin == null) continue; // flujo truncado
    flujos.add(
      _Flujo(diccionario, Uint8List.sublistView(bytes, inicioDatos, fin)),
    );
    desde = fin;
  }
  return flujos;
}

/// Posición donde terminan los datos del flujo que empieza en [inicio].
int? _finDeDatos(String texto, String diccionario, int inicio) {
  final m = _longitud.firstMatch(diccionario);
  if (m != null) {
    var longitud = int.parse(m.group(1)!);
    if (m.group(2) != null) {
      final ref = RegExp(
        '(?:^|[^0-9])${m.group(1)}\\s+${m.group(2)}\\s+obj\\s*(\\d+)\\s*endobj',
      ).firstMatch(texto);
      longitud = ref == null ? -1 : int.parse(ref.group(1)!);
    }
    final fin = inicio + longitud;
    if (longitud >= 0 && fin <= texto.length) {
      var j = fin;
      while (j < texto.length && ' \r\n\t\f\x00'.contains(texto[j])) {
        j++;
      }
      if (texto.startsWith('endstream', j)) return fin;
    }
  }
  // /Length ausente o incorrecto: se busca la palabra clave de cierre.
  final cierre = texto.indexOf('endstream', inicio);
  if (cierre < 0) return null;
  var fin = cierre;
  if (fin > inicio && texto[fin - 1] == '\n') fin--;
  if (fin > inicio && texto[fin - 1] == '\r') fin--;
  return fin;
}
