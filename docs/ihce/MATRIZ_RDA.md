# Matriz RDA de consulta externa (Fase 2)

Cruce de [MAPEO_REPOSITORIO.md](MAPEO_REPOSITORIO.md) con [PERFILES_RDA.md](PERFILES_RDA.md) (generado de los StructureDefinitions fijados en `vendor/fhir/VERSIONS.lock`) y el Anexo Técnico 1 §7.4 de la Resolución 1888 de 2025 (elementos de dato de la Resolución 866 de 2021, columna «866»).

Estados: **OK** (el dato existe con la forma exigida) · **DERIVABLE** (se obtiene de un dato existente con una regla escrita) · **FALTA** (no existe). Vías para cerrar un `FALTA`: **(1)** derivación, **(2)** configuración del prestador, **(3)** campo mínimo (regla 10, [CAMBIOS_UI.md](CAMBIOS_UI.md)). Un dato en `FALTA` sin cerrar **bloquea ese RDA localmente** (`INVALIDO_LOCAL`, categoría interna con el elemento que falta); la atención se guarda igual.

Los códigos y `display` salen siempre del catálogo cargado (`assets/ihce/catalogos_guia.json`, generado de la guía; CIE-10 del catálogo SISPRO de la app, ver D6). Las equivalencias desde códigos locales del repositorio están en `lib/core/ihce/terminologia/equivalencias.dart`.

## 1. Bundle y Composition (`BundleAmbulatoryRDA`, `CompositionAmbulatoryRDA`)

| Elemento RDA | Card. | Origen en el repositorio | Transformación | Estado | Vía |
| --- | --- | --- | --- | --- | --- |
| `Bundle.type = document` | 1..1 | — | fijo del perfil | OK | — |
| `Bundle.identifier` (`system` fijo, `value`) | 0..1 | — | D3: se omite (colección Postman) o UUID determinista (`IHCE_BUNDLE_IDENTIFIER=uuid`) | DERIVABLE | (1) |
| `Bundle.timestamp` | 1..1 | `finalizadaEn` (`historia_controller.dart:113`) | instante de cierre con zona `IHCE_ZONA_HORARIA` (no el reloj al construir) | DERIVABLE | (1) |
| `entry[0]` Composition único | 1..1 | — | ensamblador | OK | — |
| `Composition.status`, `type`, `confidentiality`, `attester.mode` | 1..1 | — | fijos/patrones del perfil | OK | — |
| `Composition.subject` | 1..1 | paciente | referencia al nodo Patient | OK | — |
| `Composition.encounter` | 1..1 | atención (`historia.id`) | referencia al nodo Encounter raíz | OK | — |
| `Composition.date` | 1..1 | `finalizadaEn` | con zona | DERIVABLE | (1) |
| `Composition.author` | 1..1 | médico | referencia al Practitioner (el perfil admite Practitioner u Organization) | OK | — |
| `Composition.title` | 1..1 | — | `IHCE_TITULO_COMPOSITION` (por defecto «RDA Consulta», como el cuerpo oficial de Postman) | DERIVABLE | (2) |
| `Composition.custodian` | 1..1 | **no existe** (código de habilitación) | referencia externa `#{CódigoHabilitación}` (Manual §5.3 c) | FALTA→cerrado | (2)+(3) campo «Código de habilitación (REPS)» |
| `Composition.event.period` | 0..1 | `fechaAtencion` → `finalizadaEn` | fecha completa con zona | DERIVABLE | (1) |
| Secciones (9 obligatorias) | 9..10 | ver §3 | título y código fijos del perfil; `emptyReason` + `text` cuando no hay entradas (Manual §5.4.3b) | OK | — |

## 2. Recursos del Bundle

### Patient (`PatientRDA`) — 866: 2.1, 2.2, 3.1–3.4, 4, 1.1, 5, 6, 13.1, 10

