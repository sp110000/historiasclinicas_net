import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/medico.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../pdf/piezas_pdf.dart';
import '../../utils/fechas.dart';
import '../../utils/numeros.dart';
import 'programa_peso.dart';

/// Indicaciones impresas del programa de peso: meta, planes, el
/// recordatorio de proteína y fuerza (pregunta 26) y el GLP-1 vigente.
Future<Uint8List> generarIndicacionesPeso({
  required ProgramaPeso programa,
  required String paciente,
  required String documento,
  Autor? medico,
  Map<String, String> recursos = const {},
  FuentesPdf? fuentes,
  DateTime? generadoEn,
}) async {
  final f = fuentes ?? await FuentesPdf.cargar();
  final ahora = generadoEn ?? DateTime.now();
  final imagenes = ImagenesPdf(recursos);
  pw.TextStyle estilo({
    double tamano = 9.5,
    pw.Font? fuente,
    PdfColor? color,
  }) => pw.TextStyle(font: fuente ?? f.regular, fontSize: tamano, color: color);
  pw.Widget titulo(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
    child: pw.Text(
      t.toUpperCase(),
      style: estilo(tamano: 8, fuente: f.seminegrita, color: acentoPdf),
    ),
  );
  final p = programa;
  final g = p.glp1;
  final meta = [
    if (p.metaPeso != null) 'peso ${formatoNumero(p.metaPeso!)} kg',
    if (p.metaCintura != null) 'cintura ${formatoNumero(p.metaCintura!)} cm',
    if (p.metaFecha != null) 'para el ${formatoFecha(p.metaFecha!)}',
  ];

  final doc = pw.Document(
    title: 'Indicaciones · programa de peso · $paciente',
    author: medico?.nombre ?? 'historiasclinicas.net',
    creator: 'historiasclinicas.net',
    theme: f.tema,
  );
  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
        theme: f.tema,
      ),
      header: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: acentoPdf, width: 1)),
        ),
        child: medico == null
            ? pw.Text(
                'historiasclinicas.net',
                style: estilo(fuente: f.negrita, tamano: 11),
              )
            : datosMedicoPdf(f, medico),
      ),
      footer: (context) => pw.Text(
        'historiasclinicas.net · Indicaciones del programa de peso · '
        '${formatoFechaHora(ahora)} · Pág. ${context.pageNumber} de '
        '${context.pagesCount}',
        style: estilo(tamano: 7, color: grisPdf),
      ),
      build: (context) => [
        pw.Text(
          'INDICACIONES · PROGRAMA DE PESO',
          style: estilo(tamano: 13, fuente: f.negrita, color: acentoPdf),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '$paciente${documento.isEmpty ? '' : ' · $documento'} · desde el '
          '${formatoFecha(p.inicio)}',
          style: estilo(fuente: f.seminegrita),
        ),
        if (meta.isNotEmpty) ...[
          titulo('Meta'),
          pw.Text(meta.join(' · '), style: estilo()),
        ],
        titulo('Recuerda'),
        pw.Text(
          '$recordatorioProteinaFuerza'
          '${p.proteina.isEmpty ? '' : ' Proteína indicada: ${p.proteina}.'}',
          style: estilo(),
        ),
        if (p.planNutricional != null) ...[
          titulo('Plan nutricional · ${p.planNutricional!.nombre}'),
          textoLargo(p.planNutricional!.texto, estilo()),
        ],
        if (p.planEjercicio != null) ...[
          titulo('Plan de ejercicio · ${p.planEjercicio!.nombre}'),
          textoLargo(p.planEjercicio!.texto, estilo()),
        ],
        if (g != null && g.activo && g.dosisActual != null) ...[
          titulo('Medicamento'),
          pw.Text(
            '${g.nombre}: ${g.dosisActual!.texto} desde el '
            '${formatoFecha(g.dosisActual!.fecha)}.',
            style: estilo(),
          ),
        ],
        pw.SizedBox(height: 24),
        pw.Inseparable(
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: bloqueFirmaPdf(f, medico, imagenes, alto: 50),
          ),
        ),
      ],
    ),
  );
  return doc.save();
}
