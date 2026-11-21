import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../ihce/reloj.dart';
import '../../models/historia.dart';
import '../../pdf/adjunto_historia.dart';
import '../../pdf/lector_adjunto.dart';
import '../../utils/ids.dart';
import '../modelos/ficha_paciente.dart';
import '../modelos/registro_receta.dart';
import '../modelos/registro_historia.dart';
import '../repositorio/bitacora.dart';
import '../repositorio/repositorio.dart';
import 'normalizar.dart';

/// Qué pasó al registrar una historia en el índice.
enum TipoRegistro {
  /// Historia que el índice no tenía.
  nueva('Importada'),

  /// Una revisión más nueva que la del índice: la reemplaza.
  actualizada('Versión más nueva'),

  /// La misma revisión y el mismo contenido.
  yaEstaba('Ya estaba'),

  /// Una revisión más vieja que la del índice: no la reemplaza.
  masVieja('Versión más vieja'),

  /// La misma revisión con otro contenido: versiones divergentes.
  divergente('Versiones divergentes');

  const TipoRegistro(this.etiqueta);

  final String etiqueta;
}

class ResultadoRegistro {
  const ResultadoRegistro({
    required this.tipo,
    required this.historiaId,
    required this.pacienteId,
    required this.integridadCorrecta,
    required this.integridadDescripcion,
    this.pacienteNuevo = false,
  });

  final TipoRegistro tipo;
  final String historiaId;
  final String pacienteId;
  final bool pacienteNuevo;
  final bool integridadCorrecta;
  final String integridadDescripcion;
}

/// Resultado de importar un archivo en lote.
enum TipoImportacion { registrada, alterada, danada, noEsDeLaApp, noEsHistoria }

class ResultadoImportacion {
  const ResultadoImportacion({
    required this.nombre,
    required this.tipo,
    required this.mensaje,
    this.registro,
  });

  final String nombre;
  final TipoImportacion tipo;
  final String mensaje;
  final ResultadoRegistro? registro;

  bool get importada => registro != null;
}

/// Filtro por la fecha de la última atención.
enum FiltroUltimaAtencion {
  ultimoMes('Último mes', 31),
  ultimos3Meses('Últimos 3 meses', 92),
  ultimoAnio('Último año', 366),
  masDeUnAnio('Hace más de un año', 0);

  const FiltroUltimaAtencion(this.etiqueta, this.dias);

  final String etiqueta;
  final int dias;
}

/// Lo que la lista muestra de cada paciente.
class ResumenPaciente {
  const ResumenPaciente({
    required this.ficha,
    this.ultimaAtencion,
    this.proximoControl,
    this.historias = 0,
  });

  final FichaPaciente ficha;
  final DateTime? ultimaAtencion;
  final DateTime? proximoControl;
  final int historias;

  /// Control vencido: la fecha pasó y no hubo atención desde entonces.
  bool controlVencido(DateTime ahora) {
    final p = proximoControl;
    if (p == null) return false;
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    if (!p.isBefore(hoy)) return false;
    final u = ultimaAtencion;
    return u == null || u.isBefore(p);
  }
}

/// Índice de pacientes del consultorio: fichas e historias registradas,
/// en memoria mientras el consultorio está abierto.
class IndicePacientes {
  IndicePacientes(this._repo, {this.reloj = const RelojSistema()});

  final RepositorioConsultorio _repo;
  final Reloj reloj;

  final _fichas = <String, FichaPaciente>{};
  final _historias = <String, RegistroHistoria>{};
  final _recetas = <String, RegistroReceta>{};

  /// Clave de documento → id de la ficha que la lleva.
  final _porClave = <String, String>{};

  /// Historias de cada ficha, ordenadas; se rehace al cambiar una historia.
  Map<String, List<RegistroHistoria>>? _porPaciente;

  /// Nombre y documento normalizados de cada ficha, para buscar.
  final _textoBusqueda = Expando<({String nombre, String documento})>();
  bool _cargado = false;

  bool get cargado => _cargado;

