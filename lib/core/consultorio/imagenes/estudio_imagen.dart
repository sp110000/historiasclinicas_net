import '../../integridad/json_canonico.dart';
import '../../models/mapa.dart';
import '../documentos/documento_clinico.dart' show DiagnosticoDocumento;
import 'plantillas_eco.dart';

/// «1,8» (con coma, sin ceros de más).
String numeroEco(double v, {int decimales = 1}) {
  final t = v.toStringAsFixed(decimales);
  final limpio = t.contains('.')
      ? t.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
      : t;
  return limpio.replaceAll('.', ',');
}

/// Factor del volumen del elipsoide (π / 6).
const factorElipsoide = 0.523;

/// Una sección de hallazgos del informe.
class SeccionEstudio {
  const SeccionEstudio({required this.titulo, this.texto = ''});

  final String titulo;
  final String texto;

  SeccionEstudio copyWith({String? titulo, String? texto}) =>
      SeccionEstudio(titulo: titulo ?? this.titulo, texto: texto ?? this.texto);

  Map<String, Object?> aMapa() => {'titulo': titulo, 'texto': texto};

  static SeccionEstudio desdeMapa(Map<String, Object?> m) =>
      SeccionEstudio(titulo: m.texto('titulo'), texto: m.texto('texto'));
}

/// Una medida. Con [volumen] lleva tres diámetros en cm y el resultado es
/// el volumen del elipsoide en mL; si no, un solo valor en [unidad].
class MedidaEstudio {
  const MedidaEstudio({
    required this.nombre,
    required this.unidad,
    this.volumen = false,
    this.valores = const [],
  });

  factory MedidaEstudio.desdePlantilla(MedidaPlantilla m) =>
      MedidaEstudio(nombre: m.nombre, unidad: m.unidad, volumen: m.volumen);

  final String nombre;
  final String unidad;
  final bool volumen;

  /// Uno o tres valores (los que falten van en `null`).
  final List<double?> valores;

  double? valor(int i) => i < valores.length ? valores[i] : null;

  /// El volumen (mL) con los tres diámetros, o el valor único.
  double? get resultado {
    if (!volumen) return valor(0);
    final a = valor(0), b = valor(1), c = valor(2);
    if (a == null || b == null || c == null) return null;
    return a * b * c * factorElipsoide;
  }

  bool get vacia => valores.every((v) => v == null);

  /// «1,8 × 2 × 4,5 cm (8,5 mL)» o «5,2 mm».
  String get texto {
    if (!volumen) {
      final v = valor(0);
      return v == null ? '' : '${numeroEco(v)} $unidad';
    }
    final r = resultado;
    final diametros = [
      for (var i = 0; i < 3; i++)
        if (valor(i) case final v?) numeroEco(v),
    ];
    if (diametros.isEmpty) return '';
    return [
      '${diametros.join(' × ')} cm',
      if (r != null) '(${numeroEco(r)} $unidad)',
    ].join(' ');
  }

  MedidaEstudio copyWith({
    String? nombre,
    String? unidad,
    List<double?>? valores,
  }) => MedidaEstudio(
    nombre: nombre ?? this.nombre,
    unidad: unidad ?? this.unidad,
    volumen: volumen,
    valores: valores ?? this.valores,
  );

  /// Con el valor [i] cambiado.
  MedidaEstudio conValor(int i, double? v) {
    final n = volumen ? 3 : 1;
    final l = [for (var k = 0; k < n; k++) k == i ? v : valor(k)];
    return copyWith(valores: l);
  }

  Map<String, Object?> aMapa() => compacto({
    'nombre': nombre,
    'unidad': unidad,
    'volumen': volumen ? true : null,
    'valores': valores,
    if (resultado case final r?)
      'resultado': double.parse(r.toStringAsFixed(2)),
  });

  static MedidaEstudio desdeMapa(Map<String, Object?> m) => MedidaEstudio(
    nombre: m.texto('nombre'),
    unidad: m.texto('unidad'),
    volumen: m.booleano('volumen'),
    valores: [
      for (final v in (m['valores'] as List?) ?? const [])
        (v as num?)?.toDouble(),
    ],
  );
}

/// Una imagen del estudio (JPEG cifrado). Hasta [maxImagenesInforme] van
/// en el PDF del informe.
class ImagenEstudio {
  const ImagenEstudio({
    required this.id,
    required this.ancho,
    required this.alto,
    required this.sha256,
    this.rotulo = '',
    this.enInforme = true,
  });

  final String id;
  final int ancho;
  final int alto;
  final String sha256;
  final String rotulo;
  final bool enInforme;

  ImagenEstudio copyWith({String? rotulo, bool? enInforme}) => ImagenEstudio(
    id: id,
    ancho: ancho,
    alto: alto,
    sha256: sha256,
    rotulo: rotulo ?? this.rotulo,
    enInforme: enInforme ?? this.enInforme,
  );

