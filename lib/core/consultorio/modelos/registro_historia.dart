import '../../integridad/cadena_hash.dart';
import '../../integridad/json_canonico.dart';
import '../../models/historia.dart';
import '../../models/mapa.dart';

/// De dónde llegó un PDF de la historia.
enum OrigenArchivo { generado, importado, abierto }

/// Un PDF conocido de la historia (cada revisión descargada o importada).
class ArchivoHistoria {
  const ArchivoHistoria({
    required this.nombre,
    required this.revision,
    required this.fecha,
    required this.origen,
    this.sha256Pdf = '',
    this.hashFinal = '',
  });

  final String nombre;
  final int revision;
  final DateTime fecha;
  final OrigenArchivo origen;
  final String sha256Pdf;

  /// Último hash de la cadena de esa revisión.
  final String hashFinal;

  Map<String, Object?> aMapa() => compacto({
    'nombre': nombre,
    'revision': revision,
    'fecha': fecha.toUtc().toIso8601String(),
    'origen': origen.name,
    'sha256Pdf': sha256Pdf,
    'hashFinal': hashFinal,
  });

  static ArchivoHistoria desdeMapa(Map<String, Object?> m) => ArchivoHistoria(
    nombre: m.texto('nombre'),
    revision: m.entero('revision') ?? 0,
    fecha: DateTime.parse(m['fecha']! as String).toLocal(),
    origen: OrigenArchivo.values.byName(m.texto('origen')),
    sha256Pdf: m.texto('sha256Pdf'),
    hashFinal: m.texto('hashFinal'),
  );
}

/// Una evolución, resumida para la línea de tiempo.
class ResumenEvolucion {
  const ResumenEvolucion({
    required this.numero,
    required this.fechaHora,
    this.autor = '',
    this.huella = '',
    this.resumen = '',
    this.proximoControl,
  });

  final int numero;
  final DateTime fechaHora;
  final String autor;
  final String huella;

  /// Primeras líneas del texto.
  final String resumen;
  final DateTime? proximoControl;

  Map<String, Object?> aMapa() => compacto({
    'numero': numero,
    'fechaHora': fechaHoraIso(fechaHora),
    'autor': autor,
    'huella': huella,
    'resumen': resumen,
    'proximoControl': proximoControl == null ? null : fechaIso(proximoControl!),
  });

  static ResumenEvolucion desdeMapa(Map<String, Object?> m) => ResumenEvolucion(
    numero: m.entero('numero') ?? 0,
    fechaHora: m.fecha('fechaHora')!,
    autor: m.texto('autor'),
    huella: m.texto('huella'),
    resumen: m.texto('resumen'),
    proximoControl: m.fecha('proximoControl'),
  );
}

/// Prefijo de la línea que deja «Actualizar alergias» en una evolución.
const prefijoAlergiasActualizadas = 'Alergias actualizadas:';

/// Una historia en el índice: el resumen para la ficha y la línea de
/// tiempo. Los datos sellados completos y el PDF exacto van aparte, en
/// binarios (`datos/<id>` y `pdf/<id>`), y se leen solo cuando se abren.
class RegistroHistoria {
  const RegistroHistoria({
    required this.id,
    required this.pacienteId,
    required this.revision,
    required this.fechaAtencion,
    required this.hashFinal,
    required this.integridadCorrecta,
    required this.integridadDescripcion,
    required this.actualizado,
    this.finalizadaEn,
    this.tipoConsulta,
    this.motivo = '',
    this.diagnosticos = const [],
    this.medico = '',
    this.proximoControl,
    this.evoluciones = const [],
    this.alergias = const [],
    this.niegaAlergias = false,
    this.alergiasDesde,
    this.antecedentes = const {},
    this.recetasEnTexto = const [],
    this.archivos = const [],
    this.divergencias = const [],
    this.tienePdf = false,
  });

  static const coleccion = 'historias';

  static const tipoBinarioDatos = 'datos';
  static const tipoBinarioPdf = 'pdf';

  /// El `id` de la historia (`historia.json`).
  final String id;
  final String pacienteId;
  final int revision;
  final DateTime fechaAtencion;
  final DateTime? finalizadaEn;
  final String? tipoConsulta;
  final String motivo;

  /// «J029 Faringitis aguda», el principal primero.
  final List<String> diagnosticos;

  /// Médico que finalizó la historia.
  final String medico;

  /// El más reciente entre el del plan y el de las evoluciones.
  final DateTime? proximoControl;
  final List<ResumenEvolucion> evoluciones;
  final List<String> alergias;
  final bool niegaAlergias;

  /// Fecha de la evolución que actualizó las alergias; `null` si vienen de
  /// la historia inicial.
  final DateTime? alergiasDesde;

  /// Antecedentes con texto: personales, quirúrgicos, medicación actual…
  final Map<String, String> antecedentes;

  /// «Se formuló (R-000123) el …» sellado en el plan o en evoluciones.
  final List<String> recetasEnTexto;
  final String hashFinal;
  final bool integridadCorrecta;
  final String integridadDescripcion;
  final List<ArchivoHistoria> archivos;