  /// Registros que no se pudieron leer al cargar (`pacientes/<id>` o
  /// `historias/<id>`): dañados, alterados o de un formato desconocido. No
  /// impiden abrir el consultorio; la lista de pacientes avisa.
  List<String> get registrosIlegibles => List.unmodifiable(_ilegibles);
  final _ilegibles = <String>[];

  Future<void> cargar() async {
    final fichas = await _repo.leerColeccionTolerante(FichaPaciente.coleccion);
    final historias = await _repo.leerColeccionTolerante(
      RegistroHistoria.coleccion,
    );
    final recetas = await _repo.leerColeccionTolerante(
      RegistroReceta.coleccion,
    );
    olvidar();
    _ilegibles
      ..addAll([
        for (final id in fichas.ilegibles) '${FichaPaciente.coleccion}/$id',
      ])
      ..addAll([
        for (final id in historias.ilegibles)
          '${RegistroHistoria.coleccion}/$id',
      ]);
    for (final e in fichas.registros.entries) {
      try {
        _ponerFicha(FichaPaciente.desdeMapa(e.key, e.value));
      } on Object {
        _ilegibles.add('${FichaPaciente.coleccion}/${e.key}');
      }
    }
    for (final e in historias.registros.entries) {
      try {
        _historias[e.key] = RegistroHistoria.desdeMapa(e.key, e.value);
      } on Object {
        _ilegibles.add('${RegistroHistoria.coleccion}/${e.key}');
      }
    }
    for (final e in recetas.registros.entries) {
      try {
        _recetas[e.key] = RegistroReceta.desdeMapa(e.key, e.value);
      } on Object {
        _ilegibles.add('${RegistroReceta.coleccion}/${e.key}');
      }
    }
    _cargado = true;
  }

  /// Descarta lo descifrado (al bloquear).
  void olvidar() {
    _fichas.clear();
    _historias.clear();
    _recetas.clear();
    _porClave.clear();
    _porPaciente = null;
    _ilegibles.clear();
    _cargado = false;
  }

  void _ponerFicha(FichaPaciente f) {
    final anterior = _fichas[f.id];
    if (anterior != null && _porClave[anterior.clave] == f.id) {
      _porClave.remove(anterior.clave);
    }
    _fichas[f.id] = f;
    // Una ficha unida no le quita la clave a la activa que la lleva.
    final actual = _fichas[_porClave[f.clave]];
    if (actual == null || !actual.activa || f.activa) {
      _porClave[f.clave] = f.id;
    }
  }

  void _ponerHistoria(RegistroHistoria h) {
    _historias[h.id] = h;
    _porPaciente = null;
  }

  Map<String, List<RegistroHistoria>> get _historiasPorPaciente =>
      _porPaciente ??= () {
        final m = <String, List<RegistroHistoria>>{};
        for (final h in _historias.values) {
          (m[h.pacienteId] ??= []).add(h);
        }
        for (final l in m.values) {
          l.sort((a, b) => b.ultimaAtencion.compareTo(a.ultimaAtencion));
        }
        return m;
      }();

  ({String nombre, String documento}) _texto(FichaPaciente f) =>
      _textoBusqueda[f] ??= (
        nombre: paraBuscar(
          '${f.primerApellido} ${f.segundoApellido} ${f.nombres}',
        ),
        documento: documentoNormalizado(f.numeroDocumento).toLowerCase(),
      );

  Iterable<FichaPaciente> get fichasActivas =>
      _fichas.values.where((f) => f.activa);

  FichaPaciente? ficha(String id) => _fichas[id];

  RegistroHistoria? historia(String id) => _historias[id];

  /// Historias de la ficha, de la más reciente a la más vieja.
  List<RegistroHistoria> historiasDe(String pacienteId) =>
      List.of(_historiasPorPaciente[pacienteId] ?? const []);

  /// Ficha activa: si se unió a otra, la que la reemplaza.
  FichaPaciente? _activa(FichaPaciente? f) {
    var actual = f;
    for (var i = 0; i < 10 && actual?.unidaEn != null; i++) {
      actual = _fichas[actual!.unidaEn];
    }
    return actual;
  }

  FichaPaciente? porClave(String clave) => _activa(_fichas[_porClave[clave]]);

  /// La ficha activa para [id]: la misma, o la que la reemplazó al unirlas.
  FichaPaciente? fichaActiva(String id) => _activa(_fichas[id]);

