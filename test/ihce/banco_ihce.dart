// Banco de pruebas del módulo IHCE: todo en memoria, sin red ni secretos
// reales. El transporte es un MockClient de package:http/testing.dart.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:historiasclinicas_net/core/ihce/almacen/almacen_kv.dart';
import 'package:historiasclinicas_net/core/ihce/almacen/repositorio_ihce.dart';
import 'package:historiasclinicas_net/core/ihce/cifrado/cifrador.dart';
import 'package:historiasclinicas_net/core/ihce/cliente/registro.dart';
import 'package:historiasclinicas_net/core/ihce/cliente/transporte.dart';
import 'package:historiasclinicas_net/core/ihce/cliente/validador_vida_client.dart';
import 'package:historiasclinicas_net/core/ihce/config/config_ihce.dart';
import 'package:historiasclinicas_net/core/ihce/ensamblado/pdf_soporte.dart';
import 'package:historiasclinicas_net/core/ihce/modelo/documento_rda.dart';
import 'package:historiasclinicas_net/core/ihce/outbox/servicio_ihce.dart';
import 'package:historiasclinicas_net/core/ihce/reloj.dart';
import 'package:historiasclinicas_net/core/ihce/secretos/almacen_secretos.dart';

import 'ayudas_ihce.dart';

/// Credenciales sintéticas (no son de ningún prestador).
const clientIdSintetico = 'cid-sintetico-0001';
const secretoSintetico = 'secreto-sintetico-NO-REAL-9f3c';
const claveSuscripcionSintetica = 'clave-apim-sintetica-7a1b';
const tokenSintetico = 'token-sintetico-abc.def.ghi';
const vidaSintetico = 'VIDA-SINTETICO-9f3c1b7e5a2d4c60b8e1f0a7d6c5b4a3';

/// Todos los logs emitidos en las pruebas (T15 los revisa).
final logsCapturados = <EntradaRegistro>[];

RegistroIhce registroDePrueba() => RegistroIhce(salida: logsCapturados.add);

/// Fecha «actual» de las pruebas: un día después de la atención sintética.
DateTime ahoraDePrueba() => DateTime(2026, 1, 16, 9);

class PdfFijo implements GeneradorPdfSoporte {
  int generados = 0;

  @override
  Future<Uint8List> generar(Map<String, Object?> datos, int revision) async {
    generados++;
    return Uint8List.fromList(pdfSintetico);
  }
}

/// Servidor simulado: token de Entra ID y operaciones de IHCE.
class ServidorSimulado {
  ServidorSimulado({this.expiraEn = 3599});

  int expiraEn;
  final peticionesToken = <http.Request>[];
  final peticionesApi = <http.Request>[];

  /// Respuestas de la API en orden; la última se repite.
  final respuestasApi = <Future<http.Response> Function(http.Request)>[];

  /// Respuestas del endpoint de token en orden; la última se repite.
  final respuestasToken = <http.Response Function()>[];

  MockClient get cliente => MockClient((r) async {
    if (r.url.host == 'login.microsoftonline.com') {
      peticionesToken.add(r);
      final f = respuestasToken.isEmpty
          ? _tokenOk
          : respuestasToken[min(
              peticionesToken.length - 1,
              respuestasToken.length - 1,
            )];
      return f();
    }
    peticionesApi.add(r);
    final f =
        respuestasApi[min(peticionesApi.length - 1, respuestasApi.length - 1)];
    return f(r);
  });

