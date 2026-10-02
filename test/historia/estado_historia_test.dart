import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/integridad/cadena_hash.dart';
import 'package:historiasclinicas_net/core/models/historia.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/historia/estado/borrador_provider.dart';
import 'package:historiasclinicas_net/features/historia/estado/historia_controller.dart';
import 'package:historiasclinicas_net/features/historia/estado/validacion.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';

/// Simula abrir la app: un contenedor nuevo sobre el mismo almacenamiento.
Future<ProviderContainer> abrirApp() async {
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [preferenciasProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  // Mantiene vivo el autoguardado durante la prueba.
  c.listen(historiaProvider, (_, _) {}, fireImmediately: true);
  c.listen(borradorProvider, (_, _) {}, fireImmediately: true);
  return c;
}

Future<void> esperarAutoguardado() => Future<void>.delayed(
  BorradorController.espera + const Duration(milliseconds: 150),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({Claves.pais: 'CO'}));

  test('una historia vacía no genera borrador', () async {
    final c = await abrirApp();
    c.read(historiaProvider.notifier).limpiar();
    await esperarAutoguardado();
    expect(c.read(borradorStoreProvider).leer(), isNull);
    expect(c.read(borradorProvider).guardadoEn, isNull);
  });

  test('autoguarda el borrador y lo recupera al volver a abrir', () async {
    final c = await abrirApp();
    c.read(historiaProvider.notifier).actualizar((_) => historiaCompleta());
    await esperarAutoguardado();
    expect(c.read(borradorProvider).guardadoEn, isNotNull);

    final otra = await abrirApp();
    final estado = otra.read(historiaProvider);
    expect(estado.borradorRestauradoEn, isNotNull);
    expect(estado.abierta, isFalse);
    expect(estado.historia.paciente.nombreCompleto, 'PEÑA MUÑOZ, José Ángel');
    expect(estado.historia.signos.peso, 64.5);
  });

  test('finalizar sella la historia, la abre y borra el borrador', () async {
    final c = await abrirApp();
    final ctrl = c.read(historiaProvider.notifier)
      ..actualizar((_) => historiaCompleta());
    await esperarAutoguardado();

    final guardado = ctrl.prepararGuardado(ahora: DateTime(2026, 10, 2, 9, 40));
    expect(guardado.revision, 1);
    expect(guardado.datos['finalizadaEn'], '2026-10-02T09:40');
    expect(verificarIntegridad(guardado.datos).correcta, isTrue);

    ctrl.guardado(guardado, nombreArchivo: 'Historia_PENA_1032456789.pdf');
    final estado = c.read(historiaProvider);
    expect(estado.abierta, isTrue);
    expect(estado.revision, 1);
    expect(estado.integridad!.correcta, isTrue);
    expect(estado.hayCambiosSinGuardar, isFalse);

    await esperarAutoguardado();
    expect(c.read(borradorStoreProvider).leer(), isNull);
  });

  test('en una historia abierta solo se agregan evoluciones', () async {
    final c = await abrirApp();
    final ctrl = c.read(historiaProvider.notifier);
    ctrl.abrir(sellarBase(historiaCompleta().aMapa()), revision: 1);

    ctrl.actualizar((h) => h.copyWith(motivoConsulta: 'Cambiado'));
    expect(
      c.read(historiaProvider).historia.motivoConsulta,
      'Dolor de garganta',
    );

    ctrl
      ..agregarEvolucion(ahora: DateTime(2026, 10, 9, 10, 30))
      ..agregarEvolucion(ahora: DateTime(2026, 10, 9, 10, 31));
    ctrl.actualizarEvolucion(
      0,
      c.read(historiaProvider).evolucionesNuevas[0].copyWith(texto: 'Mejoría.'),
    );
    ctrl.descartarEvolucion(1);
    expect(c.read(historiaProvider).evolucionesNuevas.single.texto, 'Mejoría.');

    final v2 = ctrl.prepararGuardado();
    expect(v2.revision, 2);
    final r = verificarIntegridad(v2.datos);
    expect(r.correcta, isTrue);
    expect(r.sellos, 2);
  });

  test(
    'el borrador de una historia abierta conserva las evoluciones nuevas',
    () async {
      final c = await abrirApp();
      c.read(historiaProvider.notifier)
        ..abrir(
          sellarBase(historiaCompleta().aMapa()),
          revision: 3,
          nombreArchivo: 'Historia_PENA_1032456789_v3.pdf',
        )
        ..agregarEvolucion(ahora: DateTime(2026, 10, 9, 10, 30));
      final e = c.read(historiaProvider).evolucionesNuevas.single;
      c
          .read(historiaProvider.notifier)
          .actualizarEvolucion(0, e.copyWith(texto: 'Afebril.'));
      await esperarAutoguardado();

      final otra = await abrirApp();
      final estado = otra.read(historiaProvider);
      expect(estado.abierta, isTrue);
      expect(estado.revision, 3);
      expect(estado.nombreArchivo, 'Historia_PENA_1032456789_v3.pdf');
      expect(estado.evolucionesNuevas.single.texto, 'Afebril.');
      expect(estado.integridad!.correcta, isTrue);
    },
  );

  test(
    'una historia alterada se marca y la nueva evolución lo registra',
    () async {
      final c = await abrirApp();
      final datos = sellarBase(historiaCompleta().aMapa());
      final alterados = {
        ...datos,
        'motivo': {'motivoConsulta': 'Otro motivo'},
      };
      final ctrl = c.read(historiaProvider.notifier)
        ..abrir(alterados, revision: 1);

      expect(c.read(historiaProvider).integridadComprometida, isTrue);
      ctrl.agregarEvolucion();
      expect(
        c.read(historiaProvider).evolucionesNuevas.single.avisoIntegridad,
        contains('historia inicial'),
      );
    },
  );

  test('con el borrador desactivado no se guarda nada', () async {
    final c = await abrirApp();
    c.read(historiaProvider.notifier).actualizar((_) => historiaCompleta());
    await esperarAutoguardado();
    expect(c.read(borradorStoreProvider).leer(), isNotNull);

    await c.read(borradorProvider.notifier).cambiarDesactivado(true);
    expect(c.read(borradorStoreProvider).leer(), isNull);
    c
        .read(historiaProvider.notifier)
        .actualizar((h) => h.copyWith(motivoConsulta: 'Otro'));
    await esperarAutoguardado();
    expect(c.read(borradorStoreProvider).leer(), isNull);
  });

  test('cambiar de país ajusta el tipo de documento', () async {
    final c = await abrirApp();
    expect(c.read(historiaProvider).historia.paciente.tipoDocumento, 'CC');
    c.read(historiaProvider.notifier).cambiarPais(Pais.espana);
    final h = c.read(historiaProvider).historia;
    expect(h.pais, Pais.espana);
    expect(h.paciente.tipoDocumento, 'DNI');
  });

  group('Validación para finalizar', () {
    test('una historia vacía lista lo que falta', () {
      final h = HistoriaClinica.nueva(pais: Pais.colombia);
      final campos = pendientesParaFinalizar(h).map((p) => p.campo).toList();
      expect(
        campos,
        containsAll([
          'Primer apellido',
          'Nombres',
          'Número de documento',
          'Fecha de nacimiento (o edad aproximada)',
          'Sexo',
          'Motivo de consulta',
          'Enfermedad actual',
          'Alergias (o marcar "Niega alergias")',
          'Al menos un diagnóstico',
        ]),
      );
      expect(avanceSeccion(SeccionHistoria.paciente, h), Avance.vacia);
    });

    test('una historia completa se puede finalizar', () {
      final h = historiaCompleta();
      expect(pendientesParaFinalizar(h), isEmpty);
      expect(avanceSeccion(SeccionHistoria.paciente, h), Avance.completa);
      expect(avanceSeccion(SeccionHistoria.signos, h), Avance.completa);
    });

    test('un signo vital imposible bloquea; uno fuera de lo habitual no', () {
      final h = historiaCompleta();
      final imposible = h.copyWith(signos: h.signos.copyWith(fc: 780));
      expect(
        pendientesParaFinalizar(imposible).single.campo,
        'FC: valor no plausible',
      );
      expect(avanceSeccion(SeccionHistoria.signos, imposible), Avance.parcial);
      final taquicardia = h.copyWith(signos: h.signos.copyWith(fc: 130));
      expect(pendientesParaFinalizar(taquicardia), isEmpty);
    });

    test('"Niega alergias" cuenta como dato registrado', () {
      final h = historiaCompleta();
      final niega = h.copyWith(
        antecedentes: h.antecedentes.copyWith(
          alergias: [],
          niegaAlergias: true,
        ),
      );
      expect(pendientesParaFinalizar(niega), isEmpty);
    });
  });
}
