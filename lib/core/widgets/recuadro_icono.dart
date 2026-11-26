import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Ícono dentro de un recuadro redondeado con el tinte de su color: avisos,
/// alertas de la receta, títulos de diálogo y tarjetas del consultorio.
class RecuadroIcono extends StatelessWidget {
  const RecuadroIcono(
    this.icono, {
    super.key,
    required this.color,
    this.lado = 36,
    this.tamanoIcono = 20,
  });

  final IconData icono;
  final Color color;
  final double lado;
  final double tamanoIcono;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: lado,
      height: lado,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ColoresMarca.sobreBlanco(color, 0.12),
        borderRadius: BorderRadius.circular(lado * 0.36),
      ),
      child: Icon(icono, color: color, size: tamanoIcono),
    );
  }
}
