import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/features/consultorio/widgets/chip_seleccion.dart';

double _contraste(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

void main() {
  testWidgets('el chip elegido se lee: texto claro sobre el fondo (≥ 4,5:1)', (
    tester,
  ) async {
    var elegido = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaClaro(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ChipSeleccion(
              texto: 'Flancos',
              seleccionado: elegido,
              alCambiar: (si) => setState(() => elegido = si),
            ),
          ),
        ),
      ),
    );
    final fondo = temaClaro().chipTheme.selectedColor!;
    Color colorTexto() => tester
        .widget<RichText>(
          find
              .descendant(
                of: find.byType(ChipSeleccion),
                matching: find.byType(RichText),
              )
              .first,
        )
        .text
        .style!
        .color!;
    expect(_contraste(colorTexto(), fondo), greaterThanOrEqualTo(4.5));

    // Sin elegir: texto de tinta sobre blanco.
    await tester.tap(find.text('Flancos'));
    await tester.pumpAndSettle();
    expect(elegido, isFalse);
    expect(
      _contraste(colorTexto(), temaClaro().chipTheme.backgroundColor!),
      greaterThanOrEqualTo(4.5),
    );
  });
}
