import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/medico.dart';
import 'preferencias.dart';

/// Perfil del médico en el almacenamiento local de este navegador.
class MedicoStore {
  MedicoStore(this._prefs);

  final SharedPreferences _prefs;

  Medico leer() {
    final texto = _prefs.getString(Claves.medico);
    if (texto == null) return const Medico();
    try {
      return Medico.desdeAlmacen((jsonDecode(texto) as Map).cast());
    } on Object {
      return const Medico();
    }
  }

  Future<void> guardar(Medico medico) => medico.vacio
      ? _prefs.remove(Claves.medico)
      : _prefs.setString(Claves.medico, jsonEncode(medico.aAlmacen()));

  Future<void> borrar() => _prefs.remove(Claves.medico);
}
