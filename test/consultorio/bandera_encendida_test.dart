// Fase 5.0: con --dart-define=CONSULTORIO_ENABLED=true, la app usa el
// contenedor y las rutas del consultorio. La CI la corre con la bandera
// encendida (job «consultorio»); sin bandera se omite, porque lo que
// prueba es justamente la rama encendida.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:historiasclinicas_net/app/app.dart';
import 'package:historiasclinicas_net/app/router.dart';
import 'package:historiasclinicas_net/core/consultorio/config.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/shell/contenedor_consultorio.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';

const _soloEncendida = consultorioHabilitado
    ? null
    : 'Solo con --dart-define=CONSULTORIO_ENABLED=true (job «consultorio» de '
          'la CI)';

void main() {
  test(
    'crearRouter() usa el contenedor y las rutas del consultorio',
    () {
      final router = crearRouter();
      addTearDown(router.dispose);
      final shell = router.configuration.routes.single as ShellRoute;
      expect(shell.routes.cast<GoRoute>().map((r) => r.path).toList(), [
        '/',
        '/receta',
        '/medico',
        '/agenda',
        '/caja',
        '/pacientes',
        '/ajustes',
      ]);
      // Abre en la agenda de hoy (pregunta 51).
      expect(router.routeInformationProvider.value.uri.path, '/agenda');
      final pacientes = shell.routes.cast<GoRoute>().singleWhere(
        (r) => r.path == '/pacientes',
      );
      expect(pacientes.routes.cast<GoRoute>().single.path, ':id');
    },
    skip: _soloEncendida,
  );

  testWidgets(
    'la app muestra el riel y pide la frase en Ajustes',
    (t) async {
      t.view
        ..physicalSize = const Size(1920, 1200)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          preferenciasProvider.overrideWithValue(prefs),
          rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
          servicioConsultorioProvider.overrideWithValue(
            BancoConsultorio().servicio,
          ),
        ],
      );
      addTearDown(container.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HistoriasClinicasApp(),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(ContenedorConsultorio), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      // La agenda es la primera del riel y la que abre.
      expect(
        t.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
        0,
      );
      // Agenda, Pacientes, Historia, Caja y Ajustes (pregunta 51).
      expect(
        t
            .widget<NavigationRail>(find.byType(NavigationRail))
            .destinations
            .map((d) => (d.label as Text).data),
        ['Agenda', 'Pacientes', 'Historia', 'Caja', 'Ajustes'],
      );
      await t.tap(find.text('Ajustes'));
      await t.pumpAndSettle();
      expect(find.text('Crea tu frase de acceso'), findsOneWidget);
    },
    skip: _soloEncendida != null,
  );
}
