import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/receta/alertas.dart';
import '../../../core/receta/cantidad.dart';
import '../../../core/receta/medicamentos.dart';
import '../../../core/receta/numero_letras.dart';
import '../../../core/receta/receta.dart';
import '../../../core/widgets/campo_sugerencias.dart';
import '../../../core/widgets/campos.dart';
import '../../historia/estado/historia_controller.dart';
import '../estado/receta_controller.dart';

/// Medicamentos de la receta: numerados, reordenables (arrastrando o con
/// las flechas) y con sugerencias.
class ListaItemsReceta extends ConsumerWidget {
  const ListaItemsReceta({super.key, required this.mostrarErrores});

  final bool mostrarErrores;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recetaProvider.select((r) => r.items));
    final alertas = ref.watch(alertasAlergiaProvider);
    final ctrl = ref.read(recetaProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: items.length,
          onReorder: ctrl.reordenar,
          proxyDecorator: (child, _, _) => Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            child: child,
          ),
          itemBuilder: (context, i) => TarjetaItemReceta(
            key: ValueKey(items[i].id),
            indice: i,
            total: items.length,
            item: items[i],
            alertas: [
              for (final a in alertas)
                if (a.numeroItem == i + 1) a,
            ],
            mostrarErrores: mostrarErrores,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: ctrl.agregarItem,
            icon: const Icon(Icons.add),
            label: const Text('Agregar medicamento'),
          ),
        ),
      ],
    );
  }
}

class TarjetaItemReceta extends ConsumerStatefulWidget {
  const TarjetaItemReceta({
    super.key,
    required this.indice,
    required this.total,
    required this.item,
    required this.alertas,
    required this.mostrarErrores,
  });

  final int indice;
  final int total;
  final ItemReceta item;
  final List<AlertaAlergia> alertas;
  final bool mostrarErrores;

  @override
  ConsumerState<TarjetaItemReceta> createState() => _TarjetaItemRecetaState();
}

class _TarjetaItemRecetaState extends ConsumerState<TarjetaItemReceta> {
  late final _medicamento = TextEditingController(
    text: widget.item.medicamento,
  );
  late final _concentracion = TextEditingController(
    text: widget.item.concentracion,
  );
  late final _forma = TextEditingController(text: widget.item.forma);
  late final _dosis = TextEditingController(text: widget.item.dosis);
  late final _via = TextEditingController(text: widget.item.via);
  late final _frecuencia = TextEditingController(text: widget.item.frecuencia);
  late final _duracion = TextEditingController(text: widget.item.duracion);
  late final _cantidad = TextEditingController(
    text: widget.item.cantidad?.toString() ?? '',
  );
  late final _unidad = TextEditingController(text: widget.item.unidad);
  late final _nota = TextEditingController(text: widget.item.nota);

  List<TextEditingController> get _todos => [
    _medicamento,
    _concentracion,
    _forma,
    _dosis,
    _via,
    _frecuencia,
    _duracion,
    _cantidad,
    _unidad,
    _nota,
  ];

  @override
  void dispose() {
    for (final c in _todos) {
      c.dispose();
    }
    super.dispose();
  }

  RecetaController get _ctrl => ref.read(recetaProvider.notifier);

  void _editar(ItemReceta Function(ItemReceta i) cambio) =>
      _ctrl.actualizarItem(widget.item.id, cambio);

  void _poner(TextEditingController c, String texto) {
    if (c.text == texto) return;
    c.value = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }

  void _aplicar(PlantillaMedicamento p) {
    final nuevo = p.aplicarA(widget.item);
    _poner(_medicamento, nuevo.medicamento);
    _poner(_concentracion, nuevo.concentracion);
    _poner(_forma, nuevo.forma);
    _poner(_dosis, nuevo.dosis);
    _poner(_via, nuevo.via);
    _poner(_frecuencia, nuevo.frecuencia);
    _poner(_duracion, nuevo.duracion);
    _poner(_unidad, nuevo.unidad);
    _poner(_nota, nuevo.nota);
    _editar((_) => nuevo);
  }

