import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/agenda/cita.dart';
import '../../../core/consultorio/agenda/festivos.dart';
import '../../../core/consultorio/agenda/horario.dart';
import '../../../core/consultorio/caja/catalogo.dart';
import '../../../core/consultorio/reglas/agenda.dart';
import '../../../core/consultorio/reglas/estetica.dart';
import '../../../core/utils/fechas.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../caja/dialogo_cobro.dart';
import '../widgets/comunes.dart';
import 'acciones_cita.dart';
import 'dialogo_cita.dart';
import 'estilo_cita.dart';

enum _Vista { dia, semana }

/// La agenda (5.5): la pantalla de inicio con la bandera encendida
/// (pregunta 51). Vista de día y de semana; en móvil, solo de día,
/// deslizando entre días.
class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  late DateTime _dia = _hoy;
  var _vista = _Vista.dia;

  DateTime get _hoy {
    final a = ref.read(servicioConsultorioProvider).reloj.ahora();
    return DateTime(a.year, a.month, a.day);
  }

  DateTime get _lunes =>
      DateTime(_dia.year, _dia.month, _dia.day - (_dia.weekday - 1));

  void _mover(int pasos) => setState(() {
    final d = _vista == _Vista.semana ? 7 * pasos : pasos;
    _dia = DateTime(_dia.year, _dia.month, _dia.day + d);
  });

  Future<void> _nueva() async {
    final c = await editarCita(context, dia: _dia);
    if (c == null || !mounted) return;
    ref.read(versionIndiceProvider.notifier).cambio();
    setState(
      () => _dia = DateTime(c.inicio.year, c.inicio.month, c.inicio.day),
    );
    mostrarMensaje(
      context,
      'Cita agendada: ${diaYFecha(c.inicio)} a las ${horaTexto(c.inicio.hour * 60 + c.inicio.minute)}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(versionIndiceProvider);
    final s = ref.read(servicioConsultorioProvider);
    final ancho = MediaQuery.sizeOf(context).width;
    final movil = ancho < 700;
    final vista = movil ? _Vista.dia : _vista;
    final vencidos = s.indice.controlesVencidos;
    final pendientes = s.agenda.pendientesRecordatorio();
    final esHoy = _dia == _hoy;
    final titulo = vista == _Vista.dia
        ? diaYFecha(_dia)
        : 'Semana del ${formatoFecha(_lunes)} al '
              '${formatoFecha(DateTime(_lunes.year, _lunes.month, _lunes.day + 6))}';
    final cuerpo = vista == _Vista.dia
        ? _VistaDia(dia: _dia)
        : _VistaSemana(
            lunes: _lunes,
            alElegirDia: (d) => setState(() {
              _dia = d;
              _vista = _Vista.dia;
            }),
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Agenda',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (!movil)
            TextButton.icon(
              onPressed: () => context.go('/pacientes?vencidos=1'),
              icon: const Icon(Icons.alarm),
              label: Text('Controles vencidos ($vencidos)'),
            ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _nueva,
            icon: const Icon(Icons.add),
            label: const Text('Cita'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: GestureDetector(
        // En móvil se desliza entre días. El gesto no cambia al cruzar el
        // corte y queda fuera del árbol de accesibilidad (los lectores usan
        // «‹» y «›»): si cambiara, el motor web convertía el área en
        // desplazable con la semántica activa y lanzaba «Null check…».
        excludeFromSemantics: true,
        onHorizontalDragEnd: (d) {
          if (MediaQuery.sizeOf(context).width >= 700) return;
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 300) _mover(v < 0 ? 1 : -1);
        },
        child: CuerpoConsultorio(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: vista == _Vista.dia
                      ? 'Día anterior'
                      : 'Semana anterior',
                  onPressed: () => _mover(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                OutlinedButton(
                  onPressed: esHoy && vista == _Vista.dia
                      ? null
                      : () => setState(() => _dia = _hoy),
                  child: const Text('Hoy'),
                ),
                IconButton(
                  tooltip: vista == _Vista.dia
                      ? 'Día siguiente'
                      : 'Semana siguiente',
                  onPressed: () => _mover(1),
                  icon: const Icon(Icons.chevron_right),
                ),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!movil)
                  SegmentedButton<_Vista>(
                    segments: const [
                      ButtonSegment(value: _Vista.dia, label: Text('Día')),
                      ButtonSegment(
                        value: _Vista.semana,
                        label: Text('Semana'),
                      ),
                    ],
                    selected: {_vista},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => setState(() => _vista = v.first),
                  ),
                if (movil)
                  TextButton.icon(
                    onPressed: () => context.go('/pacientes?vencidos=1'),
                    icon: const Icon(Icons.alarm),
                    label: Text('Controles vencidos ($vencidos)'),
                  ),
              ],
            ),
            if (pendientes.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Recordatorios(citas: pendientes),
            ],
            const _AvisoInventario(),
            const SizedBox(height: 12),
            cuerpo,
          ],
        ),
      ),
    );
  }
}

