/// Búsqueda sin distinguir tildes ni mayúsculas, y documentos sin puntos ni
/// espacios.
library;

const _sinTilde = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', //
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', //
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
  'ñ': 'n', 'ç': 'c',
};

/// «Peña  MUÑOZ» → «pena munoz».
String paraBuscar(String texto) {
  final b = StringBuffer();
  for (final c in texto.toLowerCase().split('')) {
    b.write(_sinTilde[c] ?? c);
  }
  return b
      .toString()
      .replaceAll(RegExp(r'[̀-ͯ]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// «1.032.456 789» → «1032456789»; letras en mayúscula (pasaportes).
String documentoNormalizado(String numero) =>
    numero.replaceAll(RegExp(r'[\s.\-]'), '').toUpperCase();

/// Tipos de documento de una persona sin identificar: cada historia es una
/// ficha aparte hasta que el médico las una.
const tiposSinIdentificar = {'AS', 'MS'};

/// Clave natural de la ficha: tipo y número normalizados, o `null` si el
/// paciente no tiene un documento que lo identifique.
String? claveDocumento(String tipo, String numero) {
  final n = documentoNormalizado(numero);
  final t = tipo.trim().toUpperCase();
  if (n.isEmpty || t.isEmpty || tiposSinIdentificar.contains(t)) return null;
  return '$t:$n';
}
