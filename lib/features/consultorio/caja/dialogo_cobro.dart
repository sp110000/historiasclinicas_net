import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/agenda/cita.dart';
import '../../../core/consultorio/caja/caja.dart';
import '../../../core/consultorio/caja/catalogo.dart';
import '../../../core/consultorio/caja/movimientos.dart';
import '../../../core/consultorio/inventario/inventario.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/consultorio/reglas/caja.dart';
import '../../../core/consultorio/reglas/inventario.dart' show cantidadTexto;
import '../../../core/pais/pais_provider.dart';
import '../../../core/pais/perfil_pais.dart' show Opcion;
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/campo_sugerencias.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../historia/widgets/dialogos.dart';
import '../../medico/medico_provider.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../pacientes/dialogo_ficha.dart';
import '../widgets/comunes.dart';
import 'campo_pesos.dart';
import '../widgets/texto_normativo.dart';

/// El servicio que se sugiere al cobrar una cita de tipo [t].
String servicioDeCita(TipoCita t) => switch (t) {
  TipoCita.primeraVez => 'consulta_primera_vez',
  TipoCita.control || TipoCita.programaPeso => 'control',
  TipoCita.valoracionEstetica => 'valoracion_estetica',
  TipoCita.sesion => 'sesion_hidrolipoclasia',
};

String nombreArchivoRecibo(Recibo r) => 'Recibo_${r.numero}.pdf';

/// «Insumos: Jeringa, 2 unidades (lote J-1) · …», o `null` si el cobro no
/// lleva insumos.
String? textoInsumos(Cobro c) => c.insumos.isEmpty
    ? null
    : 'Insumos: ${[for (final i in c.insumos) '${i.nombre}, ${cantidadTexto(i.cantidad, i.unidad)} (lote ${i.lote})'].join(' · ')}';

String _descontados(Cobro c) => switch (c.insumos.length) {
  0 => '',
  1 => ' Se descontó 1 insumo del inventario.',
  final n => ' Se descontaron $n insumos del inventario.',
};

/// Descarga el PDF guardado del recibo [r]. Lee los proveedores antes de
/// esperar: la fila que lo pide puede desaparecer mientras tanto.
Future<void> descargarRecibo(WidgetRef ref, Recibo r) async {
  final descargar = ref.read(descargarPdfProvider);
  final pdf = await ref.read(servicioConsultorioProvider).caja.pdfRecibo(r.id);
  if (pdf != null) descargar(pdf, nombreArchivoRecibo(r));
}

typedef _Resultado = ({ResultadoCobro? cobro, Paquete? paquete});

/// Lo que se necesita después de un diálogo, leído antes de abrirlo: al
/// registrar, la tarjeta o la fila que lo abrió puede desaparecer (un saldo
/// pagado deja la lista) y su `ref` y su `context` ya no sirven.
typedef _Despues = ({
  void Function() notificar,
  void Function(Uint8List, String) descargar,
  CajaConsultorio caja,
  ScaffoldMessengerState? mensajero,
});

_Despues _antes(BuildContext context, WidgetRef ref) => (
  notificar: ref.read(versionIndiceProvider.notifier).cambio,
  descargar: ref.read(descargarPdfProvider),
  caja: ref.read(servicioConsultorioProvider).caja,
  mensajero: ScaffoldMessenger.maybeOf(context),
);

void _mensaje(_Despues d, String texto) => d.mensajero
  ?..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(texto)));

/// Cobra a [pacienteId] (o al de la [cita]): servicios, descuentos, crédito
/// de la valoración y pagos. Con pago, descarga el recibo.
Future<void> abrirCobro(
  BuildContext context,
  WidgetRef ref, {
  String? pacienteId,
  Cita? cita,
}) async {
  final d = _antes(context, ref);
  final r = await showDialog<_Resultado>(
    context: context,
    builder: (_) =>
        _DialogoCobro(pacienteId: pacienteId ?? cita?.pacienteId, cita: cita),
  );
  if (r == null) return;
  d.notificar();
  if (r.paquete case final p?) {
    _mensaje(
      d,
      '${p.nombre}: sesión ${p.usadas} de ${p.sesiones} usada (sin recibo).',
    );
    return;
  }
  final c = r.cobro!;
  final saldo = d.caja.saldo(c.cobro);
  if (c.recibo case final recibo?) {
    d.descargar(c.pdf!, nombreArchivoRecibo(recibo));
    _mensaje(
      d,
      'Recibo ${recibo.numero} descargado'
      '${saldo > 0 ? '. Queda un saldo de ${formatoPesos(saldo)}.' : '.'}'
      '${_descontados(c.cobro)}',
    );
  } else {
    _mensaje(
      d,
      'Cobro registrado sin pago: queda el saldo de ${formatoPesos(saldo)}.'
      '${_descontados(c.cobro)}',
    );
  }
}

