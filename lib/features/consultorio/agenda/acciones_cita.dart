import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/agenda/cita.dart';
import '../../../core/consultorio/agenda/recordatorio.dart';
import '../../../core/consultorio/reglas/agenda.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../medico/medico_provider.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../integracion/enganche_historia.dart';
import '../widgets/comunes.dart';
import '../widgets/texto_normativo.dart';

/// El lugar de la cita para el recordatorio y el `.ics`: el consultorio
/// (o tu nombre), la dirección y la ciudad.
({String consultorio, String direccion}) lugarDeCita(WidgetRef ref) {
  final m = ref.read(medicoProvider);
  return (
    consultorio: m.consultorio.trim().isNotEmpty
        ? m.consultorio.trim()
        : m.nombre.trim(),
    direccion: [
      m.direccion.trim(),
      m.ciudad.trim(),
    ].where((s) => s.isNotEmpty).join(', '),
  );
}

/// Cambia el estado de [c]; cancelar pide el motivo.
Future<void> cambiarEstadoCita(
  BuildContext context,
  WidgetRef ref,
  Cita c,
  EstadoCita estado,
) async {
  var motivo = '';
  if (estado == EstadoCita.cancelada) {
    final m = await pedirTexto(
      context,
      titulo: 'Cancelar la cita',
      etiqueta: 'Motivo de la cancelación',
      aceptar: 'Cancelar la cita',
    );
    if (m == null) return;
    motivo = m;
  }
  try {
    await ref
        .read(servicioConsultorioProvider)
        .agenda
        .cambiarEstado(c.id, estado, motivo: motivo);
    ref.read(versionIndiceProvider.notifier).cambio();
  } catch (e) {
    if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
  }
}

/// Muestra el recordatorio (editable) y lo abre en WhatsApp; la cita queda
/// con el recordatorio enviado.
Future<void> enviarRecordatorio(
  BuildContext context,
  WidgetRef ref,
  Cita c,
) async {
  final agenda = ref.read(servicioConsultorioProvider).agenda;
  final ficha = agenda.fichaDe(c);
  final numero = ficha == null ? null : numeroWhatsapp(ficha.telefono);
  if (ficha == null || numero == null) {
    mostrarMensaje(
      context,
      ficha == null || ficha.telefono.trim().isEmpty
          ? 'La ficha no tiene teléfono: escríbelo en «Editar datos».'
          : 'El teléfono ${ficha.telefono} no es un celular: WhatsApp necesita '
                'un celular (o un número con indicativo, «+…»).',
    );
    return;
  }
  final lugar = lugarDeCita(ref);
  final texto = mensajeRecordatorio(
    agenda.horario.mensaje,
    nombre: ficha.nombres.trim().isEmpty ? ficha.nombreCompleto : ficha.nombres,
    inicio: c.inicio,
    consultorio: lugar.consultorio,
    direccion: lugar.direccion,
  );
  final mensaje = await showDialog<String>(
    context: context,
    builder: (_) => _DialogoRecordatorio(
      paciente: ficha.nombreCompleto,
      numero: numero,
      texto: texto,
    ),
  );
  if (mensaje == null || !context.mounted) return;
  ref.read(abrirEnlaceProvider)(urlWhatsapp(numero, mensaje));
  await agenda.marcarRecordatorio(c.id);
  ref.read(versionIndiceProvider.notifier).cambio();
}

class _DialogoRecordatorio extends StatefulWidget {
  const _DialogoRecordatorio({
    required this.paciente,
    required this.numero,
    required this.texto,
  });

  final String paciente;
  final String numero;
  final String texto;

  @override
  State<_DialogoRecordatorio> createState() => _DialogoRecordatorioState();
}

class _DialogoRecordatorioState extends State<_DialogoRecordatorio> {
  late final _texto = TextEditingController(text: widget.texto);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const TituloDialogo(
      'Recordatorio por WhatsApp',
      icono: Icons.chat_outlined,
    ),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Para ${widget.paciente} · +${widget.numero}'),
          const SizedBox(height: 10),
          TextField(
            controller: _texto,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Mensaje'),
          ),
          const SizedBox(height: 8),
          const TextoNormativo(
            'WhatsApp es un tercero: el mensaje no lleva datos de salud ni el '
            'tipo de cita (VERIFICAR con tu abogado). Se abre en otra '
            'pestaña; lo envías tú.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton.icon(
        onPressed: () => Navigator.pop(context, _texto.text.trim()),
        icon: const Icon(Icons.open_in_new),
        label: const Text('Abrir WhatsApp'),
      ),
    ],
  );
}

/// Descarga el `.ics` de la cita (solo «Cita médica», la hora y el lugar).
void descargarIcs(WidgetRef ref, Cita c) {
  final agenda = ref.read(servicioConsultorioProvider).agenda;
  final lugar = lugarDeCita(ref);
  final ics = icsCita(
    c,
    lugar: [
      lugar.consultorio,
      lugar.direccion,
    ].where((s) => s.isNotEmpty).join(', '),
    ahora: agenda.reloj.ahora(),
  );
  ref.read(descargarArchivoProvider)(utf8.encode(ics), nombreArchivoIcs(c));
}

/// «Atender»: abre la evolución de su historia más reciente (o una historia
/// nueva) con el paciente cargado, y marca la cita atendida.
Future<void> atenderCita(BuildContext context, WidgetRef ref, Cita c) async {
  final s = ref.read(servicioConsultorioProvider);
  final ficha = s.agenda.fichaDe(c);
  if (ficha == null) return;
  final tieneHistorias = s.indice.ultimaHistoria(ficha.id) != null;
  if (!await confirmarReemplazoHistoria(
    context,
    ref,
    pacienteId: ficha.id,
    continuar: tieneHistorias,
  )) {
    return;
  }
  if (tieneHistorias) {
    await nuevaEvolucionPara(ref, ficha.id);
  } else {
    await nuevaHistoriaPara(ref, ficha);
  }
  if (problemaCambioEstado(c, EstadoCita.atendida, s.reloj.ahora()) == null) {
    await s.agenda.cambiarEstado(c.id, EstadoCita.atendida);
  }
  ref.read(versionIndiceProvider.notifier).cambio();
  if (context.mounted) context.go('/');
}
