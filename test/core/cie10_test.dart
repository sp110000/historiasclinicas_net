import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/cie10/catalogo_cie10.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/cie10/cie10_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Muestra de prueba (no oficial): 30 códigos, punto y coma, Windows-1252.
final muestra = File('test/fixtures/cie10_muestra.csv').readAsBytesSync();

Uint8List bytes(String texto) => Uint8List.fromList(utf8.encode(texto));

String filas(String Function(int i) fila) => List.generate(25, fila).join('\n');

void main() {
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

  test('importar, cargar cuando se usa y quitar', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [preferenciasProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    expect(c.read(infoCie10Provider), isNull);
    expect(await c.read(catalogoCie10Provider.future), isNull);

    final l = await c
        .read(infoCie10Provider.notifier)
        .importar('cie10_muestra.csv', muestra);
    expect(l.catalogo.length, 30);
    expect(c.read(infoCie10Provider)!.cantidad, 30);
    expect(prefs.getString(Claves.cie10), contains('cie10_muestra.csv'));
    final cargado = await c.read(catalogoCie10Provider.future);
    expect(cargado!.buscar('asma').single.codigo, 'J459');

    await c.read(infoCie10Provider.notifier).borrar();
    expect(c.read(infoCie10Provider), isNull);
    expect(await c.read(catalogoCie10Provider.future), isNull);
  });
}
