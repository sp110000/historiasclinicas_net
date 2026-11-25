import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/agenda/cita.dart';
import '../../../core/consultorio/agenda/horario.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import '../widgets/texto_normativo.dart';

const _nombresDias = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Ajustes → Agenda: horario por día, duraciones por tipo, mensaje del
/// recordatorio y bloqueos (pregunta 42 y 43).
class TarjetaAgenda extends ConsumerStatefulWidget {
  const TarjetaAgenda({super.key});

  @override
  ConsumerState<TarjetaAgenda> createState() => _TarjetaAgendaState();
}

class _TarjetaAgendaState extends ConsumerState<TarjetaAgenda> {
  late HorarioAgenda _h = ref.read(servicioConsultorioProvider).agenda.horario;
  late final _textos = {
    for (var d = 1; d <= 7; d++)
      d: _h.franjasDe(d).map((f) => f.texto).join(', '),
  };
  var _guardando = false;

  Map<int, String> get _errores => {
    for (final e in _textos.entries)
      if (leerFranjas(e.value) == null)
        e.key: 'No se entiende: «8:00–12:00, 14:00–18:00»',
  };

  Future<void> _guardar() async {
    if (_errores.isNotEmpty) return;
    setState(() => _guardando = true);
    try {
      final h = _h.copyWith(
        franjas: {
          for (final e in _textos.entries)
            if (leerFranjas(e.value)!.isNotEmpty) e.key: leerFranjas(e.value)!,
        },
      );
      await ref.read(servicioConsultorioProvider).agenda.guardarHorario(h);
      _h = h;
      ref.read(versionIndiceProvider.notifier).cambio();
      if (mounted) mostrarMensaje(context, 'Agenda guardada.');
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _agregarBloqueo() async {
    final b =
        await showDialog<({DateTime inicio, DateTime fin, String motivo})>(
          context: context,
          builder: (_) => const _DialogoBloqueo(),
        );
    if (b == null || !mounted) return;
    try {
      final agenda = ref.read(servicioConsultorioProvider).agenda;
      await agenda.agregarBloqueo(
        inicio: b.inicio,
        fin: b.fin,
        motivo: b.motivo,
      );
      setState(() => _h = _h.copyWith(bloqueos: agenda.horario.bloqueos));
      ref.read(versionIndiceProvider.notifier).cambio();
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeDeError(e));
    }
  }

  Future<void> _quitar(BloqueoAgenda b) async {
    final agenda = ref.read(servicioConsultorioProvider).agenda;
    await agenda.quitarBloqueo(b.id);
    setState(() => _h = _h.copyWith(bloqueos: agenda.horario.bloqueos));
    ref.read(versionIndiceProvider.notifier).cambio();
  }

  @override
  Widget build(BuildContext context) {
    final errores = _errores;
    return TarjetaConsultorio(
      icono: Icons.calendar_month_outlined,
      titulo: 'Agenda',
      subtitulo: 'Horario, duraciones, recordatorio y bloqueos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TextoNormativo(
            'Horario por día («8:00–12:00, 14:00–18:00»; en blanco, sin '
            'atención). Los festivos de Colombia se calculan solos (Ley 51 de '
            '1983, VERIFICAR). Una cita fuera del horario, en festivo o '
            'cruzada con otra avisa, pero no se bloquea.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 10),
          RejillaCampos(
            anchoMinimo: 260,
            children: [
              for (var d = 1; d <= 7; d++)
                CampoTexto(
                  etiqueta: _nombresDias[d - 1],
                  valorInicial: _textos[d],
                  ayuda: errores[d],
                  alCambiar: (v) => setState(() => _textos[d] = v),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Duración por tipo de cita (minutos)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          RejillaCampos(
            anchoMinimo: 180,
            children: [
              for (final t in TipoCita.values)
                CampoEntero(
                  etiqueta: t.etiqueta,
                  sufijo: 'min',
                  valor: _h.duracion(t),
                  alCambiar: (v) => _h = _h.copyWith(
                    duraciones: {
                      ..._h.duraciones,
                      t: (v ?? t.duracionPorDefecto).clamp(5, 480),
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          CampoTexto(
            etiqueta: 'Mensaje del recordatorio por WhatsApp',
            valorInicial: _h.mensaje,
            lineas: 3,
            ayuda: textoPresentable(
              ref,
              'Marcadores: {nombre}, {dia}, {hora}, {consultorio} y '
              '{direccion}. Sin datos de salud ni el tipo de cita (pregunta '
              '43, VERIFICAR).',
            ),
            alCambiar: (v) => _h = _h.copyWith(
              mensaje: v.trim().isEmpty ? mensajeRecordatorioPorDefecto : v,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _guardando || errores.isNotEmpty ? null : _guardar,
              child: const Text('Guardar la agenda'),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Bloqueos', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          if (_h.bloqueos.isEmpty)
            const Text(
              'Sin bloqueos (vacaciones, reuniones…).',
              style: TextStyle(color: ColoresMarca.textoSuave),
            ),
          for (final b in _h.bloqueos)
            Row(
              children: [
                const Icon(
                  Icons.block,
                  size: 18,
                  color: ColoresMarca.textoSuave,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${formatoFechaHora(b.inicio)} a ${formatoFechaHora(b.fin)}'
                    '${b.motivo.isEmpty ? '' : ' · ${b.motivo}'}',
                  ),
                ),
                TextButton(
                  onPressed: () => _quitar(b),
                  child: const Text('Quitar'),
                ),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _agregarBloqueo,
              icon: const Icon(Icons.add),
              label: const Text('Agregar bloqueo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogoBloqueo extends StatefulWidget {
  const _DialogoBloqueo();

  @override
  State<_DialogoBloqueo> createState() => _DialogoBloqueoState();
}

class _DialogoBloqueoState extends State<_DialogoBloqueo> {
  DateTime? _desde;
  DateTime? _hasta;
  var _horaDesde = (h: 8, m: 0);
  var _horaHasta = (h: 18, m: 0);
  var _motivo = '';

  DateTime? get _inicio => _desde == null
      ? null
      : DateTime(
          _desde!.year,
          _desde!.month,
          _desde!.day,
          _horaDesde.h,
          _horaDesde.m,
        );

  DateTime? get _fin {
    final d = _hasta ?? _desde;
    return d == null
        ? null
        : DateTime(d.year, d.month, d.day, _horaHasta.h, _horaHasta.m);
  }

  @override
  Widget build(BuildContext context) {
    final valido = _inicio != null && _fin != null && _inicio!.isBefore(_fin!);
    return AlertDialog(
      title: const TituloDialogo('Bloquear la agenda', icono: Icons.block),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RejillaCampos(
              anchoMinimo: 180,
              children: [
                CampoFecha(
                  etiqueta: 'Desde el día',
                  requerido: true,
                  valor: _desde,
                  alCambiar: (f) => setState(() => _desde = f),
                ),
                CampoHora(
                  etiqueta: 'A las',
                  hora: _horaDesde.h,
                  minuto: _horaDesde.m,
                  alCambiar: (h, m) =>
                      setState(() => _horaDesde = (h: h, m: m)),
                ),
                CampoFecha(
                  etiqueta: 'Hasta el día',
                  valor: _hasta,
                  ayuda: 'En blanco, el mismo día',
                  alCambiar: (f) => setState(() => _hasta = f),
                ),
                CampoHora(
                  etiqueta: 'Hasta las',
                  hora: _horaHasta.h,
                  minuto: _horaHasta.m,
                  alCambiar: (h, m) =>
                      setState(() => _horaHasta = (h: h, m: m)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CampoTexto(
              etiqueta: 'Motivo',
              pista: 'Vacaciones, reunión…',
              alCambiar: (v) => _motivo = v,
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
          onPressed: valido
              ? () => Navigator.pop(context, (
                  inicio: _inicio!,
                  fin: _fin!,
                  motivo: _motivo,
                ))
              : null,
          child: const Text('Bloquear'),
        ),
      ],
    );
  }
}
