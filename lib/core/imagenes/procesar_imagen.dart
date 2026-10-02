import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Tamaño máximo (px) de cada imagen del médico. Se reduce para que el PDF
/// y el almacenamiento del navegador no crezcan de más.
enum TipoImagen {
  firma(1200, 480),
  sello(800, 800),
  logo(900, 360);

  const TipoImagen(this.anchoMax, this.altoMax);

  final int anchoMax;
  final int altoMax;
}

/// Imagen no válida o vacía.
class ImagenNoValida implements Exception {
  const ImagenNoValida(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Prepara una imagen subida por el médico y devuelve un PNG:
/// 1. la reduce para que quepa en [tipo];
/// 2. si [quitarFondo] y la imagen no tiene ya transparencia, vuelve
///    transparente el fondo claro (papel blanco o gris de una foto);
/// 3. la recorta al contenido, con un pequeño margen.
Future<Uint8List> prepararImagen(
  Uint8List bytes, {
  required TipoImagen tipo,
  bool quitarFondo = false,
}) async {
  if (bytes.length > 15 * 1024 * 1024) {
    throw const ImagenNoValida('La imagen pesa más de 15 MB.');
  }
  ui.Image imagen;
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    imagen = (await codec.getNextFrame()).image;
  } on Object {
    throw const ImagenNoValida(
      'El archivo no es una imagen válida (usa PNG o JPG).',
    );
  }

  final escala = math.min(
    1.0,
    math.min(tipo.anchoMax / imagen.width, tipo.altoMax / imagen.height),
  );
  if (escala < 1) {
    imagen = await _redibujar(
      imagen,
      ui.Rect.fromLTWH(0, 0, imagen.width.toDouble(), imagen.height.toDouble()),
      (imagen.width * escala).round().clamp(1, tipo.anchoMax),
      (imagen.height * escala).round().clamp(1, tipo.altoMax),
    );
  }

  final pixeles = await _pixeles(imagen);
  final yaTransparente = _tieneTransparencia(pixeles);
  if (quitarFondo && !yaTransparente) {
    _quitarFondoClaro(pixeles, imagen.width, imagen.height);
    imagen = await _desdePixeles(pixeles, imagen.width, imagen.height);
  }

  final caja = cajaDeContenido(pixeles, imagen.width, imagen.height);
  if (caja == null) {
    throw const ImagenNoValida(
      'La imagen quedó vacía: prueba sin quitar el fondo.',
    );
  }
  const margen = 4.0;
  final recorte = ui.Rect.fromLTRB(
    math.max(0, caja.left - margen),
    math.max(0, caja.top - margen),
    math.min(imagen.width.toDouble(), caja.right + margen),
    math.min(imagen.height.toDouble(), caja.bottom + margen),
  );
  final recortada = await _redibujar(
    imagen,
    recorte,
    recorte.width.round(),
    recorte.height.round(),
  );
  return aPng(recortada);
}

/// Codifica una imagen como PNG.
Future<Uint8List> aPng(ui.Image imagen) async {
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
  return datos!.buffer.asUint8List();
}

/// Rectángulo que contiene los píxeles visibles (alfa > 16), o `null`.
ui.Rect? cajaDeContenido(Uint8List rgba, int ancho, int alto) {
  var minX = ancho, minY = alto, maxX = -1, maxY = -1;
  for (var y = 0; y < alto; y++) {
    final fila = y * ancho * 4;
    for (var x = 0; x < ancho; x++) {
      if (rgba[fila + x * 4 + 3] > 16) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null;
  return ui.Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    maxX + 1.0,
    maxY + 1.0,
  );
}

Future<Uint8List> _pixeles(ui.Image imagen) async {
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
  return datos!.buffer.asUint8List();
}

bool _tieneTransparencia(Uint8List rgba) {
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] < 250) return true;
  }
  return false;
}

int _luminancia(Uint8List p, int i) =>
    (p[i] * 299 + p[i + 1] * 587 + p[i + 2] * 114) ~/ 1000;

/// Vuelve transparente todo lo más claro que el umbral. El umbral se
/// calcula a partir del borde de la imagen (normalmente papel), así
/// funciona también con fotos de fondo grisáceo. Solo usa alfa 0 o 255.
void _quitarFondoClaro(Uint8List p, int ancho, int alto) {
  var suma = 0, n = 0;
  void muestra(int x, int y) {
    suma += _luminancia(p, (y * ancho + x) * 4);
    n++;
  }

  final paso = math.max(1, math.max(ancho, alto) ~/ 200);
  for (var x = 0; x < ancho; x += paso) {
    muestra(x, 0);
    muestra(x, alto - 1);
  }
  for (var y = 0; y < alto; y += paso) {
    muestra(0, y);
    muestra(ancho - 1, y);
  }
  final fondo = suma ~/ math.max(1, n);
  final umbral = (fondo - 45).clamp(110, 235);
  for (var i = 0; i < p.length; i += 4) {
    if (_luminancia(p, i) > umbral) {
      p[i] = 0;
      p[i + 1] = 0;
      p[i + 2] = 0;
      p[i + 3] = 0;
    }
  }
}

Future<ui.Image> _desdePixeles(Uint8List rgba, int ancho, int alto) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    ancho,
    alto,
    ui.PixelFormat.rgba8888,
    c.complete,
  );
  return c.future;
}

Future<ui.Image> _redibujar(
  ui.Image imagen,
  ui.Rect origen,
  int ancho,
  int alto,
) {
  final grabadora = ui.PictureRecorder();
  ui.Canvas(grabadora).drawImageRect(
    imagen,
    origen,
    ui.Rect.fromLTWH(0, 0, ancho.toDouble(), alto.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  return grabadora.endRecording().toImage(ancho, alto);
}
