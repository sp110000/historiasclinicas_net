import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/caja/catalogo.dart';
import '../../../core/consultorio/caja/movimientos.dart';
import '../../../core/consultorio/reglas/caja.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../historia/widgets/dialogos.dart';
import '../agenda/agenda_page.dart' show diaYFecha;
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../respaldo/flujos_respaldo.dart';
import '../widgets/comunes.dart';
import 'campo_pesos.dart';
import 'dialogo_cobro.dart';

const _meses = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

String _hora(DateTime f) =>
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

String _pagosTexto(Recibo r) => r.pagos
    .map(
      (p) =>
          '${p.medio.etiqueta} ${formatoPesos(p.valor)}'
          '${p.referencia.isEmpty ? '' : ' (ref. ${p.referencia})'}',
    )
    .join(' · ');

/// La caja (5.6): el día con sus recibos, usos de paquete y totales por
/// medio, el cierre, los saldos por cobrar y el informe del mes.
class CajaPage extends ConsumerStatefulWidget {
  const CajaPage({super.key});

  @override
  ConsumerState<CajaPage> createState() => _CajaPageState();
}

class _CajaPageState extends ConsumerState<CajaPage> {
  late DateTime _dia = _hoy;
  late DateTime _mes = DateTime(_hoy.year, _hoy.month);
  var _informe = false;

  DateTime get _hoy {
    final a = ref.read(servicioConsultorioProvider).reloj.ahora();
    return DateTime(a.year, a.month, a.day);
  }

  void _descargarCsv(List<int> csv, String nombre) =>
      ref.read(descargarArchivoProvider)(Uint8List.fromList(csv), nombre);

  Future<void> _csvDia() async {
    final csv = await ref
        .read(servicioConsultorioProvider)
        .caja
        .exportarDia(_dia);
    _descargarCsv(csv, 'Caja_${diaIso(_dia)}.csv');
  }

  Future<void> _csvMes() async {
    final csv = await ref
        .read(servicioConsultorioProvider)
        .caja
        .exportarInforme(_mes.year, _mes.month);
    _descargarCsv(
      csv,
      'Informe_caja_${_mes.year}-${_mes.month.toString().padLeft(2, '0')}.csv',
    );
  }

