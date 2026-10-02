// Genera el catálogo CIE-10 incluido en la app desde la tabla de referencia
// de SISPRO (Excel tal como se descarga) o cualquier archivo que acepte
// "Importar" (CSV, TXT, JSON).
//
//   dart run tool/cie10/generar_catalogo.dart TablaReferencia_CIE10.xlsx 2026-09-15
//
// El segundo argumento es la fecha de actualización de la tabla (columna
// Fecha_Actualizacion). Después actualiza `CatalogoIncluido` en
// lib/core/cie10/catalogo_incluido.dart con la fecha y la cantidad que se
// muestran al terminar; un test comprueba que coinciden.
import 'dart:io';

import 'package:historiasclinicas_net/core/cie10/catalogo_cie10.dart';

const salida = 'assets/cie10/cie10_sispro.txt';

void main(List<String> args) {
  if (args.length != 2 || DateTime.tryParse(args[1]) == null) {
    stderr.writeln(
      'Uso: dart run tool/cie10/generar_catalogo.dart <archivo> <AAAA-MM-DD>',
    );
    exit(64);
  }
  final archivo = File(args[0]);
  final lectura = leerCatalogoCie10(archivo.readAsBytesSync());
  final nombre = archivo.uri.pathSegments.last;
  File(salida).writeAsStringSync(
    lectura.catalogo.aTexto(
      encabezado: [
        'CIE-10. Tabla de referencia de SISPRO (Ministerio de Salud y '
            'Protección Social de Colombia).',
        'Actualizada el ${args[1]}. Generado desde $nombre: '
            '${lectura.catalogo.length} códigos.',
        'Formato: código, tabulador y descripción, una línea por código.',
      ],
    ),
  );
  stdout
    ..writeln('$salida: ${lectura.catalogo.length} códigos')
    ..writeln('(${lectura.omitidas} filas omitidas: encabezados o sin código)')
    ..writeln(
      'Actualiza CatalogoIncluido: cantidad = ${lectura.catalogo.length}, '
      'actualizado = ${args[1]}',
    );
}
