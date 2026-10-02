import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/archivos/archivos.dart';
import '../../../core/storage/preferencias.dart';

/// PDF abierto o guardado en esta sesión. Si el navegador dio un
/// manejador, se puede sobrescribir (no se guarda en el borrador).
final archivoActualProvider =
    NotifierProvider<ArchivoActualController, ArchivoAbierto?>(
      ArchivoActualController.new,
    );

class ArchivoActualController extends Notifier<ArchivoAbierto?> {
  @override
  ArchivoAbierto? build() => null;

  void cambiar(ArchivoAbierto? archivo) => state = archivo;
}

/// Si se muestra el aviso de privacidad (el médico puede cerrarlo).
final avisoPrivacidadProvider =
    NotifierProvider<AvisoPrivacidadController, bool>(
      AvisoPrivacidadController.new,
    );

class AvisoPrivacidadController extends Notifier<bool> {
  @override
  bool build() =>
      !(ref.read(preferenciasProvider).getBool(Claves.avisoPrivacidadCerrado) ??
          false);

  Future<void> cerrar() async {
    state = false;
    await ref
        .read(preferenciasProvider)
        .setBool(Claves.avisoPrivacidadCerrado, true);
  }
}
