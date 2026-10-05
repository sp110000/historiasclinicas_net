/// Configuración del módulo IHCE (RDA y VIDA, Resolución 1888 de 2025).
///
/// Solo valores **no secretos**: se leen de `--dart-define` o
/// `--dart-define-from-file=config/ihce.env` (todo lo que se compila en la
/// PWA es público). `IHCE_CLIENT_ID`, `IHCE_CLIENT_SECRET`,
/// `IHCE_SUBSCRIPTION_KEY` y las llaves de cifrado viven solo en el
/// [AlmacenSecretos] (`flutter_secure_storage`).
///
/// Con `IHCE_ENABLED=false` (por defecto) no se exige nada y la app clínica
/// se comporta igual que sin el módulo.
library;

/// Ambiente de la plataforma de interoperabilidad.
enum AmbienteIhce {
  preproduccion,
  produccion;

  static AmbienteIhce desdeTexto(String? v) =>
      v == 'produccion' ? produccion : preproduccion;
}

/// D1: estilo de `id` y de referencia (ver docs/ihce/DESVIACIONES.md).
enum EstiloReferencia {
  /// `#Tipo-n` (Manual de Operaciones §5.3 y colección Postman v1.5).
  hash,

  /// `Tipo-n` (ejemplo `Composition-74a4c2a5…` de la guía).
  plain;

  static EstiloReferencia desdeTexto(String? v) => v == 'plain' ? plain : hash;
}

/// D3: `Bundle.identifier` en el envío.
enum IdentificadorBundle {
  /// Sin `identifier`: así lo envía la colección Postman v1.5.
  omitir,

  /// UUID determinista de (tenant, atención, tipo, versión).
  uuid;

  static IdentificadorBundle desdeTexto(String? v) =>
      v == 'uuid' ? uuid : omitir;
}

/// D6: de dónde sale el `display` de un código CIE-10.
enum FuenteDisplayCie10 {
  /// Tabla de referencia SISPRO (la incluida o la importada en la app).
  sispro,

  /// Fragmento `ICD10CO` de la guía (395 códigos).
  guia;

  static FuenteDisplayCie10 desdeTexto(String? v) =>
      v == 'guia' ? guia : sispro;
}

/// Firma digital del documento (Anexo Técnico §3.2.1).
enum ModoFirma {
  /// Sin firma: el formato aún no está definido por una fuente oficial.
  off;

  static ModoFirma desdeTexto(String? v) => off;
}

class ConfigIhce {
  const ConfigIhce({
    this.habilitado = false,
    this.ambiente = AmbienteIhce.preproduccion,
    this.baseUrl = '',
    this.tokenUrl = tokenUrlPorDefecto,
    this.tenantId = '',
    this.scope = '',
    this.timeoutConexion = const Duration(seconds: 5),
    this.timeoutLectura = const Duration(seconds: 30),
    this.maxIntentos = 6,
    this.backoffBase = const Duration(seconds: 30),
    this.backoffTope = const Duration(hours: 1),
    this.adjuntoMaxBytes = 5242880,
    this.estiloReferencia = EstiloReferencia.hash,
    this.encounterComoEntrada = true,
    this.identificadorBundle = IdentificadorBundle.omitir,
    this.vidaPath = 'Bundle.identifier.value',
    this.vidaSystem = vidaSystemPorDefecto,
    this.modoFirma = ModoFirma.off,
    this.fuenteDisplayCie10 = FuenteDisplayCie10.sispro,
    this.zonaHoraria = '-05:00',
    this.tituloComposition = 'RDA Consulta',
    this.cortacircuitosUmbral = 5,
    this.cortacircuitosEspera = const Duration(minutes: 15),
    this.concurrenciaPorTenant = 2,
    this.cabecerasIdSolicitud = const [
      'x-request-id',
      'x-ms-request-id',
      'request-id',
    ],
    this.retencionBitacora = const Duration(days: 730),
  });

  /// Lee la configuración compilada (`--dart-define`).
  factory ConfigIhce.desdeEntorno() => ConfigIhce.desdeMapa(_entorno);

