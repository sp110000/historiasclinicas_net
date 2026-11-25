import '../../ihce/reloj.dart';
import '../../utils/ids.dart';
import '../indice/indice_pacientes.dart';
import '../modelos/ficha_paciente.dart';
import '../procedimientos/procedimientos.dart';
import '../reglas/agenda.dart';
import '../reglas/estetica.dart';
import '../repositorio/bitacora.dart';
import '../repositorio/repositorio.dart';
import 'cita.dart';
import 'horario.dart';

/// La agenda del consultorio (5.5), descifrada mientras está abierto.
class AgendaConsultorio {
  AgendaConsultorio(
    this._repo,
    this._indice,
    this._procedimientos, {
    this.reloj = const RelojSistema(),
  });

  final RepositorioConsultorio _repo;
  final IndicePacientes _indice;
  final ProcedimientosConsultorio _procedimientos;
  final Reloj reloj;

  final _citas = <String, Cita>{};
  HorarioAgenda _horario = const HorarioAgenda();

  HorarioAgenda get horario => _horario;

  Future<void> cargar() async {
    final c = await _repo.leerColeccionTolerante(Cita.coleccion);
    final h = await _repo.leer(HorarioAgenda.coleccion, HorarioAgenda.id);
    olvidar();
    for (final e in c.registros.entries) {
      try {
        _citas[e.key] = Cita.desdeMapa(e.key, e.value);
      } on Object {
        // Ilegible: se ignora (el respaldo conserva el original).
      }
    }
    try {
      _horario = h == null ? const HorarioAgenda() : HorarioAgenda.desdeMapa(h);
    } on Object {
      _horario = const HorarioAgenda();
    }
  }

  void olvidar() {
    _citas.clear();
    _horario = const HorarioAgenda();
  }

  Future<void> guardarHorario(HorarioAgenda h) async {
    await _repo.guardar(HorarioAgenda.coleccion, HorarioAgenda.id, h.aMapa());
    _horario = h;
    await registrarEnBitacora(
      _repo,
      AccionBitacora.cambiarAjustes,
      fecha: reloj.ahora(),
      resumen: 'Agenda',
    );
  }

  Future<void> agregarBloqueo({
    required DateTime inicio,
    required DateTime fin,
    String motivo = '',
  }) {
    if (!inicio.isBefore(fin)) {
      throw StateError('El bloqueo tiene que terminar después de empezar.');
    }
    return guardarHorario(
      _horario.copyWith(
        bloqueos: [
          ..._horario.bloqueos,
          BloqueoAgenda(
            id: nuevoUuid(),
            inicio: inicio,
            fin: fin,
            motivo: motivo.trim(),
          ),
        ]..sort((a, b) => a.inicio.compareTo(b.inicio)),
      ),
    );
  }

  Future<void> quitarBloqueo(String id) => guardarHorario(
    _horario.copyWith(
      bloqueos: [
        for (final b in _horario.bloqueos)
          if (b.id != id) b,
      ],
    ),
  );

  // ─────────────────────────── Citas ───────────────────────────

  Cita? cita(String id) => _citas[id];

  /// Citas que empiezan entre [desde] (incluido) y [hasta] (excluido), de
  /// la más temprana a la más tardía.
  List<Cita> citasEntre(DateTime desde, DateTime hasta) =>
      _citas.values
          .where((c) => !c.inicio.isBefore(desde) && c.inicio.isBefore(hasta))
          .toList()
        ..sort((a, b) => a.inicio.compareTo(b.inicio));

  List<Cita> citasDelDia(DateTime dia) {
    final d = DateTime(dia.year, dia.month, dia.day);
    return citasEntre(d, DateTime(d.year, d.month, d.day + 1));
  }

  /// Citas de la ficha (y de las unidas a ella), de la más reciente a la
  /// más vieja.
  List<Cita> citasDe(String pacienteId) {
    final ids = _indice.idsUnidos(pacienteId);
    return _citas.values.where((c) => ids.contains(c.pacienteId)).toList()
      ..sort((a, b) => b.inicio.compareTo(a.inicio));
  }

  /// Inasistencias de la ficha (pregunta 42).
  int inasistencias(String pacienteId) =>
      citasDe(pacienteId).where((c) => c.estado == EstadoCita.noAsistio).length;

