import 'dart:typed_data';

import 'archivo.dart';

bool get puedeSobrescribirArchivos => false;

Future<ArchivoAbierto?> elegirPdf() async => null;

Future<ArchivoAbierto?> elegirImagen() async => null;

Future<DestinoGuardado?> prepararGuardado({
  required String nombreSugerido,
  ArchivoAbierto? sobrescribir,
}) async => DestinoGuardado(nombre: nombreSugerido);

Future<void> escribirArchivo(DestinoGuardado destino, Uint8List bytes) =>
    throw UnsupportedError('Guardar archivos solo está disponible en la web.');

void Function() escucharArchivosSoltados({
  required void Function(ArchivoAbierto archivo) alSoltar,
  required void Function(bool arrastrando) alArrastrar,
}) => () {};
