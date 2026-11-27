import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/imagenes/estudio_imagen.dart';
import '../../../core/consultorio/imagenes/plantillas_eco.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/campo_sugerencias.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/ilustraciones.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../../core/pais/perfil_pais.dart' show Opcion;
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';

/// Pide el paciente (si no viene) y el tipo de estudio, crea el borrador y
/// abre el informe.
Future<void> nuevoEstudio(
  BuildContext context,
  WidgetRef ref, {
  FichaPaciente? ficha,
}) async {
  final r = await showDialog<(FichaPaciente, PlantillaEco)>(
    context: context,
    builder: (_) => _DialogoNuevo(ficha: ficha),
  );
  if (r == null || !context.mounted) return;
  final (f, p) = r;
  try {
    final e = await ref.read(servicioConsultorioProvider).imagenes.crear(f, p);
    ref.read(versionIndiceProvider.notifier).cambio();
    if (context.mounted) context.go('/imagenes/${e.id}');
  } catch (e) {
    if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
  }
}

class _DialogoNuevo extends ConsumerStatefulWidget {
  const _DialogoNuevo({this.ficha});

  final FichaPaciente? ficha;

  @override
  ConsumerState<_DialogoNuevo> createState() => _DialogoNuevoState();
}

class _DialogoNuevoState extends ConsumerState<_DialogoNuevo> {
  final _paciente = TextEditingController();
  late FichaPaciente? _ficha = widget.ficha;
  var _plantilla = plantillasEcoBase.first.id;

  @override
  void initState() {
    super.initState();
    if (_ficha != null) _paciente.text = _ficha!.nombreCompleto;
  }

  @override
  void dispose() {
    _paciente.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.read(servicioConsultorioProvider);
    return AlertDialog(
      title: const TituloDialogo(
        'Nuevo estudio',
        icono: Icons.monitor_heart_outlined,
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.ficha == null) ...[
              CampoSugerencias<FichaPaciente>(
                etiqueta: 'Paciente',
                requerido: true,
                controller: _paciente,
                pista: 'Nombre o documento',
                sugerencias: (q) => q.trim().length < 2
                    ? const []
                    : [
                        for (final r in s.indice.buscar(texto: q).take(8))
                          r.ficha,
                      ],
                texto: (f) => f.nombreCompleto,
                detalle: (f) => f.documentoTexto,
                alElegir: (f) => setState(() {
                  _ficha = f;
                  _paciente.text = f.nombreCompleto;
                }),
                alCambiar: (v) {
                  if (_ficha != null && v != _ficha!.nombreCompleto) {
                    setState(() => _ficha = null);
                  }
                },
              ),
              const SizedBox(height: 12),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.ficha!.nombreCompleto,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            CampoDesplegable(
              etiqueta: 'Tipo de estudio',
              opciones: [
                for (final p in plantillasEcoBase) Opcion(p.id, p.nombre),
              ],
              valor: _plantilla,
              alCambiar: (v) => setState(() => _plantilla = v),
            ),
            const SizedBox(height: 8),
            const Text(
              'Trae los hallazgos normales de ese estudio para que los '
              'edites, y sus medidas habituales.',
              style: TextStyle(color: ColoresMarca.textoSuave, fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _ficha == null
              ? null
              : () => Navigator.pop(context, (
                  _ficha!,
                  plantillaEco(_plantilla)!,
                )),
          child: const Text('Crear informe'),
        ),
      ],
    );
  }
}

/// «Imágenes»: los informes ecográficos, primero los borradores.
class ImagenesPage extends ConsumerWidget {
  const ImagenesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final s = ref.read(servicioConsultorioProvider);
    final todos = s.imagenes.estudios;
    final borradores = [
      for (final e in todos)
        if (e.borrador) e,
    ];
    final informes = [
      for (final e in todos)
        if (!e.borrador) e,
    ];
    final movil = MediaQuery.sizeOf(context).width < 600;
    void nuevo() => nuevoEstudio(context, ref);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Imágenes',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (movil)
            IconButton(
              tooltip: 'Nuevo estudio',
              onPressed: nuevo,
              icon: const Icon(Icons.add),
            )
          else
            FilledButton.icon(
              onPressed: nuevo,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo estudio'),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: CuerpoConsultorio(
        children: [
          if (todos.isEmpty)
            EstadoVacio(
              ilustracion: Ilustracion.consulta,
              titulo: 'Todavía no hay estudios',
              texto:
                  'Crea un informe ecográfico: eliges el paciente y el tipo '
                  'de estudio, subes las imágenes de tu ecógrafo y lo '
                  'cierras en PDF para entregar e imprimir.',
              acciones: [
                FilledButton.icon(
                  onPressed: nuevo,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo estudio'),
                ),
              ],
            )
          else ...[
            if (borradores.isNotEmpty) ...[
              const Text('BORRADORES', style: EstilosMarca.rotulo),
              const SizedBox(height: 8),
              for (final e in borradores) ...[
                FilaEstudio(estudio: e, conPaciente: true),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
            ],
            if (informes.isNotEmpty) ...[
              const Text('INFORMES', style: EstilosMarca.rotulo),
              const SizedBox(height: 8),
              for (final e in informes) ...[
                FilaEstudio(estudio: e, conPaciente: true),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

/// Un estudio en una lista (Imágenes o la línea de tiempo de la ficha).
class FilaEstudio extends ConsumerWidget {
  const FilaEstudio({
    super.key,
    required this.estudio,
    this.conPaciente = false,
  });

  final EstudioImagen estudio;
  final bool conPaciente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = estudio;
    final ficha = conPaciente
        ? ref.read(servicioConsultorioProvider).indice.fichaActiva(e.pacienteId)
        : null;
    final (color, texto, icono) = switch (e.estado) {
      EstadoEstudio.borrador => (
        ColoresMarca.aviso,
        'Borrador',
        Icons.edit_outlined,
      ),
      EstadoEstudio.cerrado => (
        ColoresMarca.estadoOk,
        e.numero ?? 'Cerrado',
        Icons.verified_outlined,
      ),
      EstadoEstudio.anulado => (
        ColoresMarca.error,
        'Anulado${e.numero == null ? '' : ' · ${e.numero}'}',
        Icons.block,
      ),
    };
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: RadiosMarca.tarjeta,
        side: const BorderSide(color: ColoresMarca.borde),
      ),
      child: InkWell(
        borderRadius: RadiosMarca.tarjeta,
        onTap: () => context.go('/imagenes/${e.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              const Icon(
                Icons.monitor_heart_outlined,
                color: ColoresMarca.primario,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      [
                        if (ficha != null) ficha.nombreCompleto,
                        formatoFechaHora(e.fecha),
                        if (e.imagenes.isNotEmpty)
                          e.imagenes.length == 1
                              ? '1 imagen'
                              : '${e.imagenes.length} imágenes',
                      ].join(' · '),
                      style: const TextStyle(
                        color: ColoresMarca.textoSuave,
                        fontSize: 13,
                      ),
                    ),
                    if (!e.borrador && e.impresion.trim().isNotEmpty)
                      Text(
                        e.impresion.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              EtiquetaEstado(icono: icono, texto: texto, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
