import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Un archivo para incrustar al generar un PDF.
class AdjuntoPdf {
  const AdjuntoPdf(this.nombre, this.json);

  final String nombre;

  /// Solo ASCII (p. ej. `jsonCanonico`): el paquete `pdf` declara /Size
  /// contando caracteres, que así coincide con los bytes escritos.
  final String json;
}

/// Incrusta [adjuntos] en [documento] con el mismo mecanismo que
/// `historia.json` (`/EmbeddedFiles` y `/AF`). Sin adjuntos no hace nada:
/// el PDF queda igual. Debe llamarse antes de `documento.save()`.
void incrustarAdjuntos(pw.Document documento, List<AdjuntoPdf> adjuntos) {
  if (adjuntos.isEmpty) return;
  PdfaAttachedFiles(documento.document, [
    for (final a in adjuntos)
      PdfaAttachedFile(
        name: a.nombre,
        data: a.json,
        subType: '/application/json',
        AFRelationship: '/Data',
      ),
  ]);
}