/// «viernes 20/11/2026»
String diaYFecha(DateTime d) => '${nombreDia(d)} ${formatoFecha(d)}';

/// Lo del inventario que pide atención hoy: lotes vencidos con existencias,
/// bajo el mínimo y por vencer (pregunta 49).
class _AvisoInventario extends ConsumerWidget {
  const _AvisoInventario();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.read(servicioConsultorioProvider).inventario.alertas();
    final partes = [
      if (a.vencidos.isNotEmpty)
        '${a.vencidos.length} ${a.vencidos.length == 1 ? 'lote vencido' : 'lotes vencidos'}',
      if (a.bajoMinimo.isNotEmpty) '${a.bajoMinimo.length} bajo el mínimo',
      if (a.porVencer.isNotEmpty) '${a.porVencer.length} por vencer',
    ];
    if (partes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: RadiosMarca.tarjeta,
          border: Border.all(color: ColoresMarca.borde),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 18,
              color: ColoresMarca.aviso,
            ),
            Text(
              'Inventario: ${partes.join(' · ')}',
              style: const TextStyle(color: ColoresMarca.aviso),
            ),
            TextButton(
              onPressed: () => context.go('/inventario'),
              child: const Text('Ver el inventario'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Recordatorios extends ConsumerWidget {
  const _Recordatorios({required this.citas});

  final List<Cita> citas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.read(servicioConsultorioProvider).agenda;
    final n = citas.length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresMarca.avisoFondo,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.avisoBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mañana: $n ${n == 1 ? 'cita' : 'citas'} sin recordatorio',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: ColoresMarca.avisoTexto,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final c in citas)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // El nombre se parte en pantallas angostas.
                    Flexible(
                      child: Text(
                        '${agenda.fichaDe(c)?.nombreCompleto ?? 'Sin ficha'} · '
                        '${horaTexto(c.inicio.hour * 60 + c.inicio.minute)}',
                        style: const TextStyle(color: ColoresMarca.avisoTexto),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () => enviarRecordatorio(context, ref, c),
                      child: const Text('Enviar'),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VistaDia extends ConsumerWidget {
  const _VistaDia({required this.dia});

  final DateTime dia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.read(servicioConsultorioProvider).agenda;
    final h = agenda.horario;
    final citas = agenda.citasDelDia(dia);
    final fin = DateTime(dia.year, dia.month, dia.day + 1);
    final bloqueos = [
      for (final b in h.bloqueos)
        if (b.cruza(dia, fin)) b,
    ];
    final franjas = h.franjasDe(dia.weekday);
    final nombreFestivo = festivo(dia);
    final entradas = <(DateTime, Widget)>[
      for (final c in citas) (c.inicio, TarjetaCita(cita: c)),
      for (final b in bloqueos)
        (b.inicio.isBefore(dia) ? dia : b.inicio, _TarjetaBloqueo(bloqueo: b)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          [
            if (nombreFestivo != null) 'Festivo: $nombreFestivo (VERIFICAR)',
            franjas.isEmpty
                ? 'Sin atención en tu horario'
                : 'Horario: ${franjas.map((f) => f.texto).join(', ')}',
            '${citas.where((c) => c.estado.ocupa).length} '
                '${citas.where((c) => c.estado.ocupa).length == 1 ? 'cita' : 'citas'}',
          ].join(' · '),
          style: TextStyle(
            color: nombreFestivo != null
                ? ColoresMarca.aviso
                : ColoresMarca.textoSuave,
          ),
        ),
        const SizedBox(height: 10),
        if (entradas.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: RadiosMarca.tarjeta,
              border: Border.all(color: ColoresMarca.borde),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  color: ColoresMarca.textoSuave,
                  size: 32,
                ),
                SizedBox(height: 6),
                Text('Sin citas este día.'),
              ],
            ),
          ),
        for (final (_, w) in entradas) ...[w, const SizedBox(height: 10)],
      ],
    );
  }
}

class _TarjetaBloqueo extends ConsumerWidget {
  const _TarjetaBloqueo({required this.bloqueo});

