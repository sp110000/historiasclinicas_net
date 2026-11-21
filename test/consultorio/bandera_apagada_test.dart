// Fase 5.0: con CONSULTORIO_ENABLED apagada (por defecto), el sitio público
// se comporta exactamente como antes de la Fase 5.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:historiasclinicas_net/app/app.dart';
import 'package:historiasclinicas_net/app/router.dart';
import 'package:historiasclinicas_net/core/consultorio/config.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/ajustes/ajustes_page.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/shell/contenedor_consultorio.dart';
import 'package:historiasclinicas_net/features/historia/historia_page.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import '../../tool/consultorio/verificar_compilacion.dart' show marcaModulo;
import 'ayudas_consultorio.dart';

/// Monta la app tal como la publica `pages.yml`, contando si alguien pide
/// el servicio del consultorio (que abriría su base de IndexedDB).
Future<({ProviderContainer container, int Function() aperturas})> _montarApp(
  WidgetTester t,
  Size tamano,
) async {
  t.view
    ..physicalSize = tamano
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
  final prefs = await SharedPreferences.getInstance();
  var aperturas = 0;
  final container = ProviderContainer(
    overrides: [
      preferenciasProvider.overrideWithValue(prefs),
      rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
      servicioConsultorioProvider.overrideWith((ref) {
        aperturas++;
        return BancoConsultorio().servicio;
      }),
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
  return (container: container, aperturas: () => aperturas);
}

/// Textos de las opciones del menú «Más opciones», en orden y sin repetir
/// (la casilla `CheckboxMenuButton` lleva un `MenuItemButton` dentro).
List<String> _opcionesDelMenu(WidgetTester t) {
  final opciones = find.byWidgetPredicate(
    (w) => w is MenuItemButton || w is CheckboxMenuButton || w is SubmenuButton,
  );
  final textos = <String>[];
  for (final e in opciones.evaluate()) {
    final texto = t
        .widgetList<Text>(
          find.descendant(
            of: find.byWidget(e.widget),
            matching: find.byType(Text),
          ),
        )
        .map((x) => x.data ?? '')
        .join(' ');
    if (!textos.contains(texto)) textos.add(texto);
  }
  return textos;
}

void main() {
  test('la bandera está apagada por defecto', () {
    expect(consultorioHabilitado, isFalse);
  });

  test('el router público tiene exactamente las rutas de siempre', () {
    final router = crearRouter();
    addTearDown(router.dispose);
    final rutas = router.configuration.routes;
    expect(rutas.whereType<ShellRoute>(), isEmpty);
    expect(rutas.cast<GoRoute>().map((r) => r.path).toList(), [
      '/',
      '/receta',
      '/medico',
    ]);
  });

  for (final (nombre, tamano, esperadas) in [
    (
      'escritorio (1920 px)',
      const Size(1920, 1400),
      [
        'Datos del médico',
        'Sin borrador guardado',
        'No guardar borrador en este equipo',
        'Acerca de y limitaciones',
      ],
    ),
    (
      'móvil (390 px)',
      const Size(390, 844),
      [
        'Abrir historia existente',
        'Limpiar formulario',
        'País: Colombia',
        'Datos del médico',
        'Sin borrador guardado',
        'No guardar borrador en este equipo',
        'Acerca de y limitaciones',
      ],
    ),
  ]) {
    testWidgets('$nombre: la historia, su menú y la navegación son los de '
        'siempre, y nadie abre el almacén del consultorio', (t) async {
      final app = await _montarApp(t, tamano);
      expect(find.byType(HistoriaPage), findsOneWidget);
      expect(find.byType(ContenedorConsultorio), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byTooltip('Menú del consultorio'), findsNothing);

      await t.tap(find.byTooltip('Más opciones'));
      await t.pumpAndSettle();
      expect(_opcionesDelMenu(t), esperadas);
      await t.tapAt(Offset.zero);
      await t.pumpAndSettle();

      // /ajustes no existe: se ve la misma página de error que con
      // cualquier ruta desconocida, no los ajustes del consultorio.
      GoRouter.of(t.element(find.byType(HistoriaPage))).go('/ajustes');
      await t.pumpAndSettle();
      expect(find.byType(AjustesConsultorioPage), findsNothing);
      expect(find.byType(HistoriaPage), findsNothing);
      GoRouter.of(t.element(find.byType(Scaffold).first)).go('/');
      await t.pumpAndSettle();
      expect(find.byType(HistoriaPage), findsOneWidget);

      expect(app.aperturas(), 0);
      expect(app.container.exists(consultorioProvider), isFalse);
    });
  }

  test('ningún archivo público referencia el servicio fuera de la rama de '
      'la bandera', () {
    // El único punto de entrada al consultorio es crearRouter(), bajo
    // `if (consultorioHabilitado)`. Lo demás vive en lib/features/consultorio
    // y lib/core/consultorio.
    final fuera = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final ruta = f.path.replaceAll(r'\', '/');
      if (ruta.contains('/consultorio/')) continue;
      final texto = f.readAsStringSync();
      if (texto.contains('consultorio/') &&
          !ruta.endsWith('lib/app/router.dart')) {
        fuera.add(ruta);
      }
    }
    expect(fuera, isEmpty);
    final router = File('lib/app/router.dart').readAsStringSync();
    expect(
      router,
      contains('if (consultorioHabilitado) return crearRouterConsultorio();'),
    );
    // La marca que busca la verificación de la compilación es la del módulo.
    expect(marcaModulo, baseDeDatosConsultorio);
  });
}
