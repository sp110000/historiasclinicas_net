import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/inventario/insumo.dart';
import '../../../core/consultorio/reglas/inventario.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/utils/numeros.dart';
import '../../../core/utils/texto.dart';
import '../../../core/widgets/campos.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import 'dialogos_inventario.dart';

/// El inventario (5.7): insumos con sus lotes, existencias y alertas.
class InventarioPage extends ConsumerStatefulWidget {
  const InventarioPage({super.key});

  @override
  ConsumerState<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends ConsumerState<InventarioPage> {
  var _buscar = '';

  Future<void> _insumo([Insumo? i]) async {
    final g = await editarInsumo(context, insumo: i);
    if (g == null || !mounted) return;
    ref.read(versionIndiceProvider.notifier).cambio();
    mostrarMensaje(context, 'Insumo «${g.nombre}» guardado.');
  }

  Future<void> _entrada([String? insumoId]) async {
    final l = await registrarEntrada(context, insumoId: insumoId);
    if (l == null || !mounted) return;
    ref.read(versionIndiceProvider.notifier).cambio();
    final inv = ref.read(servicioConsultorioProvider).inventario;
    final i = inv.insumo(l.insumoId)!;
    mostrarMensaje(
      context,
      'Entrada registrada: lote ${l.numero} de «${i.nombre}» (quedan '
      '${cantidadTexto(inv.existencia(l.id), i.unidad)}).',
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(versionIndiceProvider);
    final inv = ref.read(servicioConsultorioProvider).inventario;
    final alertas = inv.alertas();
    final q = sinTildes(_buscar.trim().toLowerCase());
    final insumos = [
      for (final i in inv.insumos)
        if (q.isEmpty || sinTildes(i.nombre.toLowerCase()).contains(q)) i,
    ];
    final movil = MediaQuery.sizeOf(context).width < 600;
    String plural(int n, String uno, String varios) =>
        '$n ${n == 1 ? uno : varios}';
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inventario',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (movil)
            IconButton(
              tooltip: 'Insumo nuevo',
              onPressed: _insumo,
              icon: const Icon(Icons.add),
            )
          else
            OutlinedButton.icon(
              onPressed: _insumo,
              icon: const Icon(Icons.add),
              label: const Text('Insumo'),
            ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: inv.vacio ? null : _entrada,
            icon: const Icon(Icons.move_to_inbox_outlined),
            label: const Text('Entrada'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: CuerpoConsultorio(
        children: [
          if (alertas.total > 0) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (alertas.vencidos.isNotEmpty)
                  EtiquetaEstado(
                    icono: Icons.block,
                    texto:
                        '${plural(alertas.vencidos.length, 'lote vencido', 'lotes vencidos')} '
                        'con existencias',
                    color: ColoresMarca.error,
                  ),
                if (alertas.bajoMinimo.isNotEmpty)
                  EtiquetaEstado(
                    icono: Icons.trending_down,
                    texto: '${alertas.bajoMinimo.length} bajo el mínimo',
                    color: ColoresMarca.aviso,
                  ),
                if (alertas.porVencer.isNotEmpty)
                  EtiquetaEstado(
                    icono: Icons.hourglass_bottom,
                    texto:
                        '${plural(alertas.porVencer.length, 'lote vence', 'lotes vencen')} '
                        'en $diasAvisoVencimiento días o menos',
                    color: ColoresMarca.aviso,
                  ),
                if (alertas.sinRegistro.isNotEmpty)
                  EtiquetaEstado(
                    icono: Icons.gpp_maybe_outlined,
                    texto:
                        '${plural(alertas.sinRegistro.length, 'insumo', 'insumos')} '
                        'sin registro Invima',
                    color: ColoresMarca.aviso,
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Las existencias van en la unidad de presentación. En la sesión se '
            'sugiere el lote que vence primero y, al sellarla, se descuenta. '
            'Un lote vencido o sin existencias no deja sellar.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 12),
          if (inv.vacio)
            const TarjetaConsultorio(
              icono: Icons.inventory_2_outlined,
              titulo: 'Inventario vacío',
              child: Text(
                'Agrega tus insumos con «Insumo» (medicamentos, dispositivos '
                'médicos e insumos) y sus lotes con «Entrada».',
              ),
            )
          else ...[
            CampoTexto(
              etiqueta: 'Buscar insumo',
              mayusculas: TextCapitalization.none,
              alCambiar: (v) => setState(() => _buscar = v),
            ),
            const SizedBox(height: 12),
            if (insumos.isEmpty)
              const Text(
                'Ningún insumo con ese nombre.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
            for (final i in insumos) ...[
              _TarjetaInsumo(
                insumo: i,
                alEditar: () => _insumo(i),
                alEntrada: () => _entrada(i.id),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _TarjetaInsumo extends ConsumerStatefulWidget {
  const _TarjetaInsumo({
    required this.insumo,
    required this.alEditar,
    required this.alEntrada,
  });

  final Insumo insumo;
  final VoidCallback alEditar;
  final VoidCallback alEntrada;

  @override
  ConsumerState<_TarjetaInsumo> createState() => _TarjetaInsumoState();
}

class _TarjetaInsumoState extends ConsumerState<_TarjetaInsumo> {
  var _movimientos = false;

  @override
  Widget build(BuildContext context) {
    final inv = ref.read(servicioConsultorioProvider).inventario;
    final i = widget.insumo;
    final existencia = inv.existenciaVigente(i.id);
    final bajo = i.activo && i.stockMinimo > 0 && existencia < i.stockMinimo;
    final aviso = avisoInvima(i);
    final lotes = [
      for (final l in inv.lotesDe(i.id))
        if (inv.existencia(l.id) > 0) l,
    ];
    final movimientos = inv.movimientosDe(i.id);
    final datos = [
      i.categoria.etiqueta,
      if (i.presentacion.trim().isNotEmpty) i.presentacion.trim(),
      if (i.concentracionMgMl != null)
        '${formatoNumero(i.concentracionMgMl!)} mg/mL',
      if (i.inyectable) 'inyectable',
      if (!i.sinRegistro) 'Invima ${i.registroInvima.trim()}',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                i.nombre,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: i.activo ? null : ColoresMarca.textoSuave,
                ),
              ),
              if (!i.activo)
                const EtiquetaEstado(
                  icono: Icons.pause_circle_outline,
                  texto: 'Inactivo',
                  color: ColoresMarca.textoSuave,
                ),
              if (bajo)
                const EtiquetaEstado(
                  icono: Icons.trending_down,
                  texto: 'Bajo el mínimo',
                  color: ColoresMarca.aviso,
                ),
            ],
          ),
          Text(
            datos.join(' · '),
            style: const TextStyle(color: ColoresMarca.textoSuave),
          ),
          if (aviso != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.gpp_maybe_outlined,
                    size: 18,
                    color: i.inyectable
                        ? ColoresMarca.error
                        : ColoresMarca.aviso,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      aviso,
                      style: TextStyle(
                        color: i.inyectable
                            ? ColoresMarca.error
                            : ColoresMarca.aviso,
                        fontWeight: i.inyectable ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Existencia: ${cantidadTexto(existencia, i.unidad)}'
            '${i.stockMinimo > 0 ? ' (mínimo ${formatoNumero(i.stockMinimo)})' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          for (final l in lotes) _FilaLote(lote: l, unidad: i.unidad),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (i.activo)
                FilledButton.tonalIcon(
                  onPressed: widget.alEntrada,
                  icon: const Icon(Icons.move_to_inbox_outlined),
                  label: const Text('Entrada'),
                ),
              OutlinedButton.icon(
                onPressed: widget.alEditar,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(abrirEnlaceProvider)(urlConsultaInvima),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Consultar en Invima'),
              ),
              if (movimientos.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() => _movimientos = !_movimientos),
                  icon: Icon(
                    _movimientos ? Icons.expand_less : Icons.expand_more,
                  ),
                  label: Text('Movimientos (${movimientos.length})'),
                ),
            ],
          ),
          if (_movimientos)
            for (final m in movimientos)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${formatoFechaHora(m.fecha)} · ${m.tipo.etiqueta} · lote '
                  '${inv.lote(m.loteId)?.numero ?? '—'} · '
                  '${m.cantidad > 0 ? '+' : ''}${formatoNumero(m.cantidad)}'
                  '${m.motivo.isEmpty ? '' : ' · ${m.motivo}'}',
                  style: const TextStyle(color: ColoresMarca.textoSuave),
                ),
              ),
        ],
      ),
    );
  }
}

class _FilaLote extends ConsumerWidget {
  const _FilaLote({required this.lote, required this.unidad});

  final Lote lote;
  final String unidad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.read(servicioConsultorioProvider).inventario;
    final l = lote;
    final estado = inv.estado(l);
    final dias = diasParaVencer(l, inv.reloj.ahora());
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: ColoresMarca.fondo,
        borderRadius: RadiosMarca.tarjeta,
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
                'Lote ${l.numero}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              EtiquetaEstado(
                icono: iconoEstadoLote(estado),
                texto: switch (estado) {
                  EstadoLote.porVencer =>
                    dias == 0
                        ? 'Vence hoy'
                        : 'Vence en $dias ${dias == 1 ? 'día' : 'días'}',
                  _ => estado.etiqueta,
                },
                color: colorEstadoLote(estado),
              ),
            ],
          ),
          Text(
            'Vence el ${formatoFecha(l.vence)} · quedan '
            '${cantidadTexto(inv.existencia(l.id), unidad)}'
            '${l.proveedor.isEmpty ? '' : ' · ${l.proveedor}'}',
            style: const TextStyle(color: ColoresMarca.textoSuave),
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => ajustarLote(context, ref, l),
                child: Text('Ajustar ${l.numero}'),
              ),
              TextButton(
                onPressed: () => darDeBajaLote(context, ref, l),
                child: Text('Dar de baja ${l.numero}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
