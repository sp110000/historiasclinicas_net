import '../../../core/integridad/cadena_hash.dart';
import '../../../core/models/historia.dart';
import '../../../core/models/mapa.dart';
import '../../../core/models/medico.dart';
import '../../../core/pais/perfil_pais.dart';

enum ModoHistoria {
  /// Historia en redacción: todo es editable.
  nueva,

  /// Historia ya guardada en PDF: solo se agregan evoluciones.
  abierta,
}

class EstadoHistoria {
  const EstadoHistoria({
    required this.modo,
    required this.historia,
    this.datosSellados,
    this.evolucionesSelladas = const [],
    this.evolucionesNuevas = const [],
    this.revision = 0,
    this.nombreArchivo,
    this.integridad,
    this.versionFormulario = 0,
    this.borradorRestauradoEn,
  });

  factory EstadoHistoria.nueva(Pais pais, {int versionFormulario = 0}) =>
      EstadoHistoria(
        modo: ModoHistoria.nueva,
        historia: HistoriaClinica.nueva(pais: pais),
        versionFormulario: versionFormulario,
      );

  /// Estado de una historia leída de un PDF (o recién guardada). Lanza
  /// [FormatException] si los datos no son una historia clínica.
  factory EstadoHistoria.abierta({
    required Map<String, Object?> datos,
    required int revision,
    String? nombreArchivo,
    List<Evolucion> evolucionesNuevas = const [],
    int versionFormulario = 0,
    DateTime? borradorRestauradoEn,
  }) {
    final historia = HistoriaClinica.desdeMapa(datos);
    final selladas = [
      for (final e in datos.listaMapas('evoluciones')) Evolucion.desdeMapa(e),
    ];
    return EstadoHistoria(
      modo: ModoHistoria.abierta,
      historia: historia,
      datosSellados: datos,
      evolucionesSelladas: selladas,
      evolucionesNuevas: evolucionesNuevas,
      revision: revision,
      nombreArchivo: nombreArchivo,
      integridad: verificarIntegridad(datos),
      versionFormulario: versionFormulario,
      borradorRestauradoEn: borradorRestauradoEn,
    );
  }

  /// Reconstruye el estado guardado por [aBorrador].
  factory EstadoHistoria.desdeBorrador(
    Map<String, Object?> m, {
    required DateTime guardadoEn,
    int versionFormulario = 0,
  }) {
    final nuevas = [
      for (final e in m.listaMapas('evolucionesNuevas')) Evolucion.desdeMapa(e),
    ];
    if (m['modo'] == ModoHistoria.abierta.name) {
      return EstadoHistoria.abierta(
        datos: m.mapa('datosSellados'),
        revision: m.entero('revision') ?? 1,
        nombreArchivo: m.textoONulo('nombreArchivo'),
        evolucionesNuevas: nuevas,
        versionFormulario: versionFormulario,
        borradorRestauradoEn: guardadoEn,
      );
    }
    return EstadoHistoria(
      modo: ModoHistoria.nueva,
      historia: HistoriaClinica.desdeMapa(m.mapa('historia')),
      versionFormulario: versionFormulario,
      borradorRestauradoEn: guardadoEn,
    );
  }

  final ModoHistoria modo;

  /// En modo nueva, la historia que se edita. En modo abierta, la historia
  /// inicial (solo lectura) leída de [datosSellados].
  final HistoriaClinica historia;

  /// Datos tal como están en el PDF: historia inicial, `hashBase` y
  /// evoluciones selladas. Nunca se vuelven a serializar desde el modelo.
  final Map<String, Object?>? datosSellados;
  final List<Evolucion> evolucionesSelladas;

  /// Evoluciones aún no guardadas: se pueden editar o descartar.
  final List<Evolucion> evolucionesNuevas;

  /// Número de guardados del PDF (0 si aún no se ha guardado).
  final int revision;
  final String? nombreArchivo;
  final ResultadoIntegridad? integridad;

  /// Cambia cuando la historia se reemplaza entera (limpiar, abrir, restaurar)
  /// para reconstruir los campos del formulario.
  final int versionFormulario;

  /// Si el estado se recuperó de un borrador al abrir la app.
  final DateTime? borradorRestauradoEn;

  bool get abierta => modo == ModoHistoria.abierta;

  /// Médico que finalizó la historia (copia guardada en el PDF).
  Autor? get medicoDeLaHistoria {
    final m = datosSellados?['medico'];
    return m is Map ? Autor.desdeMapa(m.cast<String, Object?>()) : null;
  }

  bool get hayCambiosSinGuardar =>
      abierta ? evolucionesNuevas.isNotEmpty : !historia.estaVacia;

  bool get integridadComprometida => integridad?.correcta == false;

  EstadoHistoria copyWith({
    HistoriaClinica? historia,
    List<Evolucion>? evolucionesNuevas,
    Object? borradorRestauradoEn = sin,
    int? versionFormulario,
  }) => EstadoHistoria(
    modo: modo,
    historia: historia ?? this.historia,
    datosSellados: datosSellados,
    evolucionesSelladas: evolucionesSelladas,
    evolucionesNuevas: evolucionesNuevas ?? this.evolucionesNuevas,
    revision: revision,
    nombreArchivo: nombreArchivo,
    integridad: integridad,
    versionFormulario: versionFormulario ?? this.versionFormulario,
    borradorRestauradoEn: cambio(
      borradorRestauradoEn,
      this.borradorRestauradoEn,
    ),
  );

  Map<String, Object?> aBorrador() => {
    'modo': modo.name,
    if (!abierta) 'historia': historia.aMapa(),
    if (abierta) 'datosSellados': datosSellados,
    'evolucionesNuevas': [for (final e in evolucionesNuevas) e.aMapa()],
    'revision': revision,
    'nombreArchivo': nombreArchivo,
  };
}
