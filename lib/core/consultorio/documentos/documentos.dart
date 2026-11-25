import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../ihce/reloj.dart';
import '../../integridad/json_canonico.dart';
import '../../models/mapa.dart';
import '../../models/medico.dart';
import '../../pais/perfil_pais.dart';
import '../../pdf/adjuntos_pdf.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../utils/fechas.dart';
import '../../utils/ids.dart';
import '../indice/indice_pacientes.dart';
import '../modelos/configuracion.dart';
import '../modelos/ficha_paciente.dart';
import '../reglas/documentos.dart';
import '../repositorio/bitacora.dart';
import '../repositorio/repositorio.dart';
import 'documento.dart';
import 'documento_clinico.dart';
import 'documento_pdf.dart';
import 'plantillas.dart';

/// Un documento recién firmado y su PDF (para descargarlo).
typedef DocumentoFirmado = ({DocumentoConsultorio documento, Uint8List pdf});

/// Plantillas y documentos del consultorio, descifrados mientras está
/// abierto.
class DocumentosConsultorio {
  DocumentosConsultorio(
    this._repo,
    this._indice, {
    this.reloj = const RelojSistema(),
  });

  final RepositorioConsultorio _repo;
  final IndicePacientes _indice;
  final Reloj reloj;

  static const coleccionConsecutivos = 'consecutivos';

  /// «S» en el equipo secundario: sus documentos llevan una serie propia
  /// («CIM-S000001») para no chocar con los del principal al combinar.
  String serie = '';

  /// Plantillas guardadas, por id (las demás son las de fábrica).
  final _plantillas = <String, Plantilla>{};
  final _documentos = <String, DocumentoConsultorio>{};

  Future<void> cargar() async {
    final plantillas = await _repo.leerColeccionTolerante(Plantilla.coleccion);
    final documentos = await _repo.leerColeccionTolerante(
      DocumentoConsultorio.coleccion,
    );
    olvidar();
    for (final e in plantillas.registros.entries) {
      try {
        final p = Plantilla.desdeMapa(e.key, e.value);
        _plantillas[p.id] = p;
      } on Object {
        // Una plantilla ilegible vuelve a la de fábrica (en borrador).
      }
    }
    for (final e in documentos.registros.entries) {
      try {
        _documentos[e.key] = DocumentoConsultorio.desdeMapa(e.key, e.value);
      } on Object {
        // Se ignora: su PDF, si se descargó, sigue siendo el original.
      }
    }
  }

  void olvidar() {
    _plantillas.clear();
    _documentos.clear();
  }

  // ─────────────────────────── Plantillas ───────────────────────────

  /// La plantilla guardada, o la de fábrica (versión 1 en borrador).
  Plantilla plantilla(TipoPlantilla tipo) =>
      _plantillas[tipo.name] ?? Plantilla.base(tipo);

  /// Una plantilla por su id (de fábrica o propia), o `null`.
  Plantilla? plantillaPorId(String id) {
    final guardada = _plantillas[id];
    if (guardada != null) return guardada;
    final fabrica = plantillasDeFabrica[id];
    if (fabrica != null) return fabrica;
    final tipo = TipoPlantilla.values.asNameMap()[id];
    return tipo == null ? null : Plantilla.base(tipo);
  }

  /// Las plantillas de [tipo]: las de fábrica en su orden y luego las
  /// propias, por nombre.
  List<Plantilla> plantillasDe(TipoPlantilla tipo) {
    if (!tipo.varias) return [plantilla(tipo)];
    return [
      for (final p in plantillasDeFabrica.values)
        if (p.tipo == tipo) _plantillas[p.id] ?? p,
      ...(_plantillas.values.where((p) => p.tipo == tipo && p.propia).toList()
        ..sort((a, b) => a.nombre.compareTo(b.nombre))),
    ];
  }

  Future<Plantilla> guardarBorrador(
    TipoPlantilla tipo, {
    required String titulo,
    required String cuerpo,
  }) => guardarBorradorDe(tipo.name, titulo: titulo, cuerpo: cuerpo);

