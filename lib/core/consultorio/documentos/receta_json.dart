import 'dart:convert';

import '../../integridad/json_canonico.dart';
import '../../pdf/adjuntos_pdf.dart';
import '../../pdf/receta_pdf.dart';
import '../modelos/registro_receta.dart';

/// Lo sellado de una receta: la receta tal como se imprimió, el paciente
/// (con las correcciones de la receta) y la copia del médico.
Map<String, Object?> datosReceta(DocumentoReceta d) {
  final r = d.receta;
  final p = d.paciente;
  return {
    'receta': {
      'id': r.id,
      'historiaId': r.historiaId,
      'fecha': r.aMapa()['fecha'],
      'numero': ?r.numero,
      'items': [for (final i in r.itemsConDatos) i.aMapa()],
      'indicaciones': r.indicaciones.trim(),
    },
    'paciente': {
      'nombre': p.nombre,
      'documento': p.documento,
      'edad': p.edad,
      'diagnostico': p.diagnostico,
      'alergias': p.alergias,
    },
    if (d.medico != null) 'autor': d.medico!.aMapa(),
  };
}

/// `receta.json` para incrustar en el PDF de la receta (solo con
/// `CONSULTORIO_ENABLED`). Lleva su SHA-256 para verificarlo al importarlo.
List<AdjuntoPdf> adjuntosReceta(DocumentoReceta d) {
  final datos = datosReceta(d);
  return [
    AdjuntoPdf(
      nombreAdjuntoReceta,
      jsonCanonico({
        'aplicacion': 'historiasclinicas.net',
        'receta': datos,
        'sha256': sha256Canonico(datos),
      }),
    ),
  ];
}

/// Lee un `receta.json` y comprueba su huella. Devuelve lo sellado, o
/// `null` si no es una receta o la huella no coincide.
Map<String, Object?>? leerRecetaJson(List<int> bytes) {
  try {
    final m = (jsonDecode(utf8.decode(bytes)) as Map).cast<String, Object?>();
    final datos = (m['receta'] as Map?)?.cast<String, Object?>();
    if (datos == null || m['sha256'] != sha256Canonico(datos)) return null;
    return datos;
  } on Object {
    return null;
  }
}
