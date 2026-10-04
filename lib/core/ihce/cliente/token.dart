import 'dart:async';
import 'dart:convert';

import '../config/config_ihce.dart';
import '../reloj.dart';
import '../secretos/almacen_secretos.dart';
import 'registro.dart';
import 'resultado.dart';
import 'transporte.dart';

class TokenAcceso {
  const TokenAcceso(this.valor, this.venceEn);

  final String valor;
  final DateTime venceEn;

  @override
  String toString() => 'TokenAcceso(<redactado>, $venceEn)';
}

/// OAuth 2.0 Client Credentials contra Microsoft Entra ID (Manual de
/// Operaciones §5.2): cuerpo `application/x-www-form-urlencoded`, TLS 1.3.
///
/// * Caché por `(tenant, ambiente, scope)` hasta `expires_in` menos un
///   margen.
/// * Single-flight: N peticiones concurrentes con el token vencido producen
///   una sola petición al endpoint de token.
class GestorToken {
  GestorToken({
    required this.config,
    required this.transporte,
    required this.reloj,
    required this.registro,
    this.margen = const Duration(seconds: 90),
  });

  final ConfigIhce config;
  final TransporteIhce transporte;
  final Reloj reloj;
  final RegistroIhce registro;
  final Duration margen;

  final _cache = <String, TokenAcceso>{};
  final _enCurso = <String, Future<Object>>{};

  /// Peticiones al endpoint de token (observabilidad y pruebas).
  int peticiones = 0;

  String get _clave =>
      '${config.tenantId}|${config.ambiente.name}|${config.scope}';

  void invalidar() => _cache.remove(_clave);

  /// Devuelve un [TokenAcceso] o un [ResultadoEnvio] de error
  /// ([ErrorAuth] o [FalloTransitorio]).
  Future<Object> obtener(CredencialesIhce credenciales) {
    final vigente = _cache[_clave];
    if (vigente != null && reloj.ahora().isBefore(vigente.venceEn)) {
      return Future.value(vigente);
    }
    final clave = _clave;
    return _enCurso[clave] ??= _pedir(
      credenciales,
    ).whenComplete(() => _enCurso.remove(clave));
  }

  Future<Object> _pedir(CredencialesIhce c) async {
    registro.redactor.agregar(c.secretos);
    peticiones++;
    final cuerpo = Uri(
      queryParameters: {
        'grant_type': 'client_credentials',
        'client_id': c.clientId,
        'client_secret': c.clientSecret,
        'scope': config.scope,
      },
    ).query;
    final RespuestaHttp r;
    try {
      r = await transporte.enviar(
        PeticionHttp(
          metodo: 'POST',
          url: Uri.parse(config.tokenUrlResuelta),
          cabeceras: const {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          cuerpo: utf8.encode(cuerpo),
        ),
      );
    } on FalloRed catch (e) {
      registro.alerta('token_fallo_red', {'tipo': e.tipo});
      return FalloTransitorio(causa: 'token:${e.tipo}');
    }
    if (r.status == 200) {
      try {
        final m = (jsonDecode(r.cuerpo) as Map).cast<String, Object?>();
        final token = m['access_token'] as String;
        registro.redactor.agregar([token]);
        final segundos = (m['expires_in'] as num?)?.toInt() ?? 0;
        final t = TokenAcceso(
          token,
          reloj.ahora().add(Duration(seconds: segundos) - margen),
        );
        _cache[_clave] = t;
        registro.info('token_obtenido', {'expira_s': segundos});
        return t;
      } on Object {
        return const ErrorAuth(
          httpStatus: 200,
          detalleRedactado: 'Respuesta de token ilegible',
        );
      }
    }
    if (r.status == 429 || r.status >= 500) {
      registro.alerta('token_transitorio', {'http': r.status});
      return FalloTransitorio(causa: 'token', httpStatus: r.status);
    }
    registro.alerta('token_rechazado', {'http': r.status});
    return ErrorAuth(
      httpStatus: r.status,
      detalleRedactado: registro.redactor.cuerpo(r.cuerpo, maximo: 300),
    );
  }
}
