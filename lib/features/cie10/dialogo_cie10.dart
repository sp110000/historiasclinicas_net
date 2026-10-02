import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../core/archivos/archivos.dart' as archivos;
import '../../core/cie10/catalogo_incluido.dart';
import '../../core/utils/fechas.dart';
import '../../core/utils/numeros.dart';
import 'cie10_provider.dart';

Future<void> mostrarCatalogoCie10(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const DialogoCatalogoCie10(),
);

/// Qué catálogo CIE-10 se usa: el incluido o uno importado en este
/// navegador.
class DialogoCatalogoCie10 extends ConsumerStatefulWidget {
  const DialogoCatalogoCie10({super.key});

  @override
  ConsumerState<DialogoCatalogoCie10> createState() =>
      _DialogoCatalogoCie10State();
}

class _DialogoCatalogoCie10State extends ConsumerState<DialogoCatalogoCie10> {
  var _ocupado = false;
  String? _mensaje;
  var _error = false;

  Future<void> _importar() async {
    final archivo = await archivos.elegirCatalogo();
    if (archivo == null) return;
    setState(() {
      _ocupado = true;
      _mensaje = null;
    });
    try {
      final l = await ref
          .read(infoCie10Provider.notifier)
          .importar(archivo.nombre, archivo.bytes);
      _mensaje =
          'Se importaron ${formatoMiles(l.catalogo.length)} códigos'
          '${l.omitidas > 0 ? ' (se omitieron ${formatoMiles(l.omitidas)} filas sin código)' : ''}.';
      _error = false;
    } on FormatException catch (e) {
      _mensaje = 'No se pudo importar: ${e.message}.';
      _error = true;
    } catch (e) {
      _mensaje = 'No se pudo guardar el catálogo en este navegador: $e';
      _error = true;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(infoCie10Provider);
    return AlertDialog(
      icon: const Icon(Icons.menu_book_outlined, color: ColoresMarca.primario),
      title: const Text('Catálogo CIE-10'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info == null
                    ? 'En uso: el incluido en la app'
                    : 'En uso: el importado en este navegador',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                info == null
                    ? '${CatalogoIncluido.fuente}: '
                          '${formatoMiles(CatalogoIncluido.cantidad)} códigos, '
                          'actualizada el '
                          '${formatoFecha(CatalogoIncluido.actualizado)}.'
                    : '${formatoMiles(info.cantidad)} códigos · ${info.archivo} · '
                          'importado el ${formatoFecha(info.importado)}.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Al escribir un diagnóstico o un código se sugieren las '
                'coincidencias, sin conexión.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Puedes importar otra versión: una tabla más reciente de SISPRO '
                '(el Excel tal como se descarga) o la CIE-10-ES de España. '
                'Reemplaza al incluido solo en este navegador.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Formatos: Excel (.xlsx), CSV, TXT o TSV (una fila por '
                'código, con el código y su descripción) o JSON.',
                style: TextStyle(fontSize: 13, color: ColoresMarca.textoSuave),
              ),
              if (_ocupado) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ],
              if (_mensaje != null) ...[
                const SizedBox(height: 14),
                Text(
                  _mensaje!,
                  style: TextStyle(
                    color: _error
                        ? ColoresMarca.error
                        : ColoresMarca.secundario,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (info != null)
          TextButton(
            onPressed: _ocupado
                ? null
                : () async {
                    await ref.read(infoCie10Provider.notifier).borrar();
                    setState(() {
                      _mensaje = 'Se volvió al catálogo incluido.';
                      _error = false;
                    });
                  },
            child: const Text('Volver al incluido'),
          ),
        TextButton.icon(
          onPressed: _ocupado ? null : _importar,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Importar otro…'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
