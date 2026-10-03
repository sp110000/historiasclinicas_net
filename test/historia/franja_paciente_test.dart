import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/models/historia.dart';
import 'package:historiasclinicas_net/features/historia/widgets/franja_paciente.dart';

import '../ejemplos.dart';

Future<void> mostrar(
  WidgetTester t,
  HistoriaClinica h, {
  double ancho = 1400,
  bool ocupado = false,
}) async {
  t.view
    ..physicalSize = Size(ancho, 800)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: temaClaro(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('barra'),
          bottom: franjaPaciente(h, ocupado: ocupado, movil: ancho < 700),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('muestra paciente, documento, edad y alergias', (t) async {
    final h = historiaCompleta();
    await mostrar(t, h);
    final texto = t.widget<Text>(find.textContaining('Documento')).textSpan!;
    expect(texto.toPlainText(), contains(h.paciente.nombreCompleto));
    expect(texto.toPlainText(), contains('Edad'));
    expect(find.bySemanticsLabel('Alergias: Penicilina, AINEs'), findsOne);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('«Niega alergias» sale neutro, sin ícono de advertencia', (
    t,
  ) async {
    final h = historiaCompleta().copyWith(
      antecedentes: const Antecedentes(niegaAlergias: true),
    );
    await mostrar(t, h);
    expect(find.text('Niega alergias conocidas'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('sin nombre no hay franja; al guardar queda la barra', (t) async {
    final vacia = HistoriaClinica.nueva(pais: historiaCompleta().pais);
    expect(franjaPaciente(vacia, ocupado: false, movil: false), isNull);
    await mostrar(t, vacia, ocupado: true);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('Documento'), findsNothing);
  });

  testWidgets('en un móvil de 320 px no se desborda con alergias largas', (
    t,
  ) async {
    final h = historiaCompleta().copyWith(
      antecedentes: const Antecedentes(
        alergias: [
          'Penicilina',
          'Ácido acetilsalicílico',
          'Ibuprofeno',
          'Mariscos',
        ],
      ),
    );
    await mostrar(t, h, ancho: 320);
    expect(t.takeException(), isNull);
    // El nombre conserva al menos la mitad del ancho.
    final nombre = t.getSize(find.textContaining('Documento'));
    expect(nombre.width, greaterThan(150));
  });
}
