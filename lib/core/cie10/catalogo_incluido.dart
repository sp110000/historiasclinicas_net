import 'dart:convert';

import 'package:flutter/services.dart';

import 'catalogo_cie10.dart';

/// El catálogo CIE-10 que trae la app: la tabla de referencia de SISPRO
/// completa. Se genera con `tool/cie10/generar_catalogo.dart`.
abstract final class CatalogoIncluido {
  static const ruta = 'assets/cie10/cie10_sispro.txt';
  static const fuente =
      'Tabla de referencia CIE-10 de SISPRO (Ministerio de Salud y '
      'Protección Social de Colombia)';
  static const cantidad = 12634;
  static final actualizado = DateTime(2026, 9, 15);
}

/// Se lee la primera vez que se busca un diagnóstico (unos 800 KB).
Future<CatalogoCie10> cargarCatalogoIncluido([AssetBundle? bundle]) async {
  // `load` y no `loadString`: este decodifica en otro isolate los archivos
  // grandes, y en los tests eso no termina.
  final datos = await (bundle ?? rootBundle).load(CatalogoIncluido.ruta);
  return CatalogoCie10.desdeTexto(
    utf8.decode(
      datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes),
    ),
  );
}
