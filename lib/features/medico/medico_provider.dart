import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/medico.dart';
import '../../core/storage/medico_store.dart';
import '../../core/storage/preferencias.dart';

final medicoStoreProvider = Provider<MedicoStore>(
  (ref) => MedicoStore(ref.watch(preferenciasProvider)),
);

/// Datos del médico de este navegador. Se guardan solos tras cada cambio.
final medicoProvider = NotifierProvider<MedicoController, Medico>(
  MedicoController.new,
);

class MedicoController extends Notifier<Medico> {
  static const espera = Duration(milliseconds: 400);

  Timer? _temporizador;

  @override
  Medico build() {
    ref.onDispose(() {
      // Guarda lo pendiente si el contenedor se cierra antes de tiempo.
      if (_temporizador?.isActive ?? false) {
        _temporizador!.cancel();
        unawaited(ref.read(medicoStoreProvider).guardar(state));
      }
    });
    return ref.read(medicoStoreProvider).leer();
  }

  /// Cambia los datos; se guardan 400 ms después del último cambio.
  void actualizar(Medico Function(Medico m) cambio) {
    state = cambio(state);
    _temporizador?.cancel();
    _temporizador = Timer(
      espera,
      () => ref.read(medicoStoreProvider).guardar(state),
    );
  }

  /// Guarda de inmediato (por ejemplo, tras cambiar una imagen).
  Future<void> guardarAhora() async {
    _temporizador?.cancel();
    await ref.read(medicoStoreProvider).guardar(state);
  }

  Future<void> borrarTodo() async {
    _temporizador?.cancel();
    state = const Medico();
    await ref.read(medicoStoreProvider).borrar();
  }
}
