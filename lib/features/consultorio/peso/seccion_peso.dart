import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/documentos/documento.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/consultorio/peso/programa_peso.dart';
import '../../../core/consultorio/reglas/glp1.dart';
import '../../../core/pais/pais_provider.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/utils/numeros.dart';
import '../../medico/medico_provider.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import 'dialogos_peso.dart';
import '../widgets/texto_normativo.dart';

String _fechaCorta(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';

/// Ficha → Peso: meta y avance, planes, recordatorio y GLP-1 (5.3).
class SeccionPeso extends ConsumerWidget {
  const SeccionPeso({super.key, required this.ficha});

  final FichaPaciente ficha;

  Future<void> _indicaciones(
    BuildContext context,
    WidgetRef ref,
    ProgramaPeso p,
  ) async {
    final s = ref.read(servicioConsultorioProvider);
    try {
      final pdf = await s.peso.indicacionesPdf(
        p,
        ficha,
        medico: ref.read(medicoProvider),
        pais: ref.read(paisProvider),
      );
      final a = s.reloj.ahora();
      ref.read(descargarPdfProvider)(
        pdf,
        nombreArchivoDocumento(
          'Indicaciones_peso',
          apellido: ficha.primerApellido,
          numero:
              '${a.year}-${a.month.toString().padLeft(2, '0')}-'
              '${a.day.toString().padLeft(2, '0')}',
        ),
      );
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
    }
  }

  Future<void> _estado(WidgetRef ref, ProgramaPeso p, EstadoPrograma e) async {
    await ref
        .read(servicioConsultorioProvider)
        .peso
        .guardar(p.copyWith(estado: e));
    ref.read(versionIndiceProvider.notifier).cambio();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final s = ref.read(servicioConsultorioProvider);
    final p = s.peso.programaDe(ficha.id);
    if (p == null) {
      return _Caja(
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Sin programa de peso.'),
            FilledButton.icon(
              onPressed: () => editarPrograma(context, ficha: ficha),
              icon: const Icon(Icons.add),
              label: const Text('Iniciar programa'),
            ),
          ],
        ),
      );
    }
    final progreso = s.peso.progreso(p, s.seguimiento.medicionesDe(ficha.id));
    final meta = [
      if (p.metaPeso != null) '${formatoNumero(p.metaPeso!)} kg',
      if (p.metaCintura != null) 'cintura ${formatoNumero(p.metaCintura!)} cm',
      if (p.metaFecha != null) formatoFecha(p.metaFecha!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Caja(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'PROGRAMA DE PESO · desde ${formatoFecha(p.inicio)}',
                    style: EstilosMarca.rotulo,
                  ),
                  EtiquetaEstado(
                    icono: p.estado == EstadoPrograma.activo
                        ? Icons.play_circle_outline
                        : Icons.pause_circle_outline,
                    texto: p.estado.etiqueta,
                    color: p.estado == EstadoPrograma.activo
                        ? ColoresMarca.estadoOk
                        : ColoresMarca.textoSuave,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                meta.isEmpty ? 'Sin meta.' : 'Meta ${meta.join(' · ')}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (progreso != null)
                Text(
                  'Hoy ${formatoNumero(progreso.actual, decimales: 1)} kg '
                  '(${progreso.porcentaje > 0 ? '+' : ''}'
                  '${formatoNumero(progreso.porcentaje, decimales: 1)} % desde '
                  '${formatoNumero(progreso.inicial, decimales: 1)} kg)'
                  '${progreso.faltan == null
                      ? ''
                      : progreso.faltan! == 0
                      ? ' · meta alcanzada'
                      : ' · faltan ${formatoNumero(progreso.faltan!, decimales: 1)} kg'}',
                  style: const TextStyle(color: ColoresMarca.textoSuave),
                )
              else
                const Text(
                  'Registra el peso en Seguimiento para ver el avance.',
                  style: TextStyle(color: ColoresMarca.textoSuave),
                ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: ColoresMarca.primario,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Recuerda: $recordatorioProteinaFuerza'
                      '${p.proteina.isEmpty ? '' : ' Proteína: ${p.proteina}.'}',
                      style: const TextStyle(color: ColoresMarca.textoSuave),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        editarPrograma(context, ficha: ficha, programa: p),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar plan'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _indicaciones(context, ref, p),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Indicaciones (PDF)'),
                  ),
                  if (p.estado == EstadoPrograma.activo)
                    TextButton(
                      onPressed: () =>
                          _estado(ref, p, EstadoPrograma.terminado),
                      child: const Text('Terminar programa'),
                    )
                  else
                    TextButton(
                      onPressed: () => _estado(ref, p, EstadoPrograma.activo),
                      child: const Text('Reabrir'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final plan in [p.planNutricional, p.planEjercicio])
          if (plan != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Caja(
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    '${plan == p.planNutricional ? 'Plan nutricional' : 'Plan de ejercicio'}'
                    ' · ${plan.nombre} (v${plan.version})',
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(plan.texto),
                    ),
                  ],
                ),
              ),
            ),
        _Glp1(ficha: ficha, programa: p),
      ],
    );
  }
}

