import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';

/// Une [ficha] con otra que elige el médico (p. ej. la de TI con la de CC,
/// o un «adulto sin identificar» con su ficha). Devuelve el id de la ficha
/// que queda, o `null` si se cancela.
Future<String?> unirFichas(
  BuildContext context,
  WidgetRef ref, {
  required FichaPaciente ficha,
}) async {
  final eleccion = await showDialog<({String otra, bool conservarEsta})>(
    context: context,
    builder: (_) => _DialogoUnir(ficha: ficha),
  );
  if (eleccion == null) return null;
  final origen = eleccion.conservarEsta ? eleccion.otra : ficha.id;
  final destino = eleccion.conservarEsta ? ficha.id : eleccion.otra;
  try {
    await ref
        .read(servicioConsultorioProvider)
        .indice
        .unirFichas(origen, destino);
  } catch (e) {
    if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
    return null;
  }
  ref.read(versionIndiceProvider.notifier).cambio();
  return destino;
}

class _DialogoUnir extends ConsumerStatefulWidget {
  const _DialogoUnir({required this.ficha});

  final FichaPaciente ficha;

  @override
  ConsumerState<_DialogoUnir> createState() => _DialogoUnirState();
}

class _DialogoUnirState extends ConsumerState<_DialogoUnir> {
  final _busqueda = TextEditingController();
  FichaPaciente? _otra;

  /// Por defecto se conserva la ficha que tiene documento.
  bool? _conservarEsta;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  bool get _conservar =>
      _conservarEsta ??
      !(widget.ficha.clave.startsWith('SIN:') &&
          !(_otra?.clave.startsWith('SIN:') ?? true));

  @override
  Widget build(BuildContext context) {
    final indice = ref.read(servicioConsultorioProvider).indice;
    final candidatas = indice
        .buscar(texto: _busqueda.text)
        .map((r) => r.ficha)
        .where((f) => f.id != widget.ficha.id)
        .take(8)
        .toList();
    final otra = _otra;
    return AlertDialog(
      title: const TituloDialogo('Unir fichas', icono: Icons.merge_type),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Une la ficha de ${widget.ficha.nombreCompleto} con la de la '
                'misma persona (por ejemplo, cuando cambió de TI a CC). Las '
                'historias pasan a la ficha que queda; la otra se marca como '
                'unida, no se borra, y queda en la bitácora.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _busqueda,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Buscar la otra ficha',
                  hintText: 'Nombre o documento',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: otra?.id,
                onChanged: (id) => setState(() {
                  _otra = indice.ficha(id!);
                  _conservarEsta = null;
                }),
                child: Column(
                  children: [
                    for (final f in candidatas)
                      RadioListTile<String>(
                        value: f.id,
                        contentPadding: EdgeInsets.zero,
                        title: Text(f.nombreCompleto),
                        subtitle: f.documentoTexto.isEmpty
                            ? null
                            : Text(f.documentoTexto),
                      ),
                    if (candidatas.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Ninguna otra ficha coincide.',
                          style: TextStyle(color: ColoresMarca.textoSuave),
                        ),
                      ),
                  ],
                ),
              ),
              if (otra != null) ...[
                const Divider(height: 24),
                const Text('¿CUÁL QUEDA?', style: EstilosMarca.rotulo),
                RadioGroup<bool>(
                  groupValue: _conservar,
                  onChanged: (v) => setState(() => _conservarEsta = v),
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        value: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_rotulo(widget.ficha)),
                        subtitle: const Text('Esta ficha'),
                      ),
                      RadioListTile<bool>(
                        value: false,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_rotulo(otra)),
                        subtitle: const Text('La ficha elegida'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: otra == null
              ? null
              : () => Navigator.pop(context, (
                  otra: otra.id,
                  conservarEsta: _conservar,
                )),
          child: const Text('Unir'),
        ),
      ],
    );
  }

  String _rotulo(FichaPaciente f) => [
    f.nombreCompleto,
    if (f.documentoTexto.isNotEmpty) f.documentoTexto,
  ].join(' · ');
}
