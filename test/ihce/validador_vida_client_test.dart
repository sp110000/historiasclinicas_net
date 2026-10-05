// Pruebas aisladas del cliente ValidadorVidaClient y de la orquestación
// (T01–T16). Sin red: transporte MockClient, almacén y secretos en memoria,
// reloj falso. Datos 100 % sintéticos.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:historiasclinicas_net/core/ihce/almacen/almacen_kv.dart';
import 'package:historiasclinicas_net/core/ihce/cliente/resultado.dart';
import 'package:historiasclinicas_net/core/ihce/cliente/transporte_io.dart';
import 'package:historiasclinicas_net/core/ihce/cliente/validador_vida_client.dart';
import 'package:historiasclinicas_net/core/ihce/config/config_ihce.dart';
import 'package:historiasclinicas_net/core/ihce/modelo/documento_rda.dart';
import 'package:historiasclinicas_net/core/ihce/perfiles/perfiles_rda.g.dart';

import 'ayudas_ihce.dart';
import 'banco_ihce.dart';

ContextoEnvio _ctx([String? enviado, List<String> tipos = const []]) =>
    ContextoEnvio(
      idCorrelacion: 'corr-sintetica',
      documentoId: 'doc-sintetico',
      bundleIdentifierEnviado: enviado,
      tiposPorEntrada: tipos,
    );

final _bytes = utf8.encode('{"resourceType":"Bundle","type":"document"}');

