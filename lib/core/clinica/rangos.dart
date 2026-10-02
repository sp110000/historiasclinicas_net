/// Rangos para revisar los signos vitales mientras se escriben.
///
/// * Fuera de lo **plausible**: casi seguro un error de digitación; se
///   marca como error y no deja finalizar la historia.
/// * Fuera de lo **habitual en adultos**: aviso en ámbar que nunca bloquea.
///   En menores de 18 años no se muestra (los rangos dependen de la edad).
library;

class RangoSigno {
  const RangoSigno({
    required this.minPlausible,
    required this.maxPlausible,
    this.minHabitual,
    this.maxHabitual,
  });

  final double minPlausible;
  final double maxPlausible;
  final double? minHabitual;
  final double? maxHabitual;

  bool esPlausible(double v) => v >= minPlausible && v <= maxPlausible;

  bool esHabitual(double v) =>
      (minHabitual == null || v >= minHabitual!) &&
      (maxHabitual == null || v <= maxHabitual!);
}

abstract final class Rangos {
  static const paSistolica = RangoSigno(
    minPlausible: 40,
    maxPlausible: 300,
    minHabitual: 90,
    maxHabitual: 139,
  );
  static const paDiastolica = RangoSigno(
    minPlausible: 20,
    maxPlausible: 200,
    minHabitual: 60,
    maxHabitual: 89,
  );
  static const fc = RangoSigno(
    minPlausible: 20,
    maxPlausible: 300,
    minHabitual: 60,
    maxHabitual: 100,
  );
  static const fr = RangoSigno(
    minPlausible: 4,
    maxPlausible: 100,
    minHabitual: 12,
    maxHabitual: 20,
  );
  static const temperatura = RangoSigno(
    minPlausible: 25,
    maxPlausible: 45,
    minHabitual: 36,
    maxHabitual: 37.5,
  );
  static const spo2 = RangoSigno(
    minPlausible: 30,
    maxPlausible: 100,
    minHabitual: 94,
  );
  static const peso = RangoSigno(minPlausible: 0.3, maxPlausible: 400);
  static const talla = RangoSigno(minPlausible: 20, maxPlausible: 250);
  static const glucemia = RangoSigno(minPlausible: 10, maxPlausible: 1500);
  static const perimetroAbdominal = RangoSigno(
    minPlausible: 20,
    maxPlausible: 250,
  );
}