  http.Response _tokenOk() => http.Response(
    jsonEncode({
      'access_token': tokenSintetico,
      'token_type': 'Bearer',
      'expires_in': expiraEn,
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  TransporteHttp transporte() => TransporteHttp(
    cliente,
    timeoutConexion: const Duration(seconds: 5),
    timeoutLectura: const Duration(seconds: 30),
  );
}

/// Bundle de respuesta de aceptación (forma ilustrativa: la colección
/// Postman v1.5 no trae respuestas).
Map<String, Object?> bundleAceptado({
  String? vida = vidaSintetico,
  String? system,
  List<Map<String, Object?>> advertencias = const [],
}) => {
  'resourceType': 'Bundle',
  'type': 'document',
  if (vida != null)
    'identifier': {
      'system': system ?? ConfigIhce.vidaSystemPorDefecto,
      'value': vida,
    },
  'timestamp': '2026-01-15T10:30:00-05:00',
  'entry': [
    {
      'resource': {
        'resourceType': 'Composition',
        'id': 'composition-sintetico-001',
      },
    },
    if (advertencias.isNotEmpty)
      {
        'resource': {'resourceType': 'OperationOutcome', 'issue': advertencias},
      },
  ],
};

Future<http.Response> Function(http.Request) responder(
  int status,
  Object? cuerpo, {
  Map<String, String> cabeceras = const {},
}) =>
    // Bytes UTF-8 (FHIR); `http.Response(String)` sin charset usaría latin1.
    (_) async => http.Response.bytes(
      utf8.encode(cuerpo is String ? cuerpo : jsonEncode(cuerpo)),
      status,
      headers: {'content-type': 'application/fhir+json', ...cabeceras},
    );

Map<String, Object?> operationOutcome(
  String code,
  String diagnostics, {
  List<String> location = const [],
  String severity = 'error',
}) => {
  'resourceType': 'OperationOutcome',
  'issue': [
    {
      'severity': severity,
      'code': code,
      'diagnostics': diagnostics,
      if (location.isNotEmpty) 'location': location,
    },
  ],
};

/// Repositorio que puede fallar al insertar (T13).
class RepositorioQueFalla extends RepositorioIhce {
  RepositorioQueFalla(super.kv);

  int fallosPendientes = 0;

  @override
  Future<void> insertarDocumento(DocumentoRda d) {
    if (fallosPendientes > 0) {
      fallosPendientes--;
      throw StateError('inserción simulada fallida');
    }
    return super.insertarDocumento(d);
  }
}

class Banco {
  Banco({
    ConfigIhce? config,
    TransporteIhce? transporte,
    ServidorSimulado? servidor,
    bool conCredenciales = true,
    RepositorioIhce? repositorio,
    this.crearCliente,
  }) : config = config ?? configDePrueba(),
       servidor = servidor ?? ServidorSimulado() {
    this.repositorio = repositorio ?? RepositorioIhce(AlmacenKvMemoria());
    credenciales = ServicioCredenciales(secretos, this.config.ambiente);
    if (conCredenciales) {
      secretos.valores
        ..[ClavesSecretas.clientId(this.config.ambiente)] = clientIdSintetico
        ..[ClavesSecretas.clientSecret(this.config.ambiente)] = secretoSintetico
        ..[ClavesSecretas.subscriptionKey(this.config.ambiente)] =
            claveSuscripcionSintetica;
    }
    this.transporte = transporte ?? this.servidor.transporte();
    servicio = ServicioIhce(
      config: this.config,
      repositorio: this.repositorio,
      cifrador: CifradorDatos(secretos),
      credenciales: credenciales,
      cargarCatalogo: () async => catalogoDePrueba(),
      cargarEsquema: () async => esquemaDePrueba(),
      pdf: pdf,
      transporte: this.transporte,
      reloj: reloj,
      registro: registro,
      azar: Random(7),
      crearCliente: crearCliente,
    );
  }

  final ConfigIhce config;
  final ServidorSimulado servidor;
  final secretos = AlmacenSecretosMemoria();
  final reloj = RelojFalso(ahoraDePrueba());
  final registro = registroDePrueba();
  final pdf = PdfFijo();
  final ValidadorVidaClient Function(TransporteIhce t)? crearCliente;
  late final RepositorioIhce repositorio;
  late final ServicioCredenciales credenciales;
  late final TransporteIhce transporte;
  late final ServicioIhce servicio;

  ValidadorVidaClient cliente() => ValidadorVidaClient(
    config: config,
    credenciales: credenciales,
    transporte: transporte,
    reloj: reloj,
    registro: registro,
  );

  /// Cierra una atención sintética y espera el barrido del worker.
  Future<DocumentoRda> cerrarYProcesar({Map<String, Object?>? datos}) async {
    final d = datos ?? datosSinteticos();
    await servicio.alCerrarAtencion(
      datos: d,
      revision: 1,
      medico: medicoSintetico,
      prestador: prestadorSintetico,
    );
    await servicio.procesarPendientes();
    return repositorio.documentosDeAtencion(d['id']! as String).last;
  }

  DocumentoRda documento(String id) => repositorio.documento(id)!;
}
