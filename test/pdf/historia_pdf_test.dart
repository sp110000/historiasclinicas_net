import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/integridad/cadena_hash.dart';
import 'package:historiasclinicas_net/core/integridad/json_canonico.dart';
import 'package:historiasclinicas_net/core/models/historia.dart';
import 'package:historiasclinicas_net/core/models/mapa.dart';
import 'package:historiasclinicas_net/core/models/medico.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/adjunto_historia.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/pdf/historia_pdf.dart';
import 'package:historiasclinicas_net/core/pdf/lector_adjunto.dart';
import 'package:pdf/widgets.dart' as pw;

import '../ejemplos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FuentesPdf fuentes;
  setUpAll(() async => fuentes = await FuentesPdf.cargar());

  final guardado = DateTime(2026, 10, 2, 9, 40);

  Map<String, Object?> sellada() => sellarBase({
    ...historiaCompleta().aMapa(),
    'finalizadaEn': '2026-10-02T09:40',
  });

  Future<Uint8List> pdf(
    Map<String, Object?> datos, {
    int revision = 1,
    bool borrador = false,
  }) => generarPdfHistoria(
    datos: datos,
    revision: revision,
    borrador: borrador,
    fuentes: fuentes,
    generadoEn: guardado,
  );

  LecturaHistoriaException fallo(Uint8List bytes) {
    try {
      leerHistoriaDePdf(bytes);
    } on LecturaHistoriaException catch (e) {
      return e;
    }
    fail('Se esperaba LecturaHistoriaException');
  }

  group('PDF de la historia con datos incrustados', () {
    test('declara el adjunto de forma estándar', () async {
      final texto = latin1.decode(await pdf(sellada()));
      expect(texto, startsWith('%PDF-'));
      expect(texto, contains('/EmbeddedFiles'));
      expect(texto, contains('($nombreAdjuntoHistoria)'));
      expect(texto, contains(RegExp('/application#2[fF]json')));
    });

    test(
      'ida y vuelta: los datos sellados vuelven intactos y verificables',
      () async {
        final datos = sellada();
        final paquete = leerHistoriaDePdf(await pdf(datos));
        expect(paquete.revision, 1);
        expect(jsonCanonico(paquete.datos), jsonCanonico(datos));
        expect(verificarIntegridad(paquete.datos).correcta, isTrue);
        final h = HistoriaClinica.desdeMapa(paquete.datos);
        expect(h.paciente.nombreCompleto, 'PEÑA MUÑOZ, José Ángel');
        expect(h.antecedentes.alergias, ['Penicilina', 'AINEs']);
      },
    );

    test('agregar evoluciones y regenerar conserva lo anterior', () async {
      final v1 = leerHistoriaDePdf(await pdf(sellada())).datos;
      final v2Datos = sellarEvoluciones(v1, [
        Evolucion(
          id: 'e1',
          fechaHora: DateTime(2026, 10, 9, 10, 30),
          texto: 'Afebril. Mejoría de la odinofagia.',
          signos: const SignosVitales(temperatura: 36.6, fc: 78),
        ).aMapa(),
      ]);
      final v2 = leerHistoriaDePdf(await pdf(v2Datos, revision: 2));
      expect(v2.revision, 2);
      expect(verificarIntegridad(v2.datos).sellos, 2);
      expect(verificarIntegridad(v2.datos).correcta, isTrue);
      final ev = Evolucion.desdeMapa(v2.datos.listaEvoluciones.single);
      expect(ev.texto, 'Afebril. Mejoría de la odinofagia.');
      expect(ev.signos.temperatura, 36.6);
      expect(v2.datos['hashBase'], v1['hashBase']);
    });

    test('muchas evoluciones: el PDF crece y sigue siendo legible', () async {
      var datos = sellada();
      datos = sellarEvoluciones(datos, [
        for (var i = 0; i < 60; i++)
          Evolucion(
            id: 'e$i',
            fechaHora: DateTime(2026, 10, 3).add(Duration(days: i)),
            texto: 'Control $i: paciente estable, sin cambios. ' * 4,
          ).aMapa(),
      ]);
      final bytes = await pdf(datos, revision: 61);
      final r = leerHistoriaDePdf(bytes);
      expect(verificarIntegridad(r.datos).sellos, 61);
    });

    test('con el médico: encabezado, firma y sello como imágenes', () async {
      final copia = instantaneaMedico(medicoEjemplo(), pais: Pais.colombia);
      final otro = instantaneaMedico(
        const Medico(nombre: 'Dr. Luis Mora', registro: 'RM 999'),
        pais: Pais.colombia,
      );
      final datos = sellarEvoluciones(
        sellarBase({
          ...historiaCompleta().aMapa(),
          'finalizadaEn': '2026-10-02T09:40',
          'medico': copia.autor,
          'recursos': copia.recursos,
        }),
        [
          {
            ...Evolucion(
              id: 'e1',
              fechaHora: DateTime(2026, 10, 9, 10, 30),
              texto: 'Afebril.',
            ).aMapa(),
            'autor': otro.autor,
          },
        ],
      );
      final bytes = await pdf(datos, revision: 2);
      final texto = latin1.decode(bytes);
      int contar(String patron) => RegExp(patron).allMatches(texto).length;
      // Logo, sello y firma de la historia (la evolución no tiene imágenes),
      // cada una con su máscara de transparencia.
      expect(contar(r'/SMask\s+\d+'), 3);
      expect(contar(r'/Subtype\s*/Image'), 6);
      final r = leerHistoriaDePdf(bytes);
      expect(verificarIntegridad(r.datos).correcta, isTrue);
      expect(Autor.desdeMapa(r.datos.mapa('medico')).nombre, contains('Ana'));

      final sinMedico = latin1.decode(await pdf(sellada()));
      expect(RegExp(r'/Subtype\s*/Image').hasMatch(sinMedico), isFalse);
    });

    test('la vista previa del borrador no se puede reabrir', () async {
      final bytes = await pdf(historiaCompleta().aMapa(), borrador: true);
      expect(fallo(bytes).fallo, FalloLectura.sinDatosDeLaApp);
    });

    test('lee un PDF reescrito por otro programa (pikepdf/qpdf)', () {
      // PDF de la app guardado de nuevo con pikepdf: adjunto comprimido
      // (FlateDecode) y objetos en flujos de objetos.
      final bytes = File(
        'test/fixtures/historia_reescrita_pikepdf.pdf',
      ).readAsBytesSync();
      expect(latin1.decode(bytes), isNot(contains(identificadorApp)));
      final r = leerHistoriaDePdf(bytes);
      expect(r.revision, 2);
      expect(verificarIntegridad(r.datos).correcta, isTrue);
      expect(
        Evolucion.desdeMapa(r.datos.listaEvoluciones.single).texto,
        'Mejoría clínica, afebril.',
      );
    });

    test('con varias copias del adjunto gana la revisión mayor', () async {
      final v1 = await pdf(sellada());
      final v3 = await pdf(sellada(), revision: 3);
      final juntos = Uint8List.fromList([...v3, 10, ...v1]);
      expect(leerHistoriaDePdf(juntos).revision, 3);
    });

    test('datos arbitrarios: emoji, comillas y saltos de línea', () async {
      final datos = {
        'texto': 'Peña 😀 "cita" \\ barra\n\tnueva',
        'n': [72.0, 36.8],
      };
      final doc = pw.Document(theme: fuentes.tema)
        ..addPage(pw.Page(build: (_) => pw.Text('x')));
      incrustarHistoria(
        doc,
        PaqueteHistoria(revision: 1, guardadoEn: guardado, datos: datos),
      );
      expect(
        jsonCanonico(leerHistoriaDePdf(await doc.save()).datos),
        jsonCanonico(datos),
      );
    });
  });

  group('Errores claros al reabrir', () {
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
      final bytes = await pdf(sellada());
      final i = latin1.decode(bytes).indexOf('"app":"$identificadorApp"');
      expect(i, greaterThan(0));
      expect(
        fallo(Uint8List.sublistView(bytes, 0, i + 120)).fallo,
        FalloLectura.danado,
      );
    });

    test('un JSON modificado a mano no pasa la verificación', () async {
      final bytes = await pdf(sellada());
      final texto = latin1.decode(bytes);
      // Mismo tamaño: cambia una letra del apellido (la ñ va escapada).
      const bs = '\\';
      const buscado = '"primerApellido":"Pe${bs}u00f1a"';
      final i = texto.indexOf(buscado);
      expect(i, greaterThan(0));
      final alterado = Uint8List.fromList(bytes);
      alterado[i + buscado.length - 2] = 'o'.codeUnitAt(0); // Peño
      final e = fallo(alterado);
      expect(e.fallo, FalloLectura.danado);
      expect(e.detalle, contains('hash'));
    });

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

extension on Map<String, Object?> {
  List<Map<String, Object?>> get listaEvoluciones => [
    for (final e in this['evoluciones']! as List)
      (e as Map).cast<String, Object?>(),
  ];
}
