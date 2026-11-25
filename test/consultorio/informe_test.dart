import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/documento.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/plantillas.dart';
import 'package:historiasclinicas_net/core/consultorio/fotos/procesar_foto.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/ficha_paciente.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/foto.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/medicion.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/seguimiento/marcas_eje.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/models/medico.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/pacientes_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';
import 'documentos_test.dart' show textoPdf;
import 'fotos_test.dart' show contieneBytes;

final _antes = File(
  'tool/e2e/fixtures/consultorio/foto_frontal_antes.jpg',
).readAsBytesSync();
final _despues = File(
  'tool/e2e/fixtures/consultorio/foto_frontal_despues.jpg',
).readAsBytesSync();

/// Un trozo del medio del JPEG: si está en el PDF, la foto va dentro.
List<int> _huella(FotoProcesada p) {
  final medio = p.jpeg.length ~/ 2;
  return p.jpeg.sublist(medio, medio + 48);
}

/// Paciente con consentimiento de imagen, tres mediciones y dos fotos
/// frontales (antes y después).
Future<(BancoConsultorio, String, FotoProcesada, FotoProcesada)>
_pacienteConSeguimiento(FuentesPdf fuentes) async {
  final b = BancoConsultorio();
  await b.servicio.crear(fraseDePrueba);
  final r = await b.servicio.registrarHistoria(
    HistoriaPendiente(
      datos: historiaSintetica(),
      revision: 1,
      origen: OrigenArchivo.importado,
    ),
  );
  final id = r!.pacienteId;
  final s = b.servicio.seguimiento;
  // Coherentes con los signos de la historia sintética (02/10: 64,5 kg,
  // 162 cm).
  for (final (fecha, peso, cintura) in [
    (DateTime(2026, 9, 1), 68.0, 92.0),
    (DateTime(2026, 9, 15), 66.6, 91.0),
    (DateTime(2026, 11, 1), 63.0, 87.0),
  ]) {
    await s.guardarMedicion(
      Medicion(
        id: '',
        pacienteId: id,
        fecha: fecha,
        creado: fecha,
        peso: peso,
        talla: 162,
        cintura: cintura,
        cadera: 100,
      ),
    );
  }
  await b.servicio.documentos.aprobar(TipoPlantilla.consentimientoImagen);
  await b.servicio.documentos.firmarDocumento(
    TipoPlantilla.consentimientoImagen,
    ficha: b.servicio.indice.ficha(id)!,
    firmaPng: firmaDePrueba,
    medico: medicoCompleto(),
    pais: Pais.colombia,
    permisos: const PermisosImagen(clinico: true),
    fuentes: fuentes,
  );
  final antes = await procesarFoto(_antes);
  final despues = await procesarFoto(_despues);
  await s.guardarFoto(
    pacienteId: id,
    vista: VistaFoto.frontal,
    procesada: antes,
    fecha: DateTime(2026, 9, 1, 9),
  );
  await s.guardarFoto(
    pacienteId: id,
    vista: VistaFoto.frontal,
    procesada: despues,
    fecha: DateTime(2026, 11, 1, 9),
  );
  return (b, id, antes, despues);
}