  /// Desde un mapa `CLAVE → valor` (plantilla `.env`, pruebas). Las claves
  /// ausentes o vacías toman el valor por defecto.
  factory ConfigIhce.desdeMapa(Map<String, String> m) {
    String? v(String k) {
      final x = m[k]?.trim();
      return x == null || x.isEmpty ? null : x;
    }

    int? n(String k) => int.tryParse(v(k) ?? '');
    Duration? s(String k) => n(k) == null ? null : Duration(seconds: n(k)!);
    const d = ConfigIhce();
    return ConfigIhce(
      habilitado: v('IHCE_ENABLED') == 'true',
      ambiente: AmbienteIhce.desdeTexto(v('IHCE_ENV')),
      baseUrl: v('IHCE_BASE_URL') ?? d.baseUrl,
      tokenUrl: v('IHCE_TOKEN_URL') ?? d.tokenUrl,
      tenantId: v('IHCE_TENANT_ID') ?? d.tenantId,
      scope: v('IHCE_SCOPE') ?? d.scope,
      timeoutConexion: s('IHCE_TIMEOUT_CONNECT_S') ?? d.timeoutConexion,
      timeoutLectura: s('IHCE_TIMEOUT_READ_S') ?? d.timeoutLectura,
      maxIntentos: n('IHCE_MAX_INTENTOS') ?? d.maxIntentos,
      backoffBase: s('IHCE_BACKOFF_BASE_S') ?? d.backoffBase,
      backoffTope: s('IHCE_BACKOFF_TOPE_S') ?? d.backoffTope,
      adjuntoMaxBytes: n('IHCE_ATTACHMENT_MAX_BYTES') ?? d.adjuntoMaxBytes,
      estiloReferencia: EstiloReferencia.desdeTexto(v('IHCE_REFERENCE_STYLE')),
      encounterComoEntrada: v('IHCE_BUNDLE_ENCOUNTER_ENTRY') != 'false',
      identificadorBundle: IdentificadorBundle.desdeTexto(
        v('IHCE_BUNDLE_IDENTIFIER'),
      ),
      vidaPath: v('IHCE_VIDA_PATH') ?? d.vidaPath,
      vidaSystem: v('IHCE_VIDA_SYSTEM') ?? d.vidaSystem,
      modoFirma: ModoFirma.desdeTexto(v('IHCE_SIGNING_MODE')),
      fuenteDisplayCie10: FuenteDisplayCie10.desdeTexto(
        v('IHCE_DISPLAY_CIE10'),
      ),
      zonaHoraria: v('IHCE_ZONA_HORARIA') ?? d.zonaHoraria,
      tituloComposition: v('IHCE_TITULO_COMPOSITION') ?? d.tituloComposition,
      cortacircuitosUmbral:
          n('IHCE_CORTACIRCUITOS_UMBRAL') ?? d.cortacircuitosUmbral,
      cortacircuitosEspera:
          s('IHCE_CORTACIRCUITOS_ESPERA_S') ?? d.cortacircuitosEspera,
      concurrenciaPorTenant:
          n('IHCE_CONCURRENCIA_TENANT') ?? d.concurrenciaPorTenant,
      retencionBitacora: n('IHCE_RETENCION_BITACORA_DIAS') == null
          ? d.retencionBitacora
          : Duration(days: n('IHCE_RETENCION_BITACORA_DIAS')!),
    );
  }

  /// Endpoint de token de Microsoft Entra ID (colección Postman v1.5,
  /// petición `obtener-token`). `{tenant_id}` se sustituye por [tenantId].
  static const tokenUrlPorDefecto =
      'https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token';

  /// `Bundle.identifier.system` fijo en los cuatro perfiles `Bundle*RDA`.
  static const vidaSystemPorDefecto =
      'https://fhir.minsalud.gov.co/rda/NamingSystem/identifier-RDA';

  final bool habilitado;
  final AmbienteIhce ambiente;

  /// URL base del API (`APIMurl` de la colección): la entrega MinSalud con
  /// las credenciales.
  final String baseUrl;
  final String tokenUrl;
  final String tenantId;
  final String scope;
  final Duration timeoutConexion;
  final Duration timeoutLectura;
  final int maxIntentos;
  final Duration backoffBase;
  final Duration backoffTope;
  final int adjuntoMaxBytes;
  final EstiloReferencia estiloReferencia;

  /// D2: el `Encounter` viaja como entrada del Bundle.
  final bool encounterComoEntrada;
  final IdentificadorBundle identificadorBundle;
  final String vidaPath;
  final String vidaSystem;
  final ModoFirma modoFirma;
  final FuenteDisplayCie10 fuenteDisplayCie10;

  /// Desfase horario del consultorio (`±HH:MM`). La app guarda la hora local
  /// sin zona; Colombia no tiene horario de verano (los cuerpos oficiales de
  /// Postman usan `-05:00`).
  final String zonaHoraria;
  final String tituloComposition;
  final int cortacircuitosUmbral;
  final Duration cortacircuitosEspera;
  final int concurrenciaPorTenant;

  /// Cabeceras donde se busca el identificador de solicitud del servidor.
  /// TODO(IHCE-VERIFICAR): el Manual de Operaciones no nombra ninguna.
  final List<String> cabecerasIdSolicitud;
  final Duration retencionBitacora;

