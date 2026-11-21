import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/documento.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/plantillas.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/receta_json.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/models/medico.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/pdf/lector_adjunto.dart';
import 'package:historiasclinicas_net/core/pdf/receta_pdf.dart';
import 'package:historiasclinicas_net/core/receta/receta.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

/// Texto de un PDF con pdftotext, o `null` si no está instalado.
String? textoPdf(Uint8List pdf) {
  final dir = Directory.systemTemp.createTempSync('doc');
  try {
    final ruta = '${dir.path}/d.pdf';
    File(ruta).writeAsBytesSync(pdf);
    return Process.runSync('pdftotext', [ruta, '-']).stdout as String;
  } on ProcessException {
    return null;
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FuentesPdf fuentes;
  setUpAll(() async => fuentes = await FuentesPdf.cargar());

  group('Plantillas versionadas', () {
    test('la de fábrica es un borrador que no se puede usar', () {
      final p = Plantilla.base(TipoPlantilla.autorizacionDatos);
      expect(p.versiones.single.version, 1);
      expect(p.usable, isFalse);
      expect(p.borrador, isNotNull);
      expect(p.ultima.cuerpo, contains('{{paciente}}'));
      expect(p.ultima.cuerpo, contains('Superintendencia de Industria'));
    });

    test('editar una aprobada crea la versión siguiente en borrador', () {
      final ahora = DateTime(2026, 11, 21, 10);
      var p = Plantilla.base(TipoPlantilla.autorizacionDatos)
          .conBorrador('Autorización', 'Texto 1')
          .conBorrador('Autorización', 'Texto 1b');
      expect(p.versiones, hasLength(1), reason: 'reemplaza el borrador');
      p = p.aprobada(ahora);
      expect(p.vigente!.version, 1);
      expect(p.vigente!.cuerpo, 'Texto 1b');
      expect(() => p.aprobada(ahora), throwsStateError);

      p = p.conBorrador('Autorización', 'Texto 2');
      expect(p.versiones.map((v) => v.version), [1, 2]);
      expect(p.vigente!.version, 1, reason: 'la v1 sigue en uso');
      expect(p.borrador!.version, 2);
      p = p.aprobada(ahora.add(const Duration(days: 1)));
      expect(p.vigente!.cuerpo, 'Texto 2');
      expect(Plantilla.desdeMapa(p.id, p.aMapa()).aMapa(), p.aMapa());
    });

    test('marcadores: los vacíos quedan para completar a mano', () {
      expect(
        rellenarPlantilla(
          'Yo, {{paciente}} ({{ documentoPaciente }}), '
          'autorizo a {{responsable}}.',
          {'paciente': 'PEÑA, José', 'documentoPaciente': 'CC 1'},
        ),
        'Yo, PEÑA, José (CC 1), autorizo a ______.',
      );
    });
  });

  group('Autorización de tratamiento de datos', () {
    late BancoConsultorio b;
    late String pacienteId;

    setUp(() async {
      b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      final r = await b.servicio.registrarHistoria(
        HistoriaPendiente(
          datos: historiaSintetica(),
          revision: 1,
          origen: OrigenArchivo.importado,
        ),
      );
      pacienteId = r!.pacienteId;
    });

    Future<({DocumentoConsultorio documento, Uint8List pdf})> firmar() =>
        b.servicio.documentos.firmarAutorizacion(
          ficha: b.servicio.indice.ficha(pacienteId)!,
          firmaPng: firmaDePrueba,
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        );

    test('sin aprobar la plantilla no se puede firmar', () async {
      expect(firmar, throwsStateError);
      expect(b.servicio.indice.ficha(pacienteId)!.autorizacionDatosId, isNull);
    });

    test(
      'firmada: número, ficha, PDF con documento.json y todo cifrado',
      () async {
        await b.servicio.documentos.aprobar(TipoPlantilla.autorizacionDatos);
        final r = await firmar();
        final d = r.documento;

        expect(d.numero, 'AD-000001');
        expect(d.versionPlantilla, 1);
        expect(d.pacienteId, pacienteId);
        expect(d.contenido, startsWith('Yo, PEÑA MUÑOZ, José Ángel'));
        expect(d.contenido, contains('CC 1032456789'));
        expect(d.contenido, contains('Dra. Ana Pérez Gómez'));
        expect(d.contenido, contains('consultorio@ejemplo.invalid'));
        expect(d.contenido, isNot(contains('{{')));
        expect(d.sha256Firma, sha256.convert(firmaDePrueba).toString());
        expect(b.servicio.indice.ficha(pacienteId)!.autorizacionDatosId, d.id);
        expect(b.servicio.documentos.documentosDe(pacienteId).single.id, d.id);
        expect(await b.servicio.documentos.pdfDe(d.id), r.pdf);

        // documento.json incrustado, con su huella; la historia no lo
        // confunde con una historia.
        final adjuntos = adjuntosConMarca(r.pdf, marcaAdjuntoConsultorio);
        expect(adjuntos, hasLength(1));
        expect(leerDocumentoJson(adjuntos.single), d.datos);
        expect(
          () => leerHistoriaDePdf(r.pdf),
          throwsA(
            isA<LecturaHistoriaException>().having(
              (e) => e.fallo,
              'fallo',
              FalloLectura.sinDatosDeLaApp,
            ),
          ),
        );

        final texto = textoPdf(r.pdf);
        if (texto != null) {
          expect(texto, contains('AUTORIZACIÓN DE TRATAMIENTO DE DATOS'));
          expect(texto, contains('AD-000001'));
          expect(texto, contains('Firma del paciente'));
        }

        await b.servicio.repositorio.esperarEscrituras();
        expect(contieneTexto(b.todosLosBytes, 'autorizo de manera'), isFalse);
        expect(contieneTexto(b.todosLosBytes, 'AD-000001'), isFalse);

        final bitacora = await b.servicio.bitacora();
        expect(
          bitacora.map((e) => e.accion),
          containsAll([
            AccionBitacora.aprobarPlantilla,
            AccionBitacora.firmarDocumento,
          ]),
        );
        // La bitácora no guarda datos del paciente.
        expect(
          bitacora.map((e) => e.resumen).join(' '),
          isNot(contains('PEÑA')),
        );
      },
    );

    test(
      'revocar deja la ficha sin autorización y el número no se reutiliza',
      () async {
        await b.servicio.documentos.aprobar(TipoPlantilla.autorizacionDatos);
        final primera = (await firmar()).documento;
        expect(
          () => b.servicio.documentos.cambiarEstado(
            primera.id,
            EstadoDocumento.revocado,
            motivo: ' ',
          ),
          throwsStateError,
        );
        await b.servicio.documentos.cambiarEstado(
          primera.id,
          EstadoDocumento.revocado,
          motivo: 'El paciente la retiró por escrito',
        );
        expect(
          b.servicio.indice.ficha(pacienteId)!.autorizacionDatosId,
          isNull,
        );
        final revocada = b.servicio.documentos.documento(primera.id)!;
        expect(revocada.estado, EstadoDocumento.revocado);
        expect(revocada.motivoEstado, 'El paciente la retiró por escrito');
        // Lo sellado no cambia.
        expect(revocada.hash, primera.hash);

        final segunda = (await firmar()).documento;
        expect(segunda.numero, 'AD-000002');
        await b.servicio.documentos.cambiarEstado(
          segunda.id,
          EstadoDocumento.anulado,
          motivo: 'Paciente equivocado',
        );
        expect((await firmar()).documento.numero, 'AD-000003');
      },
    );

    test('al bloquear y abrir se recargan plantillas y documentos', () async {
      await b.servicio.documentos.aprobar(TipoPlantilla.autorizacionDatos);
      final d = (await firmar()).documento;
      await b.servicio.bloquear();
      expect(b.servicio.documentos.documentosDe(pacienteId), isEmpty);
      await b.servicio.desbloquear(fraseDePrueba);
      expect(
        b.servicio.documentos.plantilla(TipoPlantilla.autorizacionDatos).usable,
        isTrue,
      );
      expect(b.servicio.documentos.documento(d.id)!.hash, d.hash);
    });

    test('la política sale en PDF solo aprobada', () async {
      Future<Uint8List> politica() => b.servicio.documentos.politicaPdf(
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      expect(politica, throwsStateError);
      await b.servicio.documentos.aprobar(TipoPlantilla.politicaPrivacidad);
      final pdf = await politica();
      expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
      final texto = textoPdf(pdf);
      if (texto != null) {
        expect(texto, contains('POLÍTICA DE TRATAMIENTO DE DATOS PERSONALES'));
        expect(texto, contains('consultorio@ejemplo.invalid'));
        expect(texto, contains('versión 1'));
      }
    });
  });

  group('Receta con receta.json', () {
    final copia = instantaneaMedico(medicoEjemplo(), pais: Pais.colombia);
    final documento = DocumentoReceta(
      receta: Receta(
        id: 'r1',
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

    test('sin adjuntos el PDF no lleva archivos incrustados', () async {
      final pdf = await generarPdfReceta(documento, fuentes: fuentes);
      expect(latin1.decode(pdf), isNot(contains('/EmbeddedFiles')));
    });

    test('con la bandera lleva receta.json verificable', () async {
      final pdf = await generarPdfReceta(
        documento,
        fuentes: fuentes,
        adjuntos: adjuntosReceta(documento),
      );
      final adjuntos = adjuntosConMarca(pdf, marcaAdjuntoConsultorio);
      final datos = leerRecetaJson(adjuntos.single)!;
      expect((datos['receta']! as Map)['numero'], 'R-000123');
      expect(
        ((datos['receta']! as Map)['items']! as List).single,
        containsPair('medicamento', 'Metformina'),
      );
      expect((datos['paciente']! as Map)['documento'], contains('1032456789'));
      expect(
        () => leerHistoriaDePdf(pdf),
        throwsA(isA<LecturaHistoriaException>()),
      );
      // Alterado, no verifica.
      final alterado = utf8.encode(
        utf8.decode(adjuntos.single).replaceAll('Metformina', 'Insulina'),
      );
      expect(leerRecetaJson(alterado), isNull);
    });

    test('se registra en la ficha; bloqueado queda pendiente', () async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      final r = await b.servicio.registrarHistoria(
        HistoriaPendiente(
          datos: historiaSintetica(),
          revision: 1,
          origen: OrigenArchivo.importado,
        ),
      );
      final pdf = await generarPdfReceta(
        documento,
        fuentes: fuentes,
        adjuntos: adjuntosReceta(documento),
      );
      RecetaPendiente pendiente() => RecetaPendiente(
        recetaId: 'r1',
        paciente: historiaCompleta().paciente,
        fecha: documento.receta.fecha,
        bytesPdf: pdf,
        numero: 'R-000123',
        historiaId: documento.receta.historiaId,
        items: [for (final i in documento.receta.itemsConDatos) i.resumen],
        nombreArchivo: 'Receta_Pena.pdf',
      );

      await b.servicio.bloquear();
      expect(await b.servicio.registrarReceta(pendiente()), isNull);
      expect(b.servicio.recetasPendientes, 1);
      await b.servicio.desbloquear(fraseDePrueba);
      expect(b.servicio.recetasPendientes, 0);

      final recetas = b.servicio.indice.recetasDe(r!.pacienteId);
      expect(recetas.single.numero, 'R-000123');
      expect(recetas.single.items.single, startsWith('METFORMINA 850 mg'));
      expect(await b.servicio.indice.pdfReceta('r1'), pdf);

      // Reimpresa: no se duplica.
      expect(await b.servicio.registrarReceta(pendiente()), r.pacienteId);
      expect(b.servicio.indice.recetasDe(r.pacienteId), hasLength(1));
    });
  });
}
