/// Edad cumplida en años, meses y días.
class Edad {
  const Edad(this.anios, this.meses, this.dias);

  final int anios;
  final int meses;
  final int dias;

  bool get esMenorDeEdad => anios < 18;

  /// Formato clínico:
  /// * menores de 2 años: años, meses y días ("1 año 3 meses 5 días");
  /// * de 2 a 17 años: años y meses ("5 años 3 meses");
  /// * adultos: años ("34 años").
  String get texto {
    String parte(int n, String singular, String plural) =>
        '$n ${n == 1 ? singular : plural}';
    final partes = <String>[];
    if (anios > 0) partes.add(parte(anios, 'año', 'años'));
    if (anios < 18 && meses > 0) partes.add(parte(meses, 'mes', 'meses'));
    if (anios < 2 && (dias > 0 || partes.isEmpty)) {
      partes.add(parte(dias, 'día', 'días'));
    }
    return partes.join(' ');
  }

  @override
  bool operator ==(Object other) =>
      other is Edad &&
      other.anios == anios &&
      other.meses == meses &&
      other.dias == dias;

  @override
  int get hashCode => Object.hash(anios, meses, dias);

  @override
  String toString() => 'Edad($anios a, $meses m, $dias d)';
}

int _diasDelMes(int anio, int mes) => DateTime(anio, mes + 1, 0).day;

/// Suma meses a una fecha; si el día no existe en el mes de destino se usa
/// el último día de ese mes (31 de enero + 1 mes = 28 o 29 de febrero).
DateTime _sumarMeses(DateTime f, int meses) {
  final total = f.month - 1 + meses;
  final anio = f.year + total ~/ 12;
  final mes = total % 12 + 1;
  final dia = f.day <= _diasDelMes(anio, mes) ? f.day : _diasDelMes(anio, mes);
  return DateTime(anio, mes, dia);
}

int _diasEntre(DateTime desde, DateTime hasta) => DateTime.utc(
  hasta.year,
  hasta.month,
  hasta.day,
).difference(DateTime.utc(desde.year, desde.month, desde.day)).inDays;

/// Edad a la fecha [referencia]. Devuelve `null` si [nacimiento] es
/// posterior. Solo cuenta la fecha (no la hora).
///
/// Se cuentan los meses completos (cada "cumplemés") y luego los días
/// restantes. Si el día de nacimiento no existe en un mes, el cumplemés cae
/// en el último día de ese mes: quien nace un 29 de febrero cumple años el
/// 28 de febrero en los años no bisiestos.
Edad? calcularEdad(DateTime nacimiento, DateTime referencia) {
  final n = DateTime(nacimiento.year, nacimiento.month, nacimiento.day);
  final r = DateTime(referencia.year, referencia.month, referencia.day);
  if (n.isAfter(r)) return null;

  var meses = (r.year - n.year) * 12 + (r.month - n.month);
  if (_sumarMeses(n, meses).isAfter(r)) meses--;
  final dias = _diasEntre(_sumarMeses(n, meses), r);
  return Edad(meses ~/ 12, meses % 12, dias);
}
