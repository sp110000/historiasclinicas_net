// Fase 5.0: código de recuperación nuevo, fortaleza de la frase y hoja de
// recuperación en PDF.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/hoja_recuperacion.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/seguridad/fortaleza.dart';
import 'package:historiasclinicas_net/core/consultorio/seguridad/llavero.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';

import 'ayudas_consultorio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un código nuevo reemplaza al anterior y exige la frase', () async {
    final b = BancoConsultorio();
    final viejo = await b.servicio.crear(fraseDePrueba);
    await expectLater(
      b.servicio.regenerarCodigo('no es la frase'),
      throwsA(isA<SecretoIncorrecto>()),
    );
    final nuevo = await b.servicio.regenerarCodigo(fraseDePrueba);
    expect(nuevo, isNot(viejo));
    await b.servicio.bloquear();
    await expectLater(
      b.servicio.recuperar(viejo, 'otra frase bien larga'),
      throwsA(isA<SecretoIncorrecto>()),
    );
    await b.servicio.recuperar(nuevo, 'otra frase bien larga');
    final acciones = (await b.servicio.bitacora()).map((e) => e.accion);
    expect(acciones, contains(AccionBitacora.regenerarCodigo));
  });

  test('fortaleza de la frase', () {
    const casos = {
      '': NivelFrase.corta,
      'corta': NivelFrase.corta,
      'aaaaaaaaaaaaaaa': NivelFrase.debil,
      'consultorio1': NivelFrase.debil,
      'Consultorio2026!': NivelFrase.aceptable,
      'mango azul en la loma': NivelFrase.fuerte,
      'caballo correcto batería grapa': NivelFrase.fuerte,
    };
    for (final e in casos.entries) {
      expect(evaluarFrase(e.key), e.value, reason: e.key);
    }
    expect(NivelFrase.corta.admitida, isFalse);
    expect(NivelFrase.debil.admitida, isTrue);
  });

  test('la hoja de recuperación se genera como PDF', () async {
    final fuentes = await FuentesPdf.cargar();
    const codigo = 'ABCDEFGHJKMNPQRSTVWXYZ01';
    final pdf = await generarHojaRecuperacion(
      codigo: codigo,
      fecha: DateTime(2026, 11, 21, 9, 30),
      fuentes: fuentes,
    );
    expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    expect(pdf.length, greaterThan(10000), reason: 'lleva las fuentes');
    expect(
      nombreHojaRecuperacion(DateTime(2026, 11, 21)),
      'Hoja_recuperacion_consultorio_2026-11-21.pdf',
    );
    expect(formatearCodigo(codigo), 'ABCD-EFGH-JKMN-PQRS-TVWX-YZ01');

    // Con poppler instalado (en la CI de e2e y en los equipos de desarrollo),
    // se comprueba que ningún grupo del código se corte.
    final dir = Directory.systemTemp.createTempSync('hoja');
    addTearDown(() => dir.deleteSync(recursive: true));
    final ruta = '${dir.path}/hoja.pdf';
    File(ruta).writeAsBytesSync(pdf);
    final ProcessResult r;
    try {
      r = Process.runSync('pdftotext', ['-layout', ruta, '-']);
    } on ProcessException {
      markTestSkipped('Sin pdftotext: no se lee el texto de la hoja');
      return;
    }
    final texto = r.stdout as String;
    for (final g in formatearCodigo(codigo).split('-')) {
      expect(texto, contains(g), reason: 'grupo $g');
    }
  });
}
