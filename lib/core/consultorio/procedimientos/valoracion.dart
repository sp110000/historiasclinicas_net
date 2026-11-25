import '../../models/mapa.dart';
import 'plantilla_procedimiento.dart';

enum ResultadoValoracion {
  apto('Apto'),
  noApto('No apto'),
  diferir('Diferir');

  const ResultadoValoracion(this.etiqueta);

  final String etiqueta;

  /// Qué tan restrictivo es (apto < diferir < no apto).
  int get rigor => switch (this) {
    apto => 0,
    diferir => 1,
    noApto => 2,
  };
}

enum Elasticidad {
  buena('Buena'),
  regular('Regular'),
  mala('Mala');

  const Elasticidad(this.etiqueta);

  final String etiqueta;
}

class ZonaValorada {
  const ZonaValorada({
    required this.zona,
    this.pinzable = true,
    this.pinzableCm,
    this.elasticidad = Elasticidad.buena,
    this.flacidez = 0,
  });

  final String zona;
  final bool pinzable;
  final double? pinzableCm;
  final Elasticidad elasticidad;

  /// De 0 a 3.
  final int flacidez;

  ZonaValorada copyWith({
    bool? pinzable,
    Object? pinzableCm = sin,
    Elasticidad? elasticidad,
    int? flacidez,
  }) => ZonaValorada(
    zona: zona,
    pinzable: pinzable ?? this.pinzable,
    pinzableCm: cambio(pinzableCm, this.pinzableCm),
    elasticidad: elasticidad ?? this.elasticidad,
    flacidez: flacidez ?? this.flacidez,
  );

  Map<String, Object?> aMapa() => compacto({
    'zona': zona,
    'pinzable': pinzable,
    'pinzableCm': pinzableCm,
    'elasticidad': elasticidad.name,
    'flacidez': flacidez,
  });

  static ZonaValorada desdeMapa(Map<String, Object?> m) => ZonaValorada(
    zona: m.texto('zona'),
    pinzable: m.booleano('pinzable', porDefecto: true),
    pinzableCm: m.decimal('pinzableCm'),
    elasticidad: Elasticidad.values.byName(m.texto('elasticidad')),
    flacidez: m.entero('flacidez') ?? 0,
  );
}

/// Respuesta a un ítem (contraindicación o precaución), con su texto y
/// su efecto tal como estaban en la plantilla.
class RespuestaValoracion {
  const RespuestaValoracion({required this.item, this.si, this.nota = ''});

  final ItemValoracion item;

  /// `null` mientras no se responde.
  final bool? si;
  final String nota;

  Map<String, Object?> aMapa() =>
      compacto({...item.aMapa(), 'si': si, 'nota': nota});

  static RespuestaValoracion desdeMapa(Map<String, Object?> m) =>
      RespuestaValoracion(
        item: ItemValoracion.desdeMapa(m),
        si: m['si'] as bool?,
        nota: m.texto('nota'),
      );
}

class TamizajeAplicado {
  const TamizajeAplicado({required this.instrumento, required this.respuestas});

  final InstrumentoTamizaje instrumento;

  /// Una por ítem; `null` sin responder.
  final List<int?> respuestas;

  bool get completo =>
      respuestas.length == instrumento.numeroItems &&
      respuestas.every((r) => r != null);

  int get puntaje => respuestas.fold(0, (a, r) => a + (r ?? 0));

  bool get positivo => completo && puntaje >= instrumento.corte;

  String get texto =>
      '${instrumento.nombre.split(' ').first} '
      '$puntaje/${instrumento.numeroItems * instrumento.maximoPorItem} · '
      '${!completo
          ? 'incompleto'
          : positivo
          ? 'positivo'
          : 'negativo'}';

  Map<String, Object?> aMapa() => {
    'instrumento': instrumento.aMapa(),
    'respuestas': respuestas,
  };

  static TamizajeAplicado desdeMapa(Map<String, Object?> m) => TamizajeAplicado(
    instrumento: InstrumentoTamizaje.desdeMapa(m.mapa('instrumento')),
    respuestas: [
      for (final r in (m['respuestas'] as List?) ?? const []) r as int?,
    ],
  );
}

/// Valoración para un procedimiento estético (5.3). Se sella como
/// evolución en la historia; sellada no se edita.
class Valoracion {
  const Valoracion({
    required this.id,
    required this.pacienteId,
    required this.plantillaId,
    required this.version,
    required this.fecha,
    required this.creado,
    this.edad,
    this.peso,
    this.talla,
    this.zonas = const [],
    this.expectativasRealistas,
    this.notaExpectativas = '',
    this.respuestas = const [],
    this.tamizajes = const [],
    this.resultado,
    this.motivo = '',
    this.recomendacion = '',
    this.vigenteHasta,
    this.historiaId,
    this.revision,
    this.huellaEvolucion,
  });

  static const coleccion = 'valoraciones';

