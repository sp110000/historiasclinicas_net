import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/agenda/cita.dart';
import 'package:historiasclinicas_net/core/consultorio/agenda/festivos.dart';
import 'package:historiasclinicas_net/core/consultorio/agenda/horario.dart';
import 'package:historiasclinicas_net/core/consultorio/agenda/recordatorio.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/ficha_paciente.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/valoracion.dart';
import 'package:historiasclinicas_net/core/consultorio/reglas/agenda.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';

import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';
import 'ayudas_procedimientos.dart';

// Viernes 20/11/2026, 9:30 (en la agenda, «hoy»).
final _ahora = DateTime(2026, 11, 20, 9, 30);

final _ficha = FichaPaciente(
  id: 'f1',
  clave: 'CC:1',
  creado: DateTime(2026),
  actualizado: DateTime(2026),
  nombres: 'José Ángel',
  primerApellido: 'Peña',
  telefono: '300 123 4567',
  fechaNacimiento: DateTime(1990, 5, 3),
);

Cita _cita({
  String id = 'c1',
  TipoCita tipo = TipoCita.control,
  DateTime? inicio,
  int duracion = 20,
  EstadoCita estado = EstadoCita.agendada,
  String? plantillaId,
}) => Cita(
  id: id,
  pacienteId: 'f1',
  tipo: tipo,
  inicio: inicio ?? DateTime(2026, 11, 23, 8),
  duracionMin: duracion,
  creado: _ahora,
  estado: estado,
  plantillaId: plantillaId,
);

Valoracion _valoracion(ResultadoValoracion r, {DateTime? hasta}) => Valoracion(
  id: 'v1',
  pacienteId: 'f1',
  plantillaId: 'hidrolipoclasia',
  version: 1,
  fecha: DateTime(2026, 11, 1),
  creado: DateTime(2026, 11, 1),
  resultado: r,
  vigenteHasta: hasta,
  huellaEvolucion: 'h',
);

