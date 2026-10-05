// Fase 8: Bundles del gate a partir de fixtures sintéticos, con fechas
// relativas a hoy (los invariantes del perfil exigen menos de un año y no
// futuro). Cada Bundle pasa la capa 1 (JSON Schema FHIR R4) y las reglas
// locales con cero errores y se escribe en `build/ihce/bundles/` para la
// capa 2 (validador oficial de HL7, `tool/ihce/verificar.sh`).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/ihce/config/config_ihce.dart';
import 'package:historiasclinicas_net/core/ihce/ensamblado/ensamblador.dart';
import 'package:historiasclinicas_net/core/ihce/extraccion/entrada_atencion.dart';
import 'package:historiasclinicas_net/core/ihce/mappers/contexto.dart';
import 'package:historiasclinicas_net/core/ihce/modelo/documento_rda.dart';
import 'package:historiasclinicas_net/core/ihce/validacion/reglas_locales.dart';

import 'ayudas_ihce.dart';

/// [opcional]: configuración distinta de la de fábrica que no entra en la
/// línea base de la capa 2 (se valida y se reporta aparte).
typedef _Escenario = ({
  String nombre,
  ConfigIhce config,
  Map<String, Object?> datos,
  bool opcional,
});

List<_Escenario> _escenarios(DateTime hoy) {
  final inicio = DateTime(hoy.year, hoy.month, hoy.day - 2, 10, 30);
  final tipoAlergia = codigoGuia(
    Fijos(
      'AllergyIntoleranceRDA',
    ).texto('AllergyIntolerance.code.coding.system'),
  );

  Map<String, Object?> conAlergiaTipada() {
    final d = datosSinteticos(
      id: '2b7e1c3d-4f5a-4b6c-8d7e-9f0a1b2c3d4e',
      inicio: inicio,
      tipoConsulta: 'control',
      sexo: 'M',
      codigoPrincipal: 'J00X',
      alergias: ['Alergia sintética a medicamento'],
      niegaAlergias: false,
    );
    (d['antecedentes']! as Map)['tiposAlergia'] = {
      'Alergia sintética a medicamento': tipoAlergia,
    };
    return d;
  }

  Map<String, Object?> extranjero() {
    final d = datosSinteticos(
      id: '3c8f2d4e-5a6b-4c7d-9e8f-0a1b2c3d4e5f',
      inicio: inicio,
    );
    (d['paciente']! as Map)
      ..['tipoDocumento'] = 'PA'
      ..['numeroDocumento'] = 'SINT990001'
      ..['segundoApellido'] = ''
      ..['nacionalidad'] = '862';
    return d;
  }

  return [
    (
      nombre: 'consulta-primera-vez',
      config: configDePrueba(),
      datos: datosSinteticos(inicio: inicio),
      opcional: false,
    ),
    (
      nombre: 'consulta-control-alergia-tipada',
      config: configDePrueba(),
      datos: conAlergiaTipada(),
      opcional: false,
    ),
    (
      nombre: 'consulta-paciente-extranjero',
      config: configDePrueba(),
      datos: extranjero(),
      opcional: false,
    ),
    (
      nombre: 'consulta-encounter-fuera-de-entry',
      config: configDePrueba(encounterComoEntrada: false),
      datos: datosSinteticos(inicio: inicio),
      opcional: false,
    ),
    (
      nombre: 'consulta-identificador-uuid',
      config: configDePrueba(identificador: IdentificadorBundle.uuid),
      datos: datosSinteticos(inicio: inicio),
      opcional: false,
    ),
    // D1 «plain»: sin evidencia oficial para sus hallazgos de capa 2
    // (DESVIACIONES.md); se valida y se reporta, sin entrar al gate.
    (
      nombre: 'consulta-referencias-plain',
      config: configDePrueba(estilo: EstiloReferencia.plain),
      datos: datosSinteticos(inicio: inicio),
      opcional: true,
    ),
  ];
}

void main() {
  final hoy = DateTime.now();
  final salida = Directory('build/ihce/bundles');
  final opcionales = Directory('build/ihce/bundles-opcionales');

  setUpAll(() {
    for (final d in [salida, opcionales]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
      d.createSync(recursive: true);
    }
  });

  for (final e in _escenarios(hoy)) {
    test('gate: ${e.nombre}', () {
      final a = const ExtractorAtencion().extraer(
        entradaSintetica(datos: e.datos),
        pdf: pdfSintetico,
      );
      final r = EstrategiaConsulta(e.config, catalogoDePrueba()).ensamblar(
        a,
        IdentidadDocumento(
          tenantId: prestadorSintetico.codigoHabilitacion,
          atencionId: a.encuentro.id,
          tipo: TipoRda.consulta,
          version: 1,
        ),
      );
      expect(r.faltantes, isEmpty, reason: '${r.faltantes}');
      expect(r.valido, isTrue);
      // Capa 1: cero errores.
      final capa1 = esquemaDePrueba().validarBundle(r.bundle);
      expect(
        capa1.map((i) => '${i.location.join(',')}: ${i.diagnostics}'),
        isEmpty,
      );
      // Reglas locales: cero errores.
      final reglas = validarReglasLocales(
        r.bundle,
        ContextoReglas(
          config: e.config,
          tipo: TipoRda.consulta,
          ahora: hoy,
          externos: r.grafo.externos,
        ),
      );
      expect(reglas.map((i) => '${i.detailsText} ${i.diagnostics}'), isEmpty);
      final dir = e.opcional ? opcionales : salida;
      File(
        '${dir.path}/${e.nombre}.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(r.bundle));
    });
  }
}
