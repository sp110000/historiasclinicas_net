// T22: almacén de secretos. Credenciales y llave de cifrado solo a través de
// AlmacenSecretos; con el almacén vacío el módulo queda inactivo sin lanzar;
// ningún secreto en la configuración compilada ni en los logs.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/ihce/almacen/almacen_kv.dart';
import 'package:historiasclinicas_net/core/ihce/almacen/repositorio_ihce.dart';
import 'package:historiasclinicas_net/core/ihce/config/config_ihce.dart';
import 'package:historiasclinicas_net/core/ihce/modelo/documento_rda.dart';
import 'package:historiasclinicas_net/core/ihce/secretos/almacen_secretos.dart';

import 'banco_ihce.dart';

final _nombreSecreto = RegExp(
  r'SECRET|CLIENT_?ID|SUBSCRIPTION|SUBS_?KEY|PASSWORD|ACCESS_TOKEN|_KEY\b',
);

void main() {
  test(
    'T22 credenciales y llave de datos se leen del AlmacenSecretos',
    () async {
      final kv = AlmacenKvMemoria();
      final b = Banco(repositorio: RepositorioIhce(kv));
      b.servidor.respuestasApi.add(responder(201, bundleAceptado()));
      final d = await b.cerrarYProcesar();
      expect(d.estado, EstadoDocumento.aceptado);

      final ambiente = b.config.ambiente;
      expect(
        b.secretos.lecturas,
        containsAll([
          ClavesSecretas.clientId(ambiente),
          ClavesSecretas.clientSecret(ambiente),
          ClavesSecretas.subscriptionKey(ambiente),
          ClavesSecretas.llaveDatos,
        ]),
      );
      // La llave de cifrado (generada en el equipo) vive solo en el almacén
      // de secretos: ni ella ni las credenciales aparecen en el almacén de
      // datos.
      final llave = b.secretos.valores[ClavesSecretas.llaveDatos]!;
      final todo = kv.datos.entries
          .map((e) => '${e.key}=${e.value}')
          .join('\n');
      for (final s in [
        llave,
        secretoSintetico,
        clientIdSintetico,
        claveSuscripcionSintetica,
        tokenSintetico,
      ]) {
        expect(todo, isNot(contains(s)));
      }
      // El Bundle en reposo va cifrado.
      expect(todo, isNot(contains('"resourceType"')));
    },
  );

  test('T22 almacén vacío: módulo inactivo sin lanzar, sin red', () async {
    final b = Banco(conCredenciales: false);
    b.servidor.respuestasApi.add(responder(201, bundleAceptado()));
    final d = await b.cerrarYProcesar();
    expect(d.estado.terminal, isFalse);
    expect(d.estado, isNot(EstadoDocumento.errorInterno));
    expect(b.servidor.peticionesToken, isEmpty);
    expect(b.servidor.peticionesApi, isEmpty);
    expect(await b.credenciales.configuradas(), isFalse);
    expect(await b.credenciales.leer(), isNull);

    // Al guardar las credenciales (formulario), el mismo documento sale.
    await b.credenciales.guardar(
      clientId: clientIdSintetico,
      clientSecret: secretoSintetico,
      subscriptionKey: claveSuscripcionSintetica,
    );
    await b.servicio.procesarPendientes();
    expect(b.documento(d.id).estado, EstadoDocumento.aceptado);
  });

  test('T22 guardar un valor vacío borra; null no cambia', () async {
    final s = AlmacenSecretosMemoria();
    final c = ServicioCredenciales(s, AmbienteIhce.preproduccion);
    await c.guardar(
      clientId: clientIdSintetico,
      clientSecret: secretoSintetico,
    );
    expect(await c.configuradas(), isTrue);
    await c.guardar(clientId: null, clientSecret: null);
    expect(await c.configuradas(), isTrue);
    await c.guardar(clientSecret: '');
    expect(await c.configuradas(), isFalse);
    expect(await c.clientIdGuardado(), clientIdSintetico);
  });

  test('T22 ningún secreto en la configuración compilada', () {
    // Variables de compilación (`String.fromEnvironment`) de todo lib/.
    final nombres = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in RegExp(
        r"fromEnvironment\(\s*'([A-Z0-9_]+)'",
      ).allMatches(f.readAsStringSync())) {
        nombres.add(m.group(1)!);
      }
    }
    expect(nombres, contains('IHCE_ENABLED'));
    expect(nombres.where(_nombreSecreto.hasMatch), isEmpty);

    // La plantilla: nombres de variables, sin secretos y con la bandera
    // apagada.
    final plantilla = File('config/ihce.env.example').readAsLinesSync();
    final variables = {
      for (final l in plantilla)
        if (!l.startsWith('#') && l.contains('='))
          l.split('=').first: l.substring(l.indexOf('=') + 1),
    };
    expect(variables['IHCE_ENABLED'], 'false');
    expect(variables.keys.where(_nombreSecreto.hasMatch), isEmpty);
    for (final e in variables.entries) {
      if (e.key != 'IHCE_ENABLED') expect(e.value, isEmpty, reason: e.key);
    }
    // Toda variable compilada del módulo está en la plantilla.
    expect(
      variables.keys.toSet(),
      containsAll(nombres.where((n) => n.startsWith('IHCE_'))),
    );

    // Sin bandera, el módulo está apagado.
    expect(ConfigIhce.desdeMapa(const {}).habilitado, isFalse);
    expect(const ConfigIhce().habilitado, isFalse);
  });

  test('T22 ningún secreto en los logs', () async {
    final b = Banco();
    b.servidor.respuestasApi.add(responder(201, bundleAceptado()));
    await b.cerrarYProcesar();
    final texto = logsCapturados.map((e) => '$e').join('\n');
    expect(texto, isNotEmpty);
    for (final s in [
      secretoSintetico,
      clientIdSintetico,
      claveSuscripcionSintetica,
      tokenSintetico,
      b.secretos.valores[ClavesSecretas.llaveDatos]!,
    ]) {
      expect(texto, isNot(contains(s)));
    }
  });
}
