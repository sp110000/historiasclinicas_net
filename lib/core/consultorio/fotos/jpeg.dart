/// JPEG en Dart puro: quitar los metadatos y leer el tamaño.
library;

import 'dart:typed_data';

/// Segmentos que se quitan: APP1 (EXIF con la ubicación GPS, XMP), APP2
/// (perfil ICC y FlashPix), APP12, APP13 (IPTC de Photoshop) y comentarios.
/// Se conservan APP0 (JFIF) y APP14 (Adobe, necesario para los colores).
const _quitar = {0xE1, 0xE2, 0xEC, 0xED, 0xFE};

/// Copia de [jpeg] sin metadatos. Lanza [FormatException] si no es JPEG.
Uint8List quitarMetadatos(Uint8List jpeg) {
  if (!esJpeg(jpeg)) throw const FormatException('No es un JPEG.');
  final salida = BytesBuilder(copy: false)..add([0xFF, 0xD8]);
  var i = 2;
  while (i + 4 <= jpeg.length) {
    if (jpeg[i] != 0xFF) throw const FormatException('JPEG dañado.');
    final marca = jpeg[i + 1];
    if (marca == 0xFF) {
      i++; // relleno
      continue;
    }
    if (marca == 0xDA) {
      // Desde el comienzo de la imagen comprimida, todo va tal cual.
      salida.add(Uint8List.sublistView(jpeg, i));
      return salida.toBytes();
    }
    final largo = (jpeg[i + 2] << 8) | jpeg[i + 3];
    final fin = i + 2 + largo;
    if (largo < 2 || fin > jpeg.length) {
      throw const FormatException('JPEG dañado.');
    }
    if (!_quitar.contains(marca)) {
      salida.add(Uint8List.sublistView(jpeg, i, fin));
    }
    i = fin;
  }
  throw const FormatException('JPEG incompleto.');
}

bool esJpeg(Uint8List b) =>
    b.length > 4 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

/// `true` si [jpeg] trae EXIF (un segmento APP1 que empieza con «Exif»).
bool tieneExif(Uint8List jpeg) {
  if (!esJpeg(jpeg)) return false;
  var i = 2;
  while (i + 10 <= jpeg.length && jpeg[i] == 0xFF) {
    final marca = jpeg[i + 1];
    if (marca == 0xDA) return false;
    final largo = (jpeg[i + 2] << 8) | jpeg[i + 3];
    if (marca == 0xE1 &&
        String.fromCharCodes(jpeg.sublist(i + 4, i + 8)) == 'Exif') {
      return true;
    }
    i += 2 + largo;
  }
  return false;
}

/// Ancho y alto de [jpeg] (del marcador SOF), o `null` si no se encuentra.
({int ancho, int alto})? dimensionesJpeg(Uint8List jpeg) {
  if (!esJpeg(jpeg)) return null;
  var i = 2;
  while (i + 9 <= jpeg.length && jpeg[i] == 0xFF) {
    final marca = jpeg[i + 1];
    final largo = (jpeg[i + 2] << 8) | jpeg[i + 3];
    final esSof =
        marca >= 0xC0 &&
        marca <= 0xCF &&
        marca != 0xC4 &&
        marca != 0xC8 &&
        marca != 0xCC;
    if (esSof) {
      return (
        alto: (jpeg[i + 5] << 8) | jpeg[i + 6],
        ancho: (jpeg[i + 7] << 8) | jpeg[i + 8],
      );
    }
    if (marca == 0xDA) return null;
    i += 2 + largo;
  }
  return null;
}
