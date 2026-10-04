import 'package:flutter/foundation.dart';

/// Redacción en el punto de logging: ningún token, secreto, clave de
/// suscripción ni payload FHIR sale a un log, a una excepción o a un
/// mensaje. Solo identificadores internos, hashes y códigos.
class Redactor {
  Redactor([Iterable<String> secretos = const []]) {
    agregar(secretos);
  }

  final _secretos = <String>{};

  void agregar(Iterable<String> secretos) {
    for (final s in secretos) {
      if (s.length >= 4) _secretos.add(s);
    }
  }

  static final _patrones = [
    RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    RegExp(r'(client_secret|access_token|refresh_token|client_id)=[^&\s]+'),
    RegExp(r'"(access_token|client_secret|refresh_token)"\s*:\s*"[^"]*"'),
    RegExp(r'Ocp-Apim-Subscription-Key\s*[:=]\s*\S+', caseSensitive: false),
    // JWT (tres segmentos base64url).
    RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
  ];

  String redactar(String texto) {
    var r = texto;
    for (final s in _secretos) {
      r = r.replaceAll(s, '<redactado>');
    }
    for (final p in _patrones) {
      r = r.replaceAllMapped(p, (m) {
        final g = m.groupCount >= 1 ? m.group(1) : null;
        return g == null ? '<redactado>' : '$g=<redactado>';
      });
    }
    return r;
  }

  /// Cuerpo de respuesta para conservar: redactado y truncado. Nunca se
  /// registra en logs (va cifrado a la bitácora).
  String cuerpo(String texto, {int maximo = 4096}) {
    final r = redactar(texto);
    return r.length > maximo ? '${r.substring(0, maximo)}…' : r;
  }
}

enum NivelRegistro { info, advertencia, error }

class EntradaRegistro {
  const EntradaRegistro(this.nivel, this.evento, this.datos);

  final NivelRegistro nivel;
  final String evento;
  final Map<String, Object?> datos;

  @override
  String toString() => '[ihce] ${nivel.name} $evento $datos';
}

/// Logging del módulo. Las «alertas» son registros de nivel advertencia o
/// error en la capa de servicios (no avisos emergentes).
class RegistroIhce {
  RegistroIhce({Redactor? redactor, this.salida})
    : redactor = redactor ?? Redactor();

  final Redactor redactor;

  /// Destino (por defecto `debugPrint`). Las pruebas lo sustituyen.
  final void Function(EntradaRegistro e)? salida;

  /// Contadores por evento y categoría (observabilidad, Fase 6.8).
  final contadores = <String, int>{};

  void info(String evento, [Map<String, Object?> datos = const {}]) =>
      _emitir(NivelRegistro.info, evento, datos);

  void alerta(String evento, [Map<String, Object?> datos = const {}]) =>
      _emitir(NivelRegistro.advertencia, evento, datos);

  void error(String evento, [Map<String, Object?> datos = const {}]) =>
      _emitir(NivelRegistro.error, evento, datos);

  void contar(String clave) => contadores[clave] = (contadores[clave] ?? 0) + 1;

  void _emitir(NivelRegistro n, String evento, Map<String, Object?> datos) {
    final limpio = {
      for (final e in datos.entries)
        e.key: e.value is String
            ? redactor.redactar(e.value! as String)
            : e.value,
    };
    final entrada = EntradaRegistro(n, evento, limpio);
    final s = salida;
    if (s != null) {
      s(entrada);
    } else if (kDebugMode) {
      debugPrint(entrada.toString());
    }
  }
}
