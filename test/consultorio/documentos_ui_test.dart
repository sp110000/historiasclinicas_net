import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/documento.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/plantillas.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/core/widgets/lienzo_firma.dart';
import 'package:historiasclinicas_net/features/consultorio/documentos/firma_autorizacion.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/pacientes_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/medico/medico_provider.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

/// Lo que se descargó: nombre y bytes.
final descargas = <(String, Uint8List)>[];

Future<ProviderContainer> _montar(
  WidgetTester t, {
  required BancoConsultorio banco,
  required String ruta,
  Size tamano = const Size(1440, 1000),
  bool conMedico = true,
}) async {
  t.view
    ..physicalSize = tamano
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  descargas.clear();
  SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: <Override>[
      preferenciasProvider.overrideWithValue(prefs),
      rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
      servicioConsultorioProvider.overrideWithValue(banco.servicio),
      descargarPdfProvider.overrideWithValue(
        (bytes, nombre) => descargas.add((nombre, bytes)),
      ),
      exportarFirmaProvider.overrideWithValue((_) async => firmaDePrueba),
    ],
  );
  addTearDown(container.dispose);
  if (conMedico) {
    container.read(medicoProvider.notifier).actualizar((_) => medicoCompleto());
  }
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

Future<void> _pulsar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _terminar(WidgetTester t) => t.pump(const Duration(seconds: 5));

Future<(BancoConsultorio, String)> _conPaciente({bool aprobada = true}) async {
  final b = BancoConsultorio();
  await b.servicio.crear(fraseDePrueba);
  final r = await b.servicio.registrarHistoria(
    HistoriaPendiente(
      datos: historiaSintetica(),
      revision: 1,
      origen: OrigenArchivo.importado,
    ),
  );
  if (aprobada) {
    await b.servicio.documentos.aprobar(TipoPlantilla.autorizacionDatos);
  }
  return (b, r!.pacienteId);
}

