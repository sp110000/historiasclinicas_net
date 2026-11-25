import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/inventario/insumo.dart';
import '../../../core/consultorio/inventario/inventario.dart';
import '../../../core/consultorio/reglas/inventario.dart';
import '../../../core/pais/perfil_pais.dart' show Opcion;
import '../../../core/utils/fechas.dart';
import '../../../core/utils/numeros.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../caja/dialogo_cobro.dart' show LineaRegla;
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';

/// Consulta de registros sanitarios de Invima (VERIFICAR la dirección). Se
/// abre en otra pestaña, sin enviarle datos (pregunta 49).
const urlConsultaInvima = 'https://consultaregistro.invima.gov.co/';

/// Color de cada estado del lote (el texto siempre dice el estado).
Color colorEstadoLote(EstadoLote e) => switch (e) {
  EstadoLote.vigente => ColoresMarca.estadoOk,
  EstadoLote.porVencer => ColoresMarca.aviso,
  EstadoLote.vencido => ColoresMarca.error,
  EstadoLote.agotado => ColoresMarca.textoSuave,
};

IconData iconoEstadoLote(EstadoLote e) => switch (e) {
  EstadoLote.vigente => Icons.check_circle_outline,
  EstadoLote.porVencer => Icons.hourglass_bottom,
  EstadoLote.vencido => Icons.block,
  EstadoLote.agotado => Icons.remove_circle_outline,
};

/// Crea o edita un insumo. Devuelve el guardado.
Future<Insumo?> editarInsumo(BuildContext context, {Insumo? insumo}) =>
    showDialog<Insumo>(
      context: context,
      builder: (_) => _DialogoInsumo(insumo: insumo),
    );

/// Registra la entrada de un lote. Devuelve el lote.
Future<Lote?> registrarEntrada(BuildContext context, {String? insumoId}) =>
    showDialog<Lote>(
      context: context,
      builder: (_) => _DialogoEntrada(insumoId: insumoId),
    );

/// Ajusta un lote (con motivo).
Future<void> ajustarLote(BuildContext context, WidgetRef ref, Lote l) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _DialogoAjuste(lote: l),
  );
  if (ok == true && context.mounted) {
    ref.read(versionIndiceProvider.notifier).cambio();
    mostrarMensaje(context, 'Lote ${l.numero} ajustado.');
  }
}

/// Da de baja toda la existencia del lote (con motivo).
Future<void> darDeBajaLote(BuildContext context, WidgetRef ref, Lote l) async {
  final motivo = await pedirTexto(
    context,
    titulo: 'Dar de baja el lote ${l.numero}',
    etiqueta: 'Motivo (vencido, dañado…)',
    aceptar: 'Dar de baja',
  );
  if (motivo == null || !context.mounted) return;
  try {
    await ref
        .read(servicioConsultorioProvider)
        .inventario
        .darDeBaja(l.id, motivo: motivo);
    ref.read(versionIndiceProvider.notifier).cambio();
    if (context.mounted) {
      mostrarMensaje(context, 'Lote ${l.numero} dado de baja.');
    }
  } catch (e) {
    if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
  }
}

/// Lo que se eligió en el selector de lote de la sesión.
sealed class EleccionLote {
  const EleccionLote();
}

class LoteElegido extends EleccionLote {
  const LoteElegido(this.lote);
  final Lote lote;
}

class EscribirAMano extends EleccionLote {
  const EscribirAMano();
}

/// Elige el lote de [nombre] en el inventario (o escribirlo a mano). El
/// insumo con ese nombre va primero; los vencidos se pueden elegir, pero la
/// sesión no se sella con ellos.
Future<EleccionLote?> elegirLoteInventario(
  BuildContext context, {
  required String nombre,
}) => showDialog<EleccionLote>(
  context: context,
  builder: (_) => _DialogoElegirLote(nombre: nombre),
);

class _DialogoInsumo extends ConsumerStatefulWidget {
  const _DialogoInsumo({this.insumo});

  final Insumo? insumo;

  @override
  ConsumerState<_DialogoInsumo> createState() => _DialogoInsumoState();
}

