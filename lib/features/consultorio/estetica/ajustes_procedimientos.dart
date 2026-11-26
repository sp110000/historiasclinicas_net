import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/documentos/plantillas.dart';
import '../../../core/consultorio/procedimientos/plantilla_procedimiento.dart';
import '../../../core/consultorio/procedimientos/protocolo_pdf.dart';
import '../../../core/pais/pais_provider.dart';
import '../../medico/medico_provider.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import '../widgets/editor_versionado.dart';
import '../widgets/texto_normativo.dart';

/// Procedimientos: plantillas declarativas (la hidrolipoclasia de fábrica y
/// las que agrega el médico) con versiones; sin el protocolo completo no se
/// pueden aprobar ni usar.
class TarjetaProcedimientos extends ConsumerWidget {
  const TarjetaProcedimientos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final procedimientos = ref.read(servicioConsultorioProvider).procedimientos;
    return TarjetaConsultorio(
      icono: Icons.spa_outlined,
      titulo: 'Procedimientos',
      subtitulo: 'Valoración, protocolo y consentimiento por procedimiento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TextoNormativo(
            'Cada procedimiento es una plantilla con versiones: los criterios '
            'de la valoración, el protocolo de la sesión y los textos del '
            'consentimiento. La app no trae composiciones, volúmenes ni dosis: '
            'los escribes tú y apruebas la plantilla (VERIFICAR).',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          for (final p in procedimientos.plantillas)
            FilaVersionada(
              nombre: p.nombre,
              versiones: [
                for (final v in p.versiones)
                  VersionPlantilla(
                    version: v.version,
                    titulo: v.definicion.nombre,
                    cuerpo: '',
                    aprobadaEn: v.aprobadaEn,
                  ),
              ],
              textoAprobar:
                  'Desde ahora las valoraciones y sesiones nuevas de '
                  '«${p.nombre}» usan este protocolo.',
              alEditar: () => context.go('/procedimientos/${p.id}'),
              alAprobar: () async {
                await ref
                    .read(servicioConsultorioProvider)
                    .procedimientos
                    .aprobar(p.id);
                ref.read(versionIndiceProvider.notifier).cambio();
              },
              extra: [
                BotonImprimirProcedimiento(plantilla: p),
                if (p.borrador != null &&
                    p.borrador!.definicion.faltantes.isNotEmpty)
                  Text(
                    'Falta: ${p.borrador!.definicion.faltantes.join(', ')}.',
                    style: const TextStyle(color: ColoresMarca.aviso),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Qué se imprime de un procedimiento.
enum _QueImprimir { protocolo, lista, consentimiento }

/// «Imprimir»: el protocolo (vigente, anteriores o el borrador), la hoja de
/// la lista de verificación y el consentimiento de muestra, en PDF.
class BotonImprimirProcedimiento extends ConsumerWidget {
  const BotonImprimirProcedimiento({super.key, required this.plantilla});

  final PlantillaProcedimiento plantilla;

  Future<void> _imprimir(
    BuildContext context,
    WidgetRef ref,
    _QueImprimir que,
    int version,
  ) async {
    final procedimientos = ref.read(servicioConsultorioProvider).procedimientos;
    final descargar = ref.read(descargarPdfProvider);
    final medico = ref.read(medicoProvider);
    final pais = ref.read(paisProvider);
    final p = plantilla;
    try {
      final (pdf, nombre) = switch (que) {
        _QueImprimir.protocolo => (
          await procedimientos.protocoloPdf(
            p.id,
            version: version,
            medico: medico,
            pais: pais,
          ),
          nombreArchivoProcedimiento('Protocolo', p.nombre, version: version),
        ),
        _QueImprimir.lista => (
          await procedimientos.listaVerificacionPdf(
            p.id,
            version: version,
            medico: medico,
            pais: pais,
          ),
          nombreArchivoProcedimiento(
            'Lista_verificacion',
            p.nombre,
            version: version,
          ),
        ),
        _QueImprimir.consentimiento => (
          await procedimientos.consentimientoMuestraPdf(
            p.id,
            medico: medico,
            pais: pais,
          ),
          nombreArchivoProcedimiento('Consentimiento_muestra', p.nombre),
        ),
      };
      descargar(pdf, nombre);
      if (context.mounted) mostrarMensaje(context, '$nombre descargado.');
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = plantilla;
    final vigente = p.vigente;
    final borrador = p.borrador;
    final paraLista = vigente ?? borrador ?? p.ultima;
    final anteriores = [
      for (final v in p.versiones.reversed)
        if (v.aprobada && v.version != vigente?.version) v,
    ];
    MenuItemButton item(
      String texto,
      IconData icono,
      _QueImprimir que,
      int version,
    ) => MenuItemButton(
      leadingIcon: Icon(icono),
      onPressed: () => _imprimir(context, ref, que, version),
      child: Text(texto),
    );
    return MenuAnchor(
      menuChildren: [
        if (vigente != null)
          item(
            'Protocolo v${vigente.version} (vigente)',
            Icons.description_outlined,
            _QueImprimir.protocolo,
            vigente.version,
          ),
        if (borrador != null)
          item(
            'Borrador v${borrador.version} del protocolo',
            Icons.edit_note_outlined,
            _QueImprimir.protocolo,
            borrador.version,
          ),
        for (final v in anteriores)
          item(
            'Protocolo v${v.version} (anterior)',
            Icons.history,
            _QueImprimir.protocolo,
            v.version,
          ),
        item(
          'Lista de verificación v${paraLista.version}',
          Icons.checklist_outlined,
          _QueImprimir.lista,
          paraLista.version,
        ),
        item(
          'Consentimiento de muestra',
          Icons.assignment_outlined,
          _QueImprimir.consentimiento,
          paraLista.version,
        ),
      ],
      builder: (context, controlador, _) {
        void alternar() =>
            controlador.isOpen ? controlador.close() : controlador.open();
        // Se ve «Imprimir»; el lector dice de qué procedimiento.
        return Semantics(
          label: 'Imprimir ${p.nombre}',
          button: true,
          excludeSemantics: true,
          onTap: alternar,
          child: OutlinedButton.icon(
            onPressed: alternar,
            icon: const Icon(Icons.print_outlined),
            label: const Text('Imprimir'),
          ),
        );
      },
    );
  }
}
