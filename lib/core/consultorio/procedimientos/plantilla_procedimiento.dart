import '../../models/mapa.dart';

/// Qué hace un «sí» en un ítem de la valoración (pregunta 28).
enum EfectoItem {
  noApto('No apto'),
  diferir('Diferir'),
  precaucion('Precaución (pide nota)');

  const EfectoItem(this.etiqueta);

  final String etiqueta;
}

class ItemValoracion {
  const ItemValoracion(this.texto, this.efecto);

  final String texto;
  final EfectoItem efecto;

  Map<String, Object?> aMapa() => {'texto': texto, 'efecto': efecto.name};

  static ItemValoracion desdeMapa(Map<String, Object?> m) => ItemValoracion(
    m.texto('texto'),
    EfectoItem.values.byName(m.texto('efecto')),
  );
}

/// Estructura de un instrumento de tamizaje (pregunta 30). Sin licencia
/// confirmada no trae el texto de los ítems: lo carga el médico.
class InstrumentoTamizaje {
  const InstrumentoTamizaje({
    required this.id,
    required this.nombre,
    required this.numeroItems,
    required this.maximoPorItem,
    required this.corte,
    this.referencia = '',
    this.textos = const [],
  });

  final String id;
  final String nombre;
  final int numeroItems;

  /// 1: sí/no; 3: escala de 0 a 3.
  final int maximoPorItem;

  /// Positivo si el puntaje es mayor o igual (VERIFICAR).
  final int corte;
  final String referencia;

  /// Texto de cada ítem; vacío si no se ha cargado.
  final List<String> textos;

  String textoItem(int i) {
    final t = i < textos.length ? textos[i].trim() : '';
    return t.isEmpty ? 'Ítem ${i + 1} (texto sin cargar)' : t;
  }

  bool get textosCargados =>
      textos.length >= numeroItems &&
      textos.take(numeroItems).every((t) => t.trim().isNotEmpty);

  InstrumentoTamizaje conTextos(List<String> t) => InstrumentoTamizaje(
    id: id,
    nombre: nombre,
    numeroItems: numeroItems,
    maximoPorItem: maximoPorItem,
    corte: corte,
    referencia: referencia,
    textos: t,
  );

  Map<String, Object?> aMapa() => compacto({
    'id': id,
    'nombre': nombre,
    'numeroItems': numeroItems,
    'maximoPorItem': maximoPorItem,
    'corte': corte,
    'referencia': referencia,
    if (textos.any((t) => t.trim().isNotEmpty)) 'textos': textos,
  });

  static InstrumentoTamizaje desdeMapa(Map<String, Object?> m) =>
      InstrumentoTamizaje(
        id: m.texto('id'),
        nombre: m.texto('nombre'),
        numeroItems: m.entero('numeroItems') ?? 0,
        maximoPorItem: m.entero('maximoPorItem') ?? 1,
        corte: m.entero('corte') ?? 1,
        referencia: m.texto('referencia'),
        textos: m.listaTextos('textos'),
      );
}

/// Anestésico local del protocolo, con su máximo en mg/kg (pregunta 32:
/// lo fija el médico, VERIFICAR).
class AnestesicoProtocolo {
  const AnestesicoProtocolo({
    required this.nombre,
    this.concentracionMgMl,
    this.maximoMgKg,
  });

  final String nombre;
  final double? concentracionMgMl;
  final double? maximoMgKg;

  bool get completo =>
      nombre.trim().isNotEmpty &&
      (concentracionMgMl ?? 0) > 0 &&
      (maximoMgKg ?? 0) > 0;

  Map<String, Object?> aMapa() => compacto({
    'nombre': nombre,
    'concentracionMgMl': concentracionMgMl,
    'maximoMgKg': maximoMgKg,
  });

  static AnestesicoProtocolo desdeMapa(Map<String, Object?> m) =>
      AnestesicoProtocolo(
        nombre: m.texto('nombre'),
        concentracionMgMl: m.decimal('concentracionMgMl'),
        maximoMgKg: m.decimal('maximoMgKg'),
      );
}

/// Lo que define una versión de la plantilla de un procedimiento: la
/// valoración (criterios, contraindicaciones, tamizajes), el protocolo de
/// la sesión y los textos del consentimiento. Agregar toxina o rellenos es
/// agregar otra definición, sin tocar el resto del módulo.
class DefinicionProcedimiento {
  const DefinicionProcedimiento({
    required this.nombre,
    this.familia = '',
    this.imcMaximoAviso,
    this.vigenciaDias = 90,
    this.zonas = const [],
    this.items = const [],
    this.tamizajes = const [],
    this.recomendaciones = const [],
    this.componentes = const [],
    this.volumenMaximoZonaMl,
    this.volumenMaximoSesionMl,
    this.intervaloDias,
    this.numeroSesiones,
    this.anestesicos = const [],
    this.listaVerificacion = const [],
    this.indicacionesPosteriores = '',
    this.diasControl,
    this.protocolo = '',
    this.riesgos = '',
    this.alternativas = '',
  });

