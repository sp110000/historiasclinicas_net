// T21: build web sin relevo de servidor. Con el adaptador «no disponible»
// el documento queda SIN_TRANSPORTE, sin red y sin excepciones hacia la
// presentación; al registrar un adaptador válido se envía el mismo
// documento, sin reconstruirlo.
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/ihce/canonico/jcs.dart';
import 'package:historiasclinicas_net/core/ihce/cliente/transporte.dart';
import 'package:historiasclinicas_net/core/ihce/cliente/transporte_plataforma.dart'
    as web;
import 'package:historiasclinicas_net/core/ihce/modelo/documento_rda.dart';

import 'ayudas_ihce.dart';
import 'banco_ihce.dart';

void main() {
  test('T21 sin transporte: SIN_TRANSPORTE y envío al registrar uno', () async {
    final servidor = ServidorSimulado()
      ..respuestasApi.add(responder(201, bundleAceptado()));
    final b = Banco(
      servidor: servidor,
      transporte: const TransporteNoDisponible(),
    );

    // Ninguna excepción llega a quien cierra la atención.
    final d = await b.cerrarYProcesar();
    expect(d.estado, EstadoDocumento.sinTransporte);
    expect(servidor.peticionesToken, isEmpty);
    expect(servidor.peticionesApi, isEmpty);
    expect(b.pdf.generados, 1);
    final sha = d.bundleSha256;
    expect(sha, isNotNull);

    // Barridos posteriores sin transporte: siguen en cola, sin red.
    await b.servicio.procesarPendientes();
    expect(b.documento(d.id).estado, EstadoDocumento.sinTransporte);
    expect(servidor.peticionesApi, isEmpty);

    await b.servicio.registrarTransporte(servidor.transporte());
    final enviado = b.documento(d.id);
    expect(enviado.estado, EstadoDocumento.aceptado);
    expect(enviado.id, d.id);
    expect(enviado.versionDoc, d.versionDoc, reason: 'mismo documento');
    expect(b.pdf.generados, 1, reason: 'sin reconstruir');
    expect(enviado.bundleSha256, sha);
    expect(sha256Hex(servidor.peticionesApi.single.bodyBytes), sha);
  });

  test('T21 el adaptador del navegador es «no disponible»', () {
    // `transporte_plataforma.dart` es la variante que la importación
    // condicional elige cuando compila para la web.
    final t = web.crearTransporte(configDePrueba());
    expect(t, isA<TransporteNoDisponible>());
    expect(t.disponible, isFalse);
    expect(t.tls, isNull);
  });
}
