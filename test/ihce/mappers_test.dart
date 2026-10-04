// T17: cada mapper con su fixture sintético. El recurso es válido contra el
// JSON Schema oficial de FHIR R4, lleva el `meta.profile` de su perfil y los
// `display` salen del catálogo cargado. Los códigos se toman de los
// CodeSystems de la guía (no se escriben a mano).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/cie10/catalogo_cie10.dart';
import 'package:historiasclinicas_net/core/ihce/config/config_ihce.dart';
import 'package:historiasclinicas_net/core/ihce/grafo/referencias.dart';
import 'package:historiasclinicas_net/core/ihce/mappers/condition_mapper.dart';
import 'package:historiasclinicas_net/core/ihce/mappers/contexto.dart';
import 'package:historiasclinicas_net/core/ihce/mappers/encounter_mapper.dart';
import 'package:historiasclinicas_net/core/ihce/mappers/estructurales_mapper.dart';
import 'package:historiasclinicas_net/core/ihce/mappers/medication_request_mapper.dart';
import 'package:historiasclinicas_net/core/ihce/mappers/observation_mapper.dart';
import 'package:historiasclinicas_net/core/ihce/mappers/patient_mapper.dart';
import 'package:historiasclinicas_net/core/ihce/mappers/practitioner_mapper.dart';
import 'package:historiasclinicas_net/core/ihce/mappers/procedure_mapper.dart';
import 'package:historiasclinicas_net/core/ihce/modelo/dto.dart';
import 'package:historiasclinicas_net/core/ihce/perfiles/perfiles_rda.g.dart';
import 'package:historiasclinicas_net/core/ihce/terminologia/catalogo_terminologia.dart';

import 'ayudas_ihce.dart';

final _guia =
    (jsonDecode(File('assets/ihce/catalogos_guia.json').readAsStringSync())
            as Map)
        .cast<String, Object?>();

/// Primer código del CodeSystem [system] de la guía (con [largo], el
/// primero de esa longitud: CIUO-88 tiene códigos de agrupación).
String codigoGuia(String system, {int? largo}) {
  final cs = (_guia['codeSystems']! as Map)[system] as Map?;
  expect(cs, isNotNull, reason: '$system no está en la guía');
  final codigos = (cs!['conceptos']! as Map).keys.cast<String>();
  return largo == null
      ? codigos.first
      : codigos.firstWhere((c) => c.length == largo);
}

CatalogoTerminologia _catalogoNuevo() =>
    CatalogoTerminologia.desdeGuia(
      File('assets/ihce/catalogos_guia.json').readAsStringSync(),
    )..usarCie10(
      CatalogoCie10.desdeTexto(
        File('assets/cie10/cie10_sispro.txt').readAsStringSync(),
      ),
      FuenteDisplayCie10.sispro,
    );

ContextoMapeo _contexto() => ContextoMapeo(
  config: configDePrueba(),
  catalogo: _catalogoNuevo(),
  referencias: ReferenciasRda(EstiloReferencia.hash),
);

/// Todo `Coding` (mapa con `system` y `code`) del recurso.
List<Map<String, Object?>> _codings(Object? v) {
  final r = <Map<String, Object?>>[];
  void visitar(Object? x) {
    if (x is Map) {
      if (x['system'] is String && x['code'] is String && x['value'] == null) {
        r.add(x.cast());
      }
      x.values.forEach(visitar);
    } else if (x is List) {
      x.forEach(visitar);
    }
  }

  visitar(v);
  return r;
}

void _comprobar(
  Map<String, Object?> recurso,
  String perfil,
  ContextoMapeo c, {
  int codificadosMinimos = 1,
}) {
  expect(c.faltantes, isEmpty, reason: '${c.faltantes}');
  expect(
    esquemaDePrueba().validarRecurso(recurso),
    isEmpty,
    reason: 'JSON Schema FHIR R4',
  );
  expect((recurso['meta']! as Map)['profile'], [perfil]);
  expect(perfilDe(recurso), perfil);
  var deCatalogo = 0;
  for (final coding in _codings(recurso)) {
    final esperado = c.catalogo.display(
      coding['system']! as String,
      coding['code']! as String,
    );
    if (esperado == null) continue; // sistema externo (LOINC, UCUM, …)
    deCatalogo++;
    expect(
      coding['display'],
      esperado,
      reason: '${coding['system']}|${coding['code']}',
    );
  }
  expect(deCatalogo, greaterThanOrEqualTo(codificadosMinimos));
}

const _origen = Origen('datos', 'sintetico');

