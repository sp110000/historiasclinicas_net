/// Estructuras que describen los perfiles del RDA. Los datos los genera
/// `tool/ihce/generar_perfiles.dart` en `perfiles_rda.g.dart`.
library;

/// Entrada admitida por un perfil Bundle*RDA (slicing cerrado de `entry`).
class EntradaPerfil {
  const EntradaPerfil({
    required this.slice,
    required this.tipo,
    required this.perfil,
    required this.min,
    required this.max,
  });

  final String slice;
  final String tipo;

  /// URL canónica exigida al recurso; `null` si el slice solo fija el tipo.
  final String? perfil;
  final int min;

  /// `'*'` o un número.
  final String max;
}

/// Sección de un perfil Composition*RDA.
class SeccionPerfil {
  const SeccionPerfil({
    required this.slice,
    required this.min,
    required this.max,
    required this.titulo,
    required this.tituloMin,
    required this.sistema,
    required this.codigo,
    required this.display,
    required this.entradaMin,
    required this.entradaMax,
    required this.emptyReasonPermitido,
    required this.perfilesEntrada,
  });

  final String slice;
  final int min;
  final String max;

  /// Título fijado por el perfil (`fixedString`), si lo hay.
  final String? titulo;
  final int tituloMin;
  final String? sistema;
  final String? codigo;
  final String? display;
  final int entradaMin;
  final String entradaMax;
  final bool emptyReasonPermitido;

  /// Perfiles que admite `section.entry`.
  final List<String> perfilesEntrada;

  bool get obligatoria => min >= 1;
}
