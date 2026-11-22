import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/medico.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../pdf/piezas_pdf.dart';
import '../../utils/fechas.dart';
import '../../utils/numeros.dart';
import '../modelos/foto.dart';
import '../modelos/medicion.dart';

/// Datos del paciente que van en el encabezado del informe.
class PacienteInforme {
  const PacienteInforme({
    required this.nombre,
    this.documento = '',
    this.edad,
    this.sexo,
  });

  final String nombre;
  final String documento;
  final int? edad;
  final String? sexo;
}

/// Una foto con sus bytes (JPEG), para incluirla en un PDF.
typedef FotoConBytes = ({Foto foto, Uint8List bytes});

String _n(double? v, [int? d]) =>
    v == null ? '—' : formatoNumero(v, decimales: d);

/// Informe de seguimiento (A4): ficha del paciente, cambios, gráficas de
/// peso, IMC y cintura (`pw.Chart`, en gris con el acento petróleo), tabla
/// de mediciones y, solo si se piden, fotos. Firma y sello al final.
Future<Uint8List> generarInformeSeguimiento({
  required PacienteInforme paciente,
  required List<Medicion> mediciones,
  List<FotoConBytes> fotos = const [],
  Autor? medico,
  Map<String, String> recursos = const {},
  FuentesPdf? fuentes,
  DateTime? generadoEn,
}) async {
  final f = fuentes ?? await FuentesPdf.cargar();
  final ahora = generadoEn ?? DateTime.now();
  final ms = [...mediciones]..sort((a, b) => a.fecha.compareTo(b.fecha));
  final imagenes = ImagenesPdf(recursos);

  pw.TextStyle estilo({double tamano = 9, pw.Font? fuente, PdfColor? color}) =>
      pw.TextStyle(font: fuente ?? f.regular, fontSize: tamano, color: color);

  pw.Widget titulo(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12, bottom: 5),
    child: pw.Text(
      t.toUpperCase(),
      style: estilo(tamano: 8, fuente: f.seminegrita, color: acentoPdf),
    ),
  );

  pw.Widget? grafica(
    String nombre,
    String unidad,
    double? Function(Medicion) valor,
  ) {
    final puntos = [
      for (final m in ms)
        if (valor(m) case final v?) (fecha: m.fecha, valor: v),
    ];
    if (puntos.length < 2) return null;
    final ejeY = marcasEje(
      puntos.map((p) => p.valor).reduce(math.min),
      puntos.map((p) => p.valor).reduce(math.max),
    );
    // Eje X proporcional al tiempo (como la gráfica de la ficha), en días
    // desde la primera medición; se rotulan las fechas que no se pisan.
    final t0 = puntos.first.fecha;
    double dia(DateTime f) => f.difference(t0).inMinutes / (24 * 60);
    final span = dia(puntos.last.fecha);
    if (span <= 0) return null; // Todas el mismo momento: no hay curva.
    final rotulos = <double, DateTime>{};
    for (final p in puntos.reversed) {
      final d = dia(p.fecha);
      if (rotulos.keys.every((k) => (k - d).abs() >= span * 0.12)) {
        rotulos[d] = p.fecha;
      }
    }
    if (!rotulos.containsKey(0.0)) {
      rotulos.removeWhere((k, _) => k < span * 0.12);
      rotulos[0] = t0;
    }
    final ejeX = rotulos.keys.toList()..sort();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$nombre${unidad.isEmpty ? '' : ' ($unidad)'}',
          style: estilo(tamano: 8.5, fuente: f.seminegrita),
        ),
        pw.SizedBox(
          height: 92,
          child: pw.Chart(
            grid: pw.CartesianGrid(
              xAxis: pw.FixedAxis(
                ejeX,
                buildLabel: (v) => pw.Text(
                  _fechaCorta(rotulos[v]!),
                  style: estilo(tamano: 6.5, color: grisPdf),
                ),
                color: lineaPdf,
                textStyle: estilo(tamano: 6.5, color: grisPdf),
                marginStart: 10,
                marginEnd: 10,
              ),
              yAxis: pw.FixedAxis(
                ejeY.marcas,
                format: (v) =>
                    formatoNumero(v.toDouble(), decimales: ejeY.decimales),
                divisions: true,
                divisionsColor: lineaPdf,
                color: lineaPdf,
                textStyle: estilo(tamano: 6.5, color: grisPdf),
              ),
            ),
            datasets: [
              pw.LineDataSet(
                data: [
                  for (final p in puntos)
                    pw.PointChartValue(dia(p.fecha), p.valor),
                ],
                color: acentoPdf,
                pointColor: acentoPdf,
                pointSize: 2.5,
                lineWidth: 1.5,
              ),
            ],
          ),
        ),
      ],
    );
  }

  final cambios = <String>[
    for (final (nombre, unidad, valor, d)
        in <(String, String, double? Function(Medicion), int?)>[
          ('Peso', 'kg', (m) => m.peso, null),
          ('IMC', '', (m) => m.imc, 1),
          ('Cintura', 'cm', (m) => m.cintura, null),
          ('ICC', '', (m) => m.icc, 2),
        ])
      if (cambioEn(ms, valor) case final c?)
        '$nombre ${_n(c.primera, d)} → ${_n(c.ultima, d)}'
            '${unidad.isEmpty ? '' : ' $unidad'} '
            '(${c.porcentaje > 0 ? '+' : ''}${formatoNumero(c.porcentaje, decimales: 1)} %)',
  ];

  final graficas = [
    ?grafica('Peso', 'kg', (m) => m.peso),
    ?grafica('IMC', 'kg/m²', (m) => m.imc),
    ?grafica('Cintura', 'cm', (m) => m.cintura),
  ];

  final doc = pw.Document(
    title: 'Informe de seguimiento · ${paciente.nombre}',
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
              pw.SizedBox(height: 36, child: pw.Image(logo)),
          ],
        ),
      ),
      footer: (context) => pw.Text(
        'historiasclinicas.net · Informe de seguimiento · generado el '
        '${formatoFechaHora(ahora)} · Pág. ${context.pageNumber} de '
        '${context.pagesCount}',
        style: estilo(tamano: 7, color: grisPdf),
      ),
      build: (context) => [
        pw.Text(
          'INFORME DE SEGUIMIENTO',
          style: estilo(tamano: 13, fuente: f.negrita, color: acentoPdf),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: lineaPdf, width: 0.6),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  paciente.nombre,
                  style: estilo(fuente: f.seminegrita, tamano: 10),
                ),
              ),
              pw.Text(
                [
                  if (paciente.documento.isNotEmpty) paciente.documento,
                  if (paciente.edad != null) '${paciente.edad} años',
                  ?paciente.sexo,
                ].join(' · '),
                style: estilo(),
              ),
            ],
          ),
        ),
        if (ms.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5),
            child: pw.Text(
              'Del ${formatoFecha(ms.first.fecha)} al '
              '${formatoFecha(ms.last.fecha)} · ${ms.length} mediciones',
              style: estilo(color: grisPdf),
            ),
          ),
        if (cambios.isNotEmpty) ...[
          titulo('Cambios'),
          pw.Text(cambios.join('   ·   '), style: estilo()),
        ],
        if (graficas.isNotEmpty) ...[
          titulo('Gráficas'),
          for (final g in graficas) ...[g, pw.SizedBox(height: 8)],
        ],
        titulo('Mediciones'),
        if (ms.isEmpty)
          pw.Text('Sin mediciones.', style: estilo(color: grisPdf))
        else
          pw.TableHelper.fromTextArray(
            headers: [
              'Fecha',
              'Peso',
              'Talla',
              'IMC',
              'Cintura',
              'Cadera',
              'ICC',
              'PA',
              '% grasa',
            ],
            data: [
              for (final m in ms)
                [
                  formatoFecha(m.fecha),
                  _n(m.peso),
                  _n(m.talla),
                  _n(m.imc, 1),
                  _n(m.cintura),
                  _n(m.cadera),
                  _n(m.icc, 2),
                  m.paSistolica == null || m.paDiastolica == null
                      ? '—'
                      : '${_n(m.paSistolica)}/${_n(m.paDiastolica)}',
                  _n(m.grasa),
                ],
            ],
            headerStyle: estilo(tamano: 7.5, fuente: f.seminegrita),
            cellStyle: estilo(tamano: 7.5),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFEDF2F5),
            ),
            border: pw.TableBorder.all(color: lineaPdf, width: 0.4),
            cellAlignment: pw.Alignment.centerRight,
            cellAlignments: {0: pw.Alignment.centerLeft},
          ),
        ..._fotos(fotos, estilo, encabezado: titulo('Fotos')),
        pw.SizedBox(height: 22),
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

