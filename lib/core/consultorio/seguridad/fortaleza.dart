/// Qué tan difícil de adivinar es una frase de acceso (orientativo).
enum NivelFrase {
  corta('Muy corta: usa al menos 12 caracteres'),
  debil('Débil: agrega palabras o mezcla letras, números y signos'),
  aceptable('Aceptable'),
  fuerte('Fuerte');

  const NivelFrase(this.texto);

  final String texto;

  bool get admitida => this != corta;
}

const largoMinimoFrase = 12;

/// Más largo y con más palabras es mejor que una contraseña corta y rara:
/// se recomienda una frase de varias palabras que solo tú conozcas.
NivelFrase evaluarFrase(String frase) {
  final f = frase.trim();
  if (f.runes.length < largoMinimoFrase) return NivelFrase.corta;
  final distintos = f.toLowerCase().runes.toSet().length;
  if (distintos < 6) return NivelFrase.debil;
  final palabras = f
      .split(RegExp(r'\s+'))
      .where((p) => p.runes.length >= 3)
      .length;
  var clases = 0;
  if (RegExp('[a-záéíóúñü]').hasMatch(f)) clases++;
  if (RegExp('[A-ZÁÉÍÓÚÑÜ]').hasMatch(f)) clases++;
  if (RegExp(r'\d').hasMatch(f)) clases++;
  if (RegExp(r'[^\wáéíóúñüÁÉÍÓÚÑÜ\s]').hasMatch(f)) clases++;
  if (f.runes.length >= 20 || palabras >= 4) return NivelFrase.fuerte;
  if (palabras >= 3 || clases >= 3) return NivelFrase.aceptable;
  return NivelFrase.debil;
}
