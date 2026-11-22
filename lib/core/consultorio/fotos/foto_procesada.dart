import 'dart:typed_data';

/// Foto lista para guardar: JPEG sin metadatos y su miniatura.
class FotoProcesada {
  const FotoProcesada({
    required this.jpeg,
    required this.miniatura,
    required this.ancho,
    required this.alto,
  });

  final Uint8List jpeg;
  final Uint8List miniatura;
  final int ancho;
  final int alto;
}

/// Lado mayor de la foto guardada y de la miniatura (pregunta 20).
const ladoMayorFoto = 1600;
const ladoMiniatura = 320;
const calidadJpeg = 0.8;