EvaluacionCita _evaluar(
  Cita c, {
  FichaPaciente? ficha,
  bool sinFicha = false,
  HorarioAgenda horario = const HorarioAgenda(),
  List<Cita> otras = const [],
  Valoracion? valoracion,
}) => evaluarCita(
  c,
  ficha: sinFicha ? null : ficha ?? _ficha,
  horario: horario,
  otras: otras,
  valoracion: valoracion,
  ahora: _ahora,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Festivos de Colombia (Ley 51 de 1983)', () {
    test('Domingo de Pascua', () {
      expect(domingoDePascua(2024), DateTime(2024, 3, 31));
      expect(domingoDePascua(2025), DateTime(2025, 4, 20));
      expect(domingoDePascua(2026), DateTime(2026, 4, 5));
      expect(domingoDePascua(2027), DateTime(2027, 3, 28));
    });

    test('los 18 de 2026, con los trasladados al lunes', () {
      final f = festivosColombia(2026).keys.toList()..sort();
      expect(f, [
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 12),
        DateTime(2026, 3, 23),
        DateTime(2026, 4, 2),
        DateTime(2026, 4, 3),
        DateTime(2026, 5, 1),
        DateTime(2026, 5, 18),
        DateTime(2026, 6, 8),
        DateTime(2026, 6, 15),
        DateTime(2026, 6, 29),
        DateTime(2026, 7, 20),
        DateTime(2026, 8, 7),
        DateTime(2026, 8, 17),
        DateTime(2026, 10, 12),
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 16),
        DateTime(2026, 12, 8),
        DateTime(2026, 12, 25),
      ]);
      expect(festivo(DateTime(2026, 11, 16, 10)), 'Independencia de Cartagena');
      expect(festivo(DateTime(2026, 11, 11)), isNull, reason: 'se trasladó');
    });

    test('2025: San Pedro y el Sagrado Corazón caen el mismo lunes', () {
      final f = festivosColombia(2025);
      expect(f, hasLength(17));
      expect(
        f[DateTime(2025, 6, 30)],
        'Sagrado Corazón y San Pedro y San Pablo',
      );
      expect(f[DateTime(2025, 6, 2)], 'Ascensión del Señor');
      expect(f[DateTime(2025, 11, 17)], 'Independencia de Cartagena');
    });
  });

  group('Horario', () {
    test('franjas escritas a mano', () {
      const casos = <String, List<Franja>?>{
        '8:00–12:00, 14:00–18:00': [Franja(480, 720), Franja(840, 1080)],
        '14:00-18:00; 08:00 a 12:00': [Franja(480, 720), Franja(840, 1080)],
        '': [],
        '8:00–7:00': null,
        '8:00–12:00, 11:00–13:00': null,
        '8 a 12': null,
        '8:75–9:00': null,
      };
      casos.forEach(
        (t, esperado) => expect(leerFranjas(t), esperado, reason: t),
      );
    });

    test('se guarda y se lee igual', () {
      final h = const HorarioAgenda().copyWith(
        duraciones: {TipoCita.control: 15},
        bloqueos: [
          BloqueoAgenda(
            id: 'b',
            inicio: DateTime(2026, 11, 23, 9),
            fin: DateTime(2026, 11, 23, 10),
            motivo: 'Reunión',
          ),
        ],
      );
      final otra = HorarioAgenda.desdeMapa(h.aMapa());
      expect(otra.aMapa(), h.aMapa());
      expect(otra.duracion(TipoCita.control), 15);
      expect(otra.duracion(TipoCita.sesion), 60);
    });
  });

  group('Reglas de la cita (por tabla)', () {
    test('un control en horario, sin nada más: se guarda sin avisos', () {
      final e = _evaluar(_cita());
      expect(e.permiteGuardar, isTrue);
      expect(e.avisos, isEmpty);
    });

    final menor = _ficha.copyWith(fechaNacimiento: DateTime(2010, 1, 1));
    final sinNacimiento = _ficha.copyWith(fechaNacimiento: null);
    final sesion = _cita(
      tipo: TipoCita.sesion,
      duracion: 60,
      plantillaId: 'hidrolipoclasia',
    );
    final apto = _valoracion(
      ResultadoValoracion.apto,
      hasta: DateTime(2027, 1, 30),
    );
    final bloqueos = <(String, EvaluacionCita, String)>[
      ('sin paciente', _evaluar(_cita(), sinFicha: true), 'Elige el paciente'),
      ('duración 0', _evaluar(_cita(duracion: 0)), 'La duración va de 5 a 480'),
      (
        'valoración de un menor',
        _evaluar(
          _cita(tipo: TipoCita.valoracionEstetica, plantillaId: 'h'),
          ficha: menor,
        ),
        'menor de 18 años',
      ),
      (
        'sesión sin fecha de nacimiento',
        _evaluar(sesion, ficha: sinNacimiento, valoracion: apto),
        'Falta la fecha de nacimiento',
      ),
      (
        'sesión de un menor',
        _evaluar(sesion, ficha: menor, valoracion: apto),
        'menor de 18 años',
      ),
      (
        'sesión sin procedimiento',
        _evaluar(_cita(tipo: TipoCita.sesion, duracion: 60), valoracion: apto),
        'Elige el procedimiento',
      ),
      (
        'sesión sin valoración',
        _evaluar(sesion),
        'hace falta una valoración «apto» vigente',
      ),
      (
        'sesión con valoración «no apto»',
        _evaluar(sesion, valoracion: _valoracion(ResultadoValoracion.noApto)),
        '«no apto»',
      ),
      (
        'sesión con valoración «diferir»',
        _evaluar(sesion, valoracion: _valoracion(ResultadoValoracion.diferir)),
        '«diferir»',
      ),
      (
        'sesión después de que vence el «apto»',
        _evaluar(
          sesion,
          valoracion: _valoracion(
            ResultadoValoracion.apto,
            hasta: DateTime(2026, 11, 22),
          ),
        ),
        'no estará vigente ese día',
      ),
    ];
    for (final (caso, e, motivo) in bloqueos) {
      test('bloquea: $caso', () {
        expect(e.permiteGuardar, isFalse);
        expect(e.bloqueos.join(' | '), contains(motivo));
      });
    }

    test('una sesión con «apto» vigente ese día se guarda', () {
      expect(_evaluar(sesion, valoracion: apto).permiteGuardar, isTrue);
    });

    final otra = _cita(id: 'c2', inicio: DateTime(2026, 11, 23, 8, 10));
    final avisos = <(String, EvaluacionCita, String)>[
      (
        'en el pasado',
        _evaluar(_cita(inicio: DateTime(2026, 11, 19, 8))),
        'en el pasado',
      ),
      (
        'festivo',
        _evaluar(_cita(inicio: DateTime(2026, 12, 8, 8))),
        'Es festivo: Inmaculada Concepción',
      ),
      (
        'fuera del horario',
        _evaluar(_cita(inicio: DateTime(2026, 11, 23, 11, 50))),
        'Fuera del horario del lunes (08:00–12:00, 14:00–18:00)',
      ),
      (
        'domingo',
        _evaluar(_cita(inicio: DateTime(2026, 11, 22, 9))),
        'El domingo no hay atención',
      ),
      (
        'bloqueo',
        _evaluar(
          _cita(),
          horario: HorarioAgenda(
            bloqueos: [
              BloqueoAgenda(
                id: 'b',
                inicio: DateTime(2026, 11, 23, 7),
                fin: DateTime(2026, 11, 23, 9),
                motivo: 'Reunión',
              ),
            ],
          ),
        ),
        'Se cruza con un bloqueo: Reunión',
      ),
      (
        'cruce con otra cita',
        _evaluar(_cita(), otras: [otra]),
        'Se cruza con otra cita de 08:10 a 08:30',
      ),
    ];
    for (final (caso, e, aviso) in avisos) {
      test('avisa sin bloquear: $caso', () {
        expect(e.permiteGuardar, isTrue, reason: '${e.bloqueos}');
        expect(e.avisos.join(' | '), contains(aviso));
      });
    }

    test('una cita cancelada no se cruza con nadie', () {
      final cancelada = _cita(
        id: 'c2',
        inicio: DateTime(2026, 11, 23, 8, 10),
        estado: EstadoCita.cancelada,
      );
      expect(_evaluar(_cita(), otras: [cancelada]).avisos, isEmpty);
    });
  });

  group('Estados (por tabla)', () {
    final hoy = _cita(inicio: DateTime(2026, 11, 20, 8));
    final manana = _cita(inicio: DateTime(2026, 11, 21, 8));
    final casos = <(String, Cita, EstadoCita, String?)>[
      ('agendada → confirmada', manana, EstadoCita.confirmada, null),
      ('agendada → cancelada', manana, EstadoCita.cancelada, null),
      ('agendada → atendida hoy', hoy, EstadoCita.atendida, null),
      ('agendada → no asistió (ya pasó)', hoy, EstadoCita.noAsistio, null),
      (
        'atendida antes de su día',
        manana,
        EstadoCita.atendida,
        'Todavía no es el día',
      ),
      (
        'no asistió antes de su hora',
        manana,
        EstadoCita.noAsistio,
        'todavía no empieza',
      ),
      ('mismo estado', manana, EstadoCita.agendada, 'ya está «Agendada»'),
      (
        'atendida no cambia',
        hoy.copyWith(estado: EstadoCita.atendida),
        EstadoCita.agendada,
        'ya se atendió',
      ),
      (
        'cancelada vuelve a agendada',
        manana.copyWith(estado: EstadoCita.cancelada),
        EstadoCita.agendada,
        null,
      ),
      (
        'cancelada no pasa a confirmada',
        manana.copyWith(estado: EstadoCita.cancelada),
        EstadoCita.confirmada,
        'solo puede volver a «Agendada»',
      ),
    ];
    for (final (caso, c, nuevo, problema) in casos) {
      test(caso, () {
        final p = problemaCambioEstado(c, nuevo, _ahora);
        if (problema == null) {
          expect(p, isNull);
        } else {
          expect(p, contains(problema));
        }
      });
    }
  });

  group('Espacios libres', () {
    const h = HorarioAgenda();
    final lunes = DateTime(2026, 11, 23);
    test('día vacío: cada 30 minutos en las dos franjas', () {
      final l = espaciosLibres(lunes, 30, h, const []);
      expect(l.first, DateTime(2026, 11, 23, 8));
      expect(l[1], DateTime(2026, 11, 23, 8, 30));
      expect(l, contains(DateTime(2026, 11, 23, 14)));
      expect(l.last, DateTime(2026, 11, 23, 17, 30));
      expect(l, hasLength(16));
    });

    test('después de una cita, desde que termina', () {
      final l = espaciosLibres(lunes, 30, h, [
        _cita(inicio: DateTime(2026, 11, 23, 8), duracion: 20),
      ]);
      expect(l.take(2), [
        DateTime(2026, 11, 23, 8, 20),
        DateTime(2026, 11, 23, 8, 50),
      ]);
    });

    test('festivo, domingo y bloqueo de todo el día: nada', () {
      expect(espaciosLibres(DateTime(2026, 12, 8), 30, h, const []), isEmpty);
      expect(espaciosLibres(DateTime(2026, 11, 22), 30, h, const []), isEmpty);
      final conBloqueo = HorarioAgenda(
        bloqueos: [
          BloqueoAgenda(
            id: 'b',
            inicio: DateTime(2026, 11, 22),
            fin: DateTime(2026, 11, 24),
          ),
        ],
      );
      expect(espaciosLibres(lunes, 30, conBloqueo, const []), isEmpty);
    });
  });

  group('Recordatorios', () {
    test('mañana, abiertas y sin recordatorio', () {
      final p = pendientesDeRecordatorio([
        _cita(id: 'a', inicio: DateTime(2026, 11, 21, 9)),
        _cita(id: 'b', inicio: DateTime(2026, 11, 21, 8)),
        _cita(
          id: 'c',
          inicio: DateTime(2026, 11, 21, 10),
          estado: EstadoCita.cancelada,
        ),
        _cita(
          id: 'd',
          inicio: DateTime(2026, 11, 21, 11),
        ).copyWith(recordatorioEnviado: _ahora),
        _cita(id: 'e', inicio: DateTime(2026, 11, 22, 8)),
      ], _ahora);
      expect(p.map((c) => c.id), ['b', 'a']);
    });

    test('número de WhatsApp', () {
      const casos = <String, String?>{
        '300 123 4567': '573001234567',
        '+57 300-123-4567': '573001234567',
        '573001234567': '573001234567',
        '(602) 555 0101': null,
        '6025550101': null,
        '+1 305 555 0101': '13055550101',
        '': null,
        '12345': null,
      };
      casos.forEach((t, n) => expect(numeroWhatsapp(t), n, reason: t));
    });

    test('mensaje sin datos de salud y URL codificada', () {
      final m = mensajeRecordatorio(
        mensajeRecordatorioPorDefecto,
        nombre: 'José Ángel',
        inicio: DateTime(2026, 11, 21, 14, 30),
        consultorio: 'Consultorio Salud Plena',
        direccion: 'Calle 5 # 10-20',
      );
      expect(
        m,
        'Hola José Ángel, le recordamos su cita el sábado 21 de noviembre a '
        'las 2:30 p. m. en Consultorio Salud Plena, Calle 5 # 10-20. Por '
        'favor confirme respondiendo este mensaje.',
      );
      final url = urlWhatsapp('573001234567', m);
      expect(
        url,
        startsWith('https://wa.me/573001234567?text=Hola%20Jos%C3%A9'),
      );
      expect(url, contains('%23%2010-20'), reason: '«#» codificado');
      expect(Uri.parse(url).queryParameters['text'], m);
      expect(horaCorta(DateTime(2026, 1, 1, 12)), '12:00 p. m.');
      expect(horaCorta(DateTime(2026, 1, 1, 8, 5)), '8:05 a. m.');
      // Las llaves con tilde también se reemplazan.
      expect(
        mensajeRecordatorio(
          '{día} {dirección}',
          nombre: '',
          inicio: DateTime(2026, 11, 23, 8),
          consultorio: '',
          direccion: 'Calle 5',
        ),
        'lunes 23 de noviembre Calle 5',
      );
    });

    test('.ics válido, solo «Cita médica», hora y lugar', () {
      final c = _cita(
        tipo: TipoCita.sesion,
        inicio: DateTime(2026, 11, 23, 8),
        duracion: 60,
      ).copyWith(motivo: 'Hidrolipoclasia abdomen');
      final ics = icsCita(
        c,
        lugar:
            'Consultorio Salud Plena, Calle 5 # 10-20, Santander de '
            'Quilichao; segundo piso, consultorio 204 (al lado de la farmacia)',
        ahora: _ahora,
      );
      final lineas = ics.split('\r\n');
      expect(lineas.first, 'BEGIN:VCALENDAR');
      expect(lineas, contains('SUMMARY:Cita médica'));
      expect(lineas, contains('UID:c1@historiasclinicas.net'));
      final inicio = c.inicio.toUtc();
      expect(
        lineas.firstWhere((l) => l.startsWith('DTSTART:')),
        'DTSTART:${inicio.year}${inicio.month}${inicio.day}T'
        '${inicio.hour.toString().padLeft(2, '0')}0000Z',
      );
      // Ninguna línea pasa de 75 octetos (RFC 5545, 3.1).
      for (final l in lineas) {
        expect(utf8.encode(l).length, lessThanOrEqualTo(75), reason: l);
      }
      expect(lineas.where((l) => l.startsWith(' ')), isNotEmpty);
      // Desplegado (RFC 5545, 3.1), el lugar va entero y escapado.
      expect(
        ics.replaceAll('\r\n ', ''),
        contains(r'\, Calle 5 # 10-20\, Santander de Quilichao\;'),
      );
      expect(ics.endsWith('END:VCALENDAR\r\n'), isTrue);
      for (final prohibido in [
        'Sesión',
        'sesion',
        'Hidrolipoclasia',
        'f1',
        'Peña',
      ]) {
        expect(ics, isNot(contains(prohibido)), reason: prohibido);
      }
      expect(nombreArchivoIcs(c), 'Cita_2026-11-23_0800.ics');
    });
  });

  group('En el consultorio', () {
    late BancoConsultorio b;
    late String id;

    setUp(() async {
      b = BancoConsultorio(ahora: _ahora);
      await b.servicio.crear(fraseDePrueba);
      final r = await b.servicio.registrarHistoria(
        HistoriaPendiente(
          datos: historiaSintetica(),
          revision: 1,
          origen: OrigenArchivo.importado,
        ),
      );
      id = r!.pacienteId;
    });

    test(
      'agendar, cambiar estados y recordatorio; cifrado y al reabrir',
      () async {
        final agenda = b.servicio.agenda;
        final c = agenda
            .nueva(
              tipo: TipoCita.control,
              inicio: DateTime(2026, 11, 21, 8),
              pacienteId: id,
            )
            .copyWith(motivo: 'Control de tiroides');
        expect(c.duracionMin, 20);
        await agenda.guardar(c);
        expect(agenda.citasDelDia(DateTime(2026, 11, 21)).single.id, c.id);
        expect(agenda.pendientesRecordatorio().single.id, c.id);
        await agenda.marcarRecordatorio(c.id);
        expect(agenda.pendientesRecordatorio(), isEmpty);
        await agenda.cambiarEstado(c.id, EstadoCita.confirmada);
        await expectLater(
          agenda.cambiarEstado(c.id, EstadoCita.cancelada),
          throwsStateError,
          reason: 'sin motivo',
        );
        await agenda.cambiarEstado(c.id, EstadoCita.cancelada, motivo: 'Viaje');
        expect(agenda.cita(c.id)!.historial.map((h) => h.estado), [
          EstadoCita.agendada,
          EstadoCita.confirmada,
          EstadoCita.cancelada,
        ]);
        expect(contieneTexto(b.todosLosBytes, 'Control de tiroides'), isFalse);
        await b.servicio.bloquear();
        await b.servicio.desbloquear(fraseDePrueba);
        final otra = b.servicio.agenda.cita(c.id)!;
        expect(otra.estado, EstadoCita.cancelada);
        expect(otra.historial.last.motivo, 'Viaje');
        expect(otra.recordatorioEnviado, isNotNull);
      },
    );

    test('inasistencias y próxima cita', () async {
      final agenda = b.servicio.agenda;
      final ayer = await agenda.guardar(
        agenda.nueva(
          tipo: TipoCita.control,
          inicio: DateTime(2026, 11, 19, 8),
          pacienteId: id,
        ),
      );
      await agenda.cambiarEstado(ayer.id, EstadoCita.noAsistio);
      final luego = await agenda.guardar(
        agenda.nueva(
          tipo: TipoCita.control,
          inicio: DateTime(2026, 11, 24, 8),
          pacienteId: id,
        ),
      );
      expect(agenda.inasistencias(id), 1);
      expect(agenda.proximaCita(id)!.id, luego.id);
    });

    test('no agenda una sesión sin «apto» vigente; con él, sí', () async {
      final agenda = b.servicio.agenda;
      final f = b.servicio.indice.ficha(id)!;
      await b.servicio.indice.guardarFicha(
        f.copyWith(fechaNacimiento: DateTime(1990, 5, 3)),
      );
      final sesion = agenda.nueva(
        tipo: TipoCita.sesion,
        inicio: DateTime(2026, 11, 24, 9),
        pacienteId: id,
      );
      expect(sesion.plantillaId, 'hidrolipoclasia');
      expect(sesion.duracionMin, 60);
      await expectLater(agenda.guardar(sesion), throwsStateError);
      await aprobarHidrolipoclasia(b);
      await valorarAptoDePrueba(b, id);
      await agenda.guardar(sesion);
      expect(agenda.citasDe(id).single.tipo, TipoCita.sesion);
    });

    test('horario y bloqueos se guardan; los libres los respetan', () async {
      final agenda = b.servicio.agenda;
      await agenda.agregarBloqueo(
        inicio: DateTime(2026, 11, 23, 8),
        fin: DateTime(2026, 11, 23, 12),
        motivo: 'Capacitación',
      );
      await agenda.guardarHorario(
        agenda.horario.copyWith(duraciones: {TipoCita.control: 15}),
      );
      await b.servicio.bloquear();
      await b.servicio.desbloquear(fraseDePrueba);
      final a = b.servicio.agenda;
      expect(a.horario.bloqueos.single.motivo, 'Capacitación');
      expect(a.horario.duracion(TipoCita.control), 15);
      expect(
        a.libres(DateTime(2026, 11, 23), 30).first,
        DateTime(2026, 11, 23, 14),
      );
      await a.quitarBloqueo(a.horario.bloqueos.single.id);
      expect(
        a.libres(DateTime(2026, 11, 23), 30).first,
        DateTime(2026, 11, 23, 8),
      );
    });
  });
}
