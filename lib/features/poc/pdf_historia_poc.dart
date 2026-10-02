import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/pdf/adjunto_historia.dart';
import '../../core/pdf/fuentes_pdf.dart';
import '../../core/utils/fechas.dart';
import 'historia_poc.dart';

/// Genera el PDF A4 de la prueba de concepto con `historia.json` incrustado.
Future<Uint8List> generarPdfHistoriaPoc(
  HistoriaPoc historia, {
  required int revision,
  required DateTime guardadoEn,
  FuentesPdf? fuentes,
}) async {
  final f = fuentes ?? await FuentesPdf.cargar();
  final doc = pw.Document(
    title: 'Historia clínica · ${historia.nombreCompleto}',
    author: 'historiasclinicas.net',
    creator: 'historiasclinicas.net',
    theme: f.tema,
  );

  final gris = PdfColor.fromInt(0xFF5F6B73);
  final linea = PdfColor.fromInt(0xFFB8C4CC);
  pw.TextStyle etiqueta() =>
      pw.TextStyle(font: f.media, fontSize: 7.5, color: gris);
  pw.Widget dato(String nombre, String valor, {int flex = 1}) => pw.Expanded(
    flex: flex,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(nombre.toUpperCase(), style: etiqueta()),
        pw.SizedBox(height: 2),
        pw.Text(
          valor.isEmpty ? '—' : valor,
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    ),
  );
  pw.Widget seccion(String titulo) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
    padding: const pw.EdgeInsets.only(bottom: 3),
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: linea, width: 0.7)),
    ),
    child: pw.Text(
      titulo.toUpperCase(),
      style: pw.TextStyle(font: f.seminegrita, fontSize: 9, letterSpacing: 0.6),
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 42, 48, 42),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        margin: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 1.2)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'HISTORIA CLÍNICA',
                    style: pw.TextStyle(font: f.negrita, fontSize: 15),
                  ),
                  pw.Text(
                    historia.nombreCompleto,
                    style: pw.TextStyle(
                      font: f.media,
                      fontSize: 9,
                      color: gris,
                    ),
                  ),
                ],
              ),
            ),
            pw.Text(
              'historiasclinicas.net · prueba de concepto',
              style: pw.TextStyle(fontSize: 7.5, color: gris),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'Contiene datos estructurados incrustados ($nombreAdjuntoHistoria) · '
                'revisión $revision · guardado ${formatoFechaHora(guardadoEn)}',
                style: pw.TextStyle(fontSize: 7, color: gris),
              ),
            ),
            pw.Text(
              'Pág. ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 7.5, color: gris),
            ),
          ],
        ),
      ),
      build: (context) => [
        seccion('Datos del paciente'),
        pw.Row(
          children: [
            dato('Apellidos', historia.apellidos.toUpperCase(), flex: 2),
            dato('Nombres', historia.nombres, flex: 2),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            dato(
              'Documento',
              '${historia.tipoDocumento} ${historia.numeroDocumento}',
            ),
            dato('Fecha de la atención', formatoFechaHora(historia.creadaEn)),
            dato(
              'Id. de historia',
              historia.id.length > 8
                  ? historia.id.substring(0, 8)
                  : historia.id,
            ),
          ],
        ),
        seccion('Motivo de consulta'),
        pw.Text(
          historia.motivoConsulta,
          style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
        ),
        seccion('Evoluciones'),
        if (historia.evoluciones.isEmpty)
          pw.Text(
            'Sin evoluciones registradas.',
            style: pw.TextStyle(fontSize: 9, color: gris),
          ),
        for (final (i, e) in historia.evoluciones.indexed)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.only(left: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: linea, width: 2)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Evolución ${i + 1} · ${formatoFechaHora(e.fechaHora)}',
                  style: pw.TextStyle(font: f.seminegrita, fontSize: 9),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  e.texto,
                  style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  incrustarHistoria(
    doc,
    PaqueteHistoria(
      revision: revision,
      guardadoEn: guardadoEn,
      datos: historia.aMapa(),
    ),
  );
  return doc.save();
}
