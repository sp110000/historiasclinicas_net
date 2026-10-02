import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferencias.dart';
import 'perfil_pais.dart';

/// País de ejercicio del médico. En la Fase 2 pasa al panel "Datos del
/// médico".
final paisProvider = NotifierProvider<PaisController, Pais>(PaisController.new);

class PaisController extends Notifier<Pais> {
  @override
  Pais build() {
    final guardado = ref.watch(preferenciasProvider).getString(Claves.pais);
    if (guardado != null) return Pais.desdeCodigo(guardado);
    final region = PlatformDispatcher.instance.locale.countryCode;
    return region == 'ES' ? Pais.espana : Pais.colombia;
  }

  Future<void> cambiar(Pais pais) async {
    state = pais;
    await ref.read(preferenciasProvider).setString(Claves.pais, pais.codigo);
  }
}
