import 'almacen.dart';

/// Fuera del navegador (VM y pruebas), el almacén vive en memoria.
AlmacenConsultorio crearAlmacenDePlataforma() => AlmacenMemoria();
