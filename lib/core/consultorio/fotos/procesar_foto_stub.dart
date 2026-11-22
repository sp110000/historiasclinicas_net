import 'dart:typed_data';

import 'foto_procesada.dart';
import 'jpeg.dart';

/// En la VM no hay lienzo: la foto queda del mismo tamaño, sin metadatos.
/// Lanza [FormatException] si no es un JPEG.
Future<FotoProcesada> procesarFoto(Uint8List original) async {
  final limpia = quitarMetadatos(original);
  final d = dimensionesJpeg(limpia);
  if (d == null) throw const FormatException('No se pudo leer la foto.');
  return FotoProcesada(
    jpeg: limpia,
    miniatura: limpia,
    ancho: d.ancho,
    alto: d.alto,
  );
}