  /// Guarda el texto de la plantilla [id] como borrador (la versión
  /// siguiente si la última está aprobada). [nombre] solo cambia el de las
  /// plantillas propias.
  Future<Plantilla> guardarBorradorDe(
    String id, {
    required String titulo,
    required String cuerpo,
    String? nombre,
  }) async {
    final actual = plantillaPorId(id);
    if (actual == null) throw StateError('No existe la plantilla.');
    if (titulo.trim().isEmpty || cuerpo.trim().isEmpty) {
      throw StateError('Escribe el título y el texto.');
    }
    final p = actual.conBorrador(
      titulo.trim(),
      cuerpo.trim(),
      nombre: actual.propia && (nombre?.trim().isNotEmpty ?? false)
          ? nombre!.trim()
          : null,
    );
    await _repo.guardar(Plantilla.coleccion, p.id, p.aMapa());
    _plantillas[p.id] = p;
    return p;
  }

  /// Aprueba el borrador: desde ahora los documentos nuevos usan esa
  /// versión. Los firmados conservan la suya.
  Future<Plantilla> aprobar(TipoPlantilla tipo) => aprobarDe(tipo.name);

  Future<Plantilla> aprobarDe(String id) async {
    final actual = plantillaPorId(id);
    if (actual == null) throw StateError('No existe la plantilla.');
    final ahora = reloj.ahora();
    final p = actual.aprobada(ahora);
    await _repo.guardar(Plantilla.coleccion, p.id, p.aMapa());
    _plantillas[p.id] = p;
    await registrarEnBitacora(
      _repo,
      AccionBitacora.aprobarPlantilla,
      fecha: ahora,
      resumen: '${p.tipo.etiqueta} · ${p.nombre} v${p.vigente!.version}',
    );
    return p;
  }

  /// Agrega una plantilla propia de [tipo] (por ejemplo, otra orden
  /// frecuente), en borrador con el texto base del tipo.
  Future<Plantilla> crearPlantilla(TipoPlantilla tipo, String nombre) async {
    if (!tipo.varias) {
      throw StateError('«${tipo.etiqueta}» tiene una sola plantilla.');
    }
    final n = nombre.trim();
    if (n.isEmpty) throw StateError('Escribe el nombre de la plantilla.');
    if (plantillasDe(
      tipo,
    ).any((p) => p.nombre.toLowerCase() == n.toLowerCase())) {
      throw StateError('Ya hay una plantilla «$n».');
    }
    final p = Plantilla.nueva(
      tipo,
      id: '${tipo.name}_${nuevoUuid().substring(0, 8)}',
      nombre: n,
    );
    await _repo.guardar(Plantilla.coleccion, p.id, p.aMapa());
    _plantillas[p.id] = p;
    return p;
  }

  // ─────────────────────────── Documentos ───────────────────────────

  DocumentoConsultorio? documento(String id) => _documentos[id];

  /// Documentos de la ficha (y de las fichas unidas a ella), del más
  /// reciente al más viejo.
  List<DocumentoConsultorio> documentosDe(String pacienteId) {
    final ids = _indice.idsUnidos(pacienteId);
    return _documentos.values
        .where((d) => ids.contains(d.fichaEfectiva))
        .toList()
      ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
  }

  /// El consentimiento de imagen vigente de la ficha (con el uso clínico),
  /// o `null`: sin él no se toman fotos (pregunta 22).
  DocumentoConsultorio? consentimientoImagenVigente(FichaPaciente ficha) {
    final id = (_indice.fichaActiva(ficha.id) ?? ficha).consentimientoImagenId;
    final d = id == null ? null : _documentos[id];
    return d != null && d.vigente && d.permisos.clinico ? d : null;
  }

  Future<Uint8List?> pdfDe(String id) =>
      _repo.leerBinario(DocumentoConsultorio.tipoBinarioPdf, id);

  /// Siguiente número del consecutivo [prefijo] («AD-000001»). Se asigna al
  /// firmar y no se reutiliza, aunque el documento se anule.
  Future<String> _siguienteNumero(String prefijo) async {
    final clave = '$prefijo$serie';
    final r = await _repo.leer(coleccionConsecutivos, clave);
    final n = (r?.entero('ultimo') ?? 0) + 1;
    await _repo.guardar(coleccionConsecutivos, clave, {'ultimo': n});
    return '$prefijo-$serie${n.toString().padLeft(6, '0')}';
  }

