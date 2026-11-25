import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/archivos/archivos.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/integridad/cadena_hash.dart';
import 'package:historiasclinicas_net/core/models/evolucion.dart';
import 'package:historiasclinicas_net/core/models/medico.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/pdf/historia_pdf.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/pacientes_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/integracion/enganche_historia.dart';
import 'package:historiasclinicas_net/features/historia/estado/archivo_provider.dart';
import 'package:historiasclinicas_net/features/historia/estado/historia_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

void main() {
  group('Servicio: historias pendientes', () {
    test(
      'con el consultorio bloqueado espera y se registra al abrir',
      () async {
        final b = BancoConsultorio();
        await b.servicio.crear(fraseDePrueba);
        await b.servicio.bloquear();
        expect(b.servicio.indice.cargado, isFalse);

        final datos = historiaSintetica();
        final r = await b.servicio.registrarHistoria(
          HistoriaPendiente(
            datos: datos,
            revision: 1,
            origen: OrigenArchivo.generado,
            nombreArchivo: 'a.pdf',
          ),
        );
        expect(r, isNull);
        // La misma historia, revisión más nueva: reemplaza la pendiente.
        final v2 = sellarEvoluciones(datos, [
          Evolucion(id: 'e1', fechaHora: DateTime(2026, 10, 9, 10)).aMapa(),
        ]);
        await b.servicio.registrarHistoria(
          HistoriaPendiente(
            datos: v2,
            revision: 2,
            origen: OrigenArchivo.generado,
            nombreArchivo: 'a.pdf',
          ),
        );
        expect(b.servicio.historiasPendientes, 1);

        await b.servicio.desbloquear(fraseDePrueba);
        expect(b.servicio.historiasPendientes, 0);
        final h = b.servicio.indice.historia(datos['id']! as String)!;
        expect(h.revision, 2);

        await b.servicio.bloquear();
        expect(b.servicio.indice.fichasActivas, isEmpty);
        await b.servicio.desbloquear(fraseDePrueba);
        expect(b.servicio.indice.fichasActivas, hasLength(1));
      },
    );
  });

  group('Próximo control en la evolución', () {
    test('sin la fecha, el mapa sellado es el de siempre', () {
      final e = Evolucion(
        id: 'e1',
        fechaHora: DateTime(2026, 10, 9, 10),
        texto: 'Control.',
      );
      expect(e.aMapa().keys, [
        'id',
        'fechaHora',
        'texto',
        'incluirFirma',
        'incluirSello',
      ]);
      final con = e.copyWith(proximoControl: DateTime(2026, 12, 1));
      expect(con.aMapa()['proximoControl'], '2026-12-01');
      expect(
        Evolucion.desdeMapa(con.aMapa()).proximoControl,
        DateTime(2026, 12, 1),
      );
      // Entra en el sello: cambiarla cambia el hash.
      expect(
        calcularHashEvolucion(con.aMapa(), 'x'),
        isNot(calcularHashEvolucion(e.aMapa(), 'x')),
      );
    });

    test(
      'la versión pública continúa esas historias sin perder el campo',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final c = ProviderContainer(
          overrides: [preferenciasProvider.overrideWithValue(prefs)],
        );
        addTearDown(c.dispose);
        c.listen(historiaProvider, (_, _) {}, fireImmediately: true);

        final datos = sellarEvoluciones(historiaSintetica(), [
          Evolucion(
            id: 'e1',
            fechaHora: DateTime(2026, 10, 9, 10),
            texto: 'Control.',
            proximoControl: DateTime(2026, 12, 1),
          ).aMapa(),
        ]);
        final ctrl = c.read(historiaProvider.notifier)
          ..abrir(datos, revision: 2, nombreArchivo: 'a.pdf');
        expect(c.read(historiaProvider).integridad!.correcta, isTrue);
        expect(
          c.read(historiaProvider).evolucionesSelladas.single.proximoControl,
          DateTime(2026, 12, 1),
        );
        ctrl
          ..agregarEvolucion(ahora: DateTime(2026, 12, 1, 9))
          ..actualizarEvolucion(
            0,
            c
                .read(historiaProvider)
                .evolucionesNuevas
                .single
                .copyWith(texto: 'Segundo control.'),
          );
        final guardado = ctrl.prepararGuardado(medico: const Medico());
        expect(verificarIntegridad(guardado.datos).correcta, isTrue);
        final evs = guardado.datos['evoluciones']! as List;
        expect((evs[0] as Map)['proximoControl'], '2026-12-01');
        expect((evs[1] as Map).containsKey('proximoControl'), isFalse);

        // El índice toma la fecha de la evolución.
        final r = RegistroHistoria.desdeDatos(
          guardado.datos,
          pacienteId: 'p',
          revision: 3,
          ahora: DateTime(2026, 12, 1),
        );
        expect(r.proximoControl, DateTime(2026, 12, 1));
        expect(r.evoluciones.first.proximoControl, DateTime(2026, 12, 1));
      },
    );

    test('el PDF la imprime en la evolución', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final datos = sellarEvoluciones(historiaSintetica(), [
        Evolucion(
          id: 'e1',
          fechaHora: DateTime(2026, 10, 9, 10),
          texto: 'Control.',
          proximoControl: DateTime(2026, 12, 1),
        ).aMapa(),
      ]);
      final pdf = await generarPdfHistoria(
        datos: datos,
        revision: 2,
        fuentes: await FuentesPdf.cargar(),
        generadoEn: DateTime(2026, 10, 9, 10, 30),
      );
      final dir = Directory.systemTemp.createTempSync('evolucion');
      addTearDown(() => dir.deleteSync(recursive: true));
      final ruta = '${dir.path}/h.pdf';
      File(ruta).writeAsBytesSync(pdf);
      final ProcessResult r;
      try {
        r = Process.runSync('pdftotext', [ruta, '-']);
      } on ProcessException {
        markTestSkipped('Sin pdftotext');
        return;
      }
      expect(r.stdout as String, contains('Próximo control: 01/12/2026'));
    });
  });

  group('Prellenado y enganches', () {
    late BancoConsultorio b;
    late ProviderContainer c;
    late WidgetRef ref;
    late BuildContext contexto;

    Future<void> montar(WidgetTester t) async {
      SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
      final prefs = await SharedPreferences.getInstance();
      c = ProviderContainer(
        overrides: [
          preferenciasProvider.overrideWithValue(prefs),
          servicioConsultorioProvider.overrideWithValue(b.servicio),
        ],
      );
      addTearDown(c.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: temaClaro(),
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: Consumer(
                builder: (context, r, _) {
                  ref = r;
                  contexto = context;
                  r.watch(historiaProvider);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('historia nueva desde la ficha: paciente y alergias vigentes', (
      t,
    ) async {
      b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      await b.servicio.registrarHistoria(
        HistoriaPendiente(
          datos: sellarEvoluciones(historiaSintetica(), [
            Evolucion(
              id: 'e1',
              fechaHora: DateTime(2026, 10, 9, 10),
              texto: '$prefijoAlergiasActualizadas Penicilina.',
            ).aMapa(),
          ]),
          revision: 2,
          origen: OrigenArchivo.importado,
        ),
      );

      await montar(t);
      final ficha = b.servicio.indice.fichasActivas.single;
      final antes = c.read(historiaProvider).versionFormulario;

      await nuevaHistoriaPara(ref, ficha);
      final e = c.read(historiaProvider);
      expect(e.abierta, isFalse);
      expect(e.versionFormulario, greaterThan(antes));
      expect(e.historia.paciente.numeroDocumento, '1032456789');
      expect(e.historia.paciente.nombres, 'José Ángel');
      expect(e.historia.antecedentes.alergias, ['Penicilina']);
      expect(e.historia.antecedentes.personales, 'Hipotiroidismo');
      expect(e.historia.motivoConsulta, isEmpty);
      expect(c.read(fichaEnCursoProvider), ficha.id);
      // Deja correr el autoguardado del borrador.
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('evolución nueva: abre la última revisión con su PDF', (
      t,
    ) async {
      b = BancoConsultorio();
      final datos = historiaSintetica();
      final pdf = await pdfCon(datos);
      await b.servicio.crear(fraseDePrueba);
      await b.servicio.registrarHistoria(
        HistoriaPendiente(
          datos: datos,
          revision: 1,
          origen: OrigenArchivo.generado,
          nombreArchivo: 'Pena_1032456789_r1.pdf',
          bytesPdf: pdf,
        ),
      );

      await montar(t);
      final ficha = b.servicio.indice.fichasActivas.single;

      await nuevaEvolucionPara(ref, ficha.id);
      var e = c.read(historiaProvider);
      expect(e.abierta, isTrue);
      expect(e.revision, 1);
      expect(e.evolucionesNuevas, hasLength(1));
      expect(c.read(archivoActualProvider)!.bytes, pdf);
      expect(c.read(archivoActualProvider)!.nombre, 'Pena_1032456789_r1.pdf');

      // Otra vez: no reabre ni agrega otra evolución.
      await nuevaEvolucionPara(ref, ficha.id);
      e = c.read(historiaProvider);
      expect(e.evolucionesNuevas, hasLength(1));
      // Deja correr el autoguardado del borrador.
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets(
      'abrir un PDF más viejo que el índice ofrece la versión nueva',
      (t) async {
        b = BancoConsultorio();
        final v1 = historiaSintetica();
        final v2 = sellarEvoluciones(v1, [
          Evolucion(
            id: 'e1',
            fechaHora: DateTime(2026, 10, 9, 10),
            texto: 'Mejoría.',
          ).aMapa(),
        ]);
        final pdf1 = await pdfCon(v1);
        final pdf2 = await pdfCon(v2, revision: 2);
        await b.servicio.crear(fraseDePrueba);
        await b.servicio.registrarHistoria(
          HistoriaPendiente(
            datos: v2,
            revision: 2,
            origen: OrigenArchivo.generado,
            nombreArchivo: 'r2.pdf',
            bytesPdf: pdf2,
          ),
        );

        await montar(t);
        c.read(historiaProvider.notifier).abrir(v1, revision: 1);

        final fin = alAbrirHistoria(
          contexto,
          ref,
          datos: v1,
          revision: 1,
          archivo: ArchivoAbierto(nombre: 'r1.pdf', bytes: pdf1),
        );
        await t.pumpAndSettle();
        expect(find.text('Hay una versión más nueva'), findsOneWidget);
        expect(find.textContaining('revisión 1'), findsOneWidget);
        await t.tap(find.text('Abrir la más nueva'));
        await t.pumpAndSettle();
        await fin;
        await t.pumpAndSettle();

        final e = c.read(historiaProvider);
        expect(e.revision, 2);
        expect(e.evolucionesSelladas, hasLength(1));
        expect(c.read(archivoActualProvider)!.bytes, pdf2);
        expect(find.textContaining('versión del consultorio'), findsOneWidget);
        // Deja correr el autoguardado del borrador.
        await t.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('al guardar con el consultorio bloqueado queda pendiente', (
      t,
    ) async {
      b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      await b.servicio.bloquear();

      await montar(t);
      final antes = c.read(versionIndiceProvider);
      final datos = historiaSintetica();
      final pdf = await pdfCon(datos);
      await registrarHistoriaGuardada(
        contexto,
        ref,
        datos: datos,
        revision: 1,
        nombreArchivo: 'a.pdf',
        bytesPdf: pdf,
      );
      expect(b.servicio.historiasPendientes, 1);
      expect(historiasPendientes(ref), 1);
      expect(c.read(versionIndiceProvider), greaterThan(antes));

      await b.servicio.desbloquear(fraseDePrueba);
      final h = b.servicio.indice.historia(datos['id']! as String)!;
      expect(h.tienePdf, isTrue);
      expect(h.archivos.single.origen, OrigenArchivo.generado);
      // Deja correr el autoguardado del borrador.
      await t.pump(const Duration(seconds: 5));
    });
  });
}