  /// [pacienteId] y los ids de las fichas que se unieron a ella: los
  /// documentos y las recetas sellados con un id viejo siguen apareciendo.
  Set<String> idsUnidos(String pacienteId) => {
    pacienteId,
    for (final f in _fichas.values)
      if (f.unidaEn != null && _activa(f)?.id == pacienteId) f.id,
  };

  /// Ficha de un paciente: la de su historia, la de su documento o una
  /// nueva (que hay que guardar) si no existe. [sinDocumento] es la clave
  /// para un paciente sin identificar.
  ({FichaPaciente ficha, bool nueva}) _fichaPara(
    Paciente p, {
    String? historiaId,
    required String sinDocumento,
    required DateTime ahora,
  }) {
    final h = historiaId == null ? null : _historias[historiaId];
    var ficha = h == null ? null : _activa(_fichas[h.pacienteId]);
    final clave = claveDocumento(p.tipoDocumento, p.numeroDocumento);
    if (ficha == null && clave != null) ficha = porClave(clave);
    if (ficha != null) {
      return (ficha: ficha.completadaCon(p, ahora), nueva: false);
    }
    return (
      ficha: FichaPaciente.desdePaciente(
        p,
        id: nuevoUuid(),
        clave: clave ?? sinDocumento,
        ahora: ahora,
      ),
      nueva: true,
    );
  }

  ResumenPaciente resumen(FichaPaciente f) {
    final hs = _historiasPorPaciente[f.id] ?? const [];
    DateTime? ultima;
    DateTime? proximo;
    for (final h in hs) {
      final u = h.ultimaAtencion;
      if (ultima == null || u.isAfter(ultima)) ultima = u;
      final p = h.proximoControl;
      if (p != null && (proximo == null || p.isAfter(proximo))) proximo = p;
    }
    return ResumenPaciente(
      ficha: f,
      ultimaAtencion: ultima,
      proximoControl: proximo,
      historias: hs.length,
    );
  }

  /// Historia más reciente de la ficha (para alergias, antecedentes y
  /// prellenar).
  RegistroHistoria? ultimaHistoria(String pacienteId) {
    final hs = historiasDe(pacienteId);
    return hs.isEmpty ? null : hs.first;
  }

  /// Alergias vigentes: las de la historia o la evolución más reciente que
  /// las registró. `desde` es la fecha de la evolución que las actualizó, o
  /// `null` si vienen de la historia inicial.
  ({List<String> alergias, bool niega, DateTime? desde})? alergiasDe(
    String pacienteId,
  ) {
    RegistroHistoria? mejor;
    DateTime? fechaMejor;
    for (final h in historiasDe(pacienteId)) {
      final f = h.alergiasDesde ?? h.fechaAtencion;
      if (fechaMejor == null || f.isAfter(fechaMejor)) {
        mejor = h;
        fechaMejor = f;
      }
    }
    if (mejor == null) return null;
    return (
      alergias: mejor.alergias,
      niega: mejor.niegaAlergias,
      // Solo si una evolución las actualizó; si no, vienen de la historia.
      desde: mejor.alergiasDesde,
    );
  }

  // ─────────────────────────── Registro ───────────────────────────