  /// Valores de los marcadores de las plantillas.
  Map<String, String> valores(
    Medico medico, {
    FichaPaciente? ficha,
    required DateTime fecha,
  }) => {
    'medico': medico.nombre.trim(),
    if (ficha?.edadAnios(fecha) case final edad?)
      'edad': '$edad ${edad == 1 ? 'año' : 'años'}',
    'responsable': [
      medico.nombre.trim(),
      if (medico.consultorio.trim().isNotEmpty) medico.consultorio.trim(),
    ].where((s) => s.isNotEmpty).join(' · '),
    'documentoResponsable': [
      medico.tipoDocumento,
      medico.documento,
    ].where((s) => s.trim().isNotEmpty).join(' '),
    'direccion': medico.direccion,
    'ciudad': medico.ciudad,
    'telefono': medico.telefono,
    'correo': medico.correo,
    'registroMedico': medico.registro.trim().isEmpty
        ? ''
        : 'registro profesional ${medico.registro.trim()}',
    if (ficha != null) 'paciente': ficha.nombreCompleto,
    if (ficha != null) 'documentoPaciente': ficha.documentoTexto,
    'fecha': formatoFecha(fecha),
  };

  /// Firma la autorización de tratamiento de datos de [ficha].
  Future<DocumentoFirmado> firmarAutorizacion({
    required FichaPaciente ficha,
    required Uint8List firmaPng,
    required Medico medico,
    required Pais pais,
    bool incluirFirma = true,
    bool incluirSello = true,
    FuentesPdf? fuentes,
  }) => firmarDocumento(
    TipoPlantilla.autorizacionDatos,
    ficha: ficha,
    firmaPng: firmaPng,
    medico: medico,
    pais: pais,
    incluirFirma: incluirFirma,
    incluirSello: incluirSello,
    fuentes: fuentes,
  );

  /// Firma un documento de [tipo] para [ficha] con la plantilla vigente.
  /// Guarda el documento, la firma y el PDF (cifrados) y lo deja ligado a
  /// la ficha. El consentimiento de imagen exige [permisos] con el uso
  /// clínico. Lanza [StateError] si la plantilla no está aprobada.
  Future<DocumentoFirmado> firmarDocumento(
    TipoPlantilla tipo, {
    required FichaPaciente ficha,
    required Uint8List firmaPng,
    required Medico medico,
    required Pais pais,
    PermisosImagen? permisos,
    Map<String, String> valoresExtra = const {},
    Map<String, Object?> datosExtra = const {},
    bool incluirFirma = true,
    bool incluirSello = true,
    FuentesPdf? fuentes,
  }) async {
    if (!tipo.conFirmaDelPaciente) {
      throw StateError('«${tipo.etiqueta}» no se firma con el paciente.');
    }
    final imagen = tipo == TipoPlantilla.consentimientoImagen;
    if (imagen && !(permisos?.clinico ?? false)) {
      throw StateError(
        'El consentimiento de imagen necesita, al menos, el uso clínico.',
      );
    }
    final version = plantilla(tipo).vigente;
    if (version == null) {
      throw StateError(
        'La plantilla «${tipo.etiqueta}» está en borrador: revísala y '
        'apruébala en Ajustes.',
      );
    }
    final ahora = reloj.ahora();
    final numero = await _siguienteNumero(tipo.prefijo!);
    final id = nuevoUuid();
    final copia = instantaneaMedico(
      medico,
      pais: pais,
      firma: incluirFirma,
      sello: incluirSello,
    );
    final contenido = rellenarPlantilla(version.cuerpo, {
      ...valores(medico, ficha: ficha, fecha: ahora),
      ...valoresExtra,
      if (imagen) 'permisos': permisos!.texto,
    });
    final documento = DocumentoConsultorio(
      id: id,
      creado: ahora,
      tienePdf: true,
      datos: {
        'tipo': tipo.name,
        'numero': numero,
        'titulo': version.titulo,
        'versionPlantilla': version.version,
        'pacienteId': ficha.id,
        'paciente': {
          'nombre': ficha.nombreCompleto,
          'documento': ficha.documentoTexto,
        },
        'fechaHora': fechaHoraIso(ahora),
        'contenido': contenido,
        'sha256Firma': sha256.convert(firmaPng).toString(),
        if (imagen) 'permisos': permisos!.aMapa(),
        ...datosExtra,
        if (medico.configurado) 'autor': copia.autor,
      },
    );
    final pdf = await generarPdfDocumento(
      ContenidoDocumentoPdf(
        titulo: version.titulo,
        cuerpo: contenido,
        fechaHora: ahora,
        numero: numero,
        version: version.version,
        paciente: ficha.nombreCompleto,
        documentoPaciente: ficha.documentoTexto,
        firmaPaciente: firmaPng,
        medico: medico.configurado ? Autor.desdeMapa(copia.autor) : null,
        recursos: copia.recursos,
        adjuntos: [AdjuntoPdf(nombreAdjuntoDocumento, documento.json)],
        huella: documento.hash,
      ),
      fuentes: fuentes,
    );
    await _repo.guardarBinario(
      DocumentoConsultorio.tipoBinarioFirma,
      id,
      firmaPng,
    );
    await _repo.guardarBinario(DocumentoConsultorio.tipoBinarioPdf, id, pdf);
    await _repo.guardar(DocumentoConsultorio.coleccion, id, documento.aMapa());
    _documentos[id] = documento;
    final actual = _indice.fichaActiva(ficha.id) ?? ficha;
    if (imagen) {
      await _indice.guardarFicha(actual.copyWith(consentimientoImagenId: id));
    } else if (tipo == TipoPlantilla.autorizacionDatos) {
      await _indice.guardarFicha(actual.copyWith(autorizacionDatosId: id));
    }
    await registrarEnBitacora(
      _repo,
      AccionBitacora.firmarDocumento,
      fecha: ahora,
      resumen: numero,
    );
    return (documento: documento, pdf: pdf);
  }

