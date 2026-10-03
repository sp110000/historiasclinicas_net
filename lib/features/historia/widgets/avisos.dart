import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/recuadro_icono.dart';
import '../../medico/medico_provider.dart';
import '../estado/archivo_provider.dart';
import '../estado/estado_historia.dart';
import 'dialogos.dart';

/// Aviso con ícono en recuadro, texto y acciones (borde completo; el de
/// error, más grueso).
class Aviso extends StatelessWidget {
  const Aviso({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    this.texto,
    this.acciones = const [],
    this.alCerrar,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final Widget? texto;
  final List<Widget> acciones;
  final VoidCallback? alCerrar;

  @override
  Widget build(BuildContext context) {
    final esError = color == ColoresMarca.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(
          color: esError ? color : ColoresMarca.sobreBlanco(color, 0.28),
          width: esError ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RecuadroIcono(icono, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (texto != null) ...[
                  const SizedBox(height: 4),
                  DefaultTextStyle.merge(
                    style: const TextStyle(fontSize: 13.5, height: 1.4),
                    child: texto!,
                  ),
                ],
                if (acciones.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: acciones),
                ],
              ],
            ),
          ),
          if (alCerrar != null)
            IconButton(
              onPressed: alCerrar,
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Cerrar aviso',
            ),
        ],
      ),
    );
  }
}

class AvisoPrivacidad extends ConsumerWidget {
  const AvisoPrivacidad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(avisoPrivacidadProvider)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Aviso(
        icono: Icons.shield_outlined,
        color: ColoresMarca.primario,
        titulo: 'Tus datos no salen de este navegador',
        texto: const Text(
          'El único registro es el PDF que descargas, con los datos incrustados: '
          'guarda copias de respaldo. El borrador automático queda solo en este '
          'navegador.',
        ),
        acciones: [
          TextButton(
            onPressed: () => mostrarAcercaDe(context),
            child: const Text('Ver limitaciones'),
          ),
        ],
        alCerrar: () => ref.read(avisoPrivacidadProvider.notifier).cerrar(),
      ),
    );
  }
}

class AvisoBorradorRecuperado extends StatelessWidget {
  const AvisoBorradorRecuperado({
    super.key,
    required this.guardadoEn,
    required this.alContinuar,
    required this.alDescartar,
  });

  final DateTime guardadoEn;
  final VoidCallback alContinuar;
  final VoidCallback alDescartar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Aviso(
        icono: Icons.restore,
        color: ColoresMarca.primario,
        titulo: 'Se recuperó el borrador del ${formatoFechaHora(guardadoEn)}',
        texto: const Text('Puedes seguir donde lo dejaste o empezar de cero.'),
        acciones: [
          FilledButton.tonal(
            onPressed: alContinuar,
            child: const Text('Continuar'),
          ),
          TextButton(
            onPressed: alDescartar,
            child: const Text('Descartar borrador'),
          ),
        ],
      ),
    );
  }
}

class AvisoHistoriaAbierta extends StatelessWidget {
  const AvisoHistoriaAbierta({super.key, required this.estado});

  final EstadoHistoria estado;

  @override
  Widget build(BuildContext context) {
    final integridad = estado.integridad;
    final correcta = integridad?.correcta ?? true;
    final selladas = estado.evolucionesSelladas.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Aviso(
        icono: correcta ? Icons.folder_open : Icons.gpp_bad_outlined,
        color: correcta ? ColoresMarca.estadoOk : ColoresMarca.error,
        titulo: 'Historia abierta · ${estado.nombreArchivo ?? 'sin nombre'}',
        texto: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revisión ${estado.revision} · atención del '
              '${formatoFecha(estado.historia.fechaAtencion)} · $selladas '
              '${selladas == 1 ? 'evolución sellada' : 'evoluciones selladas'}',
            ),
            if (integridad != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      correcta
                          ? Icons.verified_outlined
                          : Icons.warning_amber_rounded,
                      size: 17,
                      color: correcta
                          ? ColoresMarca.estadoOk
                          : ColoresMarca.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        integridad.descripcion,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: correcta
                              ? ColoresMarca.estadoOk
                              : ColoresMarca.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              correcta
                  ? 'Solo puedes agregar evoluciones al final. El bloqueo de lo '
                        'anterior lo aplica esta aplicación, no el PDF.'
                  : 'El contenido no coincide con sus huellas: el archivo pudo '
                        'modificarse fuera de la aplicación. Compáralo con tu copia '
                        'de respaldo o con el papel firmado.',
              style: const TextStyle(color: ColoresMarca.textoSuave),
            ),
          ],
        ),
      ),
    );
  }
}

/// Invita a configurar los datos del médico si aún no están.
class AvisoMedicoSinConfigurar extends ConsumerWidget {
  const AvisoMedicoSinConfigurar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(medicoProvider.select((m) => m.configurado))) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Aviso(
        icono: Icons.badge_outlined,
        color: ColoresMarca.aviso,
        titulo: 'Configura tus datos de médico',
        texto: const Text(
          'Tu nombre, registro, consultorio, firma y sello aparecerán en el PDF '
          'de la historia y en las recetas. Se configuran una sola vez.',
        ),
        acciones: [
          FilledButton.tonal(
            onPressed: () => context.push('/medico'),
            child: const Text('Configurar ahora'),
          ),
        ],
      ),
    );
  }
}