  void _cambiarForma(String forma) {
    final anterior = unidadSugerida(widget.item.forma);
    final unidad = _unidad.text.trim();
    final sugerida = unidadSugerida(forma);
    final cambiarUnidad = unidad.isEmpty || unidad == anterior;
    if (cambiarUnidad) _poner(_unidad, sugerida);
    _editar(
      (i) => i.copyWith(forma: forma, unidad: cambiarUnidad ? sugerida : null),
    );
  }

  void _cambiarCantidad(int? n) {
    _editar((i) => i.copyWith(cantidad: n));
  }

  Future<void> _guardarEnMisMedicamentos() async {
    final item = widget.item;
    if (item.medicamento.trim().isEmpty) return;
    await ref
        .read(misMedicamentosProvider.notifier)
        .guardar(PlantillaMedicamento.desdeItem(item));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '«${item.medicamento.trim()}» guardado en "Mis medicamentos".',
        ),
      ),
    );
  }

  void _eliminar() {
    final item = widget.item;
    final indice = widget.indice;
    // La tarjeta desaparece: "Deshacer" no puede depender de su estado.
    final ctrl = _ctrl..eliminarItem(item.id);
    if (item.vacio) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Se quitó «${item.medicamento.trim().isEmpty ? 'el medicamento ${indice + 1}' : item.medicamento.trim()}».',
        ),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => ctrl.insertarItem(indice, item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final numero = widget.indice + 1;
    final pais = ref.watch(historiaProvider.select((e) => e.historia.pais));
    final misMedicamentos = ref.watch(misMedicamentosProvider);
    final sugerida = cantidadSugerida(item);
    // Una fila vacía no se marca: la receta puede llevar solo indicaciones.
    final errores = widget.mostrarErrores && !item.vacio;
    final alertaAlta = widget.alertas.any(
      (a) => a.gravedad == GravedadAlerta.alta,
    );
    final colorBorde = widget.alertas.isEmpty
        ? ColoresMarca.borde
        : alertaAlta
        ? ColoresMarca.error
        : ColoresMarca.aviso;

    Widget texto(
      String etiqueta,
      TextEditingController c,
      List<String> opciones,
      ValueChanged<String> alCambiar, {
      bool requerido = true,
      String? pista,
    }) => CampoSugerencias<String>(
      etiqueta: etiqueta,
      controller: c,
      requerido: requerido,
      mostrarError: errores,
      pista: pista,
      sugerencias: (q) => filtrarOpciones(opciones, q),
      texto: (o) => o,
      alCambiar: alCambiar,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorBorde,
            width: widget.alertas.isEmpty ? 1 : 1.6,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: widget.indice,
                  child: const Tooltip(
                    message: 'Arrastra para cambiar el orden',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.drag_indicator,
                          color: ColoresMarca.textoSuave,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: ColoresMarca.secundario,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$numero',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.titulo.isEmpty ? 'Medicamento $numero' : item.titulo,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: item.titulo.isEmpty
                          ? ColoresMarca.textoSuave
                          : null,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Subir',
                  onPressed: widget.indice == 0
                      ? null
                      : () => _ctrl.subir(item.id),
                  icon: const Icon(Icons.arrow_upward, size: 20),
                ),
                IconButton(
                  tooltip: 'Bajar',
                  onPressed: widget.indice == widget.total - 1
                      ? null
                      : () => _ctrl.bajar(item.id),
                  icon: const Icon(Icons.arrow_downward, size: 20),
                ),
                IconButton(
                  tooltip: 'Guardar en "Mis medicamentos"',
                  onPressed: item.medicamento.trim().isEmpty
                      ? null
                      : _guardarEnMisMedicamentos,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Quitar',
                  onPressed: _eliminar,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
            for (final a in widget.alertas)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: a.gravedad == GravedadAlerta.alta
                          ? ColoresMarca.error
                          : ColoresMarca.aviso,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Alergia a «${a.alergia}»: ${a.motivo}',
                        style: TextStyle(
                          fontSize: 13,
                          color: a.gravedad == GravedadAlerta.alta
                              ? ColoresMarca.error
                              : ColoresMarca.aviso,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            FilaCampos(
              flex: const [5, 3, 3],
              anchoMinimo: 620,
              children: [
                CampoSugerencias<PlantillaMedicamento>(
                  etiqueta: 'Medicamento (DCI o genérico)',
                  controller: _medicamento,
                  requerido: true,
                  mostrarError: errores,
                  mayusculas: TextCapitalization.sentences,
                  sugerencias: (q) => q.trim().isEmpty
                      ? const []
                      : buscarPlantillas(misMedicamentos, q),
                  texto: (p) => p.medicamento,
                  detalle: (p) => [
                    p.etiqueta,
                    p.detalle,
                  ].where((t) => t.isNotEmpty).join(' — '),
                  alElegir: _aplicar,
                  alCambiar: (v) => _editar((i) => i.copyWith(medicamento: v)),
                ),
                texto(
                  'Concentración',
                  _concentracion,
                  const [],
                  (v) => _editar((i) => i.copyWith(concentracion: v)),
                  pista: '500 mg',
                ),
                texto(
                  'Forma farmacéutica',
                  _forma,
                  formasFarmaceuticas(pais),
                  _cambiarForma,
                ),
              ],
            ),
            const SizedBox(height: 14),
            RejillaCampos(
              anchoMinimo: 150,
              children: [
                texto(
                  'Dosis',
                  _dosis,
                  const [],
                  (v) => _editar((i) => i.copyWith(dosis: v)),
                  pista: '1 cápsula',
                ),
                texto(
                  'Vía',
                  _via,
                  viasAdministracion,
                  (v) => _editar((i) => i.copyWith(via: v)),
                ),
                texto(
                  'Frecuencia',
                  _frecuencia,
                  frecuenciasFrecuentes,
                  (v) => _editar((i) => i.copyWith(frecuencia: v)),
                ),
                texto(
                  'Duración',
                  _duracion,
                  duracionesFrecuentes,
                  (v) => _editar((i) => i.copyWith(duracion: v)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _cantidad,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Cantidad *',
                      errorText: errores && (item.cantidad ?? 0) == 0
                          ? 'Obligatoria'
                          : null,
                    ),
                    onChanged: (t) => _cambiarCantidad(int.tryParse(t)),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: texto(
                    'Unidad',
                    _unidad,
                    const [
                      'tabletas',
                      'comprimidos',
                      'cápsulas',
                      'sobres',
                      'frascos',
                      'tubos',
                      'ampollas',
                      'envases',
                      'cajas',
                    ],
                    (v) => _editar((i) => i.copyWith(unidad: v)),
                    requerido: false,
                  ),
                ),
                if (item.cantidad != null && item.cantidad! > 0)
                  Text(
                    '(${numeroALetras(item.cantidad!)})',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: ColoresMarca.textoSuave,
                    ),
                  ),
                if (sugerida != null && sugerida != item.cantidad)
                  ActionChip(
                    avatar: const Icon(Icons.calculate_outlined, size: 18),
                    label: Text('Usar $sugerida'),
                    tooltip: 'Dosis × tomas al día × días',
                    onPressed: () {
                      _poner(_cantidad, '$sugerida');
                      _cambiarCantidad(sugerida);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            CampoTexto(
              etiqueta: 'Indicación particular (opcional)',
              pista: 'Con alimentos, si hay dolor o fiebre…',
              controller: _nota,
              alCambiar: (v) => _editar((i) => i.copyWith(nota: v)),
            ),
          ],
        ),
      ),
    );
  }
}