  final String nombre;

  /// Familia de técnicas, para las certificaciones (pregunta 36).
  final String familia;

  /// IMC desde el que avisa (no bloquea; pregunta 28).
  final double? imcMaximoAviso;

  /// Días que vale una valoración «apto» (pregunta 29).
  final int vigenciaDias;
  final List<String> zonas;

  /// Contraindicaciones y precauciones de la valoración.
  final List<ItemValoracion> items;
  final List<InstrumentoTamizaje> tamizajes;
  final List<String> recomendaciones;

  /// Protocolo (pregunta 31): lo escribe el médico.
  final List<String> componentes;
  final double? volumenMaximoZonaMl;
  final double? volumenMaximoSesionMl;
  final int? intervaloDias;
  final int? numeroSesiones;
  final List<AnestesicoProtocolo> anestesicos;
  final List<String> listaVerificacion;
  final String indicacionesPosteriores;
  final int? diasControl;
  final String protocolo;

  /// Para el consentimiento informado (5.3c).
  final String riesgos;
  final String alternativas;

  /// Lo que falta para poder aprobarla. Vacía: se puede aprobar.
  List<String> get faltantes {
    bool enBlanco(String t) => t.trim().isEmpty || t.contains('______');
    return [
      if (familia.trim().isEmpty) 'la familia de técnicas',
      if (zonas.isEmpty) 'al menos una zona',
      if (componentes.isEmpty) 'los componentes de la solución',
      if ((volumenMaximoZonaMl ?? 0) <= 0) 'el volumen máximo por zona',
      if ((volumenMaximoSesionMl ?? 0) <= 0) 'el volumen máximo por sesión',
      if ((intervaloDias ?? 0) <= 0) 'el intervalo entre sesiones',
      if ((numeroSesiones ?? 0) <= 0) 'el número de sesiones',
      if (anestesicos.isEmpty || anestesicos.any((a) => !a.completo))
        'la concentración y el máximo en mg/kg de cada anestésico',
      if (listaVerificacion.isEmpty) 'la lista de verificación',
      if (enBlanco(indicacionesPosteriores)) 'las indicaciones posteriores',
      if ((diasControl ?? 0) <= 0) 'los días hasta el control',
      if (enBlanco(riesgos)) 'los riesgos (para el consentimiento)',
      if (enBlanco(alternativas)) 'las alternativas (para el consentimiento)',
    ];
  }

  DefinicionProcedimiento copyWith({
    String? nombre,
    String? familia,
    Object? imcMaximoAviso = sin,
    int? vigenciaDias,
    List<String>? zonas,
    List<ItemValoracion>? items,
    List<InstrumentoTamizaje>? tamizajes,
    List<String>? recomendaciones,
    List<String>? componentes,
    Object? volumenMaximoZonaMl = sin,
    Object? volumenMaximoSesionMl = sin,
    Object? intervaloDias = sin,
    Object? numeroSesiones = sin,
    List<AnestesicoProtocolo>? anestesicos,
    List<String>? listaVerificacion,
    String? indicacionesPosteriores,
    Object? diasControl = sin,
    String? protocolo,
    String? riesgos,
    String? alternativas,
  }) => DefinicionProcedimiento(
    nombre: nombre ?? this.nombre,
    familia: familia ?? this.familia,
    imcMaximoAviso: cambio(imcMaximoAviso, this.imcMaximoAviso),
    vigenciaDias: vigenciaDias ?? this.vigenciaDias,
    zonas: zonas ?? this.zonas,
    items: items ?? this.items,
    tamizajes: tamizajes ?? this.tamizajes,
    recomendaciones: recomendaciones ?? this.recomendaciones,
    componentes: componentes ?? this.componentes,
    volumenMaximoZonaMl: cambio(volumenMaximoZonaMl, this.volumenMaximoZonaMl),
    volumenMaximoSesionMl: cambio(
      volumenMaximoSesionMl,
      this.volumenMaximoSesionMl,
    ),
    intervaloDias: cambio(intervaloDias, this.intervaloDias),
    numeroSesiones: cambio(numeroSesiones, this.numeroSesiones),
    anestesicos: anestesicos ?? this.anestesicos,
    listaVerificacion: listaVerificacion ?? this.listaVerificacion,
    indicacionesPosteriores:
        indicacionesPosteriores ?? this.indicacionesPosteriores,
    diasControl: cambio(diasControl, this.diasControl),
    protocolo: protocolo ?? this.protocolo,
    riesgos: riesgos ?? this.riesgos,
    alternativas: alternativas ?? this.alternativas,
  );

