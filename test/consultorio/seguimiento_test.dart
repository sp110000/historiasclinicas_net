import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/medicion.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/integridad/cadena_hash.dart';
import 'package:historiasclinicas_net/core/models/evolucion.dart';
import 'package:historiasclinicas_net/core/models/signos_vitales.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/historia/estado/historia_controller.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

Medicion _m({
  String id = '',
  DateTime? fecha,
  double? peso,
  double? talla,
  double? cintura,
  double? cadera,
  double? grasa,
  MetodoGrasa? metodo,
}) => Medicion(
  id: id,
  pacienteId: 'p',
  fecha: fecha ?? DateTime(2026, 11, 12, 9),
  creado: DateTime(2026, 11, 12, 9),
  peso: peso,
  talla: talla,
  cintura: cintura,
  cadera: cadera,
  grasa: grasa,
  metodoGrasa: metodo,
);

Future<(BancoConsultorio, String)> _conHistoria() async {
  final b = BancoConsultorio();
  await b.servicio.crear(fraseDePrueba);
  // La historia de ejemplo trae peso 64,5 y talla 162; una evolución con
  // peso 63.
  final datos = sellarEvoluciones(historiaSintetica(), [
    Evolucion(
      id: 'e1',
      fechaHora: DateTime(2026, 11, 2, 9),
      texto: 'Control.',
      signos: const SignosVitales(peso: 63, perimetroAbdominal: 80),
    ).aMapa(),
  ]);
  final r = await b.servicio.registrarHistoria(
    HistoriaPendiente(
      datos: datos,
      revision: 2,
      origen: OrigenArchivo.importado,
    ),
  );
  return (b, r!.pacienteId);
}

