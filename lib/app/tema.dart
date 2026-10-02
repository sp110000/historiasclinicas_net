import 'package:flutter/material.dart';

/// Paleta sobria de salud. Ver docs/PLAN.md, sección "Paleta y estilo".
abstract final class ColoresMarca {
  static const primario = Color(0xFF1E6A8D);
  static const secundario = Color(0xFF2E9E83);
  static const aviso = Color(0xFFC98A1B);
  static const error = Color(0xFFC2413B);
  static const fondo = Color(0xFFF4F7F9);
  static const borde = Color(0xFFDCE4EA);
  static const bloqueado = Color(0xFFEEF2F5);
  static const textoSuave = Color(0xFF5F6B73);
}

ThemeData temaClaro() {
  final esquema = ColorScheme.fromSeed(
    seedColor: ColoresMarca.primario,
    primary: ColoresMarca.primario,
    secondary: ColoresMarca.secundario,
    error: ColoresMarca.error,
    surface: Colors.white,
  );
  const radio = BorderRadius.all(Radius.circular(10));
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: ColoresMarca.fondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shape: Border(bottom: BorderSide(color: ColoresMarca.borde)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFF8FAFB),
      border: OutlineInputBorder(borderRadius: radio),
      enabledBorder: OutlineInputBorder(
        borderRadius: radio,
        borderSide: BorderSide(color: ColoresMarca.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radio,
        borderSide: BorderSide(color: ColoresMarca.primario, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const RoundedRectangleBorder(borderRadius: radio),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: const RoundedRectangleBorder(borderRadius: radio),
      ),
    ),
  );
}