  Map<String, Object?> aMapa() => compacto({
    'nombre': nombre,
    'familia': familia,
    'imcMaximoAviso': imcMaximoAviso,
    'vigenciaDias': vigenciaDias,
    'zonas': zonas,
    'items': [for (final i in items) i.aMapa()],
    'tamizajes': [for (final t in tamizajes) t.aMapa()],
    'recomendaciones': recomendaciones,
    'componentes': componentes,
    'volumenMaximoZonaMl': volumenMaximoZonaMl,
    'volumenMaximoSesionMl': volumenMaximoSesionMl,
    'intervaloDias': intervaloDias,
    'numeroSesiones': numeroSesiones,
    'anestesicos': [for (final a in anestesicos) a.aMapa()],
    'listaVerificacion': listaVerificacion,
    'indicacionesPosteriores': indicacionesPosteriores,
    'diasControl': diasControl,
    'protocolo': protocolo,
    'riesgos': riesgos,
    'alternativas': alternativas,
  });

  static DefinicionProcedimiento desdeMapa(Map<String, Object?> m) =>
      DefinicionProcedimiento(
        nombre: m.texto('nombre'),
        familia: m.texto('familia'),
        imcMaximoAviso: m.decimal('imcMaximoAviso'),
        vigenciaDias: m.entero('vigenciaDias') ?? 90,
        zonas: m.listaTextos('zonas'),
        items: [
          for (final i in m.listaMapas('items')) ItemValoracion.desdeMapa(i),
        ],
        tamizajes: [
          for (final t in m.listaMapas('tamizajes'))
            InstrumentoTamizaje.desdeMapa(t),
        ],
        recomendaciones: m.listaTextos('recomendaciones'),
        componentes: m.listaTextos('componentes'),
        volumenMaximoZonaMl: m.decimal('volumenMaximoZonaMl'),
        volumenMaximoSesionMl: m.decimal('volumenMaximoSesionMl'),
        intervaloDias: m.entero('intervaloDias'),
        numeroSesiones: m.entero('numeroSesiones'),
        anestesicos: [
          for (final a in m.listaMapas('anestesicos'))
            AnestesicoProtocolo.desdeMapa(a),
        ],
        listaVerificacion: m.listaTextos('listaVerificacion'),
        indicacionesPosteriores: m.texto('indicacionesPosteriores'),
        diasControl: m.entero('diasControl'),
        protocolo: m.texto('protocolo'),
        riesgos: m.texto('riesgos'),
        alternativas: m.texto('alternativas'),
      );
}

class VersionProcedimiento {
  const VersionProcedimiento({
    required this.version,
    required this.definicion,
    this.aprobadaEn,
  });

  final int version;
  final DefinicionProcedimiento definicion;
  final DateTime? aprobadaEn;

  bool get aprobada => aprobadaEn != null;

  Map<String, Object?> aMapa() => compacto({
    'version': version,
    'definicion': definicion.aMapa(),
    'aprobadaEn': aprobadaEn?.toUtc().toIso8601String(),
  });

  static VersionProcedimiento desdeMapa(Map<String, Object?> m) =>
      VersionProcedimiento(
        version: m.entero('version')!,
        definicion: DefinicionProcedimiento.desdeMapa(m.mapa('definicion')),
        aprobadaEn: m['aprobadaEn'] == null
            ? null
            : DateTime.parse(m['aprobadaEn']! as String).toLocal(),
      );
}

/// Plantilla de un procedimiento con sus versiones (una aprobada no se
/// edita: editarla crea la siguiente, en borrador).
class PlantillaProcedimiento {
  const PlantillaProcedimiento({required this.id, required this.versiones});

  static const coleccion = 'plantillasProcedimiento';

  final String id;
  final List<VersionProcedimiento> versiones;

  VersionProcedimiento? get vigente =>
      versiones.where((v) => v.aprobada).lastOrNull;

  VersionProcedimiento? get borrador =>
      versiones.isNotEmpty && !versiones.last.aprobada ? versiones.last : null;

  VersionProcedimiento get ultima => versiones.last;

  bool get usable => vigente != null;

  String get nombre => (vigente ?? ultima).definicion.nombre;

  VersionProcedimiento? version(int v) =>
      versiones.where((x) => x.version == v).firstOrNull;

  PlantillaProcedimiento conBorrador(DefinicionProcedimiento d) {
    final b = borrador;
    return PlantillaProcedimiento(
      id: id,
      versiones: [
        ...b == null ? versiones : versiones.sublist(0, versiones.length - 1),
        VersionProcedimiento(
          version: b?.version ?? ultima.version + 1,
          definicion: d,
        ),
      ],
    );
  }

