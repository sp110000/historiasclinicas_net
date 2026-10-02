/// Número con coma decimal: 72 → "72", 36.8 → "36,8".
String formatoNumero(double valor, {int? decimales}) {
  if (decimales != null) {
    return valor.toStringAsFixed(decimales).replaceAll('.', ',');
  }
  if (valor == valor.truncateToDouble()) return valor.toInt().toString();
  return valor.toString().replaceAll('.', ',');
}

/// Acepta "36,8" o "36.8". `null` si está vacío o no es un número.
double? leerNumero(String texto) {
  final t = texto.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Separador de miles con punto: 12345 → "12.345".
String formatoMiles(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}
