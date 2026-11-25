import '../agenda/cita.dart';
import '../agenda/festivos.dart';
import '../agenda/horario.dart';
import '../modelos/ficha_paciente.dart';
import '../procedimientos/valoracion.dart';
import 'estetica.dart';

/// Lo que dicen las reglas de una cita: los bloqueos impiden guardarla;
/// los avisos no (un cruce o un festivo avisan, pregunta 42).
class EvaluacionCita {
  const EvaluacionCita({required this.bloqueos, required this.avisos});

  final List<String> bloqueos;
  final List<String> avisos;

  bool get permiteGuardar => bloqueos.isEmpty;
}

const _dias = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

String nombreDia(DateTime f) => _dias[f.weekday - 1];

int _minutos(DateTime f) => f.hour * 60 + f.minute;

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// La cita [c] cabe entera en una franja del horario de su día.
bool dentroDelHorario(Cita c, HorarioAgenda h) {
  if (!_mismoDia(c.inicio, c.fin.subtract(const Duration(minutes: 1)))) {
    return false;
  }
  final desde = _minutos(c.inicio);
  final hasta = desde + c.duracionMin;
  return h
      .franjasDe(c.inicio.weekday)
      .any((f) => f.inicio <= desde && hasta <= f.fin);
}

/// Evalúa la cita [c] (pura). [valoracion] es la última sellada del
/// procedimiento de una sesión; [otras], las demás citas cercanas.
EvaluacionCita evaluarCita(
  Cita c, {
  required FichaPaciente? ficha,
  required HorarioAgenda horario,
  required Iterable<Cita> otras,
  required Valoracion? valoracion,
  required DateTime ahora,
}) {
  final bloqueos = <String>[];
  final avisos = <String>[];

  if (ficha == null) {
    bloqueos.add('Elige el paciente.');
  }
  if (c.duracionMin < 5 || c.duracionMin > 480) {
    bloqueos.add('La duración va de 5 a 480 minutos.');
  }
  if (c.tipo.estetica) {
    final edad = ficha == null ? null : bloqueoPorEdad(ficha, ahora);
    if (edad != null) bloqueos.add(edad);
    if (c.plantillaId == null) bloqueos.add('Elige el procedimiento.');
  }
  if (c.tipo == TipoCita.sesion && ficha != null) {
    // La valoración tiene que valer el día de la sesión.
    switch (estadoValoracion(valoracion, c.inicio)) {
      case EstadoValoracion.vigente:
        break;
      case EstadoValoracion.falta:
        bloqueos.add(
          'Para agendar una sesión hace falta una valoración «apto» '
          'vigente.',
        );
      case EstadoValoracion.noApto:
        bloqueos.add(
          'La última valoración fue «no apto»: no se agenda la sesión.',
        );
      case EstadoValoracion.diferir:
        bloqueos.add(
          'La última valoración fue «diferir»: no se agenda la sesión.',
        );
      case EstadoValoracion.vencida:
        bloqueos.add(
          'La valoración «apto» no estará vigente ese día: agenda primero '
          'una valoración.',
        );
    }
  }

  if (c.inicio.isBefore(ahora) && !c.estado.cerrada) {
    avisos.add('La cita es en el pasado.');
  }
  final nombreFestivo = festivo(c.inicio);
  if (nombreFestivo != null) {
    avisos.add('Es festivo: $nombreFestivo (VERIFICAR).');
  }
  if (!dentroDelHorario(c, horario)) {
    final franjas = horario.franjasDe(c.inicio.weekday);
    avisos.add(
      franjas.isEmpty
          ? 'El ${nombreDia(c.inicio)} no hay atención en tu horario.'
          : 'Fuera del horario del ${nombreDia(c.inicio)} '
                '(${franjas.map((f) => f.texto).join(', ')}).',
    );
  }
  for (final b in horario.bloqueos) {
    if (b.cruza(c.inicio, c.fin)) {
      avisos.add(
        'Se cruza con un bloqueo'
        '${b.motivo.trim().isEmpty ? '' : ': ${b.motivo.trim()}'}.',
      );
    }
  }
  for (final o in otras) {
    if (c.cruzaCon(o)) {
      avisos.add(
        'Se cruza con otra cita de '
        '${horaTexto(_minutos(o.inicio))} a ${horaTexto(_minutos(o.fin))}.',
      );
    }
  }
  return EvaluacionCita(bloqueos: bloqueos, avisos: avisos);
}