| Elemento | Card. | Origen | Transformación | Estado | Vía |
| --- | --- | --- | --- | --- | --- |
| `id` | — | tipo y número de documento | `{TipoDoc}-{NumDoc}` (Manual §5.3 a) | DERIVABLE | (1) |
| `identifier:NationalPersonIdentifier` (tipo `ColombianPersonIdentifier`, valor) | 1..1 | `tipoDocumento`, `numeroDocumento` (`paciente.dart:47-48`) | tabla de equivalencias local → catálogo; número sin separadores | DERIVABLE | (1) |
| `active` | 1..1 | — | `true` | OK | — |
| `name:OfficialPatientName.family` | 1..1 | `primerApellido` + `segundoApellido` | unidos por espacio; extensiones `FathersFamilyName`/`MothersFamilyName` | DERIVABLE | (1) |
| `name.given` | 1..2 | `nombres` (un solo texto, `paciente.dart:46`) | primer token = primer nombre; el resto = segundo nombre (2 elementos máx.) | DERIVABLE | (1) |
| `birthDate` | 1..1 | `fechaNacimiento` (o solo `edadAproximada`) | `AAAA-MM-DD`; con solo edad aproximada **bloquea** | OK / FALTA si solo edad | campo existente |
| `gender` + `ExtensionBiologicalGender` | 0..1 / 1..1 | `sexo` F/M/I (`paciente.dart:55`) | F→`female`/`02 Mujer`; M→`male`/`01 Hombre`; I→`other`/`03 Indeterminado o Intersexual` | DERIVABLE | (1) |
| `ExtensionPatientNationality` | 1..* | **no existe** | código ISO 3166-1 numérico del catálogo `ISO31661` | FALTA→cerrado | (3) «Nacionalidad» |
| `ExtensionPatientEthnicity` | 1..1 | **no existe** | `ColombianEthnicGroup` | FALTA→cerrado | (3) «Pertenencia étnica» |
| `ExtensionPatientDisability` | 1..* | **no existe** | `ColombianDisabilityClassification` | FALTA→cerrado | (3) «Discapacidad» |
| `ExtensionPatientGenderIdentity` | 0..1 | no existe | se omite (opcional; Anexo: «a criterio del profesional») | — | — |
| `address:HomeAddress` (`id`, `use`, `type`) | 1..1 | — | fijos/patrones del perfil | OK | — |
| `address.city` | 1..1 | `ciudad` (texto, `paciente.dart:58`) | texto tal cual; vacío **bloquea** | OK | campo existente |
| `address.extension:ExtensionResidenceZone` | 1..1 | **no existe** | `ColombianResidenceZone` | FALTA→cerrado | (3) «Zona de residencia» |
| `address.country` + `ExtensionCountryCode` | 1..1 | **no existe** | código ISO 3166-1 numérico; `country` = `display` del catálogo | FALTA→cerrado | (3) «País de residencia» |
| `ExtensionDivipolaMunicipality` | 0..1 | no existe (ciudad es texto) | se omite (opcional) | — | — |

### Practitioner (`PractitionerRDA`)

| Elemento | Card. | Origen | Transformación | Estado | Vía |
| --- | --- | --- | --- | --- | --- |
| `id` | — | tipo y número de documento del médico | `{TipoDoc}-{NumDoc}` | DERIVABLE | (1) |
| `identifier:NationalPersonIdentifier` | 1..1 | `documento` (`medico.dart:57`, opcional y **sin tipo**) | valor; tipo por equivalencia | FALTA (tipo)→cerrado | (3) «Tipo de documento»; el número usa el campo existente |
| `active` | 1..1 | — | `true` | OK | — |
| `name.family` + `FathersFamilyName` | 1..1 | `nombre` (texto completo con título, `medico.dart:50`) | no se parte un nombre libre | FALTA→cerrado | (3) «Primer apellido», «Segundo apellido» |
| `name.given` | 1..* | ídem | | FALTA→cerrado | (3) «Nombres» |
| `qualification.code` (`RETHUSqualification`) | 1..1 | **no existe** (`especialidad` es texto) | código del catálogo | FALTA→cerrado | (3) «Profesión (código RETHUS)» |
| `qualification:Rethus.identifier.value` | 0..1 | `registro` (`medico.dart:54`) | tal cual | OK | — |

### Organization IPS (`CareDeliveryOrganizationRDA`) — 866: 16

La entrada es `0..1` en `BundleAmbulatoryRDA`; `custodian` y `serviceProvider` se resuelven con la referencia externa `#{CódigoHabilitación}` (Manual §5.3 c, colección Postman). **No se emite la entrada** porque exigiría NIT, clase de prestador y dirección con departamento, que el perfil pide solo si la entrada existe: no son necesarios (regla 10).

| Elemento | Origen | Estado | Vía |
| --- | --- | --- | --- |
| Código de habilitación REPS | **no existe** | FALTA→cerrado | (2)+(3) «Código de habilitación (REPS)» |

