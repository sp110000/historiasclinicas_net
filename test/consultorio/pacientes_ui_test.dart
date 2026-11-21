import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/archivos/archivos.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/integridad/cadena_hash.dart';
import 'package:historiasclinicas_net/core/models/evolucion.dart';
import 'package:historiasclinicas_net/core/models/medico.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/pacientes_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/historia/estado/historia_controller.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

Future<ProviderContainer> _montar(
  WidgetTester t, {
  required BancoConsultorio banco,
  String ruta = '/pacientes',
  Size tamano = const Size(1440, 1000),
  List<Override> extra = const [],
}) async {
  t.view
    ..physicalSize = tamano
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      preferenciasProvider.overrideWithValue(prefs),
      rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
      servicioConsultorioProvider.overrideWithValue(banco.servicio),
      ...extra,
    ],
  );
  addTearDown(container.dispose);
  final router = crearRouterConsultorio(ubicacionInicial: ruta);
  addTearDown(router.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
  return container;
}

/// Consultorio abierto con tres pacientes; José tiene dos revisiones y una
/// evolución con próximo control.
Future<BancoConsultorio> _consultorioConPacientes() async {
  final b = BancoConsultorio();
  await b.servicio.crear(fraseDePrueba);
  final jose = sellarEvoluciones(historiaSintetica(id: 'h-jose'), [
    Evolucion(
      id: 'e1',
      fechaHora: DateTime(2026, 11, 10, 9),
      texto: 'Control de peso. Buena adherencia.',
      proximoControl: DateTime(2026, 11, 15),
    ).aMapa(),
  ]);
  final pdfJose = await pdfCon(jose, revision: 2);
  await b.servicio.registrarHistoria(
    HistoriaPendiente(
      datos: jose,
      revision: 2,
      origen: OrigenArchivo.generado,
      nombreArchivo: 'Pena_1032456789_r2.pdf',
      bytesPdf: pdfJose,
    ),
  );
  for (final (id, doc, ap, nom) in [
    ('h-maria', '222', 'Muñoz', 'María José'),
    ('h-andres', '333', 'Gómez', 'Andrés'),
  ]) {
    await b.servicio.registrarHistoria(
      HistoriaPendiente(
        datos: historiaSintetica(
          id: id,
          numeroDocumento: doc,
          primerApellido: ap,
          nombres: nom,
          fecha: DateTime(2026, 6, 1),
        ),
        revision: 1,
        origen: OrigenArchivo.importado,
      ),
    );
  }
  return b;
}

Future<void> _pulsar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Deja correr los temporizadores (autoguardado del borrador).
Future<void> _terminar(WidgetTester t) => t.pump(const Duration(seconds: 5));