  String get tokenUrlResuelta => tokenUrl.replaceAll('{tenant_id}', tenantId);

  /// Errores de configuración (vacío si sirve). Solo se exige con el
  /// módulo habilitado.
  List<String> validar() {
    if (!habilitado) return const [];
    final errores = <String>[];
    void https(String nombre, String url) {
      final u = Uri.tryParse(url);
      if (u == null || u.scheme != 'https' || u.host.isEmpty) {
        errores.add('$nombre debe ser una URL https');
      }
    }

    if (baseUrl.isNotEmpty) https('IHCE_BASE_URL', baseUrl);
    https('IHCE_TOKEN_URL', tokenUrlResuelta);
    if (!RegExp(r'^[+-]\d{2}:\d{2}$').hasMatch(zonaHoraria)) {
      errores.add('IHCE_ZONA_HORARIA debe tener la forma ±HH:MM');
    }
    if (maxIntentos < 1) errores.add('IHCE_MAX_INTENTOS debe ser ≥ 1');
    return errores;
  }

  /// Lo necesario para hablar con IHCE (además de las credenciales).
  bool get transporteConfigurado =>
      baseUrl.isNotEmpty && tenantId.isNotEmpty && scope.isNotEmpty;
}

/// Valores compilados. `String.fromEnvironment` exige nombres constantes.
const _entorno = <String, String>{
  'IHCE_ENABLED': String.fromEnvironment('IHCE_ENABLED'),
  'IHCE_ENV': String.fromEnvironment('IHCE_ENV'),
  'IHCE_BASE_URL': String.fromEnvironment('IHCE_BASE_URL'),
  'IHCE_TOKEN_URL': String.fromEnvironment('IHCE_TOKEN_URL'),
  'IHCE_TENANT_ID': String.fromEnvironment('IHCE_TENANT_ID'),
  'IHCE_SCOPE': String.fromEnvironment('IHCE_SCOPE'),
  'IHCE_TIMEOUT_CONNECT_S': String.fromEnvironment('IHCE_TIMEOUT_CONNECT_S'),
  'IHCE_TIMEOUT_READ_S': String.fromEnvironment('IHCE_TIMEOUT_READ_S'),
  'IHCE_MAX_INTENTOS': String.fromEnvironment('IHCE_MAX_INTENTOS'),
  'IHCE_BACKOFF_BASE_S': String.fromEnvironment('IHCE_BACKOFF_BASE_S'),
  'IHCE_BACKOFF_TOPE_S': String.fromEnvironment('IHCE_BACKOFF_TOPE_S'),
  'IHCE_ATTACHMENT_MAX_BYTES': String.fromEnvironment(
    'IHCE_ATTACHMENT_MAX_BYTES',
  ),
  'IHCE_REFERENCE_STYLE': String.fromEnvironment('IHCE_REFERENCE_STYLE'),
  'IHCE_BUNDLE_ENCOUNTER_ENTRY': String.fromEnvironment(
    'IHCE_BUNDLE_ENCOUNTER_ENTRY',
  ),
  'IHCE_BUNDLE_IDENTIFIER': String.fromEnvironment('IHCE_BUNDLE_IDENTIFIER'),
  'IHCE_VIDA_PATH': String.fromEnvironment('IHCE_VIDA_PATH'),
  'IHCE_VIDA_SYSTEM': String.fromEnvironment('IHCE_VIDA_SYSTEM'),
  'IHCE_SIGNING_MODE': String.fromEnvironment('IHCE_SIGNING_MODE'),
  'IHCE_DISPLAY_CIE10': String.fromEnvironment('IHCE_DISPLAY_CIE10'),
  'IHCE_ZONA_HORARIA': String.fromEnvironment('IHCE_ZONA_HORARIA'),
  'IHCE_TITULO_COMPOSITION': String.fromEnvironment('IHCE_TITULO_COMPOSITION'),
  'IHCE_CORTACIRCUITOS_UMBRAL': String.fromEnvironment(
    'IHCE_CORTACIRCUITOS_UMBRAL',
  ),
  'IHCE_CORTACIRCUITOS_ESPERA_S': String.fromEnvironment(
    'IHCE_CORTACIRCUITOS_ESPERA_S',
  ),
  'IHCE_CONCURRENCIA_TENANT': String.fromEnvironment(
    'IHCE_CONCURRENCIA_TENANT',
  ),
  'IHCE_RETENCION_BITACORA_DIAS': String.fromEnvironment(
    'IHCE_RETENCION_BITACORA_DIAS',
  ),
};