  Map<String, Object?> aMapa() => compacto({
    'id': id,
    'ancho': ancho,
    'alto': alto,
    'sha256': sha256,
    'rotulo': rotulo.trim(),
    'enInforme': enInforme,
  });

  static ImagenEstudio desdeMapa(Map<String, Object?> m) => ImagenEstudio(
    id: m.texto('id'),
    ancho: m.entero('ancho') ?? 0,
    alto: m.entero('alto') ?? 0,
    sha256: m.texto('sha256'),
    rotulo: m.texto('rotulo'),
    enInforme: m.booleano('enInforme', porDefecto: true),
  );
}

/// Las imágenes que caben en el PDF del informe (una cuadrícula de 2 × 3).
const maxImagenesInforme = 6;

enum EstadoEstudio {
  borrador('Borrador'),
  cerrado('Cerrado'),
  anulado('Anulado');

  const EstadoEstudio(this.etiqueta);

  final String etiqueta;
}

/// Un estudio de imágenes: el informe ecográfico con sus imágenes. En
/// borrador se edita; al cerrarlo recibe su número (EC-) y su PDF firmado,
/// y lo sellado ([sellado]) no cambia más. Se puede anular con motivo.
class EstudioImagen {
  const EstudioImagen({
    required this.id,
    required this.pacienteId,
    required this.plantillaId,
    required this.titulo,
    required this.fecha,
    required this.creado,
    required this.actualizado,
    this.tecnica = '',
    this.equipo = '',
    this.indicacion = '',
    this.secciones = const [],
    this.medidas = const [],
    this.imagenes = const [],
    this.diagnostico = const DiagnosticoDocumento(),
    this.impresion = '',
    this.recomendaciones = '',
    this.estado = EstadoEstudio.borrador,
    this.numero,
    this.cerrado,
    this.sha256,
    this.motivoAnulacion = '',
  });

  static const coleccion = 'estudiosImagen';
  static const tipoBinarioImagen = 'ecoimg';
  static const tipoMiniatura = 'ecomini';
  static const tipoBinarioPdf = 'ecopdf';
  static const prefijo = 'EC';
  static const nombreAdjunto = 'ecografia.json';

  final String id;
  final String pacienteId;
  final String plantillaId;

  /// «Ecografía de tiroides y cuello».
  final String titulo;
  final DateTime fecha;
  final String tecnica;

  /// El aparato (texto libre: «Butterfly iQ3»).
  final String equipo;
  final String indicacion;
  final List<SeccionEstudio> secciones;
  final List<MedidaEstudio> medidas;
  final List<ImagenEstudio> imagenes;

  /// CIE-10 (opcional) de la impresión diagnóstica.
  final DiagnosticoDocumento diagnostico;
  final String impresion;
  final String recomendaciones;
  final EstadoEstudio estado;

  /// «EC-000001», al cerrarlo.
  final String? numero;
  final DateTime? cerrado;

  /// Huella de lo sellado, al cerrarlo.
  final String? sha256;
  final String motivoAnulacion;
  final DateTime creado;
  final DateTime actualizado;

  bool get borrador => estado == EstadoEstudio.borrador;

  List<ImagenEstudio> get imagenesInforme => [
    for (final i in imagenes)
      if (i.enInforme) i,
  ];

  /// Las medidas con algún valor.
  List<MedidaEstudio> get medidasConValor => [
    for (final m in medidas)
      if (!m.vacia) m,
  ];

  /// Un estudio nuevo desde [p], en borrador.
  factory EstudioImagen.nuevo({
    required String id,
    required String pacienteId,
    required PlantillaEco p,
    required DateTime ahora,
    String equipo = '',
  }) => EstudioImagen(
    id: id,
    pacienteId: pacienteId,
    plantillaId: p.id,
    titulo: p.nombre,
    fecha: ahora,
    creado: ahora,
    actualizado: ahora,
    tecnica: p.tecnica,
    equipo: equipo,
    secciones: [
      for (final s in p.secciones)
        SeccionEstudio(titulo: s.titulo, texto: s.textoNormal),
    ],
    medidas: [for (final m in p.medidas) MedidaEstudio.desdePlantilla(m)],
    impresion: p.impresion,
  );

  /// Lo que falta para cerrar el informe.
  List<String> get faltantes => [
    if (equipo.trim().isEmpty) 'el equipo',
    if (!secciones.any((s) => s.texto.trim().isNotEmpty)) 'los hallazgos',
    if (impresion.trim().isEmpty && diagnostico.vacio)
      'la impresión diagnóstica',
    if (imagenesInforme.length > maxImagenesInforme)
      'dejar como máximo $maxImagenesInforme imágenes en el informe',
  ];