/// PDF con las fotos del paciente (pregunta 23: solo si se pide).
Future<Uint8List> generarPdfFotos({
  required PacienteInforme paciente,
  required List<FotoConBytes> fotos,
  Autor? medico,
  FuentesPdf? fuentes,
  DateTime? generadoEn,
}) async {
  final f = fuentes ?? await FuentesPdf.cargar();
  final ahora = generadoEn ?? DateTime.now();
  pw.TextStyle estilo({double tamano = 9, pw.Font? fuente, PdfColor? color}) =>
      pw.TextStyle(font: fuente ?? f.regular, fontSize: tamano, color: color);
  final doc = pw.Document(
    title: 'Fotos · ${paciente.nombre}',
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
      footer: (context) => pw.Text(
        'historiasclinicas.net · Fotos clínicas, uso reservado · '
        '${formatoFechaHora(ahora)} · Pág. ${context.pageNumber} de '
        '${context.pagesCount}',
        style: estilo(tamano: 7, color: grisPdf),
      ),
      build: (context) => [
        pw.Text(
          'FOTOS CLÍNICAS · ${paciente.nombre}',
          style: estilo(tamano: 12, fuente: f.negrita, color: acentoPdf),
        ),
        if (paciente.documento.isNotEmpty)
          pw.Text(paciente.documento, style: estilo(color: grisPdf)),
        pw.SizedBox(height: 10),
        ..._fotos(fotos, estilo),
      ],
    ),
  );
  return doc.save();
}

