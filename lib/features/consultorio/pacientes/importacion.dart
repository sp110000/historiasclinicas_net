import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/archivos/archivos.dart' show ArchivoAbierto;
import '../../../core/consultorio/indice/indice_pacientes.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';

/// Importa PDF de la app (historias, documentos y recetas; elegidos o
/// soltados) y muestra el informe. Sin [archivos], abre el selector.
Future<void> importarPdfs(
  BuildContext context,
  WidgetRef ref, {
  List<ArchivoAbierto>? archivos,
}) async {
  final elegidos = archivos ?? await ref.read(elegirPdfsProvider)();
  if (elegidos.isEmpty || !context.mounted) return;
  final servicio = ref.read(servicioConsultorioProvider);
  final avance = ValueNotifier<int>(0);
  final navegador = Navigator.of(context, rootNavigator: true);
  // El avance no se puede cerrar: termina solo.
  final dialogo = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: _DialogoAvance(avance: avance, total: elegidos.length),
    ),
  );
  List<ResultadoImportacion> resultados;
  try {
    resultados = await servicio.importarArchivos([
      for (final a in elegidos) (nombre: a.nombre, bytes: a.bytes),
    ], alAvanzar: (hechos, _) => avance.value = hechos);
  } finally {
    navegador.pop();
    await dialogo;
    avance.dispose();
  }
  ref.read(versionIndiceProvider.notifier).cambio();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => InformeImportacion(resultados: resultados),
  );
}

class _DialogoAvance extends StatelessWidget {
  const _DialogoAvance({required this.avance, required this.total});

  final ValueNotifier<int> avance;
  final int total;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const TituloDialogo(
        'Importando archivos',
        icono: Icons.upload_file_outlined,
      ),
      content: ValueListenableBuilder<int>(
        valueListenable: avance,
        builder: (context, hechos, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: total == 0 ? null : hechos / total),
            const SizedBox(height: 12),
            Text('$hechos de $total archivos'),
          ],
        ),
      ),
    );
  }
}

/// Informe de la importación: qué pasó con cada archivo.
class InformeImportacion extends StatelessWidget {
  const InformeImportacion({super.key, required this.resultados});

  final List<ResultadoImportacion> resultados;

  @override
  Widget build(BuildContext context) {
    final importadas = resultados.where((r) => r.importada).length;
    final alteradas = resultados
        .where((r) => r.tipo == TipoImportacion.alterada)
        .length;
    final fallidas = resultados.length - importadas;
    return AlertDialog(
      title: TituloDialogo(
        'Importación terminada',
        icono: fallidas == 0 && alteradas == 0
            ? Icons.check_circle_outline
            : Icons.info_outline,
        color: fallidas == 0 && alteradas == 0
            ? ColoresMarca.estadoOk
            : ColoresMarca.aviso,
      ),
      // Ancho fijo: el diálogo mide anchos intrínsecos y la lista no los da.
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                [
                  '$importadas de ${resultados.length} archivos en el índice',
                  if (alteradas > 0)
                    '$alteradas con alteraciones (quedan marcadas)',
                  if (fallidas > 0) '$fallidas no se importaron',
                ].join(' · '),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: resultados.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _FilaInforme(resultados[i]),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _FilaInforme extends StatelessWidget {
  const _FilaInforme(this.r);

  final ResultadoImportacion r;

  @override
  Widget build(BuildContext context) {
    final (icono, color, estado) = switch (r.tipo) {
      TipoImportacion.registrada
          when r.registro?.tipo == TipoRegistro.divergente =>
        (Icons.call_split, ColoresMarca.aviso, 'Versiones divergentes'),
      TipoImportacion.registrada => (
        Icons.check_circle_outline,
        ColoresMarca.estadoOk,
        r.registro?.tipo.etiqueta ?? r.mensaje,
      ),
      TipoImportacion.alterada => (
        Icons.gpp_bad_outlined,
        ColoresMarca.error,
        'Importada con alteraciones',
      ),
      TipoImportacion.danada => (
        Icons.broken_image_outlined,
        ColoresMarca.error,
        'Dañada',
      ),
      TipoImportacion.noEsDeLaApp => (
        Icons.block,
        ColoresMarca.textoSuave,
        'No es de la app',
      ),
      TipoImportacion.noEsHistoria => (
        Icons.help_outline,
        ColoresMarca.aviso,
        'No es compatible',
      ),
      TipoImportacion.sinFicha => (
        Icons.person_off_outlined,
        ColoresMarca.aviso,
        'Sin ficha',
      ),
      TipoImportacion.rechazada => (
        Icons.gpp_bad_outlined,
        ColoresMarca.error,
        'No coincide',
      ),
    };
    final detalle = switch (r.tipo) {
      TipoImportacion.registrada => null,
      TipoImportacion.alterada => r.registro?.integridadDescripcion,
      _ => r.mensaje,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 20, semanticLabel: estado),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(estado, style: TextStyle(fontSize: 13, color: color)),
                if (detalle != null)
                  Text(
                    detalle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: ColoresMarca.textoSuave,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
