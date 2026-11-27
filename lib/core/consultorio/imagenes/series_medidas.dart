import 'estudio_imagen.dart';

/// Una medida de ecografía a lo largo del tiempo (p. ej. el volumen del
/// lóbulo derecho), para graficarla en el seguimiento.
class SerieMedidaEco {
  const SerieMedidaEco({
    required this.nombre,
    required this.unidad,
    required this.puntos,
  });

  final String nombre;
  final String unidad;
  final List<({DateTime fecha, double valor})> puntos;

  String get etiqueta => unidad.isEmpty ? nombre : '$nombre ($unidad)';
}

/// Las series de los informes cerrados (sin los anulados), del más viejo al
/// más reciente; una por nombre y unidad de medida.
List<SerieMedidaEco> seriesMedidasEco(Iterable<EstudioImagen> estudios) {
  final cerrados = [
    for (final e in estudios)
      if (e.estado == EstadoEstudio.cerrado) e,
  ]..sort((a, b) => a.fecha.compareTo(b.fecha));
  final series = <String, SerieMedidaEco>{};
  for (final e in cerrados) {
    for (final m in e.medidas) {
      final v = m.resultado;
      if (v == null) continue;
      final clave = '${m.nombre.trim()}|${m.unidad}';
      final s = series[clave] ??= SerieMedidaEco(
        nombre: m.nombre.trim(),
        unidad: m.unidad,
        puntos: [],
      );
      s.puntos.add((fecha: e.fecha, valor: v));
    }
  }
  return series.values.toList();
}
