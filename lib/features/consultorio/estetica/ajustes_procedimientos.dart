import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/documentos/plantillas.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import '../widgets/editor_versionado.dart';

/// Ajustes → Procedimientos: plantillas declarativas (hidrolipoclasia) con
/// versiones; sin el protocolo completo no se pueden aprobar ni usar.
class TarjetaProcedimientos extends ConsumerWidget {
  const TarjetaProcedimientos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final procedimientos = ref.read(servicioConsultorioProvider).procedimientos;
    return TarjetaConsultorio(
      icono: Icons.spa_outlined,
      titulo: 'Procedimientos',
      subtitulo: 'Valoración, protocolo y consentimiento por procedimiento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cada procedimiento es una plantilla con versiones: los criterios '
            'de la valoración, el protocolo de la sesión y los textos del '
            'consentimiento. La app no trae composiciones, volúmenes ni dosis: '
            'los escribes tú y apruebas la plantilla (VERIFICAR).',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          for (final p in procedimientos.plantillas)
            FilaVersionada(
              nombre: p.nombre,
              versiones: [
                for (final v in p.versiones)
                  VersionPlantilla(
                    version: v.version,
                    titulo: v.definicion.nombre,
                    cuerpo: '',
                    aprobadaEn: v.aprobadaEn,
                  ),
              ],
              textoAprobar:
                  'Desde ahora las valoraciones y sesiones nuevas de '
                  '«${p.nombre}» usan este protocolo.',
              alEditar: () => context.go('/ajustes/procedimientos/${p.id}'),
              alAprobar: () async {
                await ref
                    .read(servicioConsultorioProvider)
                    .procedimientos
                    .aprobar(p.id);
                ref.read(versionIndiceProvider.notifier).cambio();
              },
              extra: [
                if (p.borrador != null &&
                    p.borrador!.definicion.faltantes.isNotEmpty)
                  Text(
                    'Falta: ${p.borrador!.definicion.faltantes.join(', ')}.',
                    style: const TextStyle(color: ColoresMarca.aviso),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