/// Un abono a [cobro]: descarga su recibo.
Future<void> abrirAbono(
  BuildContext context,
  WidgetRef ref,
  Cobro cobro,
) async {
  final d = _antes(context, ref);
  final r = await showDialog<(Recibo, Uint8List)>(
    context: context,
    builder: (_) => _DialogoAbono(cobro: cobro),
  );
  if (r == null) return;
  d.notificar();
  final (recibo, pdf) = r;
  d.descargar(pdf, nombreArchivoRecibo(recibo));
  final saldo = d.caja.saldo(cobro);
  _mensaje(
    d,
    'Recibo ${recibo.numero} descargado'
    '${saldo > 0 ? '. Queda un saldo de ${formatoPesos(saldo)}.' : '.'}',
  );
}

/// Anula [r] con motivo.
Future<void> anularReciboConMotivo(
  BuildContext context,
  WidgetRef ref,
  Recibo r,
) async {
  final d = _antes(context, ref);
  final motivo = await pedirTexto(
    context,
    titulo: 'Anular el recibo ${r.numero}',
    etiqueta: 'Motivo de la anulación',
    aceptar: 'Anular',
  );
  if (motivo == null) return;
  try {
    await d.caja.anularRecibo(r.id, motivo: motivo);
    d.notificar();
    _mensaje(d, 'Recibo ${r.numero} anulado.');
  } catch (e) {
    _mensaje(d, mensajeDeError(e));
  }
}

/// Anula un cobro sin recibos vigentes (libera el crédito y el paquete, y
/// devuelve sus insumos al inventario).
Future<void> anularCobroConMotivo(
  BuildContext context,
  WidgetRef ref,
  Cobro c,
) async {
  final d = _antes(context, ref);
  final motivo = await pedirTexto(
    context,
    titulo: 'Anular el cobro',
    etiqueta: 'Motivo de la anulación',
    aceptar: 'Anular',
    texto: c.insumos.isEmpty
        ? null
        : 'Sus insumos vuelven al inventario. Si sí se usaron, regístralos '
              'de nuevo en el cobro que lo reemplace.',
  );
  if (motivo == null) return;
  try {
    await d.caja.anularCobro(c.id, motivo: motivo);
    d.notificar();
    _mensaje(
      d,
      c.insumos.isEmpty
          ? 'Cobro anulado.'
          : 'Cobro anulado: sus insumos volvieron al inventario.',
    );
  } catch (e) {
    _mensaje(d, mensajeDeError(e));
  }
}

/// Usa una sesión del paquete [p] (sin recibo, pregunta 46).
Future<Paquete?> usarSesionPaquete(
  BuildContext context,
  WidgetRef ref,
  Paquete p, {
  bool mensaje = true,
}) async {
  final si = await confirmar(
    context,
    titulo: 'Usar una sesión del paquete',
    texto:
        '${p.nombre}: sesión ${p.usadas + 1} de ${p.sesiones}. No genera '
        'recibo ni cobro.',
    aceptar: 'Usar la sesión',
    icono: Icons.confirmation_number_outlined,
  );
  if (!si || !context.mounted) return null;
  try {
    final u = await ref
        .read(servicioConsultorioProvider)
        .caja
        .usarPaquete(p.id);
    ref.read(versionIndiceProvider.notifier).cambio();
    if (mensaje && context.mounted) {
      mostrarMensaje(
        context,
        '${u.nombre}: sesión ${u.usadas} de ${u.sesiones} usada (sin recibo).',
      );
    }
    return u;
  } catch (e) {
    if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
    return null;
  }
}

/// Un bloqueo o un aviso de las reglas.
class LineaRegla extends StatelessWidget {
  const LineaRegla(this.texto, {super.key, this.bloqueo = false});