/// Las fotos en filas de tres; cada fila pasa entera de página y el
/// [encabezado] (si lo hay) va pegado a la primera.
List<pw.Widget> _fotos(
  List<FotoConBytes> fotos,
  pw.TextStyle Function({double tamano, pw.Font? fuente, PdfColor? color})
  estilo, {
  pw.Widget? encabezado,
}) {
  pw.Widget celda(FotoConBytes x) => pw.SizedBox(
    width: 160,
    child: pw.Column(
      children: [
        pw.SizedBox(
          height: 200,
          child: pw.Image(pw.MemoryImage(x.bytes), fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          '${x.foto.titulo} · ${formatoFecha(x.foto.fecha)}',
          style: estilo(tamano: 7.5),
        ),
      ],
    ),
  );
  final filas = <pw.Widget>[
    for (var i = 0; i < fotos.length; i += 3)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final x in fotos.skip(i).take(3)) ...[
              celda(x),
              pw.SizedBox(width: 10),
            ],
          ],
        ),
      ),
  ];
  if (encabezado == null || filas.isEmpty) return filas;
  return [
    pw.Inseparable(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [encabezado, filas.first],
      ),
    ),
    ...filas.skip(1),
  ];
}

/// Marcas redondas para un eje de [minimo] a [maximo] (paso 1, 2 o 5 por
/// una potencia de 10, entre 3 y 6 marcas), con los decimales que pide el
/// paso.
({List<double> marcas, int decimales}) marcasEje(double minimo, double maximo) {
  var rango = maximo - minimo;
  if (rango <= 0) rango = math.max(minimo.abs() * 0.1, 1);
  final bruto = rango / 4;
  final potencia = math
      .pow(10, (math.log(bruto) / math.ln10).floor())
      .toDouble();
  final paso = [
    1,
    2,
    5,
    10,
  ].map((k) => k * potencia).firstWhere((p) => rango / p <= 5);
  // Un poco de aire para que los puntos no queden sobre el borde.
  final desde = ((minimo - rango * 0.08) / paso).floor() * paso;
  var hasta = ((maximo + rango * 0.08) / paso).ceil() * paso;
  if (hasta <= desde) hasta = desde + paso;
  final n = ((hasta - desde) / paso).round();
  final decimales = paso >= 1 ? 0 : (-(math.log(paso) / math.ln10).floor());
  return (
    marcas: [for (var i = 0; i <= n; i++) desde + i * paso],
    decimales: decimales,
  );
}

String _fechaCorta(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';
