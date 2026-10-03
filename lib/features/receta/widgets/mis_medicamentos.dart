import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/archivos/archivos.dart' as archivos;
import '../../../core/receta/medicamentos.dart';
import '../estado/receta_controller.dart';

Future<void> mostrarMisMedicamentos(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const DialogoMisMedicamentos(),
);

/// "Mis medicamentos": buscar, quitar, importar y exportar en JSON.
class DialogoMisMedicamentos extends ConsumerStatefulWidget {
  const DialogoMisMedicamentos({super.key});

  @override
  ConsumerState<DialogoMisMedicamentos> createState() =>
      _DialogoMisMedicamentosState();
}

class _DialogoMisMedicamentosState
    extends ConsumerState<DialogoMisMedicamentos> {
  var _consulta = '';
  String? _mensaje;
  var _mensajeEsError = false;

  void _avisar(String texto, {bool error = false}) => setState(() {
    _mensaje = texto;
    _mensajeEsError = error;
  });

  Future<void> _importar() async {
    final archivo = await archivos.elegirJson();
    if (archivo == null) return;
    try {
      final r = await ref
          .read(misMedicamentosProvider.notifier)
          .importar(utf8.decode(archivo.bytes, allowMalformed: true));
      _avisar('Importados de ${archivo.nombre}: ${r.resumen}.');
    } on FormatException catch (e) {
      _avisar('No se pudo importar: ${e.message}.', error: true);
    }
  }

  void _exportar() {
    final json = ref.read(misMedicamentosProvider.notifier).exportar();
    archivos.descargar(
      'mis_medicamentos.json',
      utf8.encode(json),
      tipo: 'application/json',
    );
    _avisar('Se descargó mis_medicamentos.json.');
  }

  @override
  Widget build(BuildContext context) {
    final lista = ref.watch(misMedicamentosProvider);
    final visibles = buscarPlantillas(lista, _consulta, maximo: 500);
    return AlertDialog(
      title: const Text('Mis medicamentos'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Se guardan desde cada medicamento de la receta (botón '
              '"Guardar en Mis medicamentos") y se sugieren al escribir. '
              'Viven solo en este navegador: exporta un respaldo o impórtalos '
              'en otro equipo.',
              style: TextStyle(color: ColoresMarca.textoSuave),
            ),
            const SizedBox(height: 12),
            if (lista.isNotEmpty)
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _consulta = v),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: lista.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Aún no tienes medicamentos guardados.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final p in visibles)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(p.etiqueta),
                            subtitle: p.detalle.isEmpty
                                ? null
                                : Text(p.detalle),
                            trailing: IconButton(
                              tooltip: 'Quitar de la lista',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => ref
                                  .read(misMedicamentosProvider.notifier)
                                  .eliminar(p),
                            ),
                          ),
                      ],
                    ),
            ),
            if (_mensaje != null) ...[
              const SizedBox(height: 8),
              Text(
                _mensaje!,
                style: TextStyle(
                  color: _mensajeEsError
                      ? ColoresMarca.error
                      : ColoresMarca.estadoOk,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _importar,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Importar JSON'),
        ),
        TextButton.icon(
          onPressed: lista.isEmpty ? null : _exportar,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Exportar JSON'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
