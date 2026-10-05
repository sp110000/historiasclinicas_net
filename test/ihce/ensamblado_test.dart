// T18: ensamblado del Bundle de consulta, parametrizado con los dos estilos
// de referencia (D1) y con el Encounter dentro y fuera de `entry` (D2).
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/ihce/canonico/jcs.dart';
import 'package:historiasclinicas_net/core/ihce/config/config_ihce.dart';
import 'package:historiasclinicas_net/core/ihce/ensamblado/ensamblador.dart';
import 'package:historiasclinicas_net/core/ihce/extraccion/entrada_atencion.dart';
import 'package:historiasclinicas_net/core/ihce/modelo/documento_rda.dart';
import 'package:historiasclinicas_net/core/ihce/perfiles/perfiles_rda.g.dart';
import 'package:historiasclinicas_net/core/ihce/validacion/reglas_locales.dart';

import 'ayudas_ihce.dart';

const _identidad = IdentidadDocumento(
  tenantId: '990000000001',
  atencionId: '0f5c2a1e-8d4b-4c7a-9e21-5a3b7c9d1e2f',
  tipo: TipoRda.consulta,
  version: 1,
);

/// Patrón de `id` de FHIR R4 (datatypes: `[A-Za-z0-9\-\.]{1,64}`).
final _idFhir = RegExp(r'^[A-Za-z0-9\-.]{1,64}$');

ResultadoEnsamblado _ensamblar(
  ConfigIhce config, {
  Map<String, Object?>? datos,
}) {
  final a = const ExtractorAtencion().extraer(
    entradaSintetica(datos: datos),
    pdf: pdfSintetico,
  );
  return EstrategiaConsulta(
    config,
    catalogoDePrueba(),
  ).ensamblar(a, _identidad);
}

List<String> _referencias(Object? v) {
  final r = <String>[];
  void visitar(Object? x) {
    if (x is Map) {
      if (x['reference'] is String) r.add(x['reference']! as String);
      x.values.forEach(visitar);
    } else if (x is List) {
      x.forEach(visitar);
    }
  }

  visitar(v);
  return r;
}

