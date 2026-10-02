import 'dart:typed_data';

/// PDF elegido o soltado por el usuario.
class ArchivoAbierto {
  const ArchivoAbierto({
    required this.nombre,
    required this.bytes,
    this.manejador,
  });

  final String nombre;
  final Uint8List bytes;

  /// `FileSystemFileHandle` cuando el navegador lo ofrece (Chrome y Edge).
  /// Permite sobrescribir el mismo archivo más tarde.
  final Object? manejador;

  bool get sePuedeSobrescribir => manejador != null;
}

/// Dónde se escribirá un PDF: un archivo concreto del disco (con
/// [manejador]) o una descarga normal del navegador.
class DestinoGuardado {
  const DestinoGuardado({required this.nombre, this.manejador});

  final String nombre;
  final Object? manejador;

  bool get esDescarga => manejador == null;
}
