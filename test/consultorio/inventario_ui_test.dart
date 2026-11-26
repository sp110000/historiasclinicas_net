import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/inventario/insumo.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/medicion.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/pacientes_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/inventario/dialogos_inventario.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/medico/medico_provider.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';
import 'ayudas_procedimientos.dart';

final _enlaces = <String>[];

Future<void> _montar(
  WidgetTester t,
  BancoConsultorio b, {
  String ruta = '/inventario',
  Size tamano = const Size(1440, 1200),
}) async {
  t.view
    ..physicalSize = tamano
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  _enlaces.clear();
  SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: <Override>[
      preferenciasProvider.overrideWithValue(prefs),
      rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
      servicioConsultorioProvider.overrideWithValue(b.servicio),
      abrirEnlaceProvider.overrideWithValue(_enlaces.add),
      descargarPdfProvider.overrideWithValue((_, _) {}),
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

Future<Insumo> _anestesico(BancoConsultorio b, {String registro = ''}) =>
    b.servicio.inventario.guardarInsumo(
      b.servicio.inventario.nuevoInsumo().copyWith(
        nombre: 'Anestésico de prueba',
        unidad: 'ampolla',
        presentacion: 'Ampolla de 5 mL',
        contenidoMl: 5.0,
        concentracionMgMl: 20.0,
        registroInvima: registro,
        inyectable: true,
        stockMinimo: 3,
      ),
    );

Future<void> _pulsar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Finder _campo(String etiqueta) =>
    find.ancestor(of: find.text(etiqueta), matching: find.byType(TextField));

Future<void> _escribir(WidgetTester t, String etiqueta, String v) async {
  final f = _campo(etiqueta).first;
  await t.ensureVisible(f);
  await t.enterText(f, v);
  await t.pumpAndSettle();
}

ButtonStyleButton _boton(WidgetTester t, String texto) =>
    t.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(texto).last,
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );

void main() {
  testWidgets('insumo nuevo, entradas, ajuste, baja, movimientos e Invima', (
    t,
  ) async {
    final (b, _) = await _conPaciente();
    await _montar(t, b);
    expect(find.text('Inventario vacío'), findsOneWidget);
    expect(_boton(t, 'Entrada').onPressed, isNull);

    await _pulsar(t, find.text('Insumo'));
    await _escribir(t, 'Nombre *', 'Anestésico de prueba');
    await _escribir(t, 'Presentación', 'Ampolla de 5 mL');
    await _escribir(t, 'Unidad *', 'ampolla');
    await _escribir(t, 'Contenido por unidad', '5');
    await _escribir(t, 'Concentración', '20');
    await _escribir(t, 'Mínimo', '3');
    await _pulsar(t, find.text('Inyectable'));
    expect(
      find.textContaining('es inyectable y no tiene registro Invima'),
      findsOneWidget,
    );
    await _pulsar(t, find.text('Guardar el insumo'));
    expect(
      find.text('Insumo «Anestésico de prueba» guardado.'),
      findsOneWidget,
    );
    expect(find.text('Existencia: 0 ampollas (mínimo 3)'), findsOneWidget);
    expect(find.text('1 bajo el mínimo'), findsOneWidget);
    expect(find.text('1 insumo sin registro Invima'), findsOneWidget);
    expect(
      find.text(
        '«Anestésico de prueba» es inyectable y no tiene registro Invima: '
        'verifícalo antes de usarlo.',
      ),
      findsOneWidget,
    );

    // Entrada: un lote vencido no se ingresa.
    await _pulsar(t, find.text('Entrada').first);
    expect(find.text('Entrada de un lote'), findsOneWidget);
    await _escribir(t, 'Lote *', 'L-A');
    await _escribir(t, 'Vence *', '01/11/2026');
    await _escribir(t, 'Cantidad', '4');
    expect(
      find.text('El lote L-A venció el 01/11/2026: no se ingresa.'),
      findsOneWidget,
    );
    expect(_boton(t, 'Registrar la entrada').onPressed, isNull);
    await _escribir(t, 'Vence *', '15/12/2026');
    expect(find.text('Vence en 24 días.'), findsOneWidget);
    await _pulsar(t, find.text('Registrar la entrada'));
    expect(find.textContaining('Entrada registrada: lote L-A'), findsOneWidget);
    expect(find.text('Lote L-A'), findsOneWidget);
    expect(find.text('Vence en 24 días'), findsOneWidget);
    expect(find.text('Existencia: 4 ampollas (mínimo 3)'), findsOneWidget);
    expect(find.text('1 bajo el mínimo'), findsNothing);
    expect(find.text('1 lote vence en 30 días o menos'), findsOneWidget);

    // Ajuste: restar 2 con motivo.
    await _pulsar(t, find.text('Ajustar L-A'));
    await _escribir(t, 'Cantidad', '2');
    await _escribir(t, 'Motivo *', 'Ampollas rotas');
    expect(find.text('Quedan 2 ampollas.'), findsOneWidget);
    await _pulsar(t, find.text('Ajustar'));
    expect(find.text('Lote L-A ajustado.'), findsOneWidget);
    expect(find.text('Existencia: 2 ampollas (mínimo 3)'), findsOneWidget);
    expect(find.text('1 bajo el mínimo'), findsOneWidget);

    // Baja: el lote sale de la lista; los movimientos quedan.
    await _pulsar(t, find.text('Dar de baja L-A'));
    await t.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Dañado',
    );
    await _pulsar(t, find.text('Dar de baja'));
    expect(find.text('Lote L-A dado de baja.'), findsOneWidget);
    expect(find.text('Lote L-A'), findsNothing);
    await _pulsar(t, find.text('Movimientos (3)'));
    expect(find.textContaining('Entrada · lote L-A · +4'), findsOneWidget);
    expect(
      find.textContaining('Ajuste · lote L-A · -2 · Ampollas rotas'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Baja · lote L-A · -2 · Dañado'),
      findsOneWidget,
    );

    // Invima en otra pestaña, sin datos.
    await _pulsar(t, find.text('Consultar en Invima'));
    expect(_enlaces, [urlConsultaInvima]);
  });

  testWidgets('«Eliminar» pide confirmación y quita el insumo de la lista', (
    t,
  ) async {
    final (b, _) = await _conPaciente();
    final i = await _anestesico(b, registro: 'INVIMA PRUEBA-0001');
    await b.servicio.inventario.registrarEntrada(
      insumoId: i.id,
      numero: 'L-A',
      vence: DateTime(2027, 6, 30),
      cantidad: 2,
    );
    await _montar(t, b);
    expect(find.text('Anestésico de prueba'), findsOneWidget);
    await _pulsar(t, find.text('Eliminar'));
    expect(find.text('¿Eliminar «Anestésico de prueba»?'), findsOneWidget);
    expect(find.textContaining('se guarda oculto'), findsOneWidget);
    expect(find.textContaining('2 ampollas en existencia'), findsOneWidget);
    // Cancelar no cambia nada.
    await _pulsar(t, find.text('Cancelar'));
    expect(b.servicio.inventario.insumos, hasLength(1));
    await _pulsar(t, find.text('Eliminar'));
    await _pulsar(t, find.text('Eliminar').last);
    expect(
      find.text('Insumo «Anestésico de prueba» eliminado.'),
      findsOneWidget,
    );
    expect(b.servicio.inventario.insumos, isEmpty);
    expect(find.text('Inventario vacío'), findsOneWidget);
  });

  testWidgets('la agenda avisa del inventario y lleva a él', (t) async {
    final (b, _) = await _conPaciente();
    final i = await _anestesico(b, registro: 'INVIMA PRUEBA-0001');
    await b.servicio.inventario.registrarEntrada(
      insumoId: i.id,
      numero: 'L-A',
      vence: DateTime(2026, 12, 1),
      cantidad: 2,
    );
    await _montar(t, b, ruta: '/agenda');
    expect(
      find.text('Inventario: 1 bajo el mínimo · 1 por vencer'),
      findsOneWidget,
    );
    await _pulsar(t, find.text('Ver el inventario'));
    expect(find.text('Vence en 10 días'), findsOneWidget);
  });

  testWidgets('sesión: el lote sugerido del inventario, cambiarlo y '
      'escribirlo a mano', (t) async {
    final (b, id) = await _conPaciente();
    await b.servicio.seguimiento.guardarMedicion(
      Medicion(
        id: '',
        pacienteId: id,
        fecha: DateTime(2026, 11, 20, 9),
        creado: DateTime(2026, 11, 20, 9),
        peso: 64,
      ),
    );
    await aprobarHidrolipoclasia(b);
    await valorarAptoDePrueba(b, id);
    await consentimientoDePrueba(b, id);
    final i = await _anestesico(b, registro: 'INVIMA PRUEBA-0001');
    await b.servicio.inventario.registrarEntrada(
      insumoId: i.id,
      numero: 'L-A',
      vence: DateTime(2026, 12, 15),
      cantidad: 1,
    );
    await b.servicio.inventario.registrarEntrada(
      insumoId: i.id,
      numero: 'L-B',
      vence: DateTime(2027, 6, 30),
      cantidad: 10,
    );
    await _montar(t, b, ruta: '/pacientes/$id/sesion/hidrolipoclasia');
    expect(
      find.text('Del inventario: lote L-A · vence 15/12/2026'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Anestésico de prueba · quedan 1 ampolla · se descuentan 1 ampolla '
        'al sellar',
      ),
      findsOneWidget,
    );
    // 10 mL son 2 ampollas: el L-A no alcanza.
    await _escribir(t, 'Volumen del anestésico', '10');
    expect(
      find.textContaining('se descuentan 2 ampollas al sellar'),
      findsOneWidget,
    );
    expect(find.text('No alcanza: quedan 1 ampolla.'), findsOneWidget);
    expect(
      b.servicio.inventario.existencia(
        b.servicio.inventario.lotesDe(i.id).first.id,
      ),
      1,
    );
    // Cambiar al L-B.
    await _pulsar(t, find.text('Cambiar lote'));
    expect(find.text('Lote de «Anestésico de prueba»'), findsOneWidget);
    expect(find.textContaining('sugerido (vence primero)'), findsOneWidget);
    await _pulsar(t, find.text('Lote L-B · vence 30/06/2027'));
    expect(
      find.text('Del inventario: lote L-B · vence 30/06/2027'),
      findsOneWidget,
    );
    expect(find.textContaining('tiene 1 ampolla'), findsNothing);
    // A mano: avisa que no se descontará.
    await _pulsar(t, find.text('Cambiar lote'));
    await _pulsar(t, find.text('Escribirlo a mano'));
    expect(find.text('Lote (Anestésico de prueba)'), findsOneWidget);
    await _escribir(t, 'Lote (Anestésico de prueba)', 'L9');
    expect(
      find.textContaining('su lote se escribió a mano: no se descontará'),
      findsOneWidget,
    );
    // Y de nuevo del inventario.
    await _pulsar(t, find.text('Elegir del inventario').last);
    await _pulsar(t, find.text('Lote L-A · vence 15/12/2026'));
    expect(
      find.text('Del inventario: lote L-A · vence 15/12/2026'),
      findsOneWidget,
    );
    await t.pump(const Duration(seconds: 5));
  });

  for (final ancho in [390.0, 320.0]) {
    testWidgets('$ancho px: inventario, entrada y lote de la sesión sin '
        'desbordes', (t) async {
      final (b, id) = await _conPaciente();
      await b.servicio.seguimiento.guardarMedicion(
        Medicion(
          id: '',
          pacienteId: id,
          fecha: DateTime(2026, 11, 20, 9),
          creado: DateTime(2026, 11, 20, 9),
          peso: 64,
        ),
      );
      await aprobarHidrolipoclasia(b);
      await valorarAptoDePrueba(b, id);
      await consentimientoDePrueba(b, id);
      final i = await _anestesico(b);
      await b.servicio.inventario.registrarEntrada(
        insumoId: i.id,
        numero: 'L-0123456789',
        vence: DateTime(2026, 12, 1),
        cantidad: 2,
        proveedor: 'Distribuidora de prueba S. A. S.',
      );
      await _montar(t, b, tamano: Size(ancho, 760));
      expect(find.text('Lote L-0123456789'), findsOneWidget);
      await _pulsar(t, find.text('Movimientos (1)'));
      await _pulsar(t, find.text('Entrada').first);
      await _pulsar(t, find.text('Cancelar'));
      await _pulsar(t, find.byTooltip('Insumo nuevo'));
      await _pulsar(t, find.text('Cancelar'));
      await _montar(
        t,
        b,
        ruta: '/pacientes/$id/sesion/hidrolipoclasia',
        tamano: Size(ancho, 760),
      );
      // En pantallas angostas cada bloque se abre al tocarlo.
      await _pulsar(t, find.text('ANESTÉSICO'));
      expect(
        find.textContaining('Del inventario: lote L-0123456789'),
        findsOneWidget,
      );
      expect(find.text('Vence pronto'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 5));
    });
  }
}
