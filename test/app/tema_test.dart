import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/widgets/campos.dart';

void main() {
  // Un estilo sin familia sale con la fuente de respaldo del motor (Roboto),
  // no con Inter: pasa si un tema de componente reemplaza el estilo en vez
  // de mezclarlo.
  testWidgets('todos los textos del tema usan Inter', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: temaClaro(),
        home: Scaffold(
          body: Column(
            children: [
              const Text('cuerpo'),
              Text('título', style: temaClaro().textTheme.titleLarge),
              FilledButton(onPressed: () {}, child: const Text('relleno')),
              OutlinedButton(onPressed: () {}, child: const Text('contorno')),
              TextButton(onPressed: () {}, child: const Text('texto')),
              const Chip(label: Text('chip')),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'etiqueta',
                  hintText: 'pista',
                  helperText: 'ayuda',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    showDialog<void>(
      context: t.element(find.text('cuerpo')),
      builder: (_) =>
          const AlertDialog(title: Text('diálogo'), content: Text('contenido')),
    );
    await t.pumpAndSettle();
    final textos = {
      for (final p in t.renderObjectList<RenderParagraph>(
        find.byType(RichText),
      ))
        p.text.toPlainText(): _familia(p.text),
    };
    for (final texto in [
      'cuerpo',
      'título',
      'relleno',
      'contorno',
      'texto',
      'chip',
      'etiqueta',
      'pista',
      'ayuda',
      'diálogo',
      'contenido',
    ]) {
      expect(textos[texto], 'Inter', reason: texto);
    }
  });

  testWidgets('el desplegable usa el mismo texto que los campos', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: temaClaro(),
        home: Scaffold(
          body: CampoDesplegable(
            etiqueta: 'Tipo de documento',
            opciones: const [Opcion('CC', 'Cédula de ciudadanía')],
            valor: 'CC',
            mostrarCodigo: true,
            alCambiar: (_) {},
          ),
        ),
      ),
    );
    final valor = t
        .renderObject<RenderParagraph>(
          find.text('CC · Cédula de ciudadanía').first,
        )
        .text
        .style!;
    expect(valor.fontSize, 15);
    expect(valor.fontWeight, isNot(FontWeight.w600));
  });

  test('la etiqueta de los campos se ve a 13 px sobre el borde', () {
    final campos = temaClaro().inputDecorationTheme;
    expect(campos.floatingLabelBehavior, FloatingLabelBehavior.always);
    // Flutter dibuja la etiqueta flotante al 75 % de su tamaño.
    expect(campos.floatingLabelStyle!.fontSize! * 0.75, closeTo(13, 0.01));
  });

  test('los textos de la paleta cumplen el contraste AA sobre blanco', () {
    double contraste(Color a, Color b) {
      final (x, y) = (a.computeLuminance(), b.computeLuminance());
      return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
    }

    for (final (nombre, color) in [
      ('primario', ColoresMarca.primario),
      ('estadoOk', ColoresMarca.estadoOk),
      ('aviso', ColoresMarca.aviso),
      ('error', ColoresMarca.error),
      ('textoSuave', ColoresMarca.textoSuave),
      ('tinta', ColoresMarca.tinta),
      ('tintaSuave', ColoresMarca.tintaSuave),
      ('pista', ColoresMarca.pista),
    ]) {
      expect(
        contraste(color, Colors.white),
        greaterThanOrEqualTo(4.5),
        reason: nombre,
      );
    }
    expect(
      contraste(ColoresMarca.textoSuave, ColoresMarca.bloqueado),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contraste(ColoresMarca.avisoTexto, ColoresMarca.avisoFondo),
      greaterThanOrEqualTo(4.5),
    );
  });
}

/// Familia efectiva del primer tramo con texto.
String? _familia(InlineSpan span) {
  String? familia;
  span.visitChildren((s) {
    if (s is TextSpan && (s.text ?? '').isNotEmpty) {
      familia = s.style?.fontFamily ?? span.style?.fontFamily;
      return false;
    }
    return true;
  });
  return familia ?? span.style?.fontFamily;
}
