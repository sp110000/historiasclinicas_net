import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/medico.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../pdf/piezas_pdf.dart';
import '../../utils/fechas.dart';
import '../../utils/numeros.dart';
import '../../utils/texto.dart';
import 'plantilla_procedimiento.dart';

/// «Protocolo_Hidrolipoclasia_v2.pdf».
String nombreArchivoProcedimiento(
  String prefijo,
  String nombre, {
  int? version,
}) {
  final limpio = sinTildes(
    nombre.trim(),
  ).replaceAll(RegExp('[^A-Za-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return '${prefijo}_${limpio.isEmpty ? 'Procedimiento' : limpio}'
      '${version == null ? '' : '_v$version'}.pdf';
}

String _lista(List<String> l) => l.isEmpty ? '—' : l.join('; ');

String _o(Object? v) => v == null ? '—' : '$v';

/// El protocolo de [d] en texto, por secciones (separadas por una línea en
/// blanco): valoración, sesión, lista de verificación, indicaciones y lo
/// del consentimiento.
String textoProtocolo(DefinicionProcedimiento d) {
  List<String> de(EfectoItem e) => [
    for (final i in d.items)
      if (i.efecto == e) i.texto,
  ];
  String? mL(double? v) => v == null ? null : '${formatoNumero(v)} mL';
  String anestesico(AnestesicoProtocolo a) => [
    a.nombre,
    if (a.concentracionMgMl != null)
      '${formatoNumero(a.concentracionMgMl!)} mg/mL',
    if (a.maximoMgKg != null) 'máximo ${formatoNumero(a.maximoMgKg!)} mg/kg',
  ].join(', ');
  String texto(String t) => t.trim().isEmpty ? '—' : t.trim();
  return [
    [
      'VALORACIÓN',
      'Zonas: ${_lista(d.zonas)}.',
      'Contraindicaciones que dan «no apto»: ${_lista(de(EfectoItem.noApto))}.',
      'Contraindicaciones que dan «diferir»: ${_lista(de(EfectoItem.diferir))}.',
      'Precauciones que piden nota: ${_lista(de(EfectoItem.precaucion))}.',
      if (d.tamizajes.isNotEmpty)
        'Tamizajes: ${d.tamizajes.map((t) => t.nombre).join('; ')}.',
      if (d.imcMaximoAviso != null)
        'Avisa desde un IMC de ${formatoNumero(d.imcMaximoAviso!)}.',
      'Una valoración «apto» vale ${d.vigenciaDias} días.',
      if (d.recomendaciones.isNotEmpty)
        'Recomendaciones: ${_lista(d.recomendaciones)}.',
    ].join('\n'),
    [
      'SESIÓN',
      'Número de sesiones: ${_o(d.numeroSesiones)}. Intervalo: '
          '${_o(d.intervaloDias)} días. Control: a los ${_o(d.diasControl)} '
          'días.',
      if (d.usaSolucion) ...[
        'Componentes de la solución: ${_lista(d.componentes)}.',
        'Volumen máximo: ${mL(d.volumenMaximoZonaMl) ?? '—'} por zona y '
            '${mL(d.volumenMaximoSesionMl) ?? '—'} por sesión.',
      ] else
        'Sin solución infiltrada: se registran las zonas tratadas.',
      if (d.usaAnestesico)
        'Anestésico local: '
            '${d.anestesicos.isEmpty ? '—' : d.anestesicos.map(anestesico).join('; ')}.'
      else
        'Sin anestésico local.',
      if (d.protocolo.trim().isNotEmpty) 'Protocolo: ${d.protocolo.trim()}',
    ].join('\n'),
    [
      'LISTA DE VERIFICACIÓN PREVIA',
      if (d.listaVerificacion.isEmpty) '—',
      for (final i in d.listaVerificacion) '- $i',
    ].join('\n'),
    'INDICACIONES POSTERIORES\n${texto(d.indicacionesPosteriores)}',
    'RIESGOS (CONSENTIMIENTO)\n${texto(d.riesgos)}',
    'ALTERNATIVAS (CONSENTIMIENTO)\n${texto(d.alternativas)}',
  ].join('\n\n');
}

/// Hoja de la lista de verificación previa para la sala: casillas para
/// marcar a mano, el paciente, la fecha y quién verificó.
Future<Uint8List> generarPdfListaVerificacion({
  required String procedimiento,
  required int version,
  required bool borrador,
  required List<String> items,
  required DateTime impresa,
  Autor? medico,
  FuentesPdf? fuentes,
}) async {
  final f = fuentes ?? await FuentesPdf.cargar();
  pw.TextStyle estilo({double tamano = 10, pw.Font? fuente, PdfColor? color}) =>
      pw.TextStyle(font: fuente ?? f.regular, fontSize: tamano, color: color);
  pw.Widget linea(String etiqueta) => pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),
        pw.Divider(color: grisPdf, thickness: 0.6, height: 4),
        pw.Text(etiqueta, style: estilo(tamano: 8, color: grisPdf)),
      ],
    ),
  );
  final doc = pw.Document(
    title: 'Lista de verificación previa · $procedimiento',
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
      footer: (c) => pw.Text(
        [
          'historiasclinicas.net',
          '$procedimiento · protocolo v$version',
          'impresa el ${formatoFecha(impresa)}',
          'Pág. ${c.pageNumber} de ${c.pagesCount}',
        ].join(' · '),
        style: estilo(tamano: 7.5, color: grisPdf),
      ),
      build: (c) => [
        if (medico != null)
          datosMedicoPdf(f, medico)
        else
          pw.Text(
            'historiasclinicas.net',
            style: estilo(fuente: f.negrita, tamano: 11),
          ),
        pw.Divider(color: acentoPdf, thickness: 1.2),
        pw.SizedBox(height: 6),
        pw.Text(
          'LISTA DE VERIFICACIÓN PREVIA',
          style: estilo(fuente: f.negrita, tamano: 13, color: acentoPdf),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '$procedimiento · protocolo v$version',
          style: estilo(fuente: f.seminegrita, tamano: 11),
        ),
        if (borrador)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              'BORRADOR – sin aprobar: no la uses con pacientes.',
              style: estilo(fuente: f.negrita, color: PdfColors.red800),
            ),
          ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            linea('Paciente'),
            pw.SizedBox(width: 16),
            linea('Documento'),
          ],
        ),
        pw.Row(
          children: [
            linea('Fecha'),
            pw.SizedBox(width: 16),
            linea('Hora'),
            pw.SizedBox(width: 16),
            linea('Sesión n.º'),
          ],
        ),
        pw.SizedBox(height: 16),
        if (items.isEmpty)
          pw.Text(
            'La lista está vacía: escríbela en el editor del protocolo.',
            style: estilo(color: grisPdf),
          ),
        for (final i in items)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 12,
                  height: 12,
                  margin: const pw.EdgeInsets.only(right: 10, top: 1),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.9),
                  ),
                ),
                pw.Expanded(child: pw.Text(i, style: estilo(tamano: 11))),
              ],
            ),
          ),
        pw.SizedBox(height: 26),
        pw.Row(
          children: [
            linea('Verificó (nombre y firma)'),
            pw.SizedBox(width: 16),
            linea('Médico (nombre y firma)'),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
