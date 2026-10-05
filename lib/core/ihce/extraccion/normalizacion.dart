/// Normalización de textos de identidad (Fase 4.3): recorte, colapso de
/// espacios y composición canónica (NFC) de las letras del español.
library;

/// Dart no trae normalización Unicode: se componen las combinaciones que
/// aparecen en nombres en español (vocal o n + tilde, diéresis, virgulilla o
/// acento grave). Lo demás queda tal cual.
const _composiciones = <String, String>{
  'a\u0301': '\u00E1', // á
  'e\u0301': '\u00E9', // é
  'i\u0301': '\u00ED', // í
  'o\u0301': '\u00F3', // ó
  'u\u0301': '\u00FA', // ú
  'A\u0301': '\u00C1', // Á
  'E\u0301': '\u00C9', // É
  'I\u0301': '\u00CD', // Í
  'O\u0301': '\u00D3', // Ó
  'U\u0301': '\u00DA', // Ú
  'u\u0308': '\u00FC', // ü
  'U\u0308': '\u00DC', // Ü
  'n\u0303': '\u00F1', // ñ
  'N\u0303': '\u00D1', // Ñ
  'a\u0300': '\u00E0', // à
  'e\u0300': '\u00E8', // è
  'i\u0300': '\u00EC', // ì
  'o\u0300': '\u00F2', // ò
  'u\u0300': '\u00F9', // ù
  'i\u0308': '\u00EF', // ï
  'e\u0308': '\u00EB', // ë
  'o\u0308': '\u00F6', // ö
  'a\u0308': '\u00E4', // ä
  'c\u0327': '\u00E7', // ç
  'C\u0327': '\u00C7', // Ç
};

String componerNfc(String s) {
  if (!s.runes.any((r) => r >= 0x0300 && r <= 0x036F)) return s;
  var r = s;
  for (final e in _composiciones.entries) {
    r = r.replaceAll(e.key, e.value);
  }
  return r;
}

/// Recorta, colapsa espacios y compone.
String normalizarTexto(String s) =>
    componerNfc(s.trim().replaceAll(RegExp(r'\s+'), ' '));

/// Número de documento sin espacios ni puntos de miles («1.032.456.789»).
String normalizarNumeroDocumento(String s) =>
    s.replaceAll(RegExp(r'[\s.]'), '');

/// Comparación sin distinguir mayúsculas.
bool igualesSinMayusculas(String a, String b) =>
    normalizarTexto(a).toLowerCase() == normalizarTexto(b).toLowerCase();
