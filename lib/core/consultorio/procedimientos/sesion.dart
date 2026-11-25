import '../../models/mapa.dart';
import '../../utils/numeros.dart';

/// Lote usado en la sesión: escrito a mano o elegido del inventario (5.7),
/// con las unidades que se descuentan al sellar.
class LoteSesion {
  const LoteSesion({this.lote = '', this.vence, this.loteId, this.unidades});

  final String lote;
  final DateTime? vence;

  /// El lote del inventario, si se eligió de ahí.
  final String? loteId;

  /// Unidades de presentación a descontar (en el anestésico, `null` las
  /// calcula del volumen y del contenido de cada unidad).
  final double? unidades;

  bool get completo => lote.trim().isNotEmpty && vence != null;
  bool get delInventario => loteId != null;

  /// Vencido si la fecha de vencimiento ya pasó (el día del vencimiento
  /// todavía sirve).
  bool vencidoEn(DateTime dia) =>
      vence != null && DateTime(dia.year, dia.month, dia.day).isAfter(vence!);

  LoteSesion conUnidades(double? u) =>
      LoteSesion(lote: lote, vence: vence, loteId: loteId, unidades: u);

  Map<String, Object?> aMapa() => compacto({
    'lote': lote.trim(),
    'vence': vence == null ? null : fechaIso(vence!),
    'loteId': loteId,
    'unidades': unidades,
  });

  static LoteSesion desdeMapa(Map<String, Object?> m) => LoteSesion(
    lote: m.texto('lote'),
    vence: m.fecha('vence'),
    loteId: m.textoONulo('loteId'),
    unidades: m.decimal('unidades'),
  );
}

/// Un componente de la solución con su lote.
class ComponenteSesion {
  const ComponenteSesion({
    required this.nombre,
    this.lote = const LoteSesion(),
  });

  final String nombre;
  final LoteSesion lote;

  Map<String, Object?> aMapa() => {'nombre': nombre, ...lote.aMapa()};

  static ComponenteSesion desdeMapa(Map<String, Object?> m) => ComponenteSesion(
    nombre: m.texto('nombre'),
    lote: LoteSesion.desdeMapa(m),
  );
}

class ZonaSesion {
  const ZonaSesion({required this.zona, this.volumenMl});

  final String zona;
  final double? volumenMl;

  Map<String, Object?> aMapa() =>
      compacto({'zona': zona, 'volumenMl': volumenMl});

  static ZonaSesion desdeMapa(Map<String, Object?> m) =>
      ZonaSesion(zona: m.texto('zona'), volumenMl: m.decimal('volumenMl'));
}

/// Anestésico usado, con la dosis calculada (pregunta 32).
class AnestesicoSesion {
  const AnestesicoSesion({
    required this.nombre,
    required this.concentracionMgMl,
    required this.maximoMgKg,
    this.volumenMl,
    this.lote = const LoteSesion(),
  });

  final String nombre;
  final double concentracionMgMl;
  final double maximoMgKg;
  final double? volumenMl;
  final LoteSesion lote;

  double? get mg => volumenMl == null ? null : concentracionMgMl * volumenMl!;

  double? mgKg(double? pesoKg) =>
      mg == null || pesoKg == null || pesoKg <= 0 ? null : mg! / pesoKg;

  /// Fracción del máximo del protocolo (1 = 100 %).
  double? fraccion(double? pesoKg) {
    final d = mgKg(pesoKg);
    return d == null ? null : d / maximoMgKg;
  }

  AnestesicoSesion copyWith({Object? volumenMl = sin, LoteSesion? lote}) =>
      AnestesicoSesion(
        nombre: nombre,
        concentracionMgMl: concentracionMgMl,
        maximoMgKg: maximoMgKg,
        volumenMl: cambio(volumenMl, this.volumenMl),
        lote: lote ?? this.lote,
      );

  Map<String, Object?> aMapa() => compacto({
    'nombre': nombre,
    'concentracionMgMl': concentracionMgMl,
    'maximoMgKg': maximoMgKg,
    'volumenMl': volumenMl,
    ...lote.aMapa(),
  });

  static AnestesicoSesion desdeMapa(Map<String, Object?> m) => AnestesicoSesion(
    nombre: m.texto('nombre'),
    concentracionMgMl: m.decimal('concentracionMgMl') ?? 0,
    maximoMgKg: m.decimal('maximoMgKg') ?? 0,
    volumenMl: m.decimal('volumenMl'),
    lote: LoteSesion.desdeMapa(m),
  );
}

class InsumoSesion {
  const InsumoSesion({
    required this.nombre,
    this.cantidad = 1,
    this.lote = const LoteSesion(),
  });

