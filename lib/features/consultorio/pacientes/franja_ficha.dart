import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/indice/normalizar.dart';
import '../../historia/estado/historia_controller.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';

/// Sobre la historia: «← Ficha · PEÑA MUÑOZ, José Ángel · Penicilina»
/// cuando la historia en curso vino de una ficha y sigue siendo de ese
/// paciente.
class FranjaFicha extends ConsumerWidget {
  const FranjaFicha({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(fichaEnCursoProvider);
    if (id == null || !ref.watch(consultorioProvider).desbloqueado) {
      return const SizedBox.shrink();
    }
    ref.watch(versionIndiceProvider);
    final indice = ref.read(servicioConsultorioProvider).indice;
    final f = indice.ficha(id);
    final h = ref.watch(historiaProvider.select((e) => e.historia));
    if (f == null) return const SizedBox.shrink();
    final esDeLaFicha =
        indice.historia(h.id)?.pacienteId == f.id ||
        (claveDocumento(h.paciente.tipoDocumento, h.paciente.numeroDocumento) ??
                '') ==
            f.clave;
    if (!esDeLaFicha) return const SizedBox.shrink();
    final alergias = indice.alergiasDe(f.id)?.alergias ?? const [];
    final movil = MediaQuery.sizeOf(context).width < 700;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: movil ? 4 : 16, vertical: 2),
      decoration: const BoxDecoration(
        color: ColoresMarca.tinte,
        border: Border(bottom: BorderSide(color: ColoresMarca.borde)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => context.go('/pacientes/${f.id}'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Ficha'),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: f.nombreCompleto,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (alergias.isNotEmpty) ...[
                    const TextSpan(text: '  '),
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: ColoresMarca.error,
                        semanticLabel: 'Alergias',
                      ),
                    ),
                    TextSpan(
                      text: ' ${alergias.join(', ')}',
                      style: const TextStyle(color: ColoresMarca.error),
                    ),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
