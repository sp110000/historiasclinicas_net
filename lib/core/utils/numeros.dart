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
