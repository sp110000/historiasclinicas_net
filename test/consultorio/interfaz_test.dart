// Fase 5.0: interfaz del consultorio con la bandera encendida (contenedor,
// crear frase, código de recuperación, desbloqueo, inactividad, aviso de
// respaldo, móvil y 320 px).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/seguridad/llavero.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/ajustes/ajustes_page.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';

Future<ProviderContainer> _montar(
  WidgetTester t, {
  required BancoConsultorio banco,
  String ruta = '/ajustes',
  Size tamano = const Size(1440, 1000),
}) async {
  t.view
    ..physicalSize = tamano
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      preferenciasProvider.overrideWithValue(prefs),
      rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
      servicioConsultorioProvider.overrideWithValue(banco.servicio),
    ],
  );
  addTearDown(container.dispose);
  final router = crearRouterConsultorio(ubicacionInicial: ruta);
  addTearDown(router.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
  return container;
}

Finder _campo(String etiqueta) =>
    find.ancestor(of: find.text(etiqueta), matching: find.byType(TextField));

Future<void> _escribir(WidgetTester t, String etiqueta, String texto) async {
  await t.ensureVisible(_campo(etiqueta).first);
  await t.enterText(_campo(etiqueta).first, texto);
  await t.pump();
}

Future<void> _pulsar(WidgetTester t, String texto) async {
  await t.ensureVisible(find.text(texto).first);
  await t.pumpAndSettle();
  await t.tap(find.text(texto).first);
  await t.pumpAndSettle();
}

