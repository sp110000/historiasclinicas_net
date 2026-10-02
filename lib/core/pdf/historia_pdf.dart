import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../integridad/cadena_hash.dart';
import '../models/historia.dart';
import '../models/mapa.dart';
import '../models/medico.dart';
import '../models/secciones.dart';
import '../presentacion/datos_historia.dart';
import '../utils/fechas.dart';
import 'adjunto_historia.dart';
import 'fuentes_pdf.dart';
import 'piezas_pdf.dart';

/// PDF A4 de la historia clínica.
///
/// Se genera a partir de [datos] (el mismo mapa que se incrusta), así lo
/// impreso y lo reabrible siempre coinciden.
///
/// * Con [borrador] = `true` (vista previa antes de finalizar) lleva marca de
///   agua y **no** incrusta datos: un borrador no debe poder reabrirse como
///   historia finalizada.
/// * Si no, incrusta `historia.json` con [revision].
///
/// Si [datos] trae `medico` (copia del autor) y `recursos`, el encabezado
/// lleva sus datos y logo, y el bloque de firma su firma y sello. Cada
/// evolución lleva su propio autor. El diseño final llega en la Fase 4.
Future<Uint8List> generarPdfHistoria({
  required Map<String, Object?> datos,
  int revision = 0,
  bool borrador = false,
  FuentesPdf? fuentes,
  DateTime? generadoEn,
}) async {
  final f = fuentes ?? await FuentesPdf.cargar();
  final historia = HistoriaClinica.desdeMapa(datos);
  final evoluciones = [
    for (final e in datos.listaMapas('evoluciones')) Evolucion.desdeMapa(e),
  ];
  final hashBase = datos['hashBase'] as String?;
  final finalizadaEn = datos.fecha('finalizadaEn');
  final ahora = generadoEn ?? DateTime.now();
  final medico = datos['medico'] is Map
      ? Autor.desdeMapa(datos.mapa('medico'))
      : null;
  final imagen = ImagenesPdf(datos.mapa('recursos'));
  const gris = grisPdf;
  const linea = lineaPdf;
  const fondoSuave = fondoSuavePdf;
  final anchoUtil = PdfPageFormat.a4.width - 2 * 42;

  pw.TextStyle estilo({
    double tamano = 9.5,
    pw.Font? fuente,
    PdfColor? color,
    double interlineado = 1.5,
  }) => pw.TextStyle(
    font: fuente ?? f.regular,
    fontSize: tamano,
    color: color,
    lineSpacing: interlineado,
  );

  pw.Widget cabeceraSeccion(SeccionHistoria s) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: const pw.BoxDecoration(color: fondoSuave),
    child: pw.Text(
      '${s.numero}. ${tituloSeccion(s, historia.perfil).toUpperCase()}',
      style: pw.TextStyle(font: f.seminegrita, fontSize: 9, letterSpacing: 0.5),
    ),
  );

  pw.Widget datosSeccion(List<DatoMostrado> lista) {
    if (lista.isEmpty) {
      return pw.Text('Sin datos registrados.', style: estilo(color: gris));
    }
    double ancho(AnchoDato a) => switch (a) {
      AnchoDato.corto => (anchoUtil - 24) / 3,
      AnchoDato.medio => (anchoUtil - 12) / 2,
      AnchoDato.completo => anchoUtil,
    };
    return pw.Wrap(
      spacing: 12,
      runSpacing: 7,
      children: [
        for (final d in lista)
          pw.SizedBox(
            width: ancho(d.ancho),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  d.etiqueta.toUpperCase(),
                  style: pw.TextStyle(
                    font: f.media,
                    fontSize: 6.8,
                    color: gris,
                  ),
                ),
                pw.SizedBox(height: 1.5),
                pw.Text(d.valor, style: estilo()),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget bloqueFirma(Autor? autor, {required double alto}) =>
      bloqueFirmaPdf(f, autor, imagen, alto: alto);

  pw.Widget evolucion(int numero, Evolucion e) {
    final signos = resumenSignos(e.signos);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(left: 8, top: 2, bottom: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: linea, width: 2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Evolución $numero · ${formatoFechaHora(e.fechaHora)}',
                  style: pw.TextStyle(font: f.seminegrita, fontSize: 9.5),
                ),
              ),
              if (e.hash != null)
                pw.Text(
                  'Huella ${huella(e.hash!)}',
                  style: pw.TextStyle(fontSize: 7.5, color: gris),
                ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text(e.texto, style: estilo()),
          if (signos.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(signos, style: estilo(tamano: 8.5, color: gris)),
            ),
          if (e.avisoIntegridad != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                e.avisoIntegridad!,
                style: estilo(tamano: 8, color: gris, fuente: f.media),
              ),
            ),
          if (e.autor != null)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: bloqueFirma(e.autor, alto: 30),
              ),
            ),
        ],
      ),
    );
  }

  final p = historia.paciente;
  final doc = pw.Document(
    title: 'Historia clínica · ${p.nombreCompleto}',
    author: medico?.nombre ?? 'historiasclinicas.net',
    creator: 'historiasclinicas.net',
    theme: f.tema,
  );

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 36, 42, 36),
        theme: f.tema,
        buildForeground: borrador
            ? (context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Watermark.text(
                  'BORRADOR',
                  style: pw.TextStyle(
                    font: f.negrita,
                    fontSize: 90,
                    color: const PdfColor(0, 0, 0, 0.07),
                  ),
                ),
              )
            : null,
      ),
      header: (context) {
        final paciente = [
          p.nombreCompleto,
          if (p.numeroDocumento.isNotEmpty)
            '${p.tipoDocumento} ${p.numeroDocumento}',
        ].join(' · ');
        final logo = imagen(medico?.logo);
        final datosHistoria = pw.Column(
          crossAxisAlignment: medico == null
              ? pw.CrossAxisAlignment.start
              : pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'HISTORIA CLÍNICA',
              style: pw.TextStyle(
                font: f.negrita,
                fontSize: medico == null ? 14 : 11.5,
              ),
            ),
            pw.Text(
              paciente,
              style: pw.TextStyle(font: f.media, fontSize: 8.5, color: gris),
            ),
            pw.Text(
              'Atención: ${formatoFechaHora(historia.fechaAtencion)} · '
              'Pág. ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 7.5, color: gris),
            ),
          ],
        );
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 1.1)),
          ),
          child: medico == null
              ? pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [pw.Expanded(child: datosHistoria)],
                )
              : pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logo != null) ...[
                      pw.Container(
                        height: 40,
                        constraints: const pw.BoxConstraints(maxWidth: 110),
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(width: 10),
                    ],
                    pw.Expanded(child: datosMedicoPdf(f, medico)),
                    pw.SizedBox(width: 10),
                    datosHistoria,
                  ],
                ),
        );
      },
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 6),
        padding: const pw.EdgeInsets.only(top: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: linea, width: 0.5)),
        ),
        child: pw.Text(
          borrador
              ? 'BORRADOR SIN FINALIZAR · generado ${formatoFechaHora(ahora)} · '
                    'no contiene datos para reabrirlo'
              : 'historiasclinicas.net · revisión $revision · '
                    'guardado ${formatoFechaHora(ahora)} · contiene los datos '
                    'estructurados ($nombreAdjuntoHistoria): no lo modifique '
                    'con otros programas',
          style: pw.TextStyle(fontSize: 6.8, color: gris),
        ),
      ),
      build: (context) => [
        for (final s in SeccionHistoria.values.where(
          (s) => s != SeccionHistoria.firma && s != SeccionHistoria.evoluciones,
        )) ...[cabeceraSeccion(s), datosSeccion(datosDeSeccion(s, historia))],
        // Título y firma juntos: el título no queda solo al final de una
        // página (Inseparable impide partir el bloque).
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              cabeceraSeccion(SeccionHistoria.firma),
              pw.SizedBox(height: 18),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (finalizadaEn != null)
                          pw.Text(
                            'Historia finalizada el ${formatoFechaHora(finalizadaEn)}',
                            style: estilo(tamano: 8, color: gris),
                          ),
                        if (hashBase != null)
                          pw.Text(
                            'Huella de la historia: ${huella(hashBase)}',
                            style: estilo(tamano: 8, color: gris),
                          ),
                      ],
                    ),
                  ),
                  bloqueFirma(medico, alto: 62),
                ],
              ),
            ],
          ),
        ),
        cabeceraSeccion(SeccionHistoria.evoluciones),
        if (evoluciones.isEmpty)
          pw.Text('Sin evoluciones registradas.', style: estilo(color: gris)),
        for (final (i, e) in evoluciones.indexed) evolucion(i + 1, e),
      ],
    ),
  );

  if (!borrador) {
    incrustarHistoria(
      doc,
      PaqueteHistoria(revision: revision, guardadoEn: ahora, datos: datos),
    );
  }
  return doc.save();
}