  final BloqueoAgenda bloqueo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = bloqueo;
    final mismoDia =
        b.inicio.year == b.fin.year &&
        b.inicio.month == b.fin.month &&
        b.inicio.day == b.fin.day;
    String hora(DateTime f) => horaTexto(f.hour * 60 + f.minute);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresMarca.bloqueado,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Row(
        children: [
          const Icon(Icons.block, color: ColoresMarca.textoSuave, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bloqueado${b.motivo.isEmpty ? '' : ': ${b.motivo}'} · '
              '${mismoDia ? '${hora(b.inicio)}–${hora(b.fin)}' : '${formatoFechaHora(b.inicio)} a ${formatoFechaHora(b.fin)}'}',
              style: const TextStyle(color: ColoresMarca.textoSuave),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una cita con su estado y sus acciones.
class TarjetaCita extends ConsumerWidget {
  const TarjetaCita({super.key, required this.cita, this.conFecha = false});

  final Cita cita;

  /// Muestra también el día (en la ficha).
  final bool conFecha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.read(servicioConsultorioProvider);
    final c = cita;
    final ficha = s.agenda.fichaDe(c);
    final tipo = estiloTipo(c.tipo);
    final estado = estiloEstado(c.estado);
    final ahora = s.reloj.ahora();
    final inasistencias = ficha == null ? 0 : s.agenda.inasistencias(ficha.id);
    final plantilla = c.plantillaId == null
        ? null
        : s.procedimientos.plantilla(c.plantillaId!);
    final estados = [
      for (final e in EstadoCita.values)
        if (problemaCambioEstado(c, e, ahora) == null) e,
    ];
    final cobros = s.caja.cobrosDeCita(c.id);
    final saldoCita = cobros.fold(0, (a, x) => a + s.caja.saldo(x));
    final cobrado = cobros.isEmpty
        ? null
        : saldoCita > 0
        ? 'Saldo ${formatoPesos(saldoCita)}'
        : 'Cobrada';
    // En una sesión: si hay «apto» vigente ese día y consentimiento. (En
    // una valoración no: es la que da el «apto».)
    String? estetica;
    if (ficha != null && c.plantillaId != null && c.tipo == TipoCita.sesion) {
      final v = ultimaValoracion(
        s.procedimientos.valoracionesDe(ficha.id),
        c.plantillaId!,
      );
      final ev = estadoValoracion(v, c.inicio);
      final ci = s.procedimientos.consentimientoVigente(
        ficha.id,
        c.plantillaId!,
      );
      estetica = [
        ev == EstadoValoracion.vigente
            ? '✓ apto hasta ${formatoFecha(v!.vigenteHasta!)}'
            : '⚠ sin «apto» vigente',
        ci == null ? '⚠ sin consentimiento' : '✓ consentimiento ${ci.numero}',
      ].join(' · ');
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: tipo.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          [
                            if (conFecha) diaYFecha(c.inicio),
                            rangoHoras(c),
                          ].join(' · '),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tipo.icono, size: 18, color: tipo.color),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                [
                                  c.tipo.etiqueta,
                                  ?plantilla?.nombre,
                                ].join(' · '),
                              ),
                            ),
                          ],
                        ),
                        EtiquetaEstado(
                          icono: estado.icono,
                          texto: c.estado.etiqueta,
                          color: estado.color,
                        ),
                        if (cobrado != null)
                          EtiquetaEstado(
                            icono: Icons.point_of_sale,
                            texto: cobrado,
                            color: cobrado.startsWith('Saldo')
                                ? ColoresMarca.aviso
                                : ColoresMarca.estadoOk,
                          ),
                        if (c.recordatorioEnviado != null)
                          const EtiquetaEstado(
                            icono: Icons.chat_outlined,
                            texto: 'Recordatorio enviado',
                            color: ColoresMarca.textoSuave,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ficha?.nombreCompleto ?? 'Ficha no encontrada',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        if (ficha != null && ficha.documentoTexto.isNotEmpty)
                          ficha.documentoTexto,
                        if (ficha != null && ficha.telefono.isNotEmpty)
                          ficha.telefono,
                        if (inasistencias > 0)
                          '$inasistencias ${inasistencias == 1 ? 'inasistencia' : 'inasistencias'}',
                      ].join(' · '),
                      style: const TextStyle(color: ColoresMarca.textoSuave),
                    ),
                    if (c.motivo.trim().isNotEmpty)
                      Text(
                        'Motivo: ${c.motivo.trim()}',
                        style: const TextStyle(color: ColoresMarca.textoSuave),
                      ),
                    if (estetica != null)
                      Text(
                        estetica,
                        style: TextStyle(
                          color: estetica.contains('⚠')
                              ? ColoresMarca.aviso
                              : ColoresMarca.estadoOk,
                        ),
                      ),
                    if (c.estado == EstadoCita.cancelada &&
                        c.historial.isNotEmpty &&
                        c.historial.last.motivo.isNotEmpty)
                      Text(
                        'Cancelada: ${c.historial.last.motivo}',
                        style: const TextStyle(color: ColoresMarca.textoSuave),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (estados.isNotEmpty)
                          MenuAnchor(
                            menuChildren: [
                              for (final e in estados)
                                MenuItemButton(
                                  leadingIcon: Icon(estiloEstado(e).icono),
                                  onPressed: () =>
                                      cambiarEstadoCita(context, ref, c, e),
                                  child: Text(switch (e) {
                                    EstadoCita.agendada => 'Volver a agendada',
                                    EstadoCita.confirmada => 'Confirmada',
                                    EstadoCita.atendida => 'Atendida',
                                    EstadoCita.noAsistio => 'No asistió',
                                    EstadoCita.cancelada => 'Cancelar…',
                                  }),
                                ),
                            ],
                            builder: (context, menu, _) => OutlinedButton.icon(
                              onPressed: () =>
                                  menu.isOpen ? menu.close() : menu.open(),
                              icon: const Icon(Icons.arrow_drop_down),
                              label: const Text('Estado'),
                            ),
                          ),
                        if (!c.estado.cerrada) ...[
                          OutlinedButton.icon(
                            onPressed: () =>
                                enviarRecordatorio(context, ref, c),
                            icon: const Icon(Icons.chat_outlined),
                            label: const Text('WhatsApp'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => descargarIcs(ref, c),
                            icon: const Icon(Icons.event_outlined),
                            label: const Text('.ics'),
                          ),
                        ],
                        if (ficha != null && !conFecha)
                          OutlinedButton.icon(
                            onPressed: () =>
                                context.go('/pacientes/${ficha.id}'),
                            icon: const Icon(Icons.badge_outlined),
                            label: const Text('Ficha'),
                          ),
                        if (!c.estado.cerrada) ...[
                          OutlinedButton.icon(
                            onPressed: () async {
                              final g = await editarCita(context, cita: c);
                              if (g != null) {
                                ref
                                    .read(versionIndiceProvider.notifier)
                                    .cambio();
                              }
                            },
                            icon: const Icon(Icons.edit_calendar_outlined),
                            label: const Text('Reprogramar'),
                          ),
                          FilledButton.icon(
                            onPressed: () => atenderCita(context, ref, c),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Atender'),
                          ),
                        ],
                        if (ficha != null &&
                            c.estado != EstadoCita.cancelada &&
                            c.estado != EstadoCita.noAsistio)
                          OutlinedButton.icon(
                            onPressed: () => abrirCobro(context, ref, cita: c),
                            icon: const Icon(Icons.point_of_sale),
                            label: const Text('Cobrar'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VistaSemana extends ConsumerWidget {
  const _VistaSemana({required this.lunes, required this.alElegirDia});

  final DateTime lunes;
  final ValueChanged<DateTime> alElegirDia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.read(servicioConsultorioProvider);
    final agenda = s.agenda;
    final hoy = s.reloj.ahora();
    final dias = [
      for (var i = 0; i < 7; i++)
        DateTime(lunes.year, lunes.month, lunes.day + i),
    ];
    return LayoutBuilder(
      builder: (context, cons) {
        final anchoColumna = (cons.maxWidth / 7).clamp(132.0, 400.0);
        final columnas = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in dias)
              SizedBox(
                width: anchoColumna,
                child: _ColumnaDia(
                  dia: d,
                  citas: agenda.citasDelDia(d),
                  esHoy:
                      d.year == hoy.year &&
                      d.month == hoy.month &&
                      d.day == hoy.day,
                  bloqueado: agenda.horario.bloqueos.any(
                    (b) => b.cruza(d, DateTime(d.year, d.month, d.day + 1)),
                  ),
                  sinAtencion: agenda.horario.franjasDe(d.weekday).isEmpty,
                  alElegir: () => alElegirDia(d),
                ),
              ),
          ],
        );
        return anchoColumna * 7 > cons.maxWidth
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: columnas,
              )
            : columnas;
      },
    );
  }
}