  /// Aprueba el borrador. Lanza [StateError] si no hay borrador o si le
  /// falta algo del protocolo.
  PlantillaProcedimiento aprobada(DateTime ahora) {
    final b = borrador;
    if (b == null) throw StateError('No hay un borrador para aprobar.');
    final faltan = b.definicion.faltantes;
    if (faltan.isNotEmpty) {
      throw StateError('Para aprobarla falta ${faltan.join(', ')}.');
    }
    return PlantillaProcedimiento(
      id: id,
      versiones: [
        ...versiones.sublist(0, versiones.length - 1),
        VersionProcedimiento(
          version: b.version,
          definicion: b.definicion,
          aprobadaEn: ahora,
        ),
      ],
    );
  }

  Map<String, Object?> aMapa() => {
    'versiones': [for (final v in versiones) v.aMapa()],
  };

  static PlantillaProcedimiento desdeMapa(String id, Map<String, Object?> m) =>
      PlantillaProcedimiento(
        id: id,
        versiones: [
          for (final v in m.listaMapas('versiones'))
            VersionProcedimiento.desdeMapa(v),
        ],
      );
}

/// Hidrolipoclasia de fábrica (versión 1, en borrador). Trae la
/// estructura y lo editable con valores de referencia (VERIFICAR); el
/// protocolo (componentes, volúmenes, anestésico con su máximo, sesiones,
/// intervalo, indicaciones, control, riesgos y alternativas) viene vacío:
/// lo escribe el médico (pregunta 31). No se puede usar sin aprobarla.
const hidrolipoclasiaBase = PlantillaProcedimiento(
  id: 'hidrolipoclasia',
  versiones: [
    VersionProcedimiento(
      version: 1,
      definicion: DefinicionProcedimiento(
        nombre: 'Hidrolipoclasia',
        familia: 'Lipólisis por infiltración',
        imcMaximoAviso: 30,
        vigenciaDias: 90,
        zonas: [
          'Abdomen superior',
          'Abdomen inferior',
          'Flancos',
          'Espalda',
          'Brazos',
          'Cara interna de muslos',
          'Cara externa de muslos',
          'Papada',
        ],
        items: [
          ItemValoracion('Embarazo o lactancia', EfectoItem.diferir),
          ItemValoracion('Anticoagulación o coagulopatía', EfectoItem.noApto),
          ItemValoracion('Infección en la zona', EfectoItem.diferir),
          ItemValoracion('Enfermedad descompensada', EfectoItem.diferir),
          ItemValoracion('Alergia a anestésicos locales', EfectoItem.noApto),
          ItemValoracion(
            'Antiagregación no suspendida según protocolo',
            EfectoItem.precaucion,
          ),
          ItemValoracion('Cirugía previa en la zona', EfectoItem.precaucion),
          ItemValoracion(
            'Indicios de trastorno dismórfico corporal',
            EfectoItem.precaucion,
          ),
        ],
        tamizajes: [
          InstrumentoTamizaje(
            id: 'scoff',
            nombre: 'SCOFF (conducta alimentaria)',
            numeroItems: 5,
            maximoPorItem: 1,
            corte: 2,
            referencia:
                'Versión española validada (García-Campayo, 2005); '
                'positivo con 2 o más (VERIFICAR la licencia)',
          ),
          InstrumentoTamizaje(
            id: 'dcq',
            nombre: 'DCQ (preocupación dismórfica)',
            numeroItems: 7,
            maximoPorItem: 3,
            corte: 9,
            referencia:
                'Validado en español; ítems de 0 a 3, positivo con 9 o más '
                '(VERIFICAR el corte y la licencia)',
          ),
        ],
        recomendaciones: [
          'Primero programa de peso',
          'Flacidez: remitir a cirugía plástica',
          'Remitir a psicología o psiquiatría',
          'Tratar la condición y volver a valorar',
          'Expectativas no realistas: explicar el alcance',
        ],
        anestesicos: [
          AnestesicoProtocolo(nombre: 'Lidocaína sin epinefrina'),
          AnestesicoProtocolo(nombre: 'Lidocaína con epinefrina'),
        ],
        listaVerificacion: [
          'Consentimiento vigente',
          'Valoración vigente',
          'Mayor de edad',
          'Alergias revisadas',
          'Anticoagulación descartada',
          'Embarazo descartado',
          'Sin infección en la zona',
          'Signos vitales tomados',
          'Lotes vigentes',
          'Equipo verificado',
          'Emulsión lipídica y protocolo de toxicidad disponibles',
        ],
        indicacionesPosteriores: '''
Cuidados de la zona: ______
Prenda de compresión: ______
Actividad física: ______
Signos de alarma y a quién llamar: ______''',
        riesgos: '''
Frecuentes: ______
Poco frecuentes pero graves: ______''',
        alternativas: '______',
      ),
    ),
  ],
);

/// Las plantillas de procedimiento de fábrica.
const plantillasProcedimientoBase = [hidrolipoclasiaBase];
