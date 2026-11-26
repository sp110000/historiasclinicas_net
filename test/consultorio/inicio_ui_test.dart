import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/agenda/cita.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/core/widgets/ilustraciones.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/presentacion_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/historia/estado/historia_controller.dart';
import 'package:historiasclinicas_net/features/medico/medico_provider.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

// Viernes 20/11/2026, 9:30.
final _ahora = DateTime(2026, 11, 20, 9, 30);

Future<(GoRouter, ProviderContainer)> _montar(
  WidgetTester t,
  BancoConsultorio b, {
  String ruta = '/inicio',
  Size tamano = const Size(1920, 1200),
}) async {
  t.view
    ..physicalSize = tamano
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: <Override>[
      preferenciasProvider.overrideWithValue(prefs),
      rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
      servicioConsultorioProvider.overrideWithValue(b.servicio),
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
  // Deja guardar los datos del médico (espera de 400 ms).
  await t.pump(const Duration(milliseconds: 500));
  return (router, c);
}

Future<(BancoConsultorio, String)> _conPaciente() async {
  final b = BancoConsultorio(ahora: _ahora);
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

Future<Cita> _agendar(BancoConsultorio b, String id, DateTime inicio) =>
    b.servicio.agenda.guardar(
      b.servicio.agenda.nueva(
        tipo: TipoCita.control,
        inicio: inicio,
        pacienteId: id,
      ),
    );

Future<void> _pulsar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _ctrlK(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyEvent(LogicalKeyboardKey.keyK);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'abre en el Inicio: el siguiente paciente, «Empezar consulta» y después',
    (t) async {
      final (b, id) = await _conPaciente();
      final primera = await _agendar(b, id, DateTime(2026, 11, 20, 10));
      await _agendar(b, id, DateTime(2026, 11, 20, 11));
      final (router, c) = await _montar(t, b);

      expect(find.text('Viernes 20 de noviembre'), findsOneWidget);
      expect(find.text('Buenos días, Dra. Ana Pérez Gómez'), findsOneWidget);
      expect(
        find.text('Tu siguiente paciente · 10:00, en 30 minutos'),
        findsOneWidget,
      );
      expect(find.textContaining('PEÑA'), findsWidgets);
      expect(find.text('Agendada'), findsOneWidget);
      // La segunda cita va en «Después»; nada pendiente.
      expect(find.text('Después'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);
      expect(find.text('Todo al día'), findsOneWidget);
      expect(find.text('Tu día en números'), findsOneWidget);
      expect(find.byType(IlustracionMarca), findsWidgets);

      await _pulsar(t, find.text('Empezar consulta'));
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(b.servicio.agenda.cita(primera.id)!.estado, EstadoCita.atendida);
      expect(c.read(historiaProvider).abierta, isTrue);
      await t.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('sin citas: lo dice con su ilustración y ofrece «Nueva cita»', (
    t,
  ) async {
    final (b, _) = await _conPaciente();
    await _montar(t, b);
    expect(find.text('No tienes citas hoy'), findsOneWidget);
    expect(find.text('Nueva cita'), findsOneWidget);
    expect(find.text('Ver la agenda'), findsWidgets);
  });

  testWidgets(
    'en el modo presentación no muestra montos de la caja ni el motivo',
    (t) async {
      final (b, id) = await _conPaciente();
      await b.servicio.agenda.guardar(
        b.servicio.agenda
            .nueva(
              tipo: TipoCita.control,
              inicio: DateTime(2026, 11, 20, 10),
              pacienteId: id,
            )
            .copyWith(motivo: 'Control de tiroides'),
      );
      final (_, c) = await _montar(t, b);
      expect(find.textContaining('Control de tiroides'), findsOneWidget);
      expect(find.text('Caja de hoy'), findsOneWidget);
      expect(find.text('Por cobrar'), findsOneWidget);
      c.read(modoPresentacionProvider.notifier).cambiar(true);
      await t.pumpAndSettle();
      expect(find.text('Caja de hoy'), findsNothing);
      expect(find.text('Por cobrar'), findsNothing);
      expect(find.textContaining('Control de tiroides'), findsNothing);
      expect(find.text('Citas'), findsOneWidget);
    },
  );

  testWidgets(
    'el riel empieza por Inicio, con «Buscar» (sin «Nueva consulta»)',
    (t) async {
      final (b, _) = await _conPaciente();
      await _montar(t, b);
      final riel = t.widget<NavigationRail>(find.byType(NavigationRail));
      expect(riel.selectedIndex, 0);
      expect(find.byTooltip('Buscar (Ctrl + K)'), findsOneWidget);
      expect(find.byTooltip('Nueva consulta'), findsNothing);
    },
  );

  testWidgets(
    'buscador: Ctrl + K, «pena» sin tilde encuentra a PEÑA y Enter abre la '
    'ficha; también lleva a las pantallas',
    (t) async {
      final (b, id) = await _conPaciente();
      final (router, _) = await _montar(t, b);
      await _ctrlK(t);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Pacientes recientes'.toUpperCase()), findsOneWidget);
      await t.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        'pena',
      );
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.textContaining('PEÑA'),
        ),
        findsOneWidget,
      );
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/pacientes/$id');

      await _ctrlK(t);
      await t.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        'caja',
      );
      await t.pumpAndSettle();
      await _pulsar(t, find.text('Ir a Caja'));
      expect(router.routeInformationProvider.value.uri.path, '/caja');

      await _ctrlK(t);
      await t.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        'zzzz',
      );
      await t.pumpAndSettle();
      expect(find.text('Nada coincide con «zzzz»'), findsOneWidget);
    },
  );
}
