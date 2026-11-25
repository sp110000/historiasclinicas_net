import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/verificar/verificar.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../estado/presentacion_provider.dart';
import 'comunes.dart';

/// [texto] sin sus notas «VERIFICAR» en el modo presentación; si no, tal
/// cual. Para etiquetas, ayudas y mensajes que no llevan chip.
String textoPresentable(WidgetRef ref, String texto) =>
    ref.watch(modoPresentacionProvider)
    ? separarVerificar(texto).limpio
    : texto;

/// Como [textoPresentable], fuera de `build` (en una acción).
String textoPresentableAhora(WidgetRef ref, String texto) =>
    ref.read(modoPresentacionProvider) ? separarVerificar(texto).limpio : texto;

/// Un texto con notas «VERIFICAR» (pregunta 50): el texto limpio con un
/// chip discreto «Por verificar» (o «Verificado el … · fuente») que muestra
/// la nota completa y permite registrar la verificación. En el modo
/// presentación, solo el texto limpio. Sin notas, un [Text] común.
class TextoNormativo extends ConsumerWidget {
  const TextoNormativo(
    this.texto, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String texto;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presentacion = ref.watch(modoPresentacionProvider);
    final sep = separarVerificar(texto);
    if (sep.notas.isEmpty) {
      return Text(
        texto,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    if (presentacion) {
      return Text(
        sep.limpio,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    ref.watch(versionIndiceProvider);
    return Text.rich(
      TextSpan(
        children: [
          if (sep.limpio.isNotEmpty) TextSpan(text: '${sep.limpio} '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ChipVerificar(texto: texto, notas: sep.notas),
          ),
        ],
      ),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// «Por verificar» o «Verificado el 21/11/2026 · Res. 1995/1999».
class ChipVerificar extends ConsumerWidget {
  const ChipVerificar({super.key, required this.texto, required this.notas});

  final String texto;
  final List<String> notas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.read(servicioConsultorioProvider);
    final abierto = ref.watch(consultorioProvider).desbloqueado;
    final v = abierto ? s.verificaciones.de(texto) : null;
    final etiqueta = v == null
        ? 'Por verificar'
        : 'Verificado el ${formatoFecha(v.fecha)} · ${v.fuente}';
    return Tooltip(
      message: notas.join('\n'),
      child: Semantics(
        button: true,
        label: '$etiqueta: ${notas.join('; ')}',
        excludeSemantics: true,
        onTap: () => verificarNota(context, ref, texto),
        child: InkWell(
          borderRadius: RadiosMarca.pildora,
          onTap: () => verificarNota(context, ref, texto),
          child: EtiquetaEstado(
            icono: v == null ? Icons.info_outline : Icons.verified_outlined,
            texto: etiqueta,
            color: v == null ? ColoresMarca.aviso : ColoresMarca.estadoOk,
          ),
        ),
      ),
    );
  }
}

/// Muestra la nota completa de [texto] y deja marcarla como verificada (con
/// fecha y fuente) o quitar la verificación.
Future<void> verificarNota(
  BuildContext context,
  WidgetRef ref,
  String texto,
) async {
  final cambio = await showDialog<bool>(
    context: context,
    builder: (_) => _DialogoVerificar(texto: texto),
  );
  if (cambio == true) ref.read(versionIndiceProvider.notifier).cambio();
}

class _DialogoVerificar extends ConsumerStatefulWidget {
  const _DialogoVerificar({required this.texto});

  final String texto;

  @override
  ConsumerState<_DialogoVerificar> createState() => _DialogoVerificarState();
}

class _DialogoVerificarState extends ConsumerState<_DialogoVerificar> {
  late DateTime _fecha = ref.read(servicioConsultorioProvider).reloj.ahora();
  var _fuente = '';
  var _guardando = false;
  String? _error;

  Future<void> _hacer(Future<void> Function() f) async {
    setState(() => _guardando = true);
    try {
      await f();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.read(servicioConsultorioProvider);
    final abierto = ref.watch(consultorioProvider).desbloqueado;
    final v = abierto ? s.verificaciones.de(widget.texto) : null;
    final sep = separarVerificar(widget.texto);
    return AlertDialog(
      title: TituloDialogo(
        v == null ? 'Nota por verificar' : 'Nota verificada',
        icono: v == null ? Icons.info_outline : Icons.verified_outlined,
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final n in sep.notas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    n,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              Text(
                widget.texto,
                style: const TextStyle(color: ColoresMarca.textoSuave),
              ),
              const SizedBox(height: 12),
              if (!abierto)
                const Text(
                  'Desbloquea el consultorio para registrar la verificación.',
                )
              else if (v != null)
                Text(
                  'Verificada el ${formatoFecha(v.fecha)} con: ${v.fuente}.',
                  style: const TextStyle(color: ColoresMarca.estadoOk),
                )
              else ...[
                const Text(
                  'Cuando la revises (con la norma, tu abogado, tu contador o '
                  'la ficha técnica), regístralo aquí: el chip dirá la fecha '
                  'y la fuente. La marca sigue en el código y en los '
                  'documentos.',
                ),
                const SizedBox(height: 12),
                RejillaCampos(
                  anchoMinimo: 180,
                  children: [
                    CampoFecha(
                      etiqueta: 'Verificada el',
                      requerido: true,
                      valor: _fecha,
                      primera: DateTime(2000),
                      ultima: s.reloj.ahora(),
                      alCambiar: (f) {
                        if (f != null) setState(() => _fecha = f);
                      },
                    ),
                    CampoTexto(
                      etiqueta: 'Fuente',
                      requerido: true,
                      pista: 'Res. 1995 de 1999, concepto del abogado…',
                      alCambiar: (t) => setState(() => _fuente = t),
                    ),
                  ],
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: ColoresMarca.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        if (abierto && v != null)
          TextButton(
            onPressed: _guardando
                ? null
                : () => _hacer(() => s.verificaciones.quitar(widget.texto)),
            child: const Text('Quitar la verificación'),
          ),
        if (abierto && v == null)
          FilledButton(
            onPressed: _guardando || _fuente.trim().isEmpty
                ? null
                : () => _hacer(
                    () => s.verificaciones.marcar(
                      widget.texto,
                      fecha: _fecha,
                      fuente: _fuente,
                    ),
                  ),
            child: const Text('Marcar como verificada'),
          ),
      ],
    );
  }
}
