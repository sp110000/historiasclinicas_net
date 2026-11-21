import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/documentos/plantillas.dart';
import '../../../core/pais/pais_provider.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../historia/widgets/dialogos.dart';
import '../../medico/medico_provider.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';

/// Ajustes → Plantillas: versiones, editar, aprobar y la política en PDF.
class TarjetaPlantillas extends ConsumerWidget {
  const TarjetaPlantillas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final documentos = ref.read(servicioConsultorioProvider).documentos;
    return TarjetaConsultorio(
      icono: Icons.article_outlined,
      titulo: 'Plantillas de documentos',
      subtitulo: 'Textos con versión: solo se usan una vez aprobados',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Los textos base siguen la Ley 1581 de 2012 y el Decreto 1377 de '
            '2013, pero son un borrador: revísalos con tu abogado antes de '
            'aprobarlos (VERIFICAR). Cada documento firmado guarda la versión '
            'con la que se firmó.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 8),
          for (final tipo in TipoPlantilla.values)
            _FilaPlantilla(plantilla: documentos.plantilla(tipo)),
        ],
      ),
    );
  }
}

class _FilaPlantilla extends ConsumerWidget {
  const _FilaPlantilla({required this.plantilla});

  final Plantilla plantilla;

  Future<void> _editar(BuildContext context, WidgetRef ref) async {
    final guardada = await showDialog<bool>(
      context: context,
      builder: (_) => _EditorPlantilla(plantilla: plantilla),
    );
    if (guardada == true) ref.read(versionIndiceProvider.notifier).cambio();
  }

  Future<void> _aprobar(BuildContext context, WidgetRef ref) async {
    final b = plantilla.borrador!;
    final si = await confirmar(
      context,
      titulo: '¿Aprobar la versión ${b.version}?',
      texto:
          'Desde ahora los documentos nuevos de «${plantilla.tipo.etiqueta}» '
          'usan este texto. Los que ya se firmaron conservan el suyo. '
          'Confirma que lo revisaste (VERIFICAR con tu abogado).',
      aceptar: 'Aprobar',
      icono: Icons.verified_outlined,
    );
    if (!si) return;
    try {
      await ref
          .read(servicioConsultorioProvider)
          .documentos
          .aprobar(plantilla.tipo);
      ref.read(versionIndiceProvider.notifier).cambio();
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
    }
  }

  Future<void> _politica(BuildContext context, WidgetRef ref) async {
    final medico = ref.read(medicoProvider);
    if (!medico.configurado) {
      mostrarMensaje(
        context,
        'Completa tus datos de médico: la política los lleva como '
        'responsable del tratamiento.',
      );
      context.push('/medico');
      return;
    }
    try {
      final pdf = await ref
          .read(servicioConsultorioProvider)
          .documentos
          .politicaPdf(medico: medico, pais: ref.read(paisProvider));
      ref.read(descargarPdfProvider)(
        pdf,
        'Politica_tratamiento_datos_v${plantilla.vigente!.version}.pdf',
      );
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = plantilla;
    final vigente = p.vigente;
    final borrador = p.borrador;
    final estado = [
      if (vigente != null)
        'v${vigente.version} aprobada el ${formatoFecha(vigente.aprobadaEn!)}',
      if (borrador != null) 'v${borrador.version} en borrador',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.tipo.etiqueta,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          EtiquetaEstado(
            icono: vigente != null
                ? Icons.verified_outlined
                : Icons.edit_note_outlined,
            texto: vigente == null ? '$estado (sin aprobar)' : estado,
            color: vigente != null ? ColoresMarca.estadoOk : ColoresMarca.aviso,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => _editar(context, ref),
                icon: const Icon(Icons.edit_outlined),
                label: Text(borrador == null ? 'Editar' : 'Editar borrador'),
              ),
              if (borrador != null)
                FilledButton.icon(
                  onPressed: () => _aprobar(context, ref),
                  icon: const Icon(Icons.verified_outlined),
                  label: Text('Aprobar v${borrador.version}'),
                ),
              if (p.tipo == TipoPlantilla.politicaPrivacidad && vigente != null)
                OutlinedButton.icon(
                  onPressed: () => _politica(context, ref),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Descargar PDF para exhibir'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorPlantilla extends ConsumerStatefulWidget {
  const _EditorPlantilla({required this.plantilla});

  final Plantilla plantilla;

  @override
  ConsumerState<_EditorPlantilla> createState() => _EditorPlantillaState();
}

class _EditorPlantillaState extends ConsumerState<_EditorPlantilla> {
  late final _titulo = TextEditingController(
    text: widget.plantilla.ultima.titulo,
  );
  late final _cuerpo = TextEditingController(
    text: widget.plantilla.ultima.cuerpo,
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
      await ref
          .read(servicioConsultorioProvider)
          .documentos
          .guardarBorrador(
            widget.plantilla.tipo,
            titulo: _titulo.text,
            cuerpo: _cuerpo.text,
          );
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
    final p = widget.plantilla;
    final siguiente = p.borrador?.version ?? p.ultima.version + 1;
    final movil = MediaQuery.sizeOf(context).width < 600;
    return AlertDialog(
      title: TituloDialogo(p.tipo.etiqueta, icono: Icons.edit_note_outlined),
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
                p.borrador != null
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
              const SizedBox(height: 10),
              const Text('MARCADORES', style: EstilosMarca.rotulo),
              const SizedBox(height: 4),
              for (final e in marcadoresPlantilla.entries)
                Text(
                  '{{${e.key}}} · ${e.value}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: ColoresMarca.textoSuave,
                  ),
                ),
              if (p.versiones.length > 1 || p.vigente != null) ...[
                const SizedBox(height: 10),
                const Text('VERSIONES', style: EstilosMarca.rotulo),
                const SizedBox(height: 4),
                for (final v in p.versiones.reversed)
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
