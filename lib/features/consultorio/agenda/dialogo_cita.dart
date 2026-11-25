import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/agenda/cita.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/pais/perfil_pais.dart' show Opcion;
import '../../../core/widgets/campo_sugerencias.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../pacientes/dialogo_ficha.dart';
import '../widgets/comunes.dart';
import '../widgets/texto_normativo.dart';

/// Agenda una cita nueva (o reprograma [cita]). Devuelve la guardada.
Future<Cita?> editarCita(
  BuildContext context, {
  Cita? cita,
  DateTime? dia,
  String? pacienteId,
}) => showDialog<Cita>(
  context: context,
  builder: (_) => _DialogoCita(cita: cita, dia: dia, pacienteId: pacienteId),
);

class _DialogoCita extends ConsumerStatefulWidget {
  const _DialogoCita({this.cita, this.dia, this.pacienteId});

  final Cita? cita;
  final DateTime? dia;
  final String? pacienteId;

  @override
  ConsumerState<_DialogoCita> createState() => _DialogoCitaState();
}

class _DialogoCitaState extends ConsumerState<_DialogoCita> {
  late Cita _c;
  final _paciente = TextEditingController();
  var _guardando = false;
  String? _error;

  /// Sube al elegir una hora libre: el campo de hora se vuelve a crear.
  var _generacionHora = 0;

  @override
  void initState() {
    super.initState();
    final agenda = ref.read(servicioConsultorioProvider).agenda;
    final existente = widget.cita;
    if (existente != null) {
      _c = existente;
    } else {
      final ahora = agenda.reloj.ahora();
      final dia = widget.dia ?? ahora;
      final base = DateTime(dia.year, dia.month, dia.day);
      final libres = agenda.libres(
        base,
        agenda.horario.duracion(TipoCita.control),
      );
      final primera = libres.where((l) => l.isAfter(ahora)).firstOrNull;
      _c = agenda.nueva(
        tipo: TipoCita.control,
        inicio: primera ?? DateTime(base.year, base.month, base.day, 8),
        pacienteId: widget.pacienteId ?? '',
      );
    }
    final f = _ficha;
    if (f != null) _paciente.text = f.nombreCompleto;
  }

  @override
  void dispose() {
    _paciente.dispose();
    super.dispose();
  }

  FichaPaciente? get _ficha => _c.pacienteId.isEmpty
      ? null
      : ref.read(servicioConsultorioProvider).indice.fichaActiva(_c.pacienteId);

  void _poner(Cita c) => setState(() {
    _c = c;
    _error = null;
  });

  void _cambiarTipo(TipoCita t) {
    final agenda = ref.read(servicioConsultorioProvider).agenda;
    final plantillas = ref
        .read(servicioConsultorioProvider)
        .procedimientos
        .plantillas;
    _poner(
      _c.copyWith(
        tipo: t,
        duracionMin: agenda.horario.duracion(t),
        plantillaId: t.estetica
            ? (_c.plantillaId ?? plantillas.firstOrNull?.id)
            : null,
      ),
    );
  }

