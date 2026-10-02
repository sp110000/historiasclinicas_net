import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/models/historia.dart';
import '../../../core/widgets/campos.dart';
import '../estado/historia_controller.dart';
import 'edicion.dart';

/// Revisión de síntomas por sistemas: "Niega" o "Refiere" (con detalle) en
/// cada sistema, más observaciones.
class FormularioRevisionSistemas extends ConsumerWidget {
  const FormularioRevisionSistemas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(
      historiaProvider.select((e) => e.historia.revisionSistemas),
    );
    void editar(RevisionSistemas Function(RevisionSistemas r) cambio) =>
        ref.editar(
          (h) => h.copyWith(revisionSistemas: cambio(h.revisionSistemas)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              '${r.registrados} de ${sistemasRevision.length} sistemas registrados',
              style: const TextStyle(
                color: ColoresMarca.textoSuave,
                fontSize: 13,
              ),
            ),
            TextButton.icon(
              onPressed: r.completa
                  ? null
                  : () => editar((r) => r.negarPendientes()),
              icon: const Icon(Icons.done_all, size: 19),
              label: const Text('Marcar los pendientes como «Niega»'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final s in sistemasRevision)
          _FilaSistema(
            key: ValueKey(s.codigo),
            sistema: s,
            hallazgo: r.de(s.codigo),
            alCambiar: (h) => editar((r) => r.con(s.codigo, h)),
          ),
        const SizedBox(height: 16),
        CampoTexto(
          etiqueta: 'Observaciones de la revisión por sistemas',
          lineas: 2,
          valorInicial: r.observaciones,
          alCambiar: (v) => editar((r) => r.copyWith(observaciones: v)),
        ),
      ],
    );
  }
}

class _FilaSistema extends StatelessWidget {
  const _FilaSistema({
    super.key,
    required this.sistema,
    required this.hallazgo,
    required this.alCambiar,
  });

  final SistemaRevision sistema;
  final HallazgoSistema hallazgo;
  final ValueChanged<HallazgoSistema> alCambiar;

  @override
  Widget build(BuildContext context) {
    final estado = hallazgo.estado;
    Widget opcion(EstadoSistema e, Color color) => ChoiceChip(
      label: Text(e.etiqueta),
      selected: estado == e,
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.16),
      side: BorderSide(color: estado == e ? color : ColoresMarca.borde),
      labelStyle: TextStyle(
        color: estado == e ? color : null,
        fontWeight: estado == e ? FontWeight.w600 : FontWeight.w500,
      ),
      onSelected: (si) => alCambiar(
        HallazgoSistema(estado: si ? e : null, detalle: hallazgo.detalle),
      ),
    );
    final opciones = Wrap(
      spacing: 8,
      children: [
        opcion(EstadoSistema.niega, ColoresMarca.secundario),
        opcion(EstadoSistema.refiere, ColoresMarca.aviso),
      ],
    );
    final nombre = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sistema.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          sistema.ejemplos,
          style: const TextStyle(
            fontSize: 12.5,
            color: ColoresMarca.textoSuave,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresMarca.borde)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) => c.maxWidth < 520
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [nombre, const SizedBox(height: 8), opciones],
                  )
                : Row(
                    children: [
                      Expanded(child: nombre),
                      const SizedBox(width: 12),
                      opciones,
                    ],
                  ),
          ),
          if (estado == EstadoSistema.refiere) ...[
            const SizedBox(height: 10),
            CampoTexto(
              etiqueta: 'Qué refiere · ${sistema.nombre}',
              pista: sistema.ejemplos,
              valorInicial: hallazgo.detalle,
              alCambiar: (v) => alCambiar(
                HallazgoSistema(estado: EstadoSistema.refiere, detalle: v),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
