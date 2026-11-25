import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/verificar/verificar.dart';
import '../../../core/utils/fechas.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import '../widgets/texto_normativo.dart';

/// Ajustes → Verificaciones (pregunta 50b): las notas «VERIFICAR» que ya
/// marcaste, con la fecha y la fuente.
class TarjetaVerificaciones extends ConsumerWidget {
  const TarjetaVerificaciones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final todas = ref.read(servicioConsultorioProvider).verificaciones.todas;
    return TarjetaConsultorio(
      icono: Icons.verified_outlined,
      titulo: 'Verificaciones',
      subtitulo: todas.isEmpty
          ? 'Ninguna nota verificada todavía'
          : '${todas.length} ${todas.length == 1 ? 'nota verificada' : 'notas verificadas'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Lo que falta revisar con la norma, tu abogado o tu contador sale '
            'en cada pantalla con un chip «Por verificar». Tócalo para leer '
            'la nota completa y, cuando la verifiques, registrar la fecha y '
            'la fuente. El modo presentación oculta los chips, y los PDF '
            'nunca los imprimen.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          for (final v in todas)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: ColoresMarca.borde)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    separarVerificar(v.texto).notas.join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Verificada el ${formatoFecha(v.fecha)} · ${v.fuente}',
                    style: const TextStyle(color: ColoresMarca.estadoOk),
                  ),
                  TextButton(
                    onPressed: () => verificarNota(context, ref, v.texto),
                    child: const Text('Ver o quitar'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
