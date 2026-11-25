import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/agenda/cita.dart';
import 'package:historiasclinicas_net/core/consultorio/caja/catalogo.dart';
import 'package:historiasclinicas_net/core/consultorio/caja/movimientos.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/medicion.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/presentacion_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/consultorio/widgets/texto_normativo.dart';
import 'package:historiasclinicas_net/features/medico/medico_provider.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';
import 'ayudas_procedimientos.dart';

// Martes 08/12/2026, festivo (Inmaculada Concepción).
final _ahora = DateTime(2026, 12, 8, 9, 30);

const _notaInterna = 'Nota interna de prueba';
const _motivo = 'Motivo interno de prueba';

Future<ProviderContainer> _montar(
  WidgetTester t,
  BancoConsultorio b,
  String ruta, {
  bool presentacion = false,
  Size tamano = const Size(1440, 1200),
}) async {
  t.view
    ..physicalSize = tamano
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: <Override>[
      preferenciasProvider.overrideWithValue(prefs),
      rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
      servicioConsultorioProvider.overrideWithValue(b.servicio),
    ],
  );
  addTearDown(c.dispose);
  c.read(medicoProvider.notifier).actualizar((_) => medicoCompleto());
  c.read(modoPresentacionProvider.notifier).cambiar(presentacion);
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
  return c;
}

/// Un paciente con todo: nota interna, cita con motivo y saldo, peso,
/// procedimiento aprobado, valoración y consentimiento.
Future<(BancoConsultorio, String)> _preparar() async {
  final b = BancoConsultorio(ahora: _ahora);
  await b.servicio.crear(fraseDePrueba);
  final r = await b.servicio.registrarHistoria(
    HistoriaPendiente(
      datos: historiaSintetica(),
      revision: 1,
      origen: OrigenArchivo.importado,
    ),
  );
  final id = r!.pacienteId;
  final indice = b.servicio.indice;
  await indice.guardarFicha(indice.ficha(id)!.copyWith(notas: _notaInterna));
  await b.servicio.seguimiento.guardarMedicion(
    Medicion(id: '', pacienteId: id, fecha: _ahora, creado: _ahora, peso: 64),
  );
  await aprobarHidrolipoclasia(b);
  await valorarAptoDePrueba(b, id);
  await consentimientoDePrueba(b, id);
  final cita = await b.servicio.agenda.guardar(
    b.servicio.agenda
        .nueva(
          tipo: TipoCita.control,
          inicio: DateTime(2026, 12, 8, 10),
          pacienteId: id,
        )
        .copyWith(motivo: _motivo),
  );
  final s = b.servicio.caja.serviciosPorId['control']!;
  await b.servicio.caja.cobrar(
    pacienteId: id,
    citaId: cita.id,
    items: [
      ItemCobro(
        servicioId: s.id,
        descripcion: s.nombre,
        valorUnitario: s.tarifa,
      ),
    ],
    pagos: const [PagoRecibo(medio: MedioPago.efectivo, valor: 20000)],
    medico: medicoCompleto(),
    pais: Pais.colombia,
  );
  return (b, id);
}

Future<void> _pulsar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void _sinNotas(String donde) {
  expect(
    find.textContaining('VERIFICAR', findRichText: true),
    findsNothing,
    reason: donde,
  );
  expect(find.byType(ChipVerificar), findsNothing, reason: donde);
  expect(find.textContaining(_notaInterna), findsNothing, reason: donde);
  expect(find.textContaining(_motivo), findsNothing, reason: donde);
}

