import 'package:flutter/material.dart';

import '../../../app/tema.dart';

/// Chip para elegir varias opciones (zonas). El de Material deja el texto
/// oscuro sobre el fondo seleccionado; aquí va en blanco (≥ 4,5:1), sin
/// tocar el tema que comparte el sitio público.
class ChipSeleccion extends StatelessWidget {
  const ChipSeleccion({
    super.key,
    required this.texto,
    required this.seleccionado,
    required this.alCambiar,
    this.icono,
  });

  final String texto;
  final bool seleccionado;
  final ValueChanged<bool> alCambiar;
  final IconData? icono;

  @override
  Widget build(BuildContext context) => FilterChip(
    avatar: icono == null
        ? null
        : Icon(
            icono,
            size: 18,
            color: seleccionado ? Colors.white : ColoresMarca.tinta,
          ),
    label: Text(texto),
    selected: seleccionado,
    onSelected: alCambiar,
    checkmarkColor: Colors.white,
    labelStyle: TextStyle(
      color: seleccionado ? Colors.white : ColoresMarca.tinta,
      fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w400,
    ),
  );
}
