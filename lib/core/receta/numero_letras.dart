/// Números en letras para la cantidad de la receta: 21 → "veintiuno".
library;

const _unidades = [
  'cero',
  'uno',
  'dos',
  'tres',
  'cuatro',
  'cinco',
  'seis',
  'siete',
  'ocho',
  'nueve',
  'diez',
  'once',
  'doce',
  'trece',
  'catorce',
  'quince',
  'dieciséis',
  'diecisiete',
  'dieciocho',
  'diecinueve',
  'veinte',
  'veintiuno',
  'veintidós',
  'veintitrés',
  'veinticuatro',
  'veinticinco',
  'veintiséis',
  'veintisiete',
  'veintiocho',
  'veintinueve',
];

const _decenas = [
  '',
  '',
  '',
  'treinta',
  'cuarenta',
  'cincuenta',
  'sesenta',
  'setenta',
  'ochenta',
  'noventa',
];

const _centenas = [
  '',
  'ciento',
  'doscientos',
  'trescientos',
  'cuatrocientos',
  'quinientos',
  'seiscientos',
  'setecientos',
  'ochocientos',
  'novecientos',
];

/// 0–999. Con [apocope], "uno" final pasa a "un" (antes de "mil" o
/// "millones": "veintiún mil", "treinta y un millones").
String _hastaMil(int n, {bool apocope = false}) {
  String ajustar(String t) {
    if (!apocope) return t;
    if (t.endsWith('veintiuno')) {
      return '${t.substring(0, t.length - 'veintiuno'.length)}veintiún';
    }
    if (t.endsWith('uno')) return t.substring(0, t.length - 1);
    return t;
  }

  if (n < 30) return ajustar(_unidades[n]);
  if (n < 100) {
    final d = _decenas[n ~/ 10];
    final u = n % 10;
    return ajustar(u == 0 ? d : '$d y ${_unidades[u]}');
  }
  if (n == 100) return 'cien';
  final c = _centenas[n ~/ 100];
  final resto = n % 100;
  return resto == 0 ? c : '$c ${_hastaMil(resto, apocope: apocope)}';
}

/// [n] en letras (0 a 999 999 999). Para la receta: 21 → "veintiuno",
/// 1500 → "mil quinientos", 21 000 → "veintiún mil".
String numeroALetras(int n) {
  if (n < 0 || n > 999999999) {
    throw RangeError.range(n, 0, 999999999, 'n');
  }
  if (n < 1000) return _hastaMil(n);
  final millones = n ~/ 1000000;
  final miles = (n ~/ 1000) % 1000;
  final resto = n % 1000;
  final partes = <String>[
    if (millones == 1) 'un millón',
    if (millones > 1) '${_hastaMil(millones, apocope: true)} millones',
    if (miles == 1) 'mil',
    if (miles > 1) '${_hastaMil(miles, apocope: true)} mil',
    if (resto > 0) _hastaMil(resto),
  ];
  return partes.join(' ');
}
