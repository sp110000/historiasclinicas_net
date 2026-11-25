import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/medico.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../pdf/piezas_pdf.dart';
import '../../utils/fechas.dart';
import 'catalogo.dart';
import 'movimientos.dart';

/// Aviso obligatorio del recibo (pregunta 46). Tus obligaciones ante la DIAN
/// (facturación electrónica) quedan VERIFICAR con tu contador.
const avisoNoFactura = 'Este documento no es una factura electrónica de venta.';

/// Lo que se imprime en un recibo de caja.
class ContenidoRecibo {
  const ContenidoRecibo({
    required this.recibo,
    required this.cobro,
    required this.paciente,
    required this.documentoPaciente,
    required this.pagadoALaFecha,
    this.medico,
    this.recursos = const {},
  });

  final Recibo recibo;
  final Cobro cobro;
  final String paciente;
  final String documentoPaciente;

  /// Lo pagado del cobro con este recibo (todos los recibos vigentes).
  final int pagadoALaFecha;
  final Autor? medico;
  final Map<String, String> recursos;

  int get saldo => cobro.total - pagadoALaFecha;
}

/// Recibo de caja en A5 vertical: tus datos, el número, el paciente, lo
/// cobrado, este pago por medio, lo pagado a la fecha, el saldo y el aviso
/// de que no es factura electrónica.
Future<Uint8List> generarPdfRecibo(
  ContenidoRecibo c, {
  FuentesPdf? fuentes,
}) async {
  final f = fuentes ?? await FuentesPdf.cargar();
  final imagenes = ImagenesPdf(c.recursos);
  final medico = c.medico;
  final r = c.recibo;
  final cobro = c.cobro;

  pw.TextStyle estilo({double tamano = 9, pw.Font? fuente, PdfColor? color}) =>
      pw.TextStyle(font: fuente ?? f.regular, fontSize: tamano, color: color);

  pw.Widget fila(
    String a,
    String b, {
    bool negrita = false,
    PdfColor? color,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            a,
            style: estilo(fuente: negrita ? f.seminegrita : null, color: color),
          ),
        ),
        pw.Text(
          b,
          style: estilo(fuente: negrita ? f.seminegrita : null, color: color),
        ),
      ],
    ),
  );

  final doc = pw.Document(
    title: 'Recibo de caja · ${r.numero}',
    author: medico?.nombre ?? 'historiasclinicas.net',
    creator: 'historiasclinicas.net',
    theme: f.tema,
  );
  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 22),
        theme: f.tema,
      ),
      header: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: acentoPdf, width: 1)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: medico == null
                  ? pw.Text(
                      'historiasclinicas.net',
                      style: estilo(fuente: f.negrita, tamano: 10),
                    )
                  : datosMedicoPdf(f, medico),
            ),
            if (imagenes(medico?.logo) case final logo?)
              pw.SizedBox(height: 32, child: pw.Image(logo)),
          ],
        ),
      ),
      footer: (context) => pw.Text(
        [
          'historiasclinicas.net',
          r.numero,
          'Pág. ${context.pageNumber} de ${context.pagesCount}',
        ].join(' · '),
        style: estilo(tamano: 7, color: grisPdf),
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                'RECIBO DE CAJA',
                style: estilo(fuente: f.negrita, tamano: 12, color: acentoPdf),
              ),
            ),
            pw.Text(r.numero, style: estilo(fuente: f.seminegrita, tamano: 10)),
          ],
        ),
        pw.Text(
          formatoFechaHora(r.fecha),
          style: estilo(tamano: 8, color: grisPdf),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
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
              pw.Text(c.documentoPaciente, style: estilo()),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'CONCEPTO',
          style: estilo(tamano: 7.5, fuente: f.seminegrita, color: grisPdf),
        ),
        pw.Divider(color: lineaPdf, thickness: 0.5, height: 6),
        for (final i in cobro.items) ...[
          fila(
            '${i.descripcion}${i.cantidad > 1 ? ' × ${i.cantidad}' : ''}',
            formatoPesos(i.bruto),
          ),
          if (i.descuento > 0)
            fila(
              '   Descuento${i.motivoDescuento.isEmpty ? '' : ' (${i.motivoDescuento})'}',
              formatoPesos(-i.descuento),
              color: grisPdf,
            ),
        ],
        if (cobro.credito > 0)
          fila(
            '   Crédito de la valoración',
            formatoPesos(-cobro.credito),
            color: grisPdf,
          ),
        pw.Divider(color: lineaPdf, thickness: 0.5, height: 6),
        fila('Total', formatoPesos(cobro.total), negrita: true),
        pw.SizedBox(height: 8),
        pw.Text(
          'ESTE PAGO',
          style: estilo(tamano: 7.5, fuente: f.seminegrita, color: grisPdf),
        ),
        pw.Divider(color: lineaPdf, thickness: 0.5, height: 6),
        for (final p in r.pagos)
          fila(
            [
              p.medio.etiqueta,
              if (p.referencia.trim().isNotEmpty) 'ref. ${p.referencia.trim()}',
            ].join(' · '),
            formatoPesos(p.valor),
          ),
        pw.Divider(color: lineaPdf, thickness: 0.5, height: 6),
        fila('Valor de este recibo', formatoPesos(r.valor), negrita: true),
        fila('Pagado a la fecha', formatoPesos(c.pagadoALaFecha)),
        fila('Saldo', formatoPesos(c.saldo), negrita: c.saldo > 0),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF3F6F8),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            avisoNoFactura,
            style: estilo(fuente: f.seminegrita, tamano: 8.5),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: bloqueFirmaPdf(f, medico, imagenes, alto: 40),
        ),
      ],
    ),
  );
  return doc.save();
}
