import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/consultorio/procedimientos/plantilla_procedimiento.dart';
import '../../../core/consultorio/procedimientos/valoracion.dart';
import '../../../core/consultorio/reglas/estetica.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/campos.dart';
import '../documentos/linea_tiempo_documentos.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import 'consentimiento_informado.dart';
import '../widgets/texto_normativo.dart';

/// Pastilla del estado de la valoración de un procedimiento.
Widget etiquetaValoracion(Valoracion? v, DateTime ahora) =>
    switch (estadoValoracion(v, ahora)) {
      EstadoValoracion.falta => const EtiquetaEstado(
        icono: Icons.pending_outlined,
        texto: 'Sin valoración',
        color: ColoresMarca.textoSuave,
      ),
      EstadoValoracion.vigente => EtiquetaEstado(
        icono: Icons.check,
        texto: 'Apto hasta el ${formatoFecha(v!.vigenteHasta!)}',
        color: ColoresMarca.estadoOk,
      ),
      EstadoValoracion.vencida => EtiquetaEstado(
        icono: Icons.event_busy_outlined,
        texto: 'Valoración vencida (${formatoFecha(v!.vigenteHasta!)})',
        color: ColoresMarca.aviso,
      ),
      EstadoValoracion.noApto => const EtiquetaEstado(
        icono: Icons.block_outlined,
        texto: 'No apto',
        color: ColoresMarca.error,
      ),
      EstadoValoracion.diferir => const EtiquetaEstado(
        icono: Icons.schedule,
        texto: 'Diferir',
        color: ColoresMarca.aviso,
      ),
    };

/// Ficha → Estética: por procedimiento, la valoración (5.3b), el
/// consentimiento (5.3c) y las sesiones (5.3d).
class SeccionEstetica extends ConsumerWidget {
  const SeccionEstetica({super.key, required this.ficha});

  final FichaPaciente ficha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final s = ref.read(servicioConsultorioProvider);
    final ahora = s.reloj.ahora();
    final bloqueo = bloqueoPorEdad(ficha, ahora);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bloqueo != null) ...[
          _AvisoEdad(ficha: ficha, motivo: bloqueo),
          const SizedBox(height: 12),
        ],
        for (final p in s.procedimientos.plantillas)
          _Procedimiento(
            ficha: ficha,
            plantilla: p,
            bloqueo: bloqueo,
            ahora: ahora,
          ),
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

/// Sin fecha de nacimiento: se pide aquí. Menor de edad: se explica.
class _AvisoEdad extends ConsumerStatefulWidget {
  const _AvisoEdad({required this.ficha, required this.motivo});

  final FichaPaciente ficha;
  final String motivo;

  @override
  ConsumerState<_AvisoEdad> createState() => _AvisoEdadState();
}

class _AvisoEdadState extends ConsumerState<_AvisoEdad> {
  DateTime? _nacimiento;