class _Caja extends StatelessWidget {
  const _Caja({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: RadiosMarca.tarjeta,
      border: Border.all(color: ColoresMarca.borde),
    ),
    child: child,
  );
}

class _Glp1 extends ConsumerWidget {
  const _Glp1({required this.ficha, required this.programa});

  final FichaPaciente ficha;
  final ProgramaPeso programa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = programa;
    final g = p.glp1;
    final peso = ref.read(servicioConsultorioProvider).peso;
    final eval = evaluarContraindicaciones(
      p.contraindicaciones,
      sexo: ficha.sexo,
    );
    final r = p.contraindicaciones;
    final revision = r == null
        ? const EtiquetaEstado(
            icono: Icons.pending_outlined,
            texto: 'Contraindicaciones sin revisar',
            color: ColoresMarca.aviso,
          )
        : eval.bloqueos.isNotEmpty
        ? EtiquetaEstado(
            icono: Icons.block_outlined,
            texto: textoPresentable(ref, eval.bloqueos.first),
            color: ColoresMarca.error,
          )
        : EtiquetaEstado(
            icono: Icons.check,
            texto:
                'Contraindicaciones revisadas el ${formatoFecha(r.fecha)} · '
                '0 absolutas · ${eval.precauciones.length} '
                '${eval.precauciones.length == 1 ? 'precaución' : 'precauciones'} con nota',
            color: ColoresMarca.estadoOk,
          );
    final activo = g != null && g.activo;
    final medicamento = g == null ? null : peso.medicamento(g.medicamentoId);
    return _Caja(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('GLP-1', style: EstilosMarca.rotulo),
          const SizedBox(height: 8),
          if (g != null) ...[
            Text(g.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (medicamento != null) ...[
              const SizedBox(height: 6),
              InfoMedicamento(medicamento: medicamento),
            ],
            const SizedBox(height: 8),
          ],
          Align(alignment: Alignment.centerLeft, child: revision),
          if (g != null) ...[
            const SizedBox(height: 10),
            Text(
              'Dosis  ${[for (final d in g.dosis) '${_fechaCorta(d.fecha)} ${d.texto}'].join(' → ')}',
            ),
            if (g.tolerancia.isNotEmpty)
              Text(
                'Tolerancia  ${[for (final t in g.tolerancia) '${t.sintomas} (${t.intensidad.etiqueta.toLowerCase()}, ${_fechaCorta(t.fecha)})'].join(' · ')}',
                style: const TextStyle(color: ColoresMarca.textoSuave),
              ),
            Text(
              g.eventos.isEmpty
                  ? 'Eventos adversos  ninguno'
                  : 'Eventos adversos  ${[for (final e in g.eventos) '${e.descripcion} (${e.gravedad.etiqueta.toLowerCase()}, ${_fechaCorta(e.fecha)}${e.reportadoInvima ? ', reportado' : ''})'].join(' · ')}',
              style: TextStyle(
                color: g.eventos.isEmpty
                    ? ColoresMarca.textoSuave
                    : ColoresMarca.error,
              ),
            ),
            if (!g.activo)
              Text(
                'Suspendido el ${formatoFecha(g.suspendidoEn!)}: '
                '${g.motivoSuspension}',
                style: const TextStyle(color: ColoresMarca.textoSuave),
              ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!activo) ...[
                OutlinedButton.icon(
                  onPressed: () => revisarContraindicaciones(
                    context,
                    ficha: ficha,
                    programa: p,
                  ),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Revisar contraindicaciones'),
                ),
                FilledButton.icon(
                  onPressed: eval.permiteIniciar
                      ? () => iniciarGlp1(context, ficha: ficha, programa: p)
                      : null,
                  icon: const Icon(Icons.vaccines_outlined),
                  label: const Text('Iniciar GLP-1'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: () =>
                      cambiarDosis(context, ficha: ficha, programa: p),
                  icon: const Icon(Icons.add),
                  label: const Text('Cambio de dosis'),
                ),
                OutlinedButton(
                  onPressed: () => registrarGlp1(
                    context,
                    ficha: ficha,
                    programa: p,
                    tipo: RegistroGlp1.tolerancia,
                  ),
                  child: const Text('Tolerancia'),
                ),
                OutlinedButton(
                  onPressed: () => registrarGlp1(
                    context,
                    ficha: ficha,
                    programa: p,
                    tipo: RegistroGlp1.evento,
                  ),
                  child: const Text('Evento adverso'),
                ),
                TextButton(
                  onPressed: () => registrarGlp1(
                    context,
                    ficha: ficha,
                    programa: p,
                    tipo: RegistroGlp1.suspension,
                  ),
                  child: const Text('Suspender'),
                ),
              ],
            ],
          ),
          if (!activo && !eval.permiteIniciar && r != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                eval.motivos.first,
                style: const TextStyle(color: ColoresMarca.error),
              ),
            ),
        ],
      ),
    );
  }
}
