import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/medico.dart';
import '../pais/perfil_pais.dart';
import '../receta/receta.dart';
import '../utils/fechas.dart';
import 'fuentes_pdf.dart';
import 'piezas_pdf.dart';

/// Todo lo que se imprime en una receta.
class DocumentoReceta {
  const DocumentoReceta({
    required this.receta,
    required this.paciente,
    required this.pais,
    this.titulo = 'Receta médica',
    this.medico,
    this.recursos = const {},
  });

  final Receta receta;

  /// Datos del paciente ya con las correcciones de la receta.
  final PacienteReceta paciente;
  final Pais pais;

  /// "Receta médica"; en España podría ser "Hoja de tratamiento"
  /// (VERIFICAR).
  final String titulo;

  /// Copia del médico (ver `instantaneaMedico`) con los SHA-256 de sus
  /// imágenes en [recursos].
  final Autor? medico;
  final Map<String, String> recursos;
}

/// PDF de la receta en A5 vertical (148 × 210 mm). Si los medicamentos no
/// caben, continúa en otra hoja con la numeración seguida; la firma va al
/// pie de la última.
Future<Uint8List> generarPdfReceta(
  DocumentoReceta d, {
  FuentesPdf? fuentes,
  DateTime? generadoEn,
}) async {
  final f = fuentes ?? await FuentesPdf.cargar();
  final r = d.receta;
  final p = d.paciente;
  final medico = d.medico;
  final imagen = ImagenesPdf(d.recursos);
  final ahora = generadoEn ?? DateTime.now();
  final items = r.itemsConDatos;

  pw.TextStyle estilo({double tamano = 9, pw.Font? fuente, PdfColor? color}) =>
      pw.TextStyle(
        font: fuente ?? f.regular,
        fontSize: tamano,
        color: color,
        lineSpacing: 1.4,
      );

  pw.Widget dato(String etiqueta, String valor, {bool destacado = false}) =>
      pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$etiqueta: ',
              style: estilo(tamano: 7.5, fuente: f.media, color: grisPdf),
            ),
            pw.TextSpan(
              text: valor,
              style: estilo(
                tamano: 8.5,
                fuente: destacado ? f.seminegrita : f.regular,
              ),
            ),
          ],
        ),
      );

  pw.Widget encabezado(pw.Context context) {
    final logo = imagen(medico?.logo);
    final datosReceta = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          d.titulo.toUpperCase(),
          style: pw.TextStyle(font: f.negrita, fontSize: 9, letterSpacing: 0.4),
        ),
        if (r.numero != null)
          pw.Text(
            'N.º ${r.numero}',
            style: pw.TextStyle(font: f.seminegrita, fontSize: 8.5),
          ),
        pw.Text(
          'Fecha: ${formatoFecha(r.fecha)}',
          style: pw.TextStyle(fontSize: 7.5, color: grisPdf),
        ),
      ],
    );
    final linea2 = [
      if (p.edad.isNotEmpty) ('Edad', p.edad),
      if (d.pais == Pais.espana && p.fechaNacimiento.isNotEmpty)
        ('F. nac.', p.fechaNacimiento),
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 5),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 1)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.Container(
                  height: 32,
                  constraints: const pw.BoxConstraints(maxWidth: 78),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 8),
              ],
              pw.Expanded(
                child: medico == null
                    ? pw.SizedBox()
                    : datosMedicoPdf(
                        f,
                        medico,
                        tamanoNombre: 10,
                        tamanoDetalle: 7.2,
                      ),
              ),
              pw.SizedBox(width: 8),
              datosReceta,
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          margin: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: lineaPdf, width: 0.6),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Expanded(
                    child: dato(
                      'Paciente',
                      p.nombre.isEmpty ? '—' : p.nombre,
                      destacado: true,
                    ),
                  ),
                  if (p.documento.isNotEmpty) dato('Doc.', p.documento),
                ],
              ),
              if (linea2.isNotEmpty)
                pw.Row(
                  children: [
                    for (final (i, (e, v)) in linea2.indexed) ...[
                      if (i > 0) pw.SizedBox(width: 12),
                      dato(e, v),
                    ],
                  ],
                ),
              if (p.diagnostico.isNotEmpty) dato('Diagnóstico', p.diagnostico),
              if (p.alergias.isNotEmpty)
                dato('Alergias', p.alergias, destacado: true),
              if (context.pageNumber > 1)
                pw.Text(
                  '(continuación)',
                  style: estilo(tamano: 7.5, color: grisPdf),
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget itemReceta(int numero, ItemReceta i) => pw.Inseparable(
    child: pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 16,
            child: pw.Text(
              '$numero.',
              style: estilo(tamano: 9.5, fuente: f.seminegrita),
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  i.titulo,
                  style: estilo(tamano: 9.5, fuente: f.seminegrita),
                ),
                if (i.posologia.isNotEmpty)
                  pw.Text(i.posologia, style: estilo()),
                if (i.cantidad != null)
                  pw.Text(
                    'Cantidad: ${i.textoCantidad}',
                    style: estilo(tamano: 8.5, fuente: f.media),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  pw.Widget pie(pw.Context context) {
    final ultima = context.pageNumber == context.pagesCount;
    final autor = medico == null
        ? null
        : Autor(
            nombre: medico.nombre,
            registro: medico.registro,
            etiquetaRegistro: medico.etiquetaRegistro,
            firma: r.incluirFirma ? medico.firma : null,
            sello: r.incluirSello ? medico.sello : null,
          );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (ultima)
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: bloqueFirmaPdf(f, autor, imagen, alto: 46, ancho: 190),
          )
        else
          pw.Text(
            'Continúa en la página siguiente.',
            textAlign: pw.TextAlign.right,
            style: estilo(tamano: 8, fuente: f.media, color: grisPdf),
          ),
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 6),
          padding: const pw.EdgeInsets.only(top: 3),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: lineaPdf, width: 0.5)),
          ),
          child: pw.Text(
            [
              'historiasclinicas.net',
              if (r.numero != null) r.numero!,
              'generada ${formatoFechaHora(ahora)}',
              if (context.pagesCount > 1)
                'Pág. ${context.pageNumber} de ${context.pagesCount}',
            ].join(' · '),
            style: pw.TextStyle(fontSize: 6, color: grisPdf),
          ),
        ),
      ],
    );
  }

  final doc = pw.Document(
    title: '${d.titulo} · ${p.nombre}',
    author: medico?.nombre ?? 'historiasclinicas.net',
    creator: 'historiasclinicas.net',
    theme: f.tema,
  );

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 20),
        theme: f.tema,
      ),
      header: encabezado,
      footer: pie,
      build: (context) => [
        pw.Text('℞', style: pw.TextStyle(font: f.negrita, fontSize: 18)),
        pw.SizedBox(height: 4),
        if (items.isEmpty)
          pw.Text('Sin medicamentos.', style: estilo(color: grisPdf)),
        for (final (n, i) in items.indexed) itemReceta(n + 1, i),
        if (r.indicaciones.trim().isNotEmpty) ...[
          pw.Divider(color: lineaPdf, thickness: 0.5, height: 10),
          pw.Text(
            'INDICACIONES',
            style: estilo(tamano: 7, fuente: f.media, color: grisPdf),
          ),
          pw.Text(r.indicaciones.trim(), style: estilo()),
        ],
      ],
    ),
  );
  return doc.save();
}