  Future<void> _pacienteNuevo() async {
    final f = await editarFicha(context);
    if (f == null || !mounted) return;
    ref.read(versionIndiceProvider.notifier).cambio();
    _paciente.text = f.nombreCompleto;
    _poner(_c.copyWith(pacienteId: f.id));
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final g = await ref.read(servicioConsultorioProvider).agenda.guardar(_c);
      if (mounted) Navigator.pop(context, g);
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
    final s = ref.read(servicioConsultorioProvider);
    final agenda = s.agenda;
    final e = agenda.evaluar(_c);
    final c = _c;
    final libres = agenda
        .libres(c.inicio, c.duracionMin, sin: c.id)
        .where((l) => l.isAfter(agenda.reloj.ahora()))
        .take(12)
        .toList();
    final ficha = _ficha;
    final movil = MediaQuery.sizeOf(context).width < 600;
    return AlertDialog(
      title: TituloDialogo(
        widget.cita == null ? 'Nueva cita' : 'Reprogramar la cita',
        icono: Icons.event_available_outlined,
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: movil ? 12 : 40,
        vertical: 24,
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CampoSugerencias<FichaPaciente>(
                      etiqueta: 'Paciente',
                      requerido: true,
                      controller: _paciente,
                      pista: 'Nombre o documento',
                      sugerencias: (q) => q.trim().length < 2
                          ? const []
                          : [
                              for (final r in s.indice.buscar(texto: q).take(8))
                                r.ficha,
                            ],
                      texto: (f) => f.nombreCompleto,
                      detalle: (f) => [
                        f.documentoTexto,
                        f.telefono,
                      ].where((t) => t.isNotEmpty).join(' · '),
                      alElegir: (f) {
                        _paciente.text = f.nombreCompleto;
                        _poner(c.copyWith(pacienteId: f.id));
                      },
                      alCambiar: (v) {
                        if (ficha != null && v != ficha.nombreCompleto) {
                          _poner(c.copyWith(pacienteId: ''));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: TextButton.icon(
                      onPressed: _pacienteNuevo,
                      icon: const Icon(Icons.person_add_alt_outlined),
                      label: const Text('Paciente nuevo'),
                    ),
                  ),
                ],
              ),
              if (ficha != null && ficha.telefono.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Sin teléfono: no se podrá enviar el recordatorio.',
                    style: TextStyle(color: ColoresMarca.textoSuave),
                  ),
                ),
              const SizedBox(height: 12),
              RejillaCampos(
                anchoMinimo: 220,
                children: [
                  CampoDesplegable(
                    etiqueta: 'Tipo de cita',
                    opciones: [
                      for (final t in TipoCita.values)
                        Opcion(t.name, t.etiqueta),
                    ],
                    valor: c.tipo.name,
                    alCambiar: (v) => _cambiarTipo(TipoCita.values.byName(v)),
                  ),
                  if (c.tipo.estetica)
                    CampoDesplegable(
                      etiqueta: 'Procedimiento',
                      opciones: [
                        for (final p in s.procedimientos.plantillas)
                          Opcion(p.id, p.nombre),
                      ],
                      valor: c.plantillaId,
                      alCambiar: (v) => _poner(c.copyWith(plantillaId: v)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              RejillaCampos(
                anchoMinimo: 160,
                children: [
                  CampoFecha(
                    key: ValueKey('fecha-$_generacionHora'),
                    etiqueta: 'Día',
                    requerido: true,
                    valor: c.inicio,
                    alCambiar: (f) {
                      if (f == null) return;
                      _poner(
                        c.copyWith(
                          inicio: DateTime(
                            f.year,
                            f.month,
                            f.day,
                            c.inicio.hour,
                            c.inicio.minute,
                          ),
                        ),
                      );
                    },
                  ),
                  CampoHora(
                    key: ValueKey('hora-$_generacionHora'),
                    etiqueta: 'Hora',
                    hora: c.inicio.hour,
                    minuto: c.inicio.minute,
                    alCambiar: (h, m) => _poner(
                      c.copyWith(
                        inicio: DateTime(
                          c.inicio.year,
                          c.inicio.month,
                          c.inicio.day,
                          h,
                          m,
                        ),
                      ),
                    ),
                  ),
                  CampoEntero(
                    key: ValueKey('duracion-${c.tipo.name}'),
                    etiqueta: 'Duración',
                    sufijo: 'min',
                    valor: c.duracionMin,
                    alCambiar: (v) => _poner(c.copyWith(duracionMin: v ?? 0)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                libres.isEmpty
                    ? 'Sin horas libres ese día en tu horario.'
                    : 'Horas libres ese día',
                style: const TextStyle(color: ColoresMarca.textoSuave),
              ),
              if (libres.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final l in libres)
                      ActionChip(
                        label: Text(
                          '${l.hour.toString().padLeft(2, '0')}:'
                          '${l.minute.toString().padLeft(2, '0')}',
                        ),
                        onPressed: () {
                          _generacionHora++;
                          _poner(c.copyWith(inicio: l));
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              CampoTexto(
                etiqueta: 'Motivo',
                valorInicial: c.motivo,
                pista: 'Solo para ti: no va en el recordatorio',
                alCambiar: (v) => _c = _c.copyWith(motivo: v),
              ),
              const SizedBox(height: 12),
              CampoTexto(
                etiqueta: 'Notas',
                valorInicial: c.notas,
                lineas: 2,
                alCambiar: (v) => _c = _c.copyWith(notas: v),
              ),
              if (e.bloqueos.isNotEmpty || e.avisos.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final m in e.bloqueos)
                  _Linea(m, Icons.block, ColoresMarca.error),
                for (final m in e.avisos)
                  _Linea(m, Icons.warning_amber_rounded, ColoresMarca.aviso),
              ],
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
          onPressed: _guardando || !e.permiteGuardar ? null : _guardar,
          child: Text(widget.cita == null ? 'Agendar' : 'Guardar'),
        ),
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.texto, this.icono, this.color);

  final String texto;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: TextoNormativo(texto, style: TextStyle(color: color)),
        ),
      ],
    ),
  );
}