class _ColumnaDia extends ConsumerWidget {
  const _ColumnaDia({
    required this.dia,
    required this.citas,
    required this.esHoy,
    required this.bloqueado,
    required this.sinAtencion,
    required this.alElegir,
  });

  final DateTime dia;
  final List<Cita> citas;
  final bool esHoy;
  final bool bloqueado;
  final bool sinAtencion;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.read(servicioConsultorioProvider).agenda;
    final nombreFestivo = festivo(dia);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        constraints: const BoxConstraints(minHeight: 260),
        decoration: BoxDecoration(
          color: sinAtencion || nombreFestivo != null
              ? ColoresMarca.bloqueado
              : Colors.white,
          borderRadius: RadiosMarca.recuadro,
          border: Border.all(
            color: esHoy ? ColoresMarca.primario : ColoresMarca.borde,
            width: esHoy ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: alElegir,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${nombreDia(dia)} ${dia.day}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: esHoy
                            ? ColoresMarca.primario
                            : ColoresMarca.tinta,
                      ),
                    ),
                    if (nombreFestivo != null)
                      Text(
                        'Festivo',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ColoresMarca.aviso,
                        ),
                      ),
                    if (bloqueado)
                      const Text(
                        'Con bloqueo',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColoresMarca.textoSuave,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            for (final c in citas)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                child: _BloqueCita(
                  cita: c,
                  nombre: agenda.fichaDe(c)?.nombreCompleto ?? '—',
                  alTocar: alElegir,
                ),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _BloqueCita extends StatelessWidget {
  const _BloqueCita({
    required this.cita,
    required this.nombre,
    required this.alTocar,
  });

  final Cita cita;
  final String nombre;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final t = estiloTipo(cita.tipo);
    final apagada = !cita.estado.ocupa;
    return Material(
      color: t.color.withValues(alpha: apagada ? 0.04 : 0.09),
      shape: RoundedRectangleBorder(
        borderRadius: RadiosMarca.control,
        side: BorderSide(color: t.color.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: alTocar,
        borderRadius: RadiosMarca.control,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(t.icono, size: 15, color: t.color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      rangoHoras(cita),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  decoration: apagada ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(
                '${cita.tipo.etiqueta} · ${cita.estado.etiqueta}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: ColoresMarca.textoSuave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