double _contraste(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

Color _sobre(Color c, double alfa, Color fondo) =>
    Color.alphaBlend(c.withValues(alpha: alfa), fondo);

void main() {
  test('contraste de lo nuevo (≥ 4,5:1)', () {
    // Los chips («Por verificar», «Verificado…», «Vigente», «Caja
    // abierta»): el texto del color sobre su tinte del 6 % en blanco, opaco
    // en cualquier pantalla (también sobre el fondo gris).
    for (final c in [
      ColoresMarca.aviso,
      ColoresMarca.estadoOk,
      ColoresMarca.error,
      ColoresMarca.textoSuave,
      ColoresMarca.primario,
    ]) {
      expect(
        _contraste(c, _sobre(c, 0.06, Colors.white)),
        greaterThanOrEqualTo(4.5),
        reason: '$c',
      );
    }
    // Sin el fondo opaco, el verde sobre el gris no llegaba.
    expect(
      _contraste(
        ColoresMarca.estadoOk,
        _sobre(ColoresMarca.estadoOk, 0.06, ColoresMarca.fondo),
      ),
      lessThan(4.5),
    );
    // La franja del modo presentación y los textos sobre el fondo gris.
    expect(
      _contraste(ColoresMarca.primario, ColoresMarca.tinte),
      greaterThanOrEqualTo(4.5),
    );
    for (final c in [
      ColoresMarca.aviso,
      ColoresMarca.error,
      ColoresMarca.textoSuave,
      ColoresMarca.estadoOk,
    ]) {
      expect(
        _contraste(c, ColoresMarca.fondo),
        greaterThanOrEqualTo(4.5),
        reason: '$c sobre el fondo',
      );
    }
  });

  final rutas = <(String, String Function(String))>[
    ('agenda', (_) => '/agenda'),
    ('pacientes', (_) => '/pacientes'),
    ('ficha', (id) => '/pacientes/$id'),
    ('caja', (_) => '/caja'),
    ('inventario', (_) => '/inventario'),
    ('ajustes', (_) => '/ajustes'),
    ('procedimientos', (_) => '/procedimientos'),
    ('sesión', (id) => '/pacientes/$id/sesion/hidrolipoclasia'),
    ('valoración', (id) => '/pacientes/$id/valoracion/hidrolipoclasia'),
    ('certificado', (id) => '/pacientes/$id/documento/certificado'),
    ('incapacidad', (id) => '/pacientes/$id/documento/incapacidad'),
    ('protocolo', (_) => '/procedimientos/hidrolipoclasia'),
  ];

  testWidgets('sin el modo presentación: chips «Por verificar» en lugar de '
      'la marca', (t) async {
    final (b, id) = await _preparar();
    await _montar(t, b, '/agenda');
    // El festivo del día y la cita con su motivo y su saldo.
    expect(
      find.textContaining('Festivo: Inmaculada Concepción', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(ChipVerificar), findsWidgets);
    expect(find.textContaining(_motivo), findsOneWidget);
    expect(find.text(r'Saldo $ 25.000'), findsOneWidget);
    await _montar(t, b, '/ajustes');
    expect(find.byType(ChipVerificar), findsWidgets);
    // Los textos con chip ya no llevan la marca.
    for (final e in find.byType(TextoNormativo).evaluate()) {
      final w = e.widget as TextoNormativo;
      if (!w.texto.contains('VERIFICAR')) continue;
      expect(
        find.descendant(
          of: find.byWidget(w),
          matching: find.textContaining('VERIFICAR', findRichText: true),
        ),
        findsNothing,
      );
    }
    await _montar(t, b, '/pacientes/$id');
    expect(find.textContaining(_notaInterna), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Caja'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('modo presentación: ningún «VERIFICAR» ni chip, sin notas '
      'internas, motivo ni montos, en cada pantalla', (t) async {
    final (b, id) = await _preparar();
    // Con una nota verificada (Ajustes → Verificaciones la lista).
    await b.servicio.verificaciones.marcar(
      'Festivo: Inmaculada Concepción (VERIFICAR)',
      fecha: DateTime(2026, 12, 8),
      fuente: 'Ley 51 de 1983',
    );
    for (final (nombre, ruta) in rutas) {
      await _montar(t, b, ruta(id), presentacion: true);
      expect(
        find.text(
          'Modo presentación: sin notas por verificar, notas internas ni '
          'montos de la caja.',
        ),
        findsOneWidget,
        reason: nombre,
      );
      _sinNotas(nombre);
    }
    // La agenda: el festivo sin la marca, la cita sin el saldo.
    await _montar(t, b, '/agenda', presentacion: true);
    expect(
      find.textContaining('Festivo: Inmaculada Concepción ·'),
      findsOneWidget,
    );
    expect(find.textContaining(r'Saldo $'), findsNothing);
    expect(find.text('Cobrada'), findsNothing);
    // La ficha: sin la sección Caja; cada sección, sin notas.
    await _montar(t, b, '/pacientes/$id', presentacion: true);
    expect(find.widgetWithText(ChoiceChip, 'Caja'), findsNothing);
    for (final s in ['Seguimiento', 'Peso', 'Estética', 'Fotos']) {
      await _pulsar(t, find.widgetWithText(ChoiceChip, s).first);
      _sinNotas('ficha · $s');
    }
    // La caja: el informe del mes también.
    await _montar(t, b, '/caja', presentacion: true);
    await _pulsar(t, find.text('Informe del mes'));
    _sinNotas('caja · informe');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('el interruptor del riel, la franja con «Salir» y se apaga al '
      'bloquear', (t) async {
    final (b, id) = await _preparar();
    final c = await _montar(t, b, '/pacientes/$id');
    expect(find.textContaining(_notaInterna), findsOneWidget);
    await _pulsar(t, find.byTooltip('Modo presentación'));
    expect(c.read(modoPresentacionProvider), isTrue);
    expect(find.textContaining(_notaInterna), findsNothing);
    expect(find.byTooltip('Salir del modo presentación'), findsOneWidget);
    await _pulsar(t, find.text('Salir'));
    expect(c.read(modoPresentacionProvider), isFalse);
    expect(find.textContaining(_notaInterna), findsOneWidget);
    await _pulsar(t, find.byTooltip('Modo presentación'));
    await _pulsar(t, find.byTooltip('Bloquear el consultorio'));
    expect(c.read(modoPresentacionProvider), isFalse);
    expect(find.byTooltip('Modo presentación'), findsNothing);
    await t.pump(const Duration(seconds: 5));
  });

  for (final ancho in [390.0, 320.0]) {
    testWidgets('$ancho px: cada pantalla sin desbordes (también en el modo '
        'presentación)', (t) async {
      final (b, id) = await _preparar();
      for (final presentacion in [false, true]) {
        for (final (nombre, ruta) in rutas) {
          await _montar(
            t,
            b,
            ruta(id),
            presentacion: presentacion,
            tamano: Size(ancho, 760),
          );
          expect(t.takeException(), isNull, reason: '$nombre a $ancho px');
        }
      }
      // El menú lateral con el interruptor y el nombre del consultorio.
      await _montar(t, b, '/agenda', tamano: Size(ancho, 760));
      expect(find.text('Consultorio Salud Plena'), findsOneWidget);
      expect(find.byTooltip('Modo presentación'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });
  }
}