  Future<void> _cerrar() async {
    final c = await showDialog<CierreDiario>(
      context: context,
      builder: (_) => const _DialogoCierre(),
    );
    if (c == null || !mounted) return;
    ref.read(versionIndiceProvider.notifier).cambio();
    // Decisión 7: al cerrar la caja se ofrece el respaldo.
    final respaldar = await confirmar(
      context,
      titulo: 'Caja cerrada',
      texto:
          'Total del día: ${formatoPesos(c.total)}. Diferencia en efectivo: '
          '${formatoPesos(c.diferencia)}.\n\n¿Descargas ahora un respaldo '
          'del consultorio?',
      aceptar: 'Descargar el respaldo',
      icono: Icons.lock_clock_outlined,
    );
    if (respaldar && mounted) await respaldarYDescargar(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(versionIndiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Caja',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => abrirCobro(context, ref),
            icon: const Icon(Icons.point_of_sale),
            label: const Text('Cobrar'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: CuerpoConsultorio(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Día'),
                  icon: Icon(Icons.today_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Informe del mes'),
                  icon: Icon(Icons.bar_chart),
                ),
              ],
              selected: {_informe},
              onSelectionChanged: (v) => setState(() => _informe = v.first),
            ),
          ),
          const SizedBox(height: 16),
          if (_informe) ..._vistaInforme() else ..._vistaDia(),
        ],
      ),
    );
  }

  Widget _navegador({
    required String titulo,
    required String anterior,
    required String siguiente,
    required VoidCallback alAnterior,
    required VoidCallback alSiguiente,
    Widget? extra,
  }) => Row(
    children: [
      IconButton(
        tooltip: anterior,
        onPressed: alAnterior,
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Text(titulo, style: EstilosMarca.titulo.copyWith(fontSize: 18)),
      ),
      IconButton(
        tooltip: siguiente,
        onPressed: alSiguiente,
        icon: const Icon(Icons.chevron_right),
      ),
      ?extra,
    ],
  );

  List<Widget> _vistaDia() {
    final s = ref.read(servicioConsultorioProvider);
    final caja = s.caja;
    final esHoy = _dia == _hoy;
    final cierre = caja.cierre(_dia);
    final totales = cierre?.totales ?? caja.totales(_dia);
    final total = totales.values.fold(0, (a, b) => a + b);
    final recibos = caja.recibosDelDia(_dia);
    final anulaciones = caja.anulacionesDelDia(_dia);
    final usos = caja.usosDelDia(_dia);
    final saldos = caja.cobrosConSaldo();
    String paciente(String id) => s.indice.ficha(id)?.nombreCompleto ?? '';
    return [
      _navegador(
        titulo: diaYFecha(_dia),
        anterior: 'Día anterior',
        siguiente: 'Día siguiente',
        alAnterior: () => setState(
          () => _dia = DateTime(_dia.year, _dia.month, _dia.day - 1),
        ),
        alSiguiente: () => setState(
          () => _dia = DateTime(_dia.year, _dia.month, _dia.day + 1),
        ),
        extra: esHoy
            ? null
            : TextButton(
                onPressed: () => setState(() => _dia = _hoy),
                child: const Text('Hoy'),
              ),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (cierre != null)
            EtiquetaEstado(
              icono: Icons.lock_outline,
              texto: 'Caja cerrada a las ${_hora(cierre.cerradoEn)}',
              color: ColoresMarca.textoSuave,
            )
          else if (esHoy)
            const EtiquetaEstado(
              icono: Icons.lock_open_outlined,
              texto: 'Caja abierta',
              color: ColoresMarca.estadoOk,
            )
          else if (_dia.isBefore(_hoy) &&
              (recibos.isNotEmpty || usos.isNotEmpty))
            const EtiquetaEstado(
              icono: Icons.warning_amber_rounded,
              texto: 'Sin cerrar',
              color: ColoresMarca.aviso,
            ),
        ],
      ),
      if (s.documentos.serie == 'S')
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Equipo secundario: sus recibos llevan la serie S y la caja no '
            'viaja en el paquete. Lleva la caja en el equipo principal.',
            style: TextStyle(color: ColoresMarca.aviso),
          ),
        ),
      const SizedBox(height: 12),
      TarjetaConsultorio(
        icono: Icons.point_of_sale_outlined,
        titulo: 'Totales del día',
        subtitulo: 'Por medio de pago, con lo anulado después de un cierre',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final m in MedioPago.values)
              FilaValor(m.etiqueta, totales[m]!),
            const Divider(),
            FilaValor('Total', total, fuerte: true),
            if (cierre != null) ...[
              const SizedBox(height: 8),
              FilaValor('Efectivo esperado', cierre.efectivoEsperado),
              FilaValor('Efectivo contado', cierre.efectivoContado),
              FilaValor(
                'Diferencia',
                cierre.diferencia,
                fuerte: true,
                color: cierre.diferencia == 0
                    ? ColoresMarca.estadoOk
                    : ColoresMarca.aviso,
              ),
              if (cierre.notas.trim().isNotEmpty)
                Text(
                  'Notas: ${cierre.notas.trim()}',
                  style: const TextStyle(color: ColoresMarca.textoSuave),
                ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (esHoy && cierre == null)
                  FilledButton.icon(
                    onPressed: _cerrar,
                    icon: const Icon(Icons.lock_clock_outlined),
                    label: const Text('Cerrar la caja'),
                  ),
                OutlinedButton.icon(
                  onPressed: _csvDia,
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('CSV del día'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      TarjetaConsultorio(
        icono: Icons.receipt_long_outlined,
        titulo: 'Recibos',
        subtitulo: 'Solo cuando hay pago. No son factura electrónica.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (recibos.isEmpty)
              const Text(
                'Sin recibos este día.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
            for (final r in recibos)
              FilaRecibo(recibo: r, paciente: paciente(r.pacienteId)),
          ],
        ),
      ),
      if (anulaciones.isNotEmpty) ...[
        const SizedBox(height: 16),
        TarjetaConsultorio(
          icono: Icons.undo,
          titulo: 'Anulaciones de días cerrados',
          subtitulo: 'Restan hoy (pregunta 46)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in anulaciones)
                _Renglon(
                  titulo:
                      '${r.numero} del ${formatoFecha(r.fecha)} · '
                      '${_hora(r.anuladoEn!)}',
                  lineas: [
                    paciente(r.pacienteId),
                    _pagosTexto(r),
                    'Motivo: ${r.motivoAnulacion}',
                  ],
                  valor: -r.valor,
                ),
            ],
          ),
        ),
      ],
      if (usos.isNotEmpty) ...[
        const SizedBox(height: 16),
        TarjetaConsultorio(
          icono: Icons.confirmation_number_outlined,
          titulo: 'Sesiones de paquete',
          subtitulo: 'Usadas este día, sin recibo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final u in usos)
                _Renglon(
                  titulo: _hora(u.uso.fecha),
                  lineas: [
                    paciente(u.paquete.pacienteId),
                    '${u.paquete.nombre}: sesión ${u.numero} de '
                        '${u.paquete.sesiones}',
                  ],
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      TarjetaConsultorio(
        icono: Icons.account_balance_wallet_outlined,
        titulo: 'Saldos por cobrar',
        subtitulo: 'De todos los días',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (saldos.isEmpty)
              const Text(
                'Nadie debe nada.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
            for (final c in saldos)
              FilaSaldo(cobro: c, paciente: paciente(c.pacienteId)),
          ],
        ),
      ),
    ];
  }

  List<Widget> _vistaInforme() {
    final s = ref.read(servicioConsultorioProvider);
    final caja = s.caja;
    final i = caja.informe(_mes.year, _mes.month);
    final volumen = caja.volumenPorTecnica(_mes.year, _mes.month);
    Widget tabla(List<FilaInforme> filas, {bool conLinea = false}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (filas.isEmpty)
          const Text(
            'Sin cobros este mes.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
        for (final f in filas)
          _Renglon(
            titulo: f.concepto,
            lineas: [
              [
                if (conLinea) f.linea,
                '${f.cantidad} ${f.cantidad == 1 ? 'vez' : 'veces'}',
                if (f.descuentos > 0)
                  'descuentos ${formatoPesos(f.descuentos)}',
              ].join(' · '),
            ],
            valor: f.neto,
          ),
        if (filas.isNotEmpty) ...[
          const Divider(),
          FilaValor('Total', i.totalNeto, fuerte: true),
        ],
      ],
    );
    return [
      _navegador(
        titulo: '${_meses[_mes.month - 1]} de ${_mes.year}',
        anterior: 'Mes anterior',
        siguiente: 'Mes siguiente',
        alAnterior: () =>
            setState(() => _mes = DateTime(_mes.year, _mes.month - 1)),
        alSiguiente: () =>
            setState(() => _mes = DateTime(_mes.year, _mes.month + 1)),
      ),
      const SizedBox(height: 4),
      const Text(
        'Lo cobrado cuenta en el mes del cobro (sin los anulados); el '
        'recaudo, en el día de cada recibo.',
        style: TextStyle(color: ColoresMarca.textoSuave),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _csvMes,
          icon: const Icon(Icons.table_view_outlined),
          label: const Text('CSV del mes'),
        ),
      ),
      const SizedBox(height: 12),
      TarjetaConsultorio(
        icono: Icons.list_alt,
        titulo: 'Por servicio',
        child: tabla(i.porServicio, conLinea: true),
      ),
      const SizedBox(height: 16),
      TarjetaConsultorio(
        icono: Icons.category_outlined,
        titulo: 'Por línea',
        child: tabla(i.porLinea),
      ),
      const SizedBox(height: 16),
      TarjetaConsultorio(
        icono: Icons.payments_outlined,
        titulo: 'Recaudo',
        subtitulo: 'Por medio de pago',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final m in MedioPago.values)
              FilaValor(m.etiqueta, i.recaudo[m]!),
            const Divider(),
            FilaValor('Total recaudado', i.totalRecaudo, fuerte: true),
            if (i.creditosAplicados > 0)
              FilaValor(
                'Créditos de valoración aplicados',
                i.creditosAplicados,
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      TarjetaConsultorio(
        icono: Icons.spa_outlined,
        titulo: 'Volumen por técnica',
        subtitulo: 'Valoraciones y sesiones selladas en el mes',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (volumen.isEmpty)
              const Text(
                'Sin valoraciones ni sesiones este mes.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
            for (final v in volumen)
              _Renglon(
                titulo: v.tecnica,
                lineas: [
                  '${v.valoraciones} '
                      '${v.valoraciones == 1 ? 'valoración' : 'valoraciones'}'
                      ' · ${v.sesiones} '
                      '${v.sesiones == 1 ? 'sesión' : 'sesiones'}',
                ],
              ),
          ],
        ),
      ),
    ];
  }
}

