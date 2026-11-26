import 'package:flutter/material.dart';

/// Dirección visual «Naranja cálido» (noviembre de 2026), con el naranja
/// «Mandarina» desde el 26/11/2026: naranja de marca,
/// neutros cálidos y color solo con significado: verde = todo bien,
/// ámbar = atención, carmesí = peligro. Ver docs/REDISENO.md.
///
/// Los contrastes indicados son sobre blanco (WCAG AA pide 4,5:1 en texto).
abstract final class ColoresMarca {
  /// Naranja de marca «Mandarina» (#FF6A13), el del logo: acentos y barras
  /// de avance. No se usa para texto ni para bordes de foco (2,9:1).
  static const marca = Color(0xFFFF6A13);

  /// Naranja de botones, enlaces y foco: el de marca un poco más hondo para
  /// que el texto blanco y el texto naranja se lean bien.
  static const primario = Color(0xFFB8470A); // 5,3:1 · 4,8:1 sobre tinte
  static const secundario = primario; // ℞ y números de la receta
  static const estadoOk = Color(0xFF1E6B3A); // «Completa», integridad · 6,5:1
  static const estadoOkFondo = Color(0xFFE7F3EA);
  static const aviso = Color(0xFF8A5A0B); // 5,9:1
  static const error = Color(0xFF9B1C3A); // carmesí, lejos del naranja · 8:1
  static const errorFondo = Color(0xFFFCE7EC);
  static const fondo = Color(0xFFFAF6F3);
  static const borde = Color(0xFFEADFD8);
  static const bordeCampo = Color(0xFFD9C9BF);
  static const separador = Color(0xFFF3ECE7); // bajo la cabecera de tarjeta
  static const bloqueado = Color(0xFFF6F1ED);
  static const deshabilitado = Color(0xFFEDE4DE);
  static const textoDeshabilitado = Color(0xFF9C8E87);
  static const interruptorApagado = Color(0xFFCFC3BB);
  static const textoSuave = Color(0xFF6A5C55); // 6,4:1
  static const tinta = Color(0xFF2B211D); // texto principal · 15,7:1
  static const tintaSuave = Color(0xFF574A44); // etiquetas · 8,5:1
  static const pista = Color(0xFF7A6B64); // textos de ayuda · 5,1:1
  static const tinte = Color(0xFFFFF1E6); // selección y fondos tonales
  static const tinteTexto = Color(0xFF9A3B07); // texto sobre tinte · 6,3:1
  static const neutroFondo = Color(0xFFF4EEEA); // chips y avatares neutros
  static const avisoFondo = Color(0xFFFFF6DD);
  static const avisoBorde = Color(0xFFF3DC97);
  static const avisoTexto = Color(0xFF5C3C06); // 9,3:1 sobre avisoFondo

  /// [c] mezclado sobre blanco: fondos de los recuadros de ícono y bordes
  /// suaves de los avisos.
  static Color sobreBlanco(Color c, double alfa) =>
      Color.alphaBlend(c.withValues(alpha: alfa), Colors.white);
}

/// Radios de esquina: redondeados y suaves; los botones son píldoras.
abstract final class RadiosMarca {
  /// Campos, avisos flotantes e índice.
  static const control = BorderRadius.all(Radius.circular(12));

  /// Menús y recuadros de ícono.
  static const recuadro = BorderRadius.all(Radius.circular(14));

  /// Tarjetas y avisos.
  static const tarjeta = BorderRadius.all(Radius.circular(20));

  /// Diálogos.
  static const dialogo = BorderRadius.all(Radius.circular(24));

  /// Píldoras.
  static const pildora = BorderRadius.all(Radius.circular(999));
}

/// Estilos de texto propios del sistema que no están en el TextTheme.
abstract final class EstilosMarca {
  /// Rótulo en versalitas: «SECCIÓN 3», «ASÍ APARECERÁ EN TUS DOCUMENTOS».
  static const rotulo = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.9,
    color: ColoresMarca.textoSuave,
  );

  /// Título de tarjeta y de diálogo.
  static const titulo = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: ColoresMarca.tinta,
  );
}