  /// La próxima cita abierta de la ficha, o `null`.
  Cita? proximaCita(String pacienteId) {
    final ahora = reloj.ahora();
    return citasDe(pacienteId)
        .where((c) => !c.estado.cerrada && !c.inicio.isBefore(ahora))
        .fold<Cita?>(
          null,
          (m, c) => m == null || c.inicio.isBefore(m.inicio) ? c : m,
        );
  }

  /// Una cita nueva (sin guardar) con la duración del tipo.
  Cita nueva({
    required TipoCita tipo,
    required DateTime inicio,
    String pacienteId = '',
  }) => Cita(
    id: nuevoUuid(),
    pacienteId: pacienteId,
    tipo: tipo,
    inicio: inicio,
    duracionMin: _horario.duracion(tipo),
    creado: reloj.ahora(),
    plantillaId: tipo.estetica ? _plantillaPorDefecto : null,
  );

  String? get _plantillaPorDefecto =>
      _procedimientos.plantillas.firstOrNull?.id;

  /// Las reglas de la cita con las demás del mismo día.
  EvaluacionCita evaluar(Cita c) {
    final ficha = c.pacienteId.isEmpty
        ? null
        : _indice.fichaActiva(c.pacienteId);
    return evaluarCita(
      c,
      ficha: ficha,
      horario: _horario,
      otras: citasDelDia(c.inicio),
      valoracion: ficha == null || c.plantillaId == null
          ? null
          : ultimaValoracion(
              _procedimientos.valoracionesDe(ficha.id),
              c.plantillaId!,
            ),
      ahora: reloj.ahora(),
    );
  }

  /// Horas libres de [dia] para [duracion] minutos (sin contar [sin]).
  List<DateTime> libres(DateTime dia, int duracion, {String? sin}) =>
      espaciosLibres(dia, duracion, _horario, [
        for (final c in citasDelDia(dia))
          if (c.id != sin) c,
      ]);

  /// Guarda una cita nueva o reprogramada. Lanza [StateError] con el
  /// primer bloqueo de las reglas.
  Future<Cita> guardar(Cita c) async {
    final e = evaluar(c);
    if (!e.permiteGuardar) throw StateError(e.bloqueos.first);
    final nueva = !_citas.containsKey(c.id);
    final ficha = _indice.fichaActiva(c.pacienteId)!;
    final cita = c.copyWith(
      pacienteId: ficha.id,
      historial: nueva
          ? [CambioEstadoCita(estado: c.estado, fecha: reloj.ahora())]
          : c.historial,
    );
    await _repo.guardar(Cita.coleccion, cita.id, cita.aMapa());
    _citas[cita.id] = cita;
    return cita;
  }

  /// Cambia el estado de la cita [id]. Cancelar pide motivo.
  Future<Cita> cambiarEstado(
    String id,
    EstadoCita estado, {
    String motivo = '',
  }) async {
    final c = _citas[id];
    if (c == null) throw StateError('No existe la cita.');
    final ahora = reloj.ahora();
    final problema = problemaCambioEstado(c, estado, ahora);
    if (problema != null) throw StateError(problema);
    if (estado == EstadoCita.cancelada && motivo.trim().isEmpty) {
      throw StateError('Escribe el motivo de la cancelación.');
    }
    final nueva = c.copyWith(
      estado: estado,
      historial: [
        ...c.historial,
        CambioEstadoCita(estado: estado, fecha: ahora, motivo: motivo),
      ],
    );
    await _repo.guardar(Cita.coleccion, id, nueva.aMapa());
    _citas[id] = nueva;
    return nueva;
  }

  /// Anota que se abrió el recordatorio por WhatsApp.
  Future<Cita> marcarRecordatorio(String id) async {
    final c = _citas[id];
    if (c == null) throw StateError('No existe la cita.');
    final nueva = c.copyWith(recordatorioEnviado: reloj.ahora());
    await _repo.guardar(Cita.coleccion, id, nueva.aMapa());
    _citas[id] = nueva;
    return nueva;
  }

  /// Las citas de mañana sin recordatorio.
  List<Cita> pendientesRecordatorio() =>
      pendientesDeRecordatorio(_citas.values, reloj.ahora());

  /// La ficha de una cita (la activa, si se unió a otra).
  FichaPaciente? fichaDe(Cita c) => _indice.fichaActiva(c.pacienteId);
}
