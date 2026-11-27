import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/fotos/jpeg.dart';
import 'package:historiasclinicas_net/core/consultorio/fotos/procesar_foto.dart';
import 'package:historiasclinicas_net/core/consultorio/imagenes/estudio_imagen.dart';
import 'package:historiasclinicas_net/core/consultorio/imagenes/plantillas_eco.dart';
import 'package:historiasclinicas_net/core/consultorio/indice/eliminar_paciente.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';

import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';
import 'documentos_test.dart' show textoPdf;
import 'fotos_test.dart' show contieneBytes;

final _foto = File('test/fixtures/foto_con_exif.jpg').readAsBytesSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BancoConsultorio b;
  late ServicioConsultorio s;
  late String paciente;
  late FuentesPdf fuentes;

  setUpAll(() async {
    fuentes = await FuentesPdf.cargar();
  });

  setUp(() async {
    b = BancoConsultorio();
    s = b.servicio;
    await s.crear(fraseDePrueba);
    final r = await s.registrarHistoria(
      HistoriaPendiente(
        datos: historiaSintetica(),
        revision: 1,
        origen: OrigenArchivo.importado,
      ),
    );
    paciente = r!.pacienteId;
  });

  Future<EstudioImagen> tiroides() => s.imagenes.crear(
    s.indice.ficha(paciente)!,
    plantillaEco('tiroides_cuello')!,
  );

  group('Medidas', () {
    test('el volumen del elipsoide con tres diámetros', () {
      const m = MedidaEstudio(
        nombre: 'Lóbulo derecho',
        unidad: 'mL',
        volumen: true,
        valores: [1.8, 2.0, 4.5],
      );
      expect(m.resultado, closeTo(8.47, 0.01));
      expect(m.texto, '1,8 × 2 × 4,5 cm (8,5 mL)');
      expect(m.conValor(1, null).resultado, isNull);
      const simple = MedidaEstudio(
        nombre: 'Istmo',
        unidad: 'mm',
        valores: [3.2],
      );
      expect(simple.texto, '3,2 mm');
      expect(
        MedidaEstudio.desdeMapa(m.aMapa()).texto,
        '1,8 × 2 × 4,5 cm (8,5 mL)',
      );
    });

    test('todas las plantillas tienen nombre, secciones e id único', () {
      expect(
        plantillasEcoBase.map((p) => p.id).toSet(),
        hasLength(plantillasEcoBase.length),
      );
      for (final p in plantillasEcoBase) {
        expect(p.nombre, isNotEmpty);
        expect(p.secciones, isNotEmpty, reason: p.id);
      }
    });
  });

  test(
    'un estudio nuevo trae la plantilla y sugiere el último equipo',
    () async {
      final e = await tiroides();
      expect(e.borrador, isTrue);
      expect(e.titulo, 'Ecografía de tiroides y cuello');
      expect(e.secciones.map((x) => x.titulo), contains('Lóbulo derecho'));
      expect(e.medidas.first.volumen, isTrue);
      expect(e.faltantes, contains('el equipo'));
      await s.imagenes.guardar(e.copyWith(equipo: 'POCUS de prueba'));
      final otro = await tiroides();
      expect(otro.equipo, 'POCUS de prueba');
      expect(s.imagenes.estudiosDe(paciente), hasLength(2));
    },
  );

  test('imágenes sin metadatos; solo 6 van al informe', () async {
    var e = await tiroides();
    final p = await procesarFoto(_foto);
    expect(tieneExif(p.jpeg), isFalse);
    for (var i = 0; i < 7; i++) {
      e = await s.imagenes.agregarImagen(e.id, p, rotulo: 'Corte $i');
    }
    expect(e.imagenes, hasLength(7));
    expect(e.imagenesInforme, hasLength(maxImagenesInforme));
    expect(e.imagenes.last.enInforme, isFalse);
    expect(await s.imagenes.bytesImagen(e.imagenes.first.id), p.jpeg);
    // Cifradas: los bytes del JPEG no están en claro en el almacén.
    expect(contieneBytes(b.todosLosBytes, p.jpeg.sublist(100, 164)), isFalse);
    e = await s.imagenes.quitarImagen(e.id, e.imagenes.first.id);
    expect(e.imagenes, hasLength(6));
    expect(await s.imagenes.bytesImagen('no-existe'), isNull);
  });

  test('cerrar: número, PDF con hallazgos, medidas, imágenes y su json; '
      'después no se edita y se anula con motivo', () async {
    var e = await tiroides();
    final p = await procesarFoto(_foto);
    e = await s.imagenes.agregarImagen(e.id, p, rotulo: 'Lóbulo derecho');
    e = await s.imagenes.guardar(
      e.copyWith(
        equipo: 'POCUS de prueba',
        indicacion: 'Nódulo palpable',
        medidas: [
          e.medidas.first.copyWith(valores: [1.8, 2.0, 4.5]),
          ...e.medidas.skip(1),
        ],
        recomendaciones: 'Control en 6 meses.',
      ),
    );
    final medico = medicoCompleto();
    final (cerrado, pdf) = await s.imagenes.cerrar(
      e.id,
      medico: medico,
      pais: Pais.colombia,
      fuentes: fuentes,
    );
    expect(cerrado.numero, 'EC-000001');
    expect(cerrado.estado, EstadoEstudio.cerrado);
    expect(cerrado.sha256, isNotNull);
    final texto = textoPdf(pdf) ?? '';
    if (texto.isNotEmpty) {
      for (final t in [
        'INFORME ECOGRÁFICO',
        'EC-000001',
        'Ecografía de tiroides y cuello',
        'POCUS de prueba',
        'Nódulo palpable',
        'Lóbulo derecho',
        '(8,5 mL)',
        'Lóbulo derecho',
        'Glándula tiroides de tamaño y ecogenicidad normales.',
        'Control en 6 meses.',
      ]) {
        expect(texto, contains(t));
      }
    }
    expect(contieneTexto(pdf, EstudioImagen.nombreAdjunto), isTrue);
    expect(await s.imagenes.pdfDe(e.id), pdf);
    await expectLater(
      () => s.imagenes.guardar(cerrado.copyWith(impresion: 'otra')),
      throwsStateError,
    );

    // El siguiente número.
    final otro = await s.imagenes.guardar(
      (await tiroides()).copyWith(equipo: 'POCUS de prueba'),
    );
    final (segundo, _) = await s.imagenes.cerrar(
      otro.id,
      medico: medico,
      pais: Pais.colombia,
      fuentes: fuentes,
    );
    expect(segundo.numero, 'EC-000002');

    await expectLater(
      () => s.imagenes.anular(e.id, motivo: ' '),
      throwsStateError,
    );
    final anulado = await s.imagenes.anular(
      e.id,
      motivo: 'Paciente equivocado',
    );
    expect(anulado.estado, EstadoEstudio.anulado);

    // Persiste al bloquear y desbloquear.
    await s.bloquear();
    await s.desbloquear(fraseDePrueba);
    expect(s.imagenes.estudio(e.id)!.estado, EstadoEstudio.anulado);
    expect(s.imagenes.estudio(otro.id)!.numero, 'EC-000002');
    expect(
      [for (final x in await leerBitacora(s.repositorio)) x.accion],
      containsAll([AccionBitacora.cerrarEstudio, AccionBitacora.anularEstudio]),
    );
  });

  test(
    'no cierra sin equipo ni impresión; un borrador se puede borrar',
    () async {
      final e = await s.imagenes.guardar(
        (await tiroides()).copyWith(impresion: ''),
      );
      await expectLater(
        () => s.imagenes.cerrar(
          e.id,
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        ),
        throwsA(
          isA<StateError>().having(
            (x) => x.message,
            'mensaje',
            'Para cerrar el informe falta el equipo, la impresión diagnóstica.',
          ),
        ),
      );
      await s.imagenes.borrarBorrador(e.id);
      expect(s.imagenes.estudio(e.id), isNull);
    },
  );

  test('transvaginal: sin el consentimiento no cierra; obstétricas con su '
      'biometría', () async {
    var e = await s.imagenes.crear(
      s.indice.ficha(paciente)!,
      plantillaEco('pelvica_transvaginal')!,
    );
    e = await s.imagenes.guardar(e.copyWith(equipo: 'POCUS de prueba'));
    expect(e.requiereConsentimiento, isTrue);
    expect(e.faltantes, ['el consentimiento informado de la paciente']);
    e = await s.imagenes.guardar(
      e.copyWith(consentimiento: true, acompanante: 'Auxiliar Ana'),
    );
    expect(e.faltantes, isEmpty);
    final (cerrado, pdf) = await s.imagenes.cerrar(
      e.id,
      medico: medicoCompleto(),
      pais: Pais.colombia,
      fuentes: fuentes,
    );
    expect(cerrado.consentimiento, isTrue);
    final texto = textoPdf(pdf) ?? '';
    if (texto.isNotEmpty) {
      expect(texto, contains('Informado y aceptado por la paciente'));
      expect(texto, contains('Auxiliar Ana'));
      expect(texto, isNot(contains('VERIFICAR')));
    }
    final obst = plantillaEco('obstetrica_segundo_tercer')!;
    expect(
      obst.medidas.map((m) => m.nombre),
      contains('Longitud femoral (LF)'),
    );
    expect(plantillaEco('obstetrica_primer_trimestre'), isNotNull);
  });

  test('un paciente con estudios no se borra al eliminarlo', () async {
    final f = await s.indice.crearFicha(
      s.indice.ficha(paciente)!.copyWith(numeroDocumento: '999'),
    );
    await s.imagenes.crear(f, plantillaEco('abdominal_total')!);
    expect(s.registrosDe(f.id).partes, ['1 estudio de imágenes']);
    expect(await s.eliminarPaciente(f.id), ResultadoEliminacion.oculta);
  });
}
