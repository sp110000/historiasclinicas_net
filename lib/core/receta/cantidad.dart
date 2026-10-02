import '../utils/texto.dart';
import 'receta.dart';

const _numerosEnLetras = {
  'una': 1,
  'un': 1,
  'uno': 1,
  'dos': 2,
  'tres': 3,
  'cuatro': 4,
  'cinco': 5,
  'seis': 6,
};

const _unidadesContables = {
  'tableta',
  'tab',
  'comprimido',
  'comp',
  'capsula',
  'cap',
  'gragea',
  'sobre',
  'ampolla',
  'vial',
  'ovulo',
  'supositorio',
  'parche',
};

String _limpio(String t) => sinTildes(t.toLowerCase()).trim();

/// "1", "1,5", "1/2", "½".
double? _numero(String t) {
  final s = t.trim();
  const fracciones = {'½': 0.5, '¼': 0.25, '¾': 0.75};
  if (fracciones.containsKey(s)) return fracciones[s];
  final frac = RegExp(r'^(\d+)/(\d+)$').firstMatch(s);
  if (frac != null) {
    final den = int.parse(frac.group(2)!);
    return den == 0 ? null : int.parse(frac.group(1)!) / den;
  }
  return double.tryParse(s.replaceAll(',', '.')) ??
      _numerosEnLetras[s]?.toDouble();
}

/// "tabletas", "sobres", "viales" o "tab." cuentan como unidades.
bool _contable(String palabra) {
  final p = palabra.replaceAll('.', '');
  return [
    p,
    if (p.endsWith('s')) p.substring(0, p.length - 1),
    if (p.endsWith('es')) p.substring(0, p.length - 2),
  ].any(_unidadesContables.contains);
}

/// Unidades por toma, si la dosis se cuenta en unidades enteras
/// ("1 tableta", "½ comprimido", "2"). `null` para "5 mL", "2 gotas"…
double? _dosis(String dosis, String forma) {
  final m = RegExp(r'^(\S+)\s*(.*)$').firstMatch(_limpio(dosis));
  if (m == null) return null;
  final n = _numero(m.group(1)!);
  if (n == null || n <= 0) return null;
  final unidad = m.group(2)!.trim();
  if (unidad.isEmpty) {
    return _contable(_limpio(forma).split(' ').first) ? n : null;
  }
  return _contable(unidad.split(RegExp(r'\s+')).first) ? n : null;
}

/// Tomas al día: "cada 8 horas" → 3; "dos veces al día" → 2.
double? _tomasAlDia(String frecuencia) {
  final f = _limpio(frecuencia);
  final cada = RegExp(r'cada\s+(\d+)\s*(h|hora|horas)\b').firstMatch(f);
  if (cada != null) {
    final h = int.parse(cada.group(1)!);
    return h == 0 ? null : 24 / h;
  }
  final veces = RegExp(
    r'(\d+|una|un|dos|tres|cuatro|cinco|seis)\s+(vez|veces)\s+(al|por)\s+dia',
  ).firstMatch(f);
  if (veces != null) return _numero(veces.group(1)!);
  if (RegExp(
    r'cada\s+dia|diari|en la (noche|manana|tarde)|al acostarse',
  ).hasMatch(f)) {
    return 1;
  }
  return null;
}

/// Días de tratamiento: "7 días" → 7; "2 semanas" → 14; "1 mes" → 30.
int? _dias(String duracion) {
  final m = RegExp(
    r'^(\d+|una|un|dos|tres|cuatro|cinco|seis)\s+(dia|dias|semana|semanas|mes|meses)\b',
  ).firstMatch(_limpio(duracion));
  if (m == null) return null;
  final n = _numero(m.group(1)!)!.toInt();
  return switch (m.group(2)!) {
    'semana' || 'semanas' => n * 7,
    'mes' || 'meses' => n * 30,
    _ => n,
  };
}

/// Cantidad a dispensar = unidades por toma × tomas al día × días, cuando
/// la dosis se cuenta en unidades (tabletas, cápsulas, sobres…). Con
/// "dosis única" es la propia dosis. `null` si no se puede calcular con
/// seguridad (jarabes, gotas, "si hay dolor"…).
int? cantidadSugerida(ItemReceta item) {
  final dosis = _dosis(item.dosis, item.forma);
  if (dosis == null) return null;
  final unica = RegExp(
    r'dosis unica',
  ).hasMatch(_limpio('${item.frecuencia} ${item.duracion}'));
  if (unica) return dosis.ceil();
  final tomas = _tomasAlDia(item.frecuencia);
  final dias = _dias(item.duracion);
  if (tomas == null || dias == null) return null;
  final total = (dosis * tomas * dias).ceil();
  return total > 0 ? total : null;
}
