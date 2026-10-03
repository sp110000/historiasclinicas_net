import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../integridad/cadena_hash.dart';
import '../models/historia.dart';
import '../models/mapa.dart';
import '../models/medico.dart';
import '../models/secciones.dart';
import '../presentacion/datos_historia.dart';
import '../receta/receta.dart' show PacienteReceta;
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
/// evolución lleva su propio autor.
///
/// Los textos largos (un campo o una evolución de varias páginas) continúan
/// en la página siguiente; lo demás va en bloques que no se parten.
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

  // 2b: número en petróleo, título en versalitas y filete inferior.
  pw.Widget cabeceraSeccion(SeccionHistoria s) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
    padding: const pw.EdgeInsets.only(bottom: 3),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: linea, width: 0.8)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          '${s.numero}',
          style: pw.TextStyle(font: f.negrita, fontSize: 9.5, color: acentoPdf),
        ),
        pw.SizedBox(width: 7),
        pw.Text(
          tituloSeccion(s, historia.perfil).toUpperCase(),
          style: pw.TextStyle(
            font: f.seminegrita,
            fontSize: 9,
            letterSpacing: 0.6,
          ),
        ),
      ],
    ),
  );

  double ancho(AnchoDato a) => switch (a) {
    AnchoDato.corto => (anchoUtil - 24) / 3,
    AnchoDato.medio => (anchoUtil - 12) / 2,
    AnchoDato.completo => anchoUtil,
  };

  pw.Widget etiquetaDato(String etiqueta) => pw.Text(
    etiqueta.toUpperCase(),
    style: pw.TextStyle(
      font: f.media,
      fontSize: 7,
      letterSpacing: 0.3,
      color: gris,
    ),
  );

  /// Ficha del paciente sobre la sección 1 (solo presentación: usa los
  /// mismos datos que ya se imprimen).
  pw.Widget fichaPaciente() {
    final r = PacienteReceta.deHistoria(historia);
    final sexo = datosDeSeccion(
      SeccionHistoria.paciente,
      historia,
    ).where((d) => d.etiqueta == 'Sexo').map((d) => d.valor).firstOrNull;
    final celdas = [
      ('Paciente', r.nombre, true, 2.2),
      ('Documento', r.documento, false, 1.4),
      ('Edad', r.edad, false, 0.8),
      ('Sexo', sexo ?? '', false, 1.0),
      ('Alergias', r.alergias, true, 1.4),
    ].where((c) => c.$2.trim().isNotEmpty).toList();
    if (celdas.isEmpty) return pw.SizedBox();
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4, bottom: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: linea, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final (i, (e, v, fuerte, flex)) in celdas.indexed)
            pw.Expanded(
              flex: (flex * 10).round(),
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 5,
                ),
                decoration: i == 0
                    ? null
                    : const pw.BoxDecoration(
                        border: pw.Border(
                          left: pw.BorderSide(color: linea, width: 0.5),
                        ),
                      ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    etiquetaDato(e),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      v,
                      style: estilo(
                        tamano: 9.5,
                        fuente: fuerte ? f.seminegrita : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget dato(DatoMostrado d) => pw.SizedBox(
    width: ancho(d.ancho),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        etiquetaDato(d.etiqueta),
        pw.SizedBox(height: 1.5),
        pw.Text(d.valor, style: estilo()),
      ],
    ),
  );

  /// Una sección: su título va siempre con la primera fila de datos. Las
  /// filas no se parten entre páginas; los textos largos van sueltos para
  /// que continúen en la página siguiente (un bloque más alto que una
  /// página no se podría imprimir).
  List<pw.Widget> seccion(SeccionHistoria s) {
    final lista = datosDeSeccion(s, historia);
    final bloques = <pw.Widget>[];
    final fila = <DatoMostrado>[];
    var usado = 0.0;
    void cerrarFila() {
      if (fila.isEmpty) return;
      bloques.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 7),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final (i, d) in fila.indexed) ...[
                if (i > 0) pw.SizedBox(width: 12),
                dato(d),
              ],
            ],
          ),
        ),
      );
      fila.clear();
      usado = 0;
    }

    for (final d in lista) {
      final w = ancho(d.ancho);
      if (!cabeEnBloque(d.valor, w)) {
        cerrarFila();
        bloques
          ..add(etiquetaDato(d.etiqueta))
          ..add(pw.SizedBox(height: 1.5))
          ..add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 7),
              child: textoLargo(d.valor, estilo()),
            ),
          );
        continue;
      }
      final necesario = fila.isEmpty ? w : usado + 12 + w;
      if (necesario > anchoUtil + 0.5) cerrarFila();
      usado = fila.isEmpty ? w : usado + 12 + w;
      fila.add(d);
    }
    cerrarFila();
    if (bloques.isEmpty) {
      bloques.add(
        pw.Text('Sin datos registrados.', style: estilo(color: gris)),
      );
    }
    final primero = bloques.removeAt(0);
    return [
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [cabeceraSeccion(s), primero],
        ),
      ),
      ...bloques,
    ];
  }

  pw.Widget bloqueFirma(Autor? autor, {required double alto}) =>
      bloqueFirmaPdf(f, autor, imagen, alto: alto);

  /// [titulo] (el de la sección, en la primera) va pegado a la evolución.
  List<pw.Widget> evolucion(int numero, Evolucion e, {pw.Widget? titulo}) {
    final signos = resumenSignos(e.signos);
    final encabezado = pw.Container(
      margin: const pw.EdgeInsets.only(top: 2),
      padding: const pw.EdgeInsets.only(top: 5, bottom: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: linea, width: 0.6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
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
    );
    pw.Widget sangria(pw.Widget hijo, {double arriba = 0}) => pw.Padding(
      padding: pw.EdgeInsets.only(left: 8, top: arriba),
      child: hijo,
    );
    final partes = [
      if (titulo == null)
        encabezado
      else
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [titulo, encabezado],
          ),
        ),
      sangria(textoLargo(e.texto, estilo())),
      if (signos.isNotEmpty)
        sangria(
          pw.Text(signos, style: estilo(tamano: 8.5, color: gris)),
          arriba: 2,
        ),
      if (e.avisoIntegridad != null)
        sangria(
          pw.Text(
            e.avisoIntegridad!,
            style: estilo(tamano: 8, color: gris, fuente: f.media),
          ),
          arriba: 2,
        ),
      if (e.autor != null)
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: bloqueFirma(e.autor, alto: 30),
          ),
        ),
      pw.SizedBox(height: 8),
    ];
    // Una evolución corta no se parte; una larga continúa en otra página.
    return cabeEnBloque(e.texto, anchoUtil - 8)
        ? [
            pw.Inseparable(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: partes,
              ),
            ),
          ]
        : partes;
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
        fichaPaciente(),
        for (final s in SeccionHistoria.values.where(
          (s) => s != SeccionHistoria.firma && s != SeccionHistoria.evoluciones,
        ))
          ...seccion(s),
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
        if (evoluciones.isEmpty) ...[
          cabeceraSeccion(SeccionHistoria.evoluciones),
          pw.Text('Sin evoluciones registradas.', style: estilo(color: gris)),
        ],
        for (final (i, e) in evoluciones.indexed)
          ...evolucion(
            i + 1,
            e,
            titulo: i == 0
                ? cabeceraSeccion(SeccionHistoria.evoluciones)
                : null,
          ),
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