void main() {
  group('T01 token 200 y envío aceptado', () {
    for (final status in [200, 201]) {
      test('HTTP $status con VIDA', () async {
        final b = Banco();
        b.servidor.respuestasApi.add(responder(status, bundleAceptado()));
        final d = await b.cerrarYProcesar();

        expect(d.estado, EstadoDocumento.aceptado);
        // VIDA persistido byte a byte y enlazado a la atención (raíz).
        expect(d.vida, vidaSintetico);
        expect(utf8.encode(d.vida!), utf8.encode(vidaSintetico));
        expect(b.repositorio.vidaDeAtencion(d.atencionId), vidaSintetico);
        expect(d.idCompositionIhce, 'composition-sintetico-001');

        final r = b.servidor.peticionesApi.single;
        expect(r.method, 'POST');
        expect(
          r.url.toString(),
          endsWith(r'/Composition/$enviar-rda-consulta'),
        );
        expect(r.url.path, contains(r'$enviar-rda-consulta'));
        expect(r.headers['Authorization'], 'Bearer $tokenSintetico');
        expect(
          r.headers['Ocp-Apim-Subscription-Key'],
          claveSuscripcionSintetica,
        );
        expect(r.headers['Content-Type'], startsWith('application/fhir+json'));
        expect(r.headers['Accept'], 'application/fhir+json');

        // El cuerpo enviado es exactamente el Bundle persistido.
        final persistido = await b.servicio.cifrador.descifrar(
          d.bundleCifrado!,
        );
        expect(r.bodyBytes, persistido);

        // El VIDA no se inyecta en el Encounter saliente.
        expect(utf8.decode(r.bodyBytes), isNot(contains(vidaSintetico)));

        final bitacora = b.repositorio.intentos(d.id);
        expect(bitacora, hasLength(1));
        expect(bitacora.single.httpStatus, status);
        expect(bitacora.single.estado, 'aceptado');
        expect(bitacora.single.actor, 'sistema');
      });
    }
  });

  test('T02 caché de token y renovación tras expires_in', () async {
    final b = Banco(servidor: ServidorSimulado(expiraEn: 600));
    b.servidor.respuestasApi.add(responder(200, bundleAceptado()));
    final c = b.cliente();
    await c.enviarRda(TipoRda.consulta, _bytes, _ctx());
    await c.enviarRda(TipoRda.consulta, _bytes, _ctx());
    expect(b.servidor.peticionesToken, hasLength(1));
    b.reloj.avanzar(const Duration(seconds: 601));
    await c.enviarRda(TipoRda.consulta, _bytes, _ctx());
    expect(b.servidor.peticionesToken, hasLength(2));
    // Cuerpo x-www-form-urlencoded con client_credentials.
    final t = b.servidor.peticionesToken.first;
    expect(
      t.headers['Content-Type'],
      startsWith('application/x-www-form-urlencoded'),
    );
    expect(t.bodyFields['grant_type'], 'client_credentials');
    expect(t.bodyFields['scope'], b.config.scope);
  });

  test('T03 401, renovación del token y 200', () async {
    final b = Banco();
    b.servidor.respuestasApi
      ..add(responder(401, operationOutcome('login', 'token vencido')))
      ..add(responder(200, bundleAceptado()));
    final r = await b.cliente().enviarRda(TipoRda.consulta, _bytes, _ctx());
    expect(r, isA<Aceptado>());
    expect(b.servidor.peticionesToken, hasLength(2));
    expect(b.servidor.peticionesApi, hasLength(2));
  });

  test('T04 401 persistente y 403', () async {
    final b = Banco();
    b.servidor.respuestasApi.add(
      responder(401, operationOutcome('login', 'no')),
    );
    final r = await b.cliente().enviarRda(TipoRda.consulta, _bytes, _ctx());
    expect(r, isA<ErrorAuth>());
    expect(b.servidor.peticionesApi, hasLength(2), reason: 'un solo reintento');
    expect(
      b.servidor.peticionesToken,
      hasLength(2),
      reason: 'una sola renovación',
    );

    final b2 = Banco();
    b2.servidor.respuestasApi.add(
      responder(403, operationOutcome('forbidden', 'sin permiso')),
    );
    final d = await b2.cerrarYProcesar();
    expect(d.estado, EstadoDocumento.errorAuth);
    expect(
      b2.servidor.peticionesApi,
      hasLength(1),
      reason: '403 sin reintento',
    );
    await b2.servicio.procesarPendientes();
    expect(b2.servidor.peticionesApi, hasLength(1));
    expect(b2.servicio.hayErrorAuth, isTrue);
  });

  test('T04 tras corregir las credenciales, ERROR_AUTH se reenvía sin '
      'reconstruir', () async {
    final b = Banco();
    b.servidor.respuestasApi
      ..add(responder(403, operationOutcome('forbidden', 'sin permiso')))
      ..add(responder(201, bundleAceptado()));
    final d = await b.cerrarYProcesar();
    expect(d.estado, EstadoDocumento.errorAuth);
    expect(b.servicio.hayErrorAuth, isTrue);

    await b.credenciales.guardar(clientSecret: 'secreto-sintetico-corregido');
    expect(await b.servicio.reactivarErrorAuth(), 1);
    final enviado = b.documento(d.id);
    expect(enviado.estado, EstadoDocumento.aceptado);
    expect(enviado.bundleSha256, d.bundleSha256);
    expect(b.pdf.generados, 1, reason: 'sin reconstruir');
    expect(b.servicio.hayErrorAuth, isFalse);
    expect(b.servidor.peticionesApi, hasLength(2));
  });

  test(
    'T05 400 estructural: SINTACTICO, ubicación resuelta al origen',
    () async {
      final b = Banco();
      b.servidor.respuestasApi.add(
        responder(400, {
          'resourceType': 'OperationOutcome',
          'issue': [
            {
              'severity': 'error',
              'code': 'structure',
              'diagnostics': 'Formato de fecha no válido',
              'location': ['Bundle.entry[1].resource.birthDate'],
            },
            {
              'severity': 'warning',
              'code': 'informational',
              'diagnostics': 'Advertencia adicional',
            },
          ],
        }),
      );
      final d = await b.cerrarYProcesar();
      expect(d.estado, EstadoDocumento.rechazado);
      expect(d.categoria, 'SINTACTICO');
      expect(d.issues, hasLength(2), reason: 'se conservan todas las issues');
      final nodo = d.issues.first.nodoLocal;
      expect(nodo, 'CC-9900000001');
      final registro = b.repositorio.nodo(d.id, nodo!)!;
      expect(registro.tipoRecurso, 'Patient');
      expect(registro.tablaOrigen, 'datos.paciente');
      expect(registro.pkOrigen, d.atencionId);
      await b.servicio.procesarPendientes();
      expect(b.servidor.peticionesApi, hasLength(1), reason: 'sin reintento');
    },
  );

  test('T06 400 por code/display: SEMANTICO y catálogo marcado', () async {
    final b = Banco();
    // La entrada 4 es el Condition (Composition, Patient, Practitioner,
    // Encounter, Condition, DocumentReference).
    b.servidor.respuestasApi.add(
      responder(
        400,
        operationOutcome(
          'code-invalid',
          'El display no coincide con el configurado para el código informado',
          location: ['Bundle.entry[4].resource.code.coding[0].display'],
        ),
      ),
    );
    final d = await b.cerrarYProcesar();
    expect(d.estado, EstadoDocumento.rechazado);
    expect(d.categoria, 'SEMANTICO');
    expect(
      catalogoDePrueba().marcadosParaSincronizar,
      contains(SistemaRda.icd10CO),
    );
    catalogoDePrueba().marcadosParaSincronizar.clear();
  });

  group('T07 rechazos de identidad', () {
    test('paciente no encontrado en el registro nacional', () async {
      final b = Banco();
      b.servidor.respuestasApi.add(
        responder(
          400,
          operationOutcome(
            'business-rule',
            'El paciente no existe en el registro nacional EVOL',
            location: ['Bundle.entry[1].resource'],
          ),
        ),
      );
      final r = await b.cliente().enviarRda(
        TipoRda.consulta,
        _bytes,
        _ctx(null, ['Composition', 'Patient']),
      );
      expect((r as Rechazado).categoria, CategoriaError.identidad);
    });

    test('profesional no habilitado en RETHUS', () async {
      final b = Banco();
      b.servidor.respuestasApi.add(
        responder(
          422,
          operationOutcome(
            'business-rule',
            'El profesional no está activo en RETHUS',
            location: ['Bundle.entry[2].resource'],
          ),
        ),
      );
      final r = await b.cliente().enviarRda(
        TipoRda.consulta,
        _bytes,
        _ctx(null, ['Composition', 'Patient', 'Practitioner']),
      );
      expect((r as Rechazado).categoria, CategoriaError.identidad);
    });
  });

  test('T08 409: DUPLICADO sin reintento', () async {
    final b = Banco();
    b.servidor.respuestasApi.add(
      responder(409, operationOutcome('duplicate', 'RDA repetido')),
    );
    final d = await b.cerrarYProcesar();
    expect(d.estado, EstadoDocumento.duplicado);
    await b.servicio.procesarPendientes();
    expect(b.servidor.peticionesApi, hasLength(1));
  });

  test('T09 2xx con advertencias de coincidencia parcial', () async {
    final b = Banco();
    b.servidor.respuestasApi.add(
      responder(
        200,
        bundleAceptado(
          advertencias: [
            {
              'severity': 'warning',
              'code': 'business-rule',
              'diagnostics': 'El segundo apellido no coincide al 100 %',
            },
          ],
        ),
      ),
    );
    final d = await b.cerrarYProcesar();
    expect(d.estado, EstadoDocumento.aceptado);
    expect(
      d.advertencias.map((a) => a.diagnostics),
      contains('El segundo apellido no coincide al 100 %'),
    );
  });

  group('T10 aceptado sin VIDA', () {
    test('2xx con Bundle sin identificador', () async {
      final b = Banco();
      b.servidor.respuestasApi.add(responder(200, bundleAceptado(vida: null)));
      logsCapturados.clear();
      final d = await b.cerrarYProcesar();
      expect(d.estado, EstadoDocumento.aceptadoSinVida);
      expect(d.vida, isNull);
      expect(
        logsCapturados.map((l) => l.evento),
        contains('aceptado_sin_vida'),
      );
    });

    test('2xx cuyo identificador es un eco del enviado', () async {
      final b = Banco(
        config: configDePrueba(identificador: IdentificadorBundle.uuid),
      );
      b.servidor.respuestasApi.add((r) async {
        final enviado = (jsonDecode(r.body) as Map)['identifier']['value'];
        return http.Response(
          jsonEncode(bundleAceptado(vida: enviado as String)),
          200,
        );
      });
      logsCapturados.clear();
      final d = await b.cerrarYProcesar();
      expect(d.bundleIdentifier, isNotNull);
      expect(d.estado, EstadoDocumento.aceptadoSinVida);
      expect(logsCapturados.map((l) => l.evento), contains('vida_eco'));
    });
  });

  group('T11 fallos transitorios y backoff', () {
    test('429 con Retry-After', () async {
      final b = Banco();
      b.servidor.respuestasApi.add(
        responder(
          429,
          operationOutcome('throttled', 'límite'),
          cabeceras: {'retry-after': '120'},
        ),
      );
      final d = await b.cerrarYProcesar();
      expect(d.estado, EstadoDocumento.reintentoProgramado);
      expect(
        d.proximoIntentoEn,
        b.reloj.ahora().add(const Duration(seconds: 120)),
      );
    });

    test('503, timeout y conexión reiniciada hasta AGOTADO', () async {
      final config = ConfigIhce(
        habilitado: true,
        baseUrl: 'https://ihce.sintetico.invalid/api',
        tenantId: '00000000-0000-0000-0000-000000000000',
        scope: 'api://sintetico/.default',
        maxIntentos: 3,
        cortacircuitosUmbral: 99,
      );
      final b = Banco(config: config);
      b.servidor.respuestasApi
        ..add(responder(503, '<html>Service Unavailable</html>'))
        ..add((_) async => throw TimeoutException('lectura'))
        ..add(
          (_) async => throw http.ClientException('Connection reset by peer'),
        );
      var d = await b.cerrarYProcesar();
      expect(d.estado, EstadoDocumento.reintentoProgramado);
      final espera1 = d.proximoIntentoEn!.difference(b.reloj.ahora());
      expect(espera1, greaterThanOrEqualTo(const Duration(seconds: 30)));
      expect(espera1, lessThanOrEqualTo(const Duration(seconds: 33)));

      // Antes del plazo no se reintenta.
      await b.servicio.procesarPendientes();
      expect(b.servidor.peticionesApi, hasLength(1));

      b.reloj.avanzar(espera1);
      await b.servicio.procesarPendientes();
      d = b.documento(d.id);
      expect(d.estado, EstadoDocumento.reintentoProgramado);
      final espera2 = d.proximoIntentoEn!.difference(b.reloj.ahora());
      expect(espera2, greaterThanOrEqualTo(const Duration(seconds: 60)));
      expect(espera2, lessThanOrEqualTo(const Duration(seconds: 66)));

      b.reloj.avanzar(espera2);
      await b.servicio.procesarPendientes();
      d = b.documento(d.id);
      expect(d.estado, EstadoDocumento.agotado);
      expect(b.servidor.peticionesApi, hasLength(3));
      expect(b.repositorio.intentos(d.id), hasLength(3));

      // AGOTADO se puede reintentar a mano (nueva version_doc).
      expect(d.estado.corregible, isTrue);
      b.servidor.respuestasApi.add(responder(201, bundleAceptado()));
      final nuevo = await b.servicio.reintentar(
        d.id,
        medico: medicoSintetico,
        prestador: prestadorSintetico,
      );
      final v2 = b.documento(nuevo!);
      expect(v2.versionDoc, 2);
      expect(v2.estado, EstadoDocumento.aceptado);
    });

    test('cortacircuitos tras fallos consecutivos', () async {
      final b = Banco();
      b.servidor.respuestasApi.add(responder(503, ''));
      for (var i = 0; i < b.config.cortacircuitosUmbral; i++) {
        await b.cerrarYProcesar(datos: datosSinteticos(id: 'atencion-cc-$i'));
      }
      final antes = b.servidor.peticionesApi.length;
      await b.cerrarYProcesar(datos: datosSinteticos(id: 'atencion-cc-x'));
      expect(
        b.servidor.peticionesApi.length,
        antes,
        reason: 'circuito abierto',
      );
    });
  });

  group('T12 cuerpos no FHIR', () {
    final casos = <String, (int, String)>{
      'JSON de gateway': (500, '{"statusCode":500,"message":"Internal error"}'),
      'HTML': (502, '<html><body>Bad Gateway</body></html>'),
      'vacío': (400, ''),
      'JSON truncado': (400, '{"resourceType":"OperationOut'),
    };
    for (final MapEntry(key: nombre, value: (status, cuerpo))
        in casos.entries) {
      test(nombre, () async {
        final b = Banco();
        b.servidor.respuestasApi.add(responder(status, cuerpo));
        final r = await b.cliente().enviarRda(TipoRda.consulta, _bytes, _ctx());
        if (status >= 500) {
          expect(r, isA<FalloTransitorio>());
          expect((r as FalloTransitorio).cuerpoRedactado, isNotNull);
        } else {
          expect(r, isA<Rechazado>());
          expect((r as Rechazado).categoria, CategoriaError.desconocido);
          expect(r.cuerpoRedactado, isNotNull);
        }
      });
    }

    test('el cuerpo crudo se conserva redactado', () async {
      final b = Banco();
      b.servidor.respuestasApi.add(
        responder(502, 'error con Bearer $tokenSintetico y $secretoSintetico'),
      );
      // Primero un envío para que el redactor conozca los secretos.
      final r = await b.cliente().enviarRda(TipoRda.consulta, _bytes, _ctx());
      final crudo = (r as FalloTransitorio).cuerpoRedactado!;
      expect(crudo, isNot(contains(tokenSintetico)));
      expect(crudo, isNot(contains(secretoSintetico)));
    });
  });

  group('T13 el cierre clínico nunca falla', () {
    test('módulo deshabilitado: no se crea documento', () async {
      final b = Banco(config: const ConfigIhce());
      await b.servicio.alCerrarAtencion(
        datos: datosSinteticos(),
        revision: 1,
        medico: medicoSintetico,
        prestador: prestadorSintetico,
      );
      await b.servicio.procesarPendientes();
      expect(b.repositorio.documentos, isEmpty);
      expect(b.servidor.peticionesApi, isEmpty);
    });

    test(
      'inserción en la outbox fallando: se registra y se reconcilia',
      () async {
        final repositorio = RepositorioQueFalla(AlmacenKvMemoria())
          ..fallosPendientes = 1;
        final b = Banco(repositorio: repositorio);
        b.servidor.respuestasApi.add(responder(200, bundleAceptado()));
        logsCapturados.clear();
        await b.servicio.alCerrarAtencion(
          datos: datosSinteticos(),
          revision: 1,
          medico: medicoSintetico,
          prestador: prestadorSintetico,
        );
        expect(
          logsCapturados.map((l) => l.evento),
          contains('outbox_insercion_fallida'),
        );
        expect(repositorio.documentos, isEmpty);
        await b.servicio.procesarPendientes(); // incluye la reconciliación
        final docs = repositorio.documentos.toList();
        expect(docs, hasLength(1));
        expect(docs.single.estado, EstadoDocumento.aceptado);
      },
    );

    test('excepción inesperada del cliente: ERROR_INTERNO y sigue', () async {
      final servidor = ServidorSimulado();
      var llamadas = 0;
      servidor.respuestasApi.add((_) async {
        llamadas++;
        if (llamadas == 1) throw StateError('fallo inesperado del cliente');
        return http.Response(jsonEncode(bundleAceptado(vida: 'VIDA-2')), 200);
      });
      final b = Banco(servidor: servidor);
      await b.servicio.alCerrarAtencion(
        datos: datosSinteticos(id: 'atencion-a'),
        revision: 1,
        medico: medicoSintetico,
        prestador: prestadorSintetico,
      );
      await b.servicio.alCerrarAtencion(
        datos: datosSinteticos(id: 'atencion-b'),
        revision: 1,
        medico: medicoSintetico,
        prestador: prestadorSintetico,
      );
      await b.servicio.procesarPendientes();
      await b.servicio.procesarPendientes();
      final a = b.repositorio.documentosDeAtencion('atencion-a').single;
      final segundo = b.repositorio.documentosDeAtencion('atencion-b').single;
      expect(a.estado, EstadoDocumento.errorInterno);
      expect(segundo.estado, EstadoDocumento.aceptado);
    });
  });

  group('T14 transporte', () {
    test('adaptador directo: TLS 1.3 mínimo y certificados verificados', () {
      final t = crearTransporte(configDePrueba()) as TransporteDirectoIo;
      expect(t.contexto.minimumTlsProtocolVersion, TlsProtocolVersion.tls1_3);
      expect(t.tls!.versionMinima, '1.3');
      expect(t.tls!.verificarCertificados, isTrue);
      // Ningún archivo del módulo desactiva la verificación.
      final codigo = Directory('lib/core/ihce')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join();
      expect(codigo, isNot(contains('badCertificateCallback =')));
    });

    test('URL base o de token sin https: rechazo', () {
      for (final config in [
        const ConfigIhce(
          habilitado: true,
          baseUrl: 'http://ihce.sintetico.invalid',
          tenantId: 't',
          scope: 's',
        ),
        const ConfigIhce(
          habilitado: true,
          baseUrl: 'https://ihce.sintetico.invalid',
          tokenUrl: 'http://login.sintetico.invalid/token',
        ),
      ]) {
        final b = Banco(config: config);
        expect(b.cliente, throwsA(isA<ConfiguracionIhceInvalida>()));
        expect(config.validar(), isNotEmpty);
      }
    });
  });

  test('T15 los logs no llevan secretos, nombres, documentos ni payloads', () {
    expect(logsCapturados, isNotEmpty);
    final texto = logsCapturados.map((l) => l.toString()).join('\n');
    for (final prohibido in [
      tokenSintetico,
      secretoSintetico,
      claveSuscripcionSintetica,
      clientIdSintetico,
      'SINTETICO',
      'PACIENTE DE PRUEBA',
      '9900000001',
      '9900000002',
      '"resourceType"',
      'Bearer token',
    ]) {
      expect(texto, isNot(contains(prohibido)), reason: prohibido);
    }
  });

  group('T16 concurrencia', () {
    test('N envíos concurrentes: una sola petición de token', () async {
      final b = Banco();
      b.servidor.respuestasApi.add(responder(200, bundleAceptado()));
      final c = b.cliente();
      await Future.wait([
        for (var i = 0; i < 8; i++)
          c.enviarRda(TipoRda.consulta, _bytes, _ctx()),
      ]);
      expect(b.servidor.peticionesToken, hasLength(1));
      expect(b.servidor.peticionesApi, hasLength(8));
    });

    test(
      'dos procesos concurrentes de la misma atención: un solo POST',
      () async {
        final b = Banco();
        b.servidor.respuestasApi.add((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(jsonEncode(bundleAceptado()), 200);
        });
        final datos = datosSinteticos();
        await b.servicio.alCerrarAtencion(
          datos: datos,
          revision: 1,
          medico: medicoSintetico,
          prestador: prestadorSintetico,
        );
        final id = b.repositorio
            .documentosDeAtencion(datos['id']! as String)
            .single
            .id;
        await Future.wait([
          b.servicio.procesarDocumento(id),
          b.servicio.procesarDocumento(id),
          b.servicio.procesarPendientes(),
        ]);
        expect(b.servidor.peticionesApi, hasLength(1));
        expect(b.documento(id).estado, EstadoDocumento.aceptado);
      },
    );
  });
}
