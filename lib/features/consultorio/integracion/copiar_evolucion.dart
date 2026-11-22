import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/consultorio_provider.dart';
import 'enganche_historia.dart';

/// Agrega [texto] a la evolución en curso de la historia más reciente de la
/// ficha (pregunta 17: lo clínico queda en la historia y se sella al
/// descargarla). Devuelve `true` si lo agregó.
Future<bool> copiarALaEvolucion(
  BuildContext context,
  WidgetRef ref, {
  required String pacienteId,
  required String texto,
}) async {
  if (!await confirmarReemplazoHistoria(
    context,
    ref,
    pacienteId: pacienteId,
    continuar: true,
  )) {
    return false;
  }
  return agregarALaEvolucion(ref, pacienteId, texto);
}

/// `true` si la ficha tiene historias (y por lo tanto evolución en curso).
bool tieneHistorias(WidgetRef ref, String pacienteId) => ref
    .read(servicioConsultorioProvider)
    .indice
    .historiasDe(pacienteId)
    .isNotEmpty;

/// Casilla «Agregar a la evolución en curso», marcada por defecto.
class CasillaEvolucion extends StatelessWidget {
  const CasillaEvolucion({
    super.key,
    required this.valor,
    required this.alCambiar,
  });

  final bool valor;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    value: valor,
    onChanged: (v) => alCambiar(v ?? false),
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    title: const Text('Agregar a la evolución en curso'),
    subtitle: const Text('Queda en la historia y se sella al descargarla.'),
  );
}