void main() {
  group('Cálculos', () {
    test('IMC, índice cintura-cadera y texto para la evolución', () {
      final m = _m(peso: 88, talla: 176, cintura: 96, cadera: 102);
      expect(m.imc, closeTo(28.4, 0.05));
      expect(m.icc, closeTo(0.941, 0.001));
      expect(
        m.texto,
        'Mediciones del día: Peso 88 kg · Talla 176 cm · IMC 28,4 · '
        'Cintura 96 cm · Cadera 102 cm · ICC 0,94.',
      );
      expect(_m(cintura: 90).icc, isNull);
      expect(_m().vacia, isTrue);
      expect(_m(peso: 70).vacia, isFalse);
    });

    test('perímetros D/I, PA y % de grasa en el texto', () {
      final m = Medicion(
        id: '',
        pacienteId: 'p',
        fecha: DateTime(2026),
        creado: DateTime(2026),
        musloDerecho: 58.5,
        musloIzquierdo: 58,
        paSistolica: 128,
        paDiastolica: 82,
        grasa: 31.2,
        metodoGrasa: MetodoGrasa.bioimpedancia,
      );
      expect(
        m.texto,
        'Mediciones del día: Muslo D/I 58,5/58 cm · PA 128/82 mmHg · '
        'Grasa 31,2 % (bioimpedancia).',
      );
    });

    test('cambio entre la primera y la última', () {
      final c = cambioEn([
        _m(fecha: DateTime(2026, 12), peso: 88),
        _m(fecha: DateTime(2026, 10), peso: 96),
        _m(fecha: DateTime(2026, 11)),
      ], (m) => m.peso)!;
      expect(c.primera, 96);
      expect(c.ultima, 88);
      expect(c.porcentaje, closeTo(-8.33, 0.01));
      expect(cambioEn([_m(peso: 1)], (m) => m.peso), isNull);
    });
  });

  group('Servicio', () {
    test('las historias aportan sus signos al seguimiento', () async {
      final (b, id) = await _conHistoria();
      final ms = b.servicio.seguimiento.medicionesDe(id);
      expect(ms.map((m) => m.peso), [64.5, 63]);
      expect(ms.first.fuente, 'Historia del 02/10/2026');
      expect(ms.last.fuente, 'Evolución 1');
      expect(ms.last.cintura, 80);
      expect(ms.every((m) => !m.editable), isTrue);
      expect(b.servicio.seguimiento.ultimaTalla(id), 162);
    });

    test('guardar, editar, borrar, validar y cifrar', () async {
      final (b, id) = await _conHistoria();
      final s = b.servicio.seguimiento;
      expect(() => s.guardarMedicion(_m()), throwsStateError);
      expect(
        () => s.guardarMedicion(_m(grasa: 30)),
        throwsStateError,
        reason: 'el % de grasa pide el método',
      );
      final g = await s.guardarMedicion(
        Medicion.desdeMapa('', {
          ..._m(peso: 61.2, cintura: 77).aMapa(),
          'pacienteId': id,
        }),
      );
      expect(g.id, isNotEmpty);
      expect(s.medicionesDe(id).last.peso, 61.2);

      final editada = Medicion.desdeMapa(g.id, {...g.aMapa(), 'peso': 60.8});
      await s.guardarMedicion(editada);
      expect(s.medicion(g.id)!.peso, 60.8);
      expect(s.medicionesDe(id).where((m) => m.editable), hasLength(1));

      await b.servicio.repositorio.esperarEscrituras();
      expect(contieneTexto(b.todosLosBytes, '60.8'), isFalse);

      await b.servicio.bloquear();
      await b.servicio.desbloquear(fraseDePrueba);
      expect(b.servicio.seguimiento.medicion(g.id)!.peso, 60.8);

      await b.servicio.seguimiento.borrarMedicion(g.id);
      expect(b.servicio.seguimiento.medicion(g.id), isNull);
    });

    test('el registro de la historia guarda sus mediciones', () {
      final r = RegistroHistoria.desdeDatos(
        historiaSintetica(),
        pacienteId: 'p',
        revision: 1,
        ahora: DateTime(2026, 11, 21),
      );
      expect(r.mediciones.single.peso, 64.5);
      final otra = RegistroHistoria.desdeMapa(r.id, r.aMapa());
      expect(otra.mediciones.single.aMapa(), r.mediciones.single.aMapa());
    });
  });

  group('Pantalla', () {
    Future<ProviderContainer> montar(
      WidgetTester t,
      BancoConsultorio b,
      String ruta, {
      Size tamano = const Size(1440, 1000),
    }) async {
      t.view
        ..physicalSize = tamano
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          preferenciasProvider.overrideWithValue(prefs),
          rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
          servicioConsultorioProvider.overrideWithValue(b.servicio),
        ],
      );
      addTearDown(c.dispose);
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
      return c;
    }

    Future<void> pulsar(WidgetTester t, Finder f) async {
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
    }

    Future<void> escribir(WidgetTester t, String etiqueta, String v) async {
      final f = find.ancestor(
        of: find.text(etiqueta),
        matching: find.byType(TextField),
      );
      await t.ensureVisible(f.first);
      await t.enterText(f.first, v);
      await t.pump();
    }

    testWidgets('registrar una medición y copiarla a la evolución', (t) async {
      final (b, id) = await _conHistoria();
      final c = await montar(t, b, '/pacientes/$id');
      await pulsar(t, find.text('Seguimiento'));
      expect(find.text('Historia del 02/10/2026'), findsOneWidget);
      expect(find.text('Evolución 1'), findsOneWidget);
      final semantica = t.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp(r'^Peso: de 64,5 a 63 kg')),
        findsOneWidget,
      );
      semantica.dispose();

      await pulsar(t, find.text('Medición'));
      expect(find.text('Medición nueva'), findsOneWidget);
      // La talla se arrastra de la última medición.
      expect(find.widgetWithText(TextField, '162'), findsOneWidget);
      await escribir(t, 'Peso', '61,5');
      await escribir(t, 'Cintura', '78');
      await escribir(t, 'Cadera', '96');
      expect(find.textContaining('IMC 23,4'), findsOneWidget);
      await pulsar(t, find.text('Guardar medición'));

      final ms = b.servicio.seguimiento.medicionesDe(id);
      expect(ms.last.peso, 61.5);
      expect(ms.last.talla, 162);
      expect(find.text('Medición'), findsWidgets);
      final evolucion = c.read(historiaProvider).evolucionesNuevas.single;
      expect(
        evolucion.texto,
        'Mediciones del día: Peso 61,5 kg · Talla 162 cm · IMC 23,4 · '
        'Cintura 78 cm · Cadera 96 cm · ICC 0,81.',
      );
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('320 px: el seguimiento no se desborda', (t) async {
      final (b, id) = await _conHistoria();
      await montar(t, b, '/pacientes/$id', tamano: const Size(320, 640));
      await t.scrollUntilVisible(
        find.text('Seguimiento'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await pulsar(t, find.text('Seguimiento'));
      expect(t.takeException(), isNull);
      await t.drag(find.byType(Scrollable).last, const Offset(0, -2000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 5));
    });
  });
}
