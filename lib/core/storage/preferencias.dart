import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento local del navegador (localStorage). Se inyecta en
/// `main()` con la instancia ya cargada.
final preferenciasProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Se inyecta en main()'),
);

/// Claves usadas en el almacenamiento local.
abstract final class Claves {
  static const pais = 'hc.pais';
  static const borrador = 'hc.borrador.v1';
  static const borradorDesactivado = 'hc.borrador.desactivado';
  static const avisoPrivacidadCerrado = 'hc.avisoPrivacidad.cerrado';
}
