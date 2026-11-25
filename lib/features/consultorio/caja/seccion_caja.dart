import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/caja/catalogo.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/utils/fechas.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import 'caja_page.dart';
import 'dialogo_cobro.dart';

/// La caja en la ficha: cobrar, saldos, paquetes, crédito de la valoración
/// y recibos.
class SeccionCaja extends ConsumerWidget {
  const SeccionCaja({super.key, required this.ficha});

  final FichaPaciente ficha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final caja = ref.read(servicioConsultorioProvider).caja;
    final f = ficha;
    final saldo = caja.saldoPaciente(f.id);
    final conSaldo = [
      for (final c in caja.cobrosDe(f.id))
        if (caja.saldo(c) > 0) c,
    ];
    final paquetes = caja.paquetesDe(f.id);
    final creditos = caja.creditosDisponibles(f.id);
    final recibos = caja.recibosDePaciente(f.id);
    return TarjetaConsultorio(
      icono: Icons.point_of_sale_outlined,
      titulo: 'Caja',
      subtitulo: saldo > 0
          ? 'Saldo pendiente: ${formatoPesos(saldo)}'
          : 'Sin saldo pendiente',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => abrirCobro(context, ref, pacienteId: f.id),
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Cobrar'),
            ),
          ),
          if (conSaldo.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('SALDOS', style: EstilosMarca.rotulo),
            for (final c in conSaldo)
              FilaSaldo(cobro: c, paciente: f.nombreCompleto, conFicha: false),
          ],
          if (paquetes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('PAQUETES', style: EstilosMarca.rotulo),
            for (final p in paquetes)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: ColoresMarca.borde)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          p.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        EtiquetaEstado(
                          icono: p.anulado
                              ? Icons.block
                              : p.agotado
                              ? Icons.check_circle_outline
                              : Icons.confirmation_number_outlined,
                          texto: p.anulado
                              ? 'Anulado'
                              : p.agotado
                              ? 'Agotado'
                              : 'Quedan ${p.pendientes} de ${p.sesiones}',
                          color: p.anulado
                              ? ColoresMarca.error
                              : p.agotado
                              ? ColoresMarca.textoSuave
                              : ColoresMarca.primario,
                        ),
                      ],
                    ),
                    Text(
                      [
                        'Desde el ${formatoFecha(p.creado)}',
                        if (p.usadas > 0)
                          'usadas: ${p.usos.where((u) => !u.anulado).map((u) => formatoFecha(u.fecha)).join(', ')}',
                      ].join(' · '),
                      style: const TextStyle(color: ColoresMarca.textoSuave),
                    ),
                    if (p.activo) ...[
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () => usarSesionPaquete(context, ref, p),
                        icon: const Icon(Icons.confirmation_number_outlined),
                        label: const Text('Usar una sesión'),
                      ),
                    ],
                  ],
                ),
              ),
          ],
          if (creditos.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('CRÉDITO DE LA VALORACIÓN', style: EstilosMarca.rotulo),
            const SizedBox(height: 4),
            for (final c in creditos)
              Text(
                '${formatoPesos(c.valor)} para el tratamiento, hasta el '
                '${formatoFecha(c.vence)}.',
              ),
          ],
          const SizedBox(height: 16),
          const Text('RECIBOS', style: EstilosMarca.rotulo),
          if (recibos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Sin recibos.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
            ),
          for (final r in recibos)
            FilaRecibo(recibo: r, paciente: '', conFecha: true),
        ],
      ),
    );
  }
}