double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  testWidgets('primera vez: crear la frase, guardar el código y llegar a '
      'Ajustes', (t) async {
    final banco = BancoConsultorio();
    final c = await _montar(t, banco: banco);
    expect(find.text('Crea tu frase de acceso'), findsOneWidget);
    expect(find.text('Ajustes del consultorio'), findsNothing);

    await _escribir(t, 'Frase de acceso', 'corta');
    expect(find.textContaining('Muy corta'), findsOneWidget);
    await _escribir(t, 'Frase de acceso', fraseDePrueba);
    await _escribir(t, 'Repite la frase', fraseDePrueba);
    await _pulsar(t, 'Crear frase');

    expect(find.text('Guarda tu código de recuperación'), findsOneWidget);
    final codigo = c.read(consultorioProvider).codigoPendiente!;
    final boton = find.widgetWithText(FilledButton, 'Ya lo guardé, continuar');
    expect(t.widget<FilledButton>(boton).onPressed, isNull);
    final n = normalizarCodigo(codigo);
    await _escribir(t, 'Últimos 4 caracteres del código', n.substring(20));
    await _pulsar(t, 'Ya lo guardé, continuar');

    expect(find.text('Ajustes del consultorio'), findsOneWidget);
    expect(c.read(consultorioProvider).codigoPendiente, isNull);
    expect(
      find.text('Todavía no has respaldado el consultorio'),
      findsOneWidget,
    );
    expect(find.textContaining('Resolución 1995 de 1999'), findsOneWidget);
    // El aviso está fuera de las pantallas: debe heredar el estilo del tema
    // (sin el subrayado amarillo de «texto sin Material» ni otra fuente).
    final estilo = DefaultTextStyle.of(
      t.element(find.text('Todavía no has respaldado el consultorio')),
    ).style;
    expect(estilo.decoration, isNot(TextDecoration.underline));
    expect(estilo.fontFamily, 'Inter');
  });

  testWidgets('bloqueado: frase incorrecta muestra el error y la correcta '
      'abre', (t) async {
    final banco = BancoConsultorio();
    await banco.servicio.crear(fraseDePrueba);
    await banco.servicio.bloquear();
    await _montar(t, banco: banco);
    expect(find.text('El consultorio está bloqueado'), findsOneWidget);
    expect(
      find.text('Todavía no hay respaldos de este consultorio.'),
      findsOneWidget,
    );

    await t.enterText(_campo('Frase de acceso'), 'no es esta');
    await _pulsar(t, 'Desbloquear');
    expect(find.text('La frase o el código no son correctos.'), findsOneWidget);

    await t.enterText(_campo('Frase de acceso'), fraseDePrueba);
    await _pulsar(t, 'Desbloquear');
    expect(find.byType(AjustesConsultorioPage), findsOneWidget);
    expect(find.text('Ajustes del consultorio'), findsOneWidget);

    // «Bloquear ahora» vuelve al desbloqueo.
    await _pulsar(t, 'Bloquear ahora');
    expect(find.text('El consultorio está bloqueado'), findsOneWidget);
  });

  testWidgets('recuperar con el código de la hoja', (t) async {
    final banco = BancoConsultorio();
    final codigo = await banco.servicio.crear(fraseDePrueba);
    await banco.servicio.bloquear();
    await _montar(t, banco: banco);
    await _pulsar(t, '¿Olvidaste la frase? Usar el código');
    await _escribir(t, 'Código de recuperación', formatearCodigo(codigo));
    await _escribir(t, 'Frase nueva', 'una frase nueva bastante larga');
    await _escribir(
      t,
      'Repite la frase nueva',
      'una frase nueva bastante larga',
    );
    await _pulsar(t, 'Recuperar');
    expect(find.text('Ajustes del consultorio'), findsOneWidget);
  });

  testWidgets('la historia funciona con el consultorio bloqueado', (t) async {
    final banco = BancoConsultorio();
    await banco.servicio.crear(fraseDePrueba);
    await banco.servicio.bloquear();
    await _montar(t, banco: banco, ruta: '/', tamano: const Size(1920, 1200));
    expect(find.text('HISTORIA NUEVA'), findsOneWidget);
    expect(find.text('El consultorio está bloqueado'), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('el riel es accesible también sobre las pantallas con su '
      'propia barra (historia)', (t) async {
    final semantica = t.ensureSemantics();
    final banco = BancoConsultorio();
    await _montar(t, banco: banco, ruta: '/', tamano: const Size(1920, 1200));
    expect(find.bySemanticsLabel(RegExp('^Ajustes')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Historia')), findsOneWidget);
    expect(find.bySemanticsLabel('Consultorio bloqueado'), findsOneWidget);

    // Abierto y sin respaldo: el aviso también se lee.
    await banco.servicio.crear(fraseDePrueba);
    await t.pumpWidget(const SizedBox());
    await _montar(t, banco: banco, ruta: '/', tamano: const Size(1920, 1200));
    expect(
      find.bySemanticsLabel(RegExp('Todavía no has respaldado el consultorio')),
      findsOneWidget,
    );
    semantica.dispose();
  });

  testWidgets('se bloquea solo tras los minutos sin actividad', (t) async {
    final banco = BancoConsultorio();
    await banco.servicio.crear(fraseDePrueba);
    await banco.servicio.bloquear();
    await _montar(t, banco: banco);
    await t.enterText(_campo('Frase de acceso'), fraseDePrueba);
    await _pulsar(t, 'Desbloquear');
    expect(find.text('Ajustes del consultorio'), findsOneWidget);

    await t.pump(const Duration(minutes: 9));
    expect(find.text('Ajustes del consultorio'), findsOneWidget);
    await t.pump(const Duration(minutes: 1, seconds: 1));
    await t.pumpAndSettle();
    expect(find.text('El consultorio está bloqueado'), findsOneWidget);
    expect(
      find.text('El consultorio se bloqueó por inactividad.'),
      findsOneWidget,
    );
  });

  testWidgets('el aviso de respaldo sale cuando se vence el plazo', (t) async {
    final banco = BancoConsultorio();
    await banco.servicio.crear(fraseDePrueba);
    await banco.servicio.respaldar();
    banco.reloj.avanzar(const Duration(days: 8));
    await banco.servicio.bloquear();
    final c = await _montar(t, banco: banco);
    await t.enterText(_campo('Frase de acceso'), fraseDePrueba);
    await _pulsar(t, 'Desbloquear');
    expect(find.text('Último respaldo hace 8 días'), findsOneWidget);
    expect(c.read(consultorioProvider).respaldo, isNotNull);
  });

  testWidgets('móvil: menú lateral en lugar del riel', (t) async {
    final banco = BancoConsultorio();
    await banco.servicio.crear(fraseDePrueba);
    await _montar(t, banco: banco, ruta: '/', tamano: const Size(390, 844));
    expect(find.byType(NavigationRail), findsNothing);
    await t.tap(find.byTooltip('Menú del consultorio'));
    await t.pumpAndSettle();
    expect(find.text('Ajustes'), findsOneWidget);
    await t.tap(find.text('Ajustes'));
    await t.pumpAndSettle();
    expect(find.text('Ajustes del consultorio'), findsOneWidget);
  });

  for (final pantalla in ['crear', 'bloqueado', 'ajustes']) {
    testWidgets('320 px sin desbordes: $pantalla', (t) async {
      final banco = BancoConsultorio();
      if (pantalla != 'crear') await banco.servicio.crear(fraseDePrueba);
      if (pantalla == 'bloqueado') await banco.servicio.bloquear();
      await _montar(t, banco: banco, tamano: const Size(320, 640));
      expect(t.takeException(), isNull);
      await t.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -2000),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  test('contraste de los textos nuevos (WCAG AA)', () {
    const blanco = Colors.white;
    final pares = <String, (Color, Color)>{
      'código sobre tinte': (ColoresMarca.tinta, ColoresMarca.tinte),
      'texto secundario sobre fondo': (
        ColoresMarca.textoSuave,
        ColoresMarca.fondo,
      ),
      'fortaleza débil': (ColoresMarca.aviso, blanco),
      'fortaleza fuerte': (ColoresMarca.estadoOk, blanco),
      'error': (ColoresMarca.error, blanco),
      'riel seleccionado': (ColoresMarca.primario, blanco),
      'riel sin seleccionar': (ColoresMarca.textoSuave, blanco),
    };
    for (final e in pares.entries) {
      expect(
        _contraste(e.value.$1, e.value.$2),
        greaterThanOrEqualTo(4.5),
        reason: e.key,
      );
    }
  });
}
