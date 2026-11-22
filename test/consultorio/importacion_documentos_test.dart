import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/documento.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/documento_clinico.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/documento_pdf.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/documentos.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/plantillas.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/receta_json.dart';
import 'package:historiasclinicas_net/core/consultorio/indice/indice_pacientes.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/configuracion.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/integridad/json_canonico.dart';
import 'package:historiasclinicas_net/core/models/medico.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/adjuntos_pdf.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/pdf/receta_pdf.dart';
import 'package:historiasclinicas_net/core/receta/receta.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

const _config = ConfiguracionConsultorio(nit: '900', codigoReps: '196');

/// Un consultorio con la historia sintética registrada; devuelve el id de
/// su ficha.
Future<(BancoConsultorio, String)> _consultorio() async {
  final b = BancoConsultorio();
  await b.servicio.crear(fraseDePrueba);
  final r = await b.servicio.registrarHistoria(
    HistoriaPendiente(
      datos: historiaSintetica(),
      revision: 1,
      origen: OrigenArchivo.importado,
    ),
  );
  return (b, r!.pacienteId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FuentesPdf fuentes;
  setUpAll(() async => fuentes = await FuentesPdf.cargar());

  Future<DocumentoFirmado> emitir(
    BancoConsultorio b,
    String id,
    TipoPlantilla tipo, {
    String finalidad = 'Empresa de prueba',
  }) async {
    final docs = b.servicio.documentos;
    final plantilla = docs.plantillasDe(tipo).first;
    if (!plantilla.usable) await docs.aprobarDe(plantilla.id);
    final ficha = b.servicio.indice.ficha(id)!;
    var borrador = docs.nuevoBorrador(
      tipo,
      ficha: ficha,
      medico: medicoCompleto(),
    );
    borrador = switch (tipo) {
      TipoPlantilla.certificado => borrador.copyWith(finalidad: finalidad),
      TipoPlantilla.incapacidad => borrador.copyWith(
        diagnostico: const DiagnosticoDocumento(
          codigo: 'A09X',
          descripcion: 'Diarrea',
        ),
        dias: 2,
      ),
      _ => borrador,
    };
    return docs.emitirDocumento(
      borrador,
      ficha: ficha,
      medico: medicoCompleto(),
      pais: Pais.colombia,
      configuracion: _config,
      fuentes: fuentes,
    );
  }

  test('reabrir un documento del consultorio: ya estaba, íntegro', () async {
    final (b, id) = await _consultorio();
    final ce = await emitir(b, id, TipoPlantilla.certificado);
    final r = await b.servicio.importarArchivos([
      (nombre: 'Certificado.pdf', bytes: ce.pdf),
    ]);
    expect(r.single.tipo, TipoImportacion.registrada);
    expect(r.single.mensaje, 'Ya estaba, íntegro · CE-000001');
    expect(r.single.pacienteId, id);
    expect(b.servicio.documentos.documentosDe(id), hasLength(1));
  });

  test('en otro equipo: se liga a la ficha del mismo documento y el '
      'consecutivo no se repite', () async {
    final (a, idA) = await _consultorio();
    final ce = await emitir(a, idA, TipoPlantilla.certificado);
    final inc = await emitir(a, idA, TipoPlantilla.incapacidad);

    // El otro equipo tiene al mismo paciente con otra ficha (otro id).
    final b = BancoConsultorio();
    await b.servicio.crear(fraseDePrueba);
    final r0 = await b.servicio.registrarHistoria(
      HistoriaPendiente(
        datos: historiaSintetica(id: 'otra-historia'),
        revision: 1,
        origen: OrigenArchivo.importado,
      ),
    );
    final idB = r0!.pacienteId;
    expect(idB, isNot(idA));

    final r = await b.servicio.importarArchivos([
      (nombre: 'Certificado.pdf', bytes: ce.pdf),
      (nombre: 'Incapacidad.pdf', bytes: inc.pdf),
    ]);
    expect(r.map((x) => x.mensaje), [
      'Documento nuevo · CE-000001',
      'Documento nuevo · IN-000001',
    ]);
    final docs = b.servicio.documentos.documentosDe(idB);
    expect(docs.map((d) => d.numero), containsAll(['CE-000001', 'IN-000001']));
    final importado = docs.firstWhere((d) => d.numero == 'CE-000001');
    expect(importado.hash, ce.documento.hash, reason: 'lo sellado no cambia');
    expect(importado.fichaEfectiva, idB);
    expect(await b.servicio.documentos.pdfDe(importado.id), ce.pdf);
    expect(
      await b.servicio.documentos.proximoNumero(TipoPlantilla.certificado),
      'CE-000002',
    );

    // Sigue ahí al volver a abrir el consultorio.
    await b.servicio.bloquear();
    await b.servicio.desbloquear(fraseDePrueba);
    expect(b.servicio.documentos.documentosDe(idB), hasLength(2));
  });

  test(
    'alterado, otro con el mismo número o sin ficha: no se importa',
    () async {
      final (a, idA) = await _consultorio();
      final ce = await emitir(a, idA, TipoPlantilla.certificado);

      // documento.json con lo sellado cambiado y la huella vieja.
      final datos = {...ce.documento.datos, 'contenido': 'Texto cambiado'};
      final alterado = await generarPdfDocumento(
        ContenidoDocumentoPdf(
          titulo: 'Certificado médico',
          cuerpo: 'Texto cambiado',
          fechaHora: DateTime(2026, 11, 21),
          adjuntos: [
            AdjuntoPdf(
              nombreAdjuntoDocumento,
              jsonCanonico({
                'aplicacion': 'historiasclinicas.net',
                'documento': datos,
                'sha256': ce.documento.hash,
              }),
            ),
          ],
        ),
        fuentes: fuentes,
      );

      // Otro consultorio con su propio CE-000001 (otra finalidad).
      final (b, idB) = await _consultorio();
      await emitir(b, idB, TipoPlantilla.certificado, finalidad: 'Colegio');

      // Un tercero sin el paciente.
      final c = BancoConsultorio();
      await c.servicio.crear(fraseDePrueba);

      final rb = await b.servicio.importarArchivos([
        (nombre: 'alterado.pdf', bytes: alterado),
        (nombre: 'Certificado.pdf', bytes: ce.pdf),
      ]);
      expect(rb.map((x) => x.tipo), [
        TipoImportacion.rechazada,
        TipoImportacion.rechazada,
      ]);
      expect(rb[0].mensaje, contains('no coinciden con su huella'));
      expect(rb[1].mensaje, contains('Ya hay un CE-000001 distinto'));
      expect(rb.where((x) => x.importada), isEmpty);
      expect(b.servicio.documentos.documentosDe(idB), hasLength(1));

      final rc = await c.servicio.importarArchivos([
        (nombre: 'Certificado.pdf', bytes: ce.pdf),
      ]);
      expect(rc.single.tipo, TipoImportacion.sinFicha);
      expect(rc.single.mensaje, contains('PEÑA'));
    },
  );

  test('recetas con receta.json: nueva y luego ya estaba', () async {
    final (b, id) = await _consultorio();
    final copia = instantaneaMedico(medicoEjemplo(), pais: Pais.colombia);
    final documento = DocumentoReceta(
      receta: Receta(
        id: 'receta-1',
        historiaId: '6f1c2b9e-0000-4000-8000-000000000001',
        fecha: DateTime(2026, 10, 2, 9, 30),
        numero: 'R-000123',
        items: const [
          ItemReceta(
            id: 'i1',
            medicamento: 'Metformina',
            concentracion: '850 mg',
            dosis: '1 tableta',
            frecuencia: 'cada 12 horas',
          ),
        ],
      ),
      paciente: PacienteReceta.deHistoria(historiaCompleta()),
      pais: Pais.colombia,
      medico: Autor.desdeMapa(copia.autor),
      recursos: copia.recursos,
    );
    final pdf = await generarPdfReceta(
      documento,
      fuentes: fuentes,
      adjuntos: adjuntosReceta(documento),
    );
    final r = await b.servicio.importarArchivos([
      (nombre: 'Receta_PENA.pdf', bytes: pdf),
      (nombre: 'Receta_PENA (copia).pdf', bytes: pdf),
    ]);
    expect(r.map((x) => x.mensaje), [
      'Receta nueva · Receta R-000123',
      'Ya estaba · Receta R-000123',
    ]);
    final receta = b.servicio.indice.recetasDe(id).single;
    expect(receta.numero, 'R-000123');
    expect(receta.items.single, contains('METFORMINA'));
    expect(await b.servicio.indice.pdfReceta('receta-1'), pdf);
  });

  test('lote mezclado: historias, documentos, recetas y ajenos', () async {
    final (a, idA) = await _consultorio();
    final ce = await emitir(a, idA, TipoPlantilla.certificado);
    final b = BancoConsultorio();
    await b.servicio.crear(fraseDePrueba);
    final historia = await pdfCon(historiaSintetica());
    final avances = <int>[];
    final r = await b.servicio.importarArchivos([
      (nombre: 'Certificado.pdf', bytes: ce.pdf),
      (nombre: 'Historia.pdf', bytes: historia),
      (nombre: 'Certificado (otra vez).pdf', bytes: ce.pdf),
      (nombre: 'nota.txt', bytes: Uint8List.fromList([104, 111, 108, 97])),
    ], alAvanzar: (hechos, _) => avances.add(hechos));
    expect(avances, [1, 2, 3, 4]);
    expect(r.map((x) => x.tipo), [
      // Sin la historia todavía, el certificado no tiene ficha.
      TipoImportacion.sinFicha,
      TipoImportacion.registrada,
      TipoImportacion.registrada,
      TipoImportacion.noEsDeLaApp,
    ]);
    expect(r[2].mensaje, 'Documento nuevo · CE-000001');
    final entrada = (await b.servicio.bitacora()).firstWhere(
      (e) => e.accion == AccionBitacora.importarPdf,
    );
    expect(entrada.resumen, '2 de 4 archivos');
    expect(contieneTexto(b.todosLosBytes, 'Empresa de prueba'), isFalse);
  });

  test('el estado del documento no viaja: uno anulado se reimporta vigente '
      'solo en otro equipo', () async {
    final (a, idA) = await _consultorio();
    final or = await emitir(a, idA, TipoPlantilla.orden);
    await a.servicio.documentos.cambiarEstado(
      or.documento.id,
      EstadoDocumento.anulado,
      motivo: 'Error',
    );
    final r = await a.servicio.importarArchivos([
      (nombre: 'Orden.pdf', bytes: or.pdf),
    ]);
    expect(r.single.mensaje, 'Ya estaba, íntegro · OR-000001');
    expect(
      a.servicio.documentos.documento(or.documento.id)!.estado,
      EstadoDocumento.anulado,
      reason: 'reimportarlo no lo revive',
    );
  });
}