ThemeData temaClaro() {
  final esquema = ColorScheme.fromSeed(seedColor: ColoresMarca.primario)
      .copyWith(
        primary: ColoresMarca.primario,
        onPrimary: Colors.white,
        secondary: ColoresMarca.secundario,
        secondaryContainer: ColoresMarca.tinte,
        onSecondaryContainer: ColoresMarca.tinteTexto,
        error: ColoresMarca.error,
        surface: Colors.white,
        onSurface: ColoresMarca.tinta,
        onSurfaceVariant: ColoresMarca.textoSuave,
        outline: ColoresMarca.bordeCampo,
        outlineVariant: ColoresMarca.borde,
      );
  // Los estilos de los temas de componentes no heredan la familia del
  // TextTheme: sin [fuente] saldrían con la fuente de respaldo del motor.
  const fuente = 'Inter';
  // La etiqueta va siempre sobre el borde y Flutter la dibuja al 75 %: con
  // 13 / 0,75 se ve a los 13 px del diseño.
  const etiqueta = TextStyle(
    fontFamily: fuente,
    fontSize: 13 / 0.75,
    fontWeight: FontWeight.w500,
    color: ColoresMarca.tintaSuave,
  );
  const botonTexto = TextStyle(
    fontFamily: fuente,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: fuente,
  );
  // Se mezcla (merge) sobre el TextTheme base para conservar Inter.
  final textos = base.textTheme.apply(
    bodyColor: ColoresMarca.tinta,
    displayColor: ColoresMarca.tinta,
  );

  return base.copyWith(
    scaffoldBackgroundColor: ColoresMarca.fondo,
    textTheme: textos.copyWith(
      titleLarge: textos.titleLarge!.merge(EstilosMarca.titulo),
      titleMedium: textos.titleMedium!.merge(
        const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      bodyLarge: textos.bodyLarge!.merge(
        const TextStyle(fontSize: 15, height: 1.5, letterSpacing: 0),
      ),
      bodyMedium: textos.bodyMedium!.merge(
        const TextStyle(fontSize: 14, height: 1.45, letterSpacing: 0),
      ),
      labelSmall: textos.labelSmall!.merge(EstilosMarca.rotulo),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ColoresMarca.tinta,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: ColoresMarca.borde)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: etiqueta,
      floatingLabelStyle: etiqueta,
      hintStyle: TextStyle(fontFamily: fuente, color: ColoresMarca.pista),
      helperStyle: TextStyle(
        fontFamily: fuente,
        fontSize: 12.5,
        color: ColoresMarca.textoSuave,
      ),
      errorStyle: TextStyle(
        fontFamily: fuente,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: ColoresMarca.error,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: RadiosMarca.control),
      enabledBorder: OutlineInputBorder(
        borderRadius: RadiosMarca.control,
        borderSide: BorderSide(color: ColoresMarca.bordeCampo),
      ),
      // El foco en el naranja de los botones (5,3:1; el de marca no llega a
      // 3:1), que no se confunde con el carmesí de los errores.
      focusedBorder: OutlineInputBorder(
        borderRadius: RadiosMarca.control,
        borderSide: BorderSide(color: ColoresMarca.primario, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: RadiosMarca.control,
        borderSide: BorderSide(color: ColoresMarca.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: RadiosMarca.control,
        borderSide: BorderSide(color: ColoresMarca.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: RadiosMarca.control,
        borderSide: BorderSide(color: ColoresMarca.deshabilitado),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const RoundedRectangleBorder(borderRadius: RadiosMarca.pildora),
        textStyle: botonTexto,
        disabledBackgroundColor: ColoresMarca.deshabilitado,
        disabledForegroundColor: ColoresMarca.textoDeshabilitado,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: const RoundedRectangleBorder(borderRadius: RadiosMarca.pildora),
        foregroundColor: ColoresMarca.tinta,
        side: const BorderSide(color: ColoresMarca.bordeCampo),
        textStyle: botonTexto,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        foregroundColor: ColoresMarca.primario,
        shape: const RoundedRectangleBorder(borderRadius: RadiosMarca.pildora),
        textStyle: botonTexto,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: ColoresMarca.tintaSuave,
      ),
    ),
    chipTheme: const ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: RadiosMarca.pildora),
      side: BorderSide(color: ColoresMarca.bordeCampo),
      backgroundColor: Colors.white,
      selectedColor: ColoresMarca.primario,
      labelStyle: TextStyle(
        fontFamily: fuente,
        fontSize: 13.5,
        color: ColoresMarca.tinta,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: fuente,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    dialogTheme: const DialogThemeData(
      actionsPadding: EdgeInsets.fromLTRB(24, 8, 24, 20),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: RadiosMarca.dialogo),
      titleTextStyle: TextStyle(
        fontFamily: fuente,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: ColoresMarca.tinta,
      ),
      contentTextStyle: TextStyle(
        fontFamily: fuente,
        fontSize: 15,
        height: 1.5,
        color: ColoresMarca.tintaSuave,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ColoresMarca.tinta,
      contentTextStyle: TextStyle(
        fontFamily: fuente,
        fontSize: 14,
        color: Colors.white,
      ),
      actionTextColor: Colors.white,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: RadiosMarca.control),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: RadiosMarca.recuadro,
            side: BorderSide(color: ColoresMarca.borde),
          ),
        ),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: RadiosMarca.recuadro),
    ),
    dividerTheme: const DividerThemeData(color: ColoresMarca.borde, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ColoresMarca.marca,
      linearTrackColor: ColoresMarca.tinte,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? ColoresMarca.estadoOk
            : ColoresMarca.interruptorApagado,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? ColoresMarca.primario
            : Colors.transparent,
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: ColoresMarca.tinta,
        borderRadius: RadiosMarca.control,
      ),
      textStyle: TextStyle(
        fontFamily: fuente,
        fontSize: 12.5,
        color: Colors.white,
      ),
    ),
  );
}
