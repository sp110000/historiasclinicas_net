import '../../models/mapa.dart';
import 'catalogo.dart';

/// Un renglón de un cobro.
class ItemCobro {
  const ItemCobro({
    required this.servicioId,
    required this.descripcion,
    required this.valorUnitario,
    this.cantidad = 1,
    this.descuento = 0,
    this.motivoDescuento = '',
    this.plantillaId,
  });

  /// El id del servicio de un procedimiento que se cobra.
  static String idProcedimiento(String plantillaId) =>
      'procedimiento:$plantillaId';

  /// Un servicio del catálogo o, con [plantillaId], un procedimiento.
  final String servicioId;
  final String descripcion;
  final int cantidad;
  final int valorUnitario;
  final int descuento;
  final String motivoDescuento;

  /// El procedimiento que se cobra (de Procedimientos), o `null` si es un
  /// servicio del catálogo.
  final String? plantillaId;

  bool get esProcedimiento => plantillaId != null;

  int get bruto => cantidad * valorUnitario;
  int get neto => bruto - descuento;

  ItemCobro copyWith({
    String? descripcion,
    int? cantidad,
    int? valorUnitario,
    int? descuento,
    String? motivoDescuento,
  }) => ItemCobro(
    servicioId: servicioId,
    plantillaId: plantillaId,
    descripcion: descripcion ?? this.descripcion,
    cantidad: cantidad ?? this.cantidad,
    valorUnitario: valorUnitario ?? this.valorUnitario,
    descuento: descuento ?? this.descuento,
    motivoDescuento: motivoDescuento ?? this.motivoDescuento,
  );

  Map<String, Object?> aMapa() => compacto({
    'servicioId': servicioId,
    'descripcion': descripcion,
    'cantidad': cantidad,
    'valorUnitario': valorUnitario,
    'descuento': descuento > 0 ? descuento : null,
    'motivoDescuento': motivoDescuento.trim(),
    'plantillaId': plantillaId,
  });

  static ItemCobro desdeMapa(Map<String, Object?> m) => ItemCobro(
    servicioId: m.texto('servicioId'),
    plantillaId: m.textoONulo('plantillaId'),
    descripcion: m.texto('descripcion'),
    cantidad: m.entero('cantidad') ?? 1,
    valorUnitario: m.entero('valorUnitario') ?? 0,
    descuento: m.entero('descuento') ?? 0,
    motivoDescuento: m.texto('motivoDescuento'),
  );
}

/// Un insumo del inventario usado en la atención que se cobra: se descuenta
/// de su lote al registrar el cobro y vuelve al inventario si se anula. No
/// cambia el valor del cobro.
class InsumoCobro {
  const InsumoCobro({
    required this.insumoId,
    required this.loteId,
    required this.nombre,
    required this.lote,
    required this.unidad,
    required this.cantidad,
  });

  final String insumoId;
  final String loteId;
  final String nombre;

  /// Número del lote, para mostrarlo aunque el lote cambie.
  final String lote;
  final String unidad;
  final double cantidad;

  InsumoCobro conCantidad(double c) => InsumoCobro(
    insumoId: insumoId,
    loteId: loteId,
    nombre: nombre,
    lote: lote,
    unidad: unidad,
    cantidad: c,
  );

  Map<String, Object?> aMapa() => compacto({
    'insumoId': insumoId,
    'loteId': loteId,
    'nombre': nombre,
    'lote': lote,
    'unidad': unidad,
    'cantidad': cantidad,
  });

  static InsumoCobro desdeMapa(Map<String, Object?> m) => InsumoCobro(
    insumoId: m.texto('insumoId'),
    loteId: m.texto('loteId'),
    nombre: m.texto('nombre'),
    lote: m.texto('lote'),
    unidad: m.texto('unidad'),
    cantidad: m.decimal('cantidad') ?? 0,
  );
}

/// Lo que se cobra (una cuenta). Se paga en uno o varios recibos (abonos).
class Cobro {
  const Cobro({
    required this.id,
    required this.pacienteId,
    required this.fecha,
    required this.items,
    this.creditoId,
    this.credito = 0,
    this.citaId,
    this.insumos = const [],
    this.anulado = false,
    this.motivoAnulacion = '',
    this.anuladoEn,
  });

