import '../config/config_ihce.dart';

/// Único componente que decide los `id` y el texto de las referencias del
/// RDA (D1). Ningún mapper concatena referencias a mano.
///
/// Convenciones (Manual de Operaciones §5.3, colección Postman v1.5):
///
/// | Recurso | `id` | referencia |
/// | --- | --- | --- |
/// | nuevo | `{Tipo}-{n}` (n desde 0) | `#{Tipo}-{n}` |
/// | Patient, Practitioner | `{TipoDoc}-{NumDoc}` | `#{TipoDoc}-{NumDoc}` |
/// | Organization (IPS) | `{CódigoHabilitación}` | `#{CódigoHabilitación}` |
/// | Organization (EAPB) | `{CódigoEAPB}` | `#{CódigoEAPB}` |
///
/// Con [EstiloReferencia.plain] se omite el `#` (ejemplo de la guía).
class ReferenciasRda {
  ReferenciasRda(this.estilo);

  final EstiloReferencia estilo;
  final _contadores = <String, int>{};

  /// `{Tipo}-{n}` estable: el orden de llamada lo fija el ensamblador.
  String nuevoId(String tipoRecurso) {
    final n = (_contadores[tipoRecurso] ?? -1) + 1;
    _contadores[tipoRecurso] = n;
    return '$tipoRecurso-$n';
  }

  static String idPersona(String tipoDocumento, String numeroDocumento) =>
      '$tipoDocumento-$numeroDocumento';

  static String idOrganizacionIps(String codigoHabilitacion) =>
      codigoHabilitacion;

  static String idEapb(String codigoEapb) => codigoEapb;

  /// `{"reference": "#id"}` o `{"reference": "id"}`.
  Map<String, Object?> referencia(String idLocal) => {
    'reference': texto(idLocal),
  };

  String texto(String idLocal) =>
      estilo == EstiloReferencia.hash ? '#$idLocal' : idLocal;

  /// El `id` local al que apunta [referencia], o `null` si es una referencia
  /// externa absoluta o de tipo (`Organization/MinSalud`).
  String? idDe(String referencia) {
    if (referencia.startsWith('#')) return referencia.substring(1);
    if (referencia.contains('/')) return null;
    return referencia;
  }
}
