import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/archivos/archivo.dart';
import 'package:historiasclinicas_net/core/consultorio/imagenes/estudio_imagen.dart';
import 'package:historiasclinicas_net/core/consultorio/imagenes/plantillas_eco.dart';
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

final _foto = File('test/fixtures/foto_con_exif.jpg').readAsBytesSync();
final _descargados = <String>[];
final _vistos = <String>[];

Future<GoRouter> _montar(
  WidgetTester t,
  BancoConsultorio b, {
  String ruta = '/imagenes',
  Size tamano = const Size(1440, 1200),
}) async {
  t.view
    ..physicalSize = tamano
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  _descargados.clear();
  _vistos.clear();
  SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: <Override>[
      preferenciasProvider.overrideWithValue(prefs),
      rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
      servicioConsultorioProvider.overrideWithValue(b.servicio),
      descargarPdfProvider.overrideWithValue(
        (_, nombre) => _descargados.add(nombre),
      ),
      verPdfProvider.overrideWithValue(
        (_, nombre) async => _vistos.add(nombre),
      ),
      elegirImagenProvider.overrideWithValue(
        () async => ArchivoAbierto(
          nombre: 'captura.jpg',
          bytes: Uint8List.fromList(_foto),
        ),
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
  final b = BancoConsultorio();
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

Future<void> _pulsar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Finder _campo(String etiqueta) =>
    find.ancestor(of: find.text(etiqueta), matching: find.byType(TextField));

/// Deja correr el guardado del borrador (500 ms).
Future<void> _guardar(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 600));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'Imágenes en el menú: nuevo estudio, hallazgos, medidas con volumen, '
    'imagen, cerrar con PDF, imprimir y verlo en la ficha',
    (t) async {
      final (b, id) = await _conPaciente();
      final router = await _montar(t, b);
      final riel = t.widget<NavigationRail>(find.byType(NavigationRail));
      expect(
        riel.destinations.map((d) => (d.label as Semantics).properties.label),
        contains('Imágenes'),
      );
      expect(find.text('Todavía no hay estudios'), findsOneWidget);

      // Nuevo estudio: paciente y tipo.
      await _pulsar(t, find.text('Nuevo estudio').first);
      await t.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'pena',
      );
      await t.pumpAndSettle();
      await _pulsar(t, find.textContaining('PEÑA').last);
      await _pulsar(t, find.text('Ecografía abdominal total').last);
      await _pulsar(t, find.text('Ecografía de tiroides y cuello').last);
      await _pulsar(t, find.text('Crear informe'));
      final estudio = b.servicio.imagenes.estudios.single;
      expect(
        router.routeInformationProvider.value.uri.path,
        '/imagenes/${estudio.id}',
      );
      expect(find.text('Borrador'), findsOneWidget);
      expect(find.text('Lóbulo derecho'), findsWidgets);
      expect(
        find.textContaining('Para cerrar falta el equipo'),
        findsOneWidget,
      );

      // Equipo y el volumen del lóbulo derecho.
      await t.enterText(_campo('Equipo *'), 'POCUS de prueba');
      final largo = _campo('Largo').first;
      await t.enterText(largo, '1,8');
      await t.enterText(_campo('Ancho').first, '2');
      await t.enterText(_campo('Alto').first, '4,5');
      await _guardar(t);
      expect(find.text('Volumen 8,5 mL'), findsOneWidget);
      expect(find.textContaining('Para cerrar falta'), findsNothing);

      // Una imagen con su rótulo.
      await _pulsar(t, find.text('Agregar imagen'));
      expect(find.text('1 de 6 en el informe'), findsOneWidget);
      await t.enterText(_campo('Rótulo'), 'Lóbulo derecho, transversal');
      await _guardar(t);
      expect(
        b.servicio.imagenes.estudio(estudio.id)!.imagenes.single.rotulo,
        'Lóbulo derecho, transversal',
      );

      // Vista previa y cierre.
      await _pulsar(t, find.text('Vista previa'));
      expect(_vistos, ['Ecografia_PENA_borrador.pdf']);
      await _pulsar(t, find.text('Cerrar informe'));
      await _pulsar(t, find.text('Cerrar y descargar'));
      expect(_descargados, ['Ecografia_PENA_EC-000001.pdf']);
      expect(
        find.text('Informe EC-000001 cerrado y descargado.'),
        findsOneWidget,
      );
      final cerrado = b.servicio.imagenes.estudio(estudio.id)!;
      expect(cerrado.estado, EstadoEstudio.cerrado);
      expect(cerrado.equipo, 'POCUS de prueba');
      expect(cerrado.medidas.first.resultado, closeTo(8.47, 0.01));
      expect(find.text('Informe EC-000001'), findsOneWidget);
      await _pulsar(t, find.text('Imprimir'));
      expect(_vistos.last, 'Ecografia_PENA_EC-000001.pdf');

      // En Imágenes y en la ficha.
      router.go('/imagenes');
      await t.pumpAndSettle();
      expect(find.text('INFORMES'), findsOneWidget);
      expect(find.text('EC-000001'), findsOneWidget);
      router.go('/pacientes/$id');
      await t.pumpAndSettle();
      expect(find.text('Ecografía'), findsOneWidget);
      expect(find.text('Ecografía de tiroides y cuello'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('desde la ficha: «Ecografía» crea el borrador de ese paciente '
      'y se puede borrar', (t) async {
    final (b, id) = await _conPaciente();
    final router = await _montar(t, b, ruta: '/pacientes/$id');
    await _pulsar(t, find.text('Ecografía'));
    await _pulsar(t, find.text('Crear informe'));
    final e = b.servicio.imagenes.estudios.single;
    expect(e.pacienteId, id);
    expect(e.titulo, 'Ecografía abdominal total');
    await _pulsar(t, find.text('Borrar borrador'));
    await _pulsar(t, find.widgetWithText(FilledButton, 'Borrar'));
    expect(b.servicio.imagenes.estudios, isEmpty);
    expect(router.routeInformationProvider.value.uri.path, '/imagenes');
  });

  for (final ancho in [390.0, 320.0]) {
    testWidgets('$ancho px: Imágenes y el informe sin desbordes', (t) async {
      final (b, id) = await _conPaciente();
      final e = await b.servicio.imagenes.crear(
        b.servicio.indice.ficha(id)!,
        plantillaEco('tiroides_cuello')!,
      );
      await _montar(t, b, tamano: Size(ancho, 800));
      expect(find.text('BORRADORES'), findsOneWidget);
      await _montar(t, b, ruta: '/imagenes/${e.id}', tamano: Size(ancho, 800));
      expect(find.text('Hallazgos'), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
    });
  }
}
