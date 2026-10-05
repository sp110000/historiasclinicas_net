import '../modelo/documento_rda.dart';

/// Categorías de error (Fase 5.6), dirigidas por tabla.
enum CategoriaError {
  sintactico('SINTACTICO'),
  semantico('SEMANTICO'),
  identidad('IDENTIDAD'),
  duplicado('DUPLICADO'),
  auth('AUTH'),
  transitorio('TRANSITORIO'),
  desconocido('DESCONOCIDO');

  const CategoriaError(this.etiqueta);

  final String etiqueta;
}

/// Resultado tipado de un envío. Los resultados esperables (rechazo,
/// duplicado, fallo transitorio) son valores, no excepciones.
sealed class ResultadoEnvio {
  const ResultadoEnvio();
}

class Aceptado extends ResultadoEnvio {
  const Aceptado({
    required this.vida,
    required this.httpStatus,
    this.idComposition,
    this.advertencias = const [],
    this.idSolicitud,
  });

  /// Valor opaco: no se descifra, recorta, normaliza ni cambia de
  /// mayúsculas.
  final String vida;
  final String? idComposition;
  final List<IhceIssue> advertencias;
  final int httpStatus;
  final String? idSolicitud;
}

class AceptadoSinVida extends ResultadoEnvio {
  const AceptadoSinVida({
    required this.httpStatus,
    required this.motivo,
    this.idComposition,
    this.advertencias = const [],
    this.idSolicitud,
  });

  final String? idComposition;
  final List<IhceIssue> advertencias;
  final int httpStatus;
  final String? idSolicitud;

  /// Por qué no hubo VIDA (sin identificador o eco del enviado).
  final String motivo;
}

/// No reintentable.
class Rechazado extends ResultadoEnvio {
  const Rechazado({
    required this.categoria,
    required this.issues,
    required this.httpStatus,
    this.cuerpoRedactado,
  });

  final CategoriaError categoria;
  final List<IhceIssue> issues;
  final int httpStatus;

  /// Cuerpo crudo (redactado) cuando no era un `OperationOutcome`.
  final String? cuerpoRedactado;
}

/// `409`: ya recibido; pendiente de conciliación. No reintentable.
class Duplicado extends ResultadoEnvio {
  const Duplicado({required this.issues, required this.httpStatus});

  final List<IhceIssue> issues;
  final int httpStatus;
}

/// No reintentable tras una renovación de token.
class ErrorAuth extends ResultadoEnvio {
  const ErrorAuth({required this.httpStatus, required this.detalleRedactado});

  final int? httpStatus;
  final String detalleRedactado;
}

/// Reintentable con backoff.
class FalloTransitorio extends ResultadoEnvio {
  const FalloTransitorio({
    required this.causa,
    this.httpStatus,
    this.reintentarEn,
    this.issues = const [],
    this.cuerpoRedactado,
  });

  final String causa;
  final int? httpStatus;

  /// Espera pedida por el servidor (`Retry-After`).
  final Duration? reintentarEn;
  final List<IhceIssue> issues;
  final String? cuerpoRedactado;
}

/// Jerarquía cerrada de excepciones del módulo: solo errores de
/// programación o de configuración. Ninguna cruza al flujo clínico.
sealed class IhceError implements Exception {
  const IhceError(this.mensaje);

  final String mensaje;

  @override
  String toString() => '$runtimeType: $mensaje';
}

class ConfiguracionIhceInvalida extends IhceError {
  const ConfiguracionIhceInvalida(super.mensaje);
}

class TlsNoSoportado extends IhceError {
  const TlsNoSoportado(super.mensaje);
}

class EstadoIhceInvalido extends IhceError {
  const EstadoIhceInvalido(super.mensaje);
}
