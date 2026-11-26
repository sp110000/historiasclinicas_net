import 'package:flutter/material.dart';

import '../../../app/tema.dart';
import '../../../core/models/historia.dart';
import '../../../core/receta/receta.dart' show PacienteReceta;

/// Franja de solo lectura bajo la barra superior: iniciales, paciente,
/// documento, edad y alergias (en carmesí, siempre a la vista). Debajo lleva la barra de progreso de 3 px
/// que se ve mientras se guarda o se abre un PDF.
///
/// Devuelve `null` si no hay nombre de paciente ni nada en curso.
PreferredSizeWidget? franjaPaciente(
  HistoriaClinica historia, {
  required bool ocupado,
  required bool movil,
}) {
  final p = PacienteReceta.deHistoria(historia);
  final hayPaciente = p.nombre.trim().isNotEmpty;
  if (!hayPaciente && !ocupado) return null;
  return PreferredSize(
    preferredSize: Size.fromHeight((hayPaciente ? _alto : 0) + 3),
    child: Column(
      children: [
        if (hayPaciente)
          _Franja(
            paciente: p,
            niegaAlergias: historia.antecedentes.niegaAlergias,
            movil: movil,
          ),
        SizedBox(
          height: 3,
          child: ocupado
              ? const LinearProgressIndicator(minHeight: 3)
              : const SizedBox.shrink(),
        ),
      ],
    ),
  );
}

const _alto = 52.0;

class _Franja extends StatelessWidget {
  const _Franja({
    required this.paciente,
    required this.niegaAlergias,
    required this.movil,
  });

  final PacienteReceta paciente;
  final bool niegaAlergias;
  final bool movil;

  @override
  Widget build(BuildContext context) {
    TextSpan dato(String etiqueta, String valor) => TextSpan(
      children: [
        TextSpan(
          text: '$etiqueta  ',
          style: const TextStyle(color: ColoresMarca.textoSuave),
        ),
        TextSpan(
          text: valor,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: ColoresMarca.tinta,
          ),
        ),
      ],
    );
    final datos = [
      if (paciente.documento.isNotEmpty) dato('Documento', paciente.documento),
      if (paciente.edad.isNotEmpty) dato('Edad', paciente.edad),
    ];
    return Container(
      height: _alto,
      padding: EdgeInsets.symmetric(horizontal: movil ? 12 : 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColoresMarca.separador)),
      ),
      child: Row(
        children: [
          // En móvil el nombre tiene prioridad: sin iniciales.
          if (!movil) ...[
            ExcludeSemantics(
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: ColoresMarca.neutroFondo,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  iniciales(paciente.nombre),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ColoresMarca.tinta,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 13.5),
                children: [
                  TextSpan(
                    text: paciente.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: ColoresMarca.tinta,
                    ),
                  ),
                  for (final d in datos) ...[
                    const TextSpan(text: '   ·   '),
                    d,
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (paciente.alergias.isNotEmpty) ...[
            SizedBox(width: movil ? 10 : 16),
            // En móvil el nombre tiene prioridad: el chip se recorta.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: movil ? MediaQuery.sizeOf(context).width * 0.42 : 300,
              ),
              child: _ChipAlergias(
                texto: paciente.alergias,
                niega: niegaAlergias,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hasta dos iniciales del nombre: «Sofía Vargas» → «SV».
String iniciales(String nombre) {
  final partes = nombre
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  return partes.take(2).map((p) => p.characters.first.toUpperCase()).join();
}

/// Alergias registradas en carmesí con ⚠; «Niega alergias», neutro.
class _ChipAlergias extends StatelessWidget {
  const _ChipAlergias({required this.texto, required this.niega});

  final String texto;
  final bool niega;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Alergias: $texto',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: niega ? ColoresMarca.neutroFondo : ColoresMarca.errorFondo,
          borderRadius: RadiosMarca.pildora,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!niega) ...[
              const Icon(
                Icons.warning_amber_rounded,
                size: 15,
                color: ColoresMarca.error,
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: niega ? FontWeight.w600 : FontWeight.w800,
                  color: niega ? ColoresMarca.tintaSuave : ColoresMarca.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