final _paciente = PacienteDto(
  origen: _origen,
  tipoDocumento: 'CC',
  numeroDocumento: '9900000001',
  primerApellido: 'SINTETICO',
  segundoApellido: 'FICTICIO',
  primerNombre: 'PACIENTE',
  segundoNombre: 'DE PRUEBA',
  fechaNacimiento: DateTime(1990, 3, 15),
  sexo: 'F',
  ciudad: 'MUNICIPIO FICTICIO',
  nacionalidad: '170',
  paisResidencia: '170',
  etnia: '99',
  discapacidad: '08',
  zonaResidencia: '01',
);

const _profesional = ProfesionalDto(
  origen: _origen,
  tipoDocumento: 'CC',
  numeroDocumento: '9900000002',
  primerApellido: 'PRUEBA',
  segundoApellido: 'FICTICIA',
  nombres: ['ANA', 'SINTETICA'],
  codigoRethus: '003',
  registro: 'RM-SINT-0001',
);

const _diagnostico = DiagnosticoDto(
  origen: Origen('datos.diagnosticos', 'd-1'),
  codigoCie10: 'J029',
  principal: true,
  caracter: 'confirmado_nuevo',
);

void main() {
  test('T17 PatientRDA', () {
    final c = _contexto();
    final r = mapearPaciente(_paciente, c, id: 'CC-9900000001');
    _comprobar(r, PerfilRda.patientRDA, c);
    expect(r['id'], 'CC-9900000001');
  });

  test('T17 PractitionerRDA', () {
    final c = _contexto();
    final r = mapearProfesional(_profesional, c, id: 'CC-9900000002');
    _comprobar(r, PerfilRda.practitionerRDA, c);
  });

  test('T17 ConditionRDA (display CIE-10 de SISPRO)', () {
    final c = _contexto();
    final r = mapearDiagnostico(
      _diagnostico,
      c,
      id: 'Condition-0',
      idPaciente: 'CC-9900000001',
    );
    _comprobar(r, PerfilRda.conditionRDA, c);
    expect(
      _codings(r).where((x) => x['code'] == 'J029').single['display'],
      c.catalogo.display(SistemaRda.icd10CO, 'J029'),
    );
    // El texto digitado del diagnóstico no viaja.
    expect(jsonEncode(r), isNot(contains('texto digitado')));
  });

  test('T17 EncounterAmbulatoryRDA', () {
    final c = _contexto();
    final r = mapearEncuentro(
      EncuentroDto(
        origen: _origen,
        id: '0f5c2a1e-8d4b-4c7a-9e21-5a3b7c9d1e2f',
        inicio: DateTime(2026, 1, 15, 10, 30),
        fin: DateTime(2026, 1, 15, 10, 55),
        tipoConsulta: 'primera_vez',
        causaExterna: '38',
      ),
      const PrestadorDto(
        codigoHabilitacion: '990000000001',
        modalidad: '01',
        entorno: '05',
        cupsConsulta: '890201',
      ),
      c,
      id: 'Encounter-0',
      idPaciente: 'CC-9900000001',
      idProfesional: 'CC-9900000002',
      idPrestador: '990000000001',
      principal: (idCondition: 'Condition-0', dto: _diagnostico),
      relacionados: const [],
    );
    _comprobar(r, PerfilRda.encounterAmbulatoryRDA, c, codificadosMinimos: 3);
    final periodo = r['period']! as Map;
    expect(periodo['start'], '2026-01-15T10:30:00-05:00');
    expect(periodo['end'], '2026-01-15T10:55:00-05:00');
  });

  test('T17 AllergyIntoleranceRDA', () {
    final c = _contexto();
    final sistema = Fijos(
      'AllergyIntoleranceRDA',
    ).texto('AllergyIntolerance.code.coding.system');
    final r = mapearAlergia(
      AlergiaDto(
        origen: _origen,
        tipo: codigoGuia(sistema),
        texto: 'ALERGIA SINTETICA',
      ),
      c,
      id: 'AllergyIntolerance-0',
      idPaciente: 'CC-9900000001',
      idEncuentro: 'Encounter-0',
    );
    _comprobar(r, PerfilRda.allergyIntoleranceRDA, c);
  });

  test('T17 DocumentReferenceEPIRDA', () {
    final c = _contexto();
    final r = mapearDocumentoSoporte(
      pdfSintetico,
      c,
      id: 'DocumentReference-0',
      idPaciente: 'CC-9900000001',
      idEncuentro: 'Encounter-0',
      idAutor: '990000000001',
      fecha: DateTime(2026, 1, 15, 10, 55),
    );
    _comprobar(r, PerfilRda.documentReferenceEPIRDA, c, codificadosMinimos: 0);
    final adjunto =
        ((r['content']! as List).single as Map)['attachment']! as Map;
    expect(base64Decode(adjunto['data']! as String), pdfSintetico);
    // D7: el perfil prohíbe contentType (0..0).
    expect(adjunto.containsKey('contentType'), isFalse);
  });

  test('T17 PatientOccupationAtEncounterRDA', () {
    final c = _contexto();
    final r = mapearObservacion(
      OcupacionDto(
        origen: _origen,
        codigoCiuo: codigoGuia(SistemaRda.ciuo88AC, largo: 4),
      ),
      c,
      id: 'Observation-0',
      idPaciente: 'CC-9900000001',
      idEncuentro: 'Encounter-0',
    );
    expect(r.perfil, PerfilRda.patientOccupationAtEncounterRDA);
    _comprobar(r.recurso, r.perfil, c);
  });

  test('T17 AttendanceAllowanceRDA', () {
    final c = _contexto();
    final sistema = Fijos('AttendanceAllowanceRDA').texto(
      'Observation.component:LicenseScope.value[x]:valueCodeableConcept.coding.system',
    );
    final r = mapearObservacion(
      IncapacidadDto(
        origen: _origen,
        alcance: codigoGuia(sistema),
        dias: 3,
        inicio: DateTime(2026, 1, 15),
        fin: DateTime(2026, 1, 17),
        prospectiva: true,
        retroactiva: false,
      ),
      c,
      id: 'Observation-1',
      idPaciente: 'CC-9900000001',
      idEncuentro: 'Encounter-0',
    );
    expect(r.perfil, PerfilRda.attendanceAllowanceRDA);
    _comprobar(r.recurso, r.perfil, c);
  });

  for (final realizado in [true, false]) {
    final perfil = realizado
        ? PerfilRda.procedureRDA
        : PerfilRda.serviceRequestRDA;
    test('T17 ${perfil.split('/').last}', () {
      final c = _contexto();
      final tipo = realizado ? 'Procedure' : 'ServiceRequest';
      final f = Fijos(realizado ? 'ProcedureRDA' : 'ServiceRequestRDA');
      final r = mapearProcedimiento(
        ProcedimientoDto(
          origen: _origen,
          cups: codigoGuia(f.texto('$tipo.code.coding.system')),
          finalidad: codigoGuia(f.texto('$tipo.reasonCode.coding.system')),
          fecha: DateTime(2026, 1, 15, 10, 40),
          realizado: realizado,
          diagnosticoPrincipal: 'd-1',
          diagnosticoRelacionado: 'd-1',
        ),
        c,
        id: '$tipo-0',
        idPaciente: 'CC-9900000001',
        idEncuentro: 'Encounter-0',
        idProfesional: 'CC-9900000002',
        idDiagnosticoPrincipal: 'Condition-0',
        idDiagnosticoRelacionado: 'Condition-0',
      );
      expect(r.perfil, perfil);
      _comprobar(r.recurso, perfil, c, codificadosMinimos: 2);
    });
  }

  test('T17 MedicationRequestRDA', () {
    final c = _contexto();
    final f = Fijos('MedicationRequestRDA');
    const med = 'MedicationRequest.medication[x].coding';
    const dosis = 'MedicationRequest.dosageInstruction';
    String de(String elemento) => codigoGuia(f.texto(elemento));
    final r = mapearMedicamento(
      MedicamentoDto(
        origen: _origen,
        fecha: DateTime(2026, 1, 15, 10, 50),
        finalidad: de('MedicationRequest.reasonCode.coding.system'),
        duracionDias: 5,
        frecuencia: de('$dosis.timing.code.coding.system'),
        via: de('$dosis.route.coding.system'),
        dosis: 1,
        unidadDosis: de('$dosis.doseAndRate:UMM.dose[x].system'),
        dci: [de('$med:DCI.system')],
        iumPrimerNivel: de('$med:IUMPrimerNivel.system'),
        categoria: c.catalogo
            .opciones(ConjuntoRda.colombianHealthTechnologyMedicationCodes)
            .first
            .$1,
        indicacionEspecial: de('$dosis.additionalInstruction.coding.system'),
        instrucciones: 'Indicaciones sintéticas',
      ),
      c,
      id: 'MedicationRequest-0',
      idPaciente: 'CC-9900000001',
      idEncuentro: 'Encounter-0',
      idProfesional: 'CC-9900000002',
      idDiagnostico: 'Condition-0',
    );
    _comprobar(r, PerfilRda.medicationRequestRDA, c, codificadosMinimos: 5);
  });

  test('T17 un código fuera de catálogo bloquea (SEMANTICO), sin inventar '
      'display', () {
    final c = _contexto();
    final r = mapearDiagnostico(
      const DiagnosticoDto(
        origen: _origen,
        codigoCie10: 'ZZZ9',
        principal: true,
        caracter: 'confirmado_nuevo',
      ),
      c,
      id: 'Condition-0',
      idPaciente: 'CC-9900000001',
    );
    expect(c.faltantes.single.categoria, 'SEMANTICO');
    expect(
      _codings(
        r,
      ).where((x) => x['code'] == 'ZZZ9').single.containsKey('display'),
      isFalse,
    );
  });
}