class _DialogoInsumoState extends ConsumerState<_DialogoInsumo> {
  late Insumo _i =
      widget.insumo ??
      ref.read(servicioConsultorioProvider).inventario.nuevoInsumo();
  var _guardando = false;
  String? _error;

  void _poner(Insumo i) => setState(() {
    _i = i;
    _error = null;
  });

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final g = await ref
          .read(servicioConsultorioProvider)
          .inventario
          .guardarInsumo(_i);
      if (mounted) Navigator.pop(context, g);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = _i;
    final movil = MediaQuery.sizeOf(context).width < 600;
    final aviso = i.nombre.trim().isEmpty ? null : avisoInvima(i);
    return AlertDialog(
      title: TituloDialogo(
        widget.insumo == null ? 'Insumo nuevo' : 'Editar el insumo',
        icono: Icons.inventory_2_outlined,
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: movil ? 12 : 40,
        vertical: 24,
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoTexto(
                etiqueta: 'Nombre',
                requerido: true,
                valorInicial: i.nombre,
                pista: 'Lidocaína 2 % sin epinefrina',
                alCambiar: (v) => _poner(_i.copyWith(nombre: v)),
              ),
              const SizedBox(height: 12),
              RejillaCampos(
                anchoMinimo: 200,
                children: [
                  CampoDesplegable(
                    etiqueta: 'Categoría',
                    opciones: [
                      for (final c in CategoriaInsumo.values)
                        Opcion(c.name, c.etiqueta),
                    ],
                    valor: i.categoria.name,
                    alCambiar: (v) => _poner(
                      _i.copyWith(categoria: CategoriaInsumo.values.byName(v)),
                    ),
                  ),
                  CampoTexto(
                    etiqueta: 'Presentación',
                    valorInicial: i.presentacion,
                    pista: 'Ampolla de 5 mL',
                    alCambiar: (v) => _poner(_i.copyWith(presentacion: v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RejillaCampos(
                anchoMinimo: 150,
                children: [
                  CampoTexto(
                    etiqueta: 'Unidad',
                    requerido: true,
                    valorInicial: i.unidad,
                    pista: 'ampolla, frasco, unidad',
                    mayusculas: TextCapitalization.none,
                    alCambiar: (v) => _poner(_i.copyWith(unidad: v)),
                  ),
                  CampoNumero(
                    etiqueta: 'Contenido por unidad',
                    unidad: 'mL',
                    valor: i.contenidoMl,
                    alCambiar: (v) => _poner(_i.copyWith(contenidoMl: v)),
                  ),
                  CampoNumero(
                    etiqueta: 'Concentración',
                    unidad: 'mg/mL',
                    valor: i.concentracionMgMl,
                    alCambiar: (v) => _poner(_i.copyWith(concentracionMgMl: v)),
                  ),
                  CampoNumero(
                    etiqueta: 'Mínimo',
                    unidad: i.unidad.trim().isEmpty ? null : i.unidad.trim(),
                    decimales: false,
                    valor: i.stockMinimo,
                    alCambiar: (v) => _poner(_i.copyWith(stockMinimo: v ?? 0)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CampoTexto(
                etiqueta: 'Registro Invima',
                valorInicial: i.registroInvima,
                mayusculas: TextCapitalization.characters,
                ayuda:
                    'Sin conexión no se puede verificar: usa «Consultar en '
                    'Invima» en el inventario.',
                alCambiar: (v) => _poner(_i.copyWith(registroInvima: v)),
              ),
              MergeSemantics(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: i.inyectable,
                  onChanged: (v) => _poner(_i.copyWith(inyectable: v)),
                  title: const Text('Inyectable'),
                ),
              ),
              if (widget.insumo != null)
                MergeSemantics(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: i.activo,
                    onChanged: (v) => _poner(_i.copyWith(activo: v)),
                    title: const Text('Activo'),
                    subtitle: const Text(
                      'Inactivo: no se sugiere en las sesiones ni alerta.',
                    ),
                  ),
                ),
              if (aviso != null) LineaRegla(aviso),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: ColoresMarca.error),
                  ),
                ),
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
          onPressed:
              _guardando || i.nombre.trim().isEmpty || i.unidad.trim().isEmpty
              ? null
              : _guardar,
          child: const Text('Guardar el insumo'),
        ),
      ],
    );
  }
}

class _DialogoEntrada extends ConsumerStatefulWidget {
  const _DialogoEntrada({this.insumoId});

  final String? insumoId;

  @override
  ConsumerState<_DialogoEntrada> createState() => _DialogoEntradaState();
}

class _DialogoEntradaState extends ConsumerState<_DialogoEntrada> {
  late String? _insumoId = widget.insumoId;
  var _numero = '';
  DateTime? _vence;
  double? _cantidad;
  var _proveedor = '';
  var _factura = '';
  var _guardando = false;
  String? _error;

  InventarioConsultorio get _inv =>
      ref.read(servicioConsultorioProvider).inventario;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final l = await _inv.registrarEntrada(
        insumoId: _insumoId!,
        numero: _numero,
        vence: _vence!,
        cantidad: _cantidad!,
        proveedor: _proveedor,
        factura: _factura,
      );
      if (mounted) Navigator.pop(context, l);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = _inv;
    final activos = [
      for (final i in inv.insumos)
        if (i.activo || i.id == _insumoId) i,
    ];
    final insumo = _insumoId == null ? null : inv.insumo(_insumoId!);
    final e = inv.evaluarEntrada(
      insumoId: _insumoId,
      numero: _numero,
      vence: _vence,
      cantidad: _cantidad,
    );
    final movil = MediaQuery.sizeOf(context).width < 600;
    return AlertDialog(
      title: const TituloDialogo(
        'Entrada de un lote',
        icono: Icons.move_to_inbox_outlined,
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: movil ? 12 : 40,
        vertical: 24,
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoDesplegable(
                etiqueta: 'Insumo',
                opciones: [for (final i in activos) Opcion(i.id, i.nombre)],
                valor: _insumoId,
                alCambiar: (v) => setState(() {
                  _insumoId = v;
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
              RejillaCampos(
                anchoMinimo: 160,
                children: [
                  CampoTexto(
                    etiqueta: 'Lote',
                    requerido: true,
                    mayusculas: TextCapitalization.characters,
                    alCambiar: (v) => setState(() => _numero = v),
                  ),
                  CampoFecha(
                    etiqueta: 'Vence',
                    requerido: true,
                    valor: _vence,
                    primera: DateTime(2000),
                    ultima: DateTime(2100),
                    alCambiar: (f) => setState(() => _vence = f),
                  ),
                  CampoNumero(
                    etiqueta: 'Cantidad',
                    unidad: insumo?.unidad,
                    decimales: false,
                    valor: _cantidad,
                    alCambiar: (v) => setState(() => _cantidad = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RejillaCampos(
                anchoMinimo: 200,
                children: [
                  CampoTexto(
                    etiqueta: 'Proveedor',
                    alCambiar: (v) => _proveedor = v,
                  ),
                  CampoTexto(
                    etiqueta: 'Factura',
                    mayusculas: TextCapitalization.characters,
                    alCambiar: (v) => _factura = v,
                  ),
                ],
              ),
              if (e.bloqueos.isNotEmpty || e.avisos.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final m in e.bloqueos) LineaRegla(m, bloqueo: true),
                for (final m in e.avisos) LineaRegla(m),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: ColoresMarca.error),
                  ),
                ),
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
          onPressed: _guardando || !e.permite ? null : _guardar,
          child: const Text('Registrar la entrada'),
        ),
      ],
    );
  }
}

class _DialogoAjuste extends ConsumerStatefulWidget {
  const _DialogoAjuste({required this.lote});

  final Lote lote;

  @override
  ConsumerState<_DialogoAjuste> createState() => _DialogoAjusteState();
}

class _DialogoAjusteState extends ConsumerState<_DialogoAjuste> {
  var _sumar = false;
  double? _cantidad;
  var _motivo = '';
  String? _error;

  @override
  Widget build(BuildContext context) {
    final inv = ref.read(servicioConsultorioProvider).inventario;
    final l = widget.lote;
    final insumo = inv.insumo(l.insumoId);
    final hay = inv.existencia(l.id);
    final con = _cantidad == null ? null : (_sumar ? _cantidad! : -_cantidad!);
    final e = evaluarAjuste(existencia: hay, cantidad: con, motivo: _motivo);
    return AlertDialog(
      title: TituloDialogo('Ajustar el lote ${l.numero}', icono: Icons.tune),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${insumo?.nombre ?? ''} · hay '
                '${cantidadTexto(hay, insumo?.unidad ?? '')}',
                style: const TextStyle(color: ColoresMarca.textoSuave),
              ),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Restar')),
                  ButtonSegment(value: true, label: Text('Sumar')),
                ],
                selected: {_sumar},
                onSelectionChanged: (v) => setState(() => _sumar = v.first),
              ),
              const SizedBox(height: 10),
              CampoNumero(
                etiqueta: 'Cantidad',
                unidad: insumo?.unidad,
                valor: _cantidad,
                alCambiar: (v) => setState(() => _cantidad = v),
              ),
              const SizedBox(height: 10),
              CampoTexto(
                etiqueta: 'Motivo',
                requerido: true,
                pista: 'Conteo físico, ampolla rota…',
                alCambiar: (v) => setState(() => _motivo = v),
              ),
              if (con != null && e.permite)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Quedan ${cantidadTexto(hay + con, insumo?.unidad ?? '')}.',
                  ),
                ),
              for (final m in e.bloqueos)
                if (_cantidad != null || _motivo.isNotEmpty)
                  LineaRegla(m, bloqueo: true),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: ColoresMarca.error),
                ),
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
          onPressed: !e.permite
              ? null
              : () async {
                  try {
                    await inv.ajustar(l.id, con!, motivo: _motivo);
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (x) {
                    setState(() => _error = mensajeDeError(x));
                  }
                },
          child: const Text('Ajustar'),
        ),
      ],
    );
  }
}

