/// Edad gestacional en semanas y días.
class EdadGestacional {
  const EdadGestacional(this.semanas, this.dias);

  final int semanas;
  final int dias;

  /// "24 semanas + 3 días"
  String get texto =>
      '$semanas ${semanas == 1 ? 'semana' : 'semanas'}'
      '${dias > 0 ? ' + $dias ${dias == 1 ? 'día' : 'días'}' : ''}';
}

int _diasEntre(DateTime desde, DateTime hasta) => DateTime.utc(
  hasta.year,
  hasta.month,
  hasta.day,
).difference(DateTime.utc(desde.year, desde.month, desde.day)).inDays;

/// Edad gestacional por fecha de última menstruación. `null` si la FUM es
/// posterior a [referencia] o da más de 45 semanas (probable error).
EdadGestacional? edadGestacional(DateTime fum, DateTime referencia) {
  final dias = _diasEntre(fum, referencia);
  if (dias < 0 || dias > 45 * 7) return null;
  return EdadGestacional(dias ~/ 7, dias % 7);
}

/// Fecha probable de parto (regla de Naegele: FUM + 280 días).
DateTime fechaProbableParto(DateTime fum) {
  final f = DateTime.utc(
    fum.year,
    fum.month,
    fum.day,
  ).add(const Duration(days: 280));
  return DateTime(f.year, f.month, f.day);
}
