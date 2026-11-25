import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modo presentación (pregunta 50): cuando te ve un paciente o un auditor
/// oculta los chips «Por verificar», las notas internas y los montos de la
/// caja en las pantallas que ve el paciente. Se apaga solo al bloquear.
class ControladorPresentacion extends Notifier<bool> {
  @override
  bool build() => false;

  void cambiar(bool v) => state = v;

  void apagar() => state = false;
}

final modoPresentacionProvider =
    NotifierProvider<ControladorPresentacion, bool>(
      ControladorPresentacion.new,
    );
