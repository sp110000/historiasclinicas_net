import 'package:flutter/material.dart';

import '../../app/tema.dart';
import 'recuadro_icono.dart';

/// Título de diálogo 2b: alineado a la izquierda, con el ícono en un
/// recuadro con tinte. Sustituye a `AlertDialog(icon: …)`, que centra el
/// título.
class TituloDialogo extends StatelessWidget {
  const TituloDialogo(
    this.texto, {
    super.key,
    this.icono,
    this.color = ColoresMarca.primario,
  });

  final String texto;
  final IconData? icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (icono == null) return Text(texto);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RecuadroIcono(icono!, color: color, lado: 40, tamanoIcono: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(texto),
          ),
        ),
      ],
    );
  }
}
