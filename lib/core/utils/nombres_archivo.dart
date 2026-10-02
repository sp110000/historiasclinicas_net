import 'texto.dart';

/// `Historia_{APELLIDO}_{DOCUMENTO}.pdf`, con sufijo `_vN` desde la
/// revisión 2.
String nombreArchivoHistoria({
  required String primerApellido,
  required String documento,
  int revision = 1,
}) {
  final base =
      'Historia_${_palabras(primerApellido, 'SIN-APELLIDO')}'
      '_${_compacto(documento, 'SIN-DOCUMENTO')}';
  return revision > 1 ? '${base}_v$revision.pdf' : '$base.pdf';
}

/// `Receta_{APELLIDO}_{AAAA-MM-DD}.pdf`.
String nombreArchivoReceta({
  required String primerApellido,
  required DateTime fecha,
}) {
  String dos(int n) => n.toString().padLeft(2, '0');
  final dia = '${fecha.year}-${dos(fecha.month)}-${dos(fecha.day)}';
  return 'Receta_${_palabras(primerApellido, 'SIN-APELLIDO')}_$dia.pdf';
}

String _mayusculasAscii(String s) => sinTildes(s.trim()).toUpperCase();

/// "De la Peña" → "DE-LA-PENA".
String _palabras(String s, String siVacio) {
  final r = _mayusculasAscii(
    s,
  ).replaceAll(RegExp(r'[^A-Z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return r.isEmpty ? siVacio : r;
}

/// "1.032.456.789" → "1032456789".
String _compacto(String s, String siVacio) {
  final r = _mayusculasAscii(s).replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return r.isEmpty ? siVacio : r;
}
