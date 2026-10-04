// T23: formulario de credenciales. T24: línea de estado del RDA y
// reintento. Widgets reales de la app con el servicio del banco de pruebas
// (sin red) y secretos en memoria.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/ihce/cliente/transporte.dart';
import 'package:historiasclinicas_net/core/ihce/config/config_ihce.dart';
import 'package:historiasclinicas_net/core/ihce/modelo/documento_rda.dart';
import 'package:historiasclinicas_net/core/ihce/outbox/servicio_ihce.dart';
import 'package:historiasclinicas_net/core/ihce/secretos/almacen_secretos.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/ihce/campos_ihce.dart';
import 'package:historiasclinicas_net/features/ihce/ihce_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayudas_ihce.dart';
import 'banco_ihce.dart';

Future<ProviderContainer> _montar(
  WidgetTester t,
  Widget hijo, {
  required ConfigIhce config,
  required AlmacenSecretos secretos,
  ServicioIhce? servicio,
}) async {
  t.view
    ..physicalSize = const Size(1400, 1000)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({
    Claves.pais: 'CO',
    Claves.medico: jsonEncode(medicoSintetico.aAlmacen()),
    Claves.ihcePrestador: jsonEncode(prestadorSintetico.aMapa()),
  });
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      preferenciasProvider.overrideWithValue(prefs),
      configIhceProvider.overrideWithValue(config),
      almacenSecretosProvider.overrideWithValue(secretos),
      servicioIhceProvider.overrideWithValue(servicio),
    ],
  );
  addTearDown(c.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: temaClaro(),
        home: Scaffold(body: SingleChildScrollView(child: hijo)),
      ),
    ),
  );
  await t.pumpAndSettle();
  return c;
}

Finder _campo(String etiqueta) =>
    find.ancestor(of: find.text(etiqueta), matching: find.byType(TextField));

/// Todo el texto visible (incluido el de los campos).
String _textoVisible(WidgetTester t) => [
  for (final w in t.widgetList<Text>(find.byType(Text)))
    w.data ?? w.textSpan?.toPlainText() ?? '',
  for (final w in t.widgetList<EditableText>(find.byType(EditableText)))
    w.controller.text,
].join('\n');