  // ──────────────────────── Documentos clínicos ────────────────────────

  /// Borrador de un documento clínico de [tipo] para [ficha] con la
  /// plantilla [plantillaId] (o la primera del tipo): el texto ya lleva los
  /// datos del paciente y los tuyos. Usa la versión aprobada; sin ella, la
  /// última (para verla, pero no se puede emitir).
  BorradorDocumento nuevoBorrador(
    TipoPlantilla tipo, {
    required FichaPaciente ficha,
    required Medico medico,
    String? plantillaId,
  }) {
    final ahora = reloj.ahora();
    final base = BorradorDocumento(
      tipo: tipo,
      plantillaId: '',
      versionPlantilla: 0,
      titulo: tipo.etiqueta,
      texto: '',
      desde: DateTime(ahora.year, ahora.month, ahora.day),
    );
    return conPlantilla(
      base,
      plantillaId ?? plantillasDe(tipo).first.id,
      ficha: ficha,
      medico: medico,
    );
  }

  /// [b] con el texto de otra plantilla (los demás campos se conservan).
  BorradorDocumento conPlantilla(
    BorradorDocumento b,
    String plantillaId, {
    required FichaPaciente ficha,
    required Medico medico,
  }) {
    final p = plantillaPorId(plantillaId);
    if (p == null || p.tipo != b.tipo) {
      throw StateError('La plantilla no es de «${b.tipo.etiqueta}».');
    }
    final v = p.vigente ?? p.ultima;
    return b.copyWith(
      plantillaId: p.id,
      versionPlantilla: v.version,
      titulo: v.titulo,
      texto: rellenarPlantilla(
        v.cuerpo,
        valores(medico, ficha: ficha, fecha: reloj.ahora()),
      ),
    );
  }

  /// Prestador para el bloque de datos de la incapacidad.
  static PrestadorDocumento prestador(
    Medico medico,
    ConfiguracionConsultorio c,
  ) => PrestadorDocumento(
    nombre: medico.consultorio.trim().isNotEmpty
        ? medico.consultorio.trim()
        : medico.nombre.trim(),
    nit: c.nit,
    codigoReps: c.codigoReps,
  );

  /// Las reglas del documento con la plantilla y tus datos de hoy.
  EvaluacionDocumento evaluar(
    BorradorDocumento b, {
    required Medico medico,
    required ConfiguracionConsultorio configuracion,
  }) {
    final p = plantillaPorId(b.plantillaId);
    final e = evaluarDocumento(
      b,
      plantilla: p ?? Plantilla.base(b.tipo),
      configuracion: configuracion,
      medicoListo: medico.configurado && medico.registro.trim().isNotEmpty,
      ahora: reloj.ahora(),
    );
    final aprobada =
        p?.versiones.any(
          (v) => v.version == b.versionPlantilla && v.aprobada,
        ) ??
        false;
    if (e.permiteEmitir && !aprobada) {
      return EvaluacionDocumento(
        bloqueos: [
          'El texto viene de un borrador de la plantilla: vuelve a elegirla.',
        ],
        avisos: e.avisos,
      );
    }
    return e;
  }

