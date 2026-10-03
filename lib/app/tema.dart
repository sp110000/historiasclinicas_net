import 'package:flutter/material.dart';

/// Dirección visual 2b «Clínico sobrio»: azul petróleo, blancos fríos y
/// verde solo para estados. Ver docs/PLAN.md, sección "Paleta y estilo".
///
/// Los contrastes indicados son sobre blanco (WCAG AA pide 4,5:1 en texto).
abstract final class ColoresMarca {
  static const primario = Color(0xFF1E5A7A); // petróleo · 7,5:1
  static const secundario = primario; // ℞ y números de la receta
  static const estadoOk = Color(0xFF2E7D5B); // «Completa», integridad · 5,0:1
  static const aviso = Color(0xFF8A5A0B); // 5,9:1
  static const error = Color(0xFFB3362F); // 6,0:1
  static const fondo = Color(0xFFF3F6F8);
  static const borde = Color(0xFFD8E1E7);
  static const bordeCampo = Color(0xFFC9D4DC);
  static const separador = Color(0xFFE6ECF0); // bajo la cabecera de tarjeta
  static const bloqueado = Color(0xFFEDF2F5);
  static const deshabilitado = Color(0xFFE1E7EC);
  static const textoDeshabilitado = Color(0xFF8995A0);
  static const interruptorApagado = Color(0xFFB9C4CC);
  static const textoSuave = Color(0xFF556370); // 6,2:1
  static const tinta = Color(0xFF13212C); // texto principal · 16:1
  static const tintaSuave = Color(0xFF3B4853); // etiquetas · 9,4:1
  static const pista = Color(0xFF6B7782); // textos de ayuda · 4,6:1
  static const tinte = Color(0xFFE6EFF4); // selección y fondos tonales
  static const avisoFondo = Color(0xFFFBF3E3);
  static const avisoBorde = Color(0xFFE8D6AE);
  static const avisoTexto = Color(0xFF5C3C06); // 9,1:1 sobre avisoFondo

  /// [c] mezclado sobre blanco: fondos de los recuadros de ícono y bordes
  /// suaves de los avisos.
  static Color sobreBlanco(Color c, double alfa) =>
      Color.alphaBlend(c.withValues(alpha: alfa), Colors.white);
}

/// Radios de esquina del sistema 2b.
abstract final class RadiosMarca {
  /// Campos, botones, chips, avisos flotantes e índice.
  static const control = BorderRadius.all(Radius.circular(8));

  /// Menús y recuadros de ícono.
  static const recuadro = BorderRadius.all(Radius.circular(10));

  /// Tarjetas y avisos.
  static const tarjeta = BorderRadius.all(Radius.circular(12));

  /// Diálogos.
  static const dialogo = BorderRadius.all(Radius.circular(14));

  /// Píldoras.
  static const pildora = BorderRadius.all(Radius.circular(999));
}

/// Estilos de texto propios del sistema 2b que no están en el TextTheme.
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
    fontWeight: FontWeight.w600,
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
        onSecondaryContainer: ColoresMarca.primario,
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
  const etiqueta = TextStyle(
    fontFamily: fuente,
    fontSize: 13,
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
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: const RoundedRectangleBorder(borderRadius: RadiosMarca.control),
        textStyle: botonTexto,
        disabledBackgroundColor: ColoresMarca.deshabilitado,
        disabledForegroundColor: ColoresMarca.textoDeshabilitado,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const RoundedRectangleBorder(borderRadius: RadiosMarca.control),
        foregroundColor: ColoresMarca.tinta,
        side: const BorderSide(color: ColoresMarca.bordeCampo),
        textStyle: botonTexto,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        foregroundColor: ColoresMarca.primario,
        shape: const RoundedRectangleBorder(borderRadius: RadiosMarca.control),
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
      shape: RoundedRectangleBorder(borderRadius: RadiosMarca.control),
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
      color: ColoresMarca.primario,
      linearTrackColor: ColoresMarca.tinte,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? ColoresMarca.primario
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
