import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/app.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/historia/estado/borrador_provider.dart';
import 'package:historiasclinicas_net/features/historia/estado/historia_controller.dart';
import 'package:historiasclinicas_net/features/pwa/avisos_pwa.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';

void main() {
  testWidgets('avisos: lista sin conexión y versión nueva con "Actualizar"', (
    t,
  ) async {
    t.view
      ..physicalSize = const Size(1920, 1200)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
    final prefs = await SharedPreferences.getInstance();
    final avisos = StreamController<AvisoPwa>();
    var recargas = 0;
    final c = ProviderContainer(
      overrides: [
        preferenciasProvider.overrideWithValue(prefs),
        avisosPwaProvider.overrideWithValue(avisos.stream),
        recargarAppProvider.overrideWithValue(() async => recargas++),
      ],
    );
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const HistoriasClinicasApp(),
      ),
    );
    await t.pumpAndSettle();

    avisos.add(AvisoPwa.listaSinConexion);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('ya funciona sin conexión'), findsOneWidget);

    avisos.add(AvisoPwa.versionNueva);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('Hay una versión nueva'), findsOneWidget);
    await t.tap(find.text('Actualizar'));
    await t.pump();
    expect(recargas, 1);
    await avisos.close();
    await t.pumpAndSettle(const Duration(seconds: 10));
  });

  test('antes de recargar se guarda el borrador pendiente', () async {
    SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [preferenciasProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    c
      ..listen(historiaProvider, (_, _) {}, fireImmediately: true)
      ..listen(borradorProvider, (_, _) {}, fireImmediately: true);
    c.read(historiaProvider.notifier).actualizar((_) => historiaCompleta());
    // Sin esperar los 700 ms del autoguardado.
    expect(c.read(borradorStoreProvider).leer(), isNull);
    await c.read(recargarAppProvider)();
    expect(
      jsonEncode(c.read(borradorStoreProvider).leer()?.contenido),
      contains('José Ángel'),
    );
  });
}
