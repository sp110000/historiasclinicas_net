import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/peso/catalogo_glp1.dart';
import '../../../core/consultorio/peso/plantillas_plan.dart';
import '../../../core/consultorio/peso/programas.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/utils/numeros.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../historia/widgets/dialogos.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import '../widgets/editor_versionado.dart';
import 'dialogos_peso.dart' show InfoMedicamento;

ProgramasPeso _peso(WidgetRef ref) =>
    ref.read(servicioConsultorioProvider).peso;

/// Ajustes → Programa de peso: catálogo GLP-1 (registro Invima, indicación
/// y esquema de titulación con aprobación) y plantillas de plan.
class TarjetaProgramaPeso extends ConsumerWidget {
  const TarjetaProgramaPeso({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final peso = _peso(ref);
    return TarjetaConsultorio(
      icono: Icons.monitor_weight_outlined,
      titulo: 'Programa de peso',
      subtitulo: 'Catálogo GLP-1 y plantillas de plan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Todo el catálogo va VERIFICAR contra la ficha técnica con '
            'registro Invima. La app no trae dosis: el esquema de titulación '
            'lo escribes y lo apruebas tú; mientras no esté aprobado solo se '
            'muestra como referencia.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 10),
          const Text('CATÁLOGO GLP-1', style: EstilosMarca.rotulo),
          for (final m in peso.catalogo) _FilaMedicamento(medicamento: m),
          const Divider(height: 24),
          const Text('PLANTILLAS DE PLAN', style: EstilosMarca.rotulo),
          const SizedBox(height: 4),
          const Text(
            'Vienen con los apartados en blanco («______»): complétalos con '
            'tus indicaciones y apruébalas para usarlas en los programas.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          for (final p in peso.plantillas)
            FilaVersionada(
              nombre: '${p.nombre} · ${p.tipo.etiqueta.toLowerCase()}',
              versiones: p.versiones,
              textoAprobar:
                  'Desde ahora los programas nuevos pueden usar «${p.nombre}».',
              alEditar: () async {
                final ok = await editarTextoVersionado(
                  context,
                  titulo: p.tipo.etiqueta,
                  versiones: p.versiones,
                  marcadores: marcadoresPlan,
                  guardar: (titulo, cuerpo) =>
                      _peso(ref).guardarBorradorPlan(p.id, titulo, cuerpo),
                );
                if (ok) ref.read(versionIndiceProvider.notifier).cambio();
              },
              alAprobar: () async {
                await _peso(ref).aprobarPlan(p.id);
                ref.read(versionIndiceProvider.notifier).cambio();
              },
            ),
        ],
      ),
    );
  }
}

class _FilaMedicamento extends ConsumerWidget {
  const _FilaMedicamento({required this.medicamento});

  final MedicamentoGlp1 medicamento;

