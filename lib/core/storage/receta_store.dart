import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../receta/medicamentos.dart';
import '../receta/receta.dart';
import 'preferencias.dart';

/// Receta en curso, numeración y "Mis medicamentos", en el almacenamiento
/// local de este navegador.
class RecetaStore {
  RecetaStore(this._prefs);

  final SharedPreferences _prefs;

  Receta? leer() {
    final texto = _prefs.getString(Claves.receta);
    if (texto == null) return null;
    try {
      return Receta.desdeMapa((jsonDecode(texto) as Map).cast());
    } on Object {
      return null;
    }
  }

  Future<void> guardar(Receta receta) =>
      _prefs.setString(Claves.receta, jsonEncode(receta.aMapa()));

  Future<void> borrar() => _prefs.remove(Claves.receta);

  // ── Numeración (el contador es de este navegador) ──

  bool get numerar => _prefs.getBool(Claves.recetaNumerar) ?? false;

  Future<void> cambiarNumerar(bool valor) =>
      _prefs.setBool(Claves.recetaNumerar, valor);

  /// Último número asignado (0 si ninguno).
  int get ultimoNumero => _prefs.getInt(Claves.recetaContador) ?? 0;

  /// El número que recibirá la próxima receta.
  String get proximoNumero => formatoNumeroReceta(ultimoNumero + 1);

  /// Asigna el siguiente número y lo deja guardado.
  Future<String> asignarNumero() async {
    final n = ultimoNumero + 1;
    await _prefs.setInt(Claves.recetaContador, n);
    return formatoNumeroReceta(n);
  }

  /// Para continuar la numeración de otro equipo o de un talonario.
  Future<void> cambiarUltimoNumero(int n) =>
      _prefs.setInt(Claves.recetaContador, n);

  /// Título impreso en la hoja ("Receta médica" por defecto).
  String get titulo => _prefs.getString(Claves.recetaTitulo) ?? 'Receta médica';

  Future<void> cambiarTitulo(String titulo) =>
      _prefs.setString(Claves.recetaTitulo, titulo);

  // ── Mis medicamentos ──

  List<PlantillaMedicamento> leerMedicamentos() {
    final texto = _prefs.getString(Claves.medicamentos);
    if (texto == null) return const [];
    try {
      return [
        for (final m in jsonDecode(texto) as List)
          PlantillaMedicamento.desdeMapa((m as Map).cast()),
      ];
    } on Object {
      return const [];
    }
  }

  Future<void> guardarMedicamentos(List<PlantillaMedicamento> lista) =>
      lista.isEmpty
      ? _prefs.remove(Claves.medicamentos)
      : _prefs.setString(
          Claves.medicamentos,
          jsonEncode([for (final p in lista) p.aMapa()]),
        );
}