/// Por qué no se puede pasar [c] a [nuevo], o `null` si se puede.
///
/// Una cita atendida no cambia; una cancelada o con inasistencia solo
/// vuelve a «agendada». No se marca atendida antes de su día, ni «no
/// asistió» antes de su hora.
String? problemaCambioEstado(Cita c, EstadoCita nuevo, DateTime ahora) {
  if (nuevo == c.estado) return 'La cita ya está «${nuevo.etiqueta}».';
  if (c.estado == EstadoCita.atendida) {
    return 'La cita ya se atendió: no cambia de estado.';
  }
  if (c.estado.cerrada && nuevo != EstadoCita.agendada) {
    return 'Una cita «${c.estado.etiqueta}» solo puede volver a «Agendada».';
  }
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final dia = DateTime(c.inicio.year, c.inicio.month, c.inicio.day);
  if (nuevo == EstadoCita.atendida && dia.isAfter(hoy)) {
    return 'Todavía no es el día de la cita.';
  }
  if (nuevo == EstadoCita.noAsistio && ahora.isBefore(c.inicio)) {
    return 'La cita todavía no empieza.';
  }
  return null;
}

/// Horas libres de [dia] para una cita de [duracion] minutos: dentro del
/// horario, sin festivo, sin bloqueos ni citas que ocupen. Empiezan al
/// comienzo de cada hueco y siguen de [duracion] en [duracion].
List<DateTime> espaciosLibres(
  DateTime dia,
  int duracion,
  HorarioAgenda horario,
  Iterable<Cita> citas,
) {
  if (festivo(dia) != null || duracion < 5) return const [];
  final base = DateTime(dia.year, dia.month, dia.day);
  DateTime enMinuto(int m) => base.add(Duration(minutes: m));
  final finDia = DateTime(base.year, base.month, base.day + 1);
  final ocupado = [
    for (final c in citas)
      if (c.estado.ocupa && _mismoDia(c.inicio, base))
        (_minutos(c.inicio), _minutos(c.inicio) + c.duracionMin),
    // Un bloqueo que sigue después de este día (o termina justo a la
    // medianoche) ocupa hasta el final.
    for (final b in horario.bloqueos)
      if (b.cruza(base, finDia))
        (
          b.inicio.isBefore(base) ? 0 : _minutos(b.inicio),
          b.fin.isBefore(finDia) ? _minutos(b.fin) : 24 * 60,
        ),
  ];
  bool libre(int desde, int hasta) =>
      ocupado.every((o) => hasta <= o.$1 || o.$2 <= desde);
  final r = <DateTime>[];
  for (final f in horario.franjasDe(dia.weekday)) {
    int? inicioHueco;
    for (var t = f.inicio; t + duracion <= f.fin; t += 5) {
      if (!libre(t, t + duracion)) {
        inicioHueco = null;
        continue;
      }
      inicioHueco ??= t;
      if ((t - inicioHueco) % duracion == 0) r.add(enMinuto(t));
    }
  }
  return r;
}

/// Citas de mañana (respecto de [ahora]) que esperan recordatorio: ni
/// cerradas ni con el recordatorio ya abierto.
List<Cita> pendientesDeRecordatorio(Iterable<Cita> citas, DateTime ahora) {
  final manana = DateTime(ahora.year, ahora.month, ahora.day + 1);
  return [
    for (final c in citas)
      if (_mismoDia(c.inicio, manana) &&
          !c.estado.cerrada &&
          c.recordatorioEnviado == null)
        c,
  ]..sort((a, b) => a.inicio.compareTo(b.inicio));
}
