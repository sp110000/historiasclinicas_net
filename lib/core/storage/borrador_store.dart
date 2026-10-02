import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'preferencias.dart';

class BorradorGuardado {
  const BorradorGuardado(this.guardadoEn, this.contenido);

  final DateTime guardadoEn;
  final Map<String, Object?> contenido;
}

/// Borrador de la historia en curso, guardado solo en este navegador para
/// no perder lo escrito si se cierra la pestaña.
class BorradorStore {
  BorradorStore(this._prefs);

  final SharedPreferences _prefs;

  bool get desactivado => _prefs.getBool(Claves.borradorDesactivado) ?? false;

  Future<void> cambiarDesactivado(bool valor) async {
    await _prefs.setBool(Claves.borradorDesactivado, valor);
    if (valor) await borrar();
  }

  /// `null` si no hay borrador o no se puede leer.
  BorradorGuardado? leer() {
    final texto = _prefs.getString(Claves.borrador);
    if (texto == null) return null;
    try {
      final m = (jsonDecode(texto) as Map).cast<String, Object?>();
      return BorradorGuardado(
        DateTime.parse(m['guardadoEn']! as String),
        (m['contenido']! as Map).cast<String, Object?>(),
      );
    } on Object {
      return null;
    }
  }

  Future<DateTime> guardar(Map<String, Object?> contenido) async {
    final ahora = DateTime.now();
    await _prefs.setString(
      Claves.borrador,
      jsonEncode({
        'guardadoEn': ahora.toIso8601String(),
        'contenido': contenido,
      }),
    );
    return ahora;
  }

  /// Borra todo lo que está en curso: la historia y la receta.
  Future<void> borrar() async {
    await _prefs.remove(Claves.borrador);
    await _prefs.remove(Claves.receta);
  }
}
