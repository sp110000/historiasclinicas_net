import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/imagenes/series_medidas.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import 'grafica_seguimiento.dart';

/// Las medidas de las ecografías cerradas del paciente, graficadas en el
/// tiempo. No se muestra si no hay ninguna.
class MedidasEcografia extends ConsumerStatefulWidget {
  const MedidasEcografia({super.key, required this.pacienteId});

  final String pacienteId;

  @override
  ConsumerState<MedidasEcografia> createState() => _MedidasEcografiaState();
}

class _MedidasEcografiaState extends ConsumerState<MedidasEcografia> {
  var _elegida = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(versionIndiceProvider);
    final series = seriesMedidasEco(
      ref
          .read(servicioConsultorioProvider)
          .imagenes
          .estudiosDe(widget.pacienteId),
    );
    if (series.isEmpty) return const SizedBox.shrink();
    final i = _elegida < series.length ? _elegida : 0;
    final s = series[i];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Medidas de ecografía',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final (k, x) in series.indexed)
                ChoiceChip(
                  label: Text(x.etiqueta),
                  selected: k == i,
                  onSelected: (_) => setState(() => _elegida = k),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GraficaSeguimiento(
            puntos: s.puntos,
            nombre: s.nombre,
            unidad: s.unidad,
            decimales: 1,
          ),
        ],
      ),
    );
  }
}
