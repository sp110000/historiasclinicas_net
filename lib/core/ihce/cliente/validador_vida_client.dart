import 'dart:convert';
import 'dart:typed_data';

import '../config/config_ihce.dart';
import '../modelo/documento_rda.dart';
import '../reloj.dart';
import '../secretos/almacen_secretos.dart';
import 'operation_outcome.dart';
import 'registro.dart';
import 'resultado.dart';
import 'token.dart';
import 'transporte.dart';

/// Contexto de un envío: identificadores internos, nunca datos clínicos.
class ContextoEnvio {
  const ContextoEnvio({
    required this.idCorrelacion,
    required this.documentoId,
    this.bundleIdentifierEnviado,
    this.tiposPorEntrada = const [],
  });

  /// Identificador por intento, registrado localmente. No se envía como
  /// cabecera: la documentación oficial no define ninguna.
  final String idCorrelacion;
  final String documentoId;

  /// `Bundle.identifier.value` enviado (si D3 lo incluye), para detectar
  /// el eco.
  final String? bundleIdentifierEnviado;

  /// `resourceType` de cada entrada del Bundle enviado, para resolver
  /// `location` a un recurso.
  final List<String> tiposPorEntrada;
}

/// Resultado de una consulta (P1).
sealed class ResultadoConsulta {
  const ResultadoConsulta();
}

class Encontrado extends ResultadoConsulta {
  const Encontrado(this.recurso);

  final Map<String, Object?> recurso;
}

class NoEncontrado extends ResultadoConsulta {
  const NoEncontrado();
}

class ConsultaFallida extends ResultadoConsulta {
  const ConsultaFallida(this.resultado);

  /// Error tipado (auth, transitorio, rechazo).
  final ResultadoEnvio resultado;
}

