import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/archivos/archivos.dart' as archivos;
import '../../../core/archivos/archivos.dart' show ArchivoAbierto;

/// Sube cada vez que cambia el índice de pacientes (registro, importación,
/// unir fichas, desbloqueo o bloqueo). Las pantallas lo miran y vuelven a
/// leer `servicio.indice`.
class ControladorVersionIndice extends Notifier<int> {
  @override
  int build() => 0;

  void cambio() => state++;
}

final versionIndiceProvider = NotifierProvider<ControladorVersionIndice, int>(
  ControladorVersionIndice.new,
);

/// Ficha desde la que se empezó o continuó la historia en curso, para la
/// franja «← Ficha». `null` si la historia no vino de una ficha.
class ControladorFichaEnCurso extends Notifier<String?> {
  @override
  String? build() => null;

  void cambiar(String? pacienteId) => state = pacienteId;
}

final fichaEnCursoProvider = NotifierProvider<ControladorFichaEnCurso, String?>(
  ControladorFichaEnCurso.new,
);

/// Elige varios PDF para importar. Las pruebas lo sustituyen.
final elegirPdfsProvider = Provider<Future<List<ArchivoAbierto>> Function()>(
  (ref) => archivos.elegirPdfs,
);

/// Muestra un PDF guardado en la vista de impresión del navegador (desde
/// ahí se ve, se imprime o se guarda). Las pruebas lo sustituyen.
final verPdfProvider = Provider<Future<void> Function(Uint8List, String)>(
  (ref) =>
      (bytes, nombre) =>
          Printing.layoutPdf(onLayout: (_) async => bytes, name: nombre),
);

/// Descarga un PDF guardado. Las pruebas lo sustituyen.
final descargarPdfProvider = Provider<void Function(Uint8List, String)>(
  (ref) =>
      (bytes, nombre) =>
          archivos.descargar(nombre, bytes, tipo: 'application/pdf'),
);

/// Elige o toma una foto. Las pruebas lo sustituyen.
final elegirFotoProvider = Provider<Future<ArchivoAbierto?> Function()>(
  (ref) => archivos.elegirFoto,
);

/// Elige un paquete del equipo secundario. Las pruebas lo sustituyen.
final elegirPaqueteProvider = Provider<Future<ArchivoAbierto?> Function()>(
  (ref) => archivos.elegirPaquete,
);

/// Descarga cualquier archivo. Las pruebas lo sustituyen.
final descargarArchivoProvider =
    Provider<void Function(Uint8List bytes, String nombre)>(
      (ref) =>
          (bytes, nombre) => archivos.descargar(
            nombre,
            bytes,
            tipo: 'application/octet-stream',
          ),
    );
