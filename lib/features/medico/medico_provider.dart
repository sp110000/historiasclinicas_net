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

  /// Cambios aún no guardados.
  Medico? _pendiente;

  @override
  Medico build() {
    // En onDispose no se puede usar `ref`: se guarda lo necesario antes.
    final store = ref.read(medicoStoreProvider);
    ref.onDispose(() {
      // Guarda lo pendiente si el contenedor se cierra antes de tiempo.
      final pendiente = _pendiente;
      _temporizador?.cancel();
      _pendiente = null;
      if (pendiente != null) unawaited(store.guardar(pendiente));
    });
    return store.leer();
  }

  /// Cambia los datos; se guardan 400 ms después del último cambio.
  void actualizar(Medico Function(Medico m) cambio) {
    final nuevo = cambio(state);
    state = nuevo;
    _pendiente = nuevo;
    _temporizador?.cancel();
    _temporizador = Timer(espera, () {
      _pendiente = null;
      ref.read(medicoStoreProvider).guardar(nuevo);
    });
  }

  /// Guarda ya los cambios que esperaban (por ejemplo, antes de recargar).
  Future<void> guardarPendiente() async {
    if (_pendiente != null) await guardarAhora();
  }

  /// Guarda de inmediato (por ejemplo, tras cambiar una imagen).
  Future<void> guardarAhora() async {
    _temporizador?.cancel();
    _pendiente = null;
    await ref.read(medicoStoreProvider).guardar(state);
  }

  Future<void> borrarTodo() async {
    _temporizador?.cancel();
    _pendiente = null;
    state = const Medico();
    await ref.read(medicoStoreProvider).borrar();
  }
}
