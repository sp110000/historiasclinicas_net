import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/documento.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/plantillas.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/configuracion.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/plan_tratamiento.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/core/widgets/lienzo_firma.dart';
import 'package:historiasclinicas_net/features/consultorio/documentos/firma_autorizacion.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/pacientes_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/medico/medico_provider.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';
import 'ayudas_procedimientos.dart';

Future<(BancoConsultorio, String)> _paciente() async {
  final b = BancoConsultorio();
  await b.servicio.crear(fraseDePrueba);
  final r = await b.servicio.registrarHistoria(
    HistoriaPendiente(
      datos: historiaSintetica(),
      revision: 1,
      origen: OrigenArchivo.importado,
    ),
  );
  await aprobarHidrolipoclasia(b);
  await b.servicio.documentos.aprobar(TipoPlantilla.consentimientoInformado);
  await b.servicio.guardarConfiguracion(
    b.servicio.configuracion.copyWith(
      codigoReps: '19698-00001',
      habilitacion: 'Medicina estética, distintivo de prueba',
      polizaNumero: '123',
      polizaAseguradora: 'Aseguradora de Prueba',
    ),
  );
  return (b, r!.pacienteId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FuentesPdf fuentes;
  setUpAll(() async => fuentes = await FuentesPdf.cargar());

  test('la póliza: con número, sin póliza o vacía', () {
    const c = ConfiguracionConsultorio();
    expect(c.textoPoliza, '');
    expect(
      c.copyWith(polizaNumero: '9', polizaAseguradora: 'X').textoPoliza,
      'póliza N.º 9 de X',
    );
    expect(
      c.copyWith(sinPoliza: true).textoPoliza,
      'sin póliza de complicaciones',
    );
    final m = c.copyWith(codigoReps: 'R', nit: 'N', sinPoliza: true).aMapa();
    final otra = ConfiguracionConsultorio.desdeMapa(m);
    expect(otra.codigoReps, 'R');
    expect(otra.nit, 'N');
    expect(otra.sinPoliza, isTrue);
  });

  test(
    'la plantilla de fábrica es un borrador con los apartados del art. 16',
    () {
      final p = Plantilla.base(TipoPlantilla.consentimientoInformado);
      expect(p.usable, isFalse);
      final t = p.ultima.cuerpo;
      for (final m in [
        '{{procedimiento}}',
        '{{zonas}}',
        '{{sesiones}}',
        '{{producto}}',
        '{{riesgos}}',
        '{{alternativas}}',
        '{{codigoReps}}',
        '{{habilitacion}}',
        '{{poliza}}',
        '{{certificacion}}',
        'obligación de medio',
        'revocar',
      ]) {
        expect(t, contains(m));
      }
    },
  );

  group('Consentimiento por plan', () {
    test('se firma con el plan, cubre zonas y sesiones, y se revoca', () async {
      final (b, id) = await _paciente();
      final p = b.servicio.procedimientos;
      final ficha = b.servicio.indice.ficha(id)!;
      final plan = p.planSugerido(id, 'hidrolipoclasia');
      expect(plan.sesiones, 4);
      expect(plan.producto, 'Componente A de prueba, Componente B de prueba');
      expect(p.problemasPlan(plan), contains('Elige al menos una zona.'));
      expect(
        p.problemasPlan(
          plan.copyWith(zonas: ['Abdomen inferior'], sesiones: 6),
        ),
        contains('El protocolo permite hasta 4 sesiones.'),
      );
      expect(
        () => p.firmarConsentimiento(
          ficha: ficha,
          plan: plan,
          firmaPng: firmaDePrueba,
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        ),
        throwsStateError,
      );

      final listo = plan.copyWith(zonas: ['Abdomen inferior', 'Flancos']);
      final r = await p.firmarConsentimiento(
        ficha: ficha,
        plan: listo,
        firmaPng: firmaDePrueba,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      final d = r.documento;
      expect(d.numero, 'CI-000001');
      expect(d.plan!.zonas, ['Abdomen inferior', 'Flancos']);
      expect(d.plan!.sesiones, 4);
      expect(
        d.contenido,
        contains(
          'Hidrolipoclasia, en Abdomen inferior, Flancos, en 4 sesiones',
        ),
      );
      expect(d.contenido, contains('Riesgos: Riesgos de prueba.'));
      expect(d.contenido, contains('REPS con el código 19698-00001'));
      expect(d.contenido, contains('póliza N.º 123 de Aseguradora de Prueba'));
      expect(d.contenido, contains('registro profesional RM 54321'));
      // No toca los enlaces de la autorización ni del consentimiento de imagen.
      final f = b.servicio.indice.ficha(id)!;
      expect(f.autorizacionDatosId, isNull);
      expect(f.consentimientoImagenId, isNull);
      expect(p.consentimientoVigente(id, 'hidrolipoclasia')!.id, d.id);
      // documento.json dentro del PDF lleva el plan.
      expect(contieneTexto(r.pdf, '(documento.json)'), isTrue);

      await b.servicio.documentos.cambiarEstado(
        d.id,
        EstadoDocumento.revocado,
        motivo: 'Lo pensó mejor',
      );
      expect(p.consentimientoVigente(id, 'hidrolipoclasia'), isNull);
      final otro = await p.firmarConsentimiento(
        ficha: ficha,
        plan: listo.copyWith(zonas: ['Flancos'], sesiones: 2),
        firmaPng: firmaDePrueba,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      expect(otro.documento.numero, 'CI-000002');
      expect(p.consentimientosDe(id, 'hidrolipoclasia'), hasLength(2));
      expect(p.consentimientoVigente(id, 'hidrolipoclasia')!.plan!.sesiones, 2);
    });

    test('un menor no puede firmarlo', () async {
      final (b, id) = await _paciente();
      final menor = b.servicio.indice
          .ficha(id)!
          .copyWith(fechaNacimiento: DateTime(2012, 1, 1));
      expect(
        () => b.servicio.procedimientos.firmarConsentimiento(
          ficha: menor,
          plan: const PlanTratamiento(
            plantillaId: 'hidrolipoclasia',
            version: 1,
            procedimiento: 'Hidrolipoclasia',
            zonas: ['Flancos'],
            sesiones: 1,
            producto: 'X',
          ),
          firmaPng: firmaDePrueba,
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        ),
        throwsStateError,
      );
    });
  });

  group('Pantalla', () {
    Future<List<(String, Uint8List)>> montar(
      WidgetTester t,
      BancoConsultorio b,
      String ruta, {
      Size tamano = const Size(1440, 1200),
    }) async {
      t.view
        ..physicalSize = tamano
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
      final prefs = await SharedPreferences.getInstance();
      final descargas = <(String, Uint8List)>[];
      final c = ProviderContainer(
        overrides: [
          preferenciasProvider.overrideWithValue(prefs),
          rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
          servicioConsultorioProvider.overrideWithValue(b.servicio),
          exportarFirmaProvider.overrideWithValue((_) async => firmaDePrueba),
          descargarPdfProvider.overrideWithValue(
            (bytes, nombre) => descargas.add((nombre, bytes)),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.read(medicoProvider.notifier).actualizar((_) => medicoCompleto());
      final router = crearRouterConsultorio(ubicacionInicial: ruta);
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

    testWidgets('plan, firma y consentimiento vigente en Estética', (t) async {
      final (b, id) = await _paciente();
      final descargas = await montar(t, b, '/pacientes/$id');
      await pulsar(t, find.text('Estética'));
      expect(find.text('Sin consentimiento vigente'), findsOneWidget);
      await pulsar(t, find.text('Firmar consentimiento'));
      expect(
        find.text('Plan de tratamiento · Hidrolipoclasia'),
        findsOneWidget,
      );
      await pulsar(t, find.text('Continuar a la firma'));
      expect(find.text('Elige al menos una zona.'), findsOneWidget);
      await pulsar(t, find.text('Flancos'));
      await pulsar(t, find.text('Continuar a la firma'));

      expect(
        find.textContaining('Hidrolipoclasia, en Flancos, en 4 sesiones'),
        findsOneWidget,
      );
      await pulsar(
        t,
        find.text('El paciente leyó el documento y resolvió sus dudas'),
      );
      await t.ensureVisible(find.byType(LienzoFirma));
      await t.drag(find.byType(LienzoFirma), const Offset(120, 30));
      await t.pumpAndSettle();
      await pulsar(t, find.text('Firmar y descargar PDF'));
      expect(
        descargas.single.$1,
        'Consentimiento_informado_PENA_CI-000001.pdf',
      );
      expect(
        find.textContaining('CI-000001 · 4 sesiones · Flancos'),
        findsOneWidget,
      );
      expect(find.text('Nuevo consentimiento (otro plan)'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('Ajustes: datos del prestador y póliza', (t) async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      await montar(t, b, '/ajustes');
      await t.scrollUntilVisible(
        find.text('Prestador y póliza'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(
        find.widgetWithText(TextField, 'Código de prestador (REPS)'),
        '19698-00001',
      );
      await pulsar(t, find.text('Sin póliza de complicaciones'));
      await pulsar(t, find.text('Guardar datos del prestador'));
      expect(b.servicio.configuracion.codigoReps, '19698-00001');
      expect(b.servicio.configuracion.sinPoliza, isTrue);
      await t.pump(const Duration(seconds: 5));
    });
  });
}