  EstudioImagen copyWith({
    String? titulo,
    DateTime? fecha,
    String? tecnica,
    String? equipo,
    String? indicacion,
    List<SeccionEstudio>? secciones,
    List<MedidaEstudio>? medidas,
    List<ImagenEstudio>? imagenes,
    DiagnosticoDocumento? diagnostico,
    String? impresion,
    String? recomendaciones,
    EstadoEstudio? estado,
    Object? numero = sin,
    Object? cerrado = sin,
    Object? sha256 = sin,
    String? motivoAnulacion,
    DateTime? actualizado,
  }) => EstudioImagen(
    id: id,
    pacienteId: pacienteId,
    plantillaId: plantillaId,
    creado: creado,
    titulo: titulo ?? this.titulo,
    fecha: fecha ?? this.fecha,
    tecnica: tecnica ?? this.tecnica,
    equipo: equipo ?? this.equipo,
    indicacion: indicacion ?? this.indicacion,
    secciones: secciones ?? this.secciones,
    medidas: medidas ?? this.medidas,
    imagenes: imagenes ?? this.imagenes,
    diagnostico: diagnostico ?? this.diagnostico,
    impresion: impresion ?? this.impresion,
    recomendaciones: recomendaciones ?? this.recomendaciones,
    estado: estado ?? this.estado,
    numero: cambio(numero, this.numero),
    cerrado: cambio(cerrado, this.cerrado),
    sha256: cambio(sha256, this.sha256),
    motivoAnulacion: motivoAnulacion ?? this.motivoAnulacion,
    actualizado: actualizado ?? this.actualizado,
  );

  /// El contenido clínico, sin el estado: lo que se sella al cerrar.
  Map<String, Object?> contenido() => compacto({
    'pacienteId': pacienteId,
    'plantillaId': plantillaId,
    'titulo': titulo.trim(),
    'fecha': fechaHoraIso(fecha),
    'tecnica': tecnica.trim(),
    'equipo': equipo.trim(),
    'indicacion': indicacion.trim(),
    'secciones': [for (final s in secciones) s.aMapa()],
    'medidas': [for (final m in medidas) m.aMapa()],
    'imagenes': [for (final i in imagenes) i.aMapa()],
    'diagnostico': diagnostico.vacio ? null : diagnostico.aMapa(),
    'impresion': impresion.trim(),
    'recomendaciones': recomendaciones.trim(),
  });

  /// Lo sellado: el contenido con su número, para `ecografia.json`.
  Map<String, Object?> sellado({
    required String numero,
    required DateTime cerrado,
    Map<String, Object?>? autor,
    Map<String, Object?>? paciente,
  }) => compacto({
    'tipo': 'ecografia',
    'numero': numero,
    'cerrado': fechaHoraIso(cerrado),
    ...contenido(),
    'paciente': paciente,
    'autor': autor,
  });

  /// `ecografia.json`: lo sellado y su huella.
  static String jsonSellado(Map<String, Object?> sellado) => jsonCanonico({
    'aplicacion': 'historiasclinicas.net',
    'ecografia': sellado,
    'sha256': sha256Canonico(sellado),
  });

  Map<String, Object?> aMapa() => compacto({
    ...contenido(),
    'estado': estado.name,
    'numero': numero,
    'cerrado': cerrado?.toUtc().toIso8601String(),
    'sha256': sha256,
    'motivoAnulacion': motivoAnulacion.trim(),
    'creado': creado.toUtc().toIso8601String(),
    'actualizado': actualizado.toUtc().toIso8601String(),
  });

  static EstudioImagen desdeMapa(String id, Map<String, Object?> m) =>
      EstudioImagen(
        id: id,
        pacienteId: m.texto('pacienteId'),
        plantillaId: m.texto('plantillaId'),
        titulo: m.texto('titulo'),
        fecha: m.fecha('fecha') ?? DateTime.parse(m['creado']! as String),
        tecnica: m.texto('tecnica'),
        equipo: m.texto('equipo'),
        indicacion: m.texto('indicacion'),
        secciones: [
          for (final s in m.listaMapas('secciones'))
            SeccionEstudio.desdeMapa(s),
        ],
        medidas: [
          for (final x in m.listaMapas('medidas')) MedidaEstudio.desdeMapa(x),
        ],
        imagenes: [
          for (final i in m.listaMapas('imagenes')) ImagenEstudio.desdeMapa(i),
        ],
        diagnostico: m['diagnostico'] is Map
            ? DiagnosticoDocumento.desdeMapa(m.mapa('diagnostico'))
            : const DiagnosticoDocumento(),
        impresion: m.texto('impresion'),
        recomendaciones: m.texto('recomendaciones'),
        estado:
            EstadoEstudio.values
                .where((e) => e.name == m.texto('estado'))
                .firstOrNull ??
            EstadoEstudio.borrador,
        numero: m.textoONulo('numero'),
        cerrado: switch (m.textoONulo('cerrado')) {
          final c? => DateTime.parse(c).toLocal(),
          null => null,
        },
        sha256: m.textoONulo('sha256'),
        motivoAnulacion: m.texto('motivoAnulacion'),
        creado: DateTime.parse(m['creado']! as String).toLocal(),
        actualizado: DateTime.parse(m['actualizado']! as String).toLocal(),
      );
}