Future<int> _exportacionesEnBitacora(BancoConsultorio b) async => [
  for (final e in await b.servicio.bitacora())
    if (e.accion == AccionBitacora.exportarFotos) e,
].length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FuentesPdf fuentes;
  setUpAll(() async => fuentes = await FuentesPdf.cargar());

  group('Informe de seguimiento', () {
    test('marcas redondas en el eje de las gráficas', () {
      final peso = marcasEje(63, 68);
      expect(peso.decimales, 0);
      expect(peso.marcas.first, lessThan(63));
      expect(peso.marcas.last, greaterThan(68));
      for (final m in peso.marcas) {
        expect(m, m.roundToDouble());
      }
      final imc = marcasEje(24.0, 25.9);
      expect(imc.decimales, 1);
      expect(imc.marcas.length, inInclusiveRange(3, 8));
      final plano = marcasEje(80, 80);
      expect(plano.marcas.first, lessThan(80));
      expect(plano.marcas.last, greaterThan(80));
    });

    test(
      'sin pedirlo no lleva fotos; trae cambios, gráficas y tabla',
      () async {
        final (b, id, antes, despues) = await _pacienteConSeguimiento(fuentes);
        final ficha = b.servicio.indice.ficha(id)!;
        final pdf = await b.servicio.seguimiento.informePdf(
          ficha,
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        );
        expect(contieneBytes(pdf, _huella(antes)), isFalse);
        expect(contieneBytes(pdf, _huella(despues)), isFalse);
        expect(await _exportacionesEnBitacora(b), 0);

        final texto = textoPdf(pdf);
        if (texto == null) return; // Sin pdftotext: basta lo anterior.
        expect(texto, contains('INFORME DE SEGUIMIENTO'));
        expect(texto, contains(ficha.nombreCompleto));
        expect(texto, contains('Peso 68 → 63 kg (-7,4 %)'));
        expect(texto, contains('Cintura 92 → 87 cm'));
        expect(texto, contains('GRÁFICAS'));
        expect(texto, contains('IMC (kg/m²)'));
        expect(texto, contains('MEDICIONES'));
        expect(texto, contains('01/11/2026'));
        expect(texto, contains('24,0'), reason: 'IMC de 63 kg y 162 cm');
        expect(texto, isNot(contains('FOTOS')));
        expect(texto, contains(medicoCompleto().nombre));
        expect(texto, contains('Pág. 1 de'));
      },
    );

    test('con «Incluir fotos» lleva la primera y la última, y queda en la '
        'bitácora', () async {
      final (b, id, antes, despues) = await _pacienteConSeguimiento(fuentes);
      final pdf = await b.servicio.seguimiento.informePdf(
        b.servicio.indice.ficha(id)!,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        incluirFotos: true,
        fuentes: fuentes,
      );
      expect(contieneBytes(pdf, _huella(antes)), isTrue);
      expect(contieneBytes(pdf, _huella(despues)), isTrue);
      expect(await _exportacionesEnBitacora(b), 1);
      final texto = textoPdf(pdf);
      if (texto != null) {
        expect(texto, contains('FOTOS'));
        expect(texto, contains('Frontal · 01/09/2026'));
      }
    });

    test('«Exportar fotos» las lleva todas; sin fotos no hay PDF', () async {
      final (b, id, antes, despues) = await _pacienteConSeguimiento(fuentes);
      final s = b.servicio.seguimiento;
      final pdf = await s.fotosPdf(
        b.servicio.indice.ficha(id)!,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      expect(contieneBytes(pdf, _huella(antes)), isTrue);
      expect(contieneBytes(pdf, _huella(despues)), isTrue);
      expect(await _exportacionesEnBitacora(b), 1);

      final otra = await b.servicio.indice.crearFicha(
        FichaPaciente(
          id: '',
          clave: '',
          creado: DateTime(2026),
          actualizado: DateTime(2026),
          tipoDocumento: 'CC',
          numeroDocumento: '52000111',
          nombres: 'María',
          primerApellido: 'Prueba',
        ),
      );
      expect(
        () => s.fotosPdf(
          otra,
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        ),
        throwsStateError,
      );
    });

    test('sin médico configurado también sale, sin firma', () async {
      final (b, id, _, _) = await _pacienteConSeguimiento(fuentes);
      final pdf = await b.servicio.seguimiento.informePdf(
        b.servicio.indice.ficha(id)!,
        medico: const Medico(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      expect(pdf.length, greaterThan(1000));
    });
  });

  group('Pantalla', () {
    Future<List<(Uint8List, String)>> montar(
      WidgetTester t,
      BancoConsultorio b,
      String id,
    ) async {
      t.view
        ..physicalSize = const Size(1440, 1200)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
      final prefs = await SharedPreferences.getInstance();
      final descargas = <(Uint8List, String)>[];
      final c = ProviderContainer(
        overrides: [
          preferenciasProvider.overrideWithValue(prefs),
          rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
          servicioConsultorioProvider.overrideWithValue(b.servicio),
          descargarPdfProvider.overrideWithValue(
            (bytes, nombre) => descargas.add((bytes, nombre)),
          ),
        ],
      );
      addTearDown(c.dispose);
      final router = crearRouterConsultorio(ubicacionInicial: '/pacientes/$id');
      addTearDown(router.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(
            theme: temaClaro(),
            routerConfig: router,
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
          ),
        ),
      );
      await t.pumpAndSettle();
      return descargas;
    }

    Future<void> pulsar(WidgetTester t, Finder f) async {
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
    }

    testWidgets('informe sin fotos por defecto y exportar fotos', (t) async {
      final (b, id, antes, _) = await _pacienteConSeguimiento(fuentes);
      final descargas = await montar(t, b, id);

      await pulsar(t, find.text('Seguimiento'));
      await pulsar(t, find.text('Informe de seguimiento'));
      expect(find.text('Incluir fotos'), findsOneWidget);
      final casilla = t.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(casilla.value, isFalse, reason: 'apagado por defecto');
      await pulsar(t, find.text('Descargar'));
      final (pdf, nombre) = descargas.single;
      expect(nombre, 'Informe_seguimiento_PENA_2026-11-21.pdf');
      expect(contieneBytes(pdf, _huella(antes)), isFalse);

      await pulsar(t, find.text('Fotos'));
      await pulsar(t, find.text('Exportar fotos en PDF'));
      expect(find.text('¿Exportar las fotos?'), findsOneWidget);
      await pulsar(t, find.widgetWithText(FilledButton, 'Exportar'));
      expect(descargas.last.$2, 'Fotos_clinicas_PENA_2026-11-21.pdf');
      expect(contieneBytes(descargas.last.$1, _huella(antes)), isTrue);
      await t.pump(const Duration(seconds: 5));
    });
  });
}
