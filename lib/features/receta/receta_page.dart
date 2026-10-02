import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tema.dart';
import '../../core/presentacion/datos_historia.dart';
import '../../core/models/medico.dart';
import '../historia/estado/historia_controller.dart';
import '../medico/medico_provider.dart';

/// Receta de media hoja (Fase 3). Por ahora muestra los datos que se
/// precargarán desde la historia y comprueba que volver conserva lo escrito.
class RecetaPage extends ConsumerWidget {
  const RecetaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(historiaProvider.select((e) => e.historia));
    final p = h.paciente;
    final m = ref.watch(medicoProvider);
    final datos = <(String, String)>[
      (
        'Médico',
        m.configurado
            ? '${m.nombre.trim()} · ${etiquetaRegistro(h.pais)} ${m.registro.trim()}'
            : 'Sin configurar (Datos del médico)',
      ),
      ('Paciente', p.nombreCompleto),
      (
        'Documento',
        p.numeroDocumento.isEmpty
            ? ''
            : '${p.tipoDocumento} ${p.numeroDocumento}',
      ),
      ('Edad', h.edadTexto),
      (
        'Diagnósticos',
        h.diagnosticos
            .map((d) => d.textoCorto)
            .where((t) => t.isNotEmpty)
            .join('; '),
      ),
      ('Alergias', textoAlergias(h.antecedentes)),
    ];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver a la historia',
        ),
        title: const Text(
          'Receta',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ColoresMarca.borde),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          '℞',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: ColoresMarca.secundario,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'La receta de media hoja llega en la Fase 3',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Estos datos se precargarán desde la historia (y podrás editarlos):',
                      style: TextStyle(color: ColoresMarca.textoSuave),
                    ),
                    const SizedBox(height: 16),
                    for (final (etiqueta, valor) in datos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              etiqueta.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w600,
                                color: ColoresMarca.textoSuave,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              valor.isEmpty ? '—' : valor,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Volver a la historia'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
