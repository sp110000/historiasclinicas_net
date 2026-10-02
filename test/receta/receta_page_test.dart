import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/app.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/cie10/cie10_provider.dart';
import 'package:historiasclinicas_net/features/historia/estado/historia_controller.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';

Future<ProviderContainer> montar(
  WidgetTester t, {
  Size tamano = const Size(1920, 1200),
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
    ],
  );
  addTearDown(c.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const HistoriasClinicasApp(),
    ),
  );
  await t.pumpAndSettle();
  return c;
}

/// Abre la receta de una historia con alergia a penicilina y AINEs.
Future<ProviderContainer> abrirReceta(
  WidgetTester t, {
  Size tamano = const Size(1920, 1200),
}) async {
  final c = await montar(t, tamano: tamano);
  c.read(historiaProvider.notifier).actualizar((_) => historiaCompleta());
  await t.pumpAndSettle();
  // En el móvil el botón de la barra inferior se llama "Receta".
  await t.tap(
    find.text(tamano.width < 700 ? 'Receta' : 'Formular receta').first,
  );
  await t.pumpAndSettle();
  return c;
}

Finder campo(String etiqueta, {int indice = 0}) => find
    .ancestor(of: find.text(etiqueta), matching: find.byType(TextField))
    .at(indice);

/// Deja correr los temporizadores (vista previa, autoguardado).
Future<void> terminar(WidgetTester t) => t.pump(const Duration(seconds: 1));

Future<void> escribir(WidgetTester t, Finder f, String texto) async {
  await t.ensureVisible(f);
  await t.enterText(f, texto);
  await t.pump();
}

Future<void> pulsar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> llenarAmoxicilina(WidgetTester t, {int indice = 0}) async {
  for (final (etiqueta, valor) in [
    ('Medicamento (DCI o genérico) *', 'Amoxicilina'),
    ('Concentración *', '500 mg'),
    ('Forma farmacéutica *', 'cápsula'),
    ('Dosis *', '1 cápsula'),
    ('Vía *', 'oral'),
    ('Frecuencia *', 'cada 8 horas'),
    ('Duración *', '7 días'),
  ]) {
    await escribir(t, campo(etiqueta, indice: indice), valor);
  }
  // Cierra las sugerencias abiertas.
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
}