/// Un renglón con título, líneas y, si hay, un valor a la derecha.
class _Renglon extends StatelessWidget {
  const _Renglon({
    required this.titulo,
    required this.lineas,
    this.valor,
    this.acciones = const [],
    this.etiqueta,
  });

  final String titulo;
  final List<String> lineas;
  final int? valor;
  final List<Widget> acciones;
  final Widget? etiqueta;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: ColoresMarca.borde)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      ?etiqueta,
                    ],
                  ),
                  for (final l in lineas)
                    if (l.trim().isNotEmpty)
                      Text(
                        l,
                        style: const TextStyle(color: ColoresMarca.textoSuave),
                      ),
                ],
              ),
            ),
            if (valor != null) ...[
              const SizedBox(width: 8),
              Text(
                formatoPesos(valor!),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
        if (acciones.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: acciones),
        ],
      ],
    ),
  );
}

/// Un recibo: número, hora, paciente, concepto, pagos; PDF y anular.
class FilaRecibo extends ConsumerWidget {
  const FilaRecibo({
    super.key,
    required this.recibo,
    required this.paciente,
    this.conFecha = false,
  });

  final Recibo recibo;
  final String paciente;
  final bool conFecha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = recibo;
    final caja = ref.read(servicioConsultorioProvider).caja;
    final cobro = caja.cobro(r.cobroId);
    return _Renglon(
      titulo:
          '${r.numero} · ${conFecha ? formatoFechaHora(r.fecha) : _hora(r.fecha)}',
      etiqueta: r.anulado
          ? EtiquetaEstado(
              icono: Icons.block,
              texto: r.anuladoTrasCierre
                  ? 'Anulado el ${formatoFecha(r.anuladoEn!)}'
                  : 'Anulado',
              color: ColoresMarca.error,
            )
          : null,
      lineas: [
        paciente,
        cobro?.descripcion ?? '',
        if (cobro != null) ?textoInsumos(cobro),
        _pagosTexto(r),
        if (r.anulado) 'Motivo: ${r.motivoAnulacion}',
      ],
      valor: r.valor,
      acciones: [
        OutlinedButton.icon(
          onPressed: () => descargarRecibo(ref, r),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text('Recibo ${r.numero}'),
        ),
        // Con la caja de hoy cerrada no se anula nada hasta mañana.
        if (!r.anulado && !caja.hoyCerrado)
          TextButton(
            onPressed: () => anularReciboConMotivo(context, ref, r),
            child: Text('Anular ${r.numero}'),
          ),
      ],
    );
  }
}