double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  testWidgets('lista: búsqueda sin tildes y Enter abre la ficha', (t) async {
    final b = await _consultorioConPacientes();
    await _montar(t, banco: b);
    expect(find.text('Pacientes · 3'), findsOneWidget);
    expect(find.text('PEÑA MUÑOZ, José Ángel'), findsOneWidget);
    expect(find.text('MUÑOZ MUÑOZ, María José'), findsOneWidget);
    // José tenía control el 15/11 y no volvió: vencido.
    expect(find.text('Control vencido'), findsOneWidget);
    expect(find.text('Controles vencidos (1)'), findsOneWidget);

    await t.enterText(find.byType(TextField).first, 'pena jose');
    await t.pumpAndSettle();
    expect(find.text('1 paciente'), findsOneWidget);
    expect(find.text('MUÑOZ MUÑOZ, María José'), findsNothing);

    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(find.text('Ficha del paciente'), findsOneWidget);
    expect(find.text('PEÑA MUÑOZ, José Ángel'), findsOneWidget);
    await _terminar(t);
  });

  testWidgets('ficha: alergias, antecedentes con su fuente y línea de tiempo', (
    t,
  ) async {
    final b = await _consultorioConPacientes();
    final id = b.servicio.indice.historia('h-jose')!.pacienteId;
    await _montar(t, banco: b, ruta: '/pacientes/$id');
    // La píldora y el dato de antecedentes; sin «actualizadas»: vienen de
    // la historia inicial.
    expect(find.text('Alergias: Penicilina, AINEs'), findsNWidgets(2));
    expect(find.textContaining('actualizadas el'), findsNothing);
    expect(find.text('Control vencido (15/11/2026)'), findsOneWidget);
    expect(
      find.text('ANTECEDENTES · DE LA HISTORIA DEL 02/10/2026'),
      findsOneWidget,
    );
    expect(find.textContaining('Hipotiroidismo'), findsOneWidget);
    expect(find.text('02/10/2026 · Historia clínica'), findsOneWidget);
    expect(find.text('Íntegra · revisión 2'), findsOneWidget);
    expect(
      find.textContaining('Evolución 1 · Control de peso'),
      findsOneWidget,
    );
    expect(find.textContaining('Próximo control 15/11/2026'), findsOneWidget);
    expect(find.text('Ver PDF'), findsOneWidget);

    // Ver PDF entrega los bytes exactos del índice.
    Uint8List? visto;
    final c = await _montar(
      t,
      banco: b,
      ruta: '/pacientes/$id',
      extra: [
        verPdfProvider.overrideWithValue((bytes, _) async => visto = bytes),
      ],
    );
    await _pulsar(t, find.text('Ver PDF'));
    expect(visto, await b.servicio.indice.pdfDe('h-jose'));
    expect(c.read(historiaProvider).abierta, isFalse);
    await _terminar(t);
  });

  testWidgets('evolución desde la ficha: la historia abre con la franja', (
    t,
  ) async {
    final b = await _consultorioConPacientes();
    final id = b.servicio.indice.historia('h-jose')!.pacienteId;
    // La historia, con la fuente de pruebas, necesita una ventana ancha.
    final c = await _montar(
      t,
      banco: b,
      ruta: '/pacientes/$id',
      tamano: const Size(1920, 1200),
    );
    await _pulsar(t, find.text('Evolución'));

    final e = c.read(historiaProvider);
    expect(e.abierta, isTrue);
    expect(e.revision, 2);
    expect(e.evolucionesNuevas, hasLength(1));
    // La franja lleva de vuelta a la ficha.
    expect(find.text('Ficha'), findsOneWidget);
    expect(find.textContaining('PEÑA MUÑOZ, José Ángel'), findsWidgets);
    await _pulsar(t, find.text('Ficha'));
    expect(find.text('Ficha del paciente'), findsOneWidget);
    await _terminar(t);
  });

  testWidgets('actualizar alergias agrega la línea a la evolución en curso', (
    t,
  ) async {
    final b = await _consultorioConPacientes();
    final id = b.servicio.indice.historia('h-jose')!.pacienteId;
    // La historia, con la fuente de pruebas, necesita una ventana ancha.
    final c = await _montar(
      t,
      banco: b,
      ruta: '/pacientes/$id',
      tamano: const Size(1920, 1200),
    );
    await _pulsar(t, find.text('Actualizar alergias'));
    await t.enterText(
      find.widgetWithText(TextField, 'Alergias'),
      'Penicilina, látex',
    );
    await t.pump();
    await _pulsar(t, find.text('Agregar a la evolución'));

    final e = c.read(historiaProvider);
    expect(
      e.evolucionesNuevas.single.texto,
      'Alergias actualizadas: Penicilina, látex.',
    );
    expect(
      find.textContaining('Se agregó «Alergias actualizadas'),
      findsOneWidget,
    );

    // Sellada y registrada, la ficha la muestra.
    final g = c
        .read(historiaProvider.notifier)
        .prepararGuardado(medico: const Medico());
    await b.servicio.registrarHistoria(
      HistoriaPendiente(
        datos: g.datos,
        revision: g.revision,
        origen: OrigenArchivo.generado,
      ),
    );
    expect(b.servicio.indice.alergiasDe(id)!.alergias, ['Penicilina', 'látex']);
    await _terminar(t);
  });

  testWidgets('importar PDF: informe por archivo y lista actualizada', (
    t,
  ) async {
    final b = BancoConsultorio();
    await b.servicio.crear(fraseDePrueba);
    final buena = await pdfCon(historiaSintetica());
    final alteradaDatos = historiaSintetica(id: 'h-alt', numeroDocumento: '9');
    (alteradaDatos['motivo']! as Map)['motivoConsulta'] = 'Cambiado';
    final alterada = await pdfCon(alteradaDatos);
    final ajeno =
        await (pw.Document()
              ..addPage(pw.Page(build: (_) => pw.Text('Factura'))))
            .save();
    await _montar(
      t,
      banco: b,
      extra: [
        elegirPdfsProvider.overrideWithValue(
          () async => [
            ArchivoAbierto(nombre: 'buena.pdf', bytes: buena),
            ArchivoAbierto(nombre: 'alterada.pdf', bytes: alterada),
            ArchivoAbierto(nombre: 'factura.pdf', bytes: ajeno),
            ArchivoAbierto(
              nombre: 'nota.pdf',
              bytes: Uint8List.fromList(utf8.encode('hola')),
            ),
          ],
        ),
      ],
    );
    expect(find.text('Todavía no hay pacientes.'), findsOneWidget);
    await _pulsar(t, find.text('Importar PDF').first);

    expect(find.text('Importación terminada'), findsOneWidget);
    expect(find.textContaining('2 de 4 archivos en el índice'), findsOneWidget);
    expect(find.textContaining('1 con alteraciones'), findsOneWidget);
    expect(find.text('Importada con alteraciones'), findsOneWidget);
    expect(find.text('No es de la app'), findsNWidgets(2));
    await _pulsar(t, find.text('Cerrar'));
    expect(find.text('Pacientes · 2'), findsOneWidget);
    await _terminar(t);
  });

  testWidgets('paciente nuevo, editar datos y unir fichas', (t) async {
    final b = await _consultorioConPacientes();
    final c = await _montar(t, banco: b);
    // Una ficha sin documento, creada a mano.
    await _pulsar(t, find.text('Paciente'));
    await t.enterText(find.widgetWithText(TextFormField, 'Nombres'), 'Pepe');
    await t.enterText(
      find.widgetWithText(TextFormField, 'Primer apellido'),
      'Peña',
    );
    await t.pump();
    await _pulsar(t, find.text('Crear ficha'));
    expect(find.text('Ficha del paciente'), findsOneWidget);
    expect(find.text('PEÑA, Pepe'), findsOneWidget);

    // Editar: el teléfono queda en la ficha.
    await _pulsar(t, find.text('Editar datos'));
    await t.enterText(
      find.widgetWithText(TextFormField, 'Teléfono'),
      '311 222 3344',
    );
    await t.pump();
    await _pulsar(t, find.text('Guardar'));
    expect(find.textContaining('Tel. 311 222 3344'), findsOneWidget);

    // Unir con la de José: queda la de José (tiene documento).
    await _pulsar(t, find.text('Unir con otra ficha'));
    await t.enterText(
      find.widgetWithText(TextField, 'Buscar la otra ficha'),
      '1032456789',
    );
    await t.pumpAndSettle();
    await _pulsar(t, find.text('PEÑA MUÑOZ, José Ángel'));
    await _pulsar(t, find.widgetWithText(FilledButton, 'Unir'));
    expect(find.text('Ficha del paciente'), findsOneWidget);
    expect(find.text('PEÑA MUÑOZ, José Ángel'), findsOneWidget);
    // Conserva el teléfono de su historia y suma lo de la otra.
    final indice = b.servicio.indice;
    expect(indice.fichasActivas, hasLength(3));
    expect(c.read(versionIndiceProvider), greaterThan(0));
    await _terminar(t);
  });

  testWidgets('al cruzar el corte del riel la pantalla conserva su estado', (
    t,
  ) async {
    final b = await _consultorioConPacientes();
    await _montar(t, banco: b);
    expect(find.byType(NavigationRail), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'pena');
    await t.pumpAndSettle();
    expect(find.text('1 paciente'), findsOneWidget);

    t.view.physicalSize = const Size(700, 900);
    await t.pumpAndSettle();
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('1 paciente'), findsOneWidget, reason: 'misma pantalla');
    expect(find.widgetWithText(TextField, 'pena'), findsOneWidget);

    t.view.physicalSize = const Size(1440, 1000);
    await t.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('1 paciente'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _terminar(t);
  });

  for (final ruta in ['/pacientes', 'ficha']) {
    testWidgets('320 px sin desbordes: $ruta', (t) async {
      final b = await _consultorioConPacientes();
      final destino = ruta == 'ficha'
          ? '/pacientes/${b.servicio.indice.historia('h-jose')!.pacienteId}'
          : ruta;
      await _montar(t, banco: b, ruta: destino, tamano: const Size(320, 640));
      expect(t.takeException(), isNull);
      if (ruta == 'ficha') {
        await t.scrollUntilVisible(
          find.text('Acciones'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await _pulsar(t, find.text('Acciones'));
        expect(find.text('Unir con otra ficha'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.tapAt(const Offset(5, 600));
        await t.pumpAndSettle();
      }
      await t.drag(find.byType(Scrollable).last, const Offset(0, -3000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await _terminar(t);
    });
  }

  test('contraste de las píldoras y la franja (WCAG AA)', () {
    const blanco = Colors.white;
    for (final color in [
      ColoresMarca.error,
      ColoresMarca.aviso,
      ColoresMarca.estadoOk,
      ColoresMarca.primario,
      ColoresMarca.textoSuave,
    ]) {
      final fondo = Color.alphaBlend(color.withValues(alpha: 0.06), blanco);
      expect(
        _contraste(color, fondo),
        greaterThanOrEqualTo(4.5),
        reason: 'píldora $color',
      );
    }
    expect(
      _contraste(ColoresMarca.error, ColoresMarca.tinte),
      greaterThanOrEqualTo(4.5),
      reason: 'alergias en la franja',
    );
    expect(
      _contraste(ColoresMarca.primario, ColoresMarca.tinte),
      greaterThanOrEqualTo(4.5),
      reason: '← Ficha',
    );
    expect(
      _contraste(ColoresMarca.aviso, ColoresMarca.fondo),
      greaterThanOrEqualTo(4.5),
      reason: 'pendientes en el desbloqueo',
    );
  });
}