void main() {
  for (final estilo in EstiloReferencia.values) {
    for (final conEncounter in [true, false]) {
      group('T18 estilo=${estilo.name} encounterEnEntry=$conEncounter', () {
        final config = configDePrueba(
          estilo: estilo,
          encounterComoEntrada: conEncounter,
        );
        late ResultadoEnsamblado r;
        late List<Map<String, Object?>> recursos;

        setUp(() {
          r = _ensamblar(config);
          recursos = [
            for (final e in r.bundle['entry']! as List)
              ((e as Map)['resource']! as Map).cast<String, Object?>(),
          ];
        });

        test('sin faltantes y Bundle document', () {
          expect(r.faltantes, isEmpty, reason: '${r.faltantes}');
          expect(r.valido, isTrue);
          expect(r.bundle['type'], 'document');
          expect(r.bundle.containsKey('identifier'), isFalse, reason: 'D3');
        });

        test('entry[0] es el único Composition', () {
          expect(recursos.first['resourceType'], 'Composition');
          expect(
            recursos.where((x) => x['resourceType'] == 'Composition'),
            hasLength(1),
          );
        });

        test('Encounter según IHCE_BUNDLE_ENCOUNTER_ENTRY', () {
          final encuentros = recursos.where(
            (x) => x['resourceType'] == 'Encounter',
          );
          expect(encuentros, hasLength(conEncounter ? 1 : 0));
          if (!conEncounter) expect(r.grafo.externos, contains('Encounter-0'));
        });

        test('todas las secciones obligatorias; emptyReason donde '
            'corresponde', () {
          final secciones = (recursos.first['section']! as List)
              .cast<Map<String, Object?>>();
          final perfil =
              seccionesPorComposition[EstrategiaConsulta.perfilComposition]!;
          for (final s in perfil.where((s) => s.obligatoria)) {
            final sec = secciones.where(
              (x) => ((x['code']! as Map)['coding']! as List).any(
                (c) => (c as Map)['code'] == s.codigo,
              ),
            );
            expect(sec, hasLength(1), reason: s.slice);
            final tieneEntradas = (sec.single['entry'] as List?) != null;
            final vacia = sec.single['emptyReason'] != null;
            expect(
              tieneEntradas != vacia,
              isTrue,
              reason: '${s.slice}: entry o emptyReason, nunca ambos',
            );
            if (vacia) {
              expect(s.emptyReasonPermitido, isTrue, reason: s.slice);
              expect(sec.single['text'], isNotNull, reason: s.slice);
            }
          }
          // La sección de problemas exige entrada (1..*) y la tiene.
          final problemas = perfil.firstWhere(
            (s) => s.slice == 'sectionProblems',
          );
          expect(problemas.entradaMin, greaterThanOrEqualTo(1));
        });

        test('toda referencia resuelve a una entrada o a un externo '
            'permitido', () {
          final ids = {
            for (final x in recursos)
              if (x['id'] != null) x['id']! as String,
          };
          for (final ref in _referencias(r.bundle)) {
            if (estilo == EstiloReferencia.hash && !ref.contains('/')) {
              expect(ref, startsWith('#'), reason: ref);
            }
            final id = ref.startsWith('#') ? ref.substring(1) : ref;
            expect(
              ids.contains(id) ||
                  r.grafo.externos.contains(id) ||
                  r.grafo.externos.contains(ref),
              isTrue,
              reason: 'referencia sin entrada: $ref',
            );
          }
          // La misma comprobación de las reglas locales (R05/R06).
          expect(
            validarReglasLocales(
              r.bundle,
              ContextoReglas(
                config: config,
                tipo: TipoRda.consulta,
                ahora: DateTime(2026, 1, 16, 9),
                externos: r.grafo.externos,
              ),
            ),
            isEmpty,
          );
        });

        test('patrones de id', () {
          for (final x in recursos.skip(1)) {
            expect(x['id'], matches(_idFhir), reason: '${x['resourceType']}');
          }
          String idDe(String tipo) =>
              recursos.firstWhere((x) => x['resourceType'] == tipo)['id']!
                  as String;
          expect(idDe('Patient'), 'CC-9900000001');
          expect(idDe('Practitioner'), 'CC-9900000002');
          expect(idDe('Condition'), 'Condition-0');
          expect(idDe('DocumentReference'), 'DocumentReference-0');
          if (conEncounter) expect(idDe('Encounter'), 'Encounter-0');
        });

        test('misma entrada ⇒ mismo bundle_sha256', () {
          final otro = _ensamblar(config);
          expect(
            sha256Hex(jcsBytes(otro.bundle)),
            sha256Hex(jcsBytes(r.bundle)),
          );
          // Otra atención ⇒ otro sha.
          final distinto = _ensamblar(
            config,
            datos: datosSinteticos(codigoPrincipal: 'J00X'),
          );
          expect(
            sha256Hex(jcsBytes(distinto.bundle)),
            isNot(sha256Hex(jcsBytes(r.bundle))),
          );
        });
      });
    }
  }

  test('T18 IHCE_BUNDLE_IDENTIFIER=uuid: UUID v5 determinista', () {
    final config = configDePrueba(identificador: IdentificadorBundle.uuid);
    final a = _ensamblar(config).bundle['identifier']! as Map;
    final b = _ensamblar(config).bundle['identifier']! as Map;
    expect(a['value'], b['value']);
    expect(
      a['value'],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      ),
    );
    expect(
      uuidDeterminista(
        const IdentidadDocumento(
          tenantId: '990000000001',
          atencionId: '0f5c2a1e-8d4b-4c7a-9e21-5a3b7c9d1e2f',
          tipo: TipoRda.consulta,
          version: 2,
        ),
      ),
      isNot(a['value']),
    );
  });

  test('T18 alergias solo en texto bloquean el RDA (D8)', () {
    final r = _ensamblar(
      configDePrueba(),
      datos: datosSinteticos(
        alergias: ['Alergia sintética'],
        niegaAlergias: false,
      ),
    );
    expect(
      r.faltantes.map((f) => f.elemento),
      contains('Composition.section:sectionAllergies'),
    );
  });
}