void main() {
  group('T23 formulario de credenciales', () {
    testWidgets('etiquetas, secreto oculto, guardado solo en '
        'AlmacenSecretos y no se vuelve a mostrar', (t) async {
      final secretos = AlmacenSecretosMemoria();
      final config = configDePrueba();
      final c = await _montar(
        t,
        const CredencialesMinSalud(),
        config: config,
        secretos: secretos,
      );
      expect(find.text('ClientID de MinSalud'), findsOneWidget);
      expect(find.text('ClientSecret de MinSalud'), findsOneWidget);
      expect(
        t.widget<TextField>(_campo('ClientSecret de MinSalud')).obscureText,
        isTrue,
      );
      expect(
        t
            .widget<TextField>(_campo('Clave de suscripción de MinSalud'))
            .obscureText,
        isTrue,
      );

      await t.enterText(_campo('ClientID de MinSalud'), clientIdSintetico);
      await t.enterText(_campo('ClientSecret de MinSalud'), secretoSintetico);
      await t.enterText(
        _campo('Clave de suscripción de MinSalud'),
        claveSuscripcionSintetica,
      );
      await t.tap(find.text('Guardar credenciales'));
      await t.pumpAndSettle();

      final a = config.ambiente;
      expect(secretos.valores, {
        ClavesSecretas.clientId(a): clientIdSintetico,
        ClavesSecretas.clientSecret(a): secretoSintetico,
        ClavesSecretas.subscriptionKey(a): claveSuscripcionSintetica,
      });
      // En ningún otro sitio: ni preferencias ni campos de la pantalla.
      final prefs = c.read(preferenciasProvider);
      for (final k in prefs.getKeys()) {
        expect('${prefs.get(k)}', isNot(contains(secretoSintetico)));
        expect('${prefs.get(k)}', isNot(contains(clientIdSintetico)));
      }
      expect(_textoVisible(t), isNot(contains(secretoSintetico)));
      expect(find.text('Configurado'), findsOneWidget);

      // Reabrir la pantalla: el secreto no se muestra.
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: temaClaro(),
            home: const Scaffold(body: CredencialesMinSalud()),
          ),
        ),
      );
      await t.pumpAndSettle();
      final visible = _textoVisible(t);
      expect(visible, isNot(contains(secretoSintetico)));
      expect(visible, isNot(contains(claveSuscripcionSintetica)));
      expect(find.text('Configurado'), findsOneWidget);
    });

    testWidgets('con IHCE_ENABLED=false los campos no aparecen', (t) async {
      final secretos = AlmacenSecretosMemoria();
      await _montar(
        t,
        const Column(
          children: [
            CredencialesMinSalud(),
            CamposIhceProfesional(),
            CamposIhcePrestador(),
          ],
        ),
        config: const ConfigIhce(),
        secretos: secretos,
      );
      expect(find.text('ClientID de MinSalud'), findsNothing);
      expect(find.text('ClientSecret de MinSalud'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(secretos.lecturas, isEmpty);
    });
  });

  group('T24 estado y reintento', () {
    testWidgets('RECHAZADO muestra motivo y botón; el reintento crea una '
        'nueva version_doc', (t) async {
      late Banco b;
      late DocumentoRda rechazado;
      ProviderContainer? c;
      await t.runAsync(() async {
        b = Banco(
          alCambiar: () => c?.read(cambiosIhceProvider.notifier).avisar(),
        );
        b.servidor.respuestasApi
          ..add(responder(201, bundleAceptado()))
          ..add(
            responder(
              400,
              operationOutcome(
                'structure',
                'Formato de fecha no válido en birthDate',
                location: ['Bundle.entry[1].resource.birthDate'],
              ),
            ),
          )
          // Cada documento aceptado recibe su propio VIDA.
          ..add(
            responder(
              201,
              bundleAceptado(vida: 'VIDA-SINTETICO-REINTENTO-0002'),
            ),
          );
        // Antes, otra atención de otro paciente, aceptada.
        final otra = datosSinteticos(
          id: '7d1e2f0f-5c2a-4c7a-9e21-1e8d4b5a3b7c',
        );
        (otra['paciente']! as Map)['nombres'] = 'OTRA PERSONA';
        (otra['paciente']! as Map)['numeroDocumento'] = '9900000099';
        final aceptada = await b.cerrarYProcesar(datos: otra);
        expect(aceptada.estado, EstadoDocumento.aceptado);
        rechazado = await b.cerrarYProcesar();
      });
      expect(rechazado.estado, EstadoDocumento.rechazado);

      c = await _montar(
        t,
        AvisoRdaAtencion(atencionId: rechazado.atencionId),
        config: b.config,
        secretos: b.secretos,
        servicio: b.servicio,
      );
      expect(
        find.text('El resumen (RDA) no se envió a MinSalud'),
        findsOneWidget,
      );
      expect(
        find.text('MinSalud rechazó el formato del documento'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);

      // Sin OperationOutcome crudo ni datos del paciente.
      final visible = _textoVisible(t);
      for (final prohibido in [
        'OperationOutcome',
        'Formato de fecha',
        'Bundle.entry',
        'birthDate',
        'SINTETICO',
        '9900000001',
        'OTRA PERSONA',
        '9900000099',
      ]) {
        expect(visible, isNot(contains(prohibido)), reason: prohibido);
      }

      await t.tap(find.text('Reintentar'));
      // El reintento corre en la zona de la prueba (pump) y espera E/S
      // simulada real (runAsync): se alternan hasta que termina.
      for (var i = 0; i < 200; i++) {
        final docs = b.repositorio.documentosDeAtencion(rechazado.atencionId);
        if (docs.length == 2 && docs.last.estado.terminal) break;
        await t.pump(const Duration(milliseconds: 10));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      await t.pumpAndSettle();

      final docs = b.repositorio.documentosDeAtencion(rechazado.atencionId);
      expect(docs.map((d) => d.versionDoc), [1, 2]);
      expect(docs.first.estado, EstadoDocumento.rechazado);
      expect(docs.last.estado, EstadoDocumento.aceptado);
      // Aceptado: no se muestra nada.
      expect(
        find.text('El resumen (RDA) no se envió a MinSalud'),
        findsNothing,
      );
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('en cola (SIN_TRANSPORTE) no se muestra nada', (t) async {
      late Banco b;
      late DocumentoRda d;
      await t.runAsync(() async {
        b = Banco(transporte: const TransporteNoDisponible());
        d = await b.cerrarYProcesar();
      });
      expect(d.estado, EstadoDocumento.sinTransporte);
      await _montar(
        t,
        AvisoRdaAtencion(atencionId: d.atencionId),
        config: b.config,
        secretos: b.secretos,
        servicio: b.servicio,
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('con el módulo apagado no se muestra nada', (t) async {
      await _montar(
        t,
        const AvisoRdaAtencion(atencionId: 'cualquiera'),
        config: const ConfigIhce(),
        secretos: AlmacenSecretosMemoria(),
      );
      expect(find.byType(Text), findsNothing);
    });
  });
}
