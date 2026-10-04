/// Registros persistidos del módulo IHCE. Son las «tablas» del esquema
/// lógico (`ihce_rda_documento`, `ihce_rda_nodo`, `ihce_rda_arista`,
/// `ihce_transmision_intento`) traducidas a colecciones del almacén local,
/// con las mismas claves e índices (ver `repositorio_ihce.dart`).
library;

import '../perfiles/perfiles_rda.g.dart';

enum TipoRda {
  consulta('enviar-rda-consulta', 'BundleAmbulatoryRDA'),
  urgencias('enviar-rda-urgencias', 'BundleEmergencyRDA'),
  hospitalizacion('enviar-rda-hospitalizacion', 'BundleHospitalizationRDA'),
  paciente('enviar-rda-paciente', 'BundlePatientStatementRDA');

  const TipoRda(this.operacion, this.perfilBundle);

  /// Nombre de la operación (colección Postman v1.5), sin el `$`.
  final String operacion;
  final String perfilBundle;

  /// Solo estos tipos devuelven VIDA (Anexo Técnico, definición de VIDA).
  bool get conVida => this != paciente;

  static TipoRda desdeNombre(String n) => values.firstWhere((t) => t.name == n);
}

/// Máquina de estados del documento (Fase 6).
enum EstadoDocumento {
  pendiente,
  construido,
  validado,
  firmado,
  enviando,
  sinTransporte,
  aceptado,
  aceptadoSinVida,
  rechazado,
  duplicado,
  errorAuth,
  reintentoProgramado,
  agotado,
  invalidoLocal,
  errorInterno;

  static EstadoDocumento desdeNombre(String n) =>
      values.firstWhere((e) => e.name == n);

  /// Transiciones permitidas. «Cualquier etapa local» puede ir a
  /// [invalidoLocal] o [errorInterno].
  static const _siguientes = <EstadoDocumento, Set<EstadoDocumento>>{
    pendiente: {construido},
    construido: {validado},
    validado: {firmado},
    firmado: {enviando, sinTransporte},
    sinTransporte: {enviando},
    enviando: {
      aceptado,
      aceptadoSinVida,
      rechazado,
      duplicado,
      errorAuth,
      reintentoProgramado,
      agotado,
    },
    reintentoProgramado: {enviando, sinTransporte},
  };

  static const _locales = {
    pendiente,
    construido,
    validado,
    firmado,
    enviando,
    sinTransporte,
    reintentoProgramado,
  };

  bool puedePasarA(EstadoDocumento otro) =>
      (_siguientes[this]?.contains(otro) ?? false) ||
      (_locales.contains(this) &&
          (otro == invalidoLocal || otro == errorInterno));

  bool get terminal => const {
    aceptado,
    aceptadoSinVida,
    rechazado,
    duplicado,
    errorAuth,
    agotado,
    invalidoLocal,
    errorInterno,
  }.contains(this);

  /// Estados que una persona puede corregir y reintentar (regla 10, c).
  bool get corregible => this == rechazado || this == invalidoLocal;
}

/// Una `issue` de un `OperationOutcome` (o un hallazgo local con la misma
/// forma).
class IhceIssue {
  const IhceIssue({
    required this.severity,
    required this.code,
    this.detailsText,
    this.diagnostics,
    this.location = const [],
    this.expression = const [],
    this.nodoLocal,
  });

  factory IhceIssue.desdeMapa(Map<String, Object?> m) => IhceIssue(
    severity: m['severity'] as String? ?? 'error',
    code: m['code'] as String? ?? 'unknown',
    detailsText: m['details_text'] as String?,
    diagnostics: m['diagnostics'] as String?,
    location: [for (final x in (m['location'] as List?) ?? const []) '$x'],
    expression: [for (final x in (m['expression'] as List?) ?? const []) '$x'],
    nodoLocal: m['nodo_local'] as String?,
  );

  final String severity;
  final String code;
  final String? detailsText;
  final String? diagnostics;
  final List<String> location;
  final List<String> expression;

  /// `id_local` del nodo del grafo al que apunta `location`/`expression`.
  final String? nodoLocal;

