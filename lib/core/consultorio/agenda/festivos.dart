/// Festivos de Colombia (Ley 51 de 1983, «ley Emiliani», y la Ley 35 de
/// 1939; VERIFICAR cada año contra el calendario oficial).
///
/// - Fijos: 1 de enero, 1 de mayo, 20 de julio, 7 de agosto, 8 y 25 de
///   diciembre.
/// - Se trasladan al lunes siguiente si no caen en lunes: 6 de enero, 19 de
///   marzo, 29 de junio, 15 de agosto, 12 de octubre, 1 y 11 de noviembre.
/// - Según la Pascua: jueves y viernes santos (fijos), y Ascensión, Corpus
///   Christi y Sagrado Corazón (trasladados al lunes: Pascua + 43, + 64 y
///   + 71 días).
library;

DateTime _dia(int anio, int mes, int dia) => DateTime(anio, mes, dia);

/// Domingo de Pascua (algoritmo anónimo gregoriano, de Meeus/Jones/Butcher).
DateTime domingoDePascua(int anio) {
  final a = anio % 19;
  final b = anio ~/ 100;
  final c = anio % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final mes = (h + l - 7 * m + 114) ~/ 31;
  final dia = (h + l - 7 * m + 114) % 31 + 1;
  return _dia(anio, mes, dia);
}

/// El mismo día si es lunes; si no, el lunes siguiente.
DateTime _alLunes(DateTime f) {
  final faltan = (DateTime.monday - f.weekday + 7) % 7;
  return _dia(f.year, f.month, f.day + faltan);
}

DateTime _mas(DateTime f, int dias) => _dia(f.year, f.month, f.day + dias);

/// Los festivos de [anio], de la fecha (sin hora) a su nombre. Si dos caen
/// el mismo día (pasa: San Pedro y el Sagrado Corazón en 2025), los nombres
/// van juntos.
Map<DateTime, String> festivosColombia(int anio) {
  final pascua = domingoDePascua(anio);
  final lista = <(DateTime, String)>[
    (_dia(anio, 1, 1), 'Año Nuevo'),
    (_alLunes(_dia(anio, 1, 6)), 'Reyes Magos'),
    (_alLunes(_dia(anio, 3, 19)), 'San José'),
    (_mas(pascua, -3), 'Jueves Santo'),
    (_mas(pascua, -2), 'Viernes Santo'),
    (_dia(anio, 5, 1), 'Día del Trabajo'),
    (_mas(pascua, 43), 'Ascensión del Señor'),
    (_mas(pascua, 64), 'Corpus Christi'),
    (_mas(pascua, 71), 'Sagrado Corazón'),
    (_alLunes(_dia(anio, 6, 29)), 'San Pedro y San Pablo'),
    (_dia(anio, 7, 20), 'Día de la Independencia'),
    (_dia(anio, 8, 7), 'Batalla de Boyacá'),
    (_alLunes(_dia(anio, 8, 15)), 'Asunción de la Virgen'),
    (_alLunes(_dia(anio, 10, 12)), 'Día de la Raza'),
    (_alLunes(_dia(anio, 11, 1)), 'Todos los Santos'),
    (_alLunes(_dia(anio, 11, 11)), 'Independencia de Cartagena'),
    (_dia(anio, 12, 8), 'Inmaculada Concepción'),
    (_dia(anio, 12, 25), 'Navidad'),
  ];
  final r = <DateTime, String>{};
  for (final (f, nombre) in lista) {
    r[f] = r.containsKey(f) ? '${r[f]} y $nombre' : nombre;
  }
  return r;
}

final _cache = <int, Map<DateTime, String>>{};

/// El nombre del festivo de [fecha] (se ignora la hora), o `null`.
String? festivo(DateTime fecha) => (_cache[fecha.year] ??= festivosColombia(
  fecha.year,
))[_dia(fecha.year, fecha.month, fecha.day)];
