import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/consultorio/verificar/verificar.dart';

/// [texto] sin sus notas «VERIFICAR». Desde el 27/11/2026 la app no muestra
/// las marcas «Por verificar» (lo normativo lo revisa el médico); las notas
/// siguen en los documentos del proyecto. Para etiquetas, ayudas y
/// mensajes.
String textoPresentable(WidgetRef ref, String texto) =>
    separarVerificar(texto).limpio;

/// Como [textoPresentable], fuera de `build` (en una acción).
String textoPresentableAhora(WidgetRef ref, String texto) =>
    separarVerificar(texto).limpio;

/// Un texto que puede llevar notas «VERIFICAR»: se muestra limpio, sin la
/// nota ni marca (pregunta 50; sin chips desde el 27/11/2026).
class TextoNormativo extends StatelessWidget {
  const TextoNormativo(
    this.texto, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String texto;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Text(
    separarVerificar(texto).limpio,
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
  );
}