  bool get esError => severity == 'error' || severity == 'fatal';

  IhceIssue conNodo(String? nodo) => IhceIssue(
    severity: severity,
    code: code,
    detailsText: detailsText,
    diagnostics: diagnostics,
    location: location,
    expression: expression,
    nodoLocal: nodo,
  );

  Map<String, Object?> aMapa() => {
    'severity': severity,
    'code': code,
    'details_text': ?detailsText,
    'diagnostics': ?diagnostics,
    if (location.isNotEmpty) 'location': location,
    if (expression.isNotEmpty) 'expression': expression,
    'nodo_local': ?nodoLocal,
  };
}

/// `ihce_rda_documento`.
class DocumentoRda {
  const DocumentoRda({
    required this.id,
    required this.tenantId,
    required this.atencionId,
    required this.tipoRda,
    required this.versionDoc,
    required this.estado,
    required this.creadoEn,
    required this.actualizadoEn,
    this.compilacionGuia = GuiaRda.compilacion,
    this.bundleIdentifier,
    this.bundleSha256,
    this.bundleCifrado,
    this.vida,
    this.idCompositionIhce,
    this.advertencias = const [],
    this.issues = const [],
    this.intentos = 0,
    this.proximoIntentoEn,
    this.ultimoHttpStatus,
    this.aceptadoEn,
    this.motivo,
    this.categoria,
    this.shaUltimoEnvio,
  });

  factory DocumentoRda.desdeMapa(Map<String, Object?> m) {
    DateTime? f(String k) =>
        m[k] == null ? null : DateTime.parse(m[k]! as String);
    List<IhceIssue> l(String k) => [
      for (final x in (m[k] as List?) ?? const [])
        IhceIssue.desdeMapa((x as Map).cast()),
    ];
    return DocumentoRda(
      id: m['id']! as String,
      tenantId: m['tenant_id']! as String,
      atencionId: m['atencion_id']! as String,
      tipoRda: TipoRda.desdeNombre(m['tipo_rda']! as String),
      versionDoc: m['version_doc']! as int,
      compilacionGuia: m['compilacion_guia']! as String,
      estado: EstadoDocumento.desdeNombre(m['estado']! as String),
      bundleIdentifier: m['bundle_identifier'] as String?,
      bundleSha256: m['bundle_sha256'] as String?,
      bundleCifrado: m['bundle_cifrado'] as String?,
      vida: m['vida'] as String?,
      idCompositionIhce: m['id_composition_ihce'] as String?,
      advertencias: l('advertencias_json'),
      issues: l('issues_json'),
      intentos: m['intentos'] as int? ?? 0,
      proximoIntentoEn: f('proximo_intento_en'),
      ultimoHttpStatus: m['ultimo_http_status'] as int?,
      creadoEn: f('creado_en')!,
      actualizadoEn: f('actualizado_en')!,
      aceptadoEn: f('aceptado_en'),
      motivo: m['motivo'] as String?,
      categoria: m['categoria'] as String?,
      shaUltimoEnvio: m['sha_ultimo_envio'] as String?,
    );
  }

  final String id;
  final String tenantId;

  /// `historia.id` de la atención: el `Encounter` raíz local.
  final String atencionId;
  final TipoRda tipoRda;
  final int versionDoc;
  final String compilacionGuia;
  final EstadoDocumento estado;
  final String? bundleIdentifier;
  final String? bundleSha256;

  /// Bytes enviados (canonicalizados, validados y firmados), cifrados.
  final String? bundleCifrado;

  /// Valor opaco: se guarda y compara byte a byte.
  final String? vida;
  final String? idCompositionIhce;
  final List<IhceIssue> advertencias;

  /// Hallazgos del último rechazo o bloqueo local.
  final List<IhceIssue> issues;
  final int intentos;
  final DateTime? proximoIntentoEn;
  final int? ultimoHttpStatus;
  final DateTime creadoEn;
  final DateTime actualizadoEn;
  final DateTime? aceptadoEn;

