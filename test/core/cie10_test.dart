import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/cie10/catalogo_cie10.dart';
import 'package:historiasclinicas_net/core/cie10/catalogo_incluido.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/cie10/cie10_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Muestra de prueba (no oficial): 30 códigos, punto y coma, Windows-1252.
final muestra = File('test/fixtures/cie10_muestra.csv').readAsBytesSync();

Uint8List bytes(String texto) => Uint8List.fromList(utf8.encode(texto));

String filas(String Function(int i) fila) => List.generate(25, fila).join('\n');

/// Un .xlsx mínimo como el de SISPRO: etiquetas con prefijo `x:`, textos
/// compartidos, una celda vacía que se salta y la columna "Habilitado".
Uint8List xlsx(List<List<String?>> filas) {
  final compartidos = <String>[];
  String celda(int fila, int col, String? valor) {
    if (valor == null) return '';
    final ref = '${String.fromCharCode(65 + col)}${fila + 1}';
    if (valor.startsWith('inline:')) {
      return '<x:c r="$ref" t="inlineStr"><x:is><x:t>'
          '${valor.substring(7)}</x:t></x:is></x:c>';
    }
    compartidos.add(valor);
    return '<x:c r="$ref" t="s"><x:v>${compartidos.length - 1}</x:v></x:c>';
  }

  final hoja =
      '<?xml version="1.0" encoding="utf-8"?><x:worksheet '
      'xmlns:x="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<x:sheetData>'
      '${[
        for (final (i, f) in filas.indexed) '<x:row r="${i + 1}">${[for (final (j, v) in f.indexed) celda(i, j, v)].join()}</x:row>',
      ].join()}'
      '</x:sheetData></x:worksheet>';
  final sst =
      '<x:sst>${[for (final t in compartidos) '<x:si><x:t>$t</x:t></x:si>'].join()}</x:sst>';
  final zip = Archive()
    ..add(ArchiveFile.bytes('xl/worksheets/sheet1.xml', utf8.encode(hoja)))
    ..add(ArchiveFile.bytes('xl/sharedStrings.xml', utf8.encode(sst)));
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Leer el catálogo', () {
    test('CSV con punto y coma en Windows-1252 y encabezado', () {
      final l = leerCatalogoCie10(muestra);
      expect(l.catalogo.length, 30);
      expect(l.omitidas, 1, reason: 'el encabezado');
      final migrana = l.catalogo.entradas.firstWhere((e) => e.codigo == 'G439');
      expect(migrana.descripcion, 'MIGRAÑA, NO ESPECIFICADA');
    });

    test('TSV con puntos en el código y comillas', () {
      final texto = filas(
        (i) =>
            'A${(i + 10).toString().padLeft(2, '0')}.$i\t"Enfermedad $i, '
            'con coma"\tOtra columna',
      );
      final l = leerCatalogoCie10(bytes(texto));
      expect(l.catalogo.length, 25);
      expect(l.catalogo.entradas.first.codigo, 'A10.0');
      expect(l.catalogo.entradas.first.descripcion, 'Enfermedad 0, con coma');
    });

    test('JSON: lista de objetos o mapa código → descripción', () {
      final lista = jsonEncode([
        for (var i = 0; i < 25; i++)
          {'code': 'B${i + 10}', 'description': 'Infección $i'},
      ]);
      expect(leerCatalogoCie10(bytes(lista)).catalogo.length, 25);
      final mapa = jsonEncode({
        for (var i = 0; i < 25; i++) 'C${i + 10}.1': 'Tumor $i',
      });
      expect(
        leerCatalogoCie10(bytes(mapa)).catalogo.entradas.last.codigo,
        'C34.1',
      );
    });

    test('quita códigos repetidos y avisa si no es un catálogo', () {
      final repetidos = '${filas((i) => 'D${i + 10};Anemia $i')}\nD10;Otra';
      expect(leerCatalogoCie10(bytes(repetidos)).catalogo.length, 25);
      for (final malo in [
        'hola, esto no es un catálogo',
        filas((i) => 'Texto;sin;código'),
        'J029;Faringitis',
        '{"tipo": "otra cosa"',
      ]) {
        expect(
          () => leerCatalogoCie10(bytes(malo)),
          throwsFormatException,
          reason: malo,
        );
      }
    });

    test('Excel (.xlsx) de SISPRO: columnas, entidades y "Habilitado"', () {
      final l = leerCatalogoCie10(
        xlsx([
          ['Tabla', 'Codigo', 'Nombre', 'Descripcion', 'Habilitado'],
          for (var i = 0; i < 24; i++)
            ['CIE10', 'K${i + 10}X', 'ENFERMEDAD $i', 'GRUPO', 'SI'],
          // La celda "Nombre" vacía: la descripción no se toma de otra fila.
          ['CIE10', 'K90X', null, 'GRUPO SIN NOMBRE', 'SI'],
          ['CIE10', 'K91X', 'TUMOR &amp; QUISTE', 'GRUPO', 'SI'],
          ['CIE10', 'K92X', 'inline:ESCRITA EN LA CELDA', 'GRUPO', 'SI'],
          ['CIE10', 'K93X', 'DESHABILITADO', 'GRUPO', 'NO'],
        ]),
      );
      final c = l.catalogo;
      expect(c.length, 27);
      expect(l.omitidas, 2, reason: 'el encabezado y el deshabilitado');
      String? descripcion(String codigo) =>
          c.entradas.where((e) => e.codigo == codigo).firstOrNull?.descripcion;
      expect(descripcion('K10X'), 'ENFERMEDAD 0');
      expect(descripcion('K90X'), 'GRUPO SIN NOMBRE');
      expect(descripcion('K91X'), 'TUMOR & QUISTE');
      expect(descripcion('K92X'), 'ESCRITA EN LA CELDA');
      expect(descripcion('K93X'), isNull);
      expect(
        () => leerCatalogoCie10(Uint8List.fromList([0x50, 0x4B, 1, 2, 3, 4])),
        throwsFormatException,
      );
    });

    test('formato del catálogo incluido: ida y vuelta', () {
      final catalogo = leerCatalogoCie10(muestra).catalogo;
      final texto = catalogo.aTexto(encabezado: ['Prueba']);
      expect(texto, startsWith('# Prueba\n'));
      expect(texto.split('\n')[1], matches(RegExp(r'^[A-Z]\d{2}\w\t\w')));
      final otro = CatalogoCie10.desdeTexto(texto);
      expect(otro.length, 30);
      expect(otro.buscar('migrana').single.codigo, 'G439');
    });

    test('forma de los códigos', () {
      expect(normalizarCodigo('j02.9 '), 'J029');
      for (final c in ['J02', 'J02.9', 'J029', 'A09X', 'S72.001A']) {
        expect(pareceCodigoCie10(c), isTrue, reason: c);
      }
      for (final c in ['J2', '12', 'Codigo', 'J02.99999']) {
        expect(pareceCodigoCie10(c), isFalse, reason: c);
      }
    });
  });

  group('Buscar', () {
    final catalogo = leerCatalogoCie10(muestra).catalogo;
    List<String> codigos(String q) =>
        catalogo.buscar(q).map((e) => e.codigo).toList();

    test('por código, con o sin punto', () {
      expect(codigos('j0'), ['J00X', 'J029', 'J039', 'J069']);
      expect(codigos('J02.9'), ['J029']);
      expect(codigos('r5'), ['R509', 'R51X']);
    });

    test('por palabras, sin tildes ni mayúsculas', () {
      expect(codigos('faring agud'), ['J029']);
      expect(codigos('migrana'), ['G439']);
      expect(codigos('MIGRAÑA'), ['G439']);
      expect(codigos('dolor abdomen'), ['R101']);
      expect(codigos('aguda').first, 'J029', reason: 'más corta primero');
      expect(codigos('x'), isEmpty, reason: 'mínimo dos letras');
    });

    test('ida y vuelta para guardarlo', () {
      final otro = CatalogoCie10.desdeJson(catalogo.aJson());
      expect(otro.length, 30);
      expect(otro.buscar('cefalea').single.codigo, 'R51X');
    });
  });

  test('catálogo incluido: la tabla de SISPRO completa', () async {
    final c = await cargarCatalogoIncluido();
    expect(c.length, CatalogoIncluido.cantidad, reason: 'actualizar la clase');
    expect(c.entradas.first.codigo, 'A000');
    expect(
      c.entradas.every((e) => RegExp(r'^[A-Z]\d{2}[0-9X]$').hasMatch(e.codigo)),
      isTrue,
    );
    expect({for (final e in c.entradas) e.codigo}, hasLength(c.length));
    String primero(String q) => c.buscar(q).first.codigo;
    expect(primero('faringitis aguda'), 'J029');
    expect(primero('J029'), 'J029');
    expect(primero('j02.9'), 'J029');
    expect(primero('hipertension esencial'), 'I10X');
    expect(
      primero('migraña no especificada'),
      'G439',
      reason: 'la tabla dice "MIGRANA"',
    );
    expect(primero('covid'), 'U071');
    expect(c.buscar('diabetes').length, 12, reason: 'máximo por defecto');
  });

  test('importar, cargar cuando se usa y volver al incluido', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [preferenciasProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    expect(c.read(infoCie10Provider), isNull);
    expect(
      (await c.read(catalogoCie10Provider.future)).length,
      CatalogoIncluido.cantidad,
      reason: 'sin importar, el incluido',
    );

    final l = await c
        .read(infoCie10Provider.notifier)
        .importar('cie10_muestra.csv', muestra);
    expect(l.catalogo.length, 30);
    expect(c.read(infoCie10Provider)!.cantidad, 30);
    expect(prefs.getString(Claves.cie10), contains('cie10_muestra.csv'));
    final cargado = await c.read(catalogoCie10Provider.future);
    expect(cargado.length, 30);
    expect(cargado.buscar('asma').single.codigo, 'J459');

    await c.read(infoCie10Provider.notifier).borrar();
    expect(c.read(infoCie10Provider), isNull);
    expect(
      (await c.read(catalogoCie10Provider.future)).length,
      CatalogoIncluido.cantidad,
    );
  });
}
