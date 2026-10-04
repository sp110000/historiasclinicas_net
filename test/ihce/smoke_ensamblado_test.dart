import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/ihce/ensamblado/ensamblador.dart';
import 'package:historiasclinicas_net/core/ihce/extraccion/entrada_atencion.dart';
import 'package:historiasclinicas_net/core/ihce/modelo/documento_rda.dart';
import 'package:historiasclinicas_net/core/ihce/validacion/reglas_locales.dart';

import 'ayudas_ihce.dart';

void main() {
  test('smoke: ensamblado de consulta', () {
    final config = configDePrueba();
    final catalogo = catalogoDePrueba();
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, ahora.day - 2, 10, 30);
    final a = const ExtractorAtencion().extraer(
      entradaSintetica(datos: datosSinteticos(inicio: inicio)),
      pdf: pdfSintetico,
    );
    final r = EstrategiaConsulta(config, catalogo).ensamblar(
      a,
      const IdentidadDocumento(
        tenantId: 't',
        atencionId: 'x',
        tipo: TipoRda.consulta,
        version: 1,
      ),
    );
    // ignore: avoid_print
    print(r.faltantes);
    // ignore: avoid_print
    print(r.advertencias);
    final reglas = validarReglasLocales(
      r.bundle,
      ContextoReglas(
        config: config,
        tipo: TipoRda.consulta,
        ahora: DateTime.now(),
        externos: r.grafo.externos,
      ),
    );
    // ignore: avoid_print
    print(reglas.map((i) => '${i.detailsText} ${i.diagnostics}').toList());
    final esquema = esquemaDePrueba().validarBundle(r.bundle);
    // ignore: avoid_print
    print(esquema.map((i) => '${i.location} ${i.diagnostics}').toList());
    Directory('build/ihce/smoke').createSync(recursive: true);
    File(
      'build/ihce/smoke/bundle-consulta.json',
    ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(r.bundle));
  });
}
