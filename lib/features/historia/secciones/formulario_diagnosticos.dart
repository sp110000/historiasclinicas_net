import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/cie10/catalogo_cie10.dart';
import '../../../core/models/historia.dart';
import '../../../core/pais/perfil_pais.dart';
import '../../../core/utils/ids.dart';
import '../../../core/utils/numeros.dart';
import '../../../core/widgets/campo_sugerencias.dart';
import '../../../core/widgets/campos.dart';
import '../../cie10/cie10_provider.dart';
import '../../cie10/dialogo_cie10.dart';
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
          const _EstadoCatalogo(),
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

class _FilaDiagnostico extends ConsumerStatefulWidget {
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
  ConsumerState<_FilaDiagnostico> createState() => _FilaDiagnosticoState();
}

class _FilaDiagnosticoState extends ConsumerState<_FilaDiagnostico> {
  late final _descripcion = TextEditingController(
    text: widget.diagnostico.descripcion,
  );
  late final _codigo = TextEditingController(text: widget.diagnostico.codigo);
  final _focoDescripcion = FocusNode();
  final _focoCodigo = FocusNode();

  /// El catálogo CIE-10 se carga la primera vez que se entra a un campo.
  var _usarCatalogo = false;

  @override
  void initState() {
    super.initState();
    _focoDescripcion.addListener(_activarCatalogo);
    _focoCodigo.addListener(_activarCatalogo);
  }

  void _activarCatalogo() {
    if (_usarCatalogo) return;
    if (_focoDescripcion.hasFocus || _focoCodigo.hasFocus) {
      setState(() => _usarCatalogo = true);
    }
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _codigo.dispose();
    _focoDescripcion.dispose();
    _focoCodigo.dispose();
    super.dispose();
  }

  void _elegir(EntradaCie10 e) {
    for (final (c, t) in [(_descripcion, e.descripcion), (_codigo, e.codigo)]) {
      c.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    }
    widget.alCambiar(
      widget.diagnostico.copyWith(descripcion: e.descripcion, codigo: e.codigo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diagnostico;
    final indice = widget.indice;
    final total = widget.total;
    final perfil = widget.perfil;
    final alCambiar = widget.alCambiar;
    final alMover = widget.alMover;
    final alEliminar = widget.alEliminar;
    final catalogo = _usarCatalogo
        ? ref.watch(catalogoCie10Provider).value
        : null;
    final descripcion = CampoSugerencias<EntradaCie10>(
      etiqueta: 'Diagnóstico',
      requerido: true,
      controller: _descripcion,
      foco: _focoDescripcion,
      mayusculas: TextCapitalization.sentences,
      validador: (v) =>
          (v == null || v.trim().isEmpty) ? 'Escribe el diagnóstico' : null,
      sugerencias: (q) => catalogo == null || q.trim().length < 3
          ? const []
          : catalogo.buscar(q, maximo: 8),
      texto: (e) => e.descripcion,
      detalle: (e) => 'CIE-10 ${e.codigo}',
      alElegir: _elegir,
      alCambiar: (v) => alCambiar(d.copyWith(descripcion: v)),
    );
    final codigo = CampoSugerencias<EntradaCie10>(
      etiqueta: 'CIE-10',
      pista: 'J02.9',
      controller: _codigo,
      foco: _focoCodigo,
      mayusculas: TextCapitalization.characters,
      sugerencias: (q) =>
          catalogo == null || !RegExp(r'^[A-Za-z]\d').hasMatch(q.trim())
          ? const []
          : catalogo.buscar(q, maximo: 8),
      texto: (e) => e.codigo,
      detalle: (e) => e.descripcion,
      alElegir: _elegir,
      alCambiar: (v) => alCambiar(d.copyWith(codigo: v.trim())),
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

/// Estado del catálogo CIE-10 y acceso para importarlo.
class _EstadoCatalogo extends ConsumerWidget {
  const _EstadoCatalogo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(infoCie10Provider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 18,
            color: ColoresMarca.textoSuave,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              info == null
                  ? 'Búsqueda CIE-10: importa una vez el catálogo oficial de tu '
                        'país.'
                  : 'Catálogo CIE-10: ${formatoMiles(info.cantidad)} códigos. '
                        'Escribe el diagnóstico o el código para buscar.',
              style: const TextStyle(
                fontSize: 13,
                color: ColoresMarca.textoSuave,
              ),
            ),
          ),
          TextButton(
            onPressed: () => mostrarCatalogoCie10(context),
            child: Text(info == null ? 'Cargar catálogo' : 'Gestionar'),
          ),
        ],
      ),
    );
  }
}
