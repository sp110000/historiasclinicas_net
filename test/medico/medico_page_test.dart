import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/app.dart';
import 'package:historiasclinicas_net/core/integridad/cadena_hash.dart';
import 'package:historiasclinicas_net/core/models/historia.dart';
import 'package:historiasclinicas_net/core/models/medico.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/historia/estado/historia_controller.dart';
import 'package:historiasclinicas_net/features/medico/medico_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';

Future<ProviderContainer> montar(WidgetTester tester, {Medico? medico}) async {
  tester.view
    ..physicalSize = const Size(1920, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    Claves.pais: 'CO',
    if (medico != null) Claves.medico: jsonEncode(medico.aAlmacen()),
  });
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

/// Deja correr el autoguardado (borrador 700 ms, médico 400 ms).
Future<void> terminar(WidgetTester t) => t.pump(const Duration(seconds: 1));

Future<void> pulsar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Finder campo(String etiqueta) =>
    find.ancestor(of: find.text(etiqueta), matching: find.byType(TextField));

void main() {
  testWidgets('sin médico: avisa, se configura una vez y aparece en la firma', (
    t,
  ) async {
    final c = await montar(t);
    expect(find.text('Configura tus datos de médico'), findsOneWidget);
    expect(find.text('Aún no configuras tus datos de médico'), findsOneWidget);

    await pulsar(t, find.text('Configurar ahora').first);
    expect(find.text('Datos profesionales'), findsOneWidget);
    expect(find.text('Guardado en este navegador'), findsNothing);
    expect(
      find.widgetWithText(OutlinedButton, 'Borrar mis datos de este navegador'),
      findsOneWidget,
    );

    await t.enterText(campo('Nombre completo *'), 'Dra. Ana Pérez Gómez');
    await t.enterText(campo('Registro profesional *'), 'RM 54321');
    await t.pump();
    expect(find.text('Guardado en este navegador'), findsOneWidget);
    expect(find.text('Registro profesional RM 54321'), findsWidgets);
    await terminar(t);
    expect(c.read(medicoStoreProvider).leer().registro, 'RM 54321');

    await t.tap(find.byTooltip('Volver a la historia'));
    await t.pumpAndSettle();
    expect(find.text('Configura tus datos de médico'), findsNothing);
    await t.ensureVisible(find.text('Editar datos del médico'));
    expect(find.text('Dra. Ana Pérez Gómez'), findsOneWidget);
    expect(find.text('Registro profesional RM 54321'), findsOneWidget);
    await terminar(t);
  });

  testWidgets('la etiqueta del registro cambia con el país', (t) async {
    final c = await montar(t, medico: medicoEjemplo());
    await pulsar(t, find.byTooltip('Más opciones'));
    await pulsar(t, find.text('Datos del médico'));
    expect(campo('Registro profesional *'), findsOneWidget);

    await pulsar(t, find.widgetWithText(ChoiceChip, 'España'));
    expect(campo('N.º de colegiado *'), findsOneWidget);
    expect(find.text('N.º de colegiado RM 54321'), findsWidgets);
    expect(c.read(historiaProvider).historia.pais, Pais.espana);
    await terminar(t);
  });

  testWidgets('borrar los datos pide confirmación y los elimina', (t) async {
    final c = await montar(t, medico: medicoEjemplo());
    await pulsar(t, find.byTooltip('Más opciones'));
    await pulsar(t, find.text('Datos del médico'));
    await pulsar(t, find.text('Borrar mis datos de este navegador'));
    expect(find.text('¿Borrar tus datos de este navegador?'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await t.pumpAndSettle();
    expect(c.read(medicoProvider).vacio, isTrue);
    expect(c.read(medicoStoreProvider).leer().vacio, isTrue);
    expect(find.text('Configura tus datos de médico'), findsOneWidget);
    await terminar(t);
  });

  testWidgets('"Firma y sello" refleja los interruptores', (t) async {
    final c = await montar(t, medico: medicoEjemplo());
    expect(find.text('Configura tus datos de médico'), findsNothing);
    await t.ensureVisible(find.text('Editar datos del médico'));
    expect(find.text('Dra. Ana Pérez Gómez'), findsOneWidget);
    expect(find.text('(sin firma ni sello)'), findsNothing);

    await pulsar(t, find.text('Incluir firma'));
    await pulsar(t, find.text('Incluir sello'));
    expect(find.text('(sin firma ni sello)'), findsOneWidget);
    final f = c.read(historiaProvider).historia.firma;
    expect(f.incluirFirma, isFalse);
    expect(f.incluirSello, isFalse);
    await terminar(t);
  });

  testWidgets('finalizar sin médico ofrece configurarlo antes', (t) async {
    final c = await montar(t);
    c.read(historiaProvider.notifier).actualizar((_) => historiaCompleta());
    await t.pumpAndSettle();
    await t.tap(find.text('Imprimir / Guardar PDF'));
    await t.pumpAndSettle();
    await t.tap(find.text('Finalizar y guardar PDF'));
    await t.pumpAndSettle();
    expect(
      find.text('Aún no configuraste tus datos de médico'),
      findsOneWidget,
    );
    expect(find.text('Guardar sin mis datos'), findsOneWidget);

    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Configurar ahora'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Datos profesionales'), findsOneWidget);
    expect(c.read(historiaProvider).abierta, isFalse, reason: 'no se guardó');
    await terminar(t);
  });

  testWidgets('historia abierta: muestra quién la firmó y cada evolución', (
    t,
  ) async {
    final c = await montar(t, medico: medicoEjemplo());
    final copia = instantaneaMedico(medicoEjemplo(), pais: Pais.colombia);
    final otro = instantaneaMedico(
      const Medico(nombre: 'Dr. Luis Mora', registro: 'RM 999'),
      pais: Pais.colombia,
    );
    final datos = sellarEvoluciones(
      sellarBase({
        ...historiaCompleta().aMapa(),
        'medico': copia.autor,
        'recursos': copia.recursos,
      }),
      [
        {
          ...Evolucion(
            id: 'e1',
            fechaHora: DateTime(2026, 10, 9, 10, 30),
            texto: 'Afebril.',
          ).aMapa(),
          'autor': otro.autor,
        },
      ],
    );
    c.read(historiaProvider.notifier).abrir(datos, revision: 2);
    await t.pumpAndSettle();

    expect(find.textContaining('Integridad verificada'), findsOneWidget);
    expect(
      find.text('Dra. Ana Pérez Gómez · Firma sí · Sello sí'),
      findsOneWidget,
    );
    expect(
      find.text('Dr. Luis Mora · Registro profesional RM 999'),
      findsOneWidget,
    );

    await pulsar(t, find.text('Agregar evolución'));
    expect(
      find.text('Quedará a nombre de Dra. Ana Pérez Gómez'),
      findsOneWidget,
    );
    await terminar(t);
  });
}
