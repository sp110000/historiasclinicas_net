import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/agenda/cita.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/pacientes_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/medico/medico_provider.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

// Viernes 20/11/2026, 9:30.
final _ahora = DateTime(2026, 11, 20, 9, 30);

final _enlaces = <String>[];
final _descargas = <(String, Uint8List)>[];

Future<GoRouter> _montar(
  WidgetTester t,
  BancoConsultorio b, {
  String ruta = '/agenda',
  Size tamano = const Size(1440, 1200),
}) async {
  t.view
    ..physicalSize = tamano
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  _enlaces.clear();
  _descargas.clear();
  SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: <Override>[
      preferenciasProvider.overrideWithValue(prefs),
      rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
      servicioConsultorioProvider.overrideWithValue(b.servicio),
      abrirEnlaceProvider.overrideWithValue(_enlaces.add),
      descargarArchivoProvider.overrideWithValue(
        (bytes, nombre) => _descargas.add((nombre, bytes)),
      ),
    ],
  );
  addTearDown(c.dispose);
  c.read(medicoProvider.notifier).actualizar((_) => medicoCompleto());
  final router = crearRouterConsultorio(ubicacionInicial: ruta);
  addTearDown(router.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        theme: temaClaro(),
        routerConfig: router,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  );
  await t.pumpAndSettle();
  return router;
}

Future<(BancoConsultorio, String)> _conPaciente() async {
  final b = BancoConsultorio(ahora: _ahora);
  await b.servicio.crear(fraseDePrueba);
  final r = await b.servicio.registrarHistoria(
    HistoriaPendiente(
      datos: historiaSintetica(),
      revision: 1,
      origen: OrigenArchivo.importado,
    ),
  );
  return (b, r!.pacienteId);
}

Future<Cita> _agendar(
  BancoConsultorio b,
  String id, {
  required DateTime inicio,
  TipoCita tipo = TipoCita.control,
}) => b.servicio.agenda.guardar(
  b.servicio.agenda.nueva(tipo: tipo, inicio: inicio, pacienteId: id),
);