  /// El número que llevará el próximo documento de [tipo] (sin gastarlo).
  Future<String> proximoNumero(TipoPlantilla tipo) async {
    final clave = '${tipo.prefijo}$serie';
    final r = await _repo.leer(coleccionConsecutivos, clave);
    final n = (r?.entero('ultimo') ?? 0) + 1;
    return '${tipo.prefijo}-$serie${n.toString().padLeft(6, '0')}';
  }

  ContenidoDocumentoPdf _contenidoClinico(
    BorradorDocumento b, {
    required FichaPaciente ficha,
    required Medico medico,
    required Pais pais,
    required ConfiguracionConsultorio configuracion,
    required DateTime fecha,
    required String numero,
    bool incluirFirma = true,
    bool incluirSello = true,
    String? huella,
    List<AdjuntoPdf> adjuntos = const [],
  }) {
    final copia = instantaneaMedico(
      medico,
      pais: pais,
      firma: incluirFirma,
      sello: incluirSello,
    );
    return ContenidoDocumentoPdf(
      titulo: b.titulo,
      cuerpo: b.texto.trim(),
      fechaHora: fecha,
      numero: numero,
      version: b.versionPlantilla,
      paciente: ficha.nombreCompleto,
      documentoPaciente: ficha.documentoTexto,
      medico: medico.configurado ? Autor.desdeMapa(copia.autor) : null,
      recursos: copia.recursos,
      filas: filasDocumento(b, prestador: prestador(medico, configuracion)),
      conFirmaPaciente: false,
      adjuntos: adjuntos,
      huella: huella,
    );
  }

  /// El PDF tal como saldría ahora, con el próximo número, para la vista
  /// previa. No guarda nada.
  Future<Uint8List> vistaPrevia(
    BorradorDocumento b, {
    required FichaPaciente ficha,
    required Medico medico,
    required Pais pais,
    required ConfiguracionConsultorio configuracion,
    bool incluirFirma = true,
    bool incluirSello = true,
    FuentesPdf? fuentes,
  }) async => generarPdfDocumento(
    _contenidoClinico(
      b,
      ficha: ficha,
      medico: medico,
      pais: pais,
      configuracion: configuracion,
      fecha: reloj.ahora(),
      numero: await proximoNumero(b.tipo),
      incluirFirma: incluirFirma,
      incluirSello: incluirSello,
    ),
    fuentes: fuentes,
  );

  /// Emite el documento clínico [b]: le da el número siguiente, sella
  /// `documento.json` dentro del PDF y guarda los dos (cifrados). Lanza
  /// [StateError] con el primer bloqueo de las reglas.
  Future<DocumentoFirmado> emitirDocumento(
    BorradorDocumento b, {
    required FichaPaciente ficha,
    required Medico medico,
    required Pais pais,
    required ConfiguracionConsultorio configuracion,
    bool incluirFirma = true,
    bool incluirSello = true,
    FuentesPdf? fuentes,
  }) async {
    final e = evaluar(b, medico: medico, configuracion: configuracion);
    if (!e.permiteEmitir) throw StateError(e.bloqueos.first);
    final ahora = reloj.ahora();
    final numero = await _siguienteNumero(b.tipo.prefijo!);
    final id = nuevoUuid();
    final copia = instantaneaMedico(
      medico,
      pais: pais,
      firma: incluirFirma,
      sello: incluirSello,
    );
    final edad = ficha.edadAnios(ahora);
    final pres = prestador(medico, configuracion);
    final documento = DocumentoConsultorio(
      id: id,
      creado: ahora,
      tienePdf: true,
      datos: {
        'tipo': b.tipo.name,
        'numero': numero,
        'titulo': b.titulo,
        'plantillaId': b.plantillaId,
        'versionPlantilla': b.versionPlantilla,
        'pacienteId': ficha.id,
        'paciente': compacto({
          'nombre': ficha.nombreCompleto,
          'documento': ficha.documentoTexto,
          'edad': edad,
        }),
        'fechaHora': fechaHoraIso(ahora),
        'contenido': b.texto.trim(),
        'campos': {
          ...b.campos(),
          if (b.tipo == TipoPlantilla.incapacidad && pres.texto.isNotEmpty)
            'prestador': compacto({
              'nombre': pres.nombre,
              'nit': pres.nit.trim(),
              'codigoReps': pres.codigoReps.trim(),
            }),
        },
        if (medico.configurado) 'autor': copia.autor,
      },
    );
    final pdf = await generarPdfDocumento(
      _contenidoClinico(
        b,
        ficha: ficha,
        medico: medico,
        pais: pais,
        configuracion: configuracion,
        fecha: ahora,
        numero: numero,
        incluirFirma: incluirFirma,
        incluirSello: incluirSello,
        huella: documento.hash,
        adjuntos: [AdjuntoPdf(nombreAdjuntoDocumento, documento.json)],
      ),
      fuentes: fuentes,
    );
    await _repo.guardarBinario(DocumentoConsultorio.tipoBinarioPdf, id, pdf);
    await _repo.guardar(DocumentoConsultorio.coleccion, id, documento.aMapa());
    _documentos[id] = documento;
    await registrarEnBitacora(
      _repo,
      AccionBitacora.emitirDocumento,
      fecha: ahora,
      resumen: numero,
    );
    return (documento: documento, pdf: pdf);
  }

