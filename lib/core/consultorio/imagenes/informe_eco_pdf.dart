import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../integridad/cadena_hash.dart';
import '../../models/medico.dart';
import '../../pdf/adjuntos_pdf.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../pdf/piezas_pdf.dart';
import '../../utils/fechas.dart';
import 'estudio_imagen.dart';

/// Lo que se imprime del informe ecográfico.
class ContenidoEstudioPdf {
  const ContenidoEstudioPdf({
    required this.estudio,
    required this.paciente,
    this.documentoPaciente = '',
    this.edad,
    this.medico,
    this.recursos = const {},
    this.imagenes = const {},
    this.numero,
    this.huella,
    this.adjuntos = const [],
  });

  final EstudioImagen estudio;
  final String paciente;
  final String documentoPaciente;
  final int? edad;

  /// Copia del médico (`instantaneaMedico`) con sus imágenes en [recursos].
  final Autor? medico;
  final Map<String, String> recursos;

  /// JPEG de cada imagen del informe, por id.
  final Map<String, Uint8List> imagenes;

  /// «EC-000001»; sin número es la vista previa.
  final String? numero;
  final String? huella;
  final List<AdjuntoPdf> adjuntos;
}

/// PDF A4 del informe: encabezado del médico, estudio y paciente, datos del
/// estudio, hallazgos, medidas, imágenes (2 × 3), impresión diagnóstica,
/// recomendaciones y firma.
Future<Uint8List> generarPdfEstudio(
  ContenidoEstudioPdf c, {
  FuentesPdf? fuentes,
}) async {
  final f = fuentes ?? await FuentesPdf.cargar();
  final recursos = ImagenesPdf(c.recursos);
  final medico = c.medico;
  final e = c.estudio;

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

  pw.Widget rotulo(String texto) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12, bottom: 5),
    child: pw.Text(
      texto.toUpperCase(),
      style: estilo(tamano: 9, fuente: f.negrita, color: acentoPdf),
    ),
  );

  pw.Widget encabezado(pw.Context context) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
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
        if (recursos(medico?.logo) case final logo?)
          pw.SizedBox(height: 42, child: pw.Image(logo)),
      ],
    ),
  );

  pw.Widget pie(pw.Context context) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 10),
    child: pw.Text(
      [
        'historiasclinicas.net',
        c.numero ?? 'Vista previa: el informe no está cerrado',
        if (c.huella != null) 'huella ${huella(c.huella!)}',
        'Pág. ${context.pageNumber} de ${context.pagesCount}',
      ].join(' · '),
      style: estilo(tamano: 7.5, color: grisPdf),
    ),
  );

  pw.Widget tabla(List<(String, String)> filas) => pw.Table(
    columnWidths: const {0: pw.IntrinsicColumnWidth(), 1: pw.FlexColumnWidth()},
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: lineaPdf, width: 0.5),
    ),
    children: [
      for (final (etiqueta, valor) in filas)
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.top,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(0, 3, 14, 3),
              child: pw.Text(
                etiqueta,
                style: estilo(tamano: 9.5, color: grisPdf),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Text(valor, style: estilo(tamano: 10)),
            ),
          ],
        ),
    ],
  );

  final secciones = [
    for (final s in e.secciones)
      if (s.texto.trim().isNotEmpty) s,
  ];
  final medidas = e.medidasConValor;
  final imagenes = [
    for (final i in e.imagenesInforme.take(maxImagenesInforme))
      if (c.imagenes[i.id] case final bytes?) (i, pw.MemoryImage(bytes)),
  ];

  pw.Widget celdaImagen(int n, ImagenEstudio i, pw.MemoryImage img) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            height: 150,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: PdfColors.black,
              border: pw.Border.all(color: lineaPdf, width: 0.5),
            ),
            child: pw.Image(img, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            ['$n.', if (i.rotulo.trim().isNotEmpty) i.rotulo.trim()].join(' '),
            style: estilo(tamano: 8.5, color: grisPdf),
          ),
        ],
      );

  final doc = pw.Document(
    title: [e.titulo, ?c.numero].join(' · '),
    author: medico?.nombre ?? 'historiasclinicas.net',
    creator: 'historiasclinicas.net',
    theme: f.tema,
  );
  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(44, 36, 44, 30),
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
                'INFORME ECOGRÁFICO',
                style: estilo(fuente: f.negrita, tamano: 13, color: acentoPdf),
              ),
            ),
            if (c.numero != null)
              pw.Text(c.numero!, style: estilo(fuente: f.seminegrita)),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Text(e.titulo, style: estilo(fuente: f.seminegrita, tamano: 11.5)),
        pw.Text(
          formatoFechaHora(e.fecha),
          style: estilo(tamano: 9, color: grisPdf),
        ),
        pw.SizedBox(height: 8),
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
                  c.paciente,
                  style: estilo(fuente: f.seminegrita),
                ),
              ),
              pw.Text(
                [
                  if (c.documentoPaciente.isNotEmpty) c.documentoPaciente,
                  if (c.edad != null) '${c.edad} años',
                ].join(' · '),
                style: estilo(),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        tabla([
          if (e.tecnica.trim().isNotEmpty) ('Técnica', e.tecnica.trim()),
          if (e.equipo.trim().isNotEmpty) ('Equipo', e.equipo.trim()),
          if (e.indicacion.trim().isNotEmpty)
            ('Indicación', e.indicacion.trim()),
        ]),
        if (secciones.isNotEmpty) ...[
          rotulo('Hallazgos'),
          for (final s in secciones)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '${s.titulo.trim()}: ',
                      style: estilo(fuente: f.seminegrita),
                    ),
                    pw.TextSpan(
                      text: s.texto.trim(),
                      style: estilo(interlineado: 1.4),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (medidas.isNotEmpty) ...[
          rotulo('Medidas'),
          tabla([for (final m in medidas) (m.nombre, m.texto)]),
        ],
        if (imagenes.isNotEmpty) ...[
          rotulo('Imágenes'),
          for (var k = 0; k < imagenes.length; k += 2)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: celdaImagen(k + 1, imagenes[k].$1, imagenes[k].$2),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: k + 1 < imagenes.length
                        ? celdaImagen(
                            k + 2,
                            imagenes[k + 1].$1,
                            imagenes[k + 1].$2,
                          )
                        : pw.SizedBox(),
                  ),
                ],
              ),
            ),
        ],
        rotulo('Impresión diagnóstica'),
        if (!e.diagnostico.vacio)
          pw.Text(e.diagnostico.texto, style: estilo(fuente: f.seminegrita)),
        if (e.impresion.trim().isNotEmpty)
          textoLargo(e.impresion.trim(), estilo(interlineado: 1.4)),
        if (e.recomendaciones.trim().isNotEmpty) ...[
          rotulo('Recomendaciones'),
          textoLargo(e.recomendaciones.trim(), estilo(interlineado: 1.4)),
        ],
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: bloqueFirmaPdf(f, medico, recursos, alto: 60),
        ),
      ],
    ),
  );
  incrustarAdjuntos(doc, c.adjuntos);
  return doc.save();
}
