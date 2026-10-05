import 'dart:io';

import 'package:http/io_client.dart';

import '../config/config_ihce.dart';
import 'resultado.dart';
import 'transporte.dart';

/// Runtime sin navegador: `HttpClient` con TLS 1.3 como mínimo y
/// verificación de certificados (no se instala `badCertificateCallback`).
/// Si el runtime no soporta TLS 1.3 falla la inicialización del cliente,
/// nunca el arranque de la app clínica.
TransporteIhce crearTransporte(ConfigIhce config) {
  final contexto = SecurityContext(withTrustedRoots: true);
  try {
    contexto.minimumTlsProtocolVersion = TlsProtocolVersion.tls1_3;
  } on Object catch (e) {
    throw TlsNoSoportado('El runtime no admite TLS 1.3: $e');
  }
  final cliente = HttpClient(context: contexto)
    ..connectionTimeout = config.timeoutConexion
    ..maxConnectionsPerHost = config.concurrenciaPorTenant
    ..idleTimeout = const Duration(seconds: 15);
  return TransporteDirectoIo(
    IOClient(cliente),
    contexto,
    timeoutConexion: config.timeoutConexion,
    timeoutLectura: config.timeoutLectura,
  );
}

/// Adaptador directo con su contexto TLS a la vista (para inspeccionarlo).
class TransporteDirectoIo extends TransporteHttp {
  TransporteDirectoIo(
    super.cliente,
    this.contexto, {
    required super.timeoutConexion,
    required super.timeoutLectura,
  }) : super(tls: const ConfiguracionTls());

  final SecurityContext contexto;
}
