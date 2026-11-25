import '../../models/mapa.dart';

/// Categoría de un insumo (pregunta 48). La sustancia modelante queda
/// prevista para cuando se agreguen rellenos (Ley 2316 de 2023, VERIFICAR).
enum CategoriaInsumo {
  medicamento('Medicamento'),
  dispositivo('Dispositivo médico'),
  insumo('Insumo'),
  sustanciaModelante('Sustancia modelante');

  const CategoriaInsumo(this.etiqueta);

  final String etiqueta;
}

/// Un insumo del inventario. Las existencias se llevan en su unidad de
/// presentación (ampolla, frasco, unidad).
class Insumo {
  const Insumo({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.unidad,
    required this.creado,
    this.presentacion = '',
    this.contenidoMl,
    this.concentracionMgMl,
    this.registroInvima = '',
    this.inyectable = false,
    this.stockMinimo = 0,
    this.activo = true,
  });

  static const coleccion = 'insumos';

  final String id;
  final String nombre;
  final CategoriaInsumo categoria;

  /// «ampolla», «frasco», «unidad».
  final String unidad;

  /// «Ampolla de 5 mL».
  final String presentacion;

  /// mL por unidad: con el volumen usado da las unidades a descontar.
  final double? contenidoMl;

  /// mg/mL, para calcular dosis.
  final double? concentracionMgMl;
  final String registroInvima;
  final bool inyectable;
  final double stockMinimo;
  final bool activo;
  final DateTime creado;

  bool get sinRegistro => registroInvima.trim().isEmpty;

  Insumo copyWith({
    String? nombre,
    CategoriaInsumo? categoria,
    String? unidad,
    String? presentacion,
    Object? contenidoMl = sin,
    Object? concentracionMgMl = sin,
    String? registroInvima,
    bool? inyectable,
    double? stockMinimo,
    bool? activo,
  }) => Insumo(
    id: id,
    nombre: nombre ?? this.nombre,
    categoria: categoria ?? this.categoria,
    unidad: unidad ?? this.unidad,
    presentacion: presentacion ?? this.presentacion,
    contenidoMl: cambio(contenidoMl, this.contenidoMl),
    concentracionMgMl: cambio(concentracionMgMl, this.concentracionMgMl),
    registroInvima: registroInvima ?? this.registroInvima,
    inyectable: inyectable ?? this.inyectable,
    stockMinimo: stockMinimo ?? this.stockMinimo,
    activo: activo ?? this.activo,
    creado: creado,
  );

  Map<String, Object?> aMapa() => compacto({
    'nombre': nombre.trim(),
    'categoria': categoria.name,
    'unidad': unidad.trim(),
    'presentacion': presentacion.trim(),
    'contenidoMl': contenidoMl,
    'concentracionMgMl': concentracionMgMl,
    'registroInvima': registroInvima.trim(),
    'inyectable': inyectable ? true : null,
    'stockMinimo': stockMinimo,
    'activo': activo ? null : false,
    'creado': fechaHoraIso(creado),
  });

  static Insumo desdeMapa(String id, Map<String, Object?> m) => Insumo(
    id: id,
    nombre: m.texto('nombre'),
    categoria: CategoriaInsumo.values.byName(m.texto('categoria')),
    unidad: m.texto('unidad'),
    presentacion: m.texto('presentacion'),
    contenidoMl: m.decimal('contenidoMl'),
    concentracionMgMl: m.decimal('concentracionMgMl'),
    registroInvima: m.texto('registroInvima'),
    inyectable: m.booleano('inyectable'),
    stockMinimo: m.decimal('stockMinimo') ?? 0,
    activo: m.booleano('activo', porDefecto: true),
    creado: m.fecha('creado')!,
  );
}

/// Un lote de un insumo. Su existencia es la suma de sus movimientos.
class Lote {
  const Lote({
    required this.id,
    required this.insumoId,
    required this.numero,
    required this.vence,
    required this.ingreso,
    this.proveedor = '',
    this.factura = '',
  });

  static const coleccion = 'lotes';

  final String id;
  final String insumoId;
  final String numero;
  final DateTime vence;
  final DateTime ingreso;
  final String proveedor;
  final String factura;

  /// El día del vencimiento todavía sirve.
  bool vencidoEn(DateTime dia) =>
      DateTime(dia.year, dia.month, dia.day).isAfter(vence);

  Map<String, Object?> aMapa() => compacto({
    'insumoId': insumoId,
    'numero': numero.trim(),
    'vence': fechaIso(vence),
    'ingreso': fechaHoraIso(ingreso),
    'proveedor': proveedor.trim(),
    'factura': factura.trim(),
  });

  static Lote desdeMapa(String id, Map<String, Object?> m) => Lote(
    id: id,
    insumoId: m.texto('insumoId'),
    numero: m.texto('numero'),
    vence: m.fecha('vence')!,
    ingreso: m.fecha('ingreso')!,
    proveedor: m.texto('proveedor'),
    factura: m.texto('factura'),
  );
}

enum TipoMovimiento {
  entrada('Entrada'),
  salida('Salida'),
  ajuste('Ajuste'),
  baja('Baja');

  const TipoMovimiento(this.etiqueta);

  final String etiqueta;
}

/// Un movimiento de un lote. Solo se agregan, nunca se editan. La cantidad
/// lleva el signo: las entradas suman; las salidas y las bajas restan.
class Movimiento {
  const Movimiento({
    required this.id,
    required this.loteId,
    required this.insumoId,
    required this.tipo,
    required this.cantidad,
    required this.fecha,
    this.sesionId,
    this.cobroId,
    this.motivo = '',
  });

  static const coleccion = 'movimientos';

  final String id;
  final String loteId;
  final String insumoId;
  final TipoMovimiento tipo;
  final double cantidad;
  final DateTime fecha;

  /// La sesión que lo descontó.
  final String? sesionId;

  /// El cobro que lo descontó (o que, al anularse, lo devolvió).
  final String? cobroId;
  final String motivo;

  Map<String, Object?> aMapa() => compacto({
    'loteId': loteId,
    'insumoId': insumoId,
    'tipo': tipo.name,
    'cantidad': cantidad,
    'fecha': fechaHoraIso(fecha),
    'sesionId': sesionId,
    'cobroId': cobroId,
    'motivo': motivo.trim(),
  });

  static Movimiento desdeMapa(String id, Map<String, Object?> m) => Movimiento(
    id: id,
    loteId: m.texto('loteId'),
    insumoId: m.texto('insumoId'),
    tipo: TipoMovimiento.values.byName(m.texto('tipo')),
    cantidad: m.decimal('cantidad') ?? 0,
    fecha: m.fecha('fecha')!,
    sesionId: m.textoONulo('sesionId'),
    cobroId: m.textoONulo('cobroId'),
    motivo: m.texto('motivo'),
  );
}