  /// PDF con la misma revisión y otro contenido: versiones divergentes.
  final List<ArchivoHistoria> divergencias;

  /// Si el índice guarda el PDF exacto de la última revisión.
  final bool tienePdf;
  final DateTime actualizado;

  bool get divergente => divergencias.isNotEmpty;

  /// Fecha de la última atención: la última evolución o la historia.
  DateTime get ultimaAtencion => evoluciones.isEmpty
      ? fechaAtencion
      : evoluciones
            .map((e) => e.fechaHora)
            .fold(fechaAtencion, (a, b) => b.isAfter(a) ? b : a);

  RegistroHistoria copyWith({
    String? pacienteId,
    List<ArchivoHistoria>? archivos,
    List<ArchivoHistoria>? divergencias,
    bool? tienePdf,
    DateTime? actualizado,
  }) => RegistroHistoria(
    id: id,
    pacienteId: pacienteId ?? this.pacienteId,
    revision: revision,
    fechaAtencion: fechaAtencion,
    hashFinal: hashFinal,
    integridadCorrecta: integridadCorrecta,
    integridadDescripcion: integridadDescripcion,
    actualizado: actualizado ?? this.actualizado,
    finalizadaEn: finalizadaEn,
    tipoConsulta: tipoConsulta,
    motivo: motivo,
    diagnosticos: diagnosticos,
    medico: medico,
    proximoControl: proximoControl,
    evoluciones: evoluciones,
    alergias: alergias,
    niegaAlergias: niegaAlergias,
    alergiasDesde: alergiasDesde,
    antecedentes: antecedentes,
    recetasEnTexto: recetasEnTexto,
    archivos: archivos ?? this.archivos,
    divergencias: divergencias ?? this.divergencias,
    tienePdf: tienePdf ?? this.tienePdf,
  );

  /// Resume los datos sellados de una historia. Lanza [FormatException] si
  /// no son una historia clínica.
  factory RegistroHistoria.desdeDatos(
    Map<String, Object?> datos, {
    required String pacienteId,
    required int revision,
    required DateTime ahora,
    List<ArchivoHistoria> archivos = const [],
    bool tienePdf = false,
  }) {
    final h = HistoriaClinica.desdeMapa(datos);
    final integridad = verificarIntegridad(datos);
    final evoluciones = datos.listaMapas('evoluciones');
    DateTime? proximo = h.plan.proximoControl;
    var alergias = h.antecedentes.alergias;
    var niega = h.antecedentes.niegaAlergias;
    DateTime? alergiasDesde;
    final recetas = <String>[..._recetasEn(h.plan.planTerapeutico)];
    final resumenes = <ResumenEvolucion>[];
    for (final (i, e) in evoluciones.indexed) {
      final texto = e.texto('texto');
      final fecha = e.fecha('fechaHora')!;
      final control = e.fecha('proximoControl');
      if (control != null && (proximo == null || control.isAfter(proximo))) {
        proximo = control;
      }
      final actualizadas = _alergiasActualizadas(texto);
      if (actualizadas != null) {
        alergias = actualizadas;
        niega = actualizadas.isEmpty;
        alergiasDesde = fecha;
      }
      recetas.addAll(_recetasEn(texto));
      final hash = e.textoONulo('hash');
      resumenes.add(
        ResumenEvolucion(
          numero: i + 1,
          fechaHora: fecha,
          autor: e.mapa('autor').texto('nombre'),
          huella: hash == null || hash.length < 8 ? '' : huella(hash),
          resumen: _resumen(texto),
          proximoControl: control,
        ),
      );
    }
    final ultimoHash = evoluciones.isEmpty
        ? datos['hashBase']
        : evoluciones.last['hash'];
    final a = h.antecedentes;
    return RegistroHistoria(
      id: h.id,
      pacienteId: pacienteId,
      revision: revision,
      fechaAtencion: h.fechaAtencion,
      finalizadaEn: datos.fecha('finalizadaEn'),
      tipoConsulta: h.tipoConsulta,
      motivo: h.motivoConsulta,
      diagnosticos: [
        for (final d in [
          ...h.diagnosticos.where((d) => d.tipo == 'principal'),
          ...h.diagnosticos.where((d) => d.tipo != 'principal'),
        ])
          [
            d.codigo.trim(),
            d.descripcion.trim(),
          ].where((s) => s.isNotEmpty).join(' '),
      ],
      medico: datos.mapa('medico').texto('nombre'),
      proximoControl: proximo,
      evoluciones: resumenes,
      alergias: alergias,
      niegaAlergias: niega,
      alergiasDesde: alergiasDesde,
      antecedentes: {
        if (a.personales.trim().isNotEmpty) 'Personales': a.personales.trim(),
        if (a.quirurgicos.trim().isNotEmpty)
          'Quirúrgicos': a.quirurgicos.trim(),
        if (a.medicacionActual.trim().isNotEmpty)
          'Medicación actual': a.medicacionActual.trim(),
        if (a.familiares.trim().isNotEmpty) 'Familiares': a.familiares.trim(),
        if (a.habitos.trim().isNotEmpty) 'Hábitos': a.habitos.trim(),
        if (a.otros.trim().isNotEmpty) 'Otros': a.otros.trim(),
      },
      recetasEnTexto: recetas,
      hashFinal: ultimoHash is String ? ultimoHash : sha256Canonico(datos),
      integridadCorrecta: integridad.correcta,
      integridadDescripcion: integridad.descripcion,
      archivos: archivos,
      tienePdf: tienePdf,
      actualizado: ahora,
    );
  }

