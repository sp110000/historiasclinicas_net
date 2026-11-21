import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../pdf/fuentes_pdf.dart';
import '../../pdf/piezas_pdf.dart';
import '../../utils/fechas.dart';
import '../seguridad/llavero.dart';

String nombreHojaRecuperacion(DateTime f) =>
    'Hoja_recuperacion_consultorio_${f.year}-'
    '${f.month.toString().padLeft(2, '0')}-'
    '${f.day.toString().padLeft(2, '0')}.pdf';

/// Hoja A4 para imprimir con el código de recuperación. No lleva datos de
/// pacientes ni la frase de acceso.
Future<Uint8List> generarHojaRecuperacion({
  required String codigo,
  required DateTime fecha,
  FuentesPdf? fuentes,
}) async {
  final f = fuentes ?? await FuentesPdf.cargar();
  final grupos = formatearCodigo(codigo).split('-');
  pw.TextStyle estilo(double tamano, {pw.Font? fuente, PdfColor? color}) =>
      pw.TextStyle(
        font: fuente ?? f.regular,
        fontSize: tamano,
        color: color,
        lineSpacing: 2,
      );
  pw.Widget punto(String texto) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 12, child: pw.Text('•', style: estilo(11))),
        pw.Expanded(child: pw.Text(texto, style: estilo(11))),
      ],
    ),
  );

  final doc = pw.Document(
    theme: f.tema,
    title: 'Hoja de recuperación del consultorio',
    creator: 'historiasclinicas.net',
  );
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(56, 56, 56, 48),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'HOJA DE RECUPERACIÓN DEL CONSULTORIO',
            style: estilo(10, fuente: f.seminegrita, color: acentoPdf),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'historiasclinicas.net · generada el ${formatoFechaHora(fecha)}',
            style: estilo(10, color: grisPdf),
          ),
          pw.SizedBox(height: 28),
          pw.Text('Código de recuperación', style: estilo(12, fuente: f.media)),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 18),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: lineaPdf, width: 1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                for (var i = 0; i < grupos.length; i++) ...[
                  if (i > 0) pw.Text(' – ', style: estilo(20, color: grisPdf)),
                  pw.Text(
                    grupos[i],
                    style: estilo(
                      24,
                      fuente: f.seminegrita,
                    ).copyWith(letterSpacing: 2),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Text('Para qué sirve', style: estilo(12, fuente: f.media)),
          pw.SizedBox(height: 8),
          punto(
            'Si olvidas la frase de acceso, este código abre el consultorio en '
            'este equipo o abre un respaldo, y te deja poner una frase nueva.',
          ),
          punto(
            'Sin la frase ni este código, nadie puede abrir los datos del '
            'consultorio: tampoco el desarrollador de la app.',
          ),
          pw.SizedBox(height: 16),
          pw.Text('Cómo guardarla', style: estilo(12, fuente: f.media)),
          pw.SizedBox(height: 8),
          punto(
            'Guárdala impresa en un lugar seguro, lejos del equipo y de las '
            'memorias con los respaldos.',
          ),
          punto(
            'No la fotografíes ni la guardes en el mismo equipo: quien tenga '
            'este código y un respaldo puede abrir los datos.',
          ),
          punto(
            'Si generas un código nuevo en Ajustes, este deja de servir: '
            'destruye esta hoja e imprime la nueva.',
          ),
          pw.Spacer(),
          pw.Divider(color: lineaPdf, thickness: 0.6),
          pw.Text(
            'Esta hoja no contiene datos de pacientes.',
            style: estilo(9, color: grisPdf),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
