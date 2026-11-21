import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/archivos/archivos.dart' as archivos;
import '../../../core/consultorio/respaldo/respaldo.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../historia/widgets/dialogos.dart';
import '../estado/consultorio_provider.dart';
import '../widgets/comunes.dart';

/// Arma el respaldo y lo descarga.
Future<void> respaldarYDescargar(BuildContext context, WidgetRef ref) async {
  try {
    final archivo = await ref.read(consultorioProvider.notifier).respaldar();
    archivos.descargar(
      archivo.nombre,
      archivo.bytes,
      tipo: FormatoRespaldo.tipoMime,
    );
    if (context.mounted) {
      mostrarMensaje(
        context,
        'Respaldo descargado: ${archivo.nombre} '
        '(${formatoTamano(archivo.bytes.length)}). Guárdalo en dos lugares.',
      );
    }
  } catch (e) {
    if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
  }
}

/// Elige un `.hcrespaldo`, lo abre con la frase (o el código), lo verifica
/// y, tras confirmar, reemplaza todo el consultorio de este navegador.
Future<void> restaurarDesdeArchivo(BuildContext context, WidgetRef ref) async {
  final archivo = await archivos.elegirRespaldo();
  if (archivo == null || !context.mounted) return;
  final verificacion = await showDialog<VerificacionRespaldo>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoAbrirRespaldo(bytes: archivo.bytes),
  );
  if (verificacion == null || !context.mounted) return;
  await confirmarYRestaurar(context, ref, verificacion, archivo.nombre);
}

/// Muestra el resultado de la verificación y restaura si se confirma.
Future<void> confirmarYRestaurar(
  BuildContext context,
  WidgetRef ref,
  VerificacionRespaldo v,
  String nombre,
) async {
  final fecha = v.creado == null ? '' : ' del ${formatoFechaHora(v.creado!)}';
  final bool si;
  if (v.integro) {
    si = await confirmar(
      context,
      titulo: '¿Restaurar este respaldo?',
      texto:
          'El respaldo$fecha está íntegro (${v.registros} registros y '
          '${v.binarios} archivos). Reemplazará todo el consultorio de este '
          'navegador: lo que no esté en el respaldo se perderá. Desde ahora, '
          'la frase de acceso será la del respaldo.',
      aceptar: 'Reemplazar y restaurar',
      icono: Icons.restore_outlined,
      peligro: true,
    );
  } else {
    final lista = v.problemas.take(8).map((p) => '• ${p.descripcion}');
    final mas = v.problemas.length > 8
        ? '\n• … y ${v.problemas.length - 8} más.'
        : '';
    si = await confirmar(
      context,
      titulo: 'El respaldo tiene problemas',
      texto:
          '${lista.join('\n')}$mas\n\nSe pueden restaurar solo los '
          '${v.cambiosIntegros.length} elementos íntegros. Reemplazará todo '
          'el consultorio de este navegador.',
      aceptar: 'Restaurar solo lo íntegro',
      icono: Icons.report_problem_outlined,
      peligro: true,
    );
  }
  if (!si || !context.mounted) return;
  try {
    await ref
        .read(consultorioProvider.notifier)
        .restaurar(v, aceptarParcial: !v.integro);
    if (context.mounted) {
      mostrarMensaje(context, 'Respaldo restaurado: $nombre.');
    }
  } catch (e) {
    if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
  }
}

class _DialogoAbrirRespaldo extends ConsumerStatefulWidget {
  const _DialogoAbrirRespaldo({required this.bytes});

  final List<int> bytes;

  @override
  ConsumerState<_DialogoAbrirRespaldo> createState() =>
      _DialogoAbrirRespaldoState();
}

class _DialogoAbrirRespaldoState extends ConsumerState<_DialogoAbrirRespaldo> {
  var _secreto = '';
  var _conCodigo = false;
  var _trabajando = false;
  String? _error;

  Future<void> _abrir() async {
    setState(() {
      _trabajando = true;
      _error = null;
    });
    try {
      final v = await ref
          .read(consultorioProvider.notifier)
          .verificar(widget.bytes, _secreto, esCodigo: _conCodigo);
      final fatal = v.problemas.where((p) => p.tipo.fatal);
      if (fatal.isNotEmpty) {
        setState(() => _error = fatal.first.descripcion);
        return;
      }
      if (mounted) Navigator.pop(context, v);
    } catch (e) {
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const TituloDialogo(
        'Abrir el respaldo',
        icono: Icons.lock_open_outlined,
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _conCodigo
                  ? 'Escribe el código de recuperación que tenías cuando '
                        'descargaste el respaldo.'
                  : 'Escribe la frase de acceso que tenías cuando descargaste '
                        'el respaldo.',
            ),
            const SizedBox(height: 16),
            CampoTexto(
              key: ValueKey(_conCodigo),
              etiqueta: _conCodigo
                  ? 'Código de recuperación'
                  : 'Frase de acceso',
              oculto: !_conCodigo,
              mayusculas: _conCodigo
                  ? TextCapitalization.characters
                  : TextCapitalization.none,
              alCambiar: (v) => _secreto = v,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: ColoresMarca.error)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _trabajando
                    ? null
                    : () => setState(() {
                        _conCodigo = !_conCodigo;
                        _secreto = '';
                        _error = null;
                      }),
                child: Text(
                  _conCodigo
                      ? 'Usar la frase de acceso'
                      : 'Usar el código de recuperación',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _trabajando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _trabajando ? null : _abrir,
          child: Text(_trabajando ? 'Verificando…' : 'Abrir y verificar'),
        ),
      ],
    );
  }
}
