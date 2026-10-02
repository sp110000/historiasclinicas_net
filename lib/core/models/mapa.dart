/// Utilidades para pasar los modelos a mapas JSON y volver.
///
/// Convenciones del esquema (schemaVersion 1):
/// * fechas sin hora: `AAAA-MM-DD`;
/// * fecha y hora: hora local del consultorio, `AAAA-MM-DDTHH:MM`;
/// * los textos vacíos y los valores nulos no se escriben.
library;

String _dos(int n) => n.toString().padLeft(2, '0');

String fechaIso(DateTime f) =>
    '${f.year.toString().padLeft(4, '0')}-${_dos(f.month)}-${_dos(f.day)}';

String fechaHoraIso(DateTime f) =>
    '${fechaIso(f)}T${_dos(f.hour)}:${_dos(f.minute)}';

/// Fecha local sin hora.
DateTime soloFecha(DateTime f) => DateTime(f.year, f.month, f.day);

/// Fecha y hora local sin segundos.
DateTime alMinuto(DateTime f) =>
    DateTime(f.year, f.month, f.day, f.hour, f.minute);

/// Elimina nulos y textos vacíos.
Map<String, Object?> compacto(Map<String, Object?> m) => {
  for (final e in m.entries)
    if (e.value != null && e.value != '') e.key: e.value,
};

extension LecturaMapa on Map<String, Object?> {
  String texto(String clave) => (this[clave] as String?) ?? '';

  String? textoONulo(String clave) => this[clave] as String?;

  double? decimal(String clave) => (this[clave] as num?)?.toDouble();

  int? entero(String clave) => (this[clave] as num?)?.toInt();

  bool booleano(String clave, {bool porDefecto = false}) =>
      (this[clave] as bool?) ?? porDefecto;

  DateTime? fecha(String clave) {
    final v = this[clave] as String?;
    return v == null ? null : DateTime.parse(v);
  }

  Map<String, Object?> mapa(String clave) =>
      (this[clave] as Map?)?.cast<String, Object?>() ?? const {};

  List<Map<String, Object?>> listaMapas(String clave) => [
    for (final e in (this[clave] as List?) ?? const [])
      (e as Map).cast<String, Object?>(),
  ];

  List<String> listaTextos(String clave) => [
    for (final e in (this[clave] as List?) ?? const []) e as String,
  ];
}

/// Marca para `copyWith` que permite distinguir "no cambiar" de "poner nulo".
class Sin {
  const Sin._();
}

const sin = Sin._();

T? cambio<T>(Object? nuevo, T? actual) =>
    identical(nuevo, sin) ? actual : nuevo as T?;
