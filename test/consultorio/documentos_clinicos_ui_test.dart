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
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
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

final _descargas = <(String, Uint8List)>[];

Future<void> _montar(
  WidgetTester t,
  BancoConsultorio b,
  String ruta, {
  Size tamano = const Size(1440, 1000),
}) async {
  t.view
    ..physicalSize = tamano
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  _descargas.clear();
  SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: <Override>[
      preferenciasProvider.overrideWithValue(prefs),
      rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
      servicioConsultorioProvider.overrideWithValue(b.servicio),
      descargarPdfProvider.overrideWithValue(
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

Future<void> _escribir(WidgetTester t, String etiqueta, String v) async {
  final f = find.ancestor(
    of: find.textContaining(etiqueta),
    matching: find.byType(TextField),
  );
  await t.ensureVisible(f.first);
  await t.enterText(f.first, v);
  await t.pump();
}

ButtonStyleButton _emitir(WidgetTester t) => t.widget<ButtonStyleButton>(
  find.ancestor(
    of: find.text('Emitir y descargar'),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  ),
);

/// Deja correr la vista previa (temporizador de 300 ms y el PDF).
Future<void> _terminar(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await t.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('sin aprobar, el botón dice por qué y lleva a Ajustes', (
    t,
  ) async {
    final (b, id) = await _conPaciente();
    await _montar(t, b, '/pacientes/$id/documento/certificado');
    expect(
      find.textContaining('La plantilla «General» está en borrador'),
      findsWidgets,
    );
    expect(_emitir(t).onPressed, isNull);
    expect(find.text('Ir a Ajustes'), findsOneWidget);
    await _terminar(t);
  });

  testWidgets('certificado: finalidad, texto y emitir descarga el PDF', (
    t,
  ) async {
    final (b, id) = await _conPaciente();
    await b.servicio.documentos.aprobarDe('certificado_general');
    await _montar(t, b, '/pacientes/$id/documento/certificado');
    expect(find.textContaining('con qué destino'), findsWidgets);
    await _escribir(t, 'Se expide con destino a', 'Empresa de prueba');
    await t.pumpAndSettle();
    expect(find.text('Listo para emitir, con 1 aviso.'), findsOneWidget);
    expect(find.textContaining('Quedan espacios'), findsOneWidget);
    await _pulsar(t, find.text('Emitir y descargar'));
    expect(_descargas.single.$1, startsWith('Certificado_'));
    expect(_descargas.single.$1, endsWith('_CE-000001.pdf'));
    // Vuelve a la ficha y el documento queda en ella.
    final d = b.servicio.documentos.documentosDe(id).single;
    expect(d.numero, 'CE-000001');
    expect(d.campos['finalidad'], 'Empresa de prueba');
    expect(find.textContaining('Certificado médico'), findsWidgets);
    await _terminar(t);
  });

  testWidgets('incapacidad: días, hasta y prórroga; sin NIT avisa', (t) async {
    final (b, id) = await _conPaciente();
    await b.servicio.documentos.aprobarDe('incapacidad');
    await _montar(t, b, '/pacientes/$id/documento/incapacidad');
    expect(
      find.text('Escribe los días para ver hasta cuándo va.'),
      findsOneWidget,
    );
    await _escribir(t, 'Días', '3');
    await t.pumpAndSettle();
    expect(
      find.text('Hasta el 23/11/2026 (el día de inicio cuenta).'),
      findsOneWidget,
    );
    expect(find.text('Falta tu NIT (Ajustes → Prestador).'), findsOneWidget);
    // El diagnóstico viene de la última historia.
    final e = b.servicio.documentos.evaluar(
      b.servicio.documentos
          .nuevoBorrador(
            TipoPlantilla.incapacidad,
            ficha: b.servicio.indice.ficha(id)!,
            medico: medicoCompleto(),
          )
          .copyWith(dias: 3),
      medico: medicoCompleto(),
      configuracion: b.servicio.configuracion,
    );
    expect(e.bloqueos.join(), contains('diagnóstico'));
    await _pulsar(t, find.text('Es una prórroga'));
    expect(
      find.text('Número de la incapacidad que se prorroga'),
      findsOneWidget,
    );
    await _terminar(t);
  });

  testWidgets('orden: cambiar de plantilla cambia el texto', (t) async {
    final (b, id) = await _conPaciente();
    for (final p in b.servicio.documentos.plantillasDe(TipoPlantilla.orden)) {
      await b.servicio.documentos.aprobarDe(p.id);
    }
    await _montar(t, b, '/pacientes/$id/documento/orden');
    expect(find.textContaining('Glucosa en ayunas'), findsOneWidget);
    await _pulsar(t, find.text('Perfil metabólico').last);
    await _pulsar(t, find.text('TSH').last);
    expect(find.textContaining('Glucosa en ayunas'), findsNothing);
    expect(
      find.textContaining('Hormona estimulante de la tiroides'),
      findsOneWidget,
    );
    await _pulsar(t, find.text('Emitir y descargar'));
    expect(_descargas.single.$1, endsWith('_OR-000001.pdf'));
    await _terminar(t);
  });

  testWidgets('la ficha abre los cuatro documentos desde «Documento»', (
    t,
  ) async {
    final (b, id) = await _conPaciente();
    await _montar(t, b, '/pacientes/$id');
    await _pulsar(t, find.text('Documento'));
    for (final texto in [
      'Certificado',
      'Incapacidad',
      'Orden de laboratorio o imágenes',
      'Remisión o interconsulta',
    ]) {
      expect(find.text(texto), findsOneWidget);
    }
    await _pulsar(t, find.text('Remisión o interconsulta'));
    expect(find.textContaining('Remitido a (especialidad'), findsWidgets);
    await _terminar(t);
  });

  testWidgets('un documento clínico se anula, no se revoca', (t) async {
    final (b, id) = await _conPaciente();
    final docs = b.servicio.documentos;
    await docs.aprobarDe('remision');
    await docs.emitirDocumento(
      docs
          .nuevoBorrador(
            TipoPlantilla.remision,
            ficha: b.servicio.indice.ficha(id)!,
            medico: medicoCompleto(),
          )
          .copyWith(destino: 'Endocrinología'),
      ficha: b.servicio.indice.ficha(id)!,
      medico: medicoCompleto(),
      pais: Pais.colombia,
      configuracion: b.servicio.configuracion,
    );
    await _montar(t, b, '/pacientes/$id', tamano: const Size(1440, 3000));
    expect(find.text('Registrar revocación'), findsNothing);
    expect(find.text('Anular'), findsOneWidget);
    expect(docs.documentosDe(id).single.estado, EstadoDocumento.vigente);
    await _terminar(t);
  });

  testWidgets('Ajustes: agregar una plantilla de orden propia', (t) async {
    final (b, _) = await _conPaciente();
    await _montar(t, b, '/ajustes', tamano: const Size(1440, 4000));
    await _pulsar(t, find.text('Agregar plantilla de orden'));
    await t.enterText(find.byType(TextField).last, 'Control prenatal');
    await t.pump();
    await _pulsar(t, find.text('Agregar'));
    expect(find.text('Control prenatal (propia)'), findsOneWidget);
    expect(
      b.servicio.documentos
          .plantillasDe(TipoPlantilla.orden)
          .any((p) => p.nombre == 'Control prenatal'),
      isTrue,
    );
    await _terminar(t);
  });

  for (final tipo in TipoPlantilla.clinicos) {
    testWidgets('320 px: ${tipo.name} sin desbordes', (t) async {
      final (b, id) = await _conPaciente();
      await _montar(
        t,
        b,
        '/pacientes/$id/documento/${tipo.name}',
        tamano: const Size(320, 640),
      );
      expect(t.takeException(), isNull);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Vista previa'), findsOneWidget);
      await _terminar(t);
    });
  }
}
