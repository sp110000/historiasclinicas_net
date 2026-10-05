import 'dart:convert';

import '../../cie10/catalogo_cie10.dart';
import '../config/config_ihce.dart';
import '../perfiles/perfiles_rda.g.dart';

/// Un ValueSet de la guía: sistemas enteros o códigos enumerados.
class _InclusionVs {
  const _InclusionVs(this.system, this.codigos);

  final String system;

  /// `null`: incluye todo el sistema.
  final Set<String>? codigos;
}

/// Catálogo versionado `(system, code) → display`. El `display` emitido en
/// el RDA sale siempre de aquí: nunca del texto digitado por el usuario ni
/// del nombre que el repositorio tenga guardado para el código.
///
/// Fuentes, según el `content` del CodeSystem en la guía:
/// * `complete` → el artefacto de la guía (`assets/ihce/catalogos_guia.json`);
/// * `fragment` → la guía no basta: se completa con catálogos importados
///   desde archivo (tablas SISPRO) o sincronizados en línea (P1). El CIE-10
///   usa la tabla SISPRO de la app (D6).
class CatalogoTerminologia {
  CatalogoTerminologia._(this._conceptos, this._contenido, this._valueSets);

  /// Lee `assets/ihce/catalogos_guia.json` (generado de la guía).
  factory CatalogoTerminologia.desdeGuia(String json) {
    final m = (jsonDecode(json) as Map).cast<String, Object?>();
    final conceptos = <String, Map<String, String>>{};
    final contenido = <String, String>{};
    for (final e
        in (m['codeSystems']! as Map).cast<String, Object?>().entries) {
      final cs = (e.value! as Map).cast<String, Object?>();
      conceptos[e.key] = (cs['conceptos']! as Map).cast<String, String>();
      contenido[e.key] = cs['content']! as String;
    }
    final valueSets = <String, List<_InclusionVs>>{};
    for (final e in (m['valueSets']! as Map).cast<String, Object?>().entries) {
      final vs = (e.value! as Map).cast<String, Object?>();
      valueSets[e.key] = [
        for (final inc in (vs['include']! as List).cast<Map>())
          if (inc['system'] != null)
            _InclusionVs(
              inc['system']! as String,
              inc['codigos'] == null
                  ? null
                  : {for (final c in inc['codigos'] as List) c as String},
            ),
      ];
    }
    return CatalogoTerminologia._(conceptos, contenido, valueSets);
  }

  final Map<String, Map<String, String>> _conceptos;
  final Map<String, String> _contenido;
  final Map<String, List<_InclusionVs>> _valueSets;

  /// Catálogos agregados por encima de la guía (importados o SISPRO).
  final _adicionales = <String, Map<String, String>>{};

  /// Sistemas que un rechazo semántico marcó para sincronizar (Fase 5.6).
  final marcadosParaSincronizar = <String>{};

  CatalogoCie10? _cie10;
  FuenteDisplayCie10 _fuenteCie10 = FuenteDisplayCie10.sispro;
  Map<String, String>? _cie10PorCodigo;

  /// Usa el catálogo CIE-10 de la app (tabla SISPRO incluida o importada)
  /// para `http://hl7.org/fhir/sid/icd-10`, según D6.
  void usarCie10(CatalogoCie10 catalogo, FuenteDisplayCie10 fuente) {
    _cie10 = catalogo;
    _fuenteCie10 = fuente;
    _cie10PorCodigo = null;
  }

  /// Agrega o reemplaza los conceptos importados de [system].
  void registrar(String system, Map<String, String> conceptos) =>
      _adicionales[system] = Map.unmodifiable(conceptos);

  String? contenidoDe(String system) => _contenido[system];

  /// `display` oficial, o `null` si el código no está en ningún catálogo
  /// cargado (bloqueo local SEMANTICO).
  String? display(String system, String code) {
    if (system == SistemaRda.icd10CO &&
        _fuenteCie10 == FuenteDisplayCie10.sispro &&
        _cie10 != null) {
      final porCodigo = _cie10PorCodigo ??= {
        for (final e in _cie10!.entradas) e.codigo: e.descripcion,
      };
      return porCodigo[code];
    }
    return _adicionales[system]?[code] ?? _conceptos[system]?[code];
  }

  bool contiene(String system, String code) => display(system, code) != null;

  /// ¿[code] de [system] pertenece al ValueSet [url]?
  bool enValueSet(String url, String system, String code) {
    final inc = _valueSets[url];
    if (inc == null) return false;
    for (final i in inc) {
      if (i.system != system) continue;
      if (i.codigos == null
          ? contiene(system, code)
          : i.codigos!.contains(code)) {
        return true;
      }
    }
    return false;
  }

  /// Códigos y `display` de un ValueSet enumerado o de un sistema completo
  /// (para los desplegables de la regla 10).
  List<(String codigo, String display)> opciones(String urlValueSet) {
    final r = <(String, String)>[];
    for (final i in _valueSets[urlValueSet] ?? const <_InclusionVs>[]) {
      final Iterable<String> codigos =
          i.codigos ?? _conceptos[i.system]?.keys ?? const <String>[];
      for (final c in codigos) {
        final d = display(i.system, c);
        if (d != null) r.add((c, d));
      }
    }
    return r;
  }

  /// Estado de carga de cada CodeSystem usado (reporte de la Fase 9).
  Map<String, String> estadoDeCarga() => {
    for (final s in _contenido.keys)
      s: _contenido[s] == 'complete'
          ? 'completo (guía)'
          : _adicionales.containsKey(s) ||
                (s == SistemaRda.icd10CO && _cie10 != null)
          ? 'fragmento en la guía; completado por importación'
          : 'fragmento en la guía; pendiente de carga',
  };
}