### Encounter (`EncounterAmbulatoryRDA`) — nodo raíz local

| Elemento | Card. | Origen | Transformación | Estado | Vía |
| --- | --- | --- | --- | --- | --- |
| `id` | — | — | `Encounter-0` | OK | — |
| `identifier:EncounterIdentifier` | 0..1 | `historia.id` (UUID, `historia.dart:173`) | `system` fijo del perfil; el VIDA **no** va aquí | OK | — |
| `status`, `class`, `type:encounterServiceGroup` | 1..1 | — | fijos del perfil (`finished`, `AMB`, `01 Consulta externa`) | OK | — |
| `type:encounterModality` | 1..1 | **no existe** | `ColombianTechModality` | FALTA→cerrado | (2)+(3) «Modalidad de la atención» |
| `type:encounterEnvironment` | 1..1 | **no existe** | `EntornoAtencion` | FALTA→cerrado | (2)+(3) «Entorno de la atención» |
| `type:encounterService` (REPS) | 0..1 | no existe | se omite | — | — |
| `serviceType` (`CUPSConsultationCodes`) | 1..1 | `tipoConsulta` (`historia.dart:178`) | primera vez / control / interconsulta → CUPS configurado por el prestador; sin tipo o sin CUPS configurado **bloquea** | FALTA→cerrado | (2)+(3) «CUPS consulta de primera vez», «… de control», «… de interconsulta» |
| `subject` | 1..1 | paciente | referencia | OK | — |
| `participant:AttenderPhysician` | 1..1 | médico | referencia; `id` y tipo fijos | OK | — |
| `period.start` / `.end` | 1..1 | `fechaAtencion` / `finalizadaEn` | fecha completa con zona; invariantes `start ≤ end ≤ ahora`, `≥ hoy − 1 año` | DERIVABLE | (1) |
| `reasonCode` (causa externa RIPS) | 1..1 | **no existe** | `RIPSCausaExternaVersion2` | FALTA→cerrado | (3) «Causa externa» (por atención) |
| `diagnosis:MainDiagnosis` | 1..1 | diagnóstico `tipo = principal` con código | referencia al Condition; `rank`, `use` fijos | OK / FALTA si sin código | campo existente |
| `diagnosis:MainDiagnosis.extension:ExtensionDiagnosisType` | 1..1 | `caracter` (`diagnostico.dart:31`) | presuntivo→`01`, confirmado_nuevo→`02`, confirmado_repetido→`03` (`RIPSTipoDiagnosticoPrincipalVersion2`) | DERIVABLE | (1) |
| `diagnosis:Comorbidity-1..3` | 0..1 | diagnósticos `relacionado` con código | hasta 3, en orden | DERIVABLE | (1) |
| `serviceProvider` | 0..1 | código de habilitación | referencia externa | DERIVABLE | (2) |
| `location` | 0..* | no existe (sedes) | se omite | — | — |

### Condition (`ConditionRDA`) — 866: 37.1–37.3

| Elemento | Card. | Origen | Transformación | Estado |
| --- | --- | --- | --- | --- |
| `code.coding:ICD10` (`system`, `code`, `display`) | 1..1 | `Diagnostico.codigo` (opcional) | `system` fijo; `display` del catálogo SISPRO cargado (D6), **nunca** de `descripcion`; código ausente o inexistente **bloquea** (principal) o se omite con advertencia (relacionado) | OK / FALTA si sin código |
| `clinicalStatus`, `verificationStatus` | — | — | fijos del perfil | OK |
| `subject` | 1..1 | paciente | referencia | OK |

### DocumentReference (`DocumentReferenceEPIRDA`) — PDF de soporte

| Elemento | Card. | Origen | Transformación | Estado |
| --- | --- | --- | --- | --- |
| `content.attachment.data` | 1..1 | `generarPdfHistoria` (`historia_pdf.dart:34`) | PDF con capa de texto y sin contraseña, generado una vez por versión del documento y persistido cifrado; ≤ `IHCE_ATTACHMENT_MAX_BYTES` | DERIVABLE |
| `content.attachment.contentType` | **0..0** | — | **no se envía**: el perfil lo prohíbe; el tipo va en `content.format` (fijo). El Manual §5.4.7 y `att-1` dicen lo contrario: manda la estructura ([DESVIACIONES.md](DESVIACIONES.md) D7) | OK |
| `type`, `category`, `description`, `securityLabel`, `custodian`, `content.format`, `status` | 1..1 | — | fijos/patrones del perfil (`custodian = Organization/MinSalud`) | OK |
| `subject`, `author`, `date`, `context.encounter` | 1..1 | paciente, prestador, `finalizadaEn`, atención | referencias; `date` instante con zona | DERIVABLE |

