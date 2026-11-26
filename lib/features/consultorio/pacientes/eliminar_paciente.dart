import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/caja/catalogo.dart';
import '../../../core/consultorio/indice/eliminar_paciente.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import '../widgets/texto_normativo.dart';

/// «2 historias, 1 receta y 3 cobros».
String _enumerar(List<String> partes) => partes.length < 2
    ? partes.join()
    : '${partes.take(partes.length - 1).join(', ')} y ${partes.last}';

/// Pide confirmación y elimina la ficha: sin registros se borra; con ellos
/// se oculta y se conservan. Vuelve a la lista con «Deshacer».
Future<void> eliminarPaciente(
  BuildContext context,
  WidgetRef ref, {
  required FichaPaciente ficha,
}) async {
  final s = ref.read(servicioConsultorioProvider);
  final r = s.registrosDe(ficha.id);
  if (r.citasPorVenir.isNotEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TituloDialogo(
          'Primero cancela sus citas',
          icono: Icons.event_busy_outlined,
          color: ColoresMarca.aviso,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            '${ficha.nombreCompleto} tiene '
            '${r.citasPorVenir.length == 1 ? 'una cita' : '${r.citasPorVenir.length} citas'} '
            'por venir (${r.citasPorVenir.map((c) => formatoFechaHora(c.inicio)).join(', ')}). '
            'Cancélalas o reprográmalas en la agenda y vuelve a eliminar la '
            'ficha.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: TituloDialogo(
        '¿Eliminar a ${ficha.nombreCompleto}?',
        icono: Icons.delete_outline,
        color: ColoresMarca.error,
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.vacio)
              const Text(
                'No tiene historias, documentos, citas, cobros ni otros '
                'registros: la ficha se borra.',
              )
            else ...[
              Text('Tiene ${_enumerar(r.partes)}.'),
              const SizedBox(height: 10),
              const TextoNormativo(
                'La historia clínica se debe conservar (Resolución 1995 de '
                '1999 y Resolución 839 de 2017: 15 años desde la última '
                'atención, VERIFICAR), así que no se borra nada: el paciente '
                'deja de aparecer en Pacientes, el buscador y el Inicio, y sus '
                'registros se conservan.',
              ),
              const SizedBox(height: 10),
              const Text(
                'Lo puedes ver o restaurar en «Pacientes eliminados», al final '
                'de la lista de pacientes.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
            ],
            if (r.saldo > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Todavía debe ${formatoPesos(r.saldo)} en la caja.',
                style: const TextStyle(
                  color: ColoresMarca.avisoTexto,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ColoresMarca.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final ResultadoEliminacion resultado;
  try {
    resultado = await s.eliminarPaciente(ficha.id);
  } catch (e) {
    if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
    return;
  }
  // El mensajero y el aviso de cambios son de la app: siguen vivos al salir
  // de la ficha.
  final version = ref.read(versionIndiceProvider.notifier);
  version.cambio();
  if (!context.mounted) return;
  final mensajero = ScaffoldMessenger.of(context);
  context.go('/pacientes');
  mensajero
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          resultado == ResultadoEliminacion.borrada
              ? 'Se eliminó la ficha de ${ficha.nombreCompleto}.'
              : 'Se eliminó a ${ficha.nombreCompleto} de la lista. Sus '
                    'registros se conservan en «Pacientes eliminados».',
        ),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            await s.restaurarPaciente(ficha.id, original: ficha);
            version.cambio();
          },
        ),
      ),
    );
}

/// Devuelve a la lista una ficha eliminada.
Future<void> restaurarPaciente(
  BuildContext context,
  WidgetRef ref, {
  required FichaPaciente ficha,
}) async {
  try {
    await ref.read(servicioConsultorioProvider).restaurarPaciente(ficha.id);
  } catch (e) {
    if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
    return;
  }
  ref.read(versionIndiceProvider.notifier).cambio();
  if (context.mounted) {
    mostrarMensaje(
      context,
      '${ficha.nombreCompleto} volvió a la lista de pacientes.',
    );
  }
}

/// Los pacientes eliminados que se conservan, para verlos o restaurarlos.
Future<void> verPacientesEliminados(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _DialogoEliminados(),
);

class _DialogoEliminados extends ConsumerWidget {
  const _DialogoEliminados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final s = ref.read(servicioConsultorioProvider);
    final eliminadas = s.indice.fichasEliminadas;
    return AlertDialog(
      title: const TituloDialogo(
        'Pacientes eliminados',
        icono: Icons.restore_from_trash_outlined,
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'No aparecen en la lista, el buscador ni el Inicio. Sus '
              'historias y demás registros se conservan.',
              style: TextStyle(color: ColoresMarca.textoSuave),
            ),
            const SizedBox(height: 12),
            if (eliminadas.isEmpty)
              const Text('No hay pacientes eliminados.')
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: eliminadas.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final f = eliminadas[i];
                    final r = s.registrosDe(f.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.nombreCompleto,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  [
                                    'Eliminado el ${formatoFecha(f.eliminada!)}',
                                    ...r.partes.take(2),
                                  ].join(' · '),
                                  style: const TextStyle(
                                    color: ColoresMarca.textoSuave,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  context.go('/pacientes/${f.id}');
                                },
                                child: const Text('Ver'),
                              ),
                              const SizedBox(width: 4),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    restaurarPaciente(context, ref, ficha: f),
                                icon: const Icon(Icons.restore, size: 18),
                                label: const Text('Restaurar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