  // ──────────────────────── Importar y verificar ────────────────────────

  /// Importa (o verifica) un documento de la app con su `documento.json` ya
  /// leído. Si ya está, comprueba que sea el mismo; si no, lo agrega a la
  /// ficha del paciente con su PDF exacto. Nunca lanza.
  Future<ResultadoImportacion> importarPdf(
    Uint8List bytes, {
    required String nombre,
    required Map<String, Object?> datos,
    required bool integro,
  }) async {
    final numero = datos.texto('numero');
    final tipo = TipoPlantilla.values.asNameMap()[datos.texto('tipo')];
    if (!integro) {
      return ResultadoImportacion(
        nombre: nombre,
        tipo: TipoImportacion.rechazada,
        mensaje:
            'Los datos del documento ${numero.isEmpty ? '' : '$numero '}no '
            'coinciden con su huella: el archivo se modificó. No se importó.',
      );
    }
    if (tipo == null || tipo.prefijo == null || numero.isEmpty) {
      return ResultadoImportacion(
        nombre: nombre,
        tipo: TipoImportacion.noEsHistoria,
        mensaje: 'Tiene datos de la app, pero no es un documento compatible.',
      );
    }
    final hash = sha256Canonico(datos);
    final existente = _documentos.values
        .where((d) => d.numero == numero)
        .firstOrNull;
    if (existente != null) {
      if (existente.hash != hash) {
        return ResultadoImportacion(
          nombre: nombre,
          tipo: TipoImportacion.rechazada,
          mensaje:
              'Ya hay un $numero distinto en el consultorio: este PDF no '
              'coincide con el registrado. No se importó.',
        );
      }
      if (!existente.tienePdf) {
        await _repo.guardarBinario(
          DocumentoConsultorio.tipoBinarioPdf,
          existente.id,
          bytes,
        );
        final con = existente.copyWith(tienePdf: true);
        await _repo.guardar(
          DocumentoConsultorio.coleccion,
          con.id,
          con.aMapa(),
        );
        _documentos[con.id] = con;
      }
      return ResultadoImportacion(
        nombre: nombre,
        tipo: TipoImportacion.registrada,
        mensaje: 'Ya estaba, íntegro · $numero',
        pacienteId: existente.fichaEfectiva,
      );
    }
    final paciente = datos.mapa('paciente');
    final ficha = _indice.fichaParaAdjunto(
      pacienteId: datos.texto('pacienteId'),
      documento: paciente.texto('documento'),
    );
    if (ficha == null) {
      final quien = paciente.texto('nombre');
      return ResultadoImportacion(
        nombre: nombre,
        tipo: TipoImportacion.sinFicha,
        mensaje:
            'No hay una ficha de ${quien.isEmpty ? 'este paciente' : '«$quien»'}: '
            'importa primero su historia o crea su ficha.',
      );
    }
    final id = nuevoUuid();
    final documento = DocumentoConsultorio(
      id: id,
      datos: datos,
      creado: reloj.ahora(),
      tienePdf: true,
      fichaId: ficha.id == datos.texto('pacienteId') ? null : ficha.id,
    );
    await _repo.guardarBinario(DocumentoConsultorio.tipoBinarioPdf, id, bytes);
    await _repo.guardar(DocumentoConsultorio.coleccion, id, documento.aMapa());
    _documentos[id] = documento;
    await _alcanzarConsecutivo(numero);
    if (tipo == TipoPlantilla.autorizacionDatos &&
        ficha.autorizacionDatosId == null) {
      await _indice.guardarFicha(ficha.copyWith(autorizacionDatosId: id));
    } else if (tipo == TipoPlantilla.consentimientoImagen &&
        documento.permisos.clinico &&
        ficha.consentimientoImagenId == null) {
      await _indice.guardarFicha(ficha.copyWith(consentimientoImagenId: id));
    }
    return ResultadoImportacion(
      nombre: nombre,
      tipo: TipoImportacion.registrada,
      mensaje: 'Documento nuevo · $numero',
      pacienteId: ficha.id,
    );
  }