  /// Registra los datos sellados de una historia (al guardarla, al abrir su
  /// PDF o al importarlo). Lanza [FormatException] si no es una historia.
  Future<ResultadoRegistro> registrarHistoria(
    Map<String, Object?> datos, {
    required int revision,
    required OrigenArchivo origen,
    String nombreArchivo = '',
    Uint8List? bytesPdf,
  }) async {
    final ahora = reloj.ahora();
    final h = HistoriaClinica.desdeMapa(datos);
    final existente = _historias[h.id];
    // Se calcula antes, para comparar el contenido con el del índice.
    final candidato = RegistroHistoria.desdeDatos(
      datos,
      pacienteId: existente?.pacienteId ?? '',
      revision: revision,
      ahora: ahora,
    );
    final archivo = ArchivoHistoria(
      nombre: nombreArchivo,
      revision: revision,
      fecha: ahora,
      origen: origen,
      sha256Pdf: bytesPdf == null ? '' : sha256.convert(bytesPdf).toString(),
      hashFinal: candidato.hashFinal,
    );
    ResultadoRegistro resultado(
      TipoRegistro t,
      String pacienteId,
      bool nuevo,
    ) => ResultadoRegistro(
      tipo: t,
      historiaId: h.id,
      pacienteId: pacienteId,
      pacienteNuevo: nuevo,
      integridadCorrecta: candidato.integridadCorrecta,
      integridadDescripcion: candidato.integridadDescripcion,
    );

    if (existente != null && revision <= existente.revision) {
      final mismo =
          revision == existente.revision &&
          candidato.hashFinal == existente.hashFinal;
      final tipo = mismo
          ? TipoRegistro.yaEstaba
          : revision == existente.revision
          ? TipoRegistro.divergente
          : TipoRegistro.masVieja;
      final conocido = existente.archivos.any(
        (a) =>
            a.nombre == archivo.nombre &&
            a.revision == archivo.revision &&
            a.hashFinal == archivo.hashFinal,
      );
      var actualizado = existente;
      if (tipo == TipoRegistro.divergente &&
          !existente.divergencias.any(
            (a) => a.hashFinal == archivo.hashFinal,
          )) {
        actualizado = actualizado.copyWith(
          divergencias: [...existente.divergencias, archivo],
          actualizado: ahora,
        );
      } else if (!conocido && archivo.nombre.isNotEmpty) {
        actualizado = actualizado.copyWith(
          archivos: [...existente.archivos, archivo],
          actualizado: ahora,
        );
      }
      // Misma versión sin PDF guardado: se guarda el que llegó.
      if (mismo && !existente.tienePdf && bytesPdf != null) {
        await _repo.guardarBinario(
          RegistroHistoria.tipoBinarioPdf,
          h.id,
          bytesPdf,
        );
        actualizado = actualizado.copyWith(tienePdf: true, actualizado: ahora);
      }
      if (!identical(actualizado, existente)) {
        await _guardarHistoria(actualizado);
      }
      return resultado(tipo, existente.pacienteId, false);
    }

    // Nueva o más reciente: ficha, datos, PDF y registro.
    final (:ficha, nueva: pacienteNuevo) = _fichaPara(
      h.paciente,
      historiaId: existente == null ? null : h.id,
      sinDocumento: 'SIN:${h.id}',
      ahora: ahora,
    );
    await _repo.guardarBinario(
      RegistroHistoria.tipoBinarioDatos,
      h.id,
      Uint8List.fromList(utf8.encode(jsonEncode(datos))),
    );
    if (bytesPdf != null) {
      await _repo.guardarBinario(
        RegistroHistoria.tipoBinarioPdf,
        h.id,
        bytesPdf,
      );
    }
    final registro = candidato.copyWith(
      pacienteId: ficha.id,
      archivos: [
        ...?existente?.archivos,
        if (archivo.nombre.isNotEmpty) archivo,
      ],
      // Una revisión nueva sin PDF deja de tener «el PDF exacto».
      tienePdf: bytesPdf != null,
    );
    await _repo.guardarVarios([
      Escritura(FichaPaciente.coleccion, ficha.id, ficha.aMapa()),
      Escritura(RegistroHistoria.coleccion, registro.id, registro.aMapa()),
    ]);
    _ponerFicha(ficha);
    _ponerHistoria(registro);
    return resultado(
      existente == null ? TipoRegistro.nueva : TipoRegistro.actualizada,
      ficha.id,
      pacienteNuevo,
    );
  }

  Future<void> _guardarHistoria(RegistroHistoria r) async {
    await _repo.guardar(RegistroHistoria.coleccion, r.id, r.aMapa());
    _ponerHistoria(r);
  }

