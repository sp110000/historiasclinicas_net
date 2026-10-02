import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/imagenes/procesar_imagen.dart';
import 'package:historiasclinicas_net/core/widgets/lienzo_firma.dart';

/// PNG de [ancho]x[alto] con fondo [fondo] y un rectángulo [tinta] en [trazo].
Future<Uint8List> imagenDePrueba({
  int ancho = 600,
  int alto = 300,
  Color? fondo = Colors.white,
  Color tinta = Colors.black,
  Rect trazo = const Rect.fromLTRB(100, 50, 300, 150),
}) async {
  final grabadora = ui.PictureRecorder();
  final lienzo = Canvas(grabadora);
  if (fondo != null) {
    lienzo.drawRect(
      Rect.fromLTWH(0, 0, ancho.toDouble(), alto.toDouble()),
      Paint()..color = fondo,
    );
  }
  lienzo.drawRect(trazo, Paint()..color = tinta);
  final imagen = await grabadora.endRecording().toImage(ancho, alto);
  return aPng(imagen);
}

Future<(ui.Image, Uint8List)> decodificar(Uint8List png) async {
  final imagen = (await (await ui.instantiateImageCodec(
    png,
  )).getNextFrame()).image;
  final rgba = await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
  return (imagen, rgba!.buffer.asUint8List());
}

int alfa(Uint8List rgba, int ancho, int x, int y) =>
    rgba[(y * ancho + x) * 4 + 3];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('prepararImagen', () {
    test('quita el fondo blanco y recorta al contenido', () async {
      final png = await prepararImagen(
        await imagenDePrueba(),
        tipo: TipoImagen.firma,
        quitarFondo: true,
      );
      final (img, rgba) = await decodificar(png);
      // Rectángulo de 200x100 más 4 px de margen por lado.
      expect(img.width, 208);
      expect(img.height, 108);
      expect(alfa(rgba, img.width, 0, 0), 0, reason: 'esquina transparente');
      expect(alfa(rgba, img.width, 104, 54), 255, reason: 'tinta opaca');
    });

    test('también con el fondo gris de una foto', () async {
      final png = await prepararImagen(
        await imagenDePrueba(
          fondo: const Color(0xFFC4C4C4),
          tinta: const Color(0xFF1E2A55),
        ),
        tipo: TipoImagen.firma,
        quitarFondo: true,
      );
      final (img, rgba) = await decodificar(png);
      expect(img.width, 208);
      expect(alfa(rgba, img.width, 1, 1), 0);
    });

    test('reduce las imágenes grandes al máximo del tipo', () async {
      final png = await prepararImagen(
        await imagenDePrueba(
          ancho: 3000,
          alto: 1000,
          trazo: const Rect.fromLTRB(0, 0, 3000, 1000),
        ),
        tipo: TipoImagen.firma,
      );
      final (img, _) = await decodificar(png);
      expect(img.width, lessThanOrEqualTo(TipoImagen.firma.anchoMax));
      expect(img.height, lessThanOrEqualTo(TipoImagen.firma.altoMax));
      expect(img.width / img.height, closeTo(3, 0.05));
    });

    test('una imagen ya transparente solo se recorta', () async {
      final png = await prepararImagen(
        await imagenDePrueba(fondo: null),
        tipo: TipoImagen.sello,
        quitarFondo: true,
      );
      final (img, rgba) = await decodificar(png);
      expect(img.width, 208);
      expect(alfa(rgba, img.width, 104, 54), 255);
    });

    test('rechaza lo que no es una imagen', () async {
      expect(
        () => prepararImagen(
          Uint8List.fromList([1, 2, 3]),
          tipo: TipoImagen.logo,
        ),
        throwsA(isA<ImagenNoValida>()),
      );
    });

    test('una imagen toda blanca queda vacía y se avisa', () async {
      expect(
        () async => prepararImagen(
          await imagenDePrueba(tinta: Colors.white),
          tipo: TipoImagen.firma,
          quitarFondo: true,
        ),
        throwsA(isA<ImagenNoValida>()),
      );
    });
  });

  group('Firma dibujada', () {
    test(
      'se exporta con fondo transparente y recortada a los trazos',
      () async {
        final c = ControladorFirma()
          ..empezar(const Offset(40, 80))
          ..continuar(const Offset(80, 60))
          ..continuar(const Offset(120, 100))
          ..continuar(const Offset(160, 70))
          ..empezar(const Offset(60, 120))
          ..continuar(const Offset(150, 118));
        final png = await c.exportarPng(escala: 2);
        final (img, rgba) = await decodificar(png!);
        // Trazos de x 40..160 y de y 60..120, más el margen (grosor + 2).
        expect(img.width, closeTo((120 + 2 * 4.6) * 2, 2));
        expect(img.height, closeTo((60 + 2 * 4.6) * 2, 2));
        expect(alfa(rgba, img.width, 0, 0), 0);
        expect(rgba.where((b) => b == 255).length, greaterThan(100));
      },
    );

    test('deshacer y limpiar', () async {
      final c = ControladorFirma()
        ..empezar(Offset.zero)
        ..continuar(const Offset(10, 10))
        ..empezar(const Offset(20, 20));
      expect(c.trazos, hasLength(2));
      c.deshacer();
      expect(c.trazos, hasLength(1));
      c.limpiar();
      expect(c.vacio, isTrue);
      expect(await c.exportarPng(), isNull);
    });
  });
}