class _DialogoElegirLote extends ConsumerWidget {
  const _DialogoElegirLote({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.read(servicioConsultorioProvider).inventario;
    final propio = inv.insumoPorNombre(nombre);
    final insumos = [
      ?propio,
      for (final i in inv.insumos)
        if (i.activo && i.id != propio?.id) i,
    ];
    final filas = <Widget>[];
    for (final i in insumos) {
      final lotes = [
        for (final l in inv.lotesDe(i.id))
          if (inv.existencia(l.id) > 0) l,
      ];
      if (lotes.isEmpty) continue;
      filas.add(
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Text(
            i.nombre,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
      for (final l in lotes) {
        final estado = inv.estado(l);
        filas.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              iconoEstadoLote(estado),
              color: colorEstadoLote(estado),
            ),
            title: Text('Lote ${l.numero} · vence ${formatoFecha(l.vence)}'),
            subtitle: Text(
              '${estado.etiqueta} · quedan '
              '${cantidadTexto(inv.existencia(l.id), i.unidad)}'
              '${l == inv.sugerido(i.id) ? ' · sugerido (vence primero)' : ''}',
            ),
            onTap: () => Navigator.pop(context, LoteElegido(l)),
          ),
        );
      }
    }
    return AlertDialog(
      title: TituloDialogo(
        'Lote de «$nombre»',
        icono: Icons.inventory_2_outlined,
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (filas.isEmpty)
                const Text(
                  'No hay lotes con existencias en el inventario.',
                  style: TextStyle(color: ColoresMarca.textoSuave),
                ),
              ...filas,
              if (propio == null && filas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Ningún insumo se llama «$nombre»: elige el que '
                    'corresponde.',
                    style: const TextStyle(color: ColoresMarca.textoSuave),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Un lote vencido se puede elegir, pero la sesión no se '
                  'sella con él.',
                  style: TextStyle(
                    color: ColoresMarca.textoSuave,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, const EscribirAMano()),
          child: const Text('Escribirlo a mano'),
        ),
      ],
    );
  }
}

/// «2 ampollas» de [i], o el número solo si no hay insumo.
String unidadesTexto(double u, Insumo? i) =>
    i == null ? formatoNumero(u) : cantidadTexto(u, i.unidad);