  final String nombre;
  final double cantidad;
  final LoteSesion lote;

  Map<String, Object?> aMapa() => {
    'nombre': nombre,
    'cantidad': cantidad,
    ...lote.aMapa(),
  };

  static InsumoSesion desdeMapa(Map<String, Object?> m) => InsumoSesion(
    nombre: m.texto('nombre'),
    cantidad: m.decimal('cantidad') ?? 1,
    lote: LoteSesion.desdeMapa(m),
  );
}

class EquipoSesion {
  const EquipoSesion({
    this.nombre = '',
    this.serie = '',
    this.registroInvima = '',
    this.parametros = '',
  });

  final String nombre;
  final String serie;
  final String registroInvima;
  final String parametros;

  bool get vacio =>
      nombre.trim().isEmpty &&
      serie.trim().isEmpty &&
      registroInvima.trim().isEmpty &&
      parametros.trim().isEmpty;

  Map<String, Object?> aMapa() => compacto({
    'nombre': nombre.trim(),
    'serie': serie.trim(),
    'registroInvima': registroInvima.trim(),
    'parametros': parametros.trim(),
  });

  static EquipoSesion desdeMapa(Map<String, Object?> m) => EquipoSesion(
    nombre: m.texto('nombre'),
    serie: m.texto('serie'),
    registroInvima: m.texto('registroInvima'),
    parametros: m.texto('parametros'),
  );
}

/// Sesión de un procedimiento (5.3). Se guarda solo al sellarla como
/// evolución en la historia (pregunta 35).
class Sesion {
  const Sesion({
    required this.id,
    required this.pacienteId,
    required this.plantillaId,
    required this.version,
    required this.fecha,
    required this.numero,
    required this.sesionesPlan,
    this.valoracionId,
    this.consentimientoId,
    this.consentimientoNumero = '',
    this.verificacion = const {},
    this.zonas = const [],
    this.componentes = const [],
    this.anestesico,
    this.pesoKg,
    this.fechaPeso,
    this.equipo = const EquipoSesion(),
    this.insumos = const [],
    this.duracionMin,
    this.eventosAdversos = 'Ninguno',
    this.indicaciones = '',
    this.control,
    this.poliza = '',
    this.avisos = const [],
    this.historiaId,
    this.revision,
    this.huellaEvolucion,
  });

  static const coleccion = 'sesiones';

  final String id;
  final String pacienteId;
  final String plantillaId;
  final int version;
  final DateTime fecha;

  /// Número de la sesión en el plan del consentimiento y total del plan.
  final int numero;
  final int sesionesPlan;
  final String? valoracionId;
  final String? consentimientoId;
  final String consentimientoNumero;

  /// Ítem de la lista de verificación → marcado (pregunta 33).
  final Map<String, bool> verificacion;
  final List<ZonaSesion> zonas;
  final List<ComponenteSesion> componentes;
  final AnestesicoSesion? anestesico;

  /// Peso con que se calculó la dosis y de cuándo es.
  final double? pesoKg;
  final DateTime? fechaPeso;
  final EquipoSesion equipo;
  final List<InsumoSesion> insumos;
  final int? duracionMin;
  final String eventosAdversos;
  final String indicaciones;
  final DateTime? control;

  /// Póliza de complicaciones copiada de la configuración (pregunta 34).
  final String poliza;

  /// Avisos que se sellaron con la sesión (p. ej. sin certificación).
  final List<String> avisos;
  final String? historiaId;
  final int? revision;
  final String? huellaEvolucion;

  bool get sellada => huellaEvolucion != null;

  double get volumenTotalMl => zonas.fold(0, (a, z) => a + (z.volumenMl ?? 0));

  String get titulo => 'Sesión $numero de $sesionesPlan';

