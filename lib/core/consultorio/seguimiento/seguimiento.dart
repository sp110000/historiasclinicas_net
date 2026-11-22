import '../../ihce/reloj.dart';
import '../../utils/ids.dart';
import '../indice/indice_pacientes.dart';
import '../modelos/medicion.dart';
import '../repositorio/bitacora.dart';
import '../repositorio/repositorio.dart';

/// Seguimiento antropométrico (y, desde la 5.2c, las fotos) del
/// consultorio, descifrado mientras está abierto.
class SeguimientoConsultorio {
  SeguimientoConsultorio(
    this._repo,
    this._indice, {
    this.reloj = const RelojSistema(),
  });

  final RepositorioConsultorio _repo;
  final IndicePacientes _indice;
  final Reloj reloj;

  final _mediciones = <String, Medicion>{};

  Future<void> cargar() async {
    final m = await _repo.leerColeccionTolerante(Medicion.coleccion);
    olvidar();
    for (final e in m.registros.entries) {
      try {
        _mediciones[e.key] = Medicion.desdeMapa(e.key, e.value);
      } on Object {
        // Ilegible: se ignora (el respaldo conserva el original).
      }
    }
  }

  void olvidar() => _mediciones.clear();

  Medicion? medicion(String id) => _mediciones[id];

  /// Las mediciones de la ficha (también las de fichas unidas a ella) y las
  /// de los signos sellados en sus historias, de la más vieja a la más
  /// reciente.
  List<Medicion> medicionesDe(String pacienteId) {
    final ids = _indice.idsUnidos(pacienteId);
    return [
      ..._mediciones.values.where((m) => ids.contains(m.pacienteId)),
      for (final h in _indice.historiasDe(pacienteId))
        for (final m in h.mediciones) m.copyWith(pacienteId: pacienteId),
    ]..sort((a, b) => a.fecha.compareTo(b.fecha));
  }

  /// La talla más reciente registrada (se arrastra a la medición nueva).
  double? ultimaTalla(String pacienteId) {
    for (final m in medicionesDe(pacienteId).reversed) {
      if (m.talla != null) return m.talla;
    }
    return null;
  }

  /// Guarda una medición nueva (sin [Medicion.id]) o editada. Lanza
  /// [StateError] si está vacía o el % de grasa no dice el método.
  Future<Medicion> guardarMedicion(Medicion m) async {
    if (!m.editable) {
      throw StateError('Las mediciones de una historia no se editan.');
    }
    if (m.vacia) throw StateError('Escribe al menos una medida.');
    if (m.grasa != null && m.metodoGrasa == null) {
      throw StateError('Indica con qué método se midió la grasa.');
    }
    final id = m.id.isEmpty ? nuevoUuid() : m.id;
    final guardada = Medicion.desdeMapa(id, m.aMapa());
    await _repo.guardar(Medicion.coleccion, id, guardada.aMapa());
    _mediciones[id] = guardada;
    return guardada;
  }

  Future<void> borrarMedicion(String id) async {
    final m = _mediciones[id];
    if (m == null) return;
    await _repo.guardarVarios([Escritura(Medicion.coleccion, id, null)]);
    _mediciones.remove(id);
    await registrarEnBitacora(
      _repo,
      AccionBitacora.borrarMedicion,
      fecha: reloj.ahora(),
    );
  }
}