## 3. Secciones sin entradas codificables

El perfil admite `entry 0..*` en estas secciones: **no son necesarias** y no justifican campos (regla 10). Sin entradas codificadas, la sección va con `emptyReason` y `text` narrativo (Manual §5.4.3b). `CompositionAmbulatoryRDA` **fija** `emptyReason = nilknown` en todas ellas (corrección de esta matriz tras la capa 2; [DESVIACIONES.md](DESVIACIONES.md) D8): no se puede enviar `notasked` ni `unavailable`. Para no perder ni falsear lo registrado:

| Sección | Dato en la historia | Sección enviada |
| --- | --- | --- |
| `sectionPayers` (EAPB) | `aseguradora` texto sin código ADRES | `nilknown` + texto estándar del Manual; si hay texto, se añade a la narrativa («Registrado solo como texto libre, sin codificación: …») |
| `sectionHistoryOfOccupation` | `ocupacion` texto sin código CIUO | ídem |
| `sectionAttendanceAllowance` (incapacidad) | no se captura | `nilknown` + texto estándar |
| `sectionMedications` | receta de texto libre (fuera de la historia) | `nilknown` + texto estándar |
| `sectionAllergies` | `niegaAlergias` / etiquetas de texto con su tipo | niega o sin alergias: `nilknown` + texto estándar (Anexo 47.1: «cuando no presente alergias conocidas, este dato debe venir vacío»). Alergias con **tipo** (campo «Tipo: ‹alergia›», [CAMBIOS_UI.md](CAMBIOS_UI.md)) → `AllergyIntoleranceRDA` en `entry`. Alergias **sin tipo** → **bloquea** (`INVALIDO_LOCAL`): `nilknown` afirmaría «sin alergias conocidas» |
| `sectionRiskFactors` | `habitos` texto | `nilknown` + texto estándar + texto libre en la narrativa |
| `sectionServiceRequests` | `examenesSolicitados`, `interconsultas` texto sin CUPS | ídem |
| `sectionClarificationNotes` | — | se omite (`0..1`) |
| `sectionProblems` | diagnósticos | **entradas obligatorias** (`1..*`): sin Condition codificado bloquea |
| `sectionAddendumDocuments` | PDF | entrada obligatoria; `emptyReason` prohibido |

## 4. Resumen de brechas

| Dato | Vía | Estado |
| --- | --- | --- |
| Nacionalidad, país de residencia, pertenencia étnica, discapacidad, zona de residencia | (3) campos en «Datos del paciente» | cerrada |
| Causa externa | (3) campo en el encabezado de la atención | cerrada |
| Tipo de documento, apellidos y nombres separados, profesión RETHUS del médico | (3) campos en «Datos profesionales» | cerrada |
| Código de habilitación, modalidad, entorno, CUPS por tipo de consulta | (2)+(3) configuración del prestador en «Consultorio» | cerrada |
| Fecha de nacimiento cuando solo hay edad aproximada | campo existente | **bloquea** hasta registrar la fecha |
| CIE-10 del diagnóstico principal sin código | campo existente | **bloquea** hasta codificar |
| Tipo de consulta sin elegir o «urgencia» | campo existente | bloquea; «urgencia» es RDA de urgencias (P1) |
| Tipo de cada alergia registrada (`AllergyIntoleranceRDA.code`) | (3) campo «Tipo: ‹alergia›» en Antecedentes | cerrada; sin tipo **bloquea** (D8) |
| Ocupación, EAPB, factores de riesgo, órdenes y medicamentos codificados | — | **abierta**: el texto libre viaja en la narrativa con `emptyReason = nilknown`; mappers listos (T17) para cuando existan datos codificados |
| Evoluciones como RDA propios | — | **abierta**: sin diagnóstico por evolución (P1) |
| Urgencias, hospitalización, resumen del paciente | — | **abierta**: el producto no captura esos datos (P1, puntos de extensión) |
