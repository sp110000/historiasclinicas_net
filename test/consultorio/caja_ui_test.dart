import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/agenda/cita.dart';
import 'package:historiasclinicas_net/core/consultorio/caja/catalogo.dart';
import 'package:historiasclinicas_net/core/consultorio/caja/movimientos.dart';
import 'package:historiasclinicas_net/core/consultorio/inventario/insumo.dart';
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

// Lunes 23/11/2026, 9:30.
final _ahora = DateTime(2026, 11, 23, 9, 30);

final _pdfs = <String>[];
final _archivos = <(String, Uint8List)>[];

Future<GoRouter> _montar(
  WidgetTester t,
  BancoConsultorio b, {
  String ruta = '/caja',
  Size tamano = const Size(1440, 1200),
}) async {
  t.view
    ..physicalSize = tamano
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  _pdfs.clear();
  _archivos.clear();
  SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: <Override>[
      preferenciasProvider.overrideWithValue(prefs),
      rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
      servicioConsultorioProvider.overrideWithValue(b.servicio),
      descargarPdfProvider.overrideWithValue((_, nombre) => _pdfs.add(nombre)),
      descargarArchivoProvider.overrideWithValue(
        (bytes, nombre) => _archivos.add((nombre, bytes)),
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

ItemCobro _item(BancoConsultorio b, String id) {
  final s = b.servicio.caja.serviciosPorId[id]!;
  return ItemCobro(
    servicioId: s.id,
    descripcion: s.nombre,
    valorUnitario: s.tarifa,
  );
}

Future<void> _cobrar(
  BancoConsultorio b,
  String paciente,
  String servicio,
  List<PagoRecibo> pagos,
) => b.servicio.caja.cobrar(
  pacienteId: paciente,
  items: [_item(b, servicio)],
  pagos: pagos,
  medico: medicoCompleto(),
  pais: Pais.colombia,
);

Future<void> _pulsar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Finder _enDialogo(Finder f) =>
    find.descendant(of: find.byType(AlertDialog), matching: f);

Finder _campo(String etiqueta) =>
    find.ancestor(of: find.text(etiqueta), matching: find.byType(TextField));

ButtonStyleButton _boton(WidgetTester t, String texto) =>
    t.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(texto).last,
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );

Future<void> _elegirPaciente(WidgetTester t) async {
  await t.enterText(_enDialogo(find.byType(TextField)).first, 'pena');
  await t.pumpAndSettle();
  await _pulsar(t, find.textContaining('PEÑA').last);
}

/// Una jeringa con dos lotes: J-1 (2, vence primero) y J-2 (10).
Future<(Lote, Lote)> _jeringas(BancoConsultorio b) async {
  final inv = b.servicio.inventario;
  final i = await inv.guardarInsumo(
    inv.nuevoInsumo().copyWith(
      nombre: 'Jeringa de prueba',
      categoria: CategoriaInsumo.dispositivo,
      unidad: 'unidad',
      registroInvima: 'INVIMA PRUEBA-0002',
    ),
  );
  final j2 = await inv.registrarEntrada(
    insumoId: i.id,
    numero: 'J-2',
    vence: DateTime(2027, 6, 30),
    cantidad: 10,
  );
  final j1 = await inv.registrarEntrada(
    insumoId: i.id,
    numero: 'J-1',
    vence: DateTime(2027, 1, 31),
    cantidad: 2,
  );
  return (j1, j2);
}

final _lineaInsumo = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('insumo-'),
);

void main() {
  testWidgets('cobrar con abono, recibo, abonar el saldo y anular', (t) async {
    final (b, id) = await _conPaciente();
    await _montar(t, b);
    expect(find.text('lunes 23/11/2026'), findsOneWidget);
    expect(find.text('Caja abierta'), findsOneWidget);
    expect(find.text('Sin recibos este día.'), findsOneWidget);
    expect(find.text('Nadie debe nada.'), findsOneWidget);

    await _pulsar(t, find.text('Cobrar'));
    expect(_enDialogo(find.text('Elige el paciente.')), findsOneWidget);
    await _elegirPaciente(t);
    // El primer servicio del catálogo y el pago en efectivo por el total.
    expect(_enDialogo(find.text('Consulta de primera vez')), findsOneWidget);
    expect(_enDialogo(find.text(r'$ 80.000')), findsWidgets);
    expect(find.text('80.000'), findsOneWidget);
    await t.enterText(_campo('Valor *'), '50000');
    await t.pumpAndSettle();
    expect(find.text('50.000'), findsOneWidget);
    expect(
      find.textContaining(r'Es un abono: queda un saldo de $ 30.000'),
      findsOneWidget,
    );
    await _pulsar(t, find.text('Registrar y descargar el recibo'));
    expect(_pdfs, ['Recibo_RC-000001.pdf']);
    expect(find.textContaining('Recibo RC-000001 descargado'), findsOneWidget);
    expect(find.text('RC-000001 · 09:30'), findsOneWidget);
    expect(find.text(r'Efectivo $ 50.000'), findsOneWidget);
    final cobro = b.servicio.caja.cobrosDe(id).single;
    expect(b.servicio.caja.saldo(cobro), 30000);

    // Saldos por cobrar → Abonar: el pago toma el saldo.
    await _pulsar(t, find.text('Abonar'));
    expect(find.text('30.000'), findsOneWidget);
    await t.tap(_enDialogo(find.byType(DropdownButtonFormField<String>)));
    await t.pumpAndSettle();
    await t.tap(find.text('Nequi').last);
    await t.pumpAndSettle();
    await t.enterText(_campo('Referencia'), 'NQ-77');
    await t.pumpAndSettle();
    await _pulsar(t, find.text('Registrar y descargar el recibo'));
    expect(_pdfs, ['Recibo_RC-000001.pdf', 'Recibo_RC-000002.pdf']);
    expect(find.text('Nadie debe nada.'), findsOneWidget);
    expect(find.text(r'Nequi $ 30.000 (ref. NQ-77)'), findsOneWidget);

    // Anular con motivo: sale de los totales y vuelve el saldo.
    await _pulsar(t, find.text('Anular RC-000002'));
    await t.enterText(_enDialogo(find.byType(TextField)), 'Pago repetido');
    await t.pumpAndSettle();
    await _pulsar(t, find.text('Anular'));
    expect(find.text('Anulado'), findsOneWidget);
    expect(find.text('Motivo: Pago repetido'), findsOneWidget);
    expect(b.servicio.caja.totales(_ahora)[MedioPago.nequi], 0);
    expect(b.servicio.caja.saldo(cobro), 30000);

    // El PDF guardado se vuelve a descargar.
    await _pulsar(t, find.text('Recibo RC-000001'));
    expect(_pdfs.last, 'Recibo_RC-000001.pdf');
  });

  testWidgets('insumos usados: se descuentan al cobrar y vuelven al anular '
      'el cobro', (t) async {
    final (b, _) = await _conPaciente();
    final (j1, j2) = await _jeringas(b);
    final inv = b.servicio.inventario;
    await _montar(t, b);
    await _pulsar(t, find.text('Cobrar'));
    await _elegirPaciente(t);
    expect(_enDialogo(find.text('INSUMOS USADOS')), findsOneWidget);
    await _pulsar(t, find.text('Agregar un insumo'));
    // El lote que vence primero, con lo que queda.
    expect(find.text('J-1 · vence 31/01/2027'), findsOneWidget);
    expect(find.text('En el lote J-1 quedan 2 unidades.'), findsOneWidget);
    final cantidad = find.descendant(
      of: _lineaInsumo,
      matching: find.byType(TextField),
    );
    await t.enterText(cantidad, '3');
    await t.pumpAndSettle();
    expect(
      find.text(
        'El lote J-1 de «Jeringa de prueba» tiene 2 unidades; el cobro usa '
        '3 unidades.',
      ),
      findsOneWidget,
    );
    expect(_boton(t, 'Registrar y descargar el recibo').onPressed, isNull);
    await t.enterText(cantidad, '2');
    await t.pumpAndSettle();
    await _pulsar(t, find.text('Registrar y descargar el recibo'));
    expect(
      find.textContaining('Se descontó 1 insumo del inventario.'),
      findsOneWidget,
    );
    expect(inv.existencia(j1.id), 0);
    expect(inv.existencia(j2.id), 10);
    expect(
      find.text('Insumos: Jeringa de prueba, 2 unidades (lote J-1)'),
      findsOneWidget,
    );

    // Anular el recibo y luego el cobro: las jeringas vuelven.
    await _pulsar(t, find.text('Anular RC-000001'));
    await t.enterText(_enDialogo(find.byType(TextField)), 'Error de prueba');
    await t.pumpAndSettle();
    await _pulsar(t, find.text('Anular'));
    await _pulsar(t, find.text('Anular el cobro'));
    expect(
      find.textContaining('Sus insumos vuelven al inventario'),
      findsOneWidget,
    );
    await t.enterText(_enDialogo(find.byType(TextField)), 'Error de prueba');
    await t.pumpAndSettle();
    await _pulsar(t, find.text('Anular'));
    expect(
      find.text('Cobro anulado: sus insumos volvieron al inventario.'),
      findsOneWidget,
    );
    expect(inv.existencia(j1.id), 2);
  });

  testWidgets('descuento con motivo y crédito de la valoración en el '
      'paquete; el paquete se usa desde la ficha', (t) async {
    final (b, id) = await _conPaciente();
    await _cobrar(b, id, 'valoracion_estetica', const [
      PagoRecibo(medio: MedioPago.transferencia, valor: 70000),
    ]);
    await _montar(t, b, ruta: '/pacientes/$id');
    await _pulsar(t, find.text('Cobrar'));
    // Cambiar el servicio al paquete: el crédito se aplica solo.
    await t.tap(_enDialogo(find.text('Consulta de primera vez')));
    await t.pumpAndSettle();
    await t.tap(find.text('Paquete de 4 sesiones').last);
    await t.pumpAndSettle();
    expect(find.text('Aplicar el crédito de la valoración'), findsOneWidget);
    expect(find.text(r'-$ 70.000'), findsOneWidget);
    expect(find.text(r'$ 810.000'), findsWidgets);
    // Un descuento sin motivo bloquea.
    await t.enterText(_campo('Descuento'), '10000');
    await t.pumpAndSettle();
    expect(
      find.textContaining('Escribe el motivo del descuento'),
      findsOneWidget,
    );
    expect(_boton(t, 'Registrar y descargar el recibo').onPressed, isNull);
    await t.enterText(_campo('Motivo del descuento *'), 'Referida');
    await t.pumpAndSettle();
    expect(find.text('800.000'), findsOneWidget);
    await _pulsar(t, find.text('Registrar y descargar el recibo'));
    expect(_pdfs, ['Recibo_RC-000002.pdf']);
    final caja = b.servicio.caja;
    final cobro = caja
        .cobrosDe(id)
        .singleWhere((c) => c.items.single.servicioId.startsWith('paquete'));
    expect(cobro.credito, 70000);
    expect(cobro.total, 800000);
    expect(caja.creditosDisponibles(id), isEmpty);

    // Sección «Caja» de la ficha: el paquete y sus sesiones.
    await _pulsar(t, find.widgetWithText(ChoiceChip, 'Caja'));
    expect(find.text('Quedan 4 de 4'), findsOneWidget);
    expect(find.text('Sin saldo pendiente'), findsOneWidget);
    await _pulsar(t, find.text('Usar una sesión'));
    await _pulsar(t, find.text('Usar la sesión'));
    expect(find.text('Quedan 3 de 4'), findsOneWidget);
    expect(
      find.textContaining('sesión 1 de 4 usada (sin recibo)'),
      findsOneWidget,
    );
    // Usar una sesión no genera recibo.
    expect(caja.recibosDePaciente(id), hasLength(2));
    expect(find.textContaining('RC-000002 · 23/11/2026'), findsOneWidget);
  });

  testWidgets('desde la cita: sugiere el servicio y la tarjeta queda '
      '«Cobrada»; el paquete se ofrece en lugar de cobrar', (t) async {
    final (b, id) = await _conPaciente();
    await b.servicio.agenda.guardar(
      b.servicio.agenda.nueva(
        tipo: TipoCita.control,
        inicio: DateTime(2026, 11, 23, 10),
        pacienteId: id,
      ),
    );
    await _montar(t, b, ruta: '/agenda');
    await _pulsar(t, find.text('Cobrar'));
    expect(_enDialogo(find.text('Control')), findsOneWidget);
    expect(find.text('45.000'), findsOneWidget);
    await _pulsar(t, find.text('Registrar y descargar el recibo'));
    expect(_pdfs, ['Recibo_RC-000001.pdf']);
    expect(find.text('Cobrada'), findsOneWidget);
    expect(
      b.servicio.caja.cobrosDe(id).single.citaId,
      b.servicio.agenda.citasDe(id).single.id,
    );

    // Con un paquete activo, el cobro ofrece usar una sesión.
    await _cobrar(b, id, 'paquete_hidrolipoclasia_4', const []);
    await _pulsar(t, find.text('Cobrar'));
    expect(find.text('Paquete de 4 sesiones: quedan 4 de 4.'), findsOneWidget);
    expect(
      find.textContaining(r'Tiene un saldo pendiente de $ 880.000'),
      findsOneWidget,
    );
    await _pulsar(t, find.text('Usar una sesión (sin cobro)'));
    await _pulsar(t, find.text('Usar la sesión'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(b.servicio.caja.paquetesDe(id).single.usadas, 1);
    expect(_pdfs, hasLength(1));
  });

  testWidgets('cierre del día: diferencia, respaldo ofrecido e inmutable', (
    t,
  ) async {
    final (b, id) = await _conPaciente();
    await _cobrar(b, id, 'control', const [
      PagoRecibo(medio: MedioPago.efectivo, valor: 45000),
    ]);
    await _cobrar(b, id, 'certificado', const [
      PagoRecibo(medio: MedioPago.daviplata, valor: 40000),
    ]);
    await _montar(t, b);
    expect(find.text(r'$ 85.000'), findsWidgets);
    await _pulsar(t, find.text('Cerrar la caja'));
    expect(find.text('Cerrar la caja de hoy'), findsOneWidget);
    expect(_boton(t, 'Cerrar la caja').onPressed, isNull);
    await t.enterText(_campo('Efectivo contado *'), '40000');
    await t.pumpAndSettle();
    expect(find.text('Falta'), findsOneWidget);
    expect(find.text(r'-$ 5.000'), findsOneWidget);
    await t.enterText(_enDialogo(_campo('Notas')), 'Faltó cambio');
    await _pulsar(t, _enDialogo(find.text('Cerrar la caja')));
    // Decisión 7: se ofrece el respaldo.
    expect(find.text('Caja cerrada'), findsOneWidget);
    expect(find.textContaining('¿Descargas ahora un respaldo'), findsOneWidget);
    await _pulsar(t, find.text('Cancelar'));
    expect(find.text('Caja cerrada a las 09:30'), findsOneWidget);
    expect(find.text('Cerrar la caja'), findsNothing);
    expect(find.text('Efectivo contado'), findsOneWidget);
    expect(find.text('Notas: Faltó cambio'), findsOneWidget);
    // Ni se anulan recibos hasta mañana.
    expect(find.text('Anular RC-000001'), findsNothing);

    // No se registran más pagos hoy.
    await _pulsar(t, find.text('Cobrar').first);
    await _elegirPaciente(t);
    expect(
      find.text('La caja de hoy ya se cerró: no se registran más pagos hoy.'),
      findsOneWidget,
    );
    expect(_boton(t, 'Registrar y descargar el recibo').onPressed, isNull);
    await _pulsar(t, find.text('Cancelar'));

    // CSV del día con el cierre.
    await _pulsar(t, find.text('CSV del día'));
    expect(_archivos.single.$1, 'Caja_2026-11-23.csv');
    expect(_archivos.single.$2.take(3), [0xEF, 0xBB, 0xBF]);
  });

  testWidgets('informe del mes: por servicio, por línea, recaudo y CSV', (
    t,
  ) async {
    final (b, id) = await _conPaciente();
    await _cobrar(b, id, 'control', const [
      PagoRecibo(medio: MedioPago.efectivo, valor: 45000),
    ]);
    await _cobrar(b, id, 'valoracion_estetica', const [
      PagoRecibo(medio: MedioPago.tarjeta, valor: 70000),
    ]);
    await _montar(t, b);
    await _pulsar(t, find.text('Informe del mes'));
    expect(find.text('Noviembre de 2026'), findsOneWidget);
    expect(
      find.text('Valoración estética (abonable al tratamiento)'),
      findsOneWidget,
    );
    expect(find.text('Estética · 1 vez'), findsOneWidget);
    expect(find.text('General · 1 vez'), findsOneWidget);
    expect(find.text(r'$ 115.000'), findsWidgets);
    expect(find.text('Sin valoraciones ni sesiones este mes.'), findsOneWidget);
    await _pulsar(t, find.text('CSV del mes'));
    expect(_archivos.single.$1, 'Informe_caja_2026-11.csv');
    await _pulsar(t, find.byTooltip('Mes anterior'));
    expect(find.text('Octubre de 2026'), findsOneWidget);
    expect(find.text('Sin cobros este mes.'), findsNWidgets(2));
  });

  testWidgets('Ajustes → Caja: cambiar una tarifa y agregar un servicio', (
    t,
  ) async {
    final (b, _) = await _conPaciente();
    await _montar(t, b, ruta: '/ajustes');
    expect(find.text('Servicios y tarifas'), findsOneWidget);
    expect(_boton(t, 'Guardar el catálogo').onPressed, isNull);
    await t.enterText(_campo('Tarifa de Control'), '50000');
    await t.pumpAndSettle();
    await _pulsar(t, find.text('Agregar un servicio'));
    await t.enterText(_campo('Nombre *'), 'Lavado de oídos');
    await t.enterText(_enDialogo(_campo('Tarifa *')), '35000');
    await t.pumpAndSettle();
    await _pulsar(t, find.text('Agregar'));
    expect(find.text('Lavado de oídos'), findsOneWidget);
    await _pulsar(t, find.text('Guardar el catálogo'));
    expect(find.text('Catálogo de la caja guardado.'), findsOneWidget);
    final caja = b.servicio.caja;
    expect(caja.serviciosPorId['control']!.tarifa, 50000);
    expect(
      caja.servicios.where((s) => s.nombre == 'Lavado de oídos').single.tarifa,
      35000,
    );
    expect(caja.servicios.length, serviciosIniciales.length + 1);
  });

  for (final ancho in [390.0, 320.0]) {
    testWidgets('$ancho px: caja, cobro y ficha sin desbordes', (t) async {
      final (b, id) = await _conPaciente();
      await _cobrar(b, id, 'paquete_hidrolipoclasia_4', const [
        PagoRecibo(
          medio: MedioPago.transferencia,
          valor: 500000,
          referencia: 'TR-123456789',
        ),
      ]);
      await b.servicio.caja.usarPaquete(
        b.servicio.caja.paquetesDe(id).single.id,
      );
      await _jeringas(b);
      await _montar(t, b, tamano: Size(ancho, 760));
      expect(find.text('RC-000001 · 09:30'), findsOneWidget);
      expect(find.text('Sesiones de paquete'), findsOneWidget);
      await _pulsar(t, find.text('Informe del mes'));
      await _pulsar(t, find.text('Día'));
      await _pulsar(t, find.text('Cobrar').first);
      await _elegirPaciente(t);
      await _pulsar(t, find.text('Agregar un insumo'));
      expect(_lineaInsumo, findsOneWidget);
      await _pulsar(t, find.text('Otro medio de pago'));
      await t.enterText(_campo('Descuento'), '5000');
      await t.pumpAndSettle();
      expect(find.text('Motivo del descuento *'), findsOneWidget);
      await _pulsar(t, find.text('Cancelar'));
      await _pulsar(t, find.text('Cerrar la caja'));
      await _pulsar(t, find.text('Cancelar'));
      final router = GoRouter.of(t.element(find.byType(Scaffold).first));
      router.go('/pacientes/$id');
      await t.pumpAndSettle();
      final chip = find.widgetWithText(ChoiceChip, 'Caja');
      await t.scrollUntilVisible(
        chip,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await _pulsar(t, chip);
      expect(find.text('Quedan 3 de 4'), findsOneWidget);
      expect(find.textContaining('Saldo pendiente'), findsOneWidget);
      // Sin desbordes (los habría lanzado como excepción).
      expect(t.takeException(), isNull);
    });
  }
}
