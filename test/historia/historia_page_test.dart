import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/app.dart';
import 'package:historiasclinicas_net/core/integridad/cadena_hash.dart';
import 'package:historiasclinicas_net/core/models/historia.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/historia/estado/historia_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';

Future<ProviderContainer> montar(WidgetTester tester) async {
  // Pantalla ancha: índice lateral y todas las acciones visibles.
  tester.view
    ..physicalSize = const Size(1920, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [preferenciasProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const HistoriasClinicasApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Deja correr el autoguardado del borrador (temporizador de 700 ms).
Future<void> terminar(WidgetTester t) => t.pump(const Duration(seconds: 1));

/// Desplaza hasta el widget y lo pulsa (la página es larga).
Future<void> pulsar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
}

Finder campo(String etiqueta) =>
    find.ancestor(of: find.text(etiqueta), matching: find.byType(TextField));

void main() {
  testWidgets('muestra las 11 secciones y las acciones principales', (t) async {
    await montar(t);
    for (final titulo in [
      '1 · Datos del paciente',
      '2 · Motivo de consulta y enfermedad actual',
      '3 · Antecedentes',
      '4 · Revisión de síntomas por sistemas',
      '5 · Signos vitales',
      '6 · Examen físico',
      '7 · Análisis',
      '8 · Diagnósticos',
      '9 · Plan de tratamiento e indicaciones',
      '10 · Firma y sello',
      '11 · Evoluciones',
    ]) {
      expect(find.text(titulo), findsOneWidget, reason: titulo);
    }
    expect(find.text('Abrir historia existente'), findsOneWidget);
    expect(find.text('Limpiar formulario'), findsOneWidget);
    expect(find.text('Imprimir / Guardar PDF'), findsOneWidget);
    expect(find.text('Formular receta'), findsOneWidget);
    expect(find.text('HISTORIA NUEVA'), findsOneWidget);
  });

  testWidgets('calcula edad e IMC mientras se escribe', (t) async {
    await montar(t);
    await t.enterText(campo('Fecha de nacimiento *'), '15031990');
    await t.enterText(campo('Peso'), '64,5');
    await t.enterText(campo('Talla'), '162');
    await t.pump();
    expect(find.textContaining('kg/m² · Normal'), findsOneWidget);
    expect(find.textContaining('años'), findsWidgets);
    await terminar(t);
  });

  testWidgets('avisa en ámbar fuera de lo habitual y en rojo lo imposible', (
    t,
  ) async {
    await montar(t);
    await t.enterText(campo('FC'), '130');
    await t.pump();
    expect(find.text('Fuera de lo habitual (60–100)'), findsOneWidget);
    await t.enterText(campo('FC'), '780');
    await t.pump();
    expect(find.text('Valor no plausible'), findsOneWidget);
    await terminar(t);
  });

  testWidgets('no deja finalizar si faltan datos y dice cuáles', (t) async {
    await montar(t);
    await t.tap(find.text('Imprimir / Guardar PDF'));
    await t.pumpAndSettle();
    await t.tap(find.text('Finalizar y guardar PDF'));
    await t.pumpAndSettle();
    expect(find.text('Faltan datos para finalizar'), findsOneWidget);
    expect(find.text('• Primer apellido'), findsOneWidget);
    expect(find.text('• Al menos un diagnóstico'), findsOneWidget);
  });

  testWidgets('alergias: etiquetas y "niega alergias" se excluyen', (t) async {
    final c = await montar(t);
    await t.enterText(
      campo('Alergia (medicamento, alimento, otro)'),
      'Penicilina,',
    );
    await t.pump();
    expect(find.widgetWithText(InputChip, 'Penicilina'), findsOneWidget);
    expect(c.read(historiaProvider).historia.antecedentes.alergias, [
      'Penicilina',
    ]);
    await t.ensureVisible(find.text('Niega alergias conocidas'));
    await t.pumpAndSettle();
    await t.tap(find.text('Niega alergias conocidas'));
    await t.pump();
    final a = c.read(historiaProvider).historia.antecedentes;
    expect(a.niegaAlergias, isTrue);
    expect(a.alergias, isEmpty);
    await terminar(t);
  });

  testWidgets('historia abierta: todo bloqueado salvo las evoluciones', (
    t,
  ) async {
    final c = await montar(t);
    c
        .read(historiaProvider.notifier)
        .abrir(
          sellarBase(historiaCompleta().aMapa()),
          revision: 1,
          nombreArchivo: 'Historia_PENA_1032456789.pdf',
        );
    await t.pumpAndSettle();

    expect(find.text('HISTORIA ABIERTA'), findsOneWidget);
    expect(
      find.textContaining('Historia abierta · Historia_PENA'),
      findsOneWidget,
    );
    expect(find.textContaining('Integridad verificada'), findsOneWidget);
    expect(find.text('Solo lectura'), findsNWidgets(10));
    expect(campo('Primer apellido *'), findsNothing);
    expect(find.text('Descargar historia actualizada'), findsOneWidget);

    await pulsar(t, find.text('Agregar evolución'));
    await t.pumpAndSettle();
    expect(campo('Nueva evolución *'), findsOneWidget);
    expect(c.read(historiaProvider).evolucionesNuevas, hasLength(1));
    await terminar(t);
  });

  testWidgets('una sección bloqueada se despliega al pulsarla', (t) async {
    final c = await montar(t);
    c
        .read(historiaProvider.notifier)
        .abrir(sellarBase(historiaCompleta().aMapa()), revision: 1);
    await t.pumpAndSettle();
    expect(find.text('Hipotiroidismo'), findsNothing);
    await pulsar(t, find.text('3 · Antecedentes'));
    await t.pumpAndSettle();
    expect(find.text('Hipotiroidismo'), findsOneWidget);
  });

  testWidgets('"Formular receta" precarga los datos y vuelve sin perder nada', (
    t,
  ) async {
    final c = await montar(t);
    c.read(historiaProvider.notifier).actualizar((_) => historiaCompleta());
    await t.pumpAndSettle();
    await t.tap(find.text('Formular receta'));
    await t.pumpAndSettle();
    expect(find.text('PEÑA MUÑOZ, José Ángel'), findsOneWidget);
    expect(find.text('J02.9 Faringitis aguda; R50.9 Fiebre'), findsOneWidget);
    expect(find.text('Penicilina, AINEs'), findsOneWidget);
    await t.tap(find.text('Volver a la historia'));
    await t.pumpAndSettle();
    expect(c.read(historiaProvider).historia.paciente.nombres, 'José Ángel');
    await terminar(t);
  });

  testWidgets(
    'revisión por sistemas: refiere con detalle y marcar pendientes',
    (t) async {
      final c = await montar(t);
      final refiere = find.widgetWithText(ChoiceChip, 'Refiere').first;
      await t.ensureVisible(refiere);
      await t.pumpAndSettle();
      await t.tap(refiere);
      await t.pump();
      await t.enterText(campo('Qué refiere · Generales'), 'Fiebre y astenia');
      await pulsar(t, find.text('Marcar los pendientes como «Niega»'));
      await t.pump();
      final r = c.read(historiaProvider).historia.revisionSistemas;
      expect(r.de('generales').estado, EstadoSistema.refiere);
      expect(r.de('generales').detalle, 'Fiebre y astenia');
      expect(r.completa, isTrue);
      expect(r.conEstado(EstadoSistema.niega), hasLength(11));
      expect(find.text('12 de 12 sistemas registrados'), findsOneWidget);
      await terminar(t);
    },
  );

  testWidgets('tipo de consulta incluye "Interconsulta"', (t) async {
    final c = await montar(t);
    await t.tap(find.widgetWithText(ChoiceChip, 'Interconsulta'));
    await t.pump();
    expect(c.read(historiaProvider).historia.tipoConsulta, 'interconsulta');
    await terminar(t);
  });
}