  final String id;
  final String pacienteId;
  final String plantillaId;
  final int version;
  final DateTime fecha;
  final DateTime creado;
  final int? edad;
  final double? peso;
  final double? talla;
  final List<ZonaValorada> zonas;
  final bool? expectativasRealistas;
  final String notaExpectativas;
  final List<RespuestaValoracion> respuestas;
  final List<TamizajeAplicado> tamizajes;
  final ResultadoValoracion? resultado;
  final String motivo;
  final String recomendacion;

  /// Solo en «apto»: hasta cuándo vale (pregunta 29).
  final DateTime? vigenteHasta;

  /// Dónde quedó sellada.
  final String? historiaId;
  final int? revision;
  final String? huellaEvolucion;

  bool get sellada => huellaEvolucion != null;

  double? get imc => peso == null || talla == null || talla! <= 0
      ? null
      : peso! / ((talla! / 100) * (talla! / 100));

  Valoracion copyWith({
    String? id,
    DateTime? fecha,
    Object? edad = sin,
    Object? peso = sin,
    Object? talla = sin,
    List<ZonaValorada>? zonas,
    Object? expectativasRealistas = sin,
    String? notaExpectativas,
    List<RespuestaValoracion>? respuestas,
    List<TamizajeAplicado>? tamizajes,
    Object? resultado = sin,
    String? motivo,
    String? recomendacion,
    Object? vigenteHasta = sin,
    Object? historiaId = sin,
    Object? revision = sin,
    Object? huellaEvolucion = sin,
  }) => Valoracion(
    id: id ?? this.id,
    pacienteId: pacienteId,
    plantillaId: plantillaId,
    version: version,
    fecha: fecha ?? this.fecha,
    creado: creado,
    edad: cambio(edad, this.edad),
    peso: cambio(peso, this.peso),
    talla: cambio(talla, this.talla),
    zonas: zonas ?? this.zonas,
    expectativasRealistas: cambio(
      expectativasRealistas,
      this.expectativasRealistas,
    ),
    notaExpectativas: notaExpectativas ?? this.notaExpectativas,
    respuestas: respuestas ?? this.respuestas,
    tamizajes: tamizajes ?? this.tamizajes,
    resultado: cambio(resultado, this.resultado),
    motivo: motivo ?? this.motivo,
    recomendacion: recomendacion ?? this.recomendacion,
    vigenteHasta: cambio(vigenteHasta, this.vigenteHasta),
    historiaId: cambio(historiaId, this.historiaId),
    revision: cambio(revision, this.revision),
    huellaEvolucion: cambio(huellaEvolucion, this.huellaEvolucion),
  );

  Map<String, Object?> aMapa() => compacto({
    'pacienteId': pacienteId,
    'plantillaId': plantillaId,
    'version': version,
    'fecha': fechaHoraIso(fecha),
    'creado': creado.toUtc().toIso8601String(),
    'edad': edad,
    'peso': peso,
    'talla': talla,
    'zonas': [for (final z in zonas) z.aMapa()],
    'expectativasRealistas': expectativasRealistas,
    'notaExpectativas': notaExpectativas,
    'respuestas': [for (final r in respuestas) r.aMapa()],
    'tamizajes': [for (final t in tamizajes) t.aMapa()],
    'resultado': resultado?.name,
    'motivo': motivo,
    'recomendacion': recomendacion,
    'vigenteHasta': vigenteHasta == null ? null : fechaIso(vigenteHasta!),
    'historiaId': historiaId,
    'revision': revision,
    'huellaEvolucion': huellaEvolucion,
  });

  static Valoracion desdeMapa(String id, Map<String, Object?> m) => Valoracion(
    id: id,
    pacienteId: m.texto('pacienteId'),
    plantillaId: m.texto('plantillaId'),
    version: m.entero('version') ?? 1,
    fecha: m.fecha('fecha')!,
    creado: DateTime.parse(m.texto('creado')).toLocal(),
    edad: m.entero('edad'),
    peso: m.decimal('peso'),
    talla: m.decimal('talla'),
    zonas: [for (final z in m.listaMapas('zonas')) ZonaValorada.desdeMapa(z)],
    expectativasRealistas: m['expectativasRealistas'] as bool?,
    notaExpectativas: m.texto('notaExpectativas'),
    respuestas: [
      for (final r in m.listaMapas('respuestas'))
        RespuestaValoracion.desdeMapa(r),
    ],
    tamizajes: [
      for (final t in m.listaMapas('tamizajes')) TamizajeAplicado.desdeMapa(t),
    ],
    resultado: m['resultado'] == null
        ? null
        : ResultadoValoracion.values.byName(m.texto('resultado')),
    motivo: m.texto('motivo'),
    recomendacion: m.texto('recomendacion'),
    vigenteHasta: m.fecha('vigenteHasta'),
    historiaId: m.textoONulo('historiaId'),
    revision: m.entero('revision'),
    huellaEvolucion: m.textoONulo('huellaEvolucion'),
  );
}
