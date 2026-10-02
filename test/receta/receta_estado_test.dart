import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/integridad/cadena_hash.dart';
import 'package:historiasclinicas_net/core/receta/receta.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/historia/estado/borrador_provider.dart';
import 'package:historiasclinicas_net/features/historia/estado/historia_controller.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';

Future<ProviderContainer> abrirApp() async {
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [preferenciasProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  c.listen(recetaProvider, (_, _) {}, fireImmediately: true);
  return c;
}

Future<void> esperarGuardado() => Future<void>.delayed(
  RecetaController.espera + const Duration(milliseconds: 100),
);

List<String> nombres(ProviderContainer c) => [
  for (final i in c.read(recetaProvider).items) i.medicamento,
];

/// Crea [n] ítems con nombre ("A", "B", …) en una receta nueva.
void conItems(ProviderContainer c, List<String> meds) {
  final ctrl = c.read(recetaProvider.notifier);
  for (var k = 1; k < meds.length; k++) {
    ctrl.agregarItem();
  }
  for (final (k, item) in c.read(recetaProvider).items.indexed) {
    ctrl.actualizarItem(item.id, (i) => i.copyWith(medicamento: meds[k]));
  }
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      Claves.pais: 'CO',
      Claves.medico: jsonEncode(medicoEjemplo().aAlmacen()),
    }),
  );

  test('empieza con un ítem vacío y la firma según la historia', () async {
    final c = await abrirApp();
    final r = c.read(recetaProvider);
    expect(r.items, hasLength(1));
    expect(r.items.single.vacio, isTrue);
    expect(r.historiaId, c.read(historiaProvider).historia.id);
    expect(r.incluirFirma, isTrue);
  });

  test('la numeración sigue al agregar, quitar y reordenar', () async {
    final c = await abrirApp();
    final ctrl = c.read(recetaProvider.notifier);
    conItems(c, ['A', 'B', 'C', 'D']);
    ctrl.bajar(c.read(recetaProvider).items.first.id);
    expect(nombres(c), ['B', 'A', 'C', 'D']);
    ctrl.subir(c.read(recetaProvider).items.last.id);
    expect(nombres(c), ['B', 'A', 'D', 'C']);
    ctrl.reordenar(0, 4); // arrastrar el primero al final
    expect(nombres(c), ['A', 'D', 'C', 'B']);
    ctrl.reordenar(3, 0); // y el último al principio
    expect(nombres(c), ['B', 'A', 'D', 'C']);
    final quitado = c.read(recetaProvider).items[1];
    ctrl.eliminarItem(quitado.id);
    expect(nombres(c), ['B', 'D', 'C']);
    ctrl.insertarItem(1, quitado); // "Deshacer"
    expect(nombres(c), ['B', 'A', 'D', 'C']);
    // Los extremos no se mueven fuera de la lista.
    ctrl.subir(c.read(recetaProvider).items.first.id);
    ctrl.bajar(c.read(recetaProvider).items.last.id);
    expect(nombres(c), ['B', 'A', 'D', 'C']);
  });

  test('se guarda sola y se recupera al volver a abrir', () async {
    final c = await abrirApp();
    // La historia también se guarda (borrador): al volver es la misma.
    c
      ..listen(historiaProvider, (_, _) {}, fireImmediately: true)
      ..listen(borradorProvider, (_, _) {}, fireImmediately: true);
    c.read(historiaProvider.notifier).actualizar((_) => historiaCompleta());
    conItems(c, ['Amoxicilina']);
    c.read(recetaProvider.notifier).ajustarPaciente('edad', '36 años');
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final otra = await abrirApp();
    expect(nombres(otra), ['Amoxicilina']);
    expect(otra.read(pacienteRecetaProvider).edad, '36 años');
  });

  test(
    'borrar el borrador o desactivarlo también vale para la receta',
    () async {
      final c = await abrirApp();
      conItems(c, ['Amoxicilina']);
      await esperarGuardado();
      expect(c.read(recetaStoreProvider).leer(), isNotNull);
      await c.read(borradorProvider.notifier).borrar();
      expect(c.read(recetaStoreProvider).leer(), isNull);
      expect(nombres(c), ['Amoxicilina'], reason: 'sigue en pantalla');

      await c.read(borradorProvider.notifier).cambiarDesactivado(true);
      conItems(c, ['Loratadina']);
      await esperarGuardado();
      expect(c.read(recetaStoreProvider).leer(), isNull);
    },
  );

  test('otra historia empieza otra receta', () async {
    final c = await abrirApp();
    conItems(c, ['Amoxicilina']);
    c.read(historiaProvider.notifier).limpiar();
    expect(c.read(recetaProvider).items.single.vacio, isTrue);
  });

  test('paciente precargado, corrección y restablecer', () async {
    final c = await abrirApp();
    c.read(historiaProvider.notifier).actualizar((_) => historiaCompleta());
    expect(c.read(pacienteRecetaProvider).nombre, 'PEÑA MUÑOZ, José Ángel');
    final ctrl = c.read(recetaProvider.notifier)
      ..ajustarPaciente('alergias', 'Sulfas');
    expect(c.read(alergiasRecetaProvider), ['Sulfas']);
    ctrl.restablecerPaciente();
    expect(c.read(alergiasRecetaProvider), ['Penicilina', 'AINEs']);
  });

  test('alertas y control especial según los medicamentos', () async {
    final c = await abrirApp();
    c.read(historiaProvider.notifier).actualizar((_) => historiaCompleta());
    conItems(c, ['Ibuprofeno', 'Loratadina', 'Clonazepam']);
    final alertas = c.read(alertasAlergiaProvider);
    expect(alertas.single.numeroItem, 1);
    expect(alertas.single.motivo, contains('AINE'));
    expect(c.read(avisosControlProvider).single.numeroItem, 3);
    c.read(recetaProvider.notifier).marcarAlertaVista(alertas.single.clave);
    expect(c.read(recetaProvider).alertasVistas, {alertas.single.clave});
  });

  test('numeración R-000001 activable y continuable', () async {
    final c = await abrirApp();
    final ctrl = c.read(recetaProvider.notifier);
    await ctrl.prepararParaImprimir();
    expect(c.read(recetaProvider).numero, isNull, reason: 'desactivada');

    await c.read(opcionesRecetaProvider.notifier).cambiarNumerar(true);
    expect(c.read(opcionesRecetaProvider).proximoNumero, 'R-000001');
    expect(
      c.read(documentoRecetaProvider).receta.numero,
      'R-000001',
      reason: 'la vista previa ya muestra el número',
    );
    expect(c.read(recetaProvider).numero, isNull, reason: 'aún sin asignar');
    await ctrl.prepararParaImprimir();
    expect(c.read(recetaProvider).numero, 'R-000001');
    await ctrl.prepararParaImprimir();
    expect(c.read(recetaProvider).numero, 'R-000001', reason: 'reimprimir');
    expect(c.read(opcionesRecetaProvider).proximoNumero, 'R-000002');

    ctrl.nueva();
    await c.read(opcionesRecetaProvider.notifier).continuarDesde(122);
    await ctrl.prepararParaImprimir();
    expect(c.read(recetaProvider).numero, 'R-000123');
  });

  test('documento: médico, firma según el interruptor y título', () async {
    final c = await abrirApp();
    var d = c.read(documentoRecetaProvider);
    expect(d.medico!.nombre, 'Dra. Ana Pérez Gómez');
    expect(d.medico!.firma, isNotNull);
    expect(d.recursos, hasLength(3));
    c
        .read(recetaProvider.notifier)
        .actualizar((r) => r.copyWith(incluirFirma: false));
    await c
        .read(opcionesRecetaProvider.notifier)
        .cambiarTitulo('Fórmula médica');
    d = c.read(documentoRecetaProvider);
    expect(d.medico!.firma, isNull);
    expect(d.recursos, hasLength(2));
    expect(d.titulo, 'Fórmula médica');
  });

  group('Registrar en la historia', () {
    const texto = 'Se formuló el 02/10/2026:\n1. AMOXICILINA 500 mg';

    test('historia nueva: al final del plan terapéutico', () async {
      final c = await abrirApp();
      final h = c.read(historiaProvider.notifier)
        ..actualizar((_) => historiaCompleta());
      final version = c.read(historiaProvider).versionFormulario;
      expect(h.registrarReceta(texto), 'el plan de tratamiento');
      final estado = c.read(historiaProvider);
      expect(
        estado.historia.plan.planTerapeutico,
        'Manejo sintomático.\n\n$texto',
      );
      expect(estado.versionFormulario, version + 1, reason: 'se ve al volver');
    });

    test('historia abierta: en la evolución en curso (o una nueva)', () async {
      final c = await abrirApp();
      final h = c.read(historiaProvider.notifier)
        ..abrir(sellarBase(historiaCompleta().aMapa()), revision: 1);
      expect(h.registrarReceta(texto), 'la evolución en curso');
      expect(c.read(historiaProvider).evolucionesNuevas.single.texto, texto);
      h.registrarReceta('Otra');
      expect(
        c.read(historiaProvider).evolucionesNuevas.single.texto,
        '$texto\n\nOtra',
      );
    });

    test('el texto lleva número, medicamentos e indicaciones', () async {
      final r = Receta(
        id: 'r',
        historiaId: 'h',
        fecha: DateTime(2026, 10, 2),
        numero: 'R-000009',
        items: const [
          ItemReceta(
            id: 'i',
            medicamento: 'Loratadina',
            concentracion: '10 mg',
            forma: 'tableta',
            dosis: '1 tableta',
            via: 'oral',
            frecuencia: 'cada 24 horas',
            duracion: '5 días',
            cantidad: 5,
            unidad: 'tabletas',
          ),
        ],
      );
      expect(
        r.textoParaHistoria(),
        'Se formuló (R-000009) el 02/10/2026:\n'
        '1. LORATADINA 10 mg · tableta 1 tableta vía oral cada 24 horas '
        'durante 5 días. Cantidad: 5 (cinco) tabletas.',
      );
    });
  });
}