  static const coleccion = 'cobros';

  final String id;
  final String pacienteId;
  final DateTime fecha;
  final List<ItemCobro> items;

  /// Crédito de una valoración aplicado a este cobro.
  final String? creditoId;
  final int credito;
  final String? citaId;

  /// Insumos usados, descontados del inventario al registrar el cobro.
  final List<InsumoCobro> insumos;
  final bool anulado;
  final String motivoAnulacion;
  final DateTime? anuladoEn;

  int get bruto => items.fold(0, (s, i) => s + i.bruto);
  int get descuentos => items.fold(0, (s, i) => s + i.descuento);
  int get total => bruto - descuentos - credito;

  String get descripcion => items.map((i) => i.descripcion).join(' · ');

  Cobro anular(String motivo, DateTime fecha) => Cobro(
    id: id,
    pacienteId: pacienteId,
    fecha: this.fecha,
    items: items,
    creditoId: creditoId,
    credito: credito,
    citaId: citaId,
    insumos: insumos,
    anulado: true,
    motivoAnulacion: motivo,
    anuladoEn: fecha,
  );

  Map<String, Object?> aMapa() => compacto({
    'pacienteId': pacienteId,
    'fecha': fecha.toUtc().toIso8601String(),
    'items': [for (final i in items) i.aMapa()],
    'creditoId': creditoId,
    'credito': credito > 0 ? credito : null,
    'citaId': citaId,
    'insumos': insumos.isEmpty ? null : [for (final i in insumos) i.aMapa()],
    'anulado': anulado ? true : null,
    'motivoAnulacion': motivoAnulacion.trim(),
    'anuladoEn': anuladoEn?.toUtc().toIso8601String(),
  });

  static Cobro desdeMapa(String id, Map<String, Object?> m) => Cobro(
    id: id,
    pacienteId: m.texto('pacienteId'),
    fecha: DateTime.parse(m.texto('fecha')).toLocal(),
    items: [for (final i in m.listaMapas('items')) ItemCobro.desdeMapa(i)],
    creditoId: m.textoONulo('creditoId'),
    credito: m.entero('credito') ?? 0,
    citaId: m.textoONulo('citaId'),
    insumos: [
      for (final i in m.listaMapas('insumos')) InsumoCobro.desdeMapa(i),
    ],
    anulado: m.booleano('anulado'),
    motivoAnulacion: m.texto('motivoAnulacion'),
    anuladoEn: m['anuladoEn'] == null
        ? null
        : DateTime.parse(m.texto('anuladoEn')).toLocal(),
  );
}

/// Un medio de pago con su valor (y referencia de la transferencia).
class PagoRecibo {
  const PagoRecibo({
    required this.medio,
    required this.valor,
    this.referencia = '',
  });

  final MedioPago medio;
  final int valor;
  final String referencia;

  Map<String, Object?> aMapa() => compacto({
    'medio': medio.name,
    'valor': valor,
    'referencia': referencia.trim(),
  });

  static PagoRecibo desdeMapa(Map<String, Object?> m) => PagoRecibo(
    medio: MedioPago.values.byName(m.texto('medio')),
    valor: m.entero('valor') ?? 0,
    referencia: m.texto('referencia'),
  );
}

/// Recibo de caja (RC-): un pago de un cobro (pregunta 46). El número se
/// asigna al emitir, no se reutiliza ni se salta. Anular un recibo de un
/// día cerrado cuenta en el día en que se anula.
class Recibo {
  const Recibo({
    required this.id,
    required this.numero,
    required this.cobroId,
    required this.pacienteId,
    required this.fecha,
    required this.pagos,
    this.anulado = false,
    this.motivoAnulacion = '',
    this.anuladoEn,
    this.anuladoTrasCierre = false,
    this.tienePdf = false,
  });

  static const coleccion = 'recibos';
  static const tipoBinarioPdf = 'pdfrecibo';

  final String id;
  final String numero;
  final String cobroId;
  final String pacienteId;
  final DateTime fecha;
  final List<PagoRecibo> pagos;
  final bool anulado;
  final String motivoAnulacion;
  final DateTime? anuladoEn;

  /// Su día ya estaba cerrado cuando se anuló: resta en el día de la
  /// anulación, no en el suyo.
  final bool anuladoTrasCierre;
  final bool tienePdf;