  /// Un documento importado de este equipo («CE-000007») con un número
  /// mayor que el consecutivo lo adelanta: así el siguiente no lo repite.
  Future<void> _alcanzarConsecutivo(String numero) async {
    final m = RegExp(r'^([A-Z]+)-([A-Z]*)(\d+)$').firstMatch(numero);
    if (m == null || m.group(2) != serie) return;
    final clave = '${m.group(1)}$serie';
    final n = int.parse(m.group(3)!);
    final r = await _repo.leer(coleccionConsecutivos, clave);
    if (n > (r?.entero('ultimo') ?? 0)) {
      await _repo.guardar(coleccionConsecutivos, clave, {'ultimo': n});
    }
  }

  /// PDF de la política de tratamiento de datos (versión vigente), para
  /// imprimir y exhibir. Lanza [StateError] si no está aprobada.
  Future<Uint8List> politicaPdf({
    required Medico medico,
    required Pais pais,
    FuentesPdf? fuentes,
  }) async {
    const tipo = TipoPlantilla.politicaPrivacidad;
    final version = plantilla(tipo).vigente;
    if (version == null) {
      throw StateError(
        'La política está en borrador: revísala y apruébala en Ajustes.',
      );
    }
    final copia = instantaneaMedico(medico, pais: pais);
    return generarPdfDocumento(
      ContenidoDocumentoPdf(
        titulo: version.titulo,
        cuerpo: rellenarPlantilla(
          version.cuerpo,
          valores(medico, fecha: version.aprobadaEn!),
        ),
        fechaHora: version.aprobadaEn!,
        version: version.version,
        medico: medico.configurado ? Autor.desdeMapa(copia.autor) : null,
        recursos: copia.recursos,
      ),
      fuentes: fuentes,
    );
  }

  /// Revoca (el paciente retira la autorización) o anula (un error) un
  /// documento. No se borra: queda con fecha y motivo. Si era la
  /// autorización vigente de la ficha, la ficha queda sin autorización.
  Future<void> cambiarEstado(
    String id,
    EstadoDocumento estado, {
    required String motivo,
  }) async {
    final d = _documentos[id];
    if (d == null || !d.vigente || estado == EstadoDocumento.vigente) {
      throw StateError('El documento no está vigente.');
    }
    if (motivo.trim().isEmpty) throw StateError('Escribe el motivo.');
    final ahora = reloj.ahora();
    final nuevo = d.copyWith(
      estado: estado,
      cambioEstado: ahora,
      motivoEstado: motivo.trim(),
    );
    await _repo.guardar(DocumentoConsultorio.coleccion, id, nuevo.aMapa());
    _documentos[id] = nuevo;
    final activa = _indice.fichaActiva(d.fichaEfectiva);
    if (activa != null && activa.autorizacionDatosId == id) {
      await _indice.guardarFicha(activa.copyWith(autorizacionDatosId: null));
    }
    if (activa != null && activa.consentimientoImagenId == id) {
      await _indice.guardarFicha(activa.copyWith(consentimientoImagenId: null));
    }
    await registrarEnBitacora(
      _repo,
      estado == EstadoDocumento.revocado
          ? AccionBitacora.revocarDocumento
          : AccionBitacora.anularDocumento,
      fecha: ahora,
      resumen: d.numero,
    );
  }
}
