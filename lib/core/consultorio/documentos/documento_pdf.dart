import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../integridad/cadena_hash.dart';
import '../../models/medico.dart';
import '../../pdf/adjuntos_pdf.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../pdf/piezas_pdf.dart';
import '../../utils/fechas.dart';

/// Lo que se imprime en un documento del consultorio (autorización de
/// datos, política de privacidad; luego consentimientos y certificados).
class ContenidoDocumentoPdf {
  const ContenidoDocumentoPdf({
    required this.titulo,
    required this.cuerpo,
    required this.fechaHora,
    this.numero,
    this.version,
    this.paciente,
    this.documentoPaciente,
    this.firmaPaciente,
    this.medico,
    this.recursos = const {},
    this.adjuntos = const [],
    this.huella,
  });

  final String titulo;
  final String cuerpo;
  final DateTime fechaHora;

  /// «AD-000001»; la política no lleva número.
  final String? numero;

  /// Versión de la plantilla con la que se generó.
  final int? version;
  final String? paciente;
  final String? documentoPaciente;

  /// PNG de la firma del paciente.
  final Uint8List? firmaPaciente;

  /// Copia del médico (`instantaneaMedico`) con sus imágenes en [recursos].
  final Autor? medico;
  final Map<String, String> recursos;
  final List<AdjuntoPdf> adjuntos;

  /// SHA-256 de lo sellado, para el pie.
  final String? huella;
}

/// PDF A4 del documento: encabezado con los datos del médico, título y
/// número, ficha del paciente, cuerpo, firmas y pie con la huella.
Future<Uint8List> generarPdfDocumento(
  ContenidoDocumentoPdf c, {
  FuentesPdf? fuentes,
}) async {
  final f = fuentes ?? await FuentesPdf.cargar();
  final imagenes = ImagenesPdf(c.recursos);
  final medico = c.medico;

  pw.TextStyle estilo({
    double tamano = 10,
    pw.Font? fuente,
    PdfColor? color,
    double? interlineado,
  }) => pw.TextStyle(
    font: fuente ?? f.regular,
    fontSize: tamano,
    color: color,
    lineSpacing: interlineado,
  );

  pw.Widget encabezado(pw.Context context) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: acentoPdf, width: 1.2)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: medico == null
              ? pw.Text(
                  'historiasclinicas.net',
                  style: estilo(fuente: f.negrita, tamano: 11),
                )
              : datosMedicoPdf(f, medico),
        ),
        if (imagenes(medico?.logo) case final logo?)
          pw.SizedBox(height: 42, child: pw.Image(logo)),
      ],
    ),
  );

  pw.Widget pie(pw.Context context) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 10),
    child: pw.Text(
      [
        'historiasclinicas.net',
        ?c.numero,
        if (c.version != null) 'versión ${c.version}',
        if (c.huella != null) 'huella ${huella(c.huella!)}',
        'Pág. ${context.pageNumber} de ${context.pagesCount}',
      ].join(' · '),
      style: estilo(tamano: 7.5, color: grisPdf),
    ),
  );

  final firmaPaciente = c.firmaPaciente == null
      ? null
      : pw.MemoryImage(c.firmaPaciente!);

  final doc = pw.Document(
    title: [c.titulo, ?c.numero].join(' · '),
    author: medico?.nombre ?? 'historiasclinicas.net',
    creator: 'historiasclinicas.net',
    theme: f.tema,
  );
  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 40, 48, 32),
        theme: f.tema,
      ),
      header: encabezado,
      footer: pie,
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                c.titulo.toUpperCase(),
                style: estilo(fuente: f.negrita, tamano: 13, color: acentoPdf),
              ),
            ),
            if (c.numero != null)
              pw.Text(c.numero!, style: estilo(fuente: f.seminegrita)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          formatoFechaHora(c.fechaHora),
          style: estilo(tamano: 9, color: grisPdf),
        ),
        if (c.paciente != null) ...[
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: lineaPdf, width: 0.6),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    c.paciente!,
                    style: estilo(fuente: f.seminegrita),
                  ),
                ),
                if (c.documentoPaciente != null)
                  pw.Text(c.documentoPaciente!, style: estilo()),
              ],
            ),
          ),
        ],
        pw.SizedBox(height: 14),
        for (final parrafo in c.cuerpo.split(RegExp(r'\n\s*\n')))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 7),
            child: textoLargo(
              parrafo.trim(),
              estilo(tamano: 10, interlineado: 1.5),
            ),
          ),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (c.paciente != null)
              pw.Container(
                width: 220,
                child: pw.Column(
                  children: [
                    pw.SizedBox(
                      height: 60,
                      child: firmaPaciente == null
                          ? pw.SizedBox()
                          : pw.Image(firmaPaciente, fit: pw.BoxFit.contain),
                    ),
                    pw.Divider(color: grisPdf, thickness: 0.6, height: 6),
                    pw.Text(
                      c.paciente!,
                      style: estilo(tamano: 9, fuente: f.seminegrita),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (c.documentoPaciente != null)
                      pw.Text(
                        c.documentoPaciente!,
                        style: estilo(tamano: 8, color: grisPdf),
                      ),
                    pw.Text(
                      'Firma del paciente',
                      style: estilo(tamano: 8, color: grisPdf),
                    ),
                  ],
                ),
              )
            else
              pw.SizedBox(),
            bloqueFirmaPdf(f, medico, imagenes, alto: 60),
          ],
        ),
      ],
    ),
  );
  incrustarAdjuntos(doc, c.adjuntos);
  return doc.save();
}
