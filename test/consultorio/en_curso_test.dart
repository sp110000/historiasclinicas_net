import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/almacen/almacen.dart';
import 'package:historiasclinicas_net/core/receta/receta.dart';
import 'package:historiasclinicas_net/core/storage/borrador_store.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/core/storage/receta_store.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/integracion/en_curso_cifrado.dart';
import 'package:historiasclinicas_net/features/historia/estado/borrador_provider.dart';
import 'package:historiasclinicas_net/features/historia/estado/historia_controller.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayudas_consultorio.dart';

bool _hayRegistro(BancoConsultorio b, String id) =>
    b.almacen.datos[Deposito.registros]!.containsKey('$coleccionEnCurso/$id');

void main() {
  group('EnCursoCifrado', () {
    late BancoConsultorio b;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
    });

    test('bloqueado queda en memoria; al abrir se cifra', () async {
      await b.servicio.bloquear();
      final e = EnCursoCifrado(b.servicio, prefs);
      await e.guardarBorrador({'motivo': 'Cefalea pulsátil'});
      await e.guardarReceta(
        Receta(id: 'r1', historiaId: 'h1', fecha: DateTime(2026, 11, 21)),
      );
      expect(e.borrador!.contenido['motivo'], 'Cefalea pulsátil');
      expect(_hayRegistro(b, 'borrador'), isFalse);
      expect(prefs.getString(Claves.borrador), isNull);
      expect(prefs.getString(Claves.receta), isNull);

      await b.servicio.desbloquear(fraseDePrueba);
      expect(await e.alAbrir(), isFalse, reason: 'ya estaba en memoria');
      await b.servicio.repositorio.esperarEscrituras();
      expect(_hayRegistro(b, 'borrador'), isTrue);
      expect(_hayRegistro(b, 'receta'), isTrue);
      expect(contieneTexto(b.todosLosBytes, 'Cefalea'), isFalse);

      // Abierto, cada guardado va directo al almacén cifrado.
      await e.guardarBorrador({'motivo': 'Otra cosa'});
      final m = await b.servicio.repositorio.leer(coleccionEnCurso, 'borrador');
      expect((m!['contenido']! as Map)['motivo'], 'Otra cosa');
    });

    test(
      'lo que había en claro se usa al iniciar y se cifra al abrir',
      () async {
        SharedPreferences.setMockInitialValues({
          Claves.borrador: jsonEncode({
            'guardadoEn': '2026-11-20T10:00:00.000',
            'contenido': {'motivo': 'De antes'},
          }),
        });
        prefs = await SharedPreferences.getInstance();
        final e = EnCursoCifrado(b.servicio, prefs);
        expect(e.borrador!.contenido['motivo'], 'De antes');
        await e.alAbrir();
        await b.servicio.repositorio.esperarEscrituras();
        expect(prefs.containsKey(Claves.borrador), isFalse);
        expect(_hayRegistro(b, 'borrador'), isTrue);
      },
    );

    test('al recargar, el borrador cifrado vuelve al abrir', () async {
      await EnCursoCifrado(b.servicio, prefs).guardarBorrador({'motivo': 'x'});
      await b.servicio.bloquear();
      final recargada = EnCursoCifrado(b.servicio, prefs);
      expect(recargada.borrador, isNull, reason: 'bloqueado: no se lee');
      await b.servicio.desbloquear(fraseDePrueba);
      expect(await recargada.alAbrir(), isTrue);
      expect(recargada.borrador!.contenido, {'motivo': 'x'});
    });

    test('borrar con el consultorio bloqueado lo borra al abrir', () async {
      final e = EnCursoCifrado(b.servicio, prefs);
      await e.guardarBorrador({'motivo': 'x'});
      await b.servicio.repositorio.esperarEscrituras();
      expect(_hayRegistro(b, 'borrador'), isTrue);
      await b.servicio.bloquear();
      await e.borrarTodo();
      await b.servicio.desbloquear(fraseDePrueba);
      await e.alAbrir();
      await b.servicio.repositorio.esperarEscrituras();
      expect(_hayRegistro(b, 'borrador'), isFalse);
      expect(e.borrador, isNull);
    });
  });

  group('Sin consultorio creado en este navegador (sitio público)', () {
    late BancoConsultorio b;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      b = BancoConsultorio();
    });

    test(
      'guarda en claro, como sin la bandera, y vuelve al recargar',
      () async {
        final e = EnCursoCifrado(b.servicio, prefs);
        await e.guardarBorrador({'motivo': 'Cefalea'});
        await e.guardarReceta(
          Receta(id: 'r1', historiaId: 'h1', fecha: DateTime(2026, 11, 21)),
        );
        // El mismo formato que lee el sitio sin la bandera.
        expect(BorradorStore(prefs).leer()!.contenido['motivo'], 'Cefalea');
        expect(RecetaStore(prefs).leer()!.id, 'r1');
        expect(b.almacen.datos[Deposito.registros], isEmpty);

        final recargada = EnCursoCifrado(b.servicio, prefs);
        expect(recargada.borrador!.contenido['motivo'], 'Cefalea');
        expect(recargada.receta!.id, 'r1');

        await recargada.borrarReceta();
        expect(prefs.containsKey(Claves.receta), isFalse);
        expect(prefs.containsKey(Claves.borrador), isTrue);
        await recargada.borrarTodo();
        expect(prefs.containsKey(Claves.borrador), isFalse);
      },
    );

    test(
      'al crear el consultorio se cifra y se borra lo que estaba en claro',
      () async {
        final e = EnCursoCifrado(b.servicio, prefs);
        await e.guardarBorrador({'motivo': 'Dolor torácico'});
        expect(prefs.containsKey(Claves.borrador), isTrue);
        await b.servicio.crear(fraseDePrueba);
        await e.alAbrir();
        await b.servicio.repositorio.esperarEscrituras();
        expect(prefs.containsKey(Claves.borrador), isFalse);
        expect(_hayRegistro(b, 'borrador'), isTrue);
        expect(contieneTexto(b.todosLosBytes, 'torácico'), isFalse);

        // Creado y bloqueado: ya no vuelve a quedar en claro.
        await b.servicio.bloquear();
        await e.guardarBorrador({'motivo': 'Otra'});
        expect(prefs.containsKey(Claves.borrador), isFalse);
      },
    );
  });

  test('la historia escrita vuelve tras recargar y desbloquear', () async {
    SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
    final prefs = await SharedPreferences.getInstance();
    final b = BancoConsultorio();
    await b.servicio.crear(fraseDePrueba);

    ProviderContainer app() {
      final c = ProviderContainer(
        overrides: [
          preferenciasProvider.overrideWithValue(prefs),
          servicioConsultorioProvider.overrideWithValue(b.servicio),
          // Lo que la bandera elige en los providers.
          borradorStoreProvider.overrideWith(crearBorradorStoreConsultorio),
          recetaStoreProvider.overrideWith(crearRecetaStoreConsultorio),
        ],
      );
      addTearDown(c.dispose);
      c.listen(historiaProvider, (_, _) {}, fireImmediately: true);
      c.listen(borradorProvider, (_, _) {}, fireImmediately: true);
      return c;
    }

    final primera = app();
    primera
        .read(historiaProvider.notifier)
        .actualizar((h) => h.copyWith(motivoConsulta: 'Dolor lumbar'));
    await Future<void>.delayed(
      BorradorController.espera + const Duration(milliseconds: 150),
    );
    await b.servicio.repositorio.esperarEscrituras();
    expect(prefs.getString(Claves.borrador), isNull, reason: 'nada en claro');
    expect(contieneTexto(b.todosLosBytes, 'lumbar'), isFalse);

    await b.servicio.bloquear();
    final segunda = app();
    expect(segunda.read(historiaProvider).historia.motivoConsulta, isEmpty);
    await segunda.read(consultorioProvider.notifier).desbloquear(fraseDePrueba);
    final e = segunda.read(historiaProvider);
    expect(e.historia.motivoConsulta, 'Dolor lumbar');
    expect(e.borradorRestauradoEn, isNotNull);
  });
}
