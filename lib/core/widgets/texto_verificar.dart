import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/consultorio/widgets/texto_normativo.dart';
import '../consultorio/config.dart';

/// Un texto con una nota «VERIFICAR» de las pantallas de siempre (historia,
/// receta, datos del médico). Con la bandera apagada es exactamente el
/// [Text] de siempre; con ella encendida, el del consultorio: el chip «Por
/// verificar» y el modo presentación (pregunta 50).
Widget textoConVerificar(String texto, {TextStyle? style}) {
  if (consultorioHabilitado) {
    return TextoNormativo(texto, style: style);
  }
  return Text(texto, style: style);
}

/// La ayuda de un campo con una nota «VERIFICAR»: igual que siempre con la
/// bandera apagada; con ella encendida, sin la nota en el modo presentación.
String? ayudaConVerificar(WidgetRef ref, String texto) {
  if (consultorioHabilitado) {
    final t = textoPresentable(ref, texto);
    return t.isEmpty ? null : t;
  }
  return texto;
}
