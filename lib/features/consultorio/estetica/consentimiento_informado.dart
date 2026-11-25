import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/documentos/plantillas.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/consultorio/procedimientos/plan_tratamiento.dart';
import '../../../core/pais/pais_provider.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../medico/medico_provider.dart';
import '../documentos/firma_autorizacion.dart';
import '../estado/consultorio_provider.dart';
import '../widgets/chip_seleccion.dart';

/// Consentimiento informado por plan de tratamiento (pregunta 39): primero
/// el plan (zonas, sesiones y producto) y luego la firma del paciente.
Future<void> pedirConsentimientoInformado(
  BuildContext context, {
  required FichaPaciente ficha,
  required String plantillaId,
}) async {
  final plan = await showDialog<PlanTratamiento>(
    context: context,
    builder: (_) => _DialogoPlan(ficha: ficha, plantillaId: plantillaId),
  );
  if (plan == null || !context.mounted) return;
  final container = ProviderScope.containerOf(context);
  final procedimientos = container
      .read(servicioConsultorioProvider)
      .procedimientos;
  await pedirFirmaDocumento(
    context,
    ficha: ficha,
    tipo: TipoPlantilla.consentimientoInformado,
    valoresExtra: procedimientos.valoresConsentimiento(plan),
    firmar: (png, {required incluirFirma, required incluirSello}) =>
        procedimientos.firmarConsentimiento(
          ficha: ficha,
          plan: plan,
          firmaPng: png,
          medico: container.read(medicoProvider),
          pais: container.read(paisProvider),
          incluirFirma: incluirFirma,
          incluirSello: incluirSello,
        ),
  );
}

class _DialogoPlan extends ConsumerStatefulWidget {
  const _DialogoPlan({required this.ficha, required this.plantillaId});

  final FichaPaciente ficha;
  final String plantillaId;

  @override
  ConsumerState<_DialogoPlan> createState() => _DialogoPlanState();
}

class _DialogoPlanState extends ConsumerState<_DialogoPlan> {
  late PlanTratamiento _plan = ref
      .read(servicioConsultorioProvider)
      .procedimientos
      .planSugerido(widget.ficha.id, widget.plantillaId);
  String? _error;

  void _continuar() {
    final problemas = ref
        .read(servicioConsultorioProvider)
        .procedimientos
        .problemasPlan(_plan);
    if (problemas.isNotEmpty) {
      setState(() => _error = problemas.first);
      return;
    }
    Navigator.pop(context, _plan);
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.read(servicioConsultorioProvider).procedimientos;
    final d = p.vigente(widget.plantillaId).definicion;
    return AlertDialog(
      title: TituloDialogo(
        'Plan de tratamiento · ${d.nombre}',
        icono: Icons.assignment_turned_in_outlined,
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'El consentimiento cubre este plan. Si cambian la técnica, el '
                'producto o las zonas, se firma uno nuevo.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
              const SizedBox(height: 12),
              const Text(
                'Zonas',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final z in d.zonas)
                    ChipSeleccion(
                      texto: z,
                      seleccionado: _plan.zonas.contains(z),
                      alCambiar: (si) => setState(
                        () => _plan = _plan.copyWith(
                          zonas: si
                              ? [..._plan.zonas, z]
                              : [
                                  for (final x in _plan.zonas)
                                    if (x != z) x,
                                ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              CampoNumero(
                etiqueta: 'Número de sesiones',
                decimales: false,
                valor: _plan.sesiones.toDouble(),
                alCambiar: (v) =>
                    _plan = _plan.copyWith(sesiones: (v ?? 0).round()),
              ),
              const SizedBox(height: 12),
              CampoTexto(
                etiqueta: 'Producto o solución (con su registro Invima)',
                valorInicial: _plan.producto,
                lineas: 2,
                alCambiar: (v) => _plan = _plan.copyWith(producto: v.trim()),
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _continuar,
          child: const Text('Continuar a la firma'),
        ),
      ],
    );
  }
}

/// Mensaje corto del estado del consentimiento de un procedimiento.
String textoPlan(PlanTratamiento p) =>
    '${p.sesiones} ${p.sesiones == 1 ? 'sesión' : 'sesiones'} · '
    '${p.textoZonas}';
