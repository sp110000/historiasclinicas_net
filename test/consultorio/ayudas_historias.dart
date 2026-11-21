import 'dart:convert';
import 'dart:typed_data';

import 'package:historiasclinicas_net/core/integridad/cadena_hash.dart';
import 'package:historiasclinicas_net/core/models/evolucion.dart';
import 'package:historiasclinicas_net/core/models/medico.dart';
import 'package:historiasclinicas_net/core/pdf/adjunto_historia.dart';
import 'package:pdf/widgets.dart' as pw;

import '../ejemplos.dart';

/// Datos sellados de una historia sintética.
Map<String, Object?> historiaSintetica({
  String id = '6f1c2b9e-0000-4000-8000-000000000001',
  String tipoDocumento = 'CC',
  String numeroDocumento = '1032456789',
  String primerApellido = 'Peña',
  String nombres = 'José Ángel',
  String telefono = '300 123 4567',
  DateTime? fecha,
  DateTime? proximoControl,
  List<Evolucion> evoluciones = const [],
}) {
  final base = historiaCompleta();
  final h = base.copyWith(
    fechaAtencion: fecha ?? DateTime(2026, 10, 2, 9, 14),
    paciente: base.paciente.copyWith(
      tipoDocumento: tipoDocumento,
      numeroDocumento: numeroDocumento,
      primerApellido: primerApellido,
      nombres: nombres,
      telefono: telefono,
    ),
    plan: base.plan.copyWith(proximoControl: proximoControl),
  );
  var datos = sellarBase({
    ...h.aMapa(),
    'id': id,
    'finalizadaEn': '2026-10-02T09:40',
  });
  if (evoluciones.isNotEmpty) {
    datos = sellarEvoluciones(datos, [for (final e in evoluciones) e.aMapa()]);
  }
  return datos;
}

/// PDF mínimo con la historia incrustada (sin el documento completo: el
/// índice solo lee el adjunto).
Future<Uint8List> pdfCon(Map<String, Object?> datos, {int revision = 1}) {
  final doc = pw.Document()..addPage(pw.Page(build: (_) => pw.Text('x')));
  incrustarHistoria(
    doc,
    PaqueteHistoria(
      revision: revision,
      guardadoEn: DateTime(2026, 10, 2, 9, 40),
      datos: datos,
    ),
  );
  return doc.save();
}

/// PNG mínimo válido (1 × 1) como firma del paciente.
final firmaDePrueba = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Médico con todos los datos que piden los documentos.
Medico medicoCompleto() => Medico(
  nombre: 'Dra. Ana Pérez Gómez',
  registro: 'RM 54321',
  tipoDocumento: 'CC',
  documento: '52111222',
  consultorio: 'Consultorio Salud Plena',
  direccion: 'Calle 5 # 10-20',
  ciudad: 'Santander de Quilichao',
  telefono: '602 555 0101',
  correo: 'consultorio@ejemplo.invalid',
  firma: pngFirma,
  sello: pngSello,
);
