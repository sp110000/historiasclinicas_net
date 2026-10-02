import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/borrador_store.dart';
import '../../../core/storage/preferencias.dart';
import 'estado_historia.dart';

final borradorStoreProvider = Provider<BorradorStore>(
  (ref) => BorradorStore(ref.watch(preferenciasProvider)),
);

class EstadoBorrador {
  const EstadoBorrador({this.guardadoEn, this.desactivado = false});

  /// Hora del último autoguardado; `null` si no hay borrador.
  final DateTime? guardadoEn;
  final bool desactivado;
}

final borradorProvider = NotifierProvider<BorradorController, EstadoBorrador>(
  BorradorController.new,
);

/// Autoguardado con espera: escribe 700 ms después del último cambio.
class BorradorController extends Notifier<EstadoBorrador> {
  static const espera = Duration(milliseconds: 700);

  Timer? _temporizador;

  BorradorStore get _store => ref.read(borradorStoreProvider);

  @override
  EstadoBorrador build() {
    ref.onDispose(() => _temporizador?.cancel());
    final store = ref.read(borradorStoreProvider);
    return EstadoBorrador(
      guardadoEn: store.desactivado ? null : store.leer()?.guardadoEn,
      desactivado: store.desactivado,
    );
  }

  /// Programa el guardado de [estado]. Si no hay nada pendiente de guardar
  /// (historia vacía o ya guardada en PDF), borra el borrador.
  void programar(EstadoHistoria estado) {
    _temporizador?.cancel();
    if (state.desactivado) return;
    _temporizador = Timer(espera, () => _escribir(estado));
  }

  Future<void> _escribir(EstadoHistoria estado) async {
    if (estado.hayCambiosSinGuardar) {
      final hora = await _store.guardar(estado.aBorrador());
      state = EstadoBorrador(guardadoEn: hora, desactivado: state.desactivado);
    } else {
      await borrar();
    }
  }

  Future<void> borrar() async {
    _temporizador?.cancel();
    await _store.borrar();
    state = EstadoBorrador(desactivado: state.desactivado);
  }

  Future<void> cambiarDesactivado(bool valor) async {
    _temporizador?.cancel();
    await _store.cambiarDesactivado(valor);
    state = EstadoBorrador(
      guardadoEn: valor ? null : state.guardadoEn,
      desactivado: valor,
    );
  }
}
