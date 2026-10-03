/// Piezas comunes a los PDF de la historia y de la receta: imágenes del
/// médico, datos del encabezado y bloque de firma.
library;

import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/medico.dart';
import 'fuentes_pdf.dart';

/// Gris de los textos secundarios (se imprime bien en blanco y negro).
const grisPdf = PdfColor.fromInt(0xFF4A5763);

/// Acento petróleo de los números de sección, el único color del PDF: en
/// una impresora en blanco y negro sale gris oscuro.
const acentoPdf = PdfColor.fromInt(0xFF1E5A7A);

/// Líneas finas.
const lineaPdf = PdfColor.fromInt(0xFFB9C3CA);

/// Imágenes de `recursos` (SHA-256 → PNG en base64). Cada una se carga una
/// sola vez, así el PDF la guarda una vez aunque se dibuje en varias
/// páginas.
class ImagenesPdf {
  ImagenesPdf(this._recursos);

  final Map<String, Object?> _recursos;
  final _cache = <String, pw.MemoryImage>{};

  pw.MemoryImage? call(String? hash) {
    if (hash == null) return null;
    final b64 = _recursos[hash];
    if (b64 is! String) return null;
    return _cache[hash] ??= pw.MemoryImage(base64Decode(b64));
  }
}

/// Nombre, especialidad · registro y datos del consultorio.
pw.Widget datosMedicoPdf(
  FuentesPdf f,
  Autor medico, {
  double tamanoNombre = 11,
  double tamanoDetalle = 8,
}) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      medico.nombre,
      style: pw.TextStyle(font: f.negrita, fontSize: tamanoNombre),
    ),
    pw.Text(
      [
        medico.especialidad,
        medico.lineaRegistro,
      ].where((t) => t.isNotEmpty).join(' · '),
      style: pw.TextStyle(
        font: f.media,
        fontSize: tamanoDetalle,
        color: grisPdf,
      ),
    ),
    pw.Text(
      [
        medico.consultorio,
        medico.direccion,
        medico.ciudad,
        if (medico.telefono.isNotEmpty) 'Tel. ${medico.telefono}',
        medico.correo,
      ].where((t) => t.isNotEmpty).join(' · '),
      style: pw.TextStyle(fontSize: tamanoDetalle - 0.5, color: grisPdf),
    ),
  ],
);

/// Firma y sello (en posición fija) sobre la línea, con nombre y registro.
/// Sin [autor] queda la línea con "Firma y sello del médico".
pw.Widget bloqueFirmaPdf(
  FuentesPdf f,
  Autor? autor,
  ImagenesPdf imagenes, {
  required double alto,
  double? ancho,
}) {
  final sello = imagenes(autor?.sello);
  final firma = imagenes(autor?.firma);
  final grande = alto >= 50;
  return pw.Container(
    width: ancho ?? (grande ? 220 : 170),
    child: pw.Column(
      children: [
        pw.SizedBox(
          height: alto,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (sello != null)
                pw.Container(
                  width: alto * 1.15,
                  height: alto,
                  child: pw.Image(sello, fit: pw.BoxFit.contain),
                ),
              if (sello != null && firma != null) pw.SizedBox(width: 4),
              if (firma != null)
                pw.Container(
                  width: alto * 2.2,
                  height: alto * 0.82,
                  child: pw.Image(firma, fit: pw.BoxFit.contain),
                ),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.only(top: 3),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(width: 0.7)),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                autor?.nombre ?? 'Firma y sello del médico',
                textAlign: pw.TextAlign.center,
                style: autor == null
                    ? pw.TextStyle(fontSize: 8, color: grisPdf)
                    : pw.TextStyle(
                        font: f.seminegrita,
                        fontSize: grande ? 8.5 : 7.5,
                      ),
              ),
              if ((autor?.lineaRegistro ?? '').isNotEmpty)
                pw.Text(
                  autor!.lineaRegistro,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: grande ? 7.5 : 6.8,
                    color: grisPdf,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// `true` si [texto] cabe holgadamente en un bloque de [ancho] puntos que no
/// se parte entre páginas (unas 30 líneas a 9,5 pt). Si no, debe imprimirse
/// como texto suelto, que sí continúa en la página siguiente.
bool cabeEnBloque(String texto, double ancho, {int maxLineas = 30}) {
  final porLinea = (ancho / 4.9).floor().clamp(10, 1000);
  var lineas = 0;
  for (final parrafo in texto.split('\n')) {
    lineas += (parrafo.length / porLinea).ceil().clamp(1, 1 << 20);
    if (lineas > maxLineas) return false;
  }
  return true;
}

/// Texto que continúa en la página siguiente si no cabe.
pw.Widget textoLargo(String texto, pw.TextStyle estilo) =>
    pw.Text(texto, style: estilo, overflow: pw.TextOverflow.span);