  final String texto;
  final bool bloqueo;

  @override
  Widget build(BuildContext context) {
    final color = bloqueo ? ColoresMarca.error : ColoresMarca.aviso;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            bloqueo ? Icons.block : Icons.warning_amber_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextoNormativo(texto, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

/// Una fila «concepto … valor» de los totales.
class FilaValor extends StatelessWidget {
  const FilaValor(
    this.concepto,
    this.valor, {
    super.key,
    this.fuerte = false,
    this.color,
  });

  final String concepto;
  final int valor;
  final bool fuerte;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontWeight: fuerte ? FontWeight.w700 : FontWeight.w400,
      fontSize: fuerte ? 16 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(concepto, style: estilo)),
          Text(formatoPesos(valor), style: estilo),
        ],
      ),
    );
  }
}

class _FilaPago {
  _FilaPago(this.clave);

  final int clave;
  MedioPago medio = MedioPago.efectivo;
  final valor = TextEditingController();
  String referencia = '';

  /// Sigue lo que falta por pagar hasta que se escribe a mano.
  bool auto = true;

  PagoRecibo get pago => PagoRecibo(
    medio: medio,
    valor: leerPesos(valor.text) ?? 0,
    referencia: referencia.trim(),
  );
}

/// Pagos por medio, compartidos por el cobro y el abono.
mixin _ConPagos<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final _pagos = <_FilaPago>[];
  var _clave = 0;

  /// Lo que se debe antes de estos pagos.
  int get debe;

  List<PagoRecibo> get pagos => [for (final p in _pagos) p.pago];

  void iniciarPagos() {
    _pagos.add(_FilaPago(_clave++));
    recalcularPagos();
  }

  /// La fila automática toma lo que falta.
  void recalcularPagos() {
    final auto = _pagos.where((p) => p.auto).firstOrNull;
    if (auto == null) return;
    final otros = _pagos
        .where((p) => p != auto)
        .fold(0, (s, p) => s + p.pago.valor);
    final v = debe - otros;
    auto.valor.text = v > 0 ? milesPesos(v) : '';
  }

  void disposePagos() {
    for (final p in _pagos) {
      p.valor.dispose();
    }
  }

  List<Widget> editorPagos() => [
    const SizedBox(height: 14),
    const Text('PAGOS', style: EstilosMarca.rotulo),
    const SizedBox(height: 6),
    if (_pagos.isEmpty)
      const Text(
        'Sin pago ahora: el cobro queda con saldo y no hay recibo.',
        style: TextStyle(color: ColoresMarca.textoSuave),
      ),
    for (final (i, p) in _pagos.indexed)
      Padding(
        key: ValueKey('pago-${p.clave}'),
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RejillaCampos(
                anchoMinimo: 150,
                maxColumnas: 3,
                children: [
                  CampoDesplegable(
                    etiqueta: 'Medio de pago ${i + 1}',
                    opciones: [
                      for (final m in MedioPago.values)
                        Opcion(m.name, m.etiqueta),
                    ],
                    valor: p.medio.name,
                    alCambiar: (v) =>
                        setState(() => p.medio = MedioPago.values.byName(v)),
                  ),
                  CampoPesos(
                    etiqueta: 'Valor',
                    controller: p.valor,
                    requerido: true,
                    alCambiar: (_) => setState(() {
                      p.auto = false;
                      recalcularPagos();
                    }),
                  ),
                  if (p.medio != MedioPago.efectivo)
                    CampoTexto(
                      etiqueta: 'Referencia',
                      valorInicial: p.referencia,
                      pista: 'Opcional',
                      alCambiar: (v) => p.referencia = v,
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Quitar el pago ${i + 1}',
              onPressed: () => setState(() {
                _pagos.remove(p);
                p.valor.dispose();
                recalcularPagos();
              }),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => setState(() {
          for (final p in _pagos) {
            p.auto = false;
          }
          _pagos.add(_FilaPago(_clave++));
          recalcularPagos();
        }),
        icon: const Icon(Icons.add),
        label: Text(_pagos.isEmpty ? 'Agregar un pago' : 'Otro medio de pago'),
      ),
    ),
  ];
}

class _Item {
  _Item(this.clave, this.item);

  final int clave;
  ItemCobro item;
}

class _Insumo {
  _Insumo(this.clave, this.linea);

  final int clave;
  InsumoCobro linea;
}

class _DialogoCobro extends ConsumerStatefulWidget {
  const _DialogoCobro({this.pacienteId, this.cita});

  final String? pacienteId;
  final Cita? cita;

  @override
  ConsumerState<_DialogoCobro> createState() => _DialogoCobroState();
}

class _DialogoCobroState extends ConsumerState<_DialogoCobro>
    with _ConPagos<_DialogoCobro> {
  final _paciente = TextEditingController();
  late String _pacienteId = widget.pacienteId ?? '';
  final _items = <_Item>[];
  var _claveItem = 0;
  final _insumos = <_Insumo>[];
  bool? _aplicarCredito;
  var _guardando = false;
  String? _error;

  CajaConsultorio get _caja => ref.read(servicioConsultorioProvider).caja;
  InventarioConsultorio get _inv =>
      ref.read(servicioConsultorioProvider).inventario;

  List<Servicio> get _activos => [
    for (final s in _caja.servicios)
      if (s.activo) s,
  ];

  @override
  void initState() {
    super.initState();
    final f = _ficha;
    if (f != null) _paciente.text = f.nombreCompleto;
    final sugerido = widget.cita == null
        ? null
        : _caja.serviciosPorId[servicioDeCita(widget.cita!.tipo)];
    final primero = sugerido != null && sugerido.activo
        ? sugerido
        : _activos.firstOrNull;
    if (primero != null) _agregar(primero);
    iniciarPagos();
  }

  @override
  void dispose() {
    _paciente.dispose();
    disposePagos();
    super.dispose();
  }

  FichaPaciente? get _ficha => _pacienteId.isEmpty
      ? null
      : ref.read(servicioConsultorioProvider).indice.fichaActiva(_pacienteId);

  void _agregar(Servicio s) => _items.add(
    _Item(
      _claveItem++,
      ItemCobro(
        servicioId: s.id,
        descripcion: s.nombre,
        valorUnitario: s.tarifa,
      ),
    ),
  );

  void _cambio(VoidCallback f) => setState(() {
    f();
    _error = null;
    recalcularPagos();
  });

  List<ItemCobro> get _lista => [for (final i in _items) i.item];
  List<InsumoCobro> get _listaInsumos => [for (final i in _insumos) i.linea];

  /// Una línea con el primer insumo usable, del lote que vence primero.
  void _agregarInsumo() {
    final i = _inv.usables.firstOrNull;
    final l = i == null ? null : _inv.sugerido(i.id);
    if (l == null) return;
    _insumos.add(_Insumo(_claveItem++, _inv.insumoCobro(l, 1)));
  }

  bool get _tratamientoEstetico => _items.any((i) {
    final s = _caja.serviciosPorId[i.item.servicioId];
    return s != null && s.linea == LineaAtencion.estetica && !s.abonable;
  });

  Credito? get _disponible => _pacienteId.isEmpty
      ? null
      : _caja.creditosDisponibles(_pacienteId).firstOrNull;

  Credito? get _credito {
    final c = _disponible;
    if (c == null) return null;
    return (_aplicarCredito ?? _tratamientoEstetico) ? c : null;
  }

  int get _total {
    final neto = _lista.fold(0, (s, i) => s + i.neto);
    return neto - _caja.valorCredito(_credito, _lista);
  }

  @override
  int get debe => _total < 0 ? 0 : _total;

  void _ponerPaciente(String id) => _cambio(() {
    _pacienteId = id;
    _aplicarCredito = null;
  });

  Future<void> _pacienteNuevo() async {
    final f = await editarFicha(context);
    if (f == null || !mounted) return;
    ref.read(versionIndiceProvider.notifier).cambio();
    _paciente.text = f.nombreCompleto;
    _ponerPaciente(f.id);
  }

  Future<void> _usarPaquete(Paquete p) async {
    final u = await usarSesionPaquete(context, ref, p, mensaje: false);
    if (u != null && mounted) Navigator.pop(context, (cobro: null, paquete: u));
  }

  Future<void> _registrar() async {
    setState(() => _guardando = true);
    try {
      final r = await _caja.cobrar(
        pacienteId: _pacienteId,
        items: _lista,
        pagos: pagos,
        credito: _credito,
        citaId: widget.cita?.id,
        insumos: _listaInsumos,
        medico: ref.read(medicoProvider),
        pais: ref.read(paisProvider),
      );
      if (mounted) Navigator.pop(context, (cobro: r, paquete: null));
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  Widget _editorItem(_Item x) {
    final i = x.item;
    final opciones = [
      for (final s in _activos) Opcion(s.id, s.nombre),
      if (!_activos.any((s) => s.id == i.servicioId))
        Opcion(i.servicioId, i.descripcion),
    ];
    return Container(
      key: ValueKey('item-${x.clave}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CampoDesplegable(
                  etiqueta: 'Servicio',
                  opciones: opciones,
                  valor: i.servicioId,
                  alCambiar: (v) => _cambio(() {
                    final s = _caja.serviciosPorId[v]!;
                    x.item = ItemCobro(
                      servicioId: s.id,
                      descripcion: s.nombre,
                      valorUnitario: s.tarifa,
                      cantidad: i.cantidad,
                    );
                  }),
                ),
              ),
              IconButton(
                tooltip: 'Quitar «${i.descripcion}»',
                onPressed: () => _cambio(() => _items.remove(x)),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: RejillaCampos(
              anchoMinimo: 120,
              maxColumnas: 3,
              children: [
                CampoEntero(
                  key: ValueKey('cantidad-${x.clave}'),
                  etiqueta: 'Cantidad',
                  valor: i.cantidad,
                  alCambiar: (v) =>
                      _cambio(() => x.item = i.copyWith(cantidad: v ?? 0)),
                ),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Valor',
                    helperText: i.cantidad > 1
                        ? '${i.cantidad} × ${formatoPesos(i.valorUnitario)}'
                        : null,
                  ),
                  child: Text(formatoPesos(i.bruto)),
                ),
                CampoPesos(
                  key: ValueKey('descuento-${x.clave}-${i.servicioId}'),
                  etiqueta: 'Descuento',
                  valorInicial: i.descuento > 0 ? i.descuento : null,
                  alCambiar: (v) => _cambio(
                    () => x.item = x.item.copyWith(descuento: v ?? 0),
                  ),
                ),
              ],
            ),
          ),
          if (i.descuento > 0) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CampoTexto(
                key: ValueKey('motivo-${x.clave}'),
                etiqueta: 'Motivo del descuento',
                requerido: true,
                valorInicial: i.motivoDescuento,
                alCambiar: (v) => setState(
                  () => x.item = x.item.copyWith(motivoDescuento: v),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _editorInsumo(_Insumo x) {
    final l = x.linea;
    final insumo = _inv.insumo(l.insumoId);
    final unidad = insumo?.unidad ?? l.unidad;
    final insumos = [
      for (final i in _inv.usables) Opcion(i.id, i.nombre),
      if (!_inv.usables.any((i) => i.id == l.insumoId))
        Opcion(l.insumoId, l.nombre),
    ];
    final disponibles = _inv.disponibles(l.insumoId);
    final lotes = [
      for (final lote in disponibles)
        Opcion(lote.id, '${lote.numero} · vence ${formatoFecha(lote.vence)}'),
      if (!disponibles.any((lote) => lote.id == l.loteId))
        Opcion(l.loteId, l.lote),
    ];
    return Container(
      key: ValueKey('insumo-${x.clave}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampoDesplegable(
                  etiqueta: 'Insumo',
                  opciones: insumos,
                  valor: l.insumoId,
                  alCambiar: (v) => _cambio(() {
                    final lote = _inv.sugerido(v);
                    if (lote != null) {
                      x.linea = _inv.insumoCobro(lote, l.cantidad);
                    }
                  }),
                ),
                const SizedBox(height: 8),
                RejillaCampos(
                  anchoMinimo: 150,
                  maxColumnas: 2,
                  children: [
                    CampoDesplegable(
                      etiqueta: 'Lote',
                      opciones: lotes,
                      valor: l.loteId,
                      alCambiar: (v) => _cambio(() {
                        final lote = _inv.lote(v);
                        if (lote != null) {
                          x.linea = _inv.insumoCobro(lote, l.cantidad);
                        }
                      }),
                    ),
                    CampoNumero(
                      key: ValueKey('cantidad-insumo-${x.clave}'),
                      etiqueta: 'Cantidad',
                      unidad: unidad,
                      valor: l.cantidad,
                      alCambiar: (v) =>
                          _cambio(() => x.linea = x.linea.conCantidad(v ?? 0)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'En el lote ${l.lote} quedan '
                  '${cantidadTexto(_inv.existencia(l.loteId), unidad)}.',
                  style: const TextStyle(color: ColoresMarca.textoSuave),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar «${l.nombre}»',
            onPressed: () => _cambio(() => _insumos.remove(x)),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  /// Insumos usados: se descuentan del inventario al registrar el cobro.
  List<Widget> _seccionInsumos() {
    if (_inv.vacio) return const [];
    final usables = _inv.usables;
    return [
      const SizedBox(height: 14),
      const Text('INSUMOS USADOS', style: EstilosMarca.rotulo),
      const SizedBox(height: 4),
      const Text(
        'Se descuentan del inventario al registrar el cobro y no cambian su '
        'valor. Los de una sesión sellada ya se descontaron: no los repitas.',
        style: TextStyle(color: ColoresMarca.textoSuave),
      ),
      const SizedBox(height: 8),
      for (final x in _insumos) _editorInsumo(x),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: usables.isEmpty ? null : () => _cambio(_agregarInsumo),
          icon: const Icon(Icons.add),
          label: Text(
            usables.isEmpty
                ? 'Ningún insumo tiene existencias vigentes'
                : 'Agregar un insumo',
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.read(servicioConsultorioProvider);
    final caja = s.caja;
    final ficha = _ficha;
    final lista = _lista;
    final credito = _credito;
    final disponible = _disponible;
    final e = caja.evaluar(
      pacienteId: _pacienteId,
      items: lista,
      pagos: pagos,
      credito: credito,
      insumos: _listaInsumos,
    );
    final bruto = lista.fold(0, (s, i) => s + i.bruto);
    final descuentos = lista.fold(0, (s, i) => s + i.descuento);
    final valorCredito = caja.valorCredito(credito, lista);
    final pagado = sumaPagos(pagos);
    final saldoPrevio = ficha == null ? 0 : caja.saldoPaciente(ficha.id);
    final paquetes = ficha == null
        ? const <Paquete>[]
        : [
            for (final p in caja.paquetesDe(ficha.id))
              if (p.activo) p,
          ];
    final movil = MediaQuery.sizeOf(context).width < 600;
    return AlertDialog(
      title: const TituloDialogo('Cobrar', icono: Icons.point_of_sale),
      insetPadding: EdgeInsets.symmetric(
        horizontal: movil ? 12 : 40,
        vertical: 24,
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: CampoSugerencias<FichaPaciente>(
                      etiqueta: 'Paciente',
                      requerido: true,
                      controller: _paciente,
                      pista: 'Nombre o documento',
                      sugerencias: (q) => q.trim().length < 2
                          ? const []
                          : [
                              for (final r in s.indice.buscar(texto: q).take(8))
                                r.ficha,
                            ],
                      texto: (f) => f.nombreCompleto,
                      detalle: (f) => f.documentoTexto,
                      alElegir: (f) {
                        _paciente.text = f.nombreCompleto;
                        _ponerPaciente(f.id);
                      },
                      alCambiar: (v) {
                        if (ficha != null && v != ficha.nombreCompleto) {
                          _ponerPaciente('');
                        }
                      },
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pacienteNuevo,
                    icon: const Icon(Icons.person_add_alt_outlined),
                    label: const Text('Paciente nuevo'),
                  ),
                ],
              ),
              if (saldoPrevio > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Tiene un saldo pendiente de ${formatoPesos(saldoPrevio)}: '
                    'se abona desde la caja o la ficha.',
                    style: const TextStyle(color: ColoresMarca.aviso),
                  ),
                ),
              for (final p in paquetes)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: ColoresMarca.primario.withValues(alpha: 0.05),
                    borderRadius: RadiosMarca.tarjeta,
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        '${p.nombre}: quedan ${p.pendientes} de ${p.sesiones}.',
                      ),
                      TextButton.icon(
                        onPressed: () => _usarPaquete(p),
                        icon: const Icon(Icons.confirmation_number_outlined),
                        label: const Text('Usar una sesión (sin cobro)'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              const Text('SERVICIOS', style: EstilosMarca.rotulo),
              const SizedBox(height: 6),
              for (final x in _items) _editorItem(x),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _activos.isEmpty
                      ? null
                      : () => _cambio(() => _agregar(_activos.first)),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar un servicio'),
                ),
              ),
              if (disponible != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: credito != null,
                  onChanged: (v) => _cambio(() => _aplicarCredito = v),
                  title: const Text('Aplicar el crédito de la valoración'),
                  subtitle: Text(
                    '${formatoPesos(disponible.valor)} · vence el '
                    '${formatoFecha(disponible.vence)}',
                  ),
                ),
              ..._seccionInsumos(),
              const Divider(),
              FilaValor('Subtotal', bruto),
              if (descuentos > 0) FilaValor('Descuentos', -descuentos),
              if (valorCredito > 0)
                FilaValor('Crédito de la valoración', -valorCredito),
              FilaValor('Total', _total, fuerte: true),
              ...editorPagos(),
              if (_pagos.isNotEmpty) ...[
                const Divider(),
                FilaValor('Pagado ahora', pagado),
                FilaValor(
                  'Saldo',
                  _total - pagado,
                  fuerte: true,
                  color: _total - pagado > 0 ? ColoresMarca.aviso : null,
                ),
              ],
              if (e.bloqueos.isNotEmpty || e.avisos.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final m in e.bloqueos) LineaRegla(m, bloqueo: true),
                for (final m in e.avisos) LineaRegla(m),
              ],
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
          onPressed: _guardando || !e.permiteRegistrar ? null : _registrar,
          child: Text(
            _pagos.isEmpty
                ? 'Registrar sin pago'
                : 'Registrar y descargar el recibo',
          ),
        ),
      ],
    );
  }
}

class _DialogoAbono extends ConsumerStatefulWidget {
  const _DialogoAbono({required this.cobro});

  final Cobro cobro;

  @override
  ConsumerState<_DialogoAbono> createState() => _DialogoAbonoState();
}

class _DialogoAbonoState extends ConsumerState<_DialogoAbono>
    with _ConPagos<_DialogoAbono> {
  var _guardando = false;
  String? _error;

  CajaConsultorio get _caja => ref.read(servicioConsultorioProvider).caja;

  @override
  int get debe => _caja.saldo(widget.cobro);

  @override
  void initState() {
    super.initState();
    iniciarPagos();
  }

  @override
  void dispose() {
    disposePagos();
    super.dispose();
  }

  Future<void> _registrar() async {
    setState(() => _guardando = true);
    try {
      final r = await _caja.abonar(
        widget.cobro.id,
        pagos,
        medico: ref.read(medicoProvider),
        pais: ref.read(paisProvider),
      );
      if (mounted) Navigator.pop(context, (r.$1, r.$2));
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
    final s = ref.read(servicioConsultorioProvider);
    final c = widget.cobro;
    final saldo = debe;
    final e = evaluarAbono(
      cobro: c,
      saldo: saldo,
      pagos: pagos,
      diaCerrado: _caja.hoyCerrado,
    );
    final ficha = s.indice.ficha(c.pacienteId);
    final movil = MediaQuery.sizeOf(context).width < 600;
    return AlertDialog(
      title: const TituloDialogo('Abonar', icono: Icons.payments_outlined),
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
              Text(
                ficha?.nombreCompleto ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${c.descripcion} · ${formatoFecha(c.fecha)}',
                style: const TextStyle(color: ColoresMarca.textoSuave),
              ),
              const SizedBox(height: 8),
              FilaValor('Total', c.total),
              FilaValor('Pagado', _caja.pagado(c.id)),
              FilaValor('Saldo', saldo, fuerte: true),
              ...editorPagos(),
              if (e.bloqueos.isNotEmpty || e.avisos.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final m in e.bloqueos) LineaRegla(m, bloqueo: true),
                for (final m in e.avisos) LineaRegla(m),
              ],
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
          onPressed: _guardando || !e.permiteRegistrar ? null : _registrar,
          child: const Text('Registrar y descargar el recibo'),
        ),
      ],
    );
  }
}
