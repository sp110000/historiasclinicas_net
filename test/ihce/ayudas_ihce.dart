// Datos 100 % sintéticos para las pruebas del módulo IHCE. Ningún nombre,
// documento ni código de habilitación corresponde a una persona o
// prestador real.
import 'dart:convert';
import 'dart:io';

import 'package:historiasclinicas_net/core/cie10/catalogo_cie10.dart';
import 'package:historiasclinicas_net/core/ihce/config/config_ihce.dart';
import 'package:historiasclinicas_net/core/ihce/extraccion/entrada_atencion.dart';
import 'package:historiasclinicas_net/core/ihce/modelo/prestador_ihce.dart';
import 'package:historiasclinicas_net/core/ihce/terminologia/catalogo_terminologia.dart';
import 'package:historiasclinicas_net/core/ihce/validacion/esquema_fhir.dart';
import 'package:historiasclinicas_net/core/models/historia.dart';
import 'package:historiasclinicas_net/core/models/mapa.dart';
import 'package:historiasclinicas_net/core/models/medico.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';

const medicoSintetico = Medico(
  nombre: 'Dra. Ficticia Prueba',
  registro: 'RM-SINT-0001',
  documento: '9900000002',
  tipoDocumento: 'CC',
  primerApellido: 'PRUEBA',
  segundoApellido: 'FICTICIA',
  nombres: 'ANA SINTETICA',
  codigoRethus: '003',
);

const prestadorSintetico = PrestadorIhce(
  codigoHabilitacion: '990000000001',
  modalidad: '01',
  entorno: '05',
  cupsPrimeraVez: '890201',
  cupsControl: '890301',
);

/// Atención sintética de consulta externa de primera vez. Con [ahora], las
/// fechas quedan 2 días antes (los invariantes del perfil exigen menos de
/// un año y no futuro).
Map<String, Object?> datosSinteticos({
  DateTime? inicio,
  DateTime? fin,
  String id = '0f5c2a1e-8d4b-4c7a-9e21-5a3b7c9d1e2f',
  String? tipoConsulta = 'primera_vez',
  String? causaExterna = '38',
  String codigoPrincipal = 'J029',
  List<String> alergias = const [],
  bool niegaAlergias = true,
  String? sexo = 'F',
  DateTime? fechaNacimiento,
  String etnia = '99',
}) {
  final i = inicio ?? DateTime(2026, 1, 15, 10, 30);
  final f = fin ?? i.add(const Duration(minutes: 25));
  final h = HistoriaClinica(
    id: id,
    pais: Pais.colombia,
    fechaAtencion: i,
    tipoConsulta: tipoConsulta,
    causaExterna: causaExterna,
    paciente: Paciente(
      primerApellido: 'SINTETICO',
      segundoApellido: 'FICTICIO',
      nombres: 'PACIENTE DE PRUEBA',
      tipoDocumento: 'CC',
      numeroDocumento: '9900000001',
      fechaNacimiento: fechaNacimiento ?? DateTime(1990, 3, 15),
      sexo: sexo,
      ciudad: 'Municipio Ficticio',
      nacionalidad: '170',
      paisResidencia: '170',
      etnia: etnia,
      discapacidad: '08',
      zonaResidencia: '01',
      ocupacion: 'Oficio de prueba',
    ),
    motivoConsulta: 'Motivo sintético',
    enfermedadActual: 'Relato sintético',
    antecedentes: Antecedentes(
      alergias: alergias,
      niegaAlergias: niegaAlergias,
    ),
    diagnosticos: [
      Diagnostico(
        id: 'd-1',
        codigo: codigoPrincipal,
        descripcion: 'texto digitado que no debe viajar',
        caracter: 'confirmado_nuevo',
      ),
    ],
  );
  return {...h.aMapa(), 'finalizadaEn': fechaHoraIso(f)};
}

EntradaAtencion entradaSintetica({Map<String, Object?>? datos}) =>
    EntradaAtencion.capturar(
      datos: datos ?? datosSinteticos(),
      revision: 1,
      medico: medicoSintetico,
      prestador: prestadorSintetico,
    );

/// PDF mínimo válido (con capa de texto) para las pruebas.
final pdfSintetico = utf8.encode(
  '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
  '2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
  '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]/Contents 4 0 R'
  '/Resources<</Font<</F1 5 0 R>>>>>>endobj\n'
  '4 0 obj<</Length 44>>stream\nBT /F1 12 Tf 20 100 Td (Resumen sintetico) Tj ET\n'
  'endstream endobj\n5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\n'
  'trailer<</Root 1 0 R>>\n%%EOF\n',
);

CatalogoTerminologia? _catalogo;

/// Catálogo de la guía + tabla CIE-10 SISPRO incluida en la app.
CatalogoTerminologia catalogoDePrueba({
  FuenteDisplayCie10 fuente = FuenteDisplayCie10.sispro,
}) {
  final c = _catalogo ??= CatalogoTerminologia.desdeGuia(
    File('assets/ihce/catalogos_guia.json').readAsStringSync(),
  );
  c.usarCie10(
    CatalogoCie10.desdeTexto(
      File('assets/cie10/cie10_sispro.txt').readAsStringSync(),
    ),
    fuente,
  );
  return c;
}

ValidadorEsquemaFhir? _esquema;

ValidadorEsquemaFhir esquemaDePrueba() =>
    _esquema ??= ValidadorEsquemaFhir.desdeTexto(
      File('assets/ihce/fhir.schema.json').readAsStringSync(),
    );

Map<String, Object?> fixture(String nombre) =>
    (jsonDecode(File('test/ihce/fixtures/$nombre').readAsStringSync()) as Map)
        .cast();

ConfigIhce configDePrueba({
  EstiloReferencia estilo = EstiloReferencia.hash,
  bool encounterComoEntrada = true,
  IdentificadorBundle identificador = IdentificadorBundle.omitir,
}) => ConfigIhce(
  habilitado: true,
  baseUrl: 'https://ihce.sintetico.invalid/api',
  tenantId: '00000000-0000-0000-0000-000000000000',
  scope: 'api://sintetico/.default',
  estiloReferencia: estilo,
  encounterComoEntrada: encounterComoEntrada,
  identificadorBundle: identificador,
);
