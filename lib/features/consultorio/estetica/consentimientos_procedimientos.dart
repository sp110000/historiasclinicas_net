import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/documentos/documento.dart';
import '../../../core/consultorio/documentos/plantillas.dart';
import '../../../core/models/mapa.dart';
import '../../../core/utils/fechas.dart';
import '../documentos/plantillas_ajustes.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../estado/presentacion_provider.dart';
import '../widgets/comunes.dart';
import '../widgets/texto_normativo.dart';

/// Procedimientos → Consentimiento informado: el texto que firma el
/// paciente, con sus versiones (antes estaba en Ajustes).
class TarjetaConsentimientoInformado extends ConsumerWidget {
  const TarjetaConsentimientoInformado({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final documentos = ref.read(servicioConsultorioProvider).documentos;
    return TarjetaConsultorio(
      icono: Icons.assignment_turned_in_outlined,
      titulo: 'Consentimiento informado',
      subtitulo: 'El texto que firma el paciente, con versiones',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TextoNormativo(
            'Un solo texto para todos los procedimientos: cada uno pone su '
            'nombre, sus riesgos y sus alternativas, y el plan de cada '
            'paciente, sus zonas, sesiones y producto. Revísalo con tu '
            'abogado antes de aprobarlo (VERIFICAR). La muestra de cada '
            'procedimiento está en su botón «Imprimir».',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 8),
          FilaPlantilla(
            plantilla: documentos.plantilla(
              TipoPlantilla.consentimientoInformado,
            ),
          ),
        ],
      ),
    );
  }
}

/// Procedimientos → Consentimientos firmados: los de todos los pacientes,
/// por procedimiento, con su estado y su PDF. En el modo presentación no
/// se muestran (llevan nombres de pacientes).
class TarjetaConsentimientosFirmados extends ConsumerStatefulWidget {
  const TarjetaConsentimientosFirmados({super.key});

  @override
  ConsumerState<TarjetaConsentimientosFirmados> createState() =>
      _TarjetaConsentimientosFirmadosState();
}

class _TarjetaConsentimientosFirmadosState
    extends ConsumerState<TarjetaConsentimientosFirmados> {
  /// Cuántos se ven de cada procedimiento antes de «Ver todos».
  static const _primeros = 5;

  final _abiertos = <String>{};

  @override
  Widget build(BuildContext context) {
    ref.watch(versionIndiceProvider);
    final presentacion = ref.watch(modoPresentacionProvider);
    final firmados = ref
        .read(servicioConsultorioProvider)
        .procedimientos
        .consentimientosFirmados;
    final grupos = <String, List<DocumentoConsultorio>>{};
    for (final d in firmados) {
      grupos.putIfAbsent(d.plan?.procedimiento ?? 'Sin plan', () => []).add(d);
    }
    final vigentes = firmados.where((d) => d.vigente).length;
    return TarjetaConsultorio(
      icono: Icons.fact_check_outlined,
      titulo: 'Consentimientos firmados',
      subtitulo: presentacion
          ? 'De todos los pacientes'
          : '${firmados.length} de todos los pacientes · $vigentes vigentes',
      child: presentacion
          ? const Text(
              'Oculto en el modo presentación: lleva nombres de pacientes.',
              style: TextStyle(color: ColoresMarca.textoSuave),
            )
          : firmados.isEmpty
          ? const Text(
              'Todavía no hay consentimientos firmados. Se firman en la ficha '
              'del paciente, en Estética.',
              style: TextStyle(color: ColoresMarca.textoSuave),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final MapEntry(key: nombre, value: docs)
                    in grupos.entries) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${nombre.toUpperCase()} · ${docs.length}',
                    style: EstilosMarca.rotulo,
                  ),
                  for (final d
                      in _abiertos.contains(nombre)
                          ? docs
                          : docs.take(_primeros))
                    _FilaConsentimiento(documento: d),
                  if (docs.length > _primeros && !_abiertos.contains(nombre))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _abiertos.add(nombre)),
                        child: Text('Ver los ${docs.length}'),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _FilaConsentimiento extends ConsumerWidget {
  const _FilaConsentimiento({required this.documento});

  final DocumentoConsultorio documento;

  Future<void> _pdf(WidgetRef ref, String nombre) async {
    final descargar = ref.read(descargarPdfProvider);
    final pdf = await ref
        .read(servicioConsultorioProvider)
        .documentos
        .pdfDe(documento.id);
    if (pdf != null) descargar(pdf, nombre);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = documento;
    final indice = ref.read(servicioConsultorioProvider).indice;
    final paciente =
        indice.fichaActiva(d.fichaEfectiva)?.nombreCompleto ??
        d.datos.mapa('paciente').texto('nombre');
    final plan = d.plan;
    final nombre = nombreArchivoDocumento(
      d.tipo.baseArchivo,
      apellido: d.datos.mapa('paciente').texto('nombre').split(',').first,
      numero: d.numero,
    );
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d.numero} · $paciente',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    'Firmado el ${formatoFecha(d.fechaHora)}',
                    if (plan != null && plan.zonas.isNotEmpty) plan.textoZonas,
                    if (plan != null)
                      '${plan.sesiones} '
                          '${plan.sesiones == 1 ? 'sesión' : 'sesiones'}',
                  ].join(' · '),
                  style: const TextStyle(color: ColoresMarca.textoSuave),
                ),
                if (!d.vigente && d.motivoEstado.trim().isNotEmpty)
                  Text(
                    'Motivo: ${d.motivoEstado.trim()}',
                    style: const TextStyle(color: ColoresMarca.textoSuave),
                  ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              EtiquetaEstado(
                icono: d.vigente ? Icons.check_circle_outline : Icons.block,
                texto: d.vigente
                    ? 'Vigente'
                    : '${d.estado.etiqueta}'
                          '${d.cambioEstado == null ? '' : ' el ${formatoFecha(d.cambioEstado!)}'}',
                color: d.vigente ? ColoresMarca.estadoOk : ColoresMarca.error,
              ),
              OutlinedButton.icon(
                onPressed: () => _pdf(ref, nombre),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text('PDF ${d.numero}'),
              ),
              TextButton(
                onPressed: () => context.go('/pacientes/${d.fichaEfectiva}'),
                child: const Text('Ficha'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