  /// Motivo en lenguaje llano (sin datos del paciente ni payload).
  final String? motivo;

  /// Categoría del último resultado (SINTACTICO, SEMANTICO, …).
  final String? categoria;
  final String? shaUltimoEnvio;

  DocumentoRda copyWith({
    EstadoDocumento? estado,
    String? bundleIdentifier,
    String? bundleSha256,
    String? bundleCifrado,
    String? vida,
    String? idCompositionIhce,
    List<IhceIssue>? advertencias,
    List<IhceIssue>? issues,
    int? intentos,
    Object? proximoIntentoEn = _sin,
    int? ultimoHttpStatus,
    DateTime? actualizadoEn,
    DateTime? aceptadoEn,
    Object? motivo = _sin,
    Object? categoria = _sin,
    String? shaUltimoEnvio,
  }) => DocumentoRda(
    id: id,
    tenantId: tenantId,
    atencionId: atencionId,
    tipoRda: tipoRda,
    versionDoc: versionDoc,
    compilacionGuia: compilacionGuia,
    estado: estado ?? this.estado,
    bundleIdentifier: bundleIdentifier ?? this.bundleIdentifier,
    bundleSha256: bundleSha256 ?? this.bundleSha256,
    bundleCifrado: bundleCifrado ?? this.bundleCifrado,
    vida: vida ?? this.vida,
    idCompositionIhce: idCompositionIhce ?? this.idCompositionIhce,
    advertencias: advertencias ?? this.advertencias,
    issues: issues ?? this.issues,
    intentos: intentos ?? this.intentos,
    proximoIntentoEn: identical(proximoIntentoEn, _sin)
        ? this.proximoIntentoEn
        : proximoIntentoEn as DateTime?,
    ultimoHttpStatus: ultimoHttpStatus ?? this.ultimoHttpStatus,
    creadoEn: creadoEn,
    actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    aceptadoEn: aceptadoEn ?? this.aceptadoEn,
    motivo: identical(motivo, _sin) ? this.motivo : motivo as String?,
    categoria: identical(categoria, _sin)
        ? this.categoria
        : categoria as String?,
    shaUltimoEnvio: shaUltimoEnvio ?? this.shaUltimoEnvio,
  );

  Map<String, Object?> aMapa() => {
    'id': id,
    'tenant_id': tenantId,
    'atencion_id': atencionId,
    'tipo_rda': tipoRda.name,
    'version_doc': versionDoc,
    'compilacion_guia': compilacionGuia,
    'estado': estado.name,
    'bundle_identifier': ?bundleIdentifier,
    'bundle_sha256': ?bundleSha256,
    'bundle_cifrado': ?bundleCifrado,
    'vida': ?vida,
    'id_composition_ihce': ?idCompositionIhce,
    'advertencias_json': [for (final a in advertencias) a.aMapa()],
    'issues_json': [for (final i in issues) i.aMapa()],
    'intentos': intentos,
    'proximo_intento_en': ?proximoIntentoEn?.toUtc().toIso8601String(),
    'ultimo_http_status': ?ultimoHttpStatus,
    'creado_en': creadoEn.toUtc().toIso8601String(),
    'actualizado_en': actualizadoEn.toUtc().toIso8601String(),
    'aceptado_en': ?aceptadoEn?.toUtc().toIso8601String(),
    'motivo': ?motivo,
    'categoria': ?categoria,
    'sha_ultimo_envio': ?shaUltimoEnvio,
  };
}

const _sin = Object();

/// `ihce_rda_nodo`: una instancia de recurso FHIR del documento.
class NodoRda {
  const NodoRda({
    required this.documentoId,
    required this.idLocal,
    required this.tipoRecurso,
    required this.perfil,
    required this.sha256,
    this.tablaOrigen,
    this.pkOrigen,
  });

  factory NodoRda.desdeMapa(Map<String, Object?> m) => NodoRda(
    documentoId: m['documento_id']! as String,
    idLocal: m['id_local']! as String,
    tipoRecurso: m['tipo_recurso']! as String,
    perfil: m['perfil'] as String?,
    tablaOrigen: m['tabla_origen'] as String?,
    pkOrigen: m['pk_origen'] as String?,
    sha256: m['sha256']! as String,
  );

