import 'package:flutter/material.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/documentos/plantillas.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../historia/widgets/dialogos.dart';
import 'comunes.dart';

/// Estado de una plantilla con versiones: «v1 aprobada el … · v2 en
/// borrador», en verde si hay una aprobada.
class EstadoVersiones extends StatelessWidget {
  const EstadoVersiones({super.key, required this.versiones});

  final List<VersionPlantilla> versiones;

  @override
  Widget build(BuildContext context) {
    final vigente = versiones.where((v) => v.aprobada).lastOrNull;
    final borrador = versiones.isNotEmpty && !versiones.last.aprobada
        ? versiones.last
        : null;
    final estado = [
      if (vigente != null)
        'v${vigente.version} aprobada el ${formatoFecha(vigente.aprobadaEn!)}',
      if (borrador != null) 'v${borrador.version} en borrador',
    ].join(' · ');
    return EtiquetaEstado(
      icono: vigente != null
          ? Icons.verified_outlined
          : Icons.edit_note_outlined,
      texto: vigente == null ? '$estado (sin aprobar)' : estado,
      color: vigente != null ? ColoresMarca.estadoOk : ColoresMarca.aviso,
    );
  }
}

/// Fila de Ajustes de una plantilla con versiones: nombre, estado,
/// «Editar» y «Aprobar vN» (con confirmación), más [extra].
class FilaVersionada extends StatelessWidget {
  const FilaVersionada({
    super.key,
    required this.nombre,
    required this.versiones,
    required this.alEditar,
    required this.alAprobar,
    this.textoAprobar = '',
    this.extra = const [],
  });

  final String nombre;
  final List<VersionPlantilla> versiones;
  final VoidCallback alEditar;

  /// Se llama tras confirmar.
  final Future<void> Function() alAprobar;

  /// Qué pasa al aprobar (se muestra en la confirmación).
  final String textoAprobar;
  final List<Widget> extra;

  Future<void> _aprobar(BuildContext context, VersionPlantilla b) async {
    final si = await confirmar(
      context,
      titulo: '¿Aprobar la versión ${b.version}?',
      texto:
          '${textoAprobar.isEmpty ? 'Desde ahora se usa este texto.' : textoAprobar} '
          'Lo que ya se hizo conserva su versión. Confirma que lo revisaste.',
      aceptar: 'Aprobar',
      icono: Icons.verified_outlined,
    );
    if (!si) return;
    try {
      await alAprobar();
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final borrador = versiones.isNotEmpty && !versiones.last.aprobada
        ? versiones.last
        : null;
    // Cada plantilla en su recuadro (rediseño): fondo cálido y el nombre
    // destacado; el estado de las versiones lleva su color.
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: ColoresMarca.fondo,
        borderRadius: RadiosMarca.control,
        border: Border.all(color: ColoresMarca.separador),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombre,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          EstadoVersiones(versiones: versiones),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: alEditar,
                icon: const Icon(Icons.edit_outlined),
                label: Text(borrador == null ? 'Editar' : 'Editar borrador'),
              ),
              if (borrador != null)
                FilledButton.icon(
                  onPressed: () => _aprobar(context, borrador),
                  icon: const Icon(Icons.verified_outlined),
                  label: Text('Aprobar v${borrador.version}'),
                ),
              ...extra,
            ],
          ),
        ],
      ),
    );
  }
}

/// Editor del texto de una plantilla con versiones. Guardar crea (o
/// reemplaza) el borrador; devuelve `true` si se guardó.
Future<bool> editarTextoVersionado(
  BuildContext context, {
  required String titulo,
  required List<VersionPlantilla> versiones,
  required Map<String, String> marcadores,
  required Future<void> Function(String titulo, String cuerpo) guardar,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _EditorVersionado(
        titulo: titulo,
        versiones: versiones,
        marcadores: marcadores,
        guardar: guardar,
      ),
    ) ??
    false;

class _EditorVersionado extends StatefulWidget {
  const _EditorVersionado({
    required this.titulo,
    required this.versiones,
    required this.marcadores,
    required this.guardar,
  });

  final String titulo;
  final List<VersionPlantilla> versiones;
  final Map<String, String> marcadores;
  final Future<void> Function(String titulo, String cuerpo) guardar;

  @override
  State<_EditorVersionado> createState() => _EditorVersionadoState();
}

class _EditorVersionadoState extends State<_EditorVersionado> {
  late final _titulo = TextEditingController(
    text: widget.versiones.last.titulo,
  );
  late final _cuerpo = TextEditingController(
    text: widget.versiones.last.cuerpo,
  );
  var _guardando = false;

  @override
  void dispose() {
    _titulo.dispose();
    _cuerpo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await widget.guardar(_titulo.text, _cuerpo.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        mostrarMensaje(context, mensajeDeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vs = widget.versiones;
    final borrador = !vs.last.aprobada ? vs.last : null;
    final siguiente = borrador?.version ?? vs.last.version + 1;
    final hayAprobada = vs.any((v) => v.aprobada);
    final movil = MediaQuery.sizeOf(context).width < 600;
    return AlertDialog(
      title: TituloDialogo(widget.titulo, icono: Icons.edit_note_outlined),
      insetPadding: EdgeInsets.symmetric(
        horizontal: movil ? 12 : 40,
        vertical: 24,
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                borrador != null
                    ? 'Editas el borrador de la versión $siguiente.'
                    : 'Al guardar se crea la versión $siguiente, en borrador. '
                          'La versión aprobada sigue en uso hasta que '
                          'apruebes la nueva.',
                style: const TextStyle(color: ColoresMarca.textoSuave),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titulo,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cuerpo,
                minLines: 10,
                maxLines: 18,
                decoration: const InputDecoration(
                  labelText: 'Texto',
                  alignLabelWithHint: true,
                ),
              ),
              if (widget.marcadores.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('MARCADORES', style: EstilosMarca.rotulo),
                const SizedBox(height: 4),
                for (final e in widget.marcadores.entries)
                  Text(
                    '{{${e.key}}} · ${e.value}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: ColoresMarca.textoSuave,
                    ),
                  ),
              ],
              if (vs.length > 1 || hayAprobada) ...[
                const SizedBox(height: 10),
                const Text('VERSIONES', style: EstilosMarca.rotulo),
                const SizedBox(height: 4),
                for (final v in vs.reversed)
                  Text(
                    v.aprobada
                        ? 'v${v.version} · aprobada el '
                              '${formatoFechaHora(v.aprobadaEn!)}'
                        : 'v${v.version} · borrador',
                    style: const TextStyle(fontSize: 13),
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
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: const Text('Guardar borrador'),
        ),
      ],
    );
  }
}