void main() {
  // Las fuentes del PDF se cargan una sola vez y quedan en caché: fuera de
  // los testWidgets, para que la caché sirva en todos.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(FuentesPdf.cargar);

  testWidgets(
    'precarga, alerta de alergia, cantidad en letras y vista previa',
    (t) async {
      final c = await abrirReceta(t);
      expect(find.text('PEÑA MUÑOZ, José Ángel'), findsOneWidget);
      expect(find.text('Penicilina, AINEs'), findsOneWidget);

      await llenarAmoxicilina(t);
      expect(find.text('ALERTA DE ALERGIA'), findsOneWidget);
      expect(
        find.textContaining('pertenece al grupo de las penicilinas'),
        findsWidgets,
      );
      expect(find.text('cápsulas'), findsOneWidget, reason: 'unidad sugerida');

      await pulsar(t, find.text('Usar 21'));
      expect(c.read(recetaProvider).items.single.cantidad, 21);
      expect(find.text('(veintiuno)'), findsOneWidget);

      await pulsar(t, find.text('Entendido'));
      expect(find.text('ALERTA DE ALERGIA'), findsNothing);
      expect(find.text('1 alerta de alergia revisada.'), findsOneWidget);

      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp('Vista previa de la receta, hoja 1 de 1')),
        findsOneWidget,
      );
      expect(find.text('Vista previa · A5 · 1 hoja'), findsOneWidget);
      await terminar(t);
    },
  );

  testWidgets('agregar, bajar y quitar con deshacer', (t) async {
    final c = await abrirReceta(t);
    await pulsar(t, find.text('Agregar medicamento'));
    await pulsar(t, find.text('Agregar medicamento'));
    for (final (i, m) in ['Loratadina', 'Omeprazol', 'Paracetamol'].indexed) {
      await escribir(t, campo('Medicamento (DCI o genérico) *', indice: i), m);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    List<String> orden() => [
      for (final i in c.read(recetaProvider).items) i.medicamento,
    ];

    await pulsar(t, find.byTooltip('Bajar').first);
    expect(orden(), ['Omeprazol', 'Loratadina', 'Paracetamol']);
    expect(find.text('OMEPRAZOL'), findsOneWidget, reason: 'ahora es el 1');

    await pulsar(t, find.byTooltip('Quitar').first);
    expect(orden(), ['Loratadina', 'Paracetamol']);
    await t.tap(find.text('Deshacer'));
    await t.pumpAndSettle();
    expect(orden(), ['Omeprazol', 'Loratadina', 'Paracetamol']);
    await terminar(t);
  });

  testWidgets('antes de imprimir pide medicamentos y dice qué falta', (
    t,
  ) async {
    await abrirReceta(t);
    await t.tap(find.text('Imprimir'));
    await t.pumpAndSettle();
    expect(find.text('Agrega al menos un medicamento.'), findsOneWidget);

    await escribir(t, campo('Medicamento (DCI o genérico) *'), 'Loratadina');
    await t.tap(find.text('Imprimir'));
    await t.pumpAndSettle();
    expect(find.text('Faltan datos en la receta'), findsOneWidget);
    expect(
      find.text(
        '• Medicamento 1: concentración, forma farmacéutica, dosis, vía, '
        'frecuencia, duración, cantidad',
      ),
      findsOneWidget,
    );
    await t.tap(find.text('Revisar'));
    await t.pumpAndSettle();
    expect(find.text('Obligatorio'), findsWidgets);
    expect(find.text('Obligatoria'), findsOneWidget);
    await terminar(t);
  });

  testWidgets('"Mis medicamentos": guardar uno y reutilizarlo', (t) async {
    final c = await abrirReceta(t);
    await llenarAmoxicilina(t);
    await pulsar(t, find.byTooltip('Guardar en "Mis medicamentos"'));
    expect(
      c.read(misMedicamentosProvider).single.etiqueta,
      'Amoxicilina 500 mg · cápsula',
    );

    await pulsar(t, find.text('Agregar medicamento'));
    await escribir(
      t,
      campo('Medicamento (DCI o genérico) *', indice: 1),
      'amo',
    );
    await t.pumpAndSettle();
    await t.tap(find.textContaining('1 cápsula · oral · cada 8 horas'));
    await t.pumpAndSettle();
    final segundo = c.read(recetaProvider).items[1];
    expect(segundo.medicamento, 'Amoxicilina');
    expect(segundo.frecuencia, 'cada 8 horas');

    await pulsar(t, find.text('Mis medicamentos'));
    expect(find.text('Amoxicilina 500 mg · cápsula'), findsOneWidget);
    await t.tap(find.text('Cerrar'));
    await terminar(t);
  });

  testWidgets('móvil: pestañas Editar y Vista previa, botones abajo', (
    t,
  ) async {
    await abrirReceta(t, tamano: const Size(390, 844));
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Imprimir'), findsOneWidget);
    expect(find.text('Guardar PDF'), findsOneWidget);
    await t.tap(find.text('Vista previa'));
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('Vista previa de la receta, hoja 1')),
      findsOneWidget,
    );
    await terminar(t);
  });

  testWidgets('diagnóstico: catálogo CIE-10 incluido o importado', (t) async {
    final c = await montar(t);
    expect(
      find.textContaining('CIE-10 (SISPRO, 12.634 códigos)'),
      findsOneWidget,
    );

    await pulsar(t, find.text('Agregar diagnóstico'));
    final diagnostico = campo('Diagnóstico *');
    await escribir(t, diagnostico, 'faring');
    // La primera vez el catálogo se carga al entrar al campo.
    await t.runAsync(() => c.read(catalogoCie10Provider.future));
    await t.pumpAndSettle();
    await escribir(t, diagnostico, 'faringitis aguda');
    await t.pumpAndSettle();
    await t.tap(find.text('FARINGITIS AGUDA, NO ESPECIFICADA'));
    await t.pumpAndSettle();
    var d = c.read(historiaProvider).historia.diagnosticos.single;
    expect(d.codigo, 'J029');
    expect(d.descripcion, 'FARINGITIS AGUDA, NO ESPECIFICADA');

    // Un catálogo importado reemplaza al incluido.
    final muestra = File('test/fixtures/cie10_muestra.csv').readAsBytesSync();
    await t.runAsync(() async {
      await c.read(infoCie10Provider.notifier).importar('muestra.csv', muestra);
      await c.read(catalogoCie10Provider.future);
    });
    await t.pumpAndSettle();
    expect(
      find.textContaining('CIE-10 (importado, 30 códigos)'),
      findsOneWidget,
    );
    await pulsar(t, find.text('Agregar diagnóstico'));
    await escribir(t, campo('CIE-10', indice: 1), 'G43');
    await t.pumpAndSettle();
    expect(find.text('G439'), findsOneWidget, reason: 'solo el de la muestra');
    await t.tap(find.text('G439'));
    await t.pumpAndSettle();
    d = c.read(historiaProvider).historia.diagnosticos[1];
    expect(d.descripcion, 'MIGRAÑA, NO ESPECIFICADA');
    await terminar(t);
  });
}