/// Cliente asíncrono del mecanismo IHCE: transmite el RDA, captura el VIDA y
/// clasifica los errores con `OperationOutcome`. Rutas y cuerpos según la
/// colección Postman v1.5; cabeceras según el Manual de Operaciones v01.4.
class ValidadorVidaClient {
  ValidadorVidaClient({
    required this.config,
    required this.credenciales,
    required this.transporte,
    Reloj? reloj,
    RegistroIhce? registro,
  }) : reloj = reloj ?? const RelojSistema(),
       registro = registro ?? RegistroIhce() {
    final base = Uri.tryParse(config.baseUrl);
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      throw const ConfiguracionIhceInvalida('IHCE_BASE_URL debe ser https');
    }
    final token = Uri.tryParse(config.tokenUrlResuelta);
    if (token == null || token.scheme != 'https') {
      throw const ConfiguracionIhceInvalida('IHCE_TOKEN_URL debe ser https');
    }
    tokens = GestorToken(
      config: config,
      transporte: transporte,
      reloj: this.reloj,
      registro: this.registro,
    );
  }

  final ConfigIhce config;
  final ServicioCredenciales credenciales;
  final TransporteIhce transporte;
  final Reloj reloj;
  final RegistroIhce registro;
  late final GestorToken tokens;

  // ───────────────────────── P0 ─────────────────────────

  /// `POST {base}/Composition/$enviar-rda-{tipo}` con los bytes tal cual
  /// (ya canonicalizados, validados, firmados y persistidos).
  Future<ResultadoEnvio> enviarRda(
    TipoRda tipo,
    Uint8List bundleBytes,
    ContextoEnvio contexto,
  ) => _operacion(
    'Composition/\$${tipo.operacion}',
    bundleBytes,
    contexto,
    conVida: tipo.conVida,
  );

  Future<void> cerrar() => transporte.cerrar();

  // ───────────────────────── P1 ─────────────────────────

  /// Correcciones tras la aceptación: `POST /Composition/{id}/$enviar-nota-aclaratoria`
  /// con un Bundle `transaction`.
  ///
  /// TODO(IHCE-VERIFICAR): la colección Postman añade a esta operación la
  /// cabecera `x-functions-key`, que el Manual no documenta.
  Future<ResultadoEnvio> enviarNotaAclaratoria(
    String idComposition,
    Uint8List bundleTransaction,
    ContextoEnvio contexto,
  ) => _operacion(
    'Composition/${Uri.encodeComponent(idComposition)}/\$enviar-nota-aclaratoria',
    bundleTransaction,
    contexto,
    conVida: false,
  );

  /// `POST /Patient/$consultar-paciente-exacto`; `humanuser` =
  /// `{TipoDoc}-{NumDoc}` del profesional que consulta (Manual §5.4.9).
  Future<ResultadoConsulta> consultarPacienteExacto(
    String tipoDocumento,
    String numeroDocumento,
    String humanuser,
    ContextoEnvio contexto,
  ) => _consulta(
    'Patient/\$consultar-paciente-exacto',
    _parametros([
      _identificador(tipoDocumento, numeroDocumento),
      {'name': 'humanuser', 'valueString': humanuser},
    ]),
    contexto,
  );

  /// `POST /Patient/$consultar-paciente-similar`: lista con puntaje.
  Future<ResultadoConsulta> consultarPacienteSimilar(
    String tipoDocumento,
    String numeroDocumento,
    String humanuser,
    ContextoEnvio contexto,
  ) => _consulta(
    'Patient/\$consultar-paciente-similar',
    _parametros([
      _identificador(tipoDocumento, numeroDocumento),
      {'name': 'humanuser', 'valueString': humanuser},
    ]),
    contexto,
  );

  Future<ResultadoConsulta> consultarProfesional(
    String tipoDocumento,
    String numeroDocumento,
    ContextoEnvio contexto,
  ) => _consulta(
    'Practitioner/\$consultar-profesional-salud',
    _parametros([_identificador(tipoDocumento, numeroDocumento)]),
    contexto,
  );

  /// Por NIT, código de habilitación o nombre (los tres son opcionales).
  Future<ResultadoConsulta> consultarOrganizacion(
    ContextoEnvio contexto, {
    String? nit,
    String? codigoHabilitacion,
    String? nombre,
  }) => _consulta(
    'Organization/\$consultar-organizacion',
    _parametros([
      if (nit != null) {'name': 'TaxIdentifier', 'valueString': nit},
      if (codigoHabilitacion != null)
        {
          'name': 'HealthcareProviderIdentifier',
          'valueString': codigoHabilitacion,
        },
      if (nombre != null) {'name': 'name', 'valueString': nombre},
    ]),
    contexto,
  );

  Future<ResultadoConsulta> consultarEapb(
    String nombre,
    ContextoEnvio contexto,
  ) => _consulta(
    'Organization/\$consultar-eapb',
    _parametros([
      {'name': 'name', 'valueString': nombre},
    ]),
    contexto,
  );

  /// `GET /CodeSystem/{id}`.
  Future<ResultadoConsulta> obtenerCodeSystem(String id, ContextoEnvio c) =>
      _consulta('CodeSystem/${Uri.encodeComponent(id)}', null, c);

  /// `GET /CodeSystem/{id}/$validate-code?code={codigo}`.
  Future<ResultadoConsulta> validarCodigo(
    String id,
    String codigo,
    ContextoEnvio c,
  ) => _consulta(
    'CodeSystem/${Uri.encodeComponent(id)}/\$validate-code'
    '?code=${Uri.encodeQueryComponent(codigo)}',
    null,
    c,
  );

  /// `GET /CodeSystem?since={AAAA-MM-DD}`.
  Future<ResultadoConsulta> codeSystemsDesde(DateTime desde, ContextoEnvio c) {
    final f =
        '${desde.year.toString().padLeft(4, '0')}-'
        '${desde.month.toString().padLeft(2, '0')}-'
        '${desde.day.toString().padLeft(2, '0')}';
    return _consulta('CodeSystem?since=$f', null, c);
  }

  // ───────────────────────── Internos ─────────────────────────

  static Map<String, Object?> _identificador(String tipo, String numero) => {
    'name': 'identifier',
    'part': [
      {'name': 'type', 'valueString': tipo},
      {'name': 'value', 'valueString': numero},
    ],
  };

  static Uint8List _parametros(List<Map<String, Object?>> p) =>
      Uint8List.fromList(
        utf8.encode(jsonEncode({'resourceType': 'Parameters', 'parameter': p})),
      );

  /// `{base}/{ruta}` con el `$` literal (no se codifica).
  Uri _url(String ruta) {
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    return Uri.parse('$base/$ruta');
  }

  /// Token vigente o resultado de error. Lee credenciales solo del almacén.
  Future<Object> _token() async {
    final c = await credenciales.leer();
    if (c == null) {
      return const ErrorAuth(
        httpStatus: null,
        detalleRedactado: 'Credenciales de IHCE no configuradas',
      );
    }
    registro.redactor.agregar(c.secretos);
    final t = await tokens.obtener(c);
    return t is TokenAcceso ? (t, c) : t;
  }

  Future<RespuestaHttp> _llamar(
    String metodo,
    Uri url,
    Uint8List? cuerpo,
    TokenAcceso token,
    CredencialesIhce c,
  ) => transporte.enviar(
    PeticionHttp(
      metodo: metodo,
      url: url,
      cabeceras: {
        'Authorization': 'Bearer ${token.valor}',
        if (c.subscriptionKey != null)
          'Ocp-Apim-Subscription-Key': c.subscriptionKey!,
        if (cuerpo != null) 'Content-Type': 'application/fhir+json',
        'Accept': 'application/fhir+json',
      },
      cuerpo: cuerpo,
    ),
  );

  /// Llama con token; ante `401` invalida, renueva una vez y reintenta una
  /// vez. Devuelve la respuesta o un [ResultadoEnvio] de error.
  Future<Object> _conToken(String metodo, Uri url, Uint8List? cuerpo) async {
    for (var intento = 0; intento < 2; intento++) {
      final t = await _token();
      if (t is! (TokenAcceso, CredencialesIhce)) return t;
      final RespuestaHttp r;
      try {
        r = await _llamar(metodo, url, cuerpo, t.$1, t.$2);
      } on FalloRed catch (e) {
        registro.alerta('fallo_red', {'tipo': e.tipo});
        return FalloTransitorio(causa: e.tipo);
      }
      if (r.status != 401) return r;
      tokens.invalidar();
      registro.alerta('http_401', {'intento': intento + 1});
      if (intento == 1) {
        return ErrorAuth(
          httpStatus: 401,
          detalleRedactado: registro.redactor.cuerpo(r.cuerpo, maximo: 300),
        );
      }
    }
    throw StateError('inalcanzable');
  }

  Future<ResultadoEnvio> _operacion(
    String ruta,
    Uint8List cuerpo,
    ContextoEnvio contexto, {
    required bool conVida,
  }) async {
    final r = await _conToken('POST', _url(ruta), cuerpo);
    if (r is ResultadoEnvio) return r;
    final respuesta = r as RespuestaHttp;
    final idSolicitud = _idSolicitud(respuesta.cabeceras);
    final interpretado = interpretarCuerpo(respuesta.cuerpo);
    final s = respuesta.status;
    registro
      ..contar('http_${s ~/ 100}xx')
      ..info('respuesta', {
        'documento': contexto.documentoId,
        'correlacion': contexto.idCorrelacion,
        'http': s,
        'cuerpo': interpretado.tipo,
      });

    if (s >= 200 && s < 300) {
      return _aceptacion(s, interpretado, contexto, idSolicitud, conVida);
    }
    final categoria = clasificar(
      s,
      interpretado.issues,
      tiposPorEntrada: contexto.tiposPorEntrada,
    );
    registro.contar('categoria_${categoria.etiqueta}');
    final crudo = interpretado.tipo == 'OperationOutcome'
        ? null
        : registro.redactor.cuerpo(respuesta.cuerpo);
    if (interpretado.tipo != 'OperationOutcome') {
      registro.alerta('cuerpo_no_fhir', {'http': s, 'tipo': interpretado.tipo});
    }
    return switch (categoria) {
      CategoriaError.auth => ErrorAuth(
        httpStatus: s,
        detalleRedactado: registro.redactor.cuerpo(
          respuesta.cuerpo,
          maximo: 300,
        ),
      ),
      CategoriaError.duplicado => Duplicado(
        issues: interpretado.issues,
        httpStatus: s,
      ),
      CategoriaError.transitorio => FalloTransitorio(
        causa: 'http_$s',
        httpStatus: s,
        reintentarEn: _retryAfter(respuesta.cabeceras),
        issues: interpretado.issues,
        cuerpoRedactado: crudo,
      ),
      _ => Rechazado(
        categoria: categoria,
        issues: interpretado.issues,
        httpStatus: s,
        cuerpoRedactado: crudo,
      ),
    };
  }

  ResultadoEnvio _aceptacion(
    int status,
    CuerpoInterpretado cuerpo,
    ContextoEnvio contexto,
    String? idSolicitud,
    bool conVida,
  ) {
    final advertencias = [
      for (final i in cuerpo.issues)
        if (i.severity == 'warning' || i.severity == 'information') i,
    ];
    final bundle = cuerpo.tipo == 'Bundle' ? cuerpo.json : null;
    final idComposition = _idComposition(bundle);
    if (bundle == null) {
      registro.alerta('aceptado_sin_bundle', {'http': status});
      return AceptadoSinVida(
        httpStatus: status,
        motivo: 'La respuesta 2xx no trae un Bundle',
        advertencias: advertencias,
        idSolicitud: idSolicitud,
      );
    }
    final vida = extraerVida(bundle);
    if (vida == null) {
      if (conVida) registro.alerta('aceptado_sin_vida', {'http': status});
      return AceptadoSinVida(
        httpStatus: status,
        motivo: 'La respuesta no trae VIDA',
        idComposition: idComposition,
        advertencias: advertencias,
        idSolicitud: idSolicitud,
      );
    }
    if (vida == contexto.bundleIdentifierEnviado) {
      registro.alerta('vida_eco', {'http': status});
      return AceptadoSinVida(
        httpStatus: status,
        motivo: 'El identificador devuelto es un eco del enviado',
        idComposition: idComposition,
        advertencias: advertencias,
        idSolicitud: idSolicitud,
      );
    }
    registro.contar('aceptado');
    return Aceptado(
      vida: vida,
      idComposition: idComposition,
      advertencias: advertencias,
      httpStatus: status,
      idSolicitud: idSolicitud,
    );
  }

  /// VIDA en `IHCE_VIDA_PATH` (por defecto `Bundle.identifier.value`) cuando
  /// el `system` del identificador coincide con `IHCE_VIDA_SYSTEM`. El valor
  /// se devuelve tal cual (opaco).
  ///
  /// TODO(IHCE-VERIFICAR): la colección Postman v1.5 no trae respuestas de
  /// ejemplo; la ubicación sale de los perfiles `Bundle*RDA`.
  String? extraerVida(Map<String, Object?> bundle) {
    final partes = config.vidaPath.split('.');
    if (partes.isEmpty || partes.first != 'Bundle') return null;
    Object? actual = bundle;
    Object? padre;
    for (final p in partes.skip(1)) {
      if (actual is List) actual = actual.isEmpty ? null : actual.first;
      if (actual is! Map) return null;
      padre = actual;
      actual = actual[p];
    }
    if (actual is! String || actual.isEmpty) return null;
    if (padre is Map &&
        padre.containsKey('system') &&
        padre['system'] != config.vidaSystem) {
      return null;
    }
    return actual;
  }

  String? _idComposition(Map<String, Object?>? bundle) {
    final e = (bundle?['entry'] as List?)?.firstOrNull;
    final r = e is Map ? e['resource'] : null;
    return r is Map && r['resourceType'] == 'Composition'
        ? r['id'] as String?
        : null;
  }

  String? _idSolicitud(Map<String, String> cabeceras) {
    for (final c in config.cabecerasIdSolicitud) {
      final v = cabeceras[c.toLowerCase()];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  Duration? _retryAfter(Map<String, String> cabeceras) {
    final v = cabeceras['retry-after'];
    if (v == null) return null;
    final s = int.tryParse(v.trim());
    if (s != null) return Duration(seconds: s);
    try {
      final f = _fechaHttp(v);
      final d = f.difference(reloj.ahora().toUtc());
      return d.isNegative ? Duration.zero : d;
    } on FormatException {
      return null;
    }
  }

  static DateTime _fechaHttp(String v) {
    const meses = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final m = RegExp(
      r'(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(v);
    if (m == null || meses[m.group(2)] == null) throw const FormatException();
    return DateTime.utc(
      int.parse(m.group(3)!),
      meses[m.group(2)]!,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
  }

  Future<ResultadoConsulta> _consulta(
    String ruta,
    Uint8List? cuerpo,
    ContextoEnvio contexto,
  ) async {
    final r = await _conToken(
      cuerpo == null ? 'GET' : 'POST',
      _url(ruta),
      cuerpo,
    );
    if (r is ResultadoEnvio) return ConsultaFallida(r);
    final respuesta = r as RespuestaHttp;
    if (respuesta.status == 404) return const NoEncontrado();
    final interpretado = interpretarCuerpo(respuesta.cuerpo);
    if (respuesta.status >= 200 &&
        respuesta.status < 300 &&
        interpretado.json != null) {
      return Encontrado(interpretado.json!);
    }
    final categoria = clasificar(respuesta.status, interpretado.issues);
    return ConsultaFallida(
      categoria == CategoriaError.transitorio
          ? FalloTransitorio(
              causa: 'http_${respuesta.status}',
              httpStatus: respuesta.status,
            )
          : Rechazado(
              categoria: categoria,
              issues: interpretado.issues,
              httpStatus: respuesta.status,
            ),
    );
  }
}