/// Un cobro con saldo: abonar, ver la ficha o anularlo (sin recibos).
class FilaSaldo extends ConsumerWidget {
  const FilaSaldo({
    super.key,
    required this.cobro,
    required this.paciente,
    this.conFicha = true,
  });

  final Cobro cobro;
  final String paciente;
  final bool conFicha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caja = ref.read(servicioConsultorioProvider).caja;
    final c = cobro;
    final saldo = caja.saldo(c);
    final sinRecibos = caja.recibosDe(c.id).every((r) => r.anulado);
    return _Renglon(
      titulo: conFicha ? paciente : c.descripcion,
      lineas: [
        if (conFicha) c.descripcion,
        ?textoInsumos(c),
        '${formatoFecha(c.fecha)} · total ${formatoPesos(c.total)} · pagado '
            '${formatoPesos(caja.pagado(c.id))}',
      ],
      valor: saldo,
      acciones: [
        FilledButton.tonalIcon(
          onPressed: () => abrirAbono(context, ref, c),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Abonar'),
        ),
        if (conFicha)
          OutlinedButton.icon(
            onPressed: () => context.go('/pacientes/${c.pacienteId}'),
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Ficha'),
          ),
        if (sinRecibos)
          TextButton(
            onPressed: () => anularCobroConMotivo(context, ref, c),
            child: const Text('Anular el cobro'),
          ),
      ],
    );
  }
}