  /// Lee un PDF de la app y lo registra. Nunca lanza: el resultado dice qué
  /// pasó con ese archivo.
  Future<ResultadoImportacion> importarPdf(
    Uint8List bytes, {
    required String nombre,
    OrigenArchivo origen = OrigenArchivo.importado,
  }) async {
    final PaqueteHistoria paquete;
    try {
      paquete = leerHistoriaDePdf(bytes);
    } on LecturaHistoriaException catch (e) {
      return ResultadoImportacion(
        nombre: nombre,
        tipo: switch (e.fallo) {
          FalloLectura.noEsPdf ||
          FalloLectura.sinDatosDeLaApp => TipoImportacion.noEsDeLaApp,
          _ => TipoImportacion.danada,
        },
        mensaje: e.mensaje,
      );
    } catch (_) {
      return ResultadoImportacion(
        nombre: nombre,
        tipo: TipoImportacion.danada,
        mensaje: 'No se pudo leer el PDF.',
      );
    }
    try {
      final r = await registrarHistoria(
        paquete.datos,
        revision: paquete.revision,
        origen: origen,
        nombreArchivo: nombre,
        bytesPdf: bytes,
      );
      return ResultadoImportacion(
        nombre: nombre,
        tipo: r.integridadCorrecta
            ? TipoImportacion.registrada
            : TipoImportacion.alterada,
        mensaje: r.integridadCorrecta
            ? r.tipo.etiqueta
            : '${r.tipo.etiqueta} · ${r.integridadDescripcion}',
        registro: r,
      );
    } on FormatException {
      return ResultadoImportacion(
        nombre: nombre,
        tipo: TipoImportacion.noEsHistoria,
        mensaje:
            'Tiene datos de historiasclinicas.net, pero no es una historia '
            'clínica compatible.',
      );
    } on TypeError {
      return ResultadoImportacion(
        nombre: nombre,
        tipo: TipoImportacion.noEsHistoria,
        mensaje: 'Los datos de la historia están incompletos.',
      );
    }
  }

  /// Importa varios PDF uno tras otro, cediendo el hilo entre archivos para
  /// que la pantalla siga respondiendo. [alAvanzar] recibe cuántos van.
  Future<List<ResultadoImportacion>> importarVarios(
    List<({String nombre, Uint8List bytes})> archivos, {
    void Function(int hechos, int total)? alAvanzar,
  }) async {
    final resultados = <ResultadoImportacion>[];
    for (final (i, a) in archivos.indexed) {
      resultados.add(await importarPdf(a.bytes, nombre: a.nombre));
      alAvanzar?.call(i + 1, archivos.length);
      await Future<void>.delayed(Duration.zero);
    }
    final importadas = resultados.where((r) => r.importada).length;
    await registrarEnBitacora(
      _repo,
      AccionBitacora.importarPdf,
      fecha: reloj.ahora(),
      resumen: '$importadas de ${archivos.length} archivos',
    );
    return resultados;
  }

  Future<Uint8List?> datosSellados(String historiaId) async {
    final b = await _repo.leerBinario(
      RegistroHistoria.tipoBinarioDatos,
      historiaId,
    );
    return b;
  }

  /// Los datos sellados de la historia, para abrirla o continuarla.
  Future<Map<String, Object?>?> datosDe(String historiaId) async {
    final b = await datosSellados(historiaId);
    if (b == null) return null;
    return (jsonDecode(utf8.decode(b)) as Map).cast<String, Object?>();
  }

  /// El PDF exacto de la última revisión, si el índice lo guarda.
  Future<Uint8List?> pdfDe(String historiaId) =>
      _repo.leerBinario(RegistroHistoria.tipoBinarioPdf, historiaId);

  // ─────────────────────────── Recetas ───────────────────────────

  RegistroReceta? receta(String id) => _recetas[id];