  Sesion copyWith({
    String? id,
    DateTime? fecha,
    Map<String, bool>? verificacion,
    List<ZonaSesion>? zonas,
    List<ComponenteSesion>? componentes,
    Object? anestesico = sin,
    Object? pesoKg = sin,
    Object? fechaPeso = sin,
    EquipoSesion? equipo,
    List<InsumoSesion>? insumos,
    Object? duracionMin = sin,
    String? eventosAdversos,
    String? indicaciones,
    Object? control = sin,
    List<String>? avisos,
    Object? historiaId = sin,
    Object? revision = sin,
    Object? huellaEvolucion = sin,
  }) => Sesion(
    id: id ?? this.id,
    pacienteId: pacienteId,
    plantillaId: plantillaId,
    version: version,
    fecha: fecha ?? this.fecha,
    numero: numero,
    sesionesPlan: sesionesPlan,
    valoracionId: valoracionId,
    consentimientoId: consentimientoId,
    consentimientoNumero: consentimientoNumero,
    verificacion: verificacion ?? this.verificacion,
    zonas: zonas ?? this.zonas,
    componentes: componentes ?? this.componentes,
    anestesico: cambio(anestesico, this.anestesico),
    pesoKg: cambio(pesoKg, this.pesoKg),
    fechaPeso: cambio(fechaPeso, this.fechaPeso),
    equipo: equipo ?? this.equipo,
    insumos: insumos ?? this.insumos,
    duracionMin: cambio(duracionMin, this.duracionMin),
    eventosAdversos: eventosAdversos ?? this.eventosAdversos,
    indicaciones: indicaciones ?? this.indicaciones,
    control: cambio(control, this.control),
    poliza: poliza,
    avisos: avisos ?? this.avisos,
    historiaId: cambio(historiaId, this.historiaId),
    revision: cambio(revision, this.revision),
    huellaEvolucion: cambio(huellaEvolucion, this.huellaEvolucion),
  );

  Map<String, Object?> aMapa() => compacto({
    'pacienteId': pacienteId,
    'plantillaId': plantillaId,
    'version': version,
    'fecha': fechaHoraIso(fecha),
    'numero': numero,
    'sesionesPlan': sesionesPlan,
    'valoracionId': valoracionId,
    'consentimientoId': consentimientoId,
    'consentimientoNumero': consentimientoNumero,
    'verificacion': verificacion,
    'zonas': [for (final z in zonas) z.aMapa()],
    'componentes': [for (final c in componentes) c.aMapa()],
    'anestesico': anestesico?.aMapa(),
    'pesoKg': pesoKg,
    'fechaPeso': fechaPeso == null ? null : fechaIso(fechaPeso!),
    'equipo': equipo.vacio ? null : equipo.aMapa(),
    'insumos': [for (final i in insumos) i.aMapa()],
    'duracionMin': duracionMin,
    'eventosAdversos': eventosAdversos,
    'indicaciones': indicaciones,
    'control': control == null ? null : fechaIso(control!),
    'poliza': poliza,
    'avisos': avisos,
    'historiaId': historiaId,
    'revision': revision,
    'huellaEvolucion': huellaEvolucion,
  });

  static Sesion desdeMapa(String id, Map<String, Object?> m) => Sesion(
    id: id,
    pacienteId: m.texto('pacienteId'),
    plantillaId: m.texto('plantillaId'),
    version: m.entero('version') ?? 1,
    fecha: m.fecha('fecha')!,
    numero: m.entero('numero') ?? 1,
    sesionesPlan: m.entero('sesionesPlan') ?? 1,
    valoracionId: m.textoONulo('valoracionId'),
    consentimientoId: m.textoONulo('consentimientoId'),
    consentimientoNumero: m.texto('consentimientoNumero'),
    verificacion: {
      for (final e in m.mapa('verificacion').entries) e.key: e.value == true,
    },
    zonas: [for (final z in m.listaMapas('zonas')) ZonaSesion.desdeMapa(z)],
    componentes: [
      for (final c in m.listaMapas('componentes'))
        ComponenteSesion.desdeMapa(c),
    ],
    anestesico: m['anestesico'] == null
        ? null
        : AnestesicoSesion.desdeMapa(m.mapa('anestesico')),
    pesoKg: m.decimal('pesoKg'),
    fechaPeso: m.fecha('fechaPeso'),
    equipo: EquipoSesion.desdeMapa(m.mapa('equipo')),
    insumos: [
      for (final i in m.listaMapas('insumos')) InsumoSesion.desdeMapa(i),
    ],
    duracionMin: m.entero('duracionMin'),
    eventosAdversos: m.texto('eventosAdversos'),
    indicaciones: m.texto('indicaciones'),
    control: m.fecha('control'),
    poliza: m.texto('poliza'),
    avisos: m.listaTextos('avisos'),
    historiaId: m.textoONulo('historiaId'),
    revision: m.entero('revision'),
    huellaEvolucion: m.textoONulo('huellaEvolucion'),
  );
}

/// «200 mg · 2,9 mg/kg».
String textoDosis(AnestesicoSesion a, double? pesoKg) {
  final mg = a.mg;
  final mgKg = a.mgKg(pesoKg);
  return [
    if (mg != null) '${formatoNumero(mg, decimales: mg % 1 == 0 ? 0 : 1)} mg',
    if (mgKg != null) '${formatoNumero(mgKg, decimales: 1)} mg/kg',
  ].join(' · ');
}