class _DialogoCierre extends ConsumerStatefulWidget {
  const _DialogoCierre();

  @override
  ConsumerState<_DialogoCierre> createState() => _DialogoCierreState();
}

class _DialogoCierreState extends ConsumerState<_DialogoCierre> {
  int? _contado;
  var _notas = '';
  var _guardando = false;
  String? _error;

  Future<void> _cerrar() async {
    setState(() => _guardando = true);
    try {
      final c = await ref
          .read(servicioConsultorioProvider)
          .caja
          .cerrarDia(efectivoContado: _contado!, notas: _notas.trim());
      if (mounted) Navigator.pop(context, c);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final caja = ref.read(servicioConsultorioProvider).caja;
    final hoy = caja.reloj.ahora();
    final t = caja.totales(hoy);
    final esperado = t[MedioPago.efectivo]!;
    final diferencia = _contado == null ? null : _contado! - esperado;
    final movil = MediaQuery.sizeOf(context).width < 600;
    return AlertDialog(
      title: const TituloDialogo(
        'Cerrar la caja de hoy',
        icono: Icons.lock_clock_outlined,
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: movil ? 12 : 40,
        vertical: 24,
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(diaYFecha(hoy), style: EstilosMarca.rotulo),
              const SizedBox(height: 6),
              for (final m in MedioPago.values) FilaValor(m.etiqueta, t[m]!),
              const Divider(),
              FilaValor(
                'Total',
                t.values.fold(0, (a, b) => a + b),
                fuerte: true,
              ),
              const SizedBox(height: 12),
              FilaValor('Efectivo esperado', esperado),
              const SizedBox(height: 8),
              CampoPesos(
                etiqueta: 'Efectivo contado',
                requerido: true,
                alCambiar: (v) => setState(() => _contado = v),
              ),
              if (diferencia != null) ...[
                const SizedBox(height: 8),
                FilaValor(
                  diferencia == 0
                      ? 'Sin diferencia'
                      : diferencia > 0
                      ? 'Sobra'
                      : 'Falta',
                  diferencia,
                  fuerte: true,
                  color: diferencia == 0
                      ? ColoresMarca.estadoOk
                      : ColoresMarca.aviso,
                ),
              ],
              const SizedBox(height: 8),
              CampoTexto(
                etiqueta: 'Notas',
                pista: 'Por ejemplo, por qué hay diferencia',
                alCambiar: (v) => _notas = v,
              ),
              const SizedBox(height: 12),
              const Text(
                'Al cerrar, la caja de hoy no se reabre: no se registran más '
                'pagos hoy ni se anulan recibos hasta mañana.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: ColoresMarca.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando || _contado == null ? null : _cerrar,
          child: const Text('Cerrar la caja'),
        ),
      ],
    );
  }
}
