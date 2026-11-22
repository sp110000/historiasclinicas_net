import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/modelos/configuracion.dart';
import '../../../core/widgets/campos.dart';
import '../estado/consultorio_provider.dart';
import '../widgets/comunes.dart';

/// Ajustes → Prestador y póliza: código REPS, NIT, habilitación del
/// servicio y póliza de complicaciones (pregunta 34), y los límites de la
/// incapacidad. Los usan el consentimiento informado y la incapacidad.
class TarjetaPrestador extends ConsumerStatefulWidget {
  const TarjetaPrestador({super.key});

  @override
  ConsumerState<TarjetaPrestador> createState() => _TarjetaPrestadorState();
}

class _TarjetaPrestadorState extends ConsumerState<TarjetaPrestador> {
  late ConfiguracionConsultorio _c = ref
      .read(servicioConsultorioProvider)
      .configuracion;
  var _guardando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await ref.read(consultorioProvider.notifier).guardarConfiguracion(_c);
      if (mounted) mostrarMensaje(context, 'Datos del prestador guardados.');
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return TarjetaConsultorio(
      icono: Icons.badge_outlined,
      titulo: 'Prestador y póliza',
      subtitulo: 'REPS, NIT, habilitación y póliza de complicaciones',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Los usan el consentimiento informado y la incapacidad. VERIFICAR '
            'la habilitación del servicio en el REPS (Resolución 3100 de '
            '2019) y la póliza que te exija la norma.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 12),
          RejillaCampos(
            anchoMinimo: 200,
            children: [
              CampoTexto(
                etiqueta: 'Código de prestador (REPS)',
                valorInicial: c.codigoReps,
                alCambiar: (v) => _c = _c.copyWith(codigoReps: v),
              ),
              CampoTexto(
                etiqueta: 'NIT',
                valorInicial: c.nit,
                alCambiar: (v) => _c = _c.copyWith(nit: v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CampoTexto(
            etiqueta: 'Habilitación del servicio',
            valorInicial: c.habilitacion,
            pista: 'Servicio habilitado y su número',
            alCambiar: (v) => _c = _c.copyWith(habilitacion: v),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: c.sinPoliza,
            onChanged: (v) =>
                setState(() => _c = _c.copyWith(sinPoliza: v ?? false)),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Sin póliza de complicaciones'),
          ),
          if (!c.sinPoliza)
            RejillaCampos(
              anchoMinimo: 200,
              children: [
                CampoTexto(
                  etiqueta: 'Aseguradora de la póliza',
                  valorInicial: c.polizaAseguradora,
                  alCambiar: (v) => _c = _c.copyWith(polizaAseguradora: v),
                ),
                CampoTexto(
                  etiqueta: 'Número de la póliza',
                  valorInicial: c.polizaNumero,
                  alCambiar: (v) => _c = _c.copyWith(polizaNumero: v),
                ),
              ],
            ),
          const SizedBox(height: 16),
          const Text(
            'Límites de la incapacidad',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Escríbelos solo cuando los verifiques en el Decreto 1427 de 2022 '
            '(VERIFICAR). En blanco, la incapacidad no avisa por los días; '
            'una retroactiva avisa siempre.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 8),
          RejillaCampos(
            anchoMinimo: 200,
            children: [
              CampoNumero(
                etiqueta: 'Máximo de días por incapacidad',
                decimales: false,
                valor: c.maxDiasIncapacidad == 0
                    ? null
                    : c.maxDiasIncapacidad.toDouble(),
                alCambiar: (v) =>
                    _c = _c.copyWith(maxDiasIncapacidad: (v ?? 0).round()),
              ),
              CampoNumero(
                etiqueta: 'Máximo de días retroactivos',
                decimales: false,
                valor: c.maxDiasRetroactivos == 0
                    ? null
                    : c.maxDiasRetroactivos.toDouble(),
                alCambiar: (v) =>
                    _c = _c.copyWith(maxDiasRetroactivos: (v ?? 0).round()),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: const Text('Guardar datos del prestador'),
            ),
          ),
        ],
      ),
    );
  }
}
