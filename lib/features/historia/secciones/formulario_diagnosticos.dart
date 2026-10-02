import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/models/historia.dart';
import '../../../core/pais/perfil_pais.dart';
import '../../../core/utils/ids.dart';
import '../../../core/widgets/campos.dart';
import '../estado/historia_controller.dart';
import 'edicion.dart';

class FormularioDiagnosticos extends ConsumerWidget {
  const FormularioDiagnosticos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(historiaProvider.select((e) => e.historia));
    final lista = h.diagnosticos;

    void guardar(List<Diagnostico> nueva) =>
        ref.editar((h) => h.copyWith(diagnosticos: nueva));

    void mover(int desde, int hasta) {
      if (hasta < 0 || hasta >= lista.length) return;
      final nueva = [...lista];
      final d = nueva.removeAt(desde);
      nueva.insert(hasta, d);
      guardar(nueva);
    }

    return FormField<bool>(
      validator: (_) => lista.any((d) => d.descripcion.trim().isNotEmpty)
          ? null
          : 'Registra al menos un diagnóstico',
      builder: (campo) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lista.isNotEmpty)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (desde, hasta) =>
                  mover(desde, hasta > desde ? hasta - 1 : hasta),
              children: [
                for (final (i, d) in lista.indexed)
                  _FilaDiagnostico(
                    key: ValueKey(d.id),
                    indice: i,
                    total: lista.length,
                    diagnostico: d,
                    perfil: h.perfil,
                    alCambiar: (nuevo) {
                      final copia = [...lista];
                      copia[i] = nuevo;
                      guardar(copia);
                    },
                    alMover: (delta) => mover(i, i + delta),
                    alEliminar: () => guardar([...lista]..removeAt(i)),
                  ),
              ],
            ),
          if (lista.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Aún no hay diagnósticos.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
            ),
          if (campo.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                campo.errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () {
                guardar([
                  ...lista,
                  Diagnostico(
                    id: nuevoUuid(),
                    tipo: lista.isEmpty ? 'principal' : 'relacionado',
                  ),
                ]);
                campo.didChange(true);
              },
              icon: const Icon(Icons.add),
              label: const Text('Agregar diagnóstico'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaDiagnostico extends StatelessWidget {
  const _FilaDiagnostico({
    super.key,
    required this.indice,
    required this.total,
    required this.diagnostico,
    required this.perfil,
    required this.alCambiar,
    required this.alMover,
    required this.alEliminar,
  });

  final int indice;
  final int total;
  final Diagnostico diagnostico;
  final PerfilPais perfil;
  final ValueChanged<Diagnostico> alCambiar;
  final ValueChanged<int> alMover;
  final VoidCallback alEliminar;

  @override
  Widget build(BuildContext context) {
    final d = diagnostico;
    final descripcion = TextFormField(
      initialValue: d.descripcion,
      decoration: const InputDecoration(labelText: 'Diagnóstico *'),
      textCapitalization: TextCapitalization.sentences,
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Escribe el diagnóstico' : null,
      onChanged: (v) => alCambiar(d.copyWith(descripcion: v)),
    );
    final codigo = TextFormField(
      initialValue: d.codigo,
      decoration: const InputDecoration(labelText: 'CIE-10', hintText: 'J02.9'),
      textCapitalization: TextCapitalization.characters,
      onChanged: (v) => alCambiar(d.copyWith(codigo: v.trim())),
    );
    final tipo = CampoDesplegable(
      etiqueta: 'Tipo',
      opciones: opcionesTipoDiagnostico,
      valor: d.tipo,
      alCambiar: (v) => alCambiar(d.copyWith(tipo: v)),
    );
    final caracter = CampoDesplegable(
      etiqueta: 'Carácter',
      opciones: perfil.caracteresDiagnostico,
      valor: d.caracter,
      alCambiar: (v) => alCambiar(d.copyWith(caracter: v)),
    );
    final acciones = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: indice > 0 ? () => alMover(-1) : null,
          icon: const Icon(Icons.arrow_upward, size: 20),
          tooltip: 'Subir',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: indice < total - 1 ? () => alMover(1) : null,
          icon: const Icon(Icons.arrow_downward, size: 20),
          tooltip: 'Bajar',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: alEliminar,
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: 'Eliminar diagnóstico',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
    final numero = ReorderableDragStartListener(
      index: indice,
      child: Tooltip(
        message: 'Arrastra para reordenar',
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ColoresMarca.primario.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${indice + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: ColoresMarca.primario,
              ),
            ),
          ),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      decoration: BoxDecoration(
        color: ColoresMarca.fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [numero, const Spacer(), acciones]),
                const SizedBox(height: 10),
                descripcion,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: codigo),
                    const SizedBox(width: 10),
                    Expanded(child: tipo),
                  ],
                ),
                const SizedBox(height: 12),
                caracter,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: numero,
                  ),
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: descripcion),
                  const SizedBox(width: 10),
                  SizedBox(width: 120, child: codigo),
                  const SizedBox(width: 2),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: acciones,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 42, right: 6),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: tipo),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: caracter),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
