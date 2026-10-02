import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/main.dart';

void main() {
  testWidgets('muestra el formulario de historia nueva', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const HistoriasClinicasApp());

    expect(find.text('historiasclinicas.net'), findsOneWidget);
    expect(find.text('Historia nueva'), findsOneWidget);
    expect(find.text('Finalizar y guardar PDF'), findsOneWidget);
    expect(find.text('Abrir historia existente'), findsOneWidget);
  });

  testWidgets('no permite finalizar con campos obligatorios vacíos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const HistoriasClinicasApp());

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombres *'), '');
    await tester.tap(find.text('Finalizar y guardar PDF'));
    await tester.pump();

    expect(find.text('Campo obligatorio'), findsOneWidget);
    expect(find.text('Historia nueva'), findsOneWidget);
  });
}
