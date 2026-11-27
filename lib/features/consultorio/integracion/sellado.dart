import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/consultorio/indice/sellar_evolucion.dart';
import '../../historia/estado/historia_controller.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';

/// Antes de sellar una valoración o una sesión: si la historia abierta en
/// el editor es de esta ficha y tiene cambios sin descargar (p. ej. una
/// evolución en curso), sellar aparte la bifurcaría. Devuelve el motivo
/// para no sellar todavía, o `null`.
String? conflictoConHistoriaEnCurso(WidgetRef ref, String pacienteId) {
  final enCurso = ref.read(historiaProvider);
  if (!enCurso.abierta || !enCurso.hayCambiosSinGuardar) return null;
  final propias = ref
      .read(servicioConsultorioProvider)
      .indice
      .historiasDe(pacienteId)
      .map((h) => h.id);
  if (!propias.contains(enCurso.historia.id)) return null;
  return 'La historia de este paciente tiene cambios sin descargar (por '
      'ejemplo, una evolución en curso). Descárgala en «Historia» antes de '
      'sellar aquí.';
}

/// Después de sellar: descarga el PDF de la versión nueva (el registro
/// legal) y, si el editor tiene abierta esa historia, la pone al día.
void alSellarEnHistoria(
  WidgetRef ref,
  EvolucionSellada s, {
  bool descargar = true,
}) {
  if (descargar) ref.read(descargarPdfProvider)(s.pdf, s.nombreArchivo);
  final enCurso = ref.read(historiaProvider);
  if (enCurso.abierta && enCurso.historia.id == s.historiaId) {
    ref
        .read(historiaProvider.notifier)
        .abrir(s.datos, revision: s.revision, nombreArchivo: s.nombreArchivo);
  }
  ref.read(versionIndiceProvider.notifier).cambio();
}