  Map<String, Object?> aMapa() => compacto({
    'pacienteId': pacienteId,
    'revision': revision,
    'fechaAtencion': fechaHoraIso(fechaAtencion),
    'finalizadaEn': finalizadaEn == null ? null : fechaHoraIso(finalizadaEn!),
    'tipoConsulta': tipoConsulta,
    'motivo': motivo,
    'diagnosticos': diagnosticos.isEmpty ? null : diagnosticos,
    'medico': medico,
    'proximoControl': proximoControl == null ? null : fechaIso(proximoControl!),
    'evoluciones': evoluciones.isEmpty
        ? null
        : [for (final e in evoluciones) e.aMapa()],
    'alergias': alergias.isEmpty ? null : alergias,
    'niegaAlergias': niegaAlergias ? true : null,
    'alergiasDesde': alergiasDesde == null
        ? null
        : fechaHoraIso(alergiasDesde!),
    'antecedentes': antecedentes.isEmpty ? null : antecedentes,
    'recetasEnTexto': recetasEnTexto.isEmpty ? null : recetasEnTexto,
    'hashFinal': hashFinal,
    'integridadCorrecta': integridadCorrecta,
    'integridadDescripcion': integridadDescripcion,
    'archivos': archivos.isEmpty ? null : [for (final a in archivos) a.aMapa()],
    'divergencias': divergencias.isEmpty
        ? null
        : [for (final a in divergencias) a.aMapa()],
    'tienePdf': tienePdf ? true : null,
    'actualizado': actualizado.toUtc().toIso8601String(),
  });

  static RegistroHistoria desdeMapa(String id, Map<String, Object?> m) =>
      RegistroHistoria(
        id: id,
        pacienteId: m.texto('pacienteId'),
        revision: m.entero('revision') ?? 1,
        fechaAtencion: m.fecha('fechaAtencion')!,
        finalizadaEn: m.fecha('finalizadaEn'),
        tipoConsulta: m.textoONulo('tipoConsulta'),
        motivo: m.texto('motivo'),
        diagnosticos: m.listaTextos('diagnosticos'),
        medico: m.texto('medico'),
        proximoControl: m.fecha('proximoControl'),
        evoluciones: [
          for (final e in m.listaMapas('evoluciones'))
            ResumenEvolucion.desdeMapa(e),
        ],
        alergias: m.listaTextos('alergias'),
        niegaAlergias: m.booleano('niegaAlergias'),
        alergiasDesde: m.fecha('alergiasDesde'),
        antecedentes: m.mapa('antecedentes').cast<String, String>(),
        recetasEnTexto: m.listaTextos('recetasEnTexto'),
        hashFinal: m.texto('hashFinal'),
        integridadCorrecta: m.booleano('integridadCorrecta', porDefecto: true),
        integridadDescripcion: m.texto('integridadDescripcion'),
        archivos: [
          for (final a in m.listaMapas('archivos'))
            ArchivoHistoria.desdeMapa(a),
        ],
        divergencias: [
          for (final a in m.listaMapas('divergencias'))
            ArchivoHistoria.desdeMapa(a),
        ],
        tienePdf: m.booleano('tienePdf'),
        actualizado: DateTime.parse(m['actualizado']! as String).toLocal(),
      );
}

String _resumen(String texto) {
  final t = texto.trim().replaceAll(RegExp(r'\s+'), ' ');
  return t.length <= 160 ? t : '${t.substring(0, 157)}…';
}

/// «Se formuló (R-000123) el 02/10/2026:» y «Se dieron indicaciones…».
Iterable<String> _recetasEn(String texto) => RegExp(
  r'^Se (?:formuló|dieron indicaciones)[^\n]*',
  multiLine: true,
).allMatches(texto).map((m) => m.group(0)!.trim());

/// Alergias de la última línea «Alergias actualizadas: …» del texto, o
/// `null` si no tiene. «niega» o vacío = sin alergias conocidas.
List<String>? _alergiasActualizadas(String texto) {
  List<String>? r;
  for (final l in texto.split('\n')) {
    final linea = l.trim();
    if (!linea.startsWith(prefijoAlergiasActualizadas)) continue;
    final resto = linea.substring(prefijoAlergiasActualizadas.length).trim();
    final sinPunto = resto.endsWith('.')
        ? resto.substring(0, resto.length - 1)
        : resto;
    r = sinPunto.isEmpty || sinPunto.toLowerCase().startsWith('niega')
        ? const []
        : [
            for (final a in sinPunto.split(','))
              if (a.trim().isNotEmpty) a.trim(),
          ];
  }
  return r;
}