  int get valor => pagos.fold(0, (s, p) => s + p.valor);

  Recibo anular(String motivo, DateTime fecha, {required bool trasCierre}) =>
      Recibo(
        id: id,
        numero: numero,
        cobroId: cobroId,
        pacienteId: pacienteId,
        fecha: this.fecha,
        pagos: pagos,
        anulado: true,
        motivoAnulacion: motivo,
        anuladoEn: fecha,
        anuladoTrasCierre: trasCierre,
        tienePdf: tienePdf,
      );

  Map<String, Object?> aMapa() => compacto({
    'numero': numero,
    'cobroId': cobroId,
    'pacienteId': pacienteId,
    'fecha': fecha.toUtc().toIso8601String(),
    'pagos': [for (final p in pagos) p.aMapa()],
    'anulado': anulado ? true : null,
    'motivoAnulacion': motivoAnulacion.trim(),
    'anuladoEn': anuladoEn?.toUtc().toIso8601String(),
    'anuladoTrasCierre': anuladoTrasCierre ? true : null,
    'tienePdf': tienePdf ? true : null,
  });

  static Recibo desdeMapa(String id, Map<String, Object?> m) => Recibo(
    id: id,
    numero: m.texto('numero'),
    cobroId: m.texto('cobroId'),
    pacienteId: m.texto('pacienteId'),
    fecha: DateTime.parse(m.texto('fecha')).toLocal(),
    pagos: [for (final p in m.listaMapas('pagos')) PagoRecibo.desdeMapa(p)],
    anulado: m.booleano('anulado'),
    motivoAnulacion: m.texto('motivoAnulacion'),
    anuladoEn: m['anuladoEn'] == null
        ? null
        : DateTime.parse(m.texto('anuladoEn')).toLocal(),
    anuladoTrasCierre: m.booleano('anuladoTrasCierre'),
    tienePdf: m.booleano('tienePdf'),
  );
}

/// Un uso de una sesión del paquete (sin recibo, pregunta 46).
class UsoPaquete {
  const UsoPaquete({required this.fecha, this.sesionId, this.anulado = false});

  final DateTime fecha;
  final String? sesionId;
  final bool anulado;

  Map<String, Object?> aMapa() => compacto({
    'fecha': fecha.toUtc().toIso8601String(),
    'sesionId': sesionId,
    'anulado': anulado ? true : null,
  });

  static UsoPaquete desdeMapa(Map<String, Object?> m) => UsoPaquete(
    fecha: DateTime.parse(m.texto('fecha')).toLocal(),
    sesionId: m.textoONulo('sesionId'),
    anulado: m.booleano('anulado'),
  );
}

/// Un paquete de sesiones comprado en un cobro (pregunta 45: una zona, sin
/// vencimiento).
class Paquete {
  const Paquete({
    required this.id,
    required this.pacienteId,
    required this.servicioId,
    required this.nombre,
    required this.sesiones,
    required this.cobroId,
    required this.creado,
    this.plantillaId,
    this.usos = const [],
    this.anulado = false,
  });

  static const coleccion = 'paquetes';

  final String id;
  final String pacienteId;
  final String servicioId;
  final String nombre;
  final int sesiones;
  final String cobroId;
  final DateTime creado;
  final String? plantillaId;
  final List<UsoPaquete> usos;
  final bool anulado;

  int get usadas => usos.where((u) => !u.anulado).length;
  int get pendientes => sesiones - usadas;
  bool get agotado => pendientes <= 0;
  bool get activo => !anulado && !agotado;

  Paquete copyWith({List<UsoPaquete>? usos, bool? anulado}) => Paquete(
    id: id,
    pacienteId: pacienteId,
    servicioId: servicioId,
    nombre: nombre,
    sesiones: sesiones,
    cobroId: cobroId,
    creado: creado,
    plantillaId: plantillaId,
    usos: usos ?? this.usos,
    anulado: anulado ?? this.anulado,
  );

  Map<String, Object?> aMapa() => compacto({
    'pacienteId': pacienteId,
    'servicioId': servicioId,
    'nombre': nombre,
    'sesiones': sesiones,
    'cobroId': cobroId,
    'creado': creado.toUtc().toIso8601String(),
    'plantillaId': plantillaId,
    'usos': usos.isEmpty ? null : [for (final u in usos) u.aMapa()],
    'anulado': anulado ? true : null,
  });