  Future<void> _aprobar(BuildContext context, WidgetRef ref) async {
    final m = medicamento;
    final si = await confirmar(
      context,
      titulo: '¿Aprobar el esquema de ${m.generico}?',
      texto:
          '${m.esquema.map((p) => p.texto).join(' · ')}. Desde ahora el '
          'cambio de dosis sugiere este esquema. Confirma que lo revisaste '
          'contra la ficha técnica (VERIFICAR).',
      aceptar: 'Aprobar',
      icono: Icons.verified_outlined,
    );
    if (!si) return;
    try {
      await _peso(ref).aprobarEsquema(m.id);
      ref.read(versionIndiceProvider.notifier).cambio();
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = medicamento;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          InfoMedicamento(medicamento: m),
          if (m.esquema.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Esquema: ${m.esquema.map((p) => p.texto).join(' · ')}'
              '${m.esquemaAprobado ? ' (aprobado el ${formatoFecha(m.esquemaAprobadoEn!)})' : ''}',
              style: const TextStyle(color: ColoresMarca.textoSuave),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _EditorMedicamento(medicamento: m),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              if (m.esquema.isNotEmpty && !m.esquemaAprobado)
                FilledButton.icon(
                  onPressed: () => _aprobar(context, ref),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Aprobar esquema'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorMedicamento extends ConsumerStatefulWidget {
  const _EditorMedicamento({required this.medicamento});

  final MedicamentoGlp1 medicamento;

  @override
  ConsumerState<_EditorMedicamento> createState() => _EditorMedicamentoState();
}

class _EditorMedicamentoState extends ConsumerState<_EditorMedicamento> {
  late var _registro = widget.medicamento.registroInvima;
  late var _indicacion = widget.medicamento.indicacion;
  late final _pasos = [
    for (final p in widget.medicamento.esquema)
      (semana: p.semana.toDouble(), dosis: p.dosis),
  ];
  var _guardando = false;
  String? _error;

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final esquema = [
        for (final p in _pasos)
          PasoEsquema(semana: p.semana.round(), dosis: p.dosis),
      ]..sort((a, b) => a.semana - b.semana);
      if (esquema.any((p) => p.dosis <= 0 || p.semana < 0)) {
        throw StateError('Cada paso necesita una semana y una dosis.');
      }
      await _peso(ref).guardarMedicamento(
        widget.medicamento.copyWith(
          registroInvima: _registro.trim(),
          indicacion: _indicacion.trim(),
          esquema: esquema,
        ),
      );
      ref.read(versionIndiceProvider.notifier).cambio();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _guardando = false;
        _error = mensajeDeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.medicamento;
    return AlertDialog(
      title: TituloDialogo(m.generico, icono: Icons.vaccines_outlined),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${m.comercial} · ${m.via}',
                style: const TextStyle(color: ColoresMarca.textoSuave),
              ),
              const SizedBox(height: 12),
              CampoTexto(
                etiqueta: 'Registro Invima',
                valorInicial: _registro,
                pista: 'Vacío: «registro Invima sin confirmar»',
                mayusculas: TextCapitalization.characters,
                alCambiar: (v) => _registro = v,
              ),
              const SizedBox(height: 12),
              CampoTexto(
                etiqueta: 'Indicación aprobada (ficha técnica)',
                valorInicial: _indicacion,
                lineas: 2,
                alCambiar: (v) => _indicacion = v,
              ),
              const SizedBox(height: 14),
              const Text('ESQUEMA DE TITULACIÓN', style: EstilosMarca.rotulo),
              const SizedBox(height: 4),
              const Text(
                'Cambiar el esquema lo deja otra vez sin aprobar.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
              const SizedBox(height: 8),
              for (final (i, p) in _pasos.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: CampoNumero(
                          key: ValueKey('semana$i${_pasos.length}'),
                          etiqueta: 'Desde la semana',
                          valor: p.semana,
                          decimales: false,
                          alCambiar: (v) => _pasos[i] = (
                            semana: v ?? -1,
                            dosis: _pasos[i].dosis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CampoNumero(
                          key: ValueKey('dosis$i${_pasos.length}'),
                          etiqueta: 'Dosis',
                          unidad: 'mg',
                          valor: p.dosis == 0 ? null : p.dosis,
                          alCambiar: (v) => _pasos[i] = (
                            semana: _pasos[i].semana,
                            dosis: v ?? 0,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar el paso',
                        onPressed: () => setState(() => _pasos.removeAt(i)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(
                    () => _pasos.add((
                      semana: _pasos.isEmpty ? 0 : _pasos.last.semana + 4,
                      dosis: 0,
                    )),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar paso'),
                ),
              ),
              if (_pasos.isNotEmpty)
                Text(
                  'Vista: ${_pasos.map((p) => 'semana ${p.semana.round()}: ${p.dosis == 0 ? '—' : formatoNumero(p.dosis)} mg').join(' · ')}',
                  style: const TextStyle(
                    color: ColoresMarca.textoSuave,
                    fontSize: 13,
                  ),
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
          onPressed: _guardando ? null : _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
