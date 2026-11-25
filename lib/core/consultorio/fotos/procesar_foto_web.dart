import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'foto_procesada.dart';
import 'jpeg.dart';

/// Decodifica con `createImageBitmap` (respeta la orientación de la cámara),
/// dibuja en un lienzo y lo codifica en JPEG: el lienzo no copia los
/// metadatos, y además se pasan por [quitarMetadatos]. Lanza
/// [FormatException] si no es una imagen.
Future<FotoProcesada> procesarFoto(Uint8List original) async {
  final web.ImageBitmap mapa;
  try {
    mapa = await web.window
        .createImageBitmap(
          web.Blob([original.toJS].toJS),
          web.ImageBitmapOptions(imageOrientation: 'from-image'),
        )
        .toDart;
  } catch (_) {
    throw const FormatException('El archivo no es una imagen válida.');
  }
  try {
    final grande = await _codificar(mapa, ladoMayorFoto, calidadJpeg);
    final mini = await _codificar(mapa, ladoMiniatura, 0.7);
    return FotoProcesada(
      jpeg: quitarMetadatos(grande.bytes),
      miniatura: quitarMetadatos(mini.bytes),
      ancho: grande.ancho,
      alto: grande.alto,
    );
  } finally {
    mapa.close();
  }
}

Future<({Uint8List bytes, int ancho, int alto})> _codificar(
  web.ImageBitmap mapa,
  int lado,
  double calidad,
) async {
  final escala = math.min(1.0, lado / math.max(mapa.width, mapa.height));
  final ancho = math.max(1, (mapa.width * escala).round());
  final alto = math.max(1, (mapa.height * escala).round());
  final lienzo = web.HTMLCanvasElement()
    ..width = ancho
    ..height = alto;
  (lienzo.getContext('2d')! as web.CanvasRenderingContext2D)
    ..imageSmoothingEnabled = true
    ..imageSmoothingQuality = 'high'
    ..drawImage(mapa, 0, 0, ancho, alto);
  final listo = Completer<web.Blob?>();
  lienzo.toBlob(
    ((web.Blob? b) => listo.complete(b)).toJS,
    'image/jpeg',
    calidad.toJS,
  );
  final blob = await listo.future;
  if (blob == null) {
    throw const FormatException('No se pudo codificar la foto.');
  }
  final bytes = (await blob.arrayBuffer().toDart).toDart.asUint8List();
  return (bytes: bytes, ancho: ancho, alto: alto);
}