  static Paquete desdeMapa(String id, Map<String, Object?> m) => Paquete(
    id: id,
    pacienteId: m.texto('pacienteId'),
    servicioId: m.texto('servicioId'),
    nombre: m.texto('nombre'),
    sesiones: m.entero('sesiones') ?? 0,
    cobroId: m.texto('cobroId'),
    creado: DateTime.parse(m.texto('creado')).toLocal(),
    plantillaId: m.textoONulo('plantillaId'),
    usos: [for (final u in m.listaMapas('usos')) UsoPaquete.desdeMapa(u)],
    anulado: m.booleano('anulado'),
  );
}

/// Crédito de una valoración abonable (pregunta 44): vale 30 días y se
/// descuenta del primer pago del tratamiento.
class Credito {
  const Credito({
    required this.id,
    required this.pacienteId,
    required this.valor,
    required this.cobroOrigenId,
    required this.vence,
    this.aplicadoEn,
    this.anulado = false,
  });

  static const coleccion = 'creditos';
  static const diasVigencia = 30;

  final String id;
  final String pacienteId;
  final int valor;
  final String cobroOrigenId;

  /// Último día en que se puede aplicar.
  final DateTime vence;

  /// El cobro donde se aplicó.
  final String? aplicadoEn;
  final bool anulado;

  bool disponible(DateTime ahora) =>
      !anulado &&
      aplicadoEn == null &&
      !DateTime(ahora.year, ahora.month, ahora.day).isAfter(vence);

  Credito copyWith({Object? aplicadoEn = sin, bool? anulado}) => Credito(
    id: id,
    pacienteId: pacienteId,
    valor: valor,
    cobroOrigenId: cobroOrigenId,
    vence: vence,
    aplicadoEn: cambio<String>(aplicadoEn, this.aplicadoEn),
    anulado: anulado ?? this.anulado,
  );

  Map<String, Object?> aMapa() => compacto({
    'pacienteId': pacienteId,
    'valor': valor,
    'cobroOrigenId': cobroOrigenId,
    'vence': fechaIso(vence),
    'aplicadoEn': aplicadoEn,
    'anulado': anulado ? true : null,
  });

  static Credito desdeMapa(String id, Map<String, Object?> m) => Credito(
    id: id,
    pacienteId: m.texto('pacienteId'),
    valor: m.entero('valor') ?? 0,
    cobroOrigenId: m.texto('cobroOrigenId'),
    vence: m.fecha('vence')!,
    aplicadoEn: m.textoONulo('aplicadoEn'),
    anulado: m.booleano('anulado'),
  );
}

/// El cierre de un día (pregunta 46): no se reabre ni se modifica.
class CierreDiario {
  const CierreDiario({
    required this.dia,
    required this.totales,
    required this.efectivoContado,
    required this.cerradoEn,
    this.notas = '',
  });

  static const coleccion = 'cierres';

  final DateTime dia;
  final Map<MedioPago, int> totales;
  final int efectivoContado;
  final DateTime cerradoEn;
  final String notas;

  int get total => totales.values.fold(0, (s, v) => s + v);
  int get efectivoEsperado => totales[MedioPago.efectivo] ?? 0;
  int get diferencia => efectivoContado - efectivoEsperado;

  static String clave(DateTime d) => fechaIso(d);

  Map<String, Object?> aMapa() => compacto({
    'dia': fechaIso(dia),
    'totales': {for (final e in totales.entries) e.key.name: e.value},
    'efectivoContado': efectivoContado,
    'cerradoEn': cerradoEn.toUtc().toIso8601String(),
    'notas': notas.trim(),
  });

  static CierreDiario desdeMapa(Map<String, Object?> m) => CierreDiario(
    dia: m.fecha('dia')!,
    totales: {
      for (final e in m.mapa('totales').entries)
        MedioPago.values.byName(e.key): (e.value as num).toInt(),
    },
    efectivoContado: m.entero('efectivoContado') ?? 0,
    cerradoEn: DateTime.parse(m.texto('cerradoEn')).toLocal(),
    notas: m.texto('notas'),
  );
}
