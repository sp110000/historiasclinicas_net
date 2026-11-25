/// Enganche de la receta con el consultorio. La receta solo lo llama dentro
/// de `if (consultorioHabilitado)`; nunca lanza: la receta ya está impresa o
/// guardada.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/consultorio/servicio.dart';
import '../../../core/pdf/receta_pdf.dart';
import '../../historia/estado/historia_controller.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';

/// Después de imprimir o guardar la receta: la registra en la ficha del
/// paciente de la historia en curso, con su PDF exacto (o la deja
/// pendiente si el consultorio está bloqueado).
Future<void> registrarRecetaEmitida(
  BuildContext context,
  WidgetRef ref, {
  required DocumentoReceta documento,
  required Uint8List bytes,
  required String nombreArchivo,
}) async {
  try {
    final r = documento.receta;
    final pacienteId = await ref
        .read(servicioConsultorioProvider)
        .registrarReceta(
          RecetaPendiente(
            recetaId: r.id,
            paciente: ref.read(historiaProvider).historia.paciente,
            fecha: r.fecha,
            bytesPdf: bytes,
            numero: r.numero,
            historiaId: r.historiaId,
            items: [for (final i in r.itemsConDatos) i.resumen],
            indicaciones: r.indicaciones.trim(),
            nombreArchivo: nombreArchivo,
          ),
        );
    ref.read(versionIndiceProvider.notifier).cambio();
    if (pacienteId != null) {
      ref.read(fichaEnCursoProvider.notifier).cambiar(pacienteId);
    }
  } on Object catch (e) {
    debugPrint('Consultorio: no se registró la receta: $e');
  }
}