  final String documentoId;
  final String idLocal;
  final String tipoRecurso;
  final String? perfil;

  /// Origen en el modelo del repositorio: clave del mapa de la historia
  /// (`datos.paciente`, `datos.diagnosticos`, …) y su identificador.
  final String? tablaOrigen;
  final String? pkOrigen;

  /// SHA-256 del JSON canónico del recurso.
  final String sha256;

  Map<String, Object?> aMapa() => {
    'documento_id': documentoId,
    'id_local': idLocal,
    'tipo_recurso': tipoRecurso,
    'perfil': perfil,
    'tabla_origen': tablaOrigen,
    'pk_origen': pkOrigen,
    'sha256': sha256,
  };
}

/// `ihce_rda_arista`: una referencia FHIR entre dos nodos.
class AristaRda {
  const AristaRda({
    required this.documentoId,
    required this.idLocalOrigen,
    required this.rutaFhir,
    required this.idLocalDestino,
  });

  factory AristaRda.desdeMapa(Map<String, Object?> m) => AristaRda(
    documentoId: m['documento_id']! as String,
    idLocalOrigen: m['id_local_origen']! as String,
    rutaFhir: m['ruta_fhir']! as String,
    idLocalDestino: m['id_local_destino']! as String,
  );

  final String documentoId;
  final String idLocalOrigen;
  final String rutaFhir;
  final String idLocalDestino;

  Map<String, Object?> aMapa() => {
    'documento_id': documentoId,
    'id_local_origen': idLocalOrigen,
    'ruta_fhir': rutaFhir,
    'id_local_destino': idLocalDestino,
  };
}

/// `ihce_transmision_intento`: bitácora append-only, una fila por intento.
class IntentoTransmision {
  const IntentoTransmision({
    required this.id,
    required this.documentoId,
    required this.nIntento,
    required this.operacion,
    required this.iniciadoEn,
    required this.duracionMs,
    required this.idCorrelacion,
    required this.actor,
    required this.estado,
    this.httpStatus,
    this.categoria,
    this.idSolicitudServidor,
    this.issues = const [],
  });

  factory IntentoTransmision.desdeMapa(Map<String, Object?> m) =>
      IntentoTransmision(
        id: m['id']! as String,
        documentoId: m['documento_id']! as String,
        nIntento: m['n_intento']! as int,
        operacion: m['operacion']! as String,
        iniciadoEn: DateTime.parse(m['iniciado_en']! as String),
        duracionMs: m['duracion_ms']! as int,
        httpStatus: m['http_status'] as int?,
        categoria: m['categoria'] as String?,
        idCorrelacion: m['id_correlacion']! as String,
        idSolicitudServidor: m['id_solicitud_servidor'] as String?,
        issues: [
          for (final x in (m['issues_json'] as List?) ?? const [])
            IhceIssue.desdeMapa((x as Map).cast()),
        ],
        actor: m['actor']! as String,
        estado: m['estado']! as String,
      );

  final String id;
  final String documentoId;
  final int nIntento;
  final String operacion;
  final DateTime iniciadoEn;
  final int duracionMs;
  final int? httpStatus;
  final String? categoria;
  final String idCorrelacion;
  final String? idSolicitudServidor;
  final List<IhceIssue> issues;

  /// `sistema` o el identificador interno del usuario.
  final String actor;

  /// Estado del documento tras el intento.
  final String estado;

  Map<String, Object?> aMapa() => {
    'id': id,
    'documento_id': documentoId,
    'n_intento': nIntento,
    'operacion': operacion,
    'iniciado_en': iniciadoEn.toUtc().toIso8601String(),
    'duracion_ms': duracionMs,
    'http_status': httpStatus,
    'categoria': categoria,
    'id_correlacion': idCorrelacion,
    'id_solicitud_servidor': idSolicitudServidor,
    'issues_json': [for (final i in issues) i.aMapa()],
    'actor': actor,
    'estado': estado,
  };
}
