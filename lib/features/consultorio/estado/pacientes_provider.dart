import 'package:flutter_riverpod/flutter_riverpod.dart';

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