  Future<void> _guardar() async {
    final f = _nacimiento;
    if (f == null) return;
    try {
      await ref
          .read(servicioConsultorioProvider)
          .indice
          .guardarFicha(widget.ficha.copyWith(fechaNacimiento: f));
      ref.read(versionIndiceProvider.notifier).cambio();
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeDeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sinFecha = widget.ficha.fechaNacimiento == null;
    return _Caja(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                sinFecha ? Icons.cake_outlined : Icons.block_outlined,
                color: sinFecha ? ColoresMarca.aviso : ColoresMarca.error,
              ),
              const SizedBox(width: 8),
              Expanded(child: TextoNormativo(widget.motivo)),
            ],
          ),
          if (sinFecha) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 220,
                  child: CampoFecha(
                    etiqueta: 'Fecha de nacimiento',
                    valor: null,
                    primera: DateTime(1900),
                    ultima: DateTime.now(),
                    alCambiar: (f) => _nacimiento = f,
                  ),
                ),
                FilledButton(
                  onPressed: _guardar,
                  child: const Text('Guardar en la ficha'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Procedimiento extends ConsumerWidget {
  const _Procedimiento({
    required this.ficha,
    required this.plantilla,
    required this.bloqueo,
    required this.ahora,
  });

  final FichaPaciente ficha;
  final PlantillaProcedimiento plantilla;
  final String? bloqueo;
  final DateTime ahora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.read(servicioConsultorioProvider);
    final valoraciones = [
      for (final v in s.procedimientos.valoracionesDe(ficha.id))
        if (v.plantillaId == plantilla.id) v,
    ];
    final ultima = ultimaValoracion(valoraciones, plantilla.id);
    final usable = plantilla.usable;
    return _Caja(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(plantilla.nombre.toUpperCase(), style: EstilosMarca.rotulo),
              etiquetaValoracion(ultima, ahora),
            ],
          ),
          const SizedBox(height: 10),
          if (!usable)
            const Text(
              'La plantilla no está aprobada: escribe tu protocolo y '
              'apruébala en Procedimientos.',
              style: TextStyle(color: ColoresMarca.textoSuave),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: usable && bloqueo == null
                    ? () => context.go(
                        '/pacientes/${ficha.id}/valoracion/${plantilla.id}',
                      )
                    : null,
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Nueva valoración'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Sesiones(
            ficha: ficha,
            plantillaId: plantilla.id,
            habilitado: usable && bloqueo == null,
          ),
          const SizedBox(height: 14),
          _Consentimiento(
            ficha: ficha,
            plantillaId: plantilla.id,
            habilitado: usable && bloqueo == null,
          ),
          if (valoraciones.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('VALORACIONES', style: EstilosMarca.rotulo),
            const SizedBox(height: 6),
            for (final v in valoraciones.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${formatoFecha(v.fecha)} · ${v.resultado?.etiqueta ?? '—'}'
                  '${v.vigenteHasta == null ? '' : ' hasta el ${formatoFecha(v.vigenteHasta!)}'}'
                  '${v.motivo.trim().isEmpty ? '' : ' · ${v.motivo.trim()}'}'
                  ' · sellada en la revisión ${v.revision}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Consentimiento informado del procedimiento: el vigente (con su plan) y
/// los anteriores, con «Firmar consentimiento».
class _Consentimiento extends ConsumerWidget {
  const _Consentimiento({
    required this.ficha,
    required this.plantillaId,
    required this.habilitado,
  });

  final FichaPaciente ficha;
  final String plantillaId;
  final bool habilitado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.read(servicioConsultorioProvider).procedimientos;
    final todos = p.consentimientosDe(ficha.id, plantillaId);
    final vigente = p.consentimientoVigente(ficha.id, plantillaId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('CONSENTIMIENTO INFORMADO', style: EstilosMarca.rotulo),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (vigente != null)
              EtiquetaEstado(
                icono: Icons.verified_outlined,
                texto:
                    '${vigente.numero} · ${textoPlan(vigente.plan!)} '
                    '(${formatoFecha(vigente.fechaHora)})',
                color: ColoresMarca.estadoOk,
              )
            else
              const EtiquetaEstado(
                icono: Icons.pending_outlined,
                texto: 'Sin consentimiento vigente',
                color: ColoresMarca.textoSuave,
              ),
            OutlinedButton.icon(
              onPressed: habilitado
                  ? () => pedirConsentimientoInformado(
                      context,
                      ficha: ficha,
                      plantillaId: plantillaId,
                    )
                  : null,
              icon: const Icon(Icons.draw_outlined),
              label: Text(
                vigente == null
                    ? 'Firmar consentimiento'
                    : 'Nuevo consentimiento (otro plan)',
              ),
            ),
          ],
        ),
        for (final d in todos.reversed) ...[
          const SizedBox(height: 8),
          TarjetaDocumento(documento: d),
        ],
      ],
    );
  }
}

/// Sesiones selladas del procedimiento y «Registrar sesión». Las reglas
/// (valoración, consentimiento, lotes, dosis…) se ven en la sesión.
class _Sesiones extends ConsumerWidget {
  const _Sesiones({
    required this.ficha,
    required this.plantillaId,
    required this.habilitado,
  });

  final FichaPaciente ficha;
  final String plantillaId;
  final bool habilitado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesiones = ref
        .read(servicioConsultorioProvider)
        .procedimientos
        .sesionesDe(ficha.id, plantillaId: plantillaId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('SESIONES', style: EstilosMarca.rotulo),
        const SizedBox(height: 6),
        if (sesiones.isEmpty)
          const Text(
            'Sin sesiones todavía.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
        for (final s in sesiones.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${s.titulo} · ${formatoFecha(s.fecha)} · '
              '${s.zonas.map((z) => z.zona).join(', ')} · '
              '${s.consentimientoNumero} · sellada en la revisión ${s.revision}'
              '${s.avisos.isEmpty ? '' : ' · ${s.avisos.length} ${s.avisos.length == 1 ? 'aviso' : 'avisos'}'}',
            ),
          ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: habilitado
                ? () => context.go('/pacientes/${ficha.id}/sesion/$plantillaId')
                : null,
            icon: const Icon(Icons.medical_services_outlined),
            label: const Text('Registrar sesión'),
          ),
        ),
      ],
    );
  }
}