void main() {
  testWidgets('Ajustes: editar y aprobar plantillas, descargar la política', (
    t,
  ) async {
    final b = BancoConsultorio();
    await b.servicio.crear(fraseDePrueba);
    await _montar(t, banco: b, ruta: '/ajustes');
    expect(find.text('Plantillas de documentos'), findsOneWidget);
    expect(find.text('v1 en borrador (sin aprobar)'), findsNWidgets(2));
    expect(find.text('Descargar PDF para exhibir'), findsNothing);

    // Editar la autorización: el borrador cambia, sigue sin aprobar.
    await _pulsar(t, find.text('Editar borrador').first);
    await t.enterText(
      find.widgetWithText(TextField, 'Texto'),
      'Yo, {{paciente}}, autorizo a {{responsable}}.',
    );
    await _pulsar(t, find.text('Guardar borrador'));
    final aut = b.servicio.documentos.plantilla(
      TipoPlantilla.autorizacionDatos,
    );
    expect(aut.ultima.cuerpo, 'Yo, {{paciente}}, autorizo a {{responsable}}.');
    expect(aut.usable, isFalse);

    await _pulsar(t, find.text('Aprobar v1').first);
    expect(find.text('¿Aprobar la versión 1?'), findsOneWidget);
    await _pulsar(t, find.widgetWithText(FilledButton, 'Aprobar'));
    expect(find.text('v1 aprobada el 21/11/2026'), findsOneWidget);
    expect(
      b.servicio.documentos.plantilla(TipoPlantilla.autorizacionDatos).usable,
      isTrue,
    );

    // La política, aprobada, se descarga en PDF.
    await _pulsar(t, find.text('Aprobar v1'));
    await _pulsar(t, find.widgetWithText(FilledButton, 'Aprobar'));
    await _pulsar(t, find.text('Descargar PDF para exhibir'));
    expect(descargas.single.$1, 'Politica_tratamiento_datos_v1.pdf');
    expect(String.fromCharCodes(descargas.single.$2.take(5)), '%PDF-');
    await _terminar(t);
  });

  testWidgets('ficha: firmar la autorización, verla y revocarla', (t) async {
    final (b, id) = await _conPaciente();
    await _montar(t, banco: b, ruta: '/pacientes/$id');
    expect(
      find.text('Sin autorización de tratamiento de datos'),
      findsOneWidget,
    );

    await _pulsar(t, find.text('Pedir autorización'));
    expect(find.textContaining('Yo, PEÑA MUÑOZ, José Ángel'), findsOneWidget);
    expect(find.text('Plantilla versión 1'), findsOneWidget);
    FilledButton boton() => t.widget<FilledButton>(
      find.ancestor(
        of: find.text('Firmar y descargar PDF'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(boton().onPressed, isNull);

    await _pulsar(
      t,
      find.text('El paciente leyó el documento y resolvió sus dudas'),
    );
    expect(boton().onPressed, isNull, reason: 'falta la firma');
    await t.ensureVisible(find.byType(LienzoFirma));
    await t.drag(find.byType(LienzoFirma), const Offset(120, 30));
    await t.pumpAndSettle();
    expect(boton().onPressed, isNotNull);

    await _pulsar(t, find.text('Firmar y descargar PDF'));
    expect(descargas.single.$1, 'Autorizacion_datos_Peña_AD-000001.pdf');
    expect(
      find.text('Autorización de datos firmada el 21/11/2026 · AD-000001'),
      findsOneWidget,
    );
    expect(find.textContaining('AD-000001 · versión 1'), findsOneWidget);
    expect(
      find.textContaining('Autorización firmada (AD-000001)'),
      findsOneWidget,
    );

    // Revocar: queda registrada, la ficha vuelve a pedirla.
    await _pulsar(t, find.text('Registrar revocación'));
    await t.enterText(find.widgetWithText(TextField, 'Motivo'), 'Por escrito');
    await t.pump();
    await _pulsar(t, find.widgetWithText(FilledButton, 'Registrar revocación'));
    expect(find.text('Revocado el 21/11/2026: Por escrito'), findsOneWidget);
    // El encabezado quedó arriba, fuera de la vista: se vuelve a él.
    await t.drag(find.byType(ListView).first, const Offset(0, 3000));
    await t.pumpAndSettle();
    expect(
      find.text('Sin autorización de tratamiento de datos'),
      findsOneWidget,
    );
    final d = b.servicio.documentos.documentosDe(id).single;
    expect(d.estado, EstadoDocumento.revocado);
    await _terminar(t);
  });

  testWidgets('sin plantilla aprobada, la firma lleva a Ajustes', (t) async {
    final (b, id) = await _conPaciente(aprobada: false);
    await _montar(t, banco: b, ruta: '/pacientes/$id');
    await _pulsar(t, find.text('Pedir autorización'));
    expect(find.textContaining('está en borrador'), findsOneWidget);
    expect(find.text('Firmar y descargar PDF'), findsNothing);
    await _pulsar(t, find.text('Ir a Ajustes'));
    expect(find.text('Ajustes del consultorio'), findsOneWidget);
    await _terminar(t);
  });

  testWidgets('sin datos del médico, pide completarlos', (t) async {
    final (b, id) = await _conPaciente();
    await _montar(t, banco: b, ruta: '/pacientes/$id', conMedico: false);
    await _pulsar(t, find.text('Pedir autorización'));
    expect(find.textContaining('Completa tus datos de médico'), findsOneWidget);
    expect(find.text('Datos del médico'), findsOneWidget);
    await _terminar(t);
  });

  testWidgets('320 px: el diálogo de firma no se desborda', (t) async {
    final (b, id) = await _conPaciente();
    await _montar(
      t,
      banco: b,
      ruta: '/pacientes/$id',
      tamano: const Size(320, 640),
    );
    await t.scrollUntilVisible(
      find.text('Pedir autorización'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await _pulsar(t, find.text('Pedir autorización'));
    expect(t.takeException(), isNull);
    await t.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -2000),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await _terminar(t);
  });
}
