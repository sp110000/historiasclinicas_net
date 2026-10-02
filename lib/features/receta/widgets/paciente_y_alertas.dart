import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/pais/perfil_pais.dart';
import '../../../core/receta/alertas.dart';
import '../../../core/receta/receta.dart';
import '../../../core/widgets/campos.dart';
import '../../historia/estado/historia_controller.dart';
import '../estado/receta_controller.dart';

/// Datos del paciente precargados desde la historia. Se pueden corregir
/// aquí sin tocar la historia.
class DatosPacienteReceta extends ConsumerStatefulWidget {
  const DatosPacienteReceta({super.key});

  @override
  ConsumerState<DatosPacienteReceta> createState() =>
      _DatosPacienteRecetaState();
}

class _DatosPacienteRecetaState extends ConsumerState<DatosPacienteReceta> {
  /// Cambia al restablecer: los campos vuelven a leer su valor.
  var _version = 0;

  @override
  Widget build(BuildContext context) {
    final h = ref.watch(historiaProvider.select((e) => e.historia));
    final ajustes = ref.watch(recetaProvider.select((r) => r.ajustesPaciente));
    final deHistoria = PacienteReceta.deHistoria(h);
    final efectivo = deHistoria.conAjustes(ajustes);
    final ctrl = ref.read(recetaProvider.notifier);

    Widget campo(String clave, String etiqueta, {int lineas = 1}) {
      final corregido = ajustes.containsKey(clave);
      return KeyedSubtree(
        key: ValueKey('$clave-$_version'),
        child: TextFormField(
          initialValue: efectivo.valor(clave),
          minLines: lineas,
          maxLines: lineas > 1 ? null : 1,
          decoration: InputDecoration(
            labelText: etiqueta,
            helperText: corregido ? 'Corregido solo en la receta' : null,
            helperStyle: const TextStyle(color: ColoresMarca.aviso),
          ),
          onChanged: (v) => ctrl.ajustarPaciente(
            clave,
            v == deHistoria.valor(clave) ? null : v,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Se toman de la historia. Lo que corrijas aquí no cambia la '
                'historia.',
                style: TextStyle(fontSize: 13, color: ColoresMarca.textoSuave),
              ),
            ),
            if (ajustes.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  ctrl.restablecerPaciente();
                  setState(() => _version++);
                },
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Restablecer'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        campo('nombre', 'Paciente'),
        const SizedBox(height: 14),
        FilaCampos(
          anchoMinimo: 480,
          children: [
            campo('documento', 'Documento'),
            campo('edad', 'Edad'),
            if (h.pais == Pais.espana)
              campo('fechaNacimiento', 'Fecha de nacimiento'),
          ],
        ),
        const SizedBox(height: 14),
        campo('diagnostico', 'Diagnóstico (CIE-10)', lineas: 2),
        const SizedBox(height: 14),
        campo('alergias', 'Alergias'),
      ],
    );
  }
}

/// Alertas de alergia y de control especial. Nunca bloquean: el médico
/// las marca como leídas.
class AlertasReceta extends ConsumerWidget {
  const AlertasReceta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertas = ref.watch(alertasAlergiaProvider);
    final vistas = ref.watch(recetaProvider.select((r) => r.alertasVistas));
    final control = ref.watch(avisosControlProvider);
    final antecedentes = ref.watch(
      historiaProvider.select((e) => e.historia.antecedentes),
    );
    final corregidas = ref.watch(
      recetaProvider.select((r) => r.ajustesPaciente.containsKey('alergias')),
    );
    final ctrl = ref.read(recetaProvider.notifier);
    final pendientes = [
      for (final a in alertas)
        if (!vistas.contains(a.clave)) a,
    ];
    final revisadas = alertas.length - pendientes.length;
    final sinDatos = !antecedentes.alergiasRegistradas && !corregidas;

    if (alertas.isEmpty && control.isEmpty && !sinDatos) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in pendientes)
          _Alerta(
            color: a.gravedad == GravedadAlerta.alta
                ? ColoresMarca.error
                : ColoresMarca.aviso,
            icono: Icons.warning_amber_rounded,
            titulo: a.gravedad == GravedadAlerta.alta
                ? 'ALERTA DE ALERGIA'
                : 'POSIBLE REACTIVIDAD CRUZADA',
            texto: a.texto,
            accion: TextButton(
              onPressed: () => ctrl.marcarAlertaVista(a.clave),
              child: const Text('Entendido'),
            ),
          ),
        if (revisadas > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              revisadas == 1
                  ? '1 alerta de alergia revisada.'
                  : '$revisadas alertas de alergia revisadas.',
              style: const TextStyle(
                fontSize: 13,
                color: ColoresMarca.textoSuave,
              ),
            ),
          ),
        for (final c in control)
          _Alerta(
            color: ColoresMarca.aviso,
            icono: Icons.policy_outlined,
            titulo: 'CONTROL ESPECIAL',
            texto: c.texto,
          ),
        if (sinDatos)
          const _Alerta(
            color: ColoresMarca.textoSuave,
            icono: Icons.info_outline,
            titulo: 'SIN DATOS DE ALERGIAS',
            texto:
                'La historia no registra alergias. Pregunta al paciente antes '
                'de prescribir (puedes anotarlas en "Alergias").',
          ),
      ],
    );
  }
}

class _Alerta extends StatelessWidget {
  const _Alerta({
    required this.color,
    required this.icono,
    required this.titulo,
    required this.texto,
    this.accion,
  });

  final Color color;
  final IconData icono;
  final String titulo;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(texto),
                ],
              ),
            ),
          ),
          ?accion,
        ],
      ),
    );
  }
}
