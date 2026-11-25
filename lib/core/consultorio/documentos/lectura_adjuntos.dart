import 'dart:convert';
import 'dart:typed_data';

import '../../integridad/json_canonico.dart';
import '../../pdf/lector_adjunto.dart';
import 'documento.dart';

/// Qué lleva incrustado un PDF del consultorio.
enum ClaseAdjunto { documento, receta }

/// Un `documento.json` o un `receta.json` leído de un PDF. [integro] dice
/// si su huella (`sha256`) coincide con lo sellado.
class AdjuntoConsultorio {
  const AdjuntoConsultorio({
    required this.clase,
    required this.datos,
    required this.integro,
  });

  final ClaseAdjunto clase;
  final Map<String, Object?> datos;
  final bool integro;
}

/// El primer adjunto del consultorio de [pdf], o `null` si no lleva ninguno
/// (por ejemplo, una historia, que lleva `historia.json` con otra marca).
AdjuntoConsultorio? leerAdjuntoConsultorio(Uint8List pdf) {
  final List<Uint8List> adjuntos;
  try {
    adjuntos = adjuntosConMarca(pdf, marcaAdjuntoConsultorio);
  } on Object {
    return null;
  }
  for (final a in adjuntos) {
    try {
      final m = (jsonDecode(utf8.decode(a)) as Map).cast<String, Object?>();
      for (final (clave, clase) in const [
        ('documento', ClaseAdjunto.documento),
        ('receta', ClaseAdjunto.receta),
      ]) {
        final datos = (m[clave] as Map?)?.cast<String, Object?>();
        if (datos == null) continue;
        return AdjuntoConsultorio(
          clase: clase,
          datos: datos,
          integro: m['sha256'] == sha256Canonico(datos),
        );
      }
    } on Object {
      // Un adjunto ilegible: se prueba con el siguiente.
    }
  }
  return null;
}

/// «CC 1032456789» → («CC», «1032456789»); sin espacio, solo el número.
(String, String) partirDocumento(String texto) {
  final t = texto.trim();
  final i = t.indexOf(' ');
  return i < 0 ? ('', t) : (t.substring(0, i), t.substring(i + 1).trim());
}