  /// Recetas de la ficha (y de las unidas a ella), de la más reciente a la
  /// más vieja.
  List<RegistroReceta> recetasDe(String pacienteId) {
    final ids = idsUnidos(pacienteId);
    return _recetas.values.where((r) => ids.contains(r.pacienteId)).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  Future<Uint8List?> pdfReceta(String id) =>
      _repo.leerBinario(RegistroReceta.tipoBinarioPdf, id);

  /// Registra una receta emitida (impresa o guardada) para [paciente] con su
  /// PDF exacto. La misma receta otra vez reemplaza la anterior (el último
  /// PDF es el que vale). Devuelve la ficha.
  Future<String> registrarReceta({
    required String recetaId,
    required Paciente paciente,
    required DateTime fecha,
    required Uint8List bytesPdf,
    String? numero,
    String historiaId = '',
    List<String> items = const [],
    String indicaciones = '',
    String nombreArchivo = '',
  }) async {
    final ahora = reloj.ahora();
    final existente = _recetas[recetaId];
    final fichaExistente = existente == null
        ? null
        : _activa(_fichas[existente.pacienteId]);
    final (:ficha, :nueva) = fichaExistente != null
        ? (ficha: fichaExistente, nueva: false)
        : _fichaPara(
            paciente,
            historiaId: historiaId.isEmpty ? null : historiaId,
            sinDocumento: 'SIN:$recetaId',
            ahora: ahora,
          );
    final registro = RegistroReceta(
      id: recetaId,
      pacienteId: ficha.id,
      fecha: fecha,
      numero: numero,
      historiaId: historiaId,
      items: items,
      indicaciones: indicaciones,
      sha256Pdf: sha256.convert(bytesPdf).toString(),
      nombreArchivo: nombreArchivo,
      tienePdf: true,
      actualizado: ahora,
    );
    await _repo.guardarBinario(
      RegistroReceta.tipoBinarioPdf,
      recetaId,
      bytesPdf,
    );
    await _repo.guardarVarios([
      if (nueva) Escritura(FichaPaciente.coleccion, ficha.id, ficha.aMapa()),
      Escritura(RegistroReceta.coleccion, recetaId, registro.aMapa()),
    ]);
    if (nueva) _ponerFicha(ficha);
    _recetas[recetaId] = registro;
    return ficha.id;
  }

  // ─────────────────────────── Fichas ───────────────────────────

  /// Ficha creada a mano (sin historia).
  Future<FichaPaciente> crearFicha(FichaPaciente borrador) async {
    final ahora = reloj.ahora();
    final clave = claveDocumento(
      borrador.tipoDocumento,
      borrador.numeroDocumento,
    );
    if (clave != null && porClave(clave) != null) {
      throw StateError('Ya hay una ficha con ese documento.');
    }
    final id = nuevoUuid();
    final ficha =
        FichaPaciente(
          id: id,
          clave: clave ?? 'SIN:$id',
          creado: ahora,
          actualizado: ahora,
        ).copyWith(
          tipoDocumento: borrador.tipoDocumento,
          numeroDocumento: borrador.numeroDocumento,
          primerApellido: borrador.primerApellido,
          segundoApellido: borrador.segundoApellido,
          nombres: borrador.nombres,
          fechaNacimiento: borrador.fechaNacimiento,
          edadAproximada: borrador.edadAproximada,
          sexo: borrador.sexo,
          telefono: borrador.telefono,
          correo: borrador.correo,
          direccion: borrador.direccion,
          ciudad: borrador.ciudad,
          lineas: borrador.lineas,
          etiquetas: borrador.etiquetas,
        );
    await guardarFicha(ficha);
    return ficha;
  }

  /// Guarda los datos administrativos de la ficha (nunca toca lo sellado).
  Future<void> guardarFicha(FichaPaciente f) async {
    final clave = claveDocumento(f.tipoDocumento, f.numeroDocumento);
    final otra = clave == null ? null : porClave(clave);
    if (otra != null && otra.id != f.id) {
      throw StateError(
        'Ya hay otra ficha con ese documento: únelas en lugar de duplicarlas.',
      );
    }
    final ficha = f.copyWith(
      clave: clave ?? (f.clave.startsWith('SIN:') ? f.clave : 'SIN:${f.id}'),
      actualizado: reloj.ahora(),
    );
    await _repo.guardar(FichaPaciente.coleccion, ficha.id, ficha.aMapa());
    _ponerFicha(ficha);
  }

  /// Une [origenId] a [destinoId]: las historias pasan a la ficha destino,
  /// que suma las líneas y las etiquetas. La ficha origen queda marcada
  /// como unida (no se borra).
  Future<void> unirFichas(String origenId, String destinoId) async {
    if (origenId == destinoId) return;
    final origen = _fichas[origenId];
    final destino = _activa(_fichas[destinoId]);
    if (origen == null || destino == null || !origen.activa) {
      throw StateError('No se encontró la ficha.');
    }
    final ahora = reloj.ahora();
    final nuevoDestino = destino.copyWith(
      lineas: {...destino.lineas, ...origen.lineas},
      etiquetas: {...destino.etiquetas, ...origen.etiquetas}.toList(),
      notas: [
        destino.notas,
        origen.notas,
      ].where((n) => n.trim().isNotEmpty).join('\n\n'),
      autorizacionDatosId:
          destino.autorizacionDatosId ?? origen.autorizacionDatosId,
      actualizado: ahora,
    );
    final nuevoOrigen = origen.copyWith(
      unidaEn: destino.id,
      actualizado: ahora,
    );
    final movidas = [
      for (final h in _historias.values)
        if (h.pacienteId == origen.id)
          h.copyWith(pacienteId: destino.id, actualizado: ahora),
    ];
    await _repo.guardarVarios([
      Escritura(FichaPaciente.coleccion, nuevoDestino.id, nuevoDestino.aMapa()),
      Escritura(FichaPaciente.coleccion, nuevoOrigen.id, nuevoOrigen.aMapa()),
      for (final h in movidas)
        Escritura(RegistroHistoria.coleccion, h.id, h.aMapa()),
    ]);
    _ponerFicha(nuevoOrigen);
    _ponerFicha(nuevoDestino);
    for (final h in movidas) {
      _ponerHistoria(h);
    }
    await registrarEnBitacora(
      _repo,
      AccionBitacora.unirFichas,
      fecha: ahora,
      resumen: movidas.length == 1
          ? '1 historia movida'
          : '${movidas.length} historias movidas',
    );
  }

  // ─────────────────────────── Búsqueda ───────────────────────────

  /// Fichas activas que cumplen todos los filtros, de la atención más
  /// reciente a la más vieja (sin atención, al final y por nombre).
  List<ResumenPaciente> buscar({
    String texto = '',
    LineaAtencion? linea,
    Set<String> etiquetas = const {},
    FiltroUltimaAtencion? ultimaAtencion,
    bool soloControlesVencidos = false,
  }) {
    final ahora = reloj.ahora();
    final terminos = paraBuscar(
      texto,
    ).split(' ').where((t) => t.isNotEmpty).toList();
    final terminosDoc = [
      for (final t in terminos) documentoNormalizado(t).toLowerCase(),
    ];
    bool coincide(FichaPaciente f) {
      if (terminos.isEmpty) return true;
      final (:nombre, :documento) = _texto(f);
      for (final (i, t) in terminos.indexed) {
        final tDoc = terminosDoc[i];
        if (!nombre.contains(t) &&
            (tDoc.isEmpty || !documento.contains(tDoc))) {
          return false;
        }
      }
      return true;
    }

    final r = <ResumenPaciente>[];
    for (final f in fichasActivas) {
      if (linea != null && !f.lineas.contains(linea)) continue;
      if (!etiquetas.every(f.etiquetas.contains)) continue;
      if (!coincide(f)) continue;
      final res = resumen(f);
      final u = res.ultimaAtencion;
      if (ultimaAtencion != null) {
        if (u == null) continue;
        final dias = ahora.difference(u).inDays;
        final ok = ultimaAtencion == FiltroUltimaAtencion.masDeUnAnio
            ? dias > 366
            : dias <= ultimaAtencion.dias;
        if (!ok) continue;
      }
      if (soloControlesVencidos && !res.controlVencido(ahora)) continue;
      r.add(res);
    }
    r.sort((a, b) {
      final ua = a.ultimaAtencion;
      final ub = b.ultimaAtencion;
      if (ua != null && ub != null) return ub.compareTo(ua);
      if (ua != null) return -1;
      if (ub != null) return 1;
      return a.ficha.nombreCompleto.compareTo(b.ficha.nombreCompleto);
    });
    return r;
  }

  /// Etiquetas usadas en las fichas activas (para sugerirlas).
  List<String> get etiquetasUsadas =>
      ({for (final f in fichasActivas) ...f.etiquetas}.toList()..sort());

  int get controlesVencidos {
    final ahora = reloj.ahora();
    return fichasActivas.where((f) => resumen(f).controlVencido(ahora)).length;
  }
}
