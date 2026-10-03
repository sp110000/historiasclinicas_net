import 'package:flutter/material.dart';

import '../../../app/tema.dart';
import '../../../core/models/historia.dart';
import '../../../core/receta/receta.dart' show PacienteReceta;

/// Franja de solo lectura bajo la barra superior (diseño 2b): paciente,
/// documento, edad y alergias. Debajo lleva la barra de progreso de 3 px
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

const _alto = 40.0;

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
        color: ColoresMarca.fondo,
        border: Border(top: BorderSide(color: ColoresMarca.borde)),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 13.5),
                children: [
                  TextSpan(
                    text: paciente.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
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

/// Alergias registradas en ámbar con ⚠; «Niega alergias», neutro.
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
          color: niega ? Colors.white : ColoresMarca.avisoFondo,
          borderRadius: RadiosMarca.pildora,
          border: Border.all(
            color: niega ? ColoresMarca.borde : ColoresMarca.avisoBorde,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!niega) ...[
              const Icon(
                Icons.warning_amber_rounded,
                size: 15,
                color: ColoresMarca.aviso,
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: niega ? FontWeight.w500 : FontWeight.w600,
                  color: niega
                      ? ColoresMarca.textoSuave
                      : ColoresMarca.avisoTexto,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
