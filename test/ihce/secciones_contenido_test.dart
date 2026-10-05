// Cierre 1.2: ningún RDA declara «nada conocido» (`emptyReason = nilknown`)
// en una sección para la que la atención sí tiene contenido. Ningún perfil
// de entrada admite el contenido de texto libre sin inventar códigos
// (DESVIACIONES.md D8), el código de emptyReason es fijo y el Manual §5.4.3b
// exige emptyReason sin entradas: el RDA queda INVALIDO_LOCAL con su motivo.
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/ihce/ensamblado/ensamblador.dart';
import 'package:historiasclinicas_net/core/ihce/extraccion/entrada_atencion.dart';
import 'package:historiasclinicas_net/core/ihce/mappers/contexto.dart';
import 'package:historiasclinicas_net/core/ihce/modelo/documento_rda.dart';
import 'package:historiasclinicas_net/core/ihce/perfiles/perfiles_rda.g.dart';

import 'ayudas_ihce.dart';
import 'banco_ihce.dart';

/// Fórmula registrada desde la receta (`Receta.textoParaHistoria`).
const _formula =
    'Se formuló el 15/01/2026:\n'
    '1. Acetaminofén 500 mg tableta, 1 cada 8 horas por 5 días';

Map<String, Object?> _conTextoLibre() => datosSinteticos(
  planTerapeutico: _formula,
  examenesSolicitados: 'Hemograma, glicemia',
  interconsultas: 'Medicina interna',
  ocupacion: 'Docente',
  aseguradora: 'EPS sintética',
  habitos: 'Fuma 5 cigarrillos al día',
);

ResultadoEnsamblado _ensamblar(Map<String, Object?> datos) {
  final a = const ExtractorAtencion().extraer(
    entradaSintetica(datos: datos),
    pdf: pdfSintetico,
  );
  return EstrategiaConsulta(configDePrueba(), catalogoDePrueba()).ensamblar(
    a,
    IdentidadDocumento(
      tenantId: prestadorSintetico.codigoHabilitacion,
      atencionId: a.encuentro.id,
      tipo: TipoRda.consulta,
      version: 1,
    ),
  );
}

List<Map<String, Object?>> _secciones(ResultadoEnsamblado r) =>
    ((((r.bundle['entry']! as List).first as Map)['resource'] as Map)['section']
            as List)
        .cast<Map<String, Object?>>();

String _codigo(Map<String, Object?> s) =>
    (((s['code']! as Map)['coding']! as List).first as Map)['code']! as String;

/// Slice de la sección del perfil por su código LOINC.
String _slice(Map<String, Object?> s) =>
    seccionesPorComposition[EstrategiaConsulta.perfilComposition]!
        .firstWhere((p) => p.codigo == _codigo(s))
        .slice;

void main() {
  test('consulta con fórmula, órdenes, ocupación, EAPB y hábitos en texto '
      'libre: ninguna sección con contenido dice «nada conocido»', () {
    final datos = _conTextoLibre();
    final r = _ensamblar(datos);
    final textos = const ExtractorAtencion()
        .extraer(entradaSintetica(datos: datos), pdf: pdfSintetico)
        .textos;

    for (final s in _secciones(r)) {
      final slice = _slice(s);
      if (contenidoSinCodificar(slice, textos) != null) {
        expect(s.containsKey('emptyReason'), isFalse, reason: slice);
        expect(s.containsKey('entry'), isFalse, reason: slice);
      }
    }

    // El RDA queda bloqueado por cada sección con contenido, con un motivo
    // claro y sin datos del paciente.
    final elementos = r.faltantes.map((f) => f.elemento).toSet();
    expect(elementos, {
      'Composition.section:sectionPayers',
      'Composition.section:sectionHistoryOfOccupation',
      'Composition.section:sectionMedications',
      'Composition.section:sectionRiskFactors',
      'Composition.section:sectionServiceRequests',
    });
    expect(r.valido, isFalse);
    for (final f in r.faltantes) {
      expect(f.mensaje, contains('no puede declarar «sin'));
      for (final dato in [
        'Acetaminofén',
        'Hemograma',
        'Docente',
        'EPS sintética',
        'cigarrillos',
      ]) {
        expect(f.mensaje, isNot(contains(dato)));
      }
    }
  });

  test('cada texto libre bloquea solo su sección', () {
    final casos = {
      'sectionMedications': datosSinteticos(planTerapeutico: _formula),
      'sectionServiceRequests': datosSinteticos(
        examenesSolicitados: 'Hemograma',
      ),
      'sectionHistoryOfOccupation': datosSinteticos(ocupacion: 'Docente'),
      'sectionPayers': datosSinteticos(aseguradora: 'EPS sintética'),
      'sectionRiskFactors': datosSinteticos(habitos: 'Fuma'),
    };
    final interconsulta = _ensamblar(
      datosSinteticos(interconsultas: 'Medicina interna'),
    );
    expect(interconsulta.faltantes.map((f) => f.elemento), [
      'Composition.section:sectionServiceRequests',
    ]);
    for (final c in casos.entries) {
      final r = _ensamblar(c.value);
      expect(r.faltantes.map((f) => f.elemento), [
        'Composition.section:${c.key}',
      ], reason: c.key);
    }
  });

  test('alergias con y sin tipo: no se envía una lista incompleta', () {
    final datos = datosSinteticos(
      alergias: ['Alergia sintética A', 'Alergia sintética B'],
      niegaAlergias: false,
    );
    final tipo = codigoGuia(
      Fijos(
        'AllergyIntoleranceRDA',
      ).texto('AllergyIntolerance.code.coding.system'),
    );
    (datos['antecedentes']! as Map)['tiposAlergia'] = {
      'Alergia sintética A': tipo,
    };
    final r = _ensamblar(datos);
    expect(r.faltantes.map((f) => f.elemento), [
      'Composition.section:sectionAllergies',
    ]);
    // Con todas tipadas, va con sus entradas.
    (datos['antecedentes']! as Map)['tiposAlergia'] = {
      'Alergia sintética A': tipo,
      'Alergia sintética B': tipo,
    };
    final completo = _ensamblar(datos);
    expect(completo.faltantes, isEmpty);
    final alergias = _secciones(
      completo,
    ).firstWhere((s) => _slice(s) == 'sectionAllergies');
    expect(alergias['entry'], hasLength(2));
  });

  test('sin texto libre, las secciones vacías van con nilknown y el texto '
      'estándar, y el RDA es válido', () {
    final r = _ensamblar(datosSinteticos());
    expect(r.faltantes, isEmpty);
    for (final s in _secciones(r).where((s) => s['entry'] == null)) {
      final coding =
          ((s['emptyReason']! as Map)['coding']! as List).single as Map;
      expect(coding['code'], 'nilknown');
      expect(
        ((s['text']! as Map)['div']! as String),
        contains(textoNadaConocido),
      );
    }
  });

  test('el servicio deja el RDA en INVALIDO_LOCAL con el motivo y no llama '
      'a la red', () async {
    final b = Banco();
    b.servidor.respuestasApi.add(responder(201, bundleAceptado()));
    final d = await b.cerrarYProcesar(datos: _conTextoLibre());
    expect(d.estado, EstadoDocumento.invalidoLocal);
    expect(d.motivo, contains('fórmula'));
    expect(b.servidor.peticionesApi, isEmpty);
    expect(b.servidor.peticionesToken, isEmpty);
  });
}
