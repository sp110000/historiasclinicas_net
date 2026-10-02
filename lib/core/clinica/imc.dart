/// Índice de masa corporal en kg/m², o `null` si faltan datos o no son
/// plausibles.
double? calcularImc({double? pesoKg, double? tallaCm}) {
  if (pesoKg == null || tallaCm == null) return null;
  if (pesoKg <= 0 || tallaCm < 20) return null;
  final metros = tallaCm / 100;
  return pesoKg / (metros * metros);
}

enum ClasificacionImc {
  bajoPeso('Bajo peso'),
  normal('Normal'),
  sobrepeso('Sobrepeso'),
  obesidad1('Obesidad grado I'),
  obesidad2('Obesidad grado II'),
  obesidad3('Obesidad grado III');

  const ClasificacionImc(this.etiqueta);

  final String etiqueta;

  bool get esNormal => this == normal;
}

/// Interpretación del IMC.
class InterpretacionImc {
  const InterpretacionImc({this.clasificacion, this.nota});

  /// Clasificación de la OMS para adultos; `null` si no aplica.
  final ClasificacionImc? clasificacion;

  /// Explicación cuando no se clasifica (niños, gestantes).
  final String? nota;

  String get texto => clasificacion?.etiqueta ?? nota ?? '';
}

/// Clasificación de la OMS para adultos (≥ 18 años, no gestantes).
InterpretacionImc interpretarImc(
  double imc, {
  required int? edadAnios,
  bool gestante = false,
}) {
  if (gestante) {
    return const InterpretacionImc(
      nota: 'En gestantes no aplica la clasificación estándar',
    );
  }
  if (edadAnios != null && edadAnios < 18) {
    return const InterpretacionImc(
      nota: 'Menor de 18 años: interpretar con percentiles (OMS)',
    );
  }
  final ClasificacionImc c;
  if (imc < 18.5) {
    c = ClasificacionImc.bajoPeso;
  } else if (imc < 25) {
    c = ClasificacionImc.normal;
  } else if (imc < 30) {
    c = ClasificacionImc.sobrepeso;
  } else if (imc < 35) {
    c = ClasificacionImc.obesidad1;
  } else if (imc < 40) {
    c = ClasificacionImc.obesidad2;
  } else {
    c = ClasificacionImc.obesidad3;
  }
  return InterpretacionImc(clasificacion: c);
}
