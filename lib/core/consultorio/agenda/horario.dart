import '../../models/mapa.dart';
import 'cita.dart';

/// Una franja de atención, en minutos desde la medianoche (8:00 = 480).
class Franja {
  const Franja(this.inicio, this.fin);

  final int inicio;
  final int fin;

  bool get valida => inicio >= 0 && fin <= 24 * 60 && inicio < fin;

  /// «08:00–12:00»
  String get texto => '${horaTexto(inicio)}–${horaTexto(fin)}';

  Map<String, Object?> aMapa() => {'inicio': inicio, 'fin': fin};

  static Franja desdeMapa(Map<String, Object?> m) =>
      Franja(m.entero('inicio')!, m.entero('fin')!);

  @override
  bool operator ==(Object other) =>
      other is Franja && other.inicio == inicio && other.fin == fin;

  @override
  int get hashCode => Object.hash(inicio, fin);
}

/// «08:00» desde minutos.
String horaTexto(int minutos) =>
    '${(minutos ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutos % 60).toString().padLeft(2, '0')}';

/// Lee «8:00–12:00, 14:00–18:00» (también con guion o «a»). Devuelve
/// `null` si algo no se entiende; vacío es un día sin atención.
List<Franja>? leerFranjas(String texto) {
  final t = texto.trim();
  if (t.isEmpty) return const [];
  final r = <Franja>[];
  for (final parte in t.split(RegExp(r'[,;]'))) {
    final m = RegExp(
      r'^\s*(\d{1,2}):(\d{2})\s*(?:–|-|a)\s*(\d{1,2}):(\d{2})\s*$',
    ).firstMatch(parte);
    if (m == null) return null;
    int min(String h, String mm) => int.parse(h) * 60 + int.parse(mm);
    final f = Franja(
      min(m.group(1)!, m.group(2)!),
      min(m.group(3)!, m.group(4)!),
    );
    if (!f.valida || int.parse(m.group(2)!) > 59) return null;
    r.add(f);
  }
  r.sort((a, b) => a.inicio.compareTo(b.inicio));
  for (var i = 1; i < r.length; i++) {
    if (r[i].inicio < r[i - 1].fin) return null;
  }
  return r;
}

/// Un bloqueo manual de la agenda (vacaciones, una reunión).
class BloqueoAgenda {
  const BloqueoAgenda({
    required this.id,
    required this.inicio,
    required this.fin,
    this.motivo = '',
  });

  final String id;
  final DateTime inicio;
  final DateTime fin;
  final String motivo;

  bool cruza(DateTime desde, DateTime hasta) =>
      inicio.isBefore(hasta) && desde.isBefore(fin);

  Map<String, Object?> aMapa() => compacto({
    'id': id,
    'inicio': fechaHoraIso(inicio),
    'fin': fechaHoraIso(fin),
    'motivo': motivo.trim(),
  });

  static BloqueoAgenda desdeMapa(Map<String, Object?> m) => BloqueoAgenda(
    id: m.texto('id'),
    inicio: m.fecha('inicio')!,
    fin: m.fecha('fin')!,
    motivo: m.texto('motivo'),
  );
}

/// Mensaje de recordatorio por defecto (pregunta 43): sin datos de salud,
/// sin el tipo de cita.
const mensajeRecordatorioPorDefecto =
    'Hola {nombre}, le recordamos su cita el {dia} a las {hora} en '
    '{consultorio}, {direccion}. Por favor confirme respondiendo este '
    'mensaje.';

/// Horario, duraciones, bloqueos y mensaje del recordatorio (pregunta 42).
class HorarioAgenda {
  const HorarioAgenda({
    this.franjas = franjasPorDefecto,
    this.duraciones = const {},
    this.bloqueos = const [],
    this.mensaje = mensajeRecordatorioPorDefecto,
  });

  static const coleccion = 'configuracion';
  static const id = 'agenda';

  /// Lunes a viernes de 8:00 a 12:00 y de 14:00 a 18:00; sábado de 8:00 a
  /// 12:00. La clave es `DateTime.weekday` (1 = lunes).
  static const franjasPorDefecto = <int, List<Franja>>{
    DateTime.monday: [Franja(480, 720), Franja(840, 1080)],
    DateTime.tuesday: [Franja(480, 720), Franja(840, 1080)],
    DateTime.wednesday: [Franja(480, 720), Franja(840, 1080)],
    DateTime.thursday: [Franja(480, 720), Franja(840, 1080)],
    DateTime.friday: [Franja(480, 720), Franja(840, 1080)],
    DateTime.saturday: [Franja(480, 720)],
  };

  final Map<int, List<Franja>> franjas;

  /// Duraciones cambiadas por el médico; las demás son las del tipo.
  final Map<TipoCita, int> duraciones;
  final List<BloqueoAgenda> bloqueos;
  final String mensaje;

  int duracion(TipoCita t) => duraciones[t] ?? t.duracionPorDefecto;

  List<Franja> franjasDe(int diaSemana) => franjas[diaSemana] ?? const [];

  HorarioAgenda copyWith({
    Map<int, List<Franja>>? franjas,
    Map<TipoCita, int>? duraciones,
    List<BloqueoAgenda>? bloqueos,
    String? mensaje,
  }) => HorarioAgenda(
    franjas: franjas ?? this.franjas,
    duraciones: duraciones ?? this.duraciones,
    bloqueos: bloqueos ?? this.bloqueos,
    mensaje: mensaje ?? this.mensaje,
  );

  Map<String, Object?> aMapa() => {
    'franjas': {
      for (final e in franjas.entries)
        '${e.key}': [for (final f in e.value) f.aMapa()],
    },
    'duraciones': {for (final e in duraciones.entries) e.key.name: e.value},
    'bloqueos': [for (final b in bloqueos) b.aMapa()],
    'mensaje': mensaje,
  };

  static HorarioAgenda desdeMapa(Map<String, Object?> m) => HorarioAgenda(
    franjas: {
      for (final e in m.mapa('franjas').entries)
        int.parse(e.key): [
          for (final f in (e.value as List?) ?? const [])
            Franja.desdeMapa((f as Map).cast<String, Object?>()),
        ],
    },
    duraciones: {
      for (final e in m.mapa('duraciones').entries)
        ?TipoCita.values.asNameMap()[e.key]: (e.value as num).toInt(),
    },
    bloqueos: [
      for (final b in m.listaMapas('bloqueos')) BloqueoAgenda.desdeMapa(b),
    ],
    mensaje: m.textoONulo('mensaje') ?? mensajeRecordatorioPorDefecto,
  );
}
