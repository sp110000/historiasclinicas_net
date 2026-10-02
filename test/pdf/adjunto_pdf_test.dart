import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/integridad/json_canonico.dart';
import 'package:historiasclinicas_net/core/pdf/adjunto_historia.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/pdf/lector_adjunto.dart';
import 'package:historiasclinicas_net/features/poc/historia_poc.dart';
import 'package:historiasclinicas_net/features/poc/pdf_historia_poc.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FuentesPdf fuentes;
  setUpAll(() async => fuentes = await FuentesPdf.cargar());

  final guardado = DateTime(2026, 10, 2, 9, 20);
  HistoriaPoc ejemplo() => HistoriaPoc(
    id: '6f1c2b9e-0000-4000-8000-000000000001',
    creadaEn: DateTime(2026, 10, 2, 9, 14),
    primerApellido: 'Peña',
    segundoApellido: 'Muñoz',
    nombres: 'José Ángel',
    tipoDocumento: 'CC',
    numeroDocumento: '1032456789',
    motivoConsulta: 'Odinofagia y fiebre de 2 días. «ñ» 38,5 °C, SpO₂ 97 %.',
  );

  Future<Uint8List> generar(HistoriaPoc h, {int revision = 1}) =>
      generarPdfHistoriaPoc(
        h,
        revision: revision,
        guardadoEn: guardado,
        fuentes: fuentes,
      );

  LecturaHistoriaException fallo(Uint8List bytes) {
    try {
      leerHistoriaDePdf(bytes);
    } on LecturaHistoriaException catch (e) {
      return e;
    }
    fail('Se esperaba LecturaHistoriaException');
  }

  group('Ida y vuelta del JSON incrustado', () {
    test('el PDF generado declara el adjunto de forma estándar', () async {
      final texto = latin1.decode(await generar(ejemplo()));
      expect(texto, startsWith('%PDF-'));
      expect(texto, contains('/EmbeddedFiles'));
      expect(texto, contains('/AF'));
      expect(texto, contains('($nombreAdjuntoHistoria)'));
      expect(texto, contains(RegExp('/application#2[fF]json')));
    });

    test('se recuperan los mismos datos, con tildes y ñ', () async {
      final h = ejemplo();
      final paquete = leerHistoriaDePdf(await generar(h));

      expect(paquete.schemaVersion, schemaVersionActual);
      expect(paquete.revision, 1);
      expect(paquete.guardadoEn, guardado.toUtc());
      expect(jsonCanonico(paquete.datos), jsonCanonico(h.aMapa()));
      final leida = HistoriaPoc.desdeMapa(paquete.datos);
      expect(leida.nombreCompleto, 'PEÑA MUÑOZ, José Ángel');
      expect(leida.motivoConsulta, h.motivoConsulta);
    });

    test(
      'agregar una evolución y regenerar conserva todo lo anterior',
      () async {
        final v1 = leerHistoriaDePdf(await generar(ejemplo()));
        final abierta = HistoriaPoc.desdeMapa(v1.datos);
        final evolucion = EvolucionPoc(
          fechaHora: DateTime(2026, 10, 9, 10, 30),
          texto: 'Mejoría clínica. Afebril. Continúa manejo.',
        );

        final v2 = leerHistoriaDePdf(
          await generar(abierta.conEvoluciones([evolucion]), revision: 2),
        );
        final reabierta = HistoriaPoc.desdeMapa(v2.datos);

        expect(v2.revision, 2);
        expect(reabierta.evoluciones, hasLength(1));
        expect(reabierta.evoluciones.single.texto, evolucion.texto);
        expect(reabierta.evoluciones.single.fechaHora, evolucion.fechaHora);
        final sinEvoluciones = Map.of(v2.datos)..['evoluciones'] = [];
        expect(jsonCanonico(sinEvoluciones), jsonCanonico(v1.datos));
      },
    );

    test('datos arbitrarios: emoji, comillas y saltos de línea', () async {
      final datos = {
        'texto': 'Peña 😀 "cita" \\ barra\n\tnueva línea',
        'numeros': [72.0, 36.8, -1],
      };
      final doc = pw.Document(theme: fuentes.tema)
        ..addPage(pw.Page(build: (_) => pw.Text('x')));
      incrustarHistoria(
        doc,
        PaqueteHistoria(revision: 1, guardadoEn: guardado, datos: datos),
      );
      final paquete = leerHistoriaDePdf(await doc.save());
      expect(jsonCanonico(paquete.datos), jsonCanonico(datos));
    });

    test('con varias copias del adjunto gana la revisión mayor', () async {
      final v1 = await generar(ejemplo());
      final v3 = await generar(ejemplo(), revision: 3);
      // Simula actualizaciones incrementales añadidas al final del archivo.
      final juntos = Uint8List.fromList([...v3, 10, ...v1]);
      expect(leerHistoriaDePdf(juntos).revision, 3);
    });

    test('lee un PDF reescrito por otro programa (pikepdf/qpdf)', () {
      // Fixture: PDF de la app guardado de nuevo con pikepdf, con el adjunto
      // comprimido (FlateDecode) y los objetos en flujos de objetos.
      final bytes = File(
        'test/fixtures/historia_reescrita_pikepdf.pdf',
      ).readAsBytesSync();
      expect(latin1.decode(bytes), isNot(contains(identificadorApp)));

      final paquete = leerHistoriaDePdf(bytes);
      final h = HistoriaPoc.desdeMapa(paquete.datos);
      expect(paquete.revision, 2);
      expect(h.nombreCompleto, 'PEÑA MUÑOZ, José Ángel');
      expect(h.evoluciones.single.texto, 'Mejoría clínica, afebril.');
    });
  });

  group('Errores claros', () {
    test('un archivo que no es PDF', () {
      final e = fallo(Uint8List.fromList(utf8.encode('hola, no soy un PDF')));
      expect(e.fallo, FalloLectura.noEsPdf);
      expect(e.mensaje, contains('no es un PDF'));
    });

    test('un PDF sin datos de la app', () async {
      final doc = pw.Document(theme: fuentes.tema)
        ..addPage(pw.Page(build: (_) => pw.Text('Documento cualquiera')));
      final e = fallo(await doc.save());
      expect(e.fallo, FalloLectura.sinDatosDeLaApp);
      expect(e.mensaje, contains('Solo se pueden reabrir'));
    });

    test('un PDF truncado en medio del adjunto', () async {
      final bytes = await generar(ejemplo());
      final i = latin1.decode(bytes).indexOf('"app":"$identificadorApp"');
      expect(i, greaterThan(0));
      final e = fallo(Uint8List.sublistView(bytes, 0, i + 120));
      expect(e.fallo, FalloLectura.danado);
    });

    test(
      'un JSON modificado a mano no pasa la verificación del hash',
      () async {
        final bytes = await generar(ejemplo());
        final texto = latin1.decode(bytes);
        // Mismo tamaño: solo cambia una letra del apellido dentro del JSON
        // (en el JSON la ñ va escapada; `bs` es la barra invertida).
        const bs = '\\';
        const buscado = '"primerApellido":"Pe${bs}u00f1a"';
        final i = texto.indexOf(buscado);
        expect(i, greaterThan(0));
        final alterado = Uint8List.fromList(bytes);
        alterado[i + buscado.length - 2] = 'o'.codeUnitAt(0); // Peño

        final e = fallo(alterado);
        expect(e.fallo, FalloLectura.danado);
        expect(e.detalle, contains('hash'));
      },
    );

    test('un esquema más nuevo que la app', () async {
      final doc = pw.Document(theme: fuentes.tema)
        ..addPage(pw.Page(build: (_) => pw.Text('x')));
      incrustarHistoria(
        doc,
        PaqueteHistoria(
          schemaVersion: schemaVersionActual + 1,
          revision: 1,
          guardadoEn: guardado,
          datos: const {},
        ),
      );
      expect(fallo(await doc.save()).fallo, FalloLectura.versionNoSoportada);
    });
  });
}