Future<void> _pulsar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('agendar desde «+ Cita»: paciente, hora libre y tarjeta', (
    t,
  ) async {
    final (b, id) = await _conPaciente();
    await _montar(t, b);
    expect(find.text('viernes 20/11/2026'), findsOneWidget);
    expect(find.text('Sin citas este día.'), findsOneWidget);
    expect(
      find.textContaining('Horario: 08:00–12:00, 14:00–18:00'),
      findsOneWidget,
    );
    await _pulsar(t, find.text('Cita'));
    expect(find.text('Nueva cita'), findsOneWidget);
    expect(find.text('Elige el paciente.'), findsOneWidget);
    await t.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first,
      'pena',
    );
    await t.pumpAndSettle();
    await _pulsar(t, find.textContaining('PEÑA').last);
    expect(find.text('Elige el paciente.'), findsNothing);
    // La primera hora libre después de las 9:30 (controles de 20 min).
    expect(find.widgetWithText(ActionChip, '09:40'), findsOneWidget);
    await _pulsar(t, find.text('Agendar'));
    final c = b.servicio.agenda.citasDe(id).single;
    expect(c.inicio, DateTime(2026, 11, 20, 9, 40));
    expect(find.text('09:40–10:00'), findsOneWidget);
    expect(find.textContaining('PEÑA'), findsWidgets);
    expect(find.text('Agendada'), findsOneWidget);
  });

  testWidgets('estados: confirmar y cancelar con motivo', (t) async {
    final (b, id) = await _conPaciente();
    final c = await _agendar(b, id, inicio: DateTime(2026, 11, 20, 10));
    await _montar(t, b);
    await _pulsar(t, find.text('Estado'));
    await _pulsar(t, find.text('Confirmada').last);
    expect(b.servicio.agenda.cita(c.id)!.estado, EstadoCita.confirmada);
    await _pulsar(t, find.text('Estado'));
    await _pulsar(t, find.text('Cancelar…'));
    await t.enterText(find.byType(TextField).last, 'Viaje');
    await t.pump();
    await _pulsar(t, find.text('Cancelar la cita').last);
    final cancelada = b.servicio.agenda.cita(c.id)!;
    expect(cancelada.estado, EstadoCita.cancelada);
    expect(find.text('Cancelada: Viaje'), findsOneWidget);
    expect(find.text('Atender'), findsNothing);
  });

  testWidgets('WhatsApp: mensaje editable, enlace +57 y recordatorio', (
    t,
  ) async {
    final (b, id) = await _conPaciente();
    await _agendar(b, id, inicio: DateTime(2026, 11, 20, 10));
    await _montar(t, b);
    await _pulsar(t, find.text('WhatsApp'));
    expect(find.text('Recordatorio por WhatsApp'), findsOneWidget);
    expect(find.textContaining('+573001234567'), findsOneWidget);
    await _pulsar(t, find.text('Abrir WhatsApp'));
    final url = _enlaces.single;
    expect(url, startsWith('https://wa.me/573001234567?text=Hola%20Jos%C3%A9'));
    final texto = Uri.parse(url).queryParameters['text']!;
    expect(texto, contains('viernes 20 de noviembre a las 10:00 a. m.'));
    expect(texto, contains('Consultorio Salud Plena'));
    expect(texto, isNot(contains('Control')));
    expect(find.text('Recordatorio enviado'), findsOneWidget);
  });

  testWidgets('mañana: citas sin recordatorio, con «Enviar»', (t) async {
    final (b, id) = await _conPaciente();
    await _agendar(b, id, inicio: DateTime(2026, 11, 21, 9));
    await _montar(t, b);
    expect(find.text('Mañana: 1 cita sin recordatorio'), findsOneWidget);
    await _pulsar(t, find.text('Enviar'));
    await _pulsar(t, find.text('Abrir WhatsApp'));
    expect(_enlaces, hasLength(1));
    expect(find.textContaining('sin recordatorio'), findsNothing);
  });

  testWidgets('.ics sin datos de salud', (t) async {
    final (b, id) = await _conPaciente();
    await _agendar(b, id, inicio: DateTime(2026, 11, 20, 10));
    await _montar(t, b);
    await _pulsar(t, find.text('.ics'));
    final (nombre, bytes) = _descargas.single;
    expect(nombre, 'Cita_2026-11-20_1000.ics');
    final ics = utf8.decode(bytes);
    expect(ics, contains('SUMMARY:Cita médica'));
    expect(ics, isNot(contains('PEÑA')));
    expect(ics, isNot(contains('Control')));
  });

  testWidgets('desde la ficha: una sesión sin «apto» no se agenda', (t) async {
    final (b, id) = await _conPaciente();
    await _montar(t, b, ruta: '/pacientes/$id', tamano: const Size(1440, 1600));
    await _pulsar(t, find.text('Agendar cita'));
    expect(find.textContaining('PEÑA'), findsWidgets);
    await _pulsar(t, find.text('Control').last);
    await _pulsar(t, find.text('Sesión de procedimiento').last);
    expect(
      find.textContaining('hace falta una valoración «apto» vigente'),
      findsOneWidget,
    );
    final agendar = t.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Agendar'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(agendar.onPressed, isNull);
  });

  testWidgets('semana: columnas por día; tocar un día vuelve a la de día', (
    t,
  ) async {
    final (b, id) = await _conPaciente();
    await _agendar(b, id, inicio: DateTime(2026, 11, 18, 8));
    await _agendar(
      b,
      id,
      inicio: DateTime(2026, 11, 20, 14),
      tipo: TipoCita.programaPeso,
    );
    await _montar(t, b);
    await _pulsar(t, find.text('Semana'));
    expect(find.text('Semana del 16/11/2026 al 22/11/2026'), findsOneWidget);
    for (final d in ['lunes 16', 'miércoles 18', 'domingo 22']) {
      expect(find.text(d), findsOneWidget);
    }
    expect(find.text('08:00–08:20'), findsOneWidget);
    expect(find.text('14:00–14:30'), findsOneWidget);
    await _pulsar(t, find.text('miércoles 18'));
    expect(find.text('miércoles 18/11/2026'), findsOneWidget);
  });

  testWidgets('Atender: abre la historia y la cita queda atendida', (t) async {
    final (b, id) = await _conPaciente();
    final c = await _agendar(b, id, inicio: DateTime(2026, 11, 20, 10));
    final router = await _montar(t, b, tamano: const Size(1920, 1200));
    await _pulsar(t, find.text('Atender'));
    expect(b.servicio.agenda.cita(c.id)!.estado, EstadoCita.atendida);
    expect(router.routeInformationProvider.value.uri.path, '/');
    // La historia deja temporizadores (guardado del borrador).
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('controles vencidos lleva a la lista filtrada', (t) async {
    final (b, _) = await _conPaciente();
    final router = await _montar(t, b);
    await _pulsar(t, find.textContaining('Controles vencidos'));
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/pacientes?vencidos=1',
    );
  });

  testWidgets('Ajustes → Agenda: horario y duración se guardan', (t) async {
    final (b, _) = await _conPaciente();
    await _montar(t, b, ruta: '/ajustes', tamano: const Size(1440, 5000));
    final sabado = find.ancestor(
      of: find.text('Sábado'),
      matching: find.byType(TextField),
    );
    await t.enterText(sabado, '9:00 a 11:00');
    await t.pump();
    final lunes = find.ancestor(
      of: find.text('Lunes'),
      matching: find.byType(TextField),
    );
    await t.enterText(lunes, '8 a 12');
    await t.pump();
    expect(find.textContaining('No se entiende'), findsOneWidget);
    await t.enterText(lunes, '7:00–13:00');
    await t.pump();
    await _pulsar(t, find.text('Guardar la agenda'));
    final h = b.servicio.agenda.horario;
    expect(h.franjasDe(DateTime.saturday).single.texto, '09:00–11:00');
    expect(h.franjasDe(DateTime.monday).single.texto, '07:00–13:00');
  });

  for (final (ancho, alto) in [(390.0, 844.0), (320.0, 640.0)]) {
    testWidgets('${ancho.toInt()} px: solo la vista de día, sin desbordes', (
      t,
    ) async {
      final (b, id) = await _conPaciente();
      await _agendar(b, id, inicio: DateTime(2026, 11, 20, 10));
      await _agendar(b, id, inicio: DateTime(2026, 11, 21, 9));
      await _montar(t, b, tamano: Size(ancho, alto));
      expect(t.takeException(), isNull);
      expect(find.text('Semana'), findsNothing);
      expect(find.text('10:00–10:20'), findsOneWidget);
      // Deslizar a la izquierda pasa al día siguiente.
      await t.fling(find.text('Hoy'), const Offset(-300, 0), 1000);
      await t.pumpAndSettle();
      expect(find.text('sábado 21/11/2026'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
