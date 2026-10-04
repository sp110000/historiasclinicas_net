import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/config_ihce.dart';
import 'resultado.dart';
import 'transporte_plataforma.dart'
    if (dart.library.io) 'transporte_io.dart'
    as plataforma;

class PeticionHttp {
  const PeticionHttp({
    required this.metodo,
    required this.url,
    required this.cabeceras,
    this.cuerpo,
  });

  final String metodo;
  final Uri url;
  final Map<String, String> cabeceras;
  final Uint8List? cuerpo;
}

class RespuestaHttp {
  const RespuestaHttp(this.status, this.cuerpo, this.cabeceras);

  final int status;
  final String cuerpo;
  final Map<String, String> cabeceras;
}

/// Fallo de red antes de tener respuesta: timeout, conexión o TLS.
class FalloRed implements Exception {
  const FalloRed(this.tipo, this.detalle);

  /// `timeout`, `conexion` o `tls`.
  final String tipo;
  final String detalle;

  @override
  String toString() => 'FalloRed($tipo)';
}

/// Exigencias de TLS del adaptador directo (Fase 5.3): versión mínima 1.3
/// y verificación de certificados siempre activa.
class ConfiguracionTls {
  const ConfiguracionTls();

  String get versionMinima => '1.3';
  bool get verificarCertificados => true;
}

/// Token y envío van detrás de este puerto. El adaptador se elige según la
/// plataforma (Fase 0: hoy la app es solo web).
abstract interface class TransporteIhce {
  /// `false`: los documentos esperan en `SIN_TRANSPORTE`, sin errores.
  bool get disponible;

  /// `null` si el adaptador no maneja TLS (navegador).
  ConfiguracionTls? get tls;

  Future<RespuestaHttp> enviar(PeticionHttp p);

  Future<void> cerrar();
}

/// Build web de la PWA: Entra ID rechaza `client_credentials` con cabecera
/// `Origin` (AADSTS9002326), la credencial no puede vivir en el navegador
/// y la CSP limita la app a su propio dominio. No existe relevo de servidor
/// en el repositorio: los documentos quedan en cola con `SIN_TRANSPORTE`.
class TransporteNoDisponible implements TransporteIhce {
  const TransporteNoDisponible();

  @override
  bool get disponible => false;

  @override
  ConfiguracionTls? get tls => null;

  @override
  Future<RespuestaHttp> enviar(PeticionHttp p) =>
      throw const EstadoIhceInvalido('Sin transporte hacia IHCE');

  @override
  Future<void> cerrar() async {}
}

/// Adaptador sobre `package:http`. En runtimes sin navegador (nativo,
/// escritorio, servidor) usa el cliente con TLS 1.3 de [crearTransporteDirecto];
/// las pruebas inyectan un `MockClient`.
class TransporteHttp implements TransporteIhce {
  TransporteHttp(
    http.Client cliente, {
    required this.timeoutConexion,
    required this.timeoutLectura,
    this.tls,
  }) : _cliente = cliente;

  final http.Client _cliente;
  final Duration timeoutConexion;
  final Duration timeoutLectura;

  @override
  final ConfiguracionTls? tls;

  @override
  bool get disponible => true;

  @override
  Future<RespuestaHttp> enviar(PeticionHttp p) async {
    final peticion = http.Request(p.metodo, p.url)
      ..headers.addAll(p.cabeceras)
      ..followRedirects = false;
    if (p.cuerpo != null) peticion.bodyBytes = p.cuerpo!;
    try {
      final r = await _cliente
          .send(peticion)
          .timeout(timeoutConexion + timeoutLectura);
      // FHIR exige UTF-8; un byte inválido no debe tumbar la clasificación
      // de la respuesta (se reemplaza por U+FFFD).
      final bytes = await r.stream.toBytes().timeout(timeoutLectura);
      return RespuestaHttp(
        r.statusCode,
        utf8.decode(bytes, allowMalformed: true),
        r.headers,
      );
    } on TimeoutException catch (e) {
      throw FalloRed('timeout', '$e');
    } on http.ClientException catch (e) {
      final m = e.message.toLowerCase();
      throw FalloRed(
        m.contains('handshake') || m.contains('certificate')
            ? 'tls'
            : 'conexion',
        e.message,
      );
    }
  }

  @override
  Future<void> cerrar() async => _cliente.close();
}

/// Adaptador directo de la plataforma (TLS 1.3, certificados verificados).
/// En el navegador no existe: devuelve [TransporteNoDisponible].
TransporteIhce crearTransporteDirecto(ConfigIhce config) =>
    plataforma.crearTransporte(config);
