# Perfiles del RDA (generado)

> **No editar a mano.** Generado por `dart run tool/ihce/generar_perfiles.dart` desde los StructureDefinitions de la guía fijados en `vendor/fhir/VERSIONS.lock`.
>
> Guía `minsalud.fhir.co.rda` (versión declarada 1.0.0), compilación `20260917200055`, último cambio rotulado 2026-08-31. La versión no identifica el contenido (D5): vale la huella.

Por perfil: URL canónica, elementos con `min ≥ 1`, must-support, valores fijos y patrones, slices con su discriminador, bindings `required` e invariantes propias del perfil. Se omiten los elementos que cuelgan de uno prohibido (`0..0`) y el ruido heredado (`Extension.url` fijo, `id` y `extension` opcionales sin slicing).

**Slices discriminados por `id`** (marcados ⚑): obligan a emitir ese `id` dentro del elemento de la instancia.

## Índice

- [AllergyIntoleranceRDA](#allergyintolerancerda) — `AllergyIntolerance`
- [AllergyIntoleranceStatementRDA](#allergyintolerancestatementrda) — `AllergyIntolerance`
- [AttendanceAllowanceRDA](#attendanceallowancerda) — `Observation`
- [BundleAmbulatoryRDA](#bundleambulatoryrda) — `Bundle`
- [BundleEmergencyRDA](#bundleemergencyrda) — `Bundle`
- [BundleHospitalizationRDA](#bundlehospitalizationrda) — `Bundle`
- [BundlePatientStatementRDA](#bundlepatientstatementrda) — `Bundle`
- [CareDeliveryLocationRDA](#caredeliverylocationrda) — `Location`
- [CareDeliveryOrganizationRDA](#caredeliveryorganizationrda) — `Organization`
- [CompositionAmbulatoryRDA](#compositionambulatoryrda) — `Composition`
- [CompositionEmergencyRDA](#compositionemergencyrda) — `Composition`
- [CompositionHospitalizationRDA](#compositionhospitalizationrda) — `Composition`
- [CompositionPatientStatementRDA](#compositionpatientstatementrda) — `Composition`
- [CompositionRDA](#compositionrda) — `Composition`
- [ConditionRDA](#conditionrda) — `Condition`
- [ConditionStatementRDA](#conditionstatementrda) — `Condition`
- [DocumentReferenceEPIRDA](#documentreferenceepirda) — `DocumentReference`
- [DocumentReferenceRDA](#documentreferencerda) — `DocumentReference`
- [EncounterAmbulatoryRDA](#encounterambulatoryrda) — `Encounter`
- [EncounterEmergencyRDA](#encounteremergencyrda) — `Encounter`
- [EncounterHospitalizationRDA](#encounterhospitalizationrda) — `Encounter`
- [FamilyMemberHistoryRDA](#familymemberhistoryrda) — `FamilyMemberHistory`
- [HealthBenefitPlanAdminOrganizationRDA](#healthbenefitplanadminorganizationrda) — `Organization`
- [HealthTechProviderOrganization](#healthtechproviderorganization) — `Organization`
- [ImmunizationRDA](#immunizationrda) — `Immunization`
- [MedicationAdminRequestRDA](#medicationadminrequestrda) — `MedicationRequest`
- [MedicationAdministrationRDA](#medicationadministrationrda) — `MedicationAdministration`
- [MedicationRDA](#medicationrda) — `Medication`
- [MedicationRequestRDA](#medicationrequestrda) — `MedicationRequest`
- [MedicationStatementRDA](#medicationstatementrda) — `MedicationStatement`
- [ObservationClarificationNoteRDA](#observationclarificationnoterda) — `Observation`
- [ObservationTriageRDA](#observationtriagerda) — `Observation`
- [OtherTechnologyProcedureRDA](#othertechnologyprocedurerda) — `Procedure`
- [OtherTechnologyServiceRequestRDA](#othertechnologyservicerequestrda) — `ServiceRequest`
- [PatientOccupationAtEncounterRDA](#patientoccupationatencounterrda) — `Observation`
- [PatientRDA](#patientrda) — `Patient`
- [PractitionerRDA](#practitionerrda) — `Practitioner`
- [ProcedureRDA](#procedurerda) — `Procedure`
- [ProcedureResultRDA](#procedureresultrda) — `Observation`
- [RiskFactorRDA](#riskfactorrda) — `RiskAssessment`
- [ServiceRequestRDA](#servicerequestrda) — `ServiceRequest`
- [Extensiones](#extensiones)
- [CodeSystems](#codesystems)

## AllergyIntoleranceRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/AllergyIntoleranceRDA`
- Tipo: `AllergyIntolerance`; base: `http://hl7.org/fhir/StructureDefinition/AllergyIntolerance`
- Descripción: Perfil FHIR de una alergia o intolerancia, para su intercambio en un documento RDA en Colombia.  Evento clínico que describe una alergia, hipersensibilidad o intolerancia que representa un riesgo clínico para el paciente y condiciona su cuidado en salud.  El registro de una alergia o intolerancia es el resultado de un proceso clínico mediante el cual un profesional de la salud, autorizado y habilitado, identifica la presencia de una reacción adversa o hipersensibilidad a un medicamento, alimento, sustancia ambiental u otro agente, con base en la evaluación de la historia clínica del paciente, antecedentes, signos, síntomas y criterios definidos por la ciencia médica, con el fin de prevenir exposiciones futuras y mitigar riesgos para la salud del paciente.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `AllergyIntolerance.meta.profile` | 1..* | canonical(StructureDefinition) | si `AllergyIntolerance.meta` |
| `AllergyIntolerance.verificationStatus.coding.code` | 1..1 | code | si `AllergyIntolerance.verificationStatus` |
| `AllergyIntolerance.verificationStatus.coding.display` | 1..1 | string | si `AllergyIntolerance.verificationStatus` |
| `AllergyIntolerance.code` | 1..1 | CodeableConcept |  |
| `AllergyIntolerance.code.coding.system` | 1..1 | uri | si `AllergyIntolerance.code.coding` |
| `AllergyIntolerance.code.coding.code` | 1..1 | code | si `AllergyIntolerance.code.coding` |
| `AllergyIntolerance.code.coding.display` | 1..1 | string | si `AllergyIntolerance.code.coding` |
| `AllergyIntolerance.code.text` | 1..1 | string |  |
| `AllergyIntolerance.patient` | 1..1 | Reference(PatientRDA) |  |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `AllergyIntolerance.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/AllergyIntoleranceRDA"` |
| `AllergyIntolerance.clinicalStatus.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical"` |
| `AllergyIntolerance.verificationStatus.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/allergyintolerance-verification"` |
| `AllergyIntolerance.verificationStatus.coding.code` | `fixedCode` | `"confirmed"` |
| `AllergyIntolerance.verificationStatus.coding.display` | `fixedString` | `"Confirmed"` |
| `AllergyIntolerance.code.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/TipoAlergia"` |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `AllergyIntolerance.code` | `https://fhir.minsalud.gov.co/rda/ValueSet/TipoAlergiaCodigos` |

## AllergyIntoleranceStatementRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/AllergyIntoleranceStatementRDA`
- Tipo: `AllergyIntolerance`; base: `http://hl7.org/fhir/StructureDefinition/AllergyIntolerance`
- Descripción: Perfil FHIR de una alergia o intolerancia declarada por el paciente, para su intercambio en un documento RDA en Colombia.  Evento clínico que describe una alergia, hipersensibilidad o intolerancia que representa un riesgo clínico para el paciente y condiciona su cuidado en salud.  El antecedente de una alergia o intolerancia puede ser reportado por el paciente, un familiar o cuidador, y debe ser registrado por un profesional de la salud autorizado y habilitado, conforme a su formación y marco legal.  Esto, no corresponde al motivo de atención, que es la razón por la cual el paciente solicita la prestación de servicios de salud en el momento actual.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `AllergyIntolerance.meta.profile` | 1..* | canonical(StructureDefinition) | si `AllergyIntolerance.meta` |
| `AllergyIntolerance.verificationStatus.coding.code` | 1..1 | code | si `AllergyIntolerance.verificationStatus` |
| `AllergyIntolerance.verificationStatus.coding.display` | 1..1 | string | si `AllergyIntolerance.verificationStatus` |
| `AllergyIntolerance.code` | 1..1 | CodeableConcept |  |
| `AllergyIntolerance.code.coding.system` | 1..1 | uri | si `AllergyIntolerance.code.coding` |
| `AllergyIntolerance.code.coding.code` | 1..1 | code | si `AllergyIntolerance.code.coding` |
| `AllergyIntolerance.code.coding.display` | 1..1 | string | si `AllergyIntolerance.code.coding` |
| `AllergyIntolerance.code.text` | 1..1 | string |  |
| `AllergyIntolerance.patient` | 1..1 | Reference(PatientRDA) |  |

### Must-support opcionales

`AllergyIntolerance.verificationStatus` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `AllergyIntolerance.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/AllergyIntoleranceStatementRDA"` |
| `AllergyIntolerance.clinicalStatus.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical"` |
| `AllergyIntolerance.verificationStatus.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/condition-ver-status"` |
| `AllergyIntolerance.verificationStatus.coding.code` | `fixedCode` | `"unconfirmed"` |
| `AllergyIntolerance.verificationStatus.coding.display` | `fixedString` | `"Unconfirmed"` |
| `AllergyIntolerance.code.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/TipoAlergia"` |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `AllergyIntolerance.code` | `https://fhir.minsalud.gov.co/rda/ValueSet/TipoAlergiaCodigos` |

## AttendanceAllowanceRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/AttendanceAllowanceRDA`
- Tipo: `Observation`; base: `http://hl7.org/fhir/StructureDefinition/Observation`
- Descripción: Perfil FHIR de una incapacidad por enfermedad o maternidad, para su intercambio en un documento RDA en Colombia.  El perfil **AttendanceAllowanceRDA** define las restricciones y extensiones aplicables al recurso `Observation` para representar información sobre las **incapacidades por enfermedad** reportadas en el **Sistema de Incapacidades y Prestaciones Económicas (SIPE)**, dentro del marco del **Resumen Digital de Atención (RDA)** en Colombia.    Este perfil permite estandarizar el registro de los principales datos asociados a una incapacidad, incluyendo:    - El **alcance de la incapacidad** (nueva o prórroga).   - El número de **días de incapacidad** otorgados.    El recurso `Observation` en FHIR se utiliza para registrar mediciones, evaluaciones o aserciones clínicas. En este contexto, se adapta para documentar información estructurada sobre incapacidades por enfermedad, garantizando su interoperabilidad en el ecosistema de información en salud colombiano.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Observation.meta.profile` | 1..* | canonical(StructureDefinition) | si `Observation.meta` |
| `Observation.status` | 1..1 | code |  |
| `Observation.code` | 1..1 | CodeableConcept |  |
| `Observation.code.coding` | 1..1 | Coding |  |
| `Observation.code.coding.system` | 1..1 | uri |  |
| `Observation.code.coding.code` | 1..1 | code |  |
| `Observation.code.coding.display` | 1..1 | string |  |
| `Observation.code.text` | 1..1 | string |  |
| `Observation.subject` | 1..1 | Reference(PatientRDA) |  |
| `Observation.component` | 2..8 | BackboneElement |  |
| `Observation.component.code` | 1..1 | CodeableConcept |  |
| `Observation.component:LicenseScope` | 1..1 | BackboneElement |  |
| `Observation.component:LicenseScope.id` | 1..1 | String |  |
| `Observation.component:LicenseScope.code` | 1..1 | CodeableConcept |  |
| `Observation.component:LicenseScope.code.coding` | 1..1 | Coding |  |
| `Observation.component:LicenseScope.code.coding.system` | 1..1 | uri |  |
| `Observation.component:LicenseScope.code.coding.code` | 1..1 | code |  |
| `Observation.component:LicenseScope.code.coding.display` | 1..1 | string |  |
| `Observation.component:LicenseScope.code.text` | 1..1 | string |  |
| `Observation.component:LicenseScope.value[x]` | 1..1 | CodeableConcept |  |
| `Observation.component:LicenseScope.value[x]:valueCodeableConcept` | 1..1 | CodeableConcept |  |
| `Observation.component:LicenseScope.value[x]:valueCodeableConcept.coding` | 1..1 | Coding |  |
| `Observation.component:LicenseScope.value[x]:valueCodeableConcept.coding.system` | 1..1 | uri |  |
| `Observation.component:LicenseScope.value[x]:valueCodeableConcept.coding.code` | 1..1 | code |  |
| `Observation.component:LicenseScope.value[x]:valueCodeableConcept.coding.display` | 1..1 | string |  |
| `Observation.component:LicenseTime.id` | 1..1 | String | si `Observation.component:LicenseTime` |
| `Observation.component:LicenseTime.code` | 1..1 | CodeableConcept | si `Observation.component:LicenseTime` |
| `Observation.component:LicenseTime.code.coding` | 1..1 | Coding | si `Observation.component:LicenseTime` |
| `Observation.component:LicenseTime.code.coding.system` | 1..1 | uri | si `Observation.component:LicenseTime` |
| `Observation.component:LicenseTime.code.coding.code` | 1..1 | code | si `Observation.component:LicenseTime` |
| `Observation.component:LicenseTime.code.coding.display` | 1..1 | string | si `Observation.component:LicenseTime` |
| `Observation.component:LicenseTime.code.text` | 1..1 | string | si `Observation.component:LicenseTime` |
| `Observation.component:LicenseTime.value[x]` | 1..1 | Quantity | si `Observation.component:LicenseTime` |
| `Observation.component:LicenseTime.value[x]:valueQuantity` | 1..1 | Quantity | si `Observation.component:LicenseTime` |
| `Observation.component:LicenseTime.value[x]:valueQuantity.value` | 1..1 | decimal | si `Observation.component:LicenseTime` |
| `Observation.component:LicenseTime.value[x]:valueQuantity.unit` | 1..1 | string | si `Observation.component:LicenseTime` |
| `Observation.component:LicenseTime.value[x]:valueQuantity.system` | 1..1 | uri | si `Observation.component:LicenseTime` |
| `Observation.component:LicenseTime.value[x]:valueQuantity.code` | 1..1 | code | si `Observation.component:LicenseTime` |
| `Observation.component:LicensePeriod.id` | 1..1 | String | si `Observation.component:LicensePeriod` |
| `Observation.component:LicensePeriod.code` | 1..1 | CodeableConcept | si `Observation.component:LicensePeriod` |
| `Observation.component:LicensePeriod.code.coding` | 1..1 | Coding | si `Observation.component:LicensePeriod` |
| `Observation.component:LicensePeriod.code.coding.system` | 1..1 | uri | si `Observation.component:LicensePeriod` |
| `Observation.component:LicensePeriod.code.coding.code` | 1..1 | code | si `Observation.component:LicensePeriod` |
| `Observation.component:LicensePeriod.code.coding.display` | 1..1 | string | si `Observation.component:LicensePeriod` |
| `Observation.component:LicensePeriod.code.text` | 1..1 | string | si `Observation.component:LicensePeriod` |
| `Observation.component:LicensePeriod.value[x]` | 1..1 | Period | si `Observation.component:LicensePeriod` |
| `Observation.component:LicensePeriod.value[x]:valuePeriod` | 1..1 | Period | si `Observation.component:LicensePeriod` |
| `Observation.component:LicensePeriod.value[x]:valuePeriod.start` | 1..1 | dateTime | si `Observation.component:LicensePeriod` |
| `Observation.component:LicensePeriod.value[x]:valuePeriod.end` | 1..1 | dateTime | si `Observation.component:LicensePeriod` |
| `Observation.component:Prospective.id` | 1..1 | String | si `Observation.component:Prospective` |
| `Observation.component:Prospective.code` | 1..1 | CodeableConcept | si `Observation.component:Prospective` |
| `Observation.component:Prospective.code.coding` | 1..1 | Coding | si `Observation.component:Prospective` |
| `Observation.component:Prospective.code.coding.system` | 1..1 | uri | si `Observation.component:Prospective` |
| `Observation.component:Prospective.code.coding.code` | 1..1 | code | si `Observation.component:Prospective` |
| `Observation.component:Prospective.code.coding.display` | 1..1 | string | si `Observation.component:Prospective` |
| `Observation.component:Prospective.code.text` | 1..1 | string | si `Observation.component:Prospective` |
| `Observation.component:Prospective.value[x]` | 1..1 | boolean | si `Observation.component:Prospective` |
| `Observation.component:Prospective.value[x]:valueBoolean` | 1..1 | boolean | si `Observation.component:Prospective` |
| `Observation.component:Retroactive.id` | 1..1 | String | si `Observation.component:Retroactive` |
| `Observation.component:Retroactive.code` | 1..1 | CodeableConcept | si `Observation.component:Retroactive` |
| `Observation.component:Retroactive.code.coding` | 1..1 | Coding | si `Observation.component:Retroactive` |
| `Observation.component:Retroactive.code.coding.system` | 1..1 | uri | si `Observation.component:Retroactive` |
| `Observation.component:Retroactive.code.coding.code` | 1..1 | code | si `Observation.component:Retroactive` |
| `Observation.component:Retroactive.code.coding.display` | 1..1 | string | si `Observation.component:Retroactive` |
| `Observation.component:Retroactive.code.text` | 1..1 | string | si `Observation.component:Retroactive` |
| `Observation.component:Retroactive.value[x]` | 1..1 | boolean | si `Observation.component:Retroactive` |
| `Observation.component:Retroactive.value[x]:valueBoolean` | 1..1 | boolean | si `Observation.component:Retroactive` |
| `Observation.component:RetroactiveReason.id` | 1..1 | String | si `Observation.component:RetroactiveReason` |
| `Observation.component:RetroactiveReason.code` | 1..1 | CodeableConcept | si `Observation.component:RetroactiveReason` |
| `Observation.component:RetroactiveReason.code.coding` | 1..1 | Coding | si `Observation.component:RetroactiveReason` |
| `Observation.component:RetroactiveReason.code.coding.system` | 1..1 | uri | si `Observation.component:RetroactiveReason` |
| `Observation.component:RetroactiveReason.code.coding.code` | 1..1 | code | si `Observation.component:RetroactiveReason` |
| `Observation.component:RetroactiveReason.code.coding.display` | 1..1 | string | si `Observation.component:RetroactiveReason` |
| `Observation.component:RetroactiveReason.code.text` | 1..1 | string | si `Observation.component:RetroactiveReason` |
| `Observation.component:RetroactiveReason.value[x]` | 1..1 | CodeableConcept | si `Observation.component:RetroactiveReason` |
| `Observation.component:RetroactiveReason.value[x]:valueCodeableConcept` | 1..1 | CodeableConcept | si `Observation.component:RetroactiveReason` |
| `Observation.component:RetroactiveReason.value[x]:valueCodeableConcept.coding` | 1..1 | Coding | si `Observation.component:RetroactiveReason` |
| `Observation.component:RetroactiveReason.value[x]:valueCodeableConcept.coding.system` | 1..1 | uri | si `Observation.component:RetroactiveReason` |
| `Observation.component:RetroactiveReason.value[x]:valueCodeableConcept.coding.code` | 1..1 | code | si `Observation.component:RetroactiveReason` |
| `Observation.component:RetroactiveReason.value[x]:valueCodeableConcept.coding.display` | 1..1 | string | si `Observation.component:RetroactiveReason` |
| `Observation.component:MemoryDisorder.id` | 1..1 | String | si `Observation.component:MemoryDisorder` |
| `Observation.component:MemoryDisorder.code` | 1..1 | CodeableConcept | si `Observation.component:MemoryDisorder` |
| `Observation.component:MemoryDisorder.code.coding` | 1..1 | Coding | si `Observation.component:MemoryDisorder` |
| `Observation.component:MemoryDisorder.code.coding.system` | 1..1 | uri | si `Observation.component:MemoryDisorder` |
| `Observation.component:MemoryDisorder.code.coding.code` | 1..1 | code | si `Observation.component:MemoryDisorder` |
| `Observation.component:MemoryDisorder.code.coding.display` | 1..1 | string | si `Observation.component:MemoryDisorder` |
| `Observation.component:MemoryDisorder.code.text` | 1..1 | string | si `Observation.component:MemoryDisorder` |
| `Observation.component:MemoryDisorder.value[x]` | 1..1 | CodeableConcept | si `Observation.component:MemoryDisorder` |
| `Observation.component:MemoryDisorder.value[x]:valueCodeableConcept` | 1..1 | CodeableConcept | si `Observation.component:MemoryDisorder` |
| `Observation.component:MemoryDisorder.value[x]:valueCodeableConcept.coding` | 1..1 | Coding | si `Observation.component:MemoryDisorder` |
| `Observation.component:MemoryDisorder.value[x]:valueCodeableConcept.coding.system` | 1..1 | uri | si `Observation.component:MemoryDisorder` |
| `Observation.component:MemoryDisorder.value[x]:valueCodeableConcept.coding.code` | 1..1 | code | si `Observation.component:MemoryDisorder` |
| `Observation.component:MemoryDisorder.value[x]:valueCodeableConcept.coding.display` | 1..1 | string | si `Observation.component:MemoryDisorder` |
| `Observation.component:MaternityLicenseTime.id` | 1..1 | String | si `Observation.component:MaternityLicenseTime` |
| `Observation.component:MaternityLicenseTime.code` | 1..1 | CodeableConcept | si `Observation.component:MaternityLicenseTime` |
| `Observation.component:MaternityLicenseTime.code.coding` | 1..1 | Coding | si `Observation.component:MaternityLicenseTime` |
| `Observation.component:MaternityLicenseTime.code.coding.system` | 1..1 | uri | si `Observation.component:MaternityLicenseTime` |
| `Observation.component:MaternityLicenseTime.code.coding.code` | 1..1 | code | si `Observation.component:MaternityLicenseTime` |
| `Observation.component:MaternityLicenseTime.code.coding.display` | 1..1 | string | si `Observation.component:MaternityLicenseTime` |
| `Observation.component:MaternityLicenseTime.code.text` | 1..1 | string | si `Observation.component:MaternityLicenseTime` |
| `Observation.component:MaternityLicenseTime.value[x]` | 1..1 | Quantity | si `Observation.component:MaternityLicenseTime` |
| `Observation.component:MaternityLicenseTime.value[x]:valueQuantity` | 1..1 | Quantity | si `Observation.component:MaternityLicenseTime` |
| `Observation.component:MaternityLicenseTime.value[x]:valueQuantity.value` | 1..1 | decimal | si `Observation.component:MaternityLicenseTime` |
| `Observation.component:MaternityLicenseTime.value[x]:valueQuantity.unit` | 1..1 | string | si `Observation.component:MaternityLicenseTime` |
| `Observation.component:MaternityLicenseTime.value[x]:valueQuantity.system` | 1..1 | uri | si `Observation.component:MaternityLicenseTime` |
| `Observation.component:MaternityLicenseTime.value[x]:valueQuantity.code` | 1..1 | code | si `Observation.component:MaternityLicenseTime` |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Observation.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/AttendanceAllowanceRDA"` |
| `Observation.status` | `fixedCode` | `"final"` |
| `Observation.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `Observation.code.coding.code` | `fixedCode` | `"160983005"` |
| `Observation.code.coding.display` | `patternString` | `"permiso de concurrencia"` |
| `Observation.code.text` | `fixedString` | `"Datos incapacidad (SIPE – Sistema de Incapacidades y Prestaciones Economicas)"` |
| `Observation.component:LicenseScope.id` | `patternString` | `"LicenseScope"` |
| `Observation.component:LicenseScope.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `Observation.component:LicenseScope.code.coding.code` | `fixedCode` | `"255590007"` |
| `Observation.component:LicenseScope.code.coding.display` | `fixedString` | `"alcance"` |
| `Observation.component:LicenseScope.code.text` | `fixedString` | `"Incapacidad - Alcance de la incapacidad"` |
| `Observation.component:LicenseScope.value[x]:valueCodeableConcept.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianLicenseScope"` |
| `Observation.component:LicenseTime.id` | `patternString` | `"LicenseTime"` |
| `Observation.component:LicenseTime.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `Observation.component:LicenseTime.code.coding.code` | `fixedCode` | `"410670007"` |
| `Observation.component:LicenseTime.code.coding.display` | `patternString` | `"tiempo"` |
| `Observation.component:LicenseTime.code.text` | `fixedString` | `"Días de incapacidad"` |
| `Observation.component:LicenseTime.value[x]:valueQuantity.unit` | `fixedString` | `"días"` |
| `Observation.component:LicenseTime.value[x]:valueQuantity.system` | `fixedUri` | `"http://unitsofmeasure.org"` |
| `Observation.component:LicenseTime.value[x]:valueQuantity.code` | `fixedCode` | `"d"` |
| `Observation.component:LicensePeriod.id` | `patternString` | `"LicensePeriod"` |
| `Observation.component:LicensePeriod.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `Observation.component:LicensePeriod.code.coding.code` | `fixedCode` | `"259037005"` |
| `Observation.component:LicensePeriod.code.coding.display` | `patternString` | `"por período"` |
| `Observation.component:LicensePeriod.code.text` | `fixedString` | `"Período de incapacidad"` |
| `Observation.component:Prospective.id` | `patternString` | `"Prospective"` |
| `Observation.component:Prospective.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `Observation.component:Prospective.code.coding.code` | `fixedCode` | `"255234002"` |
| `Observation.component:Prospective.code.coding.display` | `fixedString` | `"después"` |
| `Observation.component:Prospective.code.text` | `fixedString` | `"Incapacidad - Prospectiva"` |
| `Observation.component:Retroactive.id` | `patternString` | `"Retroactive"` |
| `Observation.component:Retroactive.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `Observation.component:Retroactive.code.coding.code` | `fixedCode` | `"288556008"` |
| `Observation.component:Retroactive.code.coding.display` | `fixedString` | `"antes"` |
| `Observation.component:Retroactive.code.text` | `fixedString` | `"Incapacidad - Retroactiva"` |
| `Observation.component:RetroactiveReason.id` | `patternString` | `"RetroactiveReason"` |
| `Observation.component:RetroactiveReason.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `Observation.component:RetroactiveReason.code.coding.code` | `fixedCode` | `"410666004"` |
| `Observation.component:RetroactiveReason.code.coding.display` | `fixedString` | `"motivo de"` |
| `Observation.component:RetroactiveReason.code.text` | `fixedString` | `"Incapacidad - Motivo de la retroactividad"` |
| `Observation.component:RetroactiveReason.value[x]:valueCodeableConcept.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianRetroactiveReason"` |
| `Observation.component:MemoryDisorder.id` | `patternString` | `"MemoryDisorder"` |
| `Observation.component:MemoryDisorder.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `Observation.component:MemoryDisorder.code.coding.code` | `fixedCode` | `"106136008"` |
| `Observation.component:MemoryDisorder.code.coding.display` | `fixedString` | `"hallazgo en el área de la memoria"` |
| `Observation.component:MemoryDisorder.code.text` | `fixedString` | `"Incapacidad - Motivo de la retroactividad - hallazgo en el área de la memoria"` |
| `Observation.component:MemoryDisorder.value[x]:valueCodeableConcept.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianMemoryDisorder"` |
| `Observation.component:MaternityLicenseTime.id` | `patternString` | `"MaternityLicenseTime"` |
| `Observation.component:MaternityLicenseTime.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `Observation.component:MaternityLicenseTime.code.coding.code` | `fixedCode` | `"410670007"` |
| `Observation.component:MaternityLicenseTime.code.coding.display` | `patternString` | `"tiempo"` |
| `Observation.component:MaternityLicenseTime.code.text` | `fixedString` | `"Días de licencia de maternidad"` |
| `Observation.component:MaternityLicenseTime.value[x]:valueQuantity.unit` | `fixedString` | `"días"` |
| `Observation.component:MaternityLicenseTime.value[x]:valueQuantity.system` | `fixedUri` | `"http://unitsofmeasure.org"` |
| `Observation.component:MaternityLicenseTime.value[x]:valueQuantity.code` | `fixedCode` | `"d"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Observation.component` | value:id ⚑ | closed | `LicenseScope` 1..1 BackboneElement<br>`LicenseTime` 0..1 BackboneElement<br>`LicensePeriod` 0..1 BackboneElement<br>`Prospective` 0..1 BackboneElement<br>`Retroactive` 0..1 BackboneElement<br>`RetroactiveReason` 0..1 BackboneElement<br>`MemoryDisorder` 0..1 BackboneElement<br>`MaternityLicenseTime` 0..1 BackboneElement |
| `Observation.component:LicenseScope.value[x]` | type:$this | closed | `valueCodeableConcept` 1..1 CodeableConcept |
| `Observation.component:LicenseTime.value[x]` | type:$this | closed | `valueQuantity` 1..1 Quantity |
| `Observation.component:LicensePeriod.value[x]` | type:$this | closed | `valuePeriod` 1..1 Period |
| `Observation.component:Prospective.value[x]` | type:$this | closed | `valueBoolean` 1..1 boolean |
| `Observation.component:Retroactive.value[x]` | type:$this | closed | `valueBoolean` 1..1 boolean |
| `Observation.component:RetroactiveReason.value[x]` | type:$this | closed | `valueCodeableConcept` 1..1 CodeableConcept |
| `Observation.component:MemoryDisorder.value[x]` | type:$this | closed | `valueCodeableConcept` 1..1 CodeableConcept |
| `Observation.component:MaternityLicenseTime.value[x]` | type:$this | closed | `valueQuantity` 1..1 Quantity |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Observation.component:LicenseScope.value[x]:valueCodeableConcept.coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianLicenseScopeCodes` |
| `Observation.component:RetroactiveReason.value[x]:valueCodeableConcept.coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianRetroactiveReasonCodes` |
| `Observation.component:MemoryDisorder.value[x]:valueCodeableConcept.coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianMemoryDisorderCodes` |

## BundleAmbulatoryRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/BundleAmbulatoryRDA`
- Tipo: `Bundle`; base: `http://hl7.org/fhir/StructureDefinition/Bundle`
- Descripción: Perfil FHIR de una paquete transaccional (Bundle) que contiene un documento FHIR RDA para el intercambio de información de un encuentro de atención de consulta.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Bundle.identifier.system` | 1..1 | uri | si `Bundle.identifier` |
| `Bundle.identifier.value` | 1..1 | string | si `Bundle.identifier` |
| `Bundle.type` | 1..1 | code |  |
| `Bundle.timestamp` | 1..1 | instant |  |
| `Bundle.link.relation` | 1..1 | string | si `Bundle.link` |
| `Bundle.link.url` | 1..1 | uri | si `Bundle.link` |
| `Bundle.entry` | 4..* | BackboneElement |  |
| `Bundle.entry.request.method` | 1..1 | code | si `Bundle.entry.request` |
| `Bundle.entry.request.url` | 1..1 | uri | si `Bundle.entry.request` |
| `Bundle.entry.response.status` | 1..1 | string | si `Bundle.entry.response` |
| `Bundle.entry:CompositionResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:CompositionResource.request.method` | 1..1 | code | si `Bundle.entry:CompositionResource.request` |
| `Bundle.entry:CompositionResource.request.url` | 1..1 | uri | si `Bundle.entry:CompositionResource.request` |
| `Bundle.entry:CompositionResource.response.status` | 1..1 | string | si `Bundle.entry:CompositionResource.response` |
| `Bundle.entry:PatientResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:PatientResource.request.method` | 1..1 | code | si `Bundle.entry:PatientResource.request` |
| `Bundle.entry:PatientResource.request.url` | 1..1 | uri | si `Bundle.entry:PatientResource.request` |
| `Bundle.entry:PatientResource.response.status` | 1..1 | string | si `Bundle.entry:PatientResource.response` |
| `Bundle.entry:CareDeliveryOrganizationResource.request.method` | 1..1 | code | si `Bundle.entry:CareDeliveryOrganizationResource` |
| `Bundle.entry:CareDeliveryOrganizationResource.request.url` | 1..1 | uri | si `Bundle.entry:CareDeliveryOrganizationResource` |
| `Bundle.entry:CareDeliveryOrganizationResource.response.status` | 1..1 | string | si `Bundle.entry:CareDeliveryOrganizationResource` |
| `Bundle.entry:PractitionerResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:PractitionerResource.request.method` | 1..1 | code | si `Bundle.entry:PractitionerResource.request` |
| `Bundle.entry:PractitionerResource.request.url` | 1..1 | uri | si `Bundle.entry:PractitionerResource.request` |
| `Bundle.entry:PractitionerResource.response.status` | 1..1 | string | si `Bundle.entry:PractitionerResource.response` |
| `Bundle.entry:PayorResources.request.method` | 1..1 | code | si `Bundle.entry:PayorResources` |
| `Bundle.entry:PayorResources.request.url` | 1..1 | uri | si `Bundle.entry:PayorResources` |
| `Bundle.entry:PayorResources.response.status` | 1..1 | string | si `Bundle.entry:PayorResources` |
| `Bundle.entry:ConditionResources.request.method` | 1..1 | code | si `Bundle.entry:ConditionResources` |
| `Bundle.entry:ConditionResources.request.url` | 1..1 | uri | si `Bundle.entry:ConditionResources` |
| `Bundle.entry:ConditionResources.response.status` | 1..1 | string | si `Bundle.entry:ConditionResources` |
| `Bundle.entry:AllergyIntoleranceIntoleranceResources.request.method` | 1..1 | code | si `Bundle.entry:AllergyIntoleranceIntoleranceResources` |
| `Bundle.entry:AllergyIntoleranceIntoleranceResources.request.url` | 1..1 | uri | si `Bundle.entry:AllergyIntoleranceIntoleranceResources` |
| `Bundle.entry:AllergyIntoleranceIntoleranceResources.response.status` | 1..1 | string | si `Bundle.entry:AllergyIntoleranceIntoleranceResources` |
| `Bundle.entry:MedicationRequestResources.request.method` | 1..1 | code | si `Bundle.entry:MedicationRequestResources` |
| `Bundle.entry:MedicationRequestResources.request.url` | 1..1 | uri | si `Bundle.entry:MedicationRequestResources` |
| `Bundle.entry:MedicationRequestResources.response.status` | 1..1 | string | si `Bundle.entry:MedicationRequestResources` |
| `Bundle.entry:ObservationAttendanceAllowanceResources.request.method` | 1..1 | code | si `Bundle.entry:ObservationAttendanceAllowanceResources` |
| `Bundle.entry:ObservationAttendanceAllowanceResources.request.url` | 1..1 | uri | si `Bundle.entry:ObservationAttendanceAllowanceResources` |
| `Bundle.entry:ObservationAttendanceAllowanceResources.response.status` | 1..1 | string | si `Bundle.entry:ObservationAttendanceAllowanceResources` |
| `Bundle.entry:ObservationPatientOccupationAtEncounterResources.request.method` | 1..1 | code | si `Bundle.entry:ObservationPatientOccupationAtEncounterResources` |
| `Bundle.entry:ObservationPatientOccupationAtEncounterResources.request.url` | 1..1 | uri | si `Bundle.entry:ObservationPatientOccupationAtEncounterResources` |
| `Bundle.entry:ObservationPatientOccupationAtEncounterResources.response.status` | 1..1 | string | si `Bundle.entry:ObservationPatientOccupationAtEncounterResources` |
| `Bundle.entry:RiskAssessmentResources.request.method` | 1..1 | code | si `Bundle.entry:RiskAssessmentResources` |
| `Bundle.entry:RiskAssessmentResources.request.url` | 1..1 | uri | si `Bundle.entry:RiskAssessmentResources` |
| `Bundle.entry:RiskAssessmentResources.response.status` | 1..1 | string | si `Bundle.entry:RiskAssessmentResources` |
| `Bundle.entry:ProcedureResources.request.method` | 1..1 | code | si `Bundle.entry:ProcedureResources` |
| `Bundle.entry:ProcedureResources.request.url` | 1..1 | uri | si `Bundle.entry:ProcedureResources` |
| `Bundle.entry:ProcedureResources.response.status` | 1..1 | string | si `Bundle.entry:ProcedureResources` |
| `Bundle.entry:ServiceRequestResources.request.method` | 1..1 | code | si `Bundle.entry:ServiceRequestResources` |
| `Bundle.entry:ServiceRequestResources.request.url` | 1..1 | uri | si `Bundle.entry:ServiceRequestResources` |
| `Bundle.entry:ServiceRequestResources.response.status` | 1..1 | string | si `Bundle.entry:ServiceRequestResources` |
| `Bundle.entry:ServiceRequestOtherTechnologyResources.request.method` | 1..1 | code | si `Bundle.entry:ServiceRequestOtherTechnologyResources` |
| `Bundle.entry:ServiceRequestOtherTechnologyResources.request.url` | 1..1 | uri | si `Bundle.entry:ServiceRequestOtherTechnologyResources` |
| `Bundle.entry:ServiceRequestOtherTechnologyResources.response.status` | 1..1 | string | si `Bundle.entry:ServiceRequestOtherTechnologyResources` |
| `Bundle.entry:DocumentReferenceResources` | 1..1 | BackboneElement |  |
| `Bundle.entry:DocumentReferenceResources.request.method` | 1..1 | code | si `Bundle.entry:DocumentReferenceResources.request` |
| `Bundle.entry:DocumentReferenceResources.request.url` | 1..1 | uri | si `Bundle.entry:DocumentReferenceResources.request` |
| `Bundle.entry:DocumentReferenceResources.response.status` | 1..1 | string | si `Bundle.entry:DocumentReferenceResources.response` |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Bundle.identifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/identifier-RDA"` |
| `Bundle.type` | `fixedCode` | `"document"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Bundle.entry` | type:resource, profile:resource | closed | `CompositionResource` 1..1 BackboneElement<br>`PatientResource` 1..1 BackboneElement<br>`CareDeliveryOrganizationResource` 0..1 BackboneElement<br>`PractitionerResource` 1..1 BackboneElement<br>`PayorResources` 0..* BackboneElement<br>`ConditionResources` 0..* BackboneElement<br>`AllergyIntoleranceIntoleranceResources` 0..* BackboneElement<br>`MedicationRequestResources` 0..* BackboneElement<br>`ObservationAttendanceAllowanceResources` 0..* BackboneElement<br>`ObservationPatientOccupationAtEncounterResources` 0..* BackboneElement<br>`RiskAssessmentResources` 0..* BackboneElement<br>`ProcedureResources` 0..* BackboneElement<br>`ServiceRequestResources` 0..* BackboneElement<br>`ServiceRequestOtherTechnologyResources` 0..* BackboneElement<br>`DocumentReferenceResources` 1..1 BackboneElement |

## BundleEmergencyRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/BundleEmergencyRDA`
- Tipo: `Bundle`; base: `http://hl7.org/fhir/StructureDefinition/Bundle`
- Descripción: Perfil FHIR de una paquete transaccional (Bundle) que contiene un documento FHIR RDA para el intercambio de información de un encuentro de atención de urgencias.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Bundle.identifier.system` | 1..1 | uri | si `Bundle.identifier` |
| `Bundle.identifier.value` | 1..1 | string | si `Bundle.identifier` |
| `Bundle.type` | 1..1 | code |  |
| `Bundle.timestamp` | 1..1 | instant |  |
| `Bundle.link.relation` | 1..1 | string | si `Bundle.link` |
| `Bundle.link.url` | 1..1 | uri | si `Bundle.link` |
| `Bundle.entry` | 5..* | BackboneElement |  |
| `Bundle.entry.request.method` | 1..1 | code | si `Bundle.entry.request` |
| `Bundle.entry.request.url` | 1..1 | uri | si `Bundle.entry.request` |
| `Bundle.entry.response.status` | 1..1 | string | si `Bundle.entry.response` |
| `Bundle.entry:CompositionResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:CompositionResource.request.method` | 1..1 | code | si `Bundle.entry:CompositionResource.request` |
| `Bundle.entry:CompositionResource.request.url` | 1..1 | uri | si `Bundle.entry:CompositionResource.request` |
| `Bundle.entry:CompositionResource.response.status` | 1..1 | string | si `Bundle.entry:CompositionResource.response` |
| `Bundle.entry:PatientResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:PatientResource.request.method` | 1..1 | code | si `Bundle.entry:PatientResource.request` |
| `Bundle.entry:PatientResource.request.url` | 1..1 | uri | si `Bundle.entry:PatientResource.request` |
| `Bundle.entry:PatientResource.response.status` | 1..1 | string | si `Bundle.entry:PatientResource.response` |
| `Bundle.entry:CareDeliveryOrganizationResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:CareDeliveryOrganizationResource.request.method` | 1..1 | code | si `Bundle.entry:CareDeliveryOrganizationResource.request` |
| `Bundle.entry:CareDeliveryOrganizationResource.request.url` | 1..1 | uri | si `Bundle.entry:CareDeliveryOrganizationResource.request` |
| `Bundle.entry:CareDeliveryOrganizationResource.response.status` | 1..1 | string | si `Bundle.entry:CareDeliveryOrganizationResource.response` |
| `Bundle.entry:PractitionerResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:PractitionerResource.request.method` | 1..1 | code | si `Bundle.entry:PractitionerResource.request` |
| `Bundle.entry:PractitionerResource.request.url` | 1..1 | uri | si `Bundle.entry:PractitionerResource.request` |
| `Bundle.entry:PractitionerResource.response.status` | 1..1 | string | si `Bundle.entry:PractitionerResource.response` |
| `Bundle.entry:PayorResources.request.method` | 1..1 | code | si `Bundle.entry:PayorResources` |
| `Bundle.entry:PayorResources.request.url` | 1..1 | uri | si `Bundle.entry:PayorResources` |
| `Bundle.entry:PayorResources.response.status` | 1..1 | string | si `Bundle.entry:PayorResources` |
| `Bundle.entry:ConditionResources.request.method` | 1..1 | code | si `Bundle.entry:ConditionResources` |
| `Bundle.entry:ConditionResources.request.url` | 1..1 | uri | si `Bundle.entry:ConditionResources` |
| `Bundle.entry:ConditionResources.response.status` | 1..1 | string | si `Bundle.entry:ConditionResources` |
| `Bundle.entry:ObservationTriageResources.request.method` | 1..1 | code | si `Bundle.entry:ObservationTriageResources` |
| `Bundle.entry:ObservationTriageResources.request.url` | 1..1 | uri | si `Bundle.entry:ObservationTriageResources` |
| `Bundle.entry:ObservationTriageResources.response.status` | 1..1 | string | si `Bundle.entry:ObservationTriageResources` |
| `Bundle.entry:AllergyIntoleranceIntoleranceResources.request.method` | 1..1 | code | si `Bundle.entry:AllergyIntoleranceIntoleranceResources` |
| `Bundle.entry:AllergyIntoleranceIntoleranceResources.request.url` | 1..1 | uri | si `Bundle.entry:AllergyIntoleranceIntoleranceResources` |
| `Bundle.entry:AllergyIntoleranceIntoleranceResources.response.status` | 1..1 | string | si `Bundle.entry:AllergyIntoleranceIntoleranceResources` |
| `Bundle.entry:MedicationAdministrationResources.request.method` | 1..1 | code | si `Bundle.entry:MedicationAdministrationResources` |
| `Bundle.entry:MedicationAdministrationResources.request.url` | 1..1 | uri | si `Bundle.entry:MedicationAdministrationResources` |
| `Bundle.entry:MedicationAdministrationResources.response.status` | 1..1 | string | si `Bundle.entry:MedicationAdministrationResources` |
| `Bundle.entry:MedicationRequestResources.request.method` | 1..1 | code | si `Bundle.entry:MedicationRequestResources` |
| `Bundle.entry:MedicationRequestResources.request.url` | 1..1 | uri | si `Bundle.entry:MedicationRequestResources` |
| `Bundle.entry:MedicationRequestResources.response.status` | 1..1 | string | si `Bundle.entry:MedicationRequestResources` |
| `Bundle.entry:ObservationAttendanceAllowanceResources.request.method` | 1..1 | code | si `Bundle.entry:ObservationAttendanceAllowanceResources` |
| `Bundle.entry:ObservationAttendanceAllowanceResources.request.url` | 1..1 | uri | si `Bundle.entry:ObservationAttendanceAllowanceResources` |
| `Bundle.entry:ObservationAttendanceAllowanceResources.response.status` | 1..1 | string | si `Bundle.entry:ObservationAttendanceAllowanceResources` |
| `Bundle.entry:ObservationPatientOccupationAtEncounterResources.request.method` | 1..1 | code | si `Bundle.entry:ObservationPatientOccupationAtEncounterResources` |
| `Bundle.entry:ObservationPatientOccupationAtEncounterResources.request.url` | 1..1 | uri | si `Bundle.entry:ObservationPatientOccupationAtEncounterResources` |
| `Bundle.entry:ObservationPatientOccupationAtEncounterResources.response.status` | 1..1 | string | si `Bundle.entry:ObservationPatientOccupationAtEncounterResources` |
| `Bundle.entry:RiskAssessmentResources.request.method` | 1..1 | code | si `Bundle.entry:RiskAssessmentResources` |
| `Bundle.entry:RiskAssessmentResources.request.url` | 1..1 | uri | si `Bundle.entry:RiskAssessmentResources` |
| `Bundle.entry:RiskAssessmentResources.response.status` | 1..1 | string | si `Bundle.entry:RiskAssessmentResources` |
| `Bundle.entry:ProcedureResources.request.method` | 1..1 | code | si `Bundle.entry:ProcedureResources` |
| `Bundle.entry:ProcedureResources.request.url` | 1..1 | uri | si `Bundle.entry:ProcedureResources` |
| `Bundle.entry:ProcedureResources.response.status` | 1..1 | string | si `Bundle.entry:ProcedureResources` |
| `Bundle.entry:ObservationResoultResources.request.method` | 1..1 | code | si `Bundle.entry:ObservationResoultResources` |
| `Bundle.entry:ObservationResoultResources.request.url` | 1..1 | uri | si `Bundle.entry:ObservationResoultResources` |
| `Bundle.entry:ObservationResoultResources.response.status` | 1..1 | string | si `Bundle.entry:ObservationResoultResources` |
| `Bundle.entry:ServiceRequestResources.request.method` | 1..1 | code | si `Bundle.entry:ServiceRequestResources` |
| `Bundle.entry:ServiceRequestResources.request.url` | 1..1 | uri | si `Bundle.entry:ServiceRequestResources` |
| `Bundle.entry:ServiceRequestResources.response.status` | 1..1 | string | si `Bundle.entry:ServiceRequestResources` |
| `Bundle.entry:ServiceRequestOtherTechnologyResources.request.method` | 1..1 | code | si `Bundle.entry:ServiceRequestOtherTechnologyResources` |
| `Bundle.entry:ServiceRequestOtherTechnologyResources.request.url` | 1..1 | uri | si `Bundle.entry:ServiceRequestOtherTechnologyResources` |
| `Bundle.entry:ServiceRequestOtherTechnologyResources.response.status` | 1..1 | string | si `Bundle.entry:ServiceRequestOtherTechnologyResources` |
| `Bundle.entry:DocumentReferenceResources` | 1..1 | BackboneElement |  |
| `Bundle.entry:DocumentReferenceResources.request.method` | 1..1 | code | si `Bundle.entry:DocumentReferenceResources.request` |
| `Bundle.entry:DocumentReferenceResources.request.url` | 1..1 | uri | si `Bundle.entry:DocumentReferenceResources.request` |
| `Bundle.entry:DocumentReferenceResources.response.status` | 1..1 | string | si `Bundle.entry:DocumentReferenceResources.response` |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Bundle.identifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/identifier-RDA"` |
| `Bundle.type` | `fixedCode` | `"document"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Bundle.entry` | type:resource, profile:resource | closed | `CompositionResource` 1..1 BackboneElement<br>`PatientResource` 1..1 BackboneElement<br>`CareDeliveryOrganizationResource` 1..1 BackboneElement<br>`PractitionerResource` 1..1 BackboneElement<br>`PayorResources` 0..* BackboneElement<br>`ConditionResources` 0..* BackboneElement<br>`ObservationTriageResources` 0..1 BackboneElement<br>`AllergyIntoleranceIntoleranceResources` 0..* BackboneElement<br>`MedicationAdministrationResources` 0..* BackboneElement<br>`MedicationRequestResources` 0..* BackboneElement<br>`ObservationAttendanceAllowanceResources` 0..* BackboneElement<br>`ObservationPatientOccupationAtEncounterResources` 0..* BackboneElement<br>`RiskAssessmentResources` 0..* BackboneElement<br>`ProcedureResources` 0..* BackboneElement<br>`ObservationResoultResources` 0..* BackboneElement<br>`ServiceRequestResources` 0..* BackboneElement<br>`ServiceRequestOtherTechnologyResources` 0..* BackboneElement<br>`DocumentReferenceResources` 1..1 BackboneElement |

## BundleHospitalizationRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/BundleHospitalizationRDA`
- Tipo: `Bundle`; base: `http://hl7.org/fhir/StructureDefinition/Bundle`
- Descripción: Perfil FHIR de una paquete transaccional (Bundle) que contiene un documento FHIR RDA para el intercambio de información de un encuentro de hospitalización.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Bundle.identifier.system` | 1..1 | uri | si `Bundle.identifier` |
| `Bundle.identifier.value` | 1..1 | string | si `Bundle.identifier` |
| `Bundle.type` | 1..1 | code |  |
| `Bundle.timestamp` | 1..1 | instant |  |
| `Bundle.link.relation` | 1..1 | string | si `Bundle.link` |
| `Bundle.link.url` | 1..1 | uri | si `Bundle.link` |
| `Bundle.entry` | 5..* | BackboneElement |  |
| `Bundle.entry.request.method` | 1..1 | code | si `Bundle.entry.request` |
| `Bundle.entry.request.url` | 1..1 | uri | si `Bundle.entry.request` |
| `Bundle.entry.response.status` | 1..1 | string | si `Bundle.entry.response` |
| `Bundle.entry:CompositionResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:CompositionResource.request.method` | 1..1 | code | si `Bundle.entry:CompositionResource.request` |
| `Bundle.entry:CompositionResource.request.url` | 1..1 | uri | si `Bundle.entry:CompositionResource.request` |
| `Bundle.entry:CompositionResource.response.status` | 1..1 | string | si `Bundle.entry:CompositionResource.response` |
| `Bundle.entry:PatientResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:PatientResource.request.method` | 1..1 | code | si `Bundle.entry:PatientResource.request` |
| `Bundle.entry:PatientResource.request.url` | 1..1 | uri | si `Bundle.entry:PatientResource.request` |
| `Bundle.entry:PatientResource.response.status` | 1..1 | string | si `Bundle.entry:PatientResource.response` |
| `Bundle.entry:CareDeliveryOrganizationResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:CareDeliveryOrganizationResource.request.method` | 1..1 | code | si `Bundle.entry:CareDeliveryOrganizationResource.request` |
| `Bundle.entry:CareDeliveryOrganizationResource.request.url` | 1..1 | uri | si `Bundle.entry:CareDeliveryOrganizationResource.request` |
| `Bundle.entry:CareDeliveryOrganizationResource.response.status` | 1..1 | string | si `Bundle.entry:CareDeliveryOrganizationResource.response` |
| `Bundle.entry:PractitionerResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:PractitionerResource.request.method` | 1..1 | code | si `Bundle.entry:PractitionerResource.request` |
| `Bundle.entry:PractitionerResource.request.url` | 1..1 | uri | si `Bundle.entry:PractitionerResource.request` |
| `Bundle.entry:PractitionerResource.response.status` | 1..1 | string | si `Bundle.entry:PractitionerResource.response` |
| `Bundle.entry:PayorResources.request.method` | 1..1 | code | si `Bundle.entry:PayorResources` |
| `Bundle.entry:PayorResources.request.url` | 1..1 | uri | si `Bundle.entry:PayorResources` |
| `Bundle.entry:PayorResources.response.status` | 1..1 | string | si `Bundle.entry:PayorResources` |
| `Bundle.entry:ConditionResources.request.method` | 1..1 | code | si `Bundle.entry:ConditionResources` |
| `Bundle.entry:ConditionResources.request.url` | 1..1 | uri | si `Bundle.entry:ConditionResources` |
| `Bundle.entry:ConditionResources.response.status` | 1..1 | string | si `Bundle.entry:ConditionResources` |
| `Bundle.entry:AllergyIntoleranceIntoleranceResources.request.method` | 1..1 | code | si `Bundle.entry:AllergyIntoleranceIntoleranceResources` |
| `Bundle.entry:AllergyIntoleranceIntoleranceResources.request.url` | 1..1 | uri | si `Bundle.entry:AllergyIntoleranceIntoleranceResources` |
| `Bundle.entry:AllergyIntoleranceIntoleranceResources.response.status` | 1..1 | string | si `Bundle.entry:AllergyIntoleranceIntoleranceResources` |
| `Bundle.entry:MedicationAdministrationResources.request.method` | 1..1 | code | si `Bundle.entry:MedicationAdministrationResources` |
| `Bundle.entry:MedicationAdministrationResources.request.url` | 1..1 | uri | si `Bundle.entry:MedicationAdministrationResources` |
| `Bundle.entry:MedicationAdministrationResources.response.status` | 1..1 | string | si `Bundle.entry:MedicationAdministrationResources` |
| `Bundle.entry:MedicationRequestResources.request.method` | 1..1 | code | si `Bundle.entry:MedicationRequestResources` |
| `Bundle.entry:MedicationRequestResources.request.url` | 1..1 | uri | si `Bundle.entry:MedicationRequestResources` |
| `Bundle.entry:MedicationRequestResources.response.status` | 1..1 | string | si `Bundle.entry:MedicationRequestResources` |
| `Bundle.entry:ObservationAttendanceAllowanceResources.request.method` | 1..1 | code | si `Bundle.entry:ObservationAttendanceAllowanceResources` |
| `Bundle.entry:ObservationAttendanceAllowanceResources.request.url` | 1..1 | uri | si `Bundle.entry:ObservationAttendanceAllowanceResources` |
| `Bundle.entry:ObservationAttendanceAllowanceResources.response.status` | 1..1 | string | si `Bundle.entry:ObservationAttendanceAllowanceResources` |
| `Bundle.entry:ObservationPatientOccupationAtEncounterResources.request.method` | 1..1 | code | si `Bundle.entry:ObservationPatientOccupationAtEncounterResources` |
| `Bundle.entry:ObservationPatientOccupationAtEncounterResources.request.url` | 1..1 | uri | si `Bundle.entry:ObservationPatientOccupationAtEncounterResources` |
| `Bundle.entry:ObservationPatientOccupationAtEncounterResources.response.status` | 1..1 | string | si `Bundle.entry:ObservationPatientOccupationAtEncounterResources` |
| `Bundle.entry:RiskAssessmentResources.request.method` | 1..1 | code | si `Bundle.entry:RiskAssessmentResources` |
| `Bundle.entry:RiskAssessmentResources.request.url` | 1..1 | uri | si `Bundle.entry:RiskAssessmentResources` |
| `Bundle.entry:RiskAssessmentResources.response.status` | 1..1 | string | si `Bundle.entry:RiskAssessmentResources` |
| `Bundle.entry:ProcedureResources.request.method` | 1..1 | code | si `Bundle.entry:ProcedureResources` |
| `Bundle.entry:ProcedureResources.request.url` | 1..1 | uri | si `Bundle.entry:ProcedureResources` |
| `Bundle.entry:ProcedureResources.response.status` | 1..1 | string | si `Bundle.entry:ProcedureResources` |
| `Bundle.entry:ObservationResoultResources.request.method` | 1..1 | code | si `Bundle.entry:ObservationResoultResources` |
| `Bundle.entry:ObservationResoultResources.request.url` | 1..1 | uri | si `Bundle.entry:ObservationResoultResources` |
| `Bundle.entry:ObservationResoultResources.response.status` | 1..1 | string | si `Bundle.entry:ObservationResoultResources` |
| `Bundle.entry:ServiceRequestResources.request.method` | 1..1 | code | si `Bundle.entry:ServiceRequestResources` |
| `Bundle.entry:ServiceRequestResources.request.url` | 1..1 | uri | si `Bundle.entry:ServiceRequestResources` |
| `Bundle.entry:ServiceRequestResources.response.status` | 1..1 | string | si `Bundle.entry:ServiceRequestResources` |
| `Bundle.entry:ServiceRequestOtherTechnologyResources.request.method` | 1..1 | code | si `Bundle.entry:ServiceRequestOtherTechnologyResources` |
| `Bundle.entry:ServiceRequestOtherTechnologyResources.request.url` | 1..1 | uri | si `Bundle.entry:ServiceRequestOtherTechnologyResources` |
| `Bundle.entry:ServiceRequestOtherTechnologyResources.response.status` | 1..1 | string | si `Bundle.entry:ServiceRequestOtherTechnologyResources` |
| `Bundle.entry:DocumentReferenceResources` | 1..1 | BackboneElement |  |
| `Bundle.entry:DocumentReferenceResources.request.method` | 1..1 | code | si `Bundle.entry:DocumentReferenceResources.request` |
| `Bundle.entry:DocumentReferenceResources.request.url` | 1..1 | uri | si `Bundle.entry:DocumentReferenceResources.request` |
| `Bundle.entry:DocumentReferenceResources.response.status` | 1..1 | string | si `Bundle.entry:DocumentReferenceResources.response` |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Bundle.identifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/identifier-RDA"` |
| `Bundle.type` | `fixedCode` | `"document"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Bundle.entry` | type:resource, profile:resource | closed | `CompositionResource` 1..1 BackboneElement<br>`PatientResource` 1..1 BackboneElement<br>`CareDeliveryOrganizationResource` 1..1 BackboneElement<br>`PractitionerResource` 1..1 BackboneElement<br>`PayorResources` 0..* BackboneElement<br>`ConditionResources` 0..* BackboneElement<br>`AllergyIntoleranceIntoleranceResources` 0..* BackboneElement<br>`MedicationAdministrationResources` 0..* BackboneElement<br>`MedicationRequestResources` 0..* BackboneElement<br>`ObservationAttendanceAllowanceResources` 0..* BackboneElement<br>`ObservationPatientOccupationAtEncounterResources` 0..* BackboneElement<br>`RiskAssessmentResources` 0..* BackboneElement<br>`ProcedureResources` 0..* BackboneElement<br>`ObservationResoultResources` 0..* BackboneElement<br>`ServiceRequestResources` 0..* BackboneElement<br>`ServiceRequestOtherTechnologyResources` 0..* BackboneElement<br>`DocumentReferenceResources` 1..1 BackboneElement |

## BundlePatientStatementRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/BundlePatientStatementRDA`
- Tipo: `Bundle`; base: `http://hl7.org/fhir/StructureDefinition/Bundle`
- Descripción: Perfil FHIR de una paquete transaccional (Bundle) que contiene un documento FHIR RDA para el intercambio inicial de antecedentes del paciente en Colombia.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Bundle.identifier.system` | 1..1 | uri | si `Bundle.identifier` |
| `Bundle.identifier.value` | 1..1 | string | si `Bundle.identifier` |
| `Bundle.type` | 1..1 | code |  |
| `Bundle.timestamp` | 1..1 | instant |  |
| `Bundle.link.relation` | 1..1 | string | si `Bundle.link` |
| `Bundle.link.url` | 1..1 | uri | si `Bundle.link` |
| `Bundle.entry` | 3..* | BackboneElement |  |
| `Bundle.entry.request.method` | 1..1 | code | si `Bundle.entry.request` |
| `Bundle.entry.request.url` | 1..1 | uri | si `Bundle.entry.request` |
| `Bundle.entry.response.status` | 1..1 | string | si `Bundle.entry.response` |
| `Bundle.entry:CompositionResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:CompositionResource.request.method` | 1..1 | code | si `Bundle.entry:CompositionResource.request` |
| `Bundle.entry:CompositionResource.request.url` | 1..1 | uri | si `Bundle.entry:CompositionResource.request` |
| `Bundle.entry:CompositionResource.response.status` | 1..1 | string | si `Bundle.entry:CompositionResource.response` |
| `Bundle.entry:PatientResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:PatientResource.request.method` | 1..1 | code | si `Bundle.entry:PatientResource.request` |
| `Bundle.entry:PatientResource.request.url` | 1..1 | uri | si `Bundle.entry:PatientResource.request` |
| `Bundle.entry:PatientResource.response.status` | 1..1 | string | si `Bundle.entry:PatientResource.response` |
| `Bundle.entry:CareDeliveryOrganizationResource.request.method` | 1..1 | code | si `Bundle.entry:CareDeliveryOrganizationResource` |
| `Bundle.entry:CareDeliveryOrganizationResource.request.url` | 1..1 | uri | si `Bundle.entry:CareDeliveryOrganizationResource` |
| `Bundle.entry:CareDeliveryOrganizationResource.response.status` | 1..1 | string | si `Bundle.entry:CareDeliveryOrganizationResource` |
| `Bundle.entry:PractitionerResource` | 1..1 | BackboneElement |  |
| `Bundle.entry:PractitionerResource.request.method` | 1..1 | code | si `Bundle.entry:PractitionerResource.request` |
| `Bundle.entry:PractitionerResource.request.url` | 1..1 | uri | si `Bundle.entry:PractitionerResource.request` |
| `Bundle.entry:PractitionerResource.response.status` | 1..1 | string | si `Bundle.entry:PractitionerResource.response` |
| `Bundle.entry:ConditionResources.request.method` | 1..1 | code | si `Bundle.entry:ConditionResources` |
| `Bundle.entry:ConditionResources.request.url` | 1..1 | uri | si `Bundle.entry:ConditionResources` |
| `Bundle.entry:ConditionResources.response.status` | 1..1 | string | si `Bundle.entry:ConditionResources` |
| `Bundle.entry:AllergyIntoleranceIntoleranceResources.request.method` | 1..1 | code | si `Bundle.entry:AllergyIntoleranceIntoleranceResources` |
| `Bundle.entry:AllergyIntoleranceIntoleranceResources.request.url` | 1..1 | uri | si `Bundle.entry:AllergyIntoleranceIntoleranceResources` |
| `Bundle.entry:AllergyIntoleranceIntoleranceResources.response.status` | 1..1 | string | si `Bundle.entry:AllergyIntoleranceIntoleranceResources` |
| `Bundle.entry:MedicationStatementResources.request.method` | 1..1 | code | si `Bundle.entry:MedicationStatementResources` |
| `Bundle.entry:MedicationStatementResources.request.url` | 1..1 | uri | si `Bundle.entry:MedicationStatementResources` |
| `Bundle.entry:MedicationStatementResources.response.status` | 1..1 | string | si `Bundle.entry:MedicationStatementResources` |
| `Bundle.entry:FamilyMemberHistoryResources.request.method` | 1..1 | code | si `Bundle.entry:FamilyMemberHistoryResources` |
| `Bundle.entry:FamilyMemberHistoryResources.request.url` | 1..1 | uri | si `Bundle.entry:FamilyMemberHistoryResources` |
| `Bundle.entry:FamilyMemberHistoryResources.response.status` | 1..1 | string | si `Bundle.entry:FamilyMemberHistoryResources` |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Bundle.identifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/identifier-RDA"` |
| `Bundle.type` | `fixedCode` | `"document"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Bundle.entry` | type:resource, profile:resource | closed | `CompositionResource` 1..1 BackboneElement<br>`PatientResource` 1..1 BackboneElement<br>`CareDeliveryOrganizationResource` 0..1 BackboneElement<br>`PractitionerResource` 1..1 BackboneElement<br>`ConditionResources` 0..* BackboneElement<br>`AllergyIntoleranceIntoleranceResources` 0..* BackboneElement<br>`MedicationStatementResources` 0..* BackboneElement<br>`FamilyMemberHistoryResources` 0..* BackboneElement |

## CareDeliveryLocationRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/CareDeliveryLocationRDA`
- Tipo: `Location`; base: `http://hl7.org/fhir/StructureDefinition/Location`
- Descripción: Perfil FHIR de un Punto de Atención en Salud (Location), para su intercambio en un documento RDA en Colombia.  Representa un punto de atención en salud, entendido como un lugar físico donde una Institución Prestadora de Servicios de Salud (IPS) realiza actividades asistenciales, administrativas o de apoyo. Puede corresponder a una sede principal, una sede alterna, un consultorio, una unidad móvil, un puesto de salud u otro espacio habilitado por la autoridad sanitaria competente para brindar servicios de salud a la población, conforme a la normatividad vigente del sistema de habilitación en Colombia.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Location.meta.profile` | 1..* | canonical(StructureDefinition) | si `Location.meta` |
| `Location.identifier` | 1..1 | Identifier |  |
| `Location.identifier:REPS.system` | 1..1 | uri | si `Location.identifier:REPS` |
| `Location.identifier:REPS.value` | 1..1 | string | si `Location.identifier:REPS` |
| `Location.identifier:NoREPS.system` | 1..1 | uri | si `Location.identifier:NoREPS` |
| `Location.identifier:NoREPS.value` | 1..1 | string | si `Location.identifier:NoREPS` |
| `Location.status` | 1..1 | code |  |
| `Location.name` | 1..1 | string |  |
| `Location.address.use` | 1..1 | code | si `Location.address` |
| `Location.address.type` | 1..1 | code | si `Location.address` |
| `Location.address.city` | 1..1 | string | si `Location.address` |
| `Location.address.state` | 1..1 | string | si `Location.address` |
| `Location.address.country` | 1..1 | string | si `Location.address` |
| `Location.managingOrganization` | 1..1 | Reference(CareDeliveryOrganizationRDA) |  |

### Must-support opcionales

`Location.address.city.extension:ExtensionDivipolaMunicipality` 0..1 · `Location.address.state.extension:ExtensionDivipolaDepartment` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Location.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/CareDeliveryLocationRDA"` |
| `Location.identifier:REPS.use` | `fixedCode` | `"official"` |
| `Location.identifier:REPS.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/REPS"` |
| `Location.identifier:NoREPS.use` | `fixedCode` | `"official"` |
| `Location.identifier:NoREPS.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/NoREPS"` |
| `Location.mode` | `fixedCode` | `"instance"` |
| `Location.address.use` | `fixedCode` | `"work"` |
| `Location.address.type` | `fixedCode` | `"physical"` |
| `Location.address.country` | `fixedString` | `"CO"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Location.identifier` | value:system | open | `REPS` 0..1 Identifier<br>`NoREPS` 0..1 Identifier |
| `Location.address.city.extension` | value:url | open | `ExtensionDivipolaMunicipality` 0..1 Extension(ExtensionDivipolaMunicipality) |
| `Location.address.state.extension` | value:url | open | `ExtensionDivipolaDepartment` 0..1 Extension(ExtensionDivipolaDepartment) |

## CareDeliveryOrganizationRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/CareDeliveryOrganizationRDA`
- Tipo: `Organization`; base: `http://hl7.org/fhir/StructureDefinition/Organization`
- Descripción: Perfil FHIR de una Institución Prestadora de Servicios de Salud (IPS), para su intercambio en un documento RDA en Colombia.  Información sobre una Institución Prestadora de Servicios de Salud (IPS). Es una entidad, pública o privada, legalmente constituida y habilitada por la autoridad sanitaria competente en Colombia, cuya finalidad es ofrecer, de manera directa o a través de terceros, servicios de salud a las personas, en los diferentes niveles de atención y modalidades (ambulatoria, hospitalaria, de urgencias, domiciliaria, entre otras), conforme a los estándares técnicos, administrativos y de calidad establecidos en la normatividad vigente.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Organization.meta.profile` | 1..* | canonical(StructureDefinition) | si `Organization.meta` |
| `Organization.identifier` | 2..2 | Identifier |  |
| `Organization.identifier:TaxIdentifier` | 1..1 | Identifier |  |
| `Organization.identifier:TaxIdentifier.id` | 1..1 | String |  |
| `Organization.identifier:TaxIdentifier.use` | 1..1 | code |  |
| `Organization.identifier:TaxIdentifier.type` | 1..1 | CodeableConcept |  |
| `Organization.identifier:TaxIdentifier.type.coding` | 2..2 | Coding |  |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode` | 1..1 | Coding |  |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode.system` | 1..1 | uri |  |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode.code` | 1..1 | code |  |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode.display` | 1..1 | string |  |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode` | 1..1 | Coding |  |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode.system` | 1..1 | uri |  |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode.code` | 1..1 | code |  |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode.display` | 1..1 | string |  |
| `Organization.identifier:TaxIdentifier.value` | 1..1 | string |  |
| `Organization.identifier:TaxIdentifier.period.start` | 1..1 | dateTime | si `Organization.identifier:TaxIdentifier.period` |
| `Organization.identifier:HealthcareProviderIdentifier` | 1..1 | Identifier |  |
| `Organization.identifier:HealthcareProviderIdentifier.id` | 1..1 | String |  |
| `Organization.identifier:HealthcareProviderIdentifier.use` | 1..1 | code |  |
| `Organization.identifier:HealthcareProviderIdentifier.type` | 1..1 | CodeableConcept |  |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding` | 2..2 | Coding |  |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:InternationalCode` | 1..1 | Coding |  |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:InternationalCode.system` | 1..1 | uri |  |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:InternationalCode.code` | 1..1 | code |  |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:InternationalCode.display` | 1..1 | string |  |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:ColombianCode` | 1..1 | Coding |  |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:ColombianCode.system` | 1..1 | uri |  |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:ColombianCode.code` | 1..1 | code |  |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:ColombianCode.display` | 1..1 | string |  |
| `Organization.identifier:HealthcareProviderIdentifier.value` | 1..1 | string |  |
| `Organization.identifier:HealthcareProviderIdentifier.period.start` | 1..1 | dateTime | si `Organization.identifier:HealthcareProviderIdentifier.period` |
| `Organization.active` | 1..1 | boolean |  |
| `Organization.type` | 1..4 | CodeableConcept |  |
| `Organization.type:ProviderClass` | 1..1 | CodeableConcept |  |
| `Organization.type:ProviderClass.coding` | 1..1 | Coding |  |
| `Organization.type:ProviderClass.coding.system` | 1..1 | uri |  |
| `Organization.type:ProviderClass.coding.code` | 1..1 | code |  |
| `Organization.type:ProviderClass.coding.display` | 1..1 | string |  |
| `Organization.type:LegalNatureType.coding` | 1..1 | Coding | si `Organization.type:LegalNatureType` |
| `Organization.type:LegalNatureType.coding.system` | 1..1 | uri | si `Organization.type:LegalNatureType` |
| `Organization.type:LegalNatureType.coding.code` | 1..1 | code | si `Organization.type:LegalNatureType` |
| `Organization.type:LegalNatureType.coding.display` | 1..1 | string | si `Organization.type:LegalNatureType` |
| `Organization.type:HealthcareLevel.coding` | 1..1 | Coding | si `Organization.type:HealthcareLevel` |
| `Organization.type:HealthcareLevel.coding.system` | 1..1 | uri | si `Organization.type:HealthcareLevel` |
| `Organization.type:HealthcareLevel.coding.code` | 1..1 | code | si `Organization.type:HealthcareLevel` |
| `Organization.type:HealthcareLevel.coding.display` | 1..1 | string | si `Organization.type:HealthcareLevel` |
| `Organization.name` | 1..1 | string |  |
| `Organization.telecom:TelecomPhone.id` | 1..1 | String | si `Organization.telecom:TelecomPhone` |
| `Organization.telecom:TelecomPhone.system` | 1..1 | code | si `Organization.telecom:TelecomPhone` |
| `Organization.telecom:TelecomPhone.value` | 1..1 | string | si `Organization.telecom:TelecomPhone` |
| `Organization.telecom:TelecomMobile.id` | 1..1 | String | si `Organization.telecom:TelecomMobile` |
| `Organization.telecom:TelecomMobile.system` | 1..1 | code | si `Organization.telecom:TelecomMobile` |
| `Organization.telecom:TelecomMobile.value` | 1..1 | string | si `Organization.telecom:TelecomMobile` |
| `Organization.telecom:TelecomMobile.use` | 1..1 | code | si `Organization.telecom:TelecomMobile` |
| `Organization.telecom:TelecomEmail.id` | 1..1 | String | si `Organization.telecom:TelecomEmail` |
| `Organization.telecom:TelecomEmail.system` | 1..1 | code | si `Organization.telecom:TelecomEmail` |
| `Organization.telecom:TelecomEmail.value` | 1..1 | string | si `Organization.telecom:TelecomEmail` |
| `Organization.telecom:TelecomURL.id` | 1..1 | String | si `Organization.telecom:TelecomURL` |
| `Organization.telecom:TelecomURL.system` | 1..1 | code | si `Organization.telecom:TelecomURL` |
| `Organization.telecom:TelecomURL.value` | 1..1 | string | si `Organization.telecom:TelecomURL` |
| `Organization.address` | 1..* | Address |  |
| `Organization.address.use` | 1..1 | code |  |
| `Organization.address.type` | 1..1 | code |  |
| `Organization.address.text` | 1..1 | string |  |
| `Organization.address.city` | 1..1 | string |  |
| `Organization.address.state` | 1..1 | string |  |
| `Organization.address.country` | 1..1 | string |  |

### Must-support opcionales

`Organization.type:LegalNatureType` 0..1 · `Organization.type:HealthcareLevel` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Organization.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/CareDeliveryOrganizationRDA"` |
| `Organization.identifier:TaxIdentifier.id` | `patternString` | `"TaxIdentifier-0"` |
| `Organization.identifier:TaxIdentifier.use` | `fixedCode` | `"official"` |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v2-0203"` |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode.code` | `fixedCode` | `"TAX"` |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode.display` | `fixedString` | `"Tax ID number"` |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianOrganizationIdentifiers"` |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode.code` | `fixedCode` | `"NIT"` |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode.display` | `fixedString` | `"Número de Identificación Tributaria"` |
| `Organization.identifier:TaxIdentifier.system` | `patternUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/DIAN"` |
| `Organization.identifier:TaxIdentifier.assigner.display` | `fixedString` | `"DIAN"` |
| `Organization.identifier:HealthcareProviderIdentifier.id` | `patternString` | `"HealthcareProviderIdentifier-0"` |
| `Organization.identifier:HealthcareProviderIdentifier.use` | `fixedCode` | `"official"` |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:InternationalCode.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v2-0203"` |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:InternationalCode.code` | `fixedCode` | `"PRN"` |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:InternationalCode.display` | `fixedString` | `"Provider number"` |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:ColombianCode.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianOrganizationIdentifiers"` |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:ColombianCode.code` | `fixedCode` | `"CodigoPrestador"` |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:ColombianCode.display` | `fixedString` | `"Código de habilitación de prestador de servicios de salud"` |
| `Organization.identifier:HealthcareProviderIdentifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/REPS"` |
| `Organization.type:ProviderClass.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianProviderClass"` |
| `Organization.type:LegalNatureType.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianLegalNatureType"` |
| `Organization.type:HealthcareLevel.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianHealthcareLevel"` |
| `Organization.telecom:TelecomPhone.id` | `patternString` | `"TelecomPhone-0"` |
| `Organization.telecom:TelecomPhone.system` | `fixedCode` | `"phone"` |
| `Organization.telecom:TelecomMobile.id` | `patternString` | `"TelecomMobile-0"` |
| `Organization.telecom:TelecomMobile.system` | `fixedCode` | `"phone"` |
| `Organization.telecom:TelecomMobile.use` | `fixedCode` | `"mobile"` |
| `Organization.telecom:TelecomEmail.id` | `patternString` | `"TelecomEmail-0"` |
| `Organization.telecom:TelecomEmail.system` | `fixedCode` | `"email"` |
| `Organization.telecom:TelecomURL.id` | `patternString` | `"TelecomURL-0"` |
| `Organization.telecom:TelecomURL.system` | `fixedCode` | `"url"` |
| `Organization.address.use` | `fixedCode` | `"work"` |
| `Organization.address.type` | `fixedCode` | `"physical"` |
| `Organization.address.country` | `fixedString` | `"CO"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Organization.identifier` | value:id ⚑ | open | `TaxIdentifier` 1..1 Identifier<br>`HealthcareProviderIdentifier` 1..1 Identifier |
| `Organization.identifier:TaxIdentifier.type.coding` | value:system | open | `InternationalCode` 1..1 Coding<br>`ColombianCode` 1..1 Coding |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding` | value:system | open | `InternationalCode` 1..1 Coding<br>`ColombianCode` 1..1 Coding |
| `Organization.type` | value:coding.system | open | `ProviderClass` 1..1 CodeableConcept<br>`LegalNatureType` 0..1 CodeableConcept<br>`HealthcareLevel` 0..1 CodeableConcept<br>`TerritorialJurisdiction` 0..1 CodeableConcept |
| `Organization.telecom` | value:id ⚑ | open | `TelecomPhone` 0..* ContactPoint<br>`TelecomMobile` 0..* ContactPoint<br>`TelecomEmail` 0..* ContactPoint<br>`TelecomURL` 0..* ContactPoint |
| `Organization.address.city.extension` | value:url | open | `ExtensionDivipolaMunicipality` 0..1 Extension(ExtensionDivipolaMunicipality) |
| `Organization.address.state.extension` | value:url | open | `ExtensionDivipolaDepartment` 0..1 Extension(ExtensionDivipolaDepartment) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianOrganizationIdentifierCodes` |
| `Organization.identifier:HealthcareProviderIdentifier.type.coding:ColombianCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianOrganizationIdentifierCodes` |
| `Organization.type:ProviderClass` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianProviderClassCodes` |
| `Organization.type:LegalNatureType` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianLegalNatureTypeCodes` |
| `Organization.type:HealthcareLevel` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianHealthcareLevelCodes` |

## CompositionAmbulatoryRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/CompositionAmbulatoryRDA`
- Tipo: `Composition`; base: `http://hl7.org/fhir/StructureDefinition/Composition`
- Descripción: Perfil FHIR RDA del Resumen Digital de Atención en Salud en Colombia, para encuentros de Consulta.  Documento clínico estructurado que consolida y resume la información relevante de un proceso de atención en salud de un paciente, integrando datos clínicos esenciales para facilitar la continuidad del cuidado y el intercambio de información entre profesionales e instituciones.  El Resumen Digital de Atención en Salud (RDA) incluye información como motivos de consulta, diagnósticos, procedimientos realizados, medicamentos prescritos, antecedentes relevantes, exámenes de apoyo diagnóstico y planes de manejo, registrados por un profesional de la salud autorizado y habilitado, de acuerdo con los lineamientos establecidos por la normativa colombiana.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Composition.meta.profile` | 1..* | canonical(StructureDefinition) | si `Composition.meta` |
| `Composition.status` | 1..1 | code |  |
| `Composition.type` | 1..1 | CodeableConcept |  |
| `Composition.type.coding.system` | 1..1 | uri | si `Composition.type.coding` |
| `Composition.subject` | 1..1 | Reference(PatientRDA) |  |
| `Composition.subject.reference` | 1..1 | string |  |
| `Composition.encounter` | 1..1 | Reference(EncounterAmbulatoryRDA) |  |
| `Composition.encounter.reference` | 1..1 | string |  |
| `Composition.date` | 1..1 | dateTime |  |
| `Composition.author` | 1..1 | Reference(CareDeliveryOrganizationRDA, PractitionerRDA) |  |
| `Composition.title` | 1..1 | string |  |
| `Composition.attester.mode` | 1..1 | code | si `Composition.attester` |
| `Composition.custodian` | 1..1 | Reference(CareDeliveryOrganizationRDA) |  |
| `Composition.relatesTo.code` | 1..1 | code | si `Composition.relatesTo` |
| `Composition.relatesTo.target[x]` | 1..1 | Reference(CompositionPatientStatementRDA) | si `Composition.relatesTo` |
| `Composition.section` | 9..10 | BackboneElement |  |
| `Composition.section:sectionPayers` | 1..1 | BackboneElement |  |
| `Composition.section:sectionPayers.title` | 1..1 | string |  |
| `Composition.section:sectionPayers.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionPayers.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionPayers.emptyReason` |
| `Composition.section:sectionPayers.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionPayers.emptyReason` |
| `Composition.section:sectionPayers.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionPayers.emptyReason` |
| `Composition.section:sectionHistoryOfOccupation` | 1..1 | BackboneElement |  |
| `Composition.section:sectionHistoryOfOccupation.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionHistoryOfOccupation.emptyReason` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionHistoryOfOccupation.emptyReason` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionHistoryOfOccupation.emptyReason` |
| `Composition.section:sectionAttendanceAllowance` | 1..1 | BackboneElement |  |
| `Composition.section:sectionAttendanceAllowance.title` | 1..1 | string |  |
| `Composition.section:sectionAttendanceAllowance.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionAttendanceAllowance.emptyReason` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionAttendanceAllowance.emptyReason` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionAttendanceAllowance.emptyReason` |
| `Composition.section:sectionMedications` | 1..1 | BackboneElement |  |
| `Composition.section:sectionMedications.title` | 1..1 | string |  |
| `Composition.section:sectionMedications.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionMedications.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionMedications.emptyReason` |
| `Composition.section:sectionMedications.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionMedications.emptyReason` |
| `Composition.section:sectionMedications.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionMedications.emptyReason` |
| `Composition.section:sectionAllergies` | 1..1 | BackboneElement |  |
| `Composition.section:sectionAllergies.title` | 1..1 | string |  |
| `Composition.section:sectionAllergies.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionAllergies.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionAllergies.emptyReason` |
| `Composition.section:sectionAllergies.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionAllergies.emptyReason` |
| `Composition.section:sectionAllergies.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionAllergies.emptyReason` |
| `Composition.section:sectionProblems` | 1..1 | BackboneElement |  |
| `Composition.section:sectionProblems.title` | 1..1 | string |  |
| `Composition.section:sectionProblems.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionProblems.entry` | 1..* | Reference(ConditionRDA) |  |
| `Composition.section:sectionProblems.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionProblems.emptyReason` |
| `Composition.section:sectionProblems.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionProblems.emptyReason` |
| `Composition.section:sectionProblems.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionProblems.emptyReason` |
| `Composition.section:sectionRiskFactors` | 1..1 | BackboneElement |  |
| `Composition.section:sectionRiskFactors.title` | 1..1 | string |  |
| `Composition.section:sectionRiskFactors.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionRiskFactors.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionRiskFactors.emptyReason` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionRiskFactors.emptyReason` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionRiskFactors.emptyReason` |
| `Composition.section:sectionServiceRequests` | 1..1 | BackboneElement |  |
| `Composition.section:sectionServiceRequests.title` | 1..1 | string |  |
| `Composition.section:sectionServiceRequests.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionServiceRequests.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionServiceRequests.emptyReason` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionServiceRequests.emptyReason` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionServiceRequests.emptyReason` |
| `Composition.section:sectionClarificationNotes.title` | 1..1 | string | si `Composition.section:sectionClarificationNotes` |
| `Composition.section:sectionClarificationNotes.code` | 1..1 | CodeableConcept | si `Composition.section:sectionClarificationNotes` |
| `Composition.section:sectionClarificationNotes.entry` | 1..* | Reference(ObservationClarificationNoteRDA) | si `Composition.section:sectionClarificationNotes` |
| `Composition.section:sectionAddendumDocuments` | 1..1 | BackboneElement |  |
| `Composition.section:sectionAddendumDocuments.title` | 1..1 | string |  |
| `Composition.section:sectionAddendumDocuments.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionAddendumDocuments.entry` | 1..1 | Reference(DocumentReferenceEPIRDA) |  |

### Must-support opcionales

`Composition.identifier` 0..1 · `Composition.confidentiality` 0..1 · `Composition.attester.party` 0..1 · `Composition.event` 0..* · `Composition.event.period` 0..1 · `Composition.section:sectionPayers.entry:EAPBPayer` 0..* · `Composition.section:sectionPayers.emptyReason` 0..1 · `Composition.section:sectionHistoryOfOccupation.emptyReason` 0..1 · `Composition.section:sectionAttendanceAllowance.entry` 0..1 · `Composition.section:sectionAttendanceAllowance.emptyReason` 0..1 · `Composition.section:sectionMedications.emptyReason` 0..1 · `Composition.section:sectionAllergies.entry` 0..* · `Composition.section:sectionAllergies.emptyReason` 0..1 · `Composition.section:sectionProblems.emptyReason` 0..1 · `Composition.section:sectionRiskFactors.entry` 0..* · `Composition.section:sectionRiskFactors.emptyReason` 0..1 · `Composition.section:sectionServiceRequests.emptyReason` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Composition.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/CompositionAmbulatoryRDA"` |
| `Composition.type.coding.system` | `fixedUri` | `"http://loinc.org"` |
| `Composition.type.coding.code` | `fixedCode` | `"51845-6"` |
| `Composition.type.coding.display` | `fixedString` | `"Outpatient Consult note"` |
| `Composition.confidentiality` | `patternCode` | `"N"` |
| `Composition.attester.mode` | `fixedCode` | `"legal"` |
| `Composition.relatesTo.code` | `fixedCode` | `"appends"` |
| `Composition.section:sectionPayers.title` | `fixedString` | `"Entidad(es) responsable(s) por el plan de beneficios en salud (consulta)"` |
| `Composition.section:sectionPayers.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"48768-6","display":"Payment sources Document"}]}` |
| `Composition.section:sectionPayers.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionPayers.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionPayers.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionHistoryOfOccupation.title` | `fixedString` | `"Otros datos demográficos"` |
| `Composition.section:sectionHistoryOfOccupation.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"74208-0","display":"Demographic information + History of occupation Document"}]}` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionAttendanceAllowance.title` | `fixedString` | `"Datos incapacidad (SIPE – Sistema de Incapacidades y Prestaciones Economicas)"` |
| `Composition.section:sectionAttendanceAllowance.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"105583-9","display":"Worker Sick leave form"}]}` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionMedications.title` | `fixedString` | `"Historial de medicamentos"` |
| `Composition.section:sectionMedications.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"10160-0","display":"History of Medication use Narrative"}]}` |
| `Composition.section:sectionMedications.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionMedications.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionMedications.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionAllergies.title` | `fixedString` | `"Historial de alergias, intolerancias y reacciones adversas"` |
| `Composition.section:sectionAllergies.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"48765-2","display":"Allergies and adverse reactions Document"}]}` |
| `Composition.section:sectionAllergies.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionAllergies.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionAllergies.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionProblems.title` | `fixedString` | `"Historial de diagnósticos de problemas de salud"` |
| `Composition.section:sectionProblems.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"11450-4","display":"Problem list - Reported"}]}` |
| `Composition.section:sectionProblems.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionProblems.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionProblems.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionRiskFactors.title` | `fixedString` | `"Factores de riesgo"` |
| `Composition.section:sectionRiskFactors.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"75492-9","display":"Risk assessment and screening note"}]}` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionServiceRequests.title` | `fixedString` | `"Órdenes, prescripciones o solicitudes de servicio"` |
| `Composition.section:sectionServiceRequests.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"61146-1","display":"Orders for services Document"}]}` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionClarificationNotes.title` | `fixedString` | `"Notas aclaratorias"` |
| `Composition.section:sectionClarificationNotes.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"34109-9","display":"Note"}]}` |
| `Composition.section:sectionAddendumDocuments.title` | `fixedString` | `"Documentos de soporte"` |
| `Composition.section:sectionAddendumDocuments.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"55107-7","display":"Addendum Document"}]}` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Composition.section` | pattern:code | closed | `sectionPayers` 1..1 BackboneElement<br>`sectionHistoryOfOccupation` 1..1 BackboneElement<br>`sectionAttendanceAllowance` 1..1 BackboneElement<br>`sectionMedications` 1..1 BackboneElement<br>`sectionAllergies` 1..1 BackboneElement<br>`sectionProblems` 1..1 BackboneElement<br>`sectionRiskFactors` 1..1 BackboneElement<br>`sectionServiceRequests` 1..1 BackboneElement<br>`sectionClarificationNotes` 0..1 BackboneElement<br>`sectionAddendumDocuments` 1..1 BackboneElement |
| `Composition.section:sectionPayers.entry` | profile:resolve() | open | `EAPBPayer` 0..* Reference(HealthBenefitPlanAdminOrganizationRDA)<br>`privatePayer` 0..1 Reference(PatientRDA) |
| `Composition.section:sectionMedications.entry` | profile:resolve() | open | `medicationRequest` 0..* Reference(MedicationRequestRDA) |
| `Composition.section:sectionServiceRequests.entry` | profile:resolve() | open | `serviceRequest` 0..* Reference(ServiceRequestRDA)<br>`OtherTechnologyServiceRequest` 0..* Reference(OtherTechnologyServiceRequestRDA) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Composition.confidentiality` | `http://terminology.hl7.org/ValueSet/v3-ConfidentialityClassification|2014-03-26` |

### Invariantes del perfil

| Clave | Severidad | Elemento | Regla | Expresión |
| --- | --- | --- | --- | --- |
| `inv-period-full-date-comp-amb` | error | `Composition.event.period` | Las fechas del periodo (start y end) deben incluir al menos día, mes y año (formato AAAA-MM-DD); no se acepta una fecha con solo el año (AAAA) o solo año y mes (AAAA-MM). | `(start.exists() implies start.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*')) and (end.exists() implies end.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*'))` |

## CompositionEmergencyRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/CompositionEmergencyRDA`
- Tipo: `Composition`; base: `http://hl7.org/fhir/StructureDefinition/Composition`
- Descripción: Perfil FHIR RDA del Resumen Digital de Atención en Salud en Colombia, para encuentros de Urgencias.  Documento clínico estructurado que consolida y resume la información relevante de un proceso de atención en salud de un paciente, integrando datos clínicos esenciales para facilitar la continuidad del cuidado y el intercambio de información entre profesionales e instituciones.  El Resumen Digital de Atención en Salud (RDA) incluye información como motivos de consulta, diagnósticos, procedimientos realizados, medicamentos prescritos, antecedentes relevantes, exámenes de apoyo diagnóstico y planes de manejo, registrados por un profesional de la salud autorizado y habilitado, de acuerdo con los lineamientos establecidos por la normativa colombiana.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Composition.meta.profile` | 1..* | canonical(StructureDefinition) | si `Composition.meta` |
| `Composition.status` | 1..1 | code |  |
| `Composition.type` | 1..1 | CodeableConcept |  |
| `Composition.type.coding.system` | 1..1 | uri | si `Composition.type.coding` |
| `Composition.subject` | 1..1 | Reference(PatientRDA) |  |
| `Composition.subject.reference` | 1..1 | string |  |
| `Composition.encounter` | 1..1 | Reference(EncounterEmergencyRDA) |  |
| `Composition.encounter.reference` | 1..1 | string |  |
| `Composition.date` | 1..1 | dateTime |  |
| `Composition.author` | 1..1 | Reference(CareDeliveryOrganizationRDA, PractitionerRDA) |  |
| `Composition.title` | 1..1 | string |  |
| `Composition.attester.mode` | 1..1 | code | si `Composition.attester` |
| `Composition.custodian` | 1..1 | Reference(CareDeliveryOrganizationRDA) |  |
| `Composition.relatesTo.code` | 1..1 | code | si `Composition.relatesTo` |
| `Composition.relatesTo.target[x]` | 1..1 | Reference(CompositionPatientStatementRDA) | si `Composition.relatesTo` |
| `Composition.section` | 12..13 | BackboneElement |  |
| `Composition.section:sectionPayers` | 1..1 | BackboneElement |  |
| `Composition.section:sectionPayers.title` | 1..1 | string |  |
| `Composition.section:sectionPayers.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionPayers.entry` | 1..* | Reference(Resource) |  |
| `Composition.section:sectionHistoryOfOccupation` | 1..1 | BackboneElement |  |
| `Composition.section:sectionHistoryOfOccupation.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionHistoryOfOccupation.emptyReason` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionHistoryOfOccupation.emptyReason` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionHistoryOfOccupation.emptyReason` |
| `Composition.section:sectionAttendanceAllowance` | 1..1 | BackboneElement |  |
| `Composition.section:sectionAttendanceAllowance.title` | 1..1 | string |  |
| `Composition.section:sectionAttendanceAllowance.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionAttendanceAllowance.emptyReason` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionAttendanceAllowance.emptyReason` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionAttendanceAllowance.emptyReason` |
| `Composition.section:sectionMedications` | 1..1 | BackboneElement |  |
| `Composition.section:sectionMedications.title` | 1..1 | string |  |
| `Composition.section:sectionMedications.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionMedications.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionMedications.emptyReason` |
| `Composition.section:sectionMedications.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionMedications.emptyReason` |
| `Composition.section:sectionMedications.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionMedications.emptyReason` |
| `Composition.section:sectionAllergies` | 1..1 | BackboneElement |  |
| `Composition.section:sectionAllergies.title` | 1..1 | string |  |
| `Composition.section:sectionAllergies.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionAllergies.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionAllergies.emptyReason` |
| `Composition.section:sectionAllergies.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionAllergies.emptyReason` |
| `Composition.section:sectionAllergies.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionAllergies.emptyReason` |
| `Composition.section:sectionProblems` | 1..1 | BackboneElement |  |
| `Composition.section:sectionProblems.title` | 1..1 | string |  |
| `Composition.section:sectionProblems.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionProblems.entry` | 1..* | Reference(ConditionRDA) |  |
| `Composition.section:sectionProblems.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionProblems.emptyReason` |
| `Composition.section:sectionProblems.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionProblems.emptyReason` |
| `Composition.section:sectionProblems.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionProblems.emptyReason` |
| `Composition.section:sectionTriage` | 1..1 | BackboneElement |  |
| `Composition.section:sectionTriage.title` | 1..1 | string |  |
| `Composition.section:sectionTriage.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionTriage.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionTriage.emptyReason` |
| `Composition.section:sectionTriage.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionTriage.emptyReason` |
| `Composition.section:sectionTriage.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionTriage.emptyReason` |
| `Composition.section:sectionRiskFactors` | 1..1 | BackboneElement |  |
| `Composition.section:sectionRiskFactors.title` | 1..1 | string |  |
| `Composition.section:sectionRiskFactors.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionRiskFactors.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionRiskFactors.emptyReason` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionRiskFactors.emptyReason` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionRiskFactors.emptyReason` |
| `Composition.section:sectionProceduresHx` | 1..1 | BackboneElement |  |
| `Composition.section:sectionProceduresHx.title` | 1..1 | string |  |
| `Composition.section:sectionProceduresHx.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionProceduresHx.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionProceduresHx.emptyReason` |
| `Composition.section:sectionProceduresHx.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionProceduresHx.emptyReason` |
| `Composition.section:sectionProceduresHx.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionProceduresHx.emptyReason` |
| `Composition.section:sectionResults` | 1..1 | BackboneElement |  |
| `Composition.section:sectionResults.title` | 1..1 | string |  |
| `Composition.section:sectionResults.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionResults.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionResults.emptyReason` |
| `Composition.section:sectionResults.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionResults.emptyReason` |
| `Composition.section:sectionResults.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionResults.emptyReason` |
| `Composition.section:sectionServiceRequests` | 1..1 | BackboneElement |  |
| `Composition.section:sectionServiceRequests.title` | 1..1 | string |  |
| `Composition.section:sectionServiceRequests.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionServiceRequests.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionServiceRequests.emptyReason` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionServiceRequests.emptyReason` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionServiceRequests.emptyReason` |
| `Composition.section:sectionClarificationNotes.title` | 1..1 | string | si `Composition.section:sectionClarificationNotes` |
| `Composition.section:sectionClarificationNotes.code` | 1..1 | CodeableConcept | si `Composition.section:sectionClarificationNotes` |
| `Composition.section:sectionClarificationNotes.entry` | 1..* | Reference(ObservationClarificationNoteRDA) | si `Composition.section:sectionClarificationNotes` |
| `Composition.section:sectionAddendumDocuments` | 1..1 | BackboneElement |  |
| `Composition.section:sectionAddendumDocuments.title` | 1..1 | string |  |
| `Composition.section:sectionAddendumDocuments.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionAddendumDocuments.entry` | 1..1 | Reference(DocumentReferenceEPIRDA) |  |

### Must-support opcionales

`Composition.identifier` 0..1 · `Composition.confidentiality` 0..1 · `Composition.attester.party` 0..1 · `Composition.event` 0..* · `Composition.event.period` 0..1 · `Composition.section:sectionPayers.entry:EAPBPayer` 0..* · `Composition.section:sectionHistoryOfOccupation.emptyReason` 0..1 · `Composition.section:sectionAttendanceAllowance.entry` 0..1 · `Composition.section:sectionAttendanceAllowance.emptyReason` 0..1 · `Composition.section:sectionAllergies.entry` 0..* · `Composition.section:sectionAllergies.emptyReason` 0..1 · `Composition.section:sectionProblems.emptyReason` 0..1 · `Composition.section:sectionTriage.entry` 0..1 · `Composition.section:sectionTriage.emptyReason` 0..1 · `Composition.section:sectionRiskFactors.entry` 0..* · `Composition.section:sectionRiskFactors.emptyReason` 0..1 · `Composition.section:sectionProceduresHx.entry` 0..* · `Composition.section:sectionProceduresHx.emptyReason` 0..1 · `Composition.section:sectionResults.entry` 0..* · `Composition.section:sectionResults.emptyReason` 0..1 · `Composition.section:sectionServiceRequests.emptyReason` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Composition.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/CompositionEmergencyRDA"` |
| `Composition.type.coding.system` | `fixedUri` | `"http://loinc.org"` |
| `Composition.type.coding.code` | `fixedCode` | `"59258-4"` |
| `Composition.type.coding.display` | `fixedString` | `"Emergency department Discharge summary"` |
| `Composition.confidentiality` | `patternCode` | `"N"` |
| `Composition.attester.mode` | `fixedCode` | `"legal"` |
| `Composition.relatesTo.code` | `fixedCode` | `"appends"` |
| `Composition.section:sectionPayers.title` | `fixedString` | `"Entidad(es) responsable(s) por el plan de beneficios en salud (urgencias)"` |
| `Composition.section:sectionPayers.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"48768-6","display":"Payment sources Document"}]}` |
| `Composition.section:sectionHistoryOfOccupation.title` | `fixedString` | `"Otros datos demográficos"` |
| `Composition.section:sectionHistoryOfOccupation.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"74208-0","display":"Demographic information + History of occupation Document"}]}` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionAttendanceAllowance.title` | `fixedString` | `"Datos incapacidad (SIPE – Sistema de Incapacidades y Prestaciones Economicas)"` |
| `Composition.section:sectionAttendanceAllowance.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"105583-9","display":"Worker Sick leave form"}]}` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionMedications.title` | `fixedString` | `"Historial de medicamentos"` |
| `Composition.section:sectionMedications.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"10160-0","display":"History of Medication use Narrative"}]}` |
| `Composition.section:sectionMedications.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionMedications.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionMedications.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionAllergies.title` | `fixedString` | `"Historial de alergias, intolerancias y reacciones adversas"` |
| `Composition.section:sectionAllergies.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"48765-2","display":"Allergies and adverse reactions Document"}]}` |
| `Composition.section:sectionAllergies.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionAllergies.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionAllergies.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionProblems.title` | `fixedString` | `"Historial de diagnósticos de problemas de salud"` |
| `Composition.section:sectionProblems.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"11450-4","display":"Problem list - Reported"}]}` |
| `Composition.section:sectionProblems.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionProblems.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionProblems.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionTriage.title` | `fixedString` | `"Clasificación de triaje"` |
| `Composition.section:sectionTriage.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"54094-8","display":"Emergency department Triage note"}]}` |
| `Composition.section:sectionTriage.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionTriage.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionTriage.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionRiskFactors.title` | `fixedString` | `"Factores de riesgo"` |
| `Composition.section:sectionRiskFactors.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"75492-9","display":"Risk assessment and screening note"}]}` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionProceduresHx.title` | `fixedString` | `"Historial de procedimientos"` |
| `Composition.section:sectionProceduresHx.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"47519-4","display":"History of Procedures Document"}]}` |
| `Composition.section:sectionProceduresHx.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionProceduresHx.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionProceduresHx.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionResults.title` | `fixedString` | `"Resultados del uso de las tecnologías en salud"` |
| `Composition.section:sectionResults.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"30954-2","display":"Relevant diagnostic tests/laboratory data note"}]}` |
| `Composition.section:sectionResults.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionResults.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionResults.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionServiceRequests.title` | `fixedString` | `"Órdenes, prescripciones o solicitudes de servicio"` |
| `Composition.section:sectionServiceRequests.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"61146-1","display":"Orders for services Document"}]}` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionClarificationNotes.title` | `fixedString` | `"Notas aclaratorias"` |
| `Composition.section:sectionClarificationNotes.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"34109-9","display":"Note"}]}` |
| `Composition.section:sectionAddendumDocuments.title` | `fixedString` | `"Documentos de soporte"` |
| `Composition.section:sectionAddendumDocuments.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"55107-7","display":"Addendum Document"}]}` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Composition.section` | pattern:code | closed | `sectionPayers` 1..1 BackboneElement<br>`sectionHistoryOfOccupation` 1..1 BackboneElement<br>`sectionAttendanceAllowance` 1..1 BackboneElement<br>`sectionMedications` 1..1 BackboneElement<br>`sectionAllergies` 1..1 BackboneElement<br>`sectionProblems` 1..1 BackboneElement<br>`sectionTriage` 1..1 BackboneElement<br>`sectionRiskFactors` 1..1 BackboneElement<br>`sectionProceduresHx` 1..1 BackboneElement<br>`sectionResults` 1..1 BackboneElement<br>`sectionServiceRequests` 1..1 BackboneElement<br>`sectionClarificationNotes` 0..1 BackboneElement<br>`sectionAddendumDocuments` 1..1 BackboneElement |
| `Composition.section:sectionPayers.entry` | profile:resolve() | open | `EAPBPayer` 0..* Reference(HealthBenefitPlanAdminOrganizationRDA)<br>`privatePayer` 0..1 Reference(PatientRDA) |
| `Composition.section:sectionMedications.entry` | profile:resolve() | open | `medicationAdminRequest` 0..* Reference(MedicationAdminRequestRDA)<br>`medicationAdministration` 0..* Reference(MedicationAdministrationRDA)<br>`medicationRequest` 0..* Reference(MedicationRequestRDA) |
| `Composition.section:sectionServiceRequests.entry` | profile:resolve() | open | `serviceRequest` 0..* Reference(ServiceRequestRDA)<br>`OtherTechnologyServiceRequest` 0..* Reference(OtherTechnologyServiceRequestRDA) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Composition.confidentiality` | `http://terminology.hl7.org/ValueSet/v3-ConfidentialityClassification|2014-03-26` |

### Invariantes del perfil

| Clave | Severidad | Elemento | Regla | Expresión |
| --- | --- | --- | --- | --- |
| `inv-period-full-date-comp-emerg` | error | `Composition.event.period` | Las fechas del periodo (start y end) deben incluir al menos día, mes y año (formato AAAA-MM-DD); no se acepta una fecha con solo el año (AAAA) o solo año y mes (AAAA-MM). | `(start.exists() implies start.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*')) and (end.exists() implies end.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*'))` |

## CompositionHospitalizationRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/CompositionHospitalizationRDA`
- Tipo: `Composition`; base: `http://hl7.org/fhir/StructureDefinition/Composition`
- Descripción: Perfil FHIR RDA del Resumen Digital de Atención en Salud en Colombia, para encuentros de hospitalización.  Documento clínico estructurado que consolida y resume la información relevante de un proceso de atención en salud de un paciente, integrando datos clínicos esenciales para facilitar la continuidad del cuidado y el intercambio de información entre profesionales e instituciones.  El Resumen Digital de Atención en Salud (RDA) incluye información como motivos de consulta, diagnósticos, procedimientos realizados, medicamentos prescritos, antecedentes relevantes, exámenes de apoyo diagnóstico y planes de manejo, registrados por un profesional de la salud autorizado y habilitado, de acuerdo con los lineamientos establecidos por la normativa colombiana.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Composition.meta.profile` | 1..* | canonical(StructureDefinition) | si `Composition.meta` |
| `Composition.status` | 1..1 | code |  |
| `Composition.type` | 1..1 | CodeableConcept |  |
| `Composition.type.coding.system` | 1..1 | uri | si `Composition.type.coding` |
| `Composition.subject` | 1..1 | Reference(PatientRDA) |  |
| `Composition.subject.reference` | 1..1 | string |  |
| `Composition.encounter` | 1..1 | Reference(EncounterHospitalizationRDA) |  |
| `Composition.encounter.reference` | 1..1 | string |  |
| `Composition.date` | 1..1 | dateTime |  |
| `Composition.author` | 1..1 | Reference(CareDeliveryOrganizationRDA) |  |
| `Composition.title` | 1..1 | string |  |
| `Composition.attester.mode` | 1..1 | code | si `Composition.attester` |
| `Composition.custodian` | 1..1 | Reference(CareDeliveryOrganizationRDA) |  |
| `Composition.relatesTo.code` | 1..1 | code | si `Composition.relatesTo` |
| `Composition.relatesTo.target[x]` | 1..1 | Reference(CompositionPatientStatementRDA) | si `Composition.relatesTo` |
| `Composition.section` | 11..12 | BackboneElement |  |
| `Composition.section:sectionPayers` | 1..1 | BackboneElement |  |
| `Composition.section:sectionPayers.title` | 1..1 | string |  |
| `Composition.section:sectionPayers.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionPayers.entry` | 1..* | Reference(Resource) |  |
| `Composition.section:sectionHistoryOfOccupation` | 1..1 | BackboneElement |  |
| `Composition.section:sectionHistoryOfOccupation.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionHistoryOfOccupation.emptyReason` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionHistoryOfOccupation.emptyReason` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionHistoryOfOccupation.emptyReason` |
| `Composition.section:sectionAttendanceAllowance` | 1..1 | BackboneElement |  |
| `Composition.section:sectionAttendanceAllowance.title` | 1..1 | string |  |
| `Composition.section:sectionAttendanceAllowance.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionAttendanceAllowance.emptyReason` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionAttendanceAllowance.emptyReason` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionAttendanceAllowance.emptyReason` |
| `Composition.section:sectionMedications` | 1..1 | BackboneElement |  |
| `Composition.section:sectionMedications.title` | 1..1 | string |  |
| `Composition.section:sectionMedications.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionMedications.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionMedications.emptyReason` |
| `Composition.section:sectionMedications.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionMedications.emptyReason` |
| `Composition.section:sectionMedications.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionMedications.emptyReason` |
| `Composition.section:sectionAllergies` | 1..1 | BackboneElement |  |
| `Composition.section:sectionAllergies.title` | 1..1 | string |  |
| `Composition.section:sectionAllergies.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionAllergies.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionAllergies.emptyReason` |
| `Composition.section:sectionAllergies.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionAllergies.emptyReason` |
| `Composition.section:sectionAllergies.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionAllergies.emptyReason` |
| `Composition.section:sectionProblems` | 1..1 | BackboneElement |  |
| `Composition.section:sectionProblems.title` | 1..1 | string |  |
| `Composition.section:sectionProblems.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionProblems.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionProblems.emptyReason` |
| `Composition.section:sectionProblems.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionProblems.emptyReason` |
| `Composition.section:sectionProblems.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionProblems.emptyReason` |
| `Composition.section:sectionRiskFactors` | 1..1 | BackboneElement |  |
| `Composition.section:sectionRiskFactors.title` | 1..1 | string |  |
| `Composition.section:sectionRiskFactors.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionRiskFactors.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionRiskFactors.emptyReason` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionRiskFactors.emptyReason` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionRiskFactors.emptyReason` |
| `Composition.section:sectionProceduresHx` | 1..1 | BackboneElement |  |
| `Composition.section:sectionProceduresHx.title` | 1..1 | string |  |
| `Composition.section:sectionProceduresHx.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionProceduresHx.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionProceduresHx.emptyReason` |
| `Composition.section:sectionProceduresHx.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionProceduresHx.emptyReason` |
| `Composition.section:sectionProceduresHx.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionProceduresHx.emptyReason` |
| `Composition.section:sectionResults` | 1..1 | BackboneElement |  |
| `Composition.section:sectionResults.title` | 1..1 | string |  |
| `Composition.section:sectionResults.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionResults.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionResults.emptyReason` |
| `Composition.section:sectionResults.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionResults.emptyReason` |
| `Composition.section:sectionResults.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionResults.emptyReason` |
| `Composition.section:sectionServiceRequests` | 1..1 | BackboneElement |  |
| `Composition.section:sectionServiceRequests.title` | 1..1 | string |  |
| `Composition.section:sectionServiceRequests.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionServiceRequests.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionServiceRequests.emptyReason` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionServiceRequests.emptyReason` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionServiceRequests.emptyReason` |
| `Composition.section:sectionClarificationNotes.title` | 1..1 | string | si `Composition.section:sectionClarificationNotes` |
| `Composition.section:sectionClarificationNotes.code` | 1..1 | CodeableConcept | si `Composition.section:sectionClarificationNotes` |
| `Composition.section:sectionClarificationNotes.entry` | 1..* | Reference(ObservationClarificationNoteRDA) | si `Composition.section:sectionClarificationNotes` |
| `Composition.section:sectionAddendumDocuments` | 1..1 | BackboneElement |  |
| `Composition.section:sectionAddendumDocuments.title` | 1..1 | string |  |
| `Composition.section:sectionAddendumDocuments.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionAddendumDocuments.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionAddendumDocuments.emptyReason` |
| `Composition.section:sectionAddendumDocuments.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionAddendumDocuments.emptyReason` |
| `Composition.section:sectionAddendumDocuments.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionAddendumDocuments.emptyReason` |

### Must-support opcionales

`Composition.identifier` 0..1 · `Composition.confidentiality` 0..1 · `Composition.attester.party` 0..1 · `Composition.event` 0..* · `Composition.event.period` 0..1 · `Composition.section:sectionPayers.entry:EAPBPayer` 0..* · `Composition.section:sectionHistoryOfOccupation.emptyReason` 0..1 · `Composition.section:sectionAttendanceAllowance.entry` 0..1 · `Composition.section:sectionAttendanceAllowance.emptyReason` 0..1 · `Composition.section:sectionMedications.entry:medicationAdminRequest` 0..* · `Composition.section:sectionMedications.entry:medicationAdministration` 0..* · `Composition.section:sectionMedications.entry:medicationRequest` 0..* · `Composition.section:sectionMedications.emptyReason` 0..1 · `Composition.section:sectionAllergies.entry` 0..* · `Composition.section:sectionAllergies.emptyReason` 0..1 · `Composition.section:sectionProblems.entry` 0..* · `Composition.section:sectionProblems.emptyReason` 0..1 · `Composition.section:sectionRiskFactors.entry` 0..* · `Composition.section:sectionRiskFactors.emptyReason` 0..1 · `Composition.section:sectionProceduresHx.entry` 0..* · `Composition.section:sectionProceduresHx.emptyReason` 0..1 · `Composition.section:sectionResults.entry` 0..* · `Composition.section:sectionResults.emptyReason` 0..1 · `Composition.section:sectionServiceRequests.emptyReason` 0..1 · `Composition.section:sectionAddendumDocuments.entry` 0..1 · `Composition.section:sectionAddendumDocuments.emptyReason` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Composition.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/CompositionHospitalizationRDA"` |
| `Composition.type.coding.system` | `fixedUri` | `"http://loinc.org"` |
| `Composition.type.coding.code` | `fixedCode` | `"34105-7"` |
| `Composition.type.coding.display` | `fixedString` | `"Hospital Discharge summary"` |
| `Composition.confidentiality` | `patternCode` | `"N"` |
| `Composition.attester.mode` | `fixedCode` | `"legal"` |
| `Composition.relatesTo.code` | `fixedCode` | `"appends"` |
| `Composition.section:sectionPayers.title` | `fixedString` | `"Entidad(es) responsable(s) por el plan de beneficios en salud (Hospitalización / Internación)"` |
| `Composition.section:sectionPayers.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"48768-6","display":"Payment sources Document"}]}` |
| `Composition.section:sectionHistoryOfOccupation.title` | `fixedString` | `"Otros datos demográficos"` |
| `Composition.section:sectionHistoryOfOccupation.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"74208-0","display":"Demographic information + History of occupation Document"}]}` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionHistoryOfOccupation.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionAttendanceAllowance.title` | `fixedString` | `"Datos incapacidad (SIPE – Sistema de Incapacidades y Prestaciones Economicas)"` |
| `Composition.section:sectionAttendanceAllowance.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"105583-9","display":"Worker Sick leave form"}]}` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionAttendanceAllowance.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionMedications.title` | `fixedString` | `"Historial de medicamentos"` |
| `Composition.section:sectionMedications.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"10160-0","display":"History of Medication use Narrative"}]}` |
| `Composition.section:sectionMedications.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionMedications.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionMedications.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionAllergies.title` | `fixedString` | `"Historial de alergias, intolerancias y reacciones adversas"` |
| `Composition.section:sectionAllergies.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"48765-2","display":"Allergies and adverse reactions Document"}]}` |
| `Composition.section:sectionAllergies.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionAllergies.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionAllergies.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionProblems.title` | `fixedString` | `"Historial de diagnósticos de problemas de salud"` |
| `Composition.section:sectionProblems.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"11450-4","display":"Problem list - Reported"}]}` |
| `Composition.section:sectionProblems.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionProblems.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionProblems.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionRiskFactors.title` | `fixedString` | `"Factores de riesgo"` |
| `Composition.section:sectionRiskFactors.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"75492-9","display":"Risk assessment and screening note"}]}` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionRiskFactors.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionProceduresHx.title` | `fixedString` | `"Historial de procedimientos"` |
| `Composition.section:sectionProceduresHx.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"47519-4","display":"History of Procedures Document"}]}` |
| `Composition.section:sectionProceduresHx.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionProceduresHx.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionProceduresHx.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionResults.title` | `fixedString` | `"Resultados del uso de las tecnologías en salud"` |
| `Composition.section:sectionResults.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"30954-2","display":"Relevant diagnostic tests/laboratory data note"}]}` |
| `Composition.section:sectionResults.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionResults.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionResults.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionServiceRequests.title` | `fixedString` | `"Órdenes, prescripciones o solicitudes de servicio"` |
| `Composition.section:sectionServiceRequests.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"61146-1","display":"Orders for services Document"}]}` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionServiceRequests.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionClarificationNotes.title` | `fixedString` | `"Notas aclaratorias"` |
| `Composition.section:sectionClarificationNotes.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"34109-9","display":"Note"}]}` |
| `Composition.section:sectionAddendumDocuments.title` | `fixedString` | `"Documentos de soporte"` |
| `Composition.section:sectionAddendumDocuments.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"55107-7","display":"Addendum Document"}]}` |
| `Composition.section:sectionAddendumDocuments.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionAddendumDocuments.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionAddendumDocuments.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Composition.section` | pattern:code | closed | `sectionPayers` 1..1 BackboneElement<br>`sectionHistoryOfOccupation` 1..1 BackboneElement<br>`sectionAttendanceAllowance` 1..1 BackboneElement<br>`sectionMedications` 1..1 BackboneElement<br>`sectionAllergies` 1..1 BackboneElement<br>`sectionProblems` 1..1 BackboneElement<br>`sectionRiskFactors` 1..1 BackboneElement<br>`sectionProceduresHx` 1..1 BackboneElement<br>`sectionResults` 1..1 BackboneElement<br>`sectionServiceRequests` 1..1 BackboneElement<br>`sectionClarificationNotes` 0..1 BackboneElement<br>`sectionAddendumDocuments` 1..1 BackboneElement |
| `Composition.section:sectionPayers.entry` | profile:resolve() | open | `EAPBPayer` 0..* Reference(HealthBenefitPlanAdminOrganizationRDA)<br>`privatePayer` 0..1 Reference(PatientRDA) |
| `Composition.section:sectionMedications.entry` | profile:resolve() | open | `medicationAdminRequest` 0..* Reference(MedicationAdminRequestRDA)<br>`medicationAdministration` 0..* Reference(MedicationAdministrationRDA)<br>`medicationRequest` 0..* Reference(MedicationRequestRDA) |
| `Composition.section:sectionServiceRequests.entry` | profile:resolve() | open | `serviceRequest` 0..* Reference(ServiceRequestRDA)<br>`OtherTechnologyServiceRequest` 0..* Reference(OtherTechnologyServiceRequestRDA) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Composition.confidentiality` | `http://terminology.hl7.org/ValueSet/v3-ConfidentialityClassification|2014-03-26` |

### Invariantes del perfil

| Clave | Severidad | Elemento | Regla | Expresión |
| --- | --- | --- | --- | --- |
| `inv-period-full-date-comp-hosp` | error | `Composition.event.period` | Las fechas del periodo (start y end) deben incluir al menos día, mes y año (formato AAAA-MM-DD); no se acepta una fecha con solo el año (AAAA) o solo año y mes (AAAA-MM). | `(start.exists() implies start.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*')) and (end.exists() implies end.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*'))` |

## CompositionPatientStatementRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/CompositionPatientStatementRDA`
- Tipo: `Composition`; base: `http://hl7.org/fhir/StructureDefinition/Composition`
- Descripción: Perfil FHIR RDA del Resumen Digital de Atención en Salud en Colombia, para antecedentes manifestados por el paciente.  Documento clínico estructurado que consolida y resume la información relevante de un proceso de atención en salud de un paciente, integrando datos clínicos esenciales para facilitar la continuidad del cuidado y el intercambio de información entre profesionales e instituciones.  El Resumen Digital de Atención en Salud (RDA) de paciente incluye información de antecedentes manifestados o declarados por el paciente como enfermedades o problemas de salud, uso de medicamentos, alergias o intolerancias y antecedentes de salud familiar, los cuales son registrados por un profesional de la salud autorizado y habilitado, de acuerdo con los lineamientos establecidos por la normativa colombiana.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Composition.meta.profile` | 1..* | canonical(StructureDefinition) | si `Composition.meta` |
| `Composition.identifier.system` | 1..1 | uri | si `Composition.identifier` |
| `Composition.identifier.value` | 1..1 | string | si `Composition.identifier` |
| `Composition.status` | 1..1 | code |  |
| `Composition.type` | 1..1 | CodeableConcept |  |
| `Composition.type.coding.system` | 1..1 | uri | si `Composition.type.coding` |
| `Composition.subject` | 1..1 | Reference(PatientRDA) |  |
| `Composition.date` | 1..1 | dateTime |  |
| `Composition.author` | 1..1 | Reference(PractitionerRDA) |  |
| `Composition.title` | 1..1 | string |  |
| `Composition.attester.mode` | 1..1 | code | si `Composition.attester` |
| `Composition.attester.party.reference` | 1..1 | string | si `Composition.attester` |
| `Composition.custodian` | 1..1 | Reference(CareDeliveryOrganizationRDA) |  |
| `Composition.event` | 1..1 | BackboneElement |  |
| `Composition.event.code` | 2..2 | CodeableConcept |  |
| `Composition.event.code:eventCodeModality` | 1..1 | CodeableConcept |  |
| `Composition.event.code:eventCodeModality.coding` | 1..1 | Coding |  |
| `Composition.event.code:eventCodeModality.coding.system` | 1..1 | uri |  |
| `Composition.event.code:eventCodeModality.coding.code` | 1..1 | code |  |
| `Composition.event.code:eventCodeModality.coding.display` | 1..1 | string |  |
| `Composition.event.code:eventCodeServiceGroup` | 1..1 | CodeableConcept |  |
| `Composition.event.code:eventCodeServiceGroup.coding` | 1..1 | Coding |  |
| `Composition.event.code:eventCodeServiceGroup.coding.system` | 1..1 | uri |  |
| `Composition.event.code:eventCodeServiceGroup.coding.code` | 1..1 | code |  |
| `Composition.event.code:eventCodeServiceGroup.coding.display` | 1..1 | string |  |
| `Composition.event.period` | 1..1 | Period |  |
| `Composition.event.period.start` | 1..1 | dateTime |  |
| `Composition.event.period.end` | 1..1 | dateTime |  |
| `Composition.section` | 4..4 | BackboneElement |  |
| `Composition.section:sectionMedications` | 1..1 | BackboneElement |  |
| `Composition.section:sectionMedications.title` | 1..1 | string |  |
| `Composition.section:sectionMedications.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionMedications.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionMedications.emptyReason` |
| `Composition.section:sectionMedications.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionMedications.emptyReason` |
| `Composition.section:sectionMedications.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionMedications.emptyReason` |
| `Composition.section:sectionAllergies` | 1..1 | BackboneElement |  |
| `Composition.section:sectionAllergies.title` | 1..1 | string |  |
| `Composition.section:sectionAllergies.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionAllergies.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionAllergies.emptyReason` |
| `Composition.section:sectionAllergies.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionAllergies.emptyReason` |
| `Composition.section:sectionAllergies.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionAllergies.emptyReason` |
| `Composition.section:sectionProblems` | 1..1 | BackboneElement |  |
| `Composition.section:sectionProblems.title` | 1..1 | string |  |
| `Composition.section:sectionProblems.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionProblems.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionProblems.emptyReason` |
| `Composition.section:sectionProblems.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionProblems.emptyReason` |
| `Composition.section:sectionProblems.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionProblems.emptyReason` |
| `Composition.section:sectionFamilyMemberHistory` | 1..1 | BackboneElement |  |
| `Composition.section:sectionFamilyMemberHistory.title` | 1..1 | string |  |
| `Composition.section:sectionFamilyMemberHistory.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionFamilyMemberHistory.emptyReason.coding.system` | 1..1 | uri | si `Composition.section:sectionFamilyMemberHistory.emptyReason` |
| `Composition.section:sectionFamilyMemberHistory.emptyReason.coding.code` | 1..1 | code | si `Composition.section:sectionFamilyMemberHistory.emptyReason` |
| `Composition.section:sectionFamilyMemberHistory.emptyReason.coding.display` | 1..1 | string | si `Composition.section:sectionFamilyMemberHistory.emptyReason` |

### Must-support opcionales

`Composition.confidentiality` 0..1 · `Composition.event.detail` 0..1 · `Composition.section:sectionMedications.entry` 0..* · `Composition.section:sectionMedications.emptyReason` 0..1 · `Composition.section:sectionAllergies.entry` 0..* · `Composition.section:sectionAllergies.emptyReason` 0..1 · `Composition.section:sectionProblems.entry` 0..* · `Composition.section:sectionProblems.emptyReason` 0..1 · `Composition.section:sectionFamilyMemberHistory.entry` 0..* · `Composition.section:sectionFamilyMemberHistory.emptyReason` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Composition.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/CompositionPatientStatementRDA"` |
| `Composition.identifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/identifier-RDA"` |
| `Composition.status` | `fixedCode` | `"final"` |
| `Composition.type.coding.system` | `fixedUri` | `"http://loinc.org"` |
| `Composition.type.coding.code` | `fixedCode` | `"102089-0"` |
| `Composition.type.coding.display` | `fixedString` | `"FHIR resource patient medical record"` |
| `Composition.confidentiality` | `patternCode` | `"N"` |
| `Composition.attester.mode` | `fixedCode` | `"legal"` |
| `Composition.event.code:eventCodeModality.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianTechModality"` |
| `Composition.event.code:eventCodeServiceGroup.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/GrupoServicios"` |
| `Composition.section:sectionMedications.title` | `fixedString` | `"Historial de medicamentos"` |
| `Composition.section:sectionMedications.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"10160-0","display":"History of Medication use Narrative"}]}` |
| `Composition.section:sectionMedications.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionMedications.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionMedications.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionAllergies.title` | `fixedString` | `"Historial de alergias, intolerancias y reacciones adversas"` |
| `Composition.section:sectionAllergies.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"48765-2","display":"Allergies and adverse reactions Document"}]}` |
| `Composition.section:sectionAllergies.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionAllergies.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionAllergies.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionProblems.title` | `fixedString` | `"Historial de diagnósticos de problemas de salud"` |
| `Composition.section:sectionProblems.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"11450-4","display":"Problem list - Reported"}]}` |
| `Composition.section:sectionProblems.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionProblems.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionProblems.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |
| `Composition.section:sectionFamilyMemberHistory.title` | `fixedString` | `"Historial de antecedentes familiares"` |
| `Composition.section:sectionFamilyMemberHistory.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"10157-6","display":"History of family member diseases Narrative"}]}` |
| `Composition.section:sectionFamilyMemberHistory.emptyReason.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/list-empty-reason"` |
| `Composition.section:sectionFamilyMemberHistory.emptyReason.coding.code` | `fixedCode` | `"nilknown"` |
| `Composition.section:sectionFamilyMemberHistory.emptyReason.coding.display` | `fixedString` | `"Nil Known"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Composition.event.code` | value:coding.system | closed | `eventCodeModality` 1..1 CodeableConcept<br>`eventCodeServiceGroup` 1..1 CodeableConcept |
| `Composition.section` | pattern:code | closed | `sectionMedications` 1..1 BackboneElement<br>`sectionAllergies` 1..1 BackboneElement<br>`sectionProblems` 1..1 BackboneElement<br>`sectionFamilyMemberHistory` 1..1 BackboneElement |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Composition.type` | `https://fhir.minsalud.gov.co/rda/ValueSet/DocumentTypeCodesRDA` |
| `Composition.confidentiality` | `http://terminology.hl7.org/ValueSet/v3-ConfidentialityClassification|2014-03-26` |
| `Composition.event.code:eventCodeModality.coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianTechModalityCodes` |
| `Composition.event.code:eventCodeServiceGroup.coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/GrupoServiciosCodigos` |

### Invariantes del perfil

| Clave | Severidad | Elemento | Regla | Expresión |
| --- | --- | --- | --- | --- |
| `pat-rda-0` | error | `Composition` | Composition.title debe ser uno de los siguientes valores permitidos. | `title = 'Resumen Digital de Atención en Salud - RDA de antecedentes manifestados por el paiente' or title = 'Resumen Digital de Atención en Salud - RDA de antecedentes manifestados por el paciente'` |
| `inv-enc-period-valid-range-comp-pat` | error | `Composition.event.period` | La fecha del encuentro (start y end) no puede ser mayor a la fecha actual | `start.exists() and end.exists() and start <= end and start <= now() and end <= now()` |
| `inv-enc-period-max-1year-comp-pat` | error | `Composition.event.period` | La fecha del encuentro (inicio y fin) no puede ser de hace más de un año. | `start.toDate() >= today() - 1 year and end.toDate() >= today() - 1 year` |
| `inv-period-full-date-comp-pat` | error | `Composition.event.period` | Las fechas del periodo (start y end) deben incluir al menos día, mes y año (formato AAAA-MM-DD); no se acepta una fecha con solo el año (AAAA) o solo año y mes (AAAA-MM). | `(start.exists() implies start.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*')) and (end.exists() implies end.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*'))` |

## CompositionRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/CompositionRDA`
- Tipo: `Composition`; base: `http://hl7.org/fhir/StructureDefinition/Composition`
- Descripción: Perfil FHIR RDA del Resumen Digital de Atención en Salud en Colombia.  Documento clínico estructurado que consolida y resume la información relevante de un proceso de atención en salud de un paciente, integrando datos clínicos esenciales para facilitar la continuidad del cuidado y el intercambio de información entre profesionales e instituciones.  El Resumen Digital de Atención en Salud (RDA) incluye información como motivos de consulta, diagnósticos, procedimientos realizados, medicamentos prescritos, antecedentes relevantes, exámenes de apoyo diagnóstico y planes de manejo, registrados por un profesional de la salud autorizado y habilitado, de acuerdo con los lineamientos establecidos por la normativa colombiana.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Composition.meta.profile` | 1..* | canonical(StructureDefinition) | si `Composition.meta` |
| `Composition.status` | 1..1 | code |  |
| `Composition.type` | 1..1 | CodeableConcept |  |
| `Composition.type.coding.system` | 1..1 | uri | si `Composition.type.coding` |
| `Composition.subject` | 1..1 | Reference(PatientRDA) |  |
| `Composition.subject.reference` | 1..1 | string |  |
| `Composition.date` | 1..1 | dateTime |  |
| `Composition.author` | 1..* | Reference(Practitioner, PractitionerRole, Device, Patient, RelatedPerson, Organization) |  |
| `Composition.author.reference` | 1..1 | string |  |
| `Composition.title` | 1..1 | string |  |
| `Composition.attester.mode` | 1..1 | code | si `Composition.attester` |
| `Composition.attester.party.reference` | 1..1 | string | si `Composition.attester` |
| `Composition.custodian.reference` | 1..1 | string | si `Composition.custodian` |
| `Composition.relatesTo.code` | 1..1 | code | si `Composition.relatesTo` |
| `Composition.relatesTo.target[x]` | 1..1 | Identifier | Reference(Composition) | si `Composition.relatesTo` |
| `Composition.section` | 2..* | BackboneElement |  |
| `Composition.section.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionMedications.title` | 1..1 | string | si `Composition.section:sectionMedications` |
| `Composition.section:sectionMedications.code` | 1..1 | CodeableConcept | si `Composition.section:sectionMedications` |
| `Composition.section:sectionMedications.entry` | 1..* | Reference(Resource) | si `Composition.section:sectionMedications` |
| `Composition.section:sectionAllergies` | 1..1 | BackboneElement |  |
| `Composition.section:sectionAllergies.title` | 1..1 | string |  |
| `Composition.section:sectionAllergies.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionProblems` | 1..1 | BackboneElement |  |
| `Composition.section:sectionProblems.title` | 1..1 | string |  |
| `Composition.section:sectionProblems.code` | 1..1 | CodeableConcept |  |
| `Composition.section:sectionProceduresHx.title` | 1..1 | string | si `Composition.section:sectionProceduresHx` |
| `Composition.section:sectionProceduresHx.code` | 1..1 | CodeableConcept | si `Composition.section:sectionProceduresHx` |
| `Composition.section:sectionProceduresHx.entry` | 1..* | Reference(ProcedureRDA) | si `Composition.section:sectionProceduresHx` |
| `Composition.section:sectionResults.title` | 1..1 | string | si `Composition.section:sectionResults` |
| `Composition.section:sectionResults.code` | 1..1 | CodeableConcept | si `Composition.section:sectionResults` |
| `Composition.section:sectionResults.entry` | 1..* | Reference(ProcedureResultRDA) | si `Composition.section:sectionResults` |
| `Composition.section:sectionFamilyMemberHistory.title` | 1..1 | string | si `Composition.section:sectionFamilyMemberHistory` |
| `Composition.section:sectionFamilyMemberHistory.code` | 1..1 | CodeableConcept | si `Composition.section:sectionFamilyMemberHistory` |
| `Composition.section:sectionFamilyMemberHistory.entry` | 1..* | Reference(FamilyMemberHistoryRDA) | si `Composition.section:sectionFamilyMemberHistory` |
| `Composition.section:sectionEncounters.title` | 1..1 | string | si `Composition.section:sectionEncounters` |
| `Composition.section:sectionEncounters.code` | 1..1 | CodeableConcept | si `Composition.section:sectionEncounters` |

### Must-support opcionales

`Composition.identifier` 0..1 · `Composition.confidentiality` 0..1 · `Composition.attester` 0..* · `Composition.attester.time` 0..1 · `Composition.attester.party` 0..1 · `Composition.custodian` 0..1 · `Composition.event` 0..* · `Composition.event.period` 0..1 · `Composition.section:sectionMedications.entry:medicationStatement` 0..* · `Composition.section:sectionMedications.entry:medicationAdminRequest` 0..* · `Composition.section:sectionMedications.entry:medicationAdministration` 0..* · `Composition.section:sectionMedications.entry:medicationRequest` 0..* · `Composition.section:sectionAllergies.entry` 0..* · `Composition.section:sectionProblems.entry` 0..* · `Composition.section:sectionEncounters` 0..1 · `Composition.section:sectionEncounters.entry` 0..* · `Composition.section:sectionEncounters.entry:encounter-ambulatory` 0..* · `Composition.section:sectionEncounters.entry:encounter-emergency` 0..* · `Composition.section:sectionEncounters.entry:encounter-hospitalization` 0..*

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Composition.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/CompositionRDA"` |
| `Composition.type.coding.system` | `fixedUri` | `"http://loinc.org"` |
| `Composition.type.coding.code` | `fixedCode` | `"60591-5"` |
| `Composition.type.coding.display` | `fixedString` | `"Patient Summary Document"` |
| `Composition.confidentiality` | `patternCode` | `"N"` |
| `Composition.attester.mode` | `patternCode` | `"legal"` |
| `Composition.section:sectionMedications.title` | `fixedString` | `"Historial de medicamentos"` |
| `Composition.section:sectionMedications.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"10160-0","display":"History of Medication use Narrative"}]}` |
| `Composition.section:sectionAllergies.title` | `fixedString` | `"Historial de alergias, intolerancias y reacciones adversas"` |
| `Composition.section:sectionAllergies.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"48765-2","display":"Allergies and adverse reactions Document"}]}` |
| `Composition.section:sectionProblems.title` | `fixedString` | `"Historial de diagnósticos de problemas de salud"` |
| `Composition.section:sectionProblems.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"11450-4","display":"Problem list - Reported"}]}` |
| `Composition.section:sectionProceduresHx.title` | `fixedString` | `"Historial de procedimientos"` |
| `Composition.section:sectionProceduresHx.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"47519-4","display":"History of Procedures Document"}]}` |
| `Composition.section:sectionResults.title` | `fixedString` | `"Resultados del uso de las tecnologías en salud"` |
| `Composition.section:sectionResults.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"30954-2","display":"Relevant diagnostic tests/laboratory data note"}]}` |
| `Composition.section:sectionFamilyMemberHistory.title` | `fixedString` | `"Historial de antecedentes familiares"` |
| `Composition.section:sectionFamilyMemberHistory.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"10157-6","display":"History of family member diseases Narrative"}]}` |
| `Composition.section:sectionEncounters.title` | `fixedString` | `"Historial de encuentros de atención en salud"` |
| `Composition.section:sectionEncounters.code` | `fixedCodeableConcept` | `{"coding":[{"system":"http://loinc.org","code":"67781-5","display":"Summarization of encounter note Narrative"}]}` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Composition.section` | pattern:code | closed | `sectionMedications` 0..1 BackboneElement<br>`sectionAllergies` 1..1 BackboneElement<br>`sectionProblems` 1..1 BackboneElement<br>`sectionProceduresHx` 0..1 BackboneElement<br>`sectionResults` 0..1 BackboneElement<br>`sectionFamilyMemberHistory` 0..1 BackboneElement<br>`sectionEncounters` 0..1 BackboneElement |
| `Composition.section:sectionMedications.entry` | profile:resolve() | closed | `medicationStatement` 0..* Reference(MedicationStatementRDA)<br>`medicationAdminRequest` 0..* Reference(Resource)<br>`medicationAdministration` 0..* Reference(MedicationAdministrationRDA)<br>`medicationRequest` 0..* Reference(MedicationRequestRDA) |
| `Composition.section:sectionEncounters.entry` | type:resolve(), profile:resolve() | closed | `encounter-ambulatory` 0..* Reference(EncounterAmbulatoryRDA)<br>`encounter-emergency` 0..* Reference(EncounterEmergencyRDA)<br>`encounter-hospitalization` 0..* Reference(EncounterHospitalizationRDA) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Composition.confidentiality` | `http://terminology.hl7.org/ValueSet/v3-ConfidentialityClassification|2014-03-26` |

## ConditionRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/ConditionRDA`
- Tipo: `Condition`; base: `http://hl7.org/fhir/StructureDefinition/Condition`
- Descripción: Perfil FHIR del diagnóstico de una condición de salud, para su intercambio en un documento RDA en Colombia.  Condición clínica, problema, diagnóstico u otro acontecimiento, situación, cuestión o concepto clínico que afecta la salud de un paciente.  El diagnóstico de una condición de salud, problema o enfermedad es el resultado de un proceso clínico mediante el cual un profesional de la salud, autorizado y habilitado, identifica la presencia de una alteración específica del estado de salud de una persona, con base en la evaluación de signos, síntomas, antecedentes, hallazgos clínicos, pruebas diagnósticas y criterios definidos por la ciencia médica.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Condition.meta.profile` | 1..* | canonical(StructureDefinition) | si `Condition.meta` |
| `Condition.clinicalStatus.coding.system` | 1..1 | uri | si `Condition.clinicalStatus` |
| `Condition.clinicalStatus.coding.code` | 1..1 | code | si `Condition.clinicalStatus` |
| `Condition.clinicalStatus.coding.display` | 1..1 | string | si `Condition.clinicalStatus` |
| `Condition.verificationStatus.coding.code` | 1..1 | code | si `Condition.verificationStatus` |
| `Condition.verificationStatus.coding.display` | 1..1 | string | si `Condition.verificationStatus` |
| `Condition.code` | 1..1 | CodeableConcept |  |
| `Condition.code.coding` | 1..* | Coding |  |
| `Condition.code.coding:ICD10` | 1..1 | Coding |  |
| `Condition.code.coding:ICD10.system` | 1..1 | uri |  |
| `Condition.code.coding:ICD10.code` | 1..1 | code |  |
| `Condition.code.coding:ICD10.display` | 1..1 | string |  |
| `Condition.code.coding:ICD11.system` | 1..1 | uri | si `Condition.code.coding:ICD11` |
| `Condition.code.coding:ICD11.code` | 1..1 | code | si `Condition.code.coding:ICD11` |
| `Condition.code.coding:ICD11.display` | 1..1 | string | si `Condition.code.coding:ICD11` |
| `Condition.code.coding:EHuerfana.system` | 1..1 | uri | si `Condition.code.coding:EHuerfana` |
| `Condition.code.coding:EHuerfana.code` | 1..1 | code | si `Condition.code.coding:EHuerfana` |
| `Condition.code.coding:EHuerfana.display` | 1..1 | string | si `Condition.code.coding:EHuerfana` |
| `Condition.subject` | 1..1 | Reference(PatientRDA) |  |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Condition.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/ConditionRDA"` |
| `Condition.clinicalStatus.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/condition-clinical"` |
| `Condition.clinicalStatus.coding.code` | `fixedCode` | `"active"` |
| `Condition.clinicalStatus.coding.display` | `fixedString` | `"Active"` |
| `Condition.verificationStatus.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/condition-ver-status"` |
| `Condition.verificationStatus.coding.code` | `fixedCode` | `"confirmed"` |
| `Condition.verificationStatus.coding.display` | `fixedString` | `"Confirmed"` |
| `Condition.code.coding:ICD10.system` | `fixedUri` | `"http://hl7.org/fhir/sid/icd-10"` |
| `Condition.code.coding:ICD11.system` | `fixedUri` | `"http://hl7.org/fhir/sid/icd-11"` |
| `Condition.code.coding:EHuerfana.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/MipresOrphanDiseases"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Condition.code.coding` | value:system | closed | `ICD10` 1..1 Coding<br>`ICD11` 0..1 Coding<br>`EHuerfana` 0..1 Coding |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Condition.code.coding:ICD10` | `https://fhir.minsalud.gov.co/rda/ValueSet/ICD10Codes` |
| `Condition.code.coding:ICD11` | `https://fhir.minsalud.gov.co/rda/ValueSet/ICD11Codes` |
| `Condition.code.coding:EHuerfana` | `https://fhir.minsalud.gov.co/rda/ValueSet/MipresOrphanDiseasesCodes` |

## ConditionStatementRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/ConditionStatementRDA`
- Tipo: `Condition`; base: `http://hl7.org/fhir/StructureDefinition/Condition`
- Descripción: Perfil FHIR de una condición de salud declarada o informada por el paciente, para su intercambio en un documento RDA en Colombia.  Condición clínica, problema, diagnóstico u otro acontecimiento, situación, cuestión o concepto clínico que afecta la salud de un paciente.  El antecedente de una condición de salud es cualquier problema, diagnóstico u otro acontecimiento, situación, cuestión o concepto clínico que afecta la salud de un paciente en un momento anterior al presente.  Esto, no corresponde al motivo de atención, que es la razón por la cual el paciente solicita la prestación de servicios de salud en el momento actual.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Condition.meta.profile` | 1..* | canonical(StructureDefinition) | si `Condition.meta` |
| `Condition.clinicalStatus.coding.system` | 1..1 | uri | si `Condition.clinicalStatus` |
| `Condition.clinicalStatus.coding.code` | 1..1 | code | si `Condition.clinicalStatus` |
| `Condition.clinicalStatus.coding.display` | 1..1 | string | si `Condition.clinicalStatus` |
| `Condition.verificationStatus.coding.code` | 1..1 | code | si `Condition.verificationStatus` |
| `Condition.verificationStatus.coding.display` | 1..1 | string | si `Condition.verificationStatus` |
| `Condition.code` | 1..1 | CodeableConcept |  |
| `Condition.code.coding:ICD10.system` | 1..1 | uri | si `Condition.code.coding:ICD10` |
| `Condition.code.coding:ICD10.code` | 1..1 | code | si `Condition.code.coding:ICD10` |
| `Condition.code.coding:ICD10.display` | 1..1 | string | si `Condition.code.coding:ICD10` |
| `Condition.code.coding:ICD11.system` | 1..1 | uri | si `Condition.code.coding:ICD11` |
| `Condition.code.coding:ICD11.code` | 1..1 | code | si `Condition.code.coding:ICD11` |
| `Condition.code.coding:ICD11.display` | 1..1 | string | si `Condition.code.coding:ICD11` |
| `Condition.subject` | 1..1 | Reference(PatientRDA) |  |

### Must-support opcionales

`Condition.code.text` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Condition.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/ConditionStatementRDA"` |
| `Condition.clinicalStatus.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/condition-clinical"` |
| `Condition.clinicalStatus.coding.code` | `fixedCode` | `"active"` |
| `Condition.clinicalStatus.coding.display` | `fixedString` | `"Active"` |
| `Condition.verificationStatus.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/condition-ver-status"` |
| `Condition.verificationStatus.coding.code` | `fixedCode` | `"unconfirmed"` |
| `Condition.verificationStatus.coding.display` | `fixedString` | `"Unconfirmed"` |
| `Condition.code.coding:ICD10.system` | `fixedUri` | `"http://hl7.org/fhir/sid/icd-10"` |
| `Condition.code.coding:ICD11.system` | `fixedUri` | `"http://hl7.org/fhir/sid/icd-11"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Condition.code.coding` | value:system | closed | `ICD10` 0..1 Coding<br>`ICD11` 0..1 Coding |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Condition.code.coding:ICD10` | `https://fhir.minsalud.gov.co/rda/ValueSet/ICD10Codes` |
| `Condition.code.coding:ICD11` | `https://fhir.minsalud.gov.co/rda/ValueSet/ICD11Codes` |

## DocumentReferenceEPIRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/DocumentReferenceEPIRDA`
- Tipo: `DocumentReference`; base: `http://hl7.org/fhir/StructureDefinition/DocumentReference`
- Descripción: Perfil FHIR para la referencia de documentos de epicrisis para soporte de atención en salud, para su intercambio en un documento RDA en Colombia.  Documento clínico o administrativo relacionado con la atención en salud de un paciente, que se adjunta en la historia clínica electrónica como soporte en formato electrónico (por ejemplo, PDF).  La referencia de documentos de epicrisis permite adjuntar, identificar y compartir información relevante del resumen de la historia clínica de la persona que ha recibido servicios de urgencia con observación, internación (hospitalización) o procedimientos quirúrgicos, cuyo contenido, según la resolución 2284 de 2023, se especifica a continuación (Ver: ANEXO TÉCNICO NO. 1, SOPORTES DE COBRO):  * Nombres y apellido á de la persona * Tipo y número de documento de identificación de la persona * Edad y sexo biológico de la persona * Servicio de ingreso de acuerdo con REPS * Hora y fecha de ingreso * Servicio de egreso de acuerdo con REPS * Hora y fecha de egreso * Motivo de consulta (Referido por la persona) * Enfermedad actual (respuesta mínima a las 'siguientes preguntas ¿Cuándo? ¿Cómo?     - Evolución, estado actual y tratamiento), Descripción de las condiciones que llevaron a la atención: Tiempo de evolución, desencadenantes, mitigadores, estado actual y tratamientos realizados (médicos o no médicos) * Antecedentes médicos, quirúrgicos, tóxicos alérgicos y los demás pertinentes de acuerdo a la atención recibida * Revisión por sistemas relacionada con la enfermedad actual * Hallazgos del examen físico, incluye signos vitales (Tensión Arterial, Frecuencia Cardiaca, Frecuencia Respiratoria, Temperatura, Saturación de oxígeno) * Diagnóstico de ingreso (presuntivos, confirmados y relacionados según la Clasificación Internacional de Enfermedades y el Listado de Enfermedades Huérfanas). * Conducta, incluye la solicitud de apoyo diagnóstico (CUPS) y el plan de manejo terapéutico (CUM o IUM) * Cambios en el estado de salud de la persona que conlleven a modificar la conducta, el manejo o justifiquen la estancia, incluye complicaciones o eventos adversos durante la estancia o procedimiento quirúrgico * Interpretación de los resultados de los procedimientos de apoyo diagnóstico y de todo aquello que justifique cambios o continuidad en el manejo o del diagnóstico * Justificación de indicaciones terapéuticas cuando éstas lo ameriten * Diagnósticos de egreso (presuntivos, confirmados y relacionados según la Clasificación Internacional de Enfermedades y el Listado de Enfermedades Huérfanas) * Condiciones generales a la salida de la persona (estado: vivo o muerto) y si hubiere incapacidad médica temporal incluir el número de días. * Plan de manejo ambulatorio incluye el manejo terapéutico, apoyo diagnóstico y consultas médicas generales o especializadas * Nombres, apellidos, tipo y número del documento de identificación del profesional tratante que diligencia el documento.  Incluir documento PDF legible (capa de texto) sin clave del documento pdf de la epicrisis de la hospitalización. La epicrisis debe cumplir con los contenidos establecidos en el Decreto 780 de 2016 Artículo 2.6.1.4.3.5

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `DocumentReference.meta.profile` | 1..* | canonical(StructureDefinition) | si `DocumentReference.meta` |
| `DocumentReference.masterIdentifier.value` | 1..1 | string | si `DocumentReference.masterIdentifier` |
| `DocumentReference.status` | 1..1 | code |  |
| `DocumentReference.type` | 1..1 | CodeableConcept |  |
| `DocumentReference.type.coding` | 2..* | Coding |  |
| `DocumentReference.type.coding:LOINC` | 1..1 | Coding |  |
| `DocumentReference.type.coding:LOINC.system` | 1..1 | uri |  |
| `DocumentReference.type.coding:LOINC.code` | 1..1 | code |  |
| `DocumentReference.type.coding:LOINC.display` | 1..1 | string |  |
| `DocumentReference.type.coding:R2284` | 1..1 | Coding |  |
| `DocumentReference.type.coding:R2284.system` | 1..1 | uri |  |
| `DocumentReference.type.coding:R2284.code` | 1..1 | code |  |
| `DocumentReference.type.coding:R2284.display` | 1..1 | string |  |
| `DocumentReference.category` | 1..1 | CodeableConcept |  |
| `DocumentReference.subject` | 1..1 | Reference(PatientRDA) |  |
| `DocumentReference.date` | 1..1 | instant |  |
| `DocumentReference.author` | 1..1 | Reference(CareDeliveryOrganizationRDA, PractitionerRDA) |  |
| `DocumentReference.custodian` | 1..1 | Reference(Organization) |  |
| `DocumentReference.description` | 1..1 | string |  |
| `DocumentReference.securityLabel` | 1..1 | CodeableConcept |  |
| `DocumentReference.securityLabel.coding.system` | 1..1 | uri | si `DocumentReference.securityLabel.coding` |
| `DocumentReference.securityLabel.coding.code` | 1..1 | code | si `DocumentReference.securityLabel.coding` |
| `DocumentReference.securityLabel.coding.display` | 1..1 | string | si `DocumentReference.securityLabel.coding` |
| `DocumentReference.content` | 1..1 | BackboneElement |  |
| `DocumentReference.content.attachment` | 1..1 | Attachment |  |
| `DocumentReference.content.format.system` | 1..1 | uri | si `DocumentReference.content.format` |
| `DocumentReference.content.format.code` | 1..1 | code | si `DocumentReference.content.format` |
| `DocumentReference.context.encounter` | 1..1 | Reference(EncounterAmbulatoryRDA, EncounterEmergencyRDA, EncounterHospitalizationRDA) | si `DocumentReference.context` |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `DocumentReference.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/DocumentReferenceEPIRDA"` |
| `DocumentReference.masterIdentifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/EPI"` |
| `DocumentReference.status` | `fixedCode` | `"current"` |
| `DocumentReference.type.coding:LOINC.system` | `fixedUri` | `"http://loinc.org"` |
| `DocumentReference.type.coding:LOINC.code` | `fixedCode` | `"18842-5"` |
| `DocumentReference.type.coding:LOINC.display` | `fixedString` | `"Discharge summary"` |
| `DocumentReference.type.coding:R2284.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDocumentTypes"` |
| `DocumentReference.type.coding:R2284.code` | `fixedCode` | `"EPI"` |
| `DocumentReference.type.coding:R2284.display` | `fixedString` | `"Epicrisis"` |
| `DocumentReference.category.coding.system` | `fixedUri` | `"http://loinc.org"` |
| `DocumentReference.category.coding.code` | `fixedCode` | `"55108-5"` |
| `DocumentReference.category.coding.display` | `fixedString` | `"Clinical presentation Document"` |
| `DocumentReference.custodian.reference` | `patternString` | `"Organization/MinSalud"` |
| `DocumentReference.description` | `fixedString` | `"Epicrisis del encuentro de atención en salud - RDA"` |
| `DocumentReference.securityLabel.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v3-Confidentiality"` |
| `DocumentReference.securityLabel.coding.code` | `fixedCode` | `"R"` |
| `DocumentReference.securityLabel.coding.display` | `fixedString` | `"restricted"` |
| `DocumentReference.content.format.system` | `fixedUri` | `"urn:ietf:bcp:13"` |
| `DocumentReference.content.format.code` | `fixedCode` | `"application/pdf"` |
| `DocumentReference.content.format.display` | `fixedString` | `"PDF"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `DocumentReference.extension` | value:url | open | `ExtensionContentSignatureRDA` 0..1 Extension(ExtensionContentSignatureRDA) |
| `DocumentReference.type.coding` | value:system | closed | `LOINC` 1..1 Coding<br>`R2284` 1..1 Coding |

## DocumentReferenceRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/DocumentReferenceRDA`
- Tipo: `DocumentReference`; base: `http://hl7.org/fhir/StructureDefinition/DocumentReference`
- Descripción: Perfil FHIR para la referencia de documentos FHIR RDA en Colombia, siguiendo el perfil IHE XDS (Cross-enterprise Document Sharing).  Documento clínico o administrativo relacionado con la atención en salud de un paciente, que se adjunta en la historia clínica electrónica como soporte en formato electrónico (por ejemplo, PDF).  La referencia de documentos FHIR permite adjuntar, identificar y compartir información relevante del resumen de la historia clínica de la persona que ha recibido servicios de urgencia con observación, internación (hospitalización) o procedimientos quirúrgicos, cuyo contenido, según la resolución 2284 de 2023, se especifica a continuación (Ver: ANEXO TÉCNICO NO. 1, SOPORTES DE COBRO):

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `DocumentReference.meta.profile` | 1..* | canonical(StructureDefinition) | si `DocumentReference.meta` |
| `DocumentReference.masterIdentifier.value` | 1..1 | string | si `DocumentReference.masterIdentifier` |
| `DocumentReference.status` | 1..1 | code |  |
| `DocumentReference.type` | 1..1 | CodeableConcept |  |
| `DocumentReference.type.coding` | 1..* | Coding |  |
| `DocumentReference.type.coding:LOINC` | 1..1 | Coding |  |
| `DocumentReference.type.coding:LOINC.system` | 1..1 | uri |  |
| `DocumentReference.type.coding:LOINC.code` | 1..1 | code |  |
| `DocumentReference.type.coding:LOINC.display` | 1..1 | string |  |
| `DocumentReference.category` | 1..1 | CodeableConcept |  |
| `DocumentReference.subject` | 1..1 | Reference(PatientRDA) |  |
| `DocumentReference.author` | 1..1 | Reference(CareDeliveryOrganizationRDA, PractitionerRDA) |  |
| `DocumentReference.custodian` | 1..1 | Reference(Organization) |  |
| `DocumentReference.description` | 1..1 | string |  |
| `DocumentReference.securityLabel` | 1..1 | CodeableConcept |  |
| `DocumentReference.securityLabel.coding.system` | 1..1 | uri | si `DocumentReference.securityLabel.coding` |
| `DocumentReference.securityLabel.coding.code` | 1..1 | code | si `DocumentReference.securityLabel.coding` |
| `DocumentReference.securityLabel.coding.display` | 1..1 | string | si `DocumentReference.securityLabel.coding` |
| `DocumentReference.content` | 1..1 | BackboneElement |  |
| `DocumentReference.content.attachment` | 1..1 | Attachment |  |
| `DocumentReference.content.attachment.url` | 1..1 | url |  |
| `DocumentReference.content.format.system` | 1..1 | uri | si `DocumentReference.content.format` |
| `DocumentReference.content.format.code` | 1..1 | code | si `DocumentReference.content.format` |
| `DocumentReference.context.encounter` | 1..1 | Reference(EncounterAmbulatoryRDA, EncounterEmergencyRDA, EncounterHospitalizationRDA) | si `DocumentReference.context` |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `DocumentReference.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/DocumentReferenceRDA"` |
| `DocumentReference.masterIdentifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/identifier-RDA"` |
| `DocumentReference.status` | `fixedCode` | `"current"` |
| `DocumentReference.type.coding:LOINC.system` | `fixedUri` | `"http://loinc.org"` |
| `DocumentReference.type.coding:LOINC.code` | `fixedCode` | `"18842-5"` |
| `DocumentReference.type.coding:LOINC.display` | `fixedString` | `"Discharge summary"` |
| `DocumentReference.category.coding.system` | `fixedUri` | `"http://loinc.org"` |
| `DocumentReference.category.coding.code` | `fixedCode` | `"55108-5"` |
| `DocumentReference.category.coding.display` | `fixedString` | `"Clinical presentation Document"` |
| `DocumentReference.custodian.reference` | `patternString` | `"Organization/MinSalud"` |
| `DocumentReference.description` | `fixedString` | `"Documento FHIR del encuentro de atención en salud - RDA"` |
| `DocumentReference.securityLabel.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v3-Confidentiality"` |
| `DocumentReference.securityLabel.coding.code` | `fixedCode` | `"R"` |
| `DocumentReference.securityLabel.coding.display` | `fixedString` | `"restricted"` |
| `DocumentReference.content.format.system` | `fixedUri` | `"http://ihe.net/fhir/ValueSet/IHE.FormatCode.codesystem"` |
| `DocumentReference.content.format.code` | `fixedCode` | `"urn:ihe:iti:xds:2017:mimeTypeSufficient"` |
| `DocumentReference.content.format.display` | `fixedString` | `"mimeType Sufficient"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `DocumentReference.type.coding` | value:system | closed | `LOINC` 1..1 Coding |

## EncounterAmbulatoryRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/EncounterAmbulatoryRDA`
- Tipo: `Encounter`; base: `http://hl7.org/fhir/StructureDefinition/Encounter`
- Descripción: Perfil FHIR del encuentro ambulatorio de atención en salud, para su intercambio en un documento RDA en Colombia.  Información sobre un encuentro de atención en ámbito ambulatorio, mediante el cual una persona accede a servicios de salud programados o por demanda espontánea, que no requieren hospitalización ni estancia prolongada, y que se desarrollan en un entorno ambulatorio, tales como consultorios, unidades móviles o servicios externos.  Este tipo de encuentro de atención está orientado principalmente a la evaluación diagnóstica, seguimiento, tratamiento médico o consejería, y puede ocurrir en contextos de atención primaria, especializada o de salud pública.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Encounter.meta.profile` | 1..* | canonical(StructureDefinition) | si `Encounter.meta` |
| `Encounter.identifier:EncounterIdentifier.id` | 1..1 | String | si `Encounter.identifier:EncounterIdentifier` |
| `Encounter.identifier:EncounterIdentifier.use` | 1..1 | code | si `Encounter.identifier:EncounterIdentifier` |
| `Encounter.identifier:EncounterIdentifier.system` | 1..1 | uri | si `Encounter.identifier:EncounterIdentifier` |
| `Encounter.identifier:EncounterIdentifier.value` | 1..1 | string | si `Encounter.identifier:EncounterIdentifier` |
| `Encounter.status` | 1..1 | code |  |
| `Encounter.statusHistory.status` | 1..1 | code | si `Encounter.statusHistory` |
| `Encounter.statusHistory.period` | 1..1 | Period | si `Encounter.statusHistory` |
| `Encounter.class` | 1..1 | Coding |  |
| `Encounter.class.code` | 1..1 | code |  |
| `Encounter.class.display` | 1..1 | string |  |
| `Encounter.classHistory.class` | 1..1 | Coding | si `Encounter.classHistory` |
| `Encounter.classHistory.period` | 1..1 | Period | si `Encounter.classHistory` |
| `Encounter.type` | 3..5 | CodeableConcept |  |
| `Encounter.type:encounterModality` | 1..1 | CodeableConcept |  |
| `Encounter.type:encounterModality.coding` | 1..1 | Coding |  |
| `Encounter.type:encounterModality.coding.system` | 1..1 | uri |  |
| `Encounter.type:encounterModality.coding.code` | 1..1 | code |  |
| `Encounter.type:encounterModality.coding.display` | 1..1 | string |  |
| `Encounter.type:encounterServiceGroup` | 1..1 | CodeableConcept |  |
| `Encounter.type:encounterServiceGroup.coding` | 1..1 | Coding |  |
| `Encounter.type:encounterServiceGroup.coding.system` | 1..1 | uri |  |
| `Encounter.type:encounterServiceGroup.coding.code` | 1..1 | code |  |
| `Encounter.type:encounterServiceGroup.coding.display` | 1..1 | string |  |
| `Encounter.type:encounterService.coding` | 1..1 | Coding | si `Encounter.type:encounterService` |
| `Encounter.type:encounterService.coding.system` | 1..1 | uri | si `Encounter.type:encounterService` |
| `Encounter.type:encounterService.coding.code` | 1..1 | code | si `Encounter.type:encounterService` |
| `Encounter.type:encounterService.coding.display` | 1..1 | string | si `Encounter.type:encounterService` |
| `Encounter.type:encounterEnvironment` | 1..1 | CodeableConcept |  |
| `Encounter.type:encounterEnvironment.coding` | 1..1 | Coding |  |
| `Encounter.type:encounterEnvironment.coding.system` | 1..1 | uri |  |
| `Encounter.type:encounterEnvironment.coding.code` | 1..1 | code |  |
| `Encounter.type:encounterEnvironment.coding.display` | 1..1 | string |  |
| `Encounter.type:encounterAmbitosAtencionMipres.coding` | 1..1 | Coding | si `Encounter.type:encounterAmbitosAtencionMipres` |
| `Encounter.type:encounterAmbitosAtencionMipres.coding.system` | 1..1 | uri | si `Encounter.type:encounterAmbitosAtencionMipres` |
| `Encounter.type:encounterAmbitosAtencionMipres.coding.code` | 1..1 | code | si `Encounter.type:encounterAmbitosAtencionMipres` |
| `Encounter.type:encounterAmbitosAtencionMipres.coding.display` | 1..1 | string | si `Encounter.type:encounterAmbitosAtencionMipres` |
| `Encounter.serviceType` | 1..1 | CodeableConcept |  |
| `Encounter.serviceType.coding.system` | 1..1 | uri | si `Encounter.serviceType.coding` |
| `Encounter.serviceType.coding.code` | 1..1 | code | si `Encounter.serviceType.coding` |
| `Encounter.serviceType.coding.display` | 1..1 | string | si `Encounter.serviceType.coding` |
| `Encounter.subject` | 1..1 | Reference(PatientRDA) |  |
| `Encounter.participant` | 1..1 | BackboneElement |  |
| `Encounter.participant:AttenderPhysician` | 1..1 | BackboneElement |  |
| `Encounter.participant:AttenderPhysician.id` | 1..1 | String |  |
| `Encounter.participant:AttenderPhysician.type` | 1..1 | CodeableConcept |  |
| `Encounter.participant:AttenderPhysician.type.coding` | 1..1 | Coding |  |
| `Encounter.participant:AttenderPhysician.type.coding.system` | 1..1 | uri |  |
| `Encounter.participant:AttenderPhysician.type.coding.code` | 1..1 | code |  |
| `Encounter.participant:AttenderPhysician.type.coding.display` | 1..1 | string |  |
| `Encounter.participant:AttenderPhysician.individual` | 1..1 | Reference(PractitionerRDA) |  |
| `Encounter.period` | 1..1 | Period |  |
| `Encounter.period.start` | 1..1 | dateTime |  |
| `Encounter.period.end` | 1..1 | dateTime |  |
| `Encounter.reasonCode` | 1..1 | CodeableConcept |  |
| `Encounter.reasonCode.coding.system` | 1..1 | uri | si `Encounter.reasonCode.coding` |
| `Encounter.reasonCode.coding.code` | 1..1 | code | si `Encounter.reasonCode.coding` |
| `Encounter.reasonCode.coding.display` | 1..1 | string | si `Encounter.reasonCode.coding` |
| `Encounter.diagnosis` | 1..4 | BackboneElement |  |
| `Encounter.diagnosis.condition` | 1..1 | Reference(Condition, Procedure) |  |
| `Encounter.diagnosis:MainDiagnosis` | 1..1 | BackboneElement |  |
| `Encounter.diagnosis:MainDiagnosis.id` | 1..1 | String |  |
| `Encounter.diagnosis:MainDiagnosis.extension` | 1..* | Extension |  |
| `Encounter.diagnosis:MainDiagnosis.extension:ExtensionDiagnosisType` | 1..1 | Extension(ExtensionDiagnosisType) |  |
| `Encounter.diagnosis:MainDiagnosis.condition` | 1..1 | Reference(ConditionRDA) |  |
| `Encounter.diagnosis:MainDiagnosis.use` | 1..1 | CodeableConcept |  |
| `Encounter.diagnosis:MainDiagnosis.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:MainDiagnosis.use.coding` |
| `Encounter.diagnosis:MainDiagnosis.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:MainDiagnosis.use.coding` |
| `Encounter.diagnosis:MainDiagnosis.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:MainDiagnosis.use.coding` |
| `Encounter.diagnosis:MainDiagnosis.rank` | 1..1 | positiveInt |  |
| `Encounter.diagnosis:Comorbidity-1.id` | 1..1 | String | si `Encounter.diagnosis:Comorbidity-1` |
| `Encounter.diagnosis:Comorbidity-1.condition` | 1..1 | Reference(ConditionRDA) | si `Encounter.diagnosis:Comorbidity-1` |
| `Encounter.diagnosis:Comorbidity-1.use` | 1..1 | CodeableConcept | si `Encounter.diagnosis:Comorbidity-1` |
| `Encounter.diagnosis:Comorbidity-1.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:Comorbidity-1` |
| `Encounter.diagnosis:Comorbidity-1.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:Comorbidity-1` |
| `Encounter.diagnosis:Comorbidity-1.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:Comorbidity-1` |
| `Encounter.diagnosis:Comorbidity-1.rank` | 1..1 | positiveInt | si `Encounter.diagnosis:Comorbidity-1` |
| `Encounter.diagnosis:Comorbidity-2.id` | 1..1 | String | si `Encounter.diagnosis:Comorbidity-2` |
| `Encounter.diagnosis:Comorbidity-2.condition` | 1..1 | Reference(ConditionRDA) | si `Encounter.diagnosis:Comorbidity-2` |
| `Encounter.diagnosis:Comorbidity-2.use` | 1..1 | CodeableConcept | si `Encounter.diagnosis:Comorbidity-2` |
| `Encounter.diagnosis:Comorbidity-2.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:Comorbidity-2` |
| `Encounter.diagnosis:Comorbidity-2.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:Comorbidity-2` |
| `Encounter.diagnosis:Comorbidity-2.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:Comorbidity-2` |
| `Encounter.diagnosis:Comorbidity-2.rank` | 1..1 | positiveInt | si `Encounter.diagnosis:Comorbidity-2` |
| `Encounter.diagnosis:Comorbidity-3.id` | 1..1 | String | si `Encounter.diagnosis:Comorbidity-3` |
| `Encounter.diagnosis:Comorbidity-3.condition` | 1..1 | Reference(ConditionRDA) | si `Encounter.diagnosis:Comorbidity-3` |
| `Encounter.diagnosis:Comorbidity-3.use` | 1..1 | CodeableConcept | si `Encounter.diagnosis:Comorbidity-3` |
| `Encounter.diagnosis:Comorbidity-3.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:Comorbidity-3` |
| `Encounter.diagnosis:Comorbidity-3.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:Comorbidity-3` |
| `Encounter.diagnosis:Comorbidity-3.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:Comorbidity-3` |
| `Encounter.diagnosis:Comorbidity-3.rank` | 1..1 | positiveInt | si `Encounter.diagnosis:Comorbidity-3` |
| `Encounter.location.location` | 1..1 | Reference(CareDeliveryLocationRDA) | si `Encounter.location` |

### Must-support opcionales

`Encounter.diagnosis:Comorbidity-1` 0..1 · `Encounter.diagnosis:Comorbidity-2` 0..1 · `Encounter.diagnosis:Comorbidity-3` 0..1 · `Encounter.location` 0..* · `Encounter.serviceProvider` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Encounter.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/EncounterAmbulatoryRDA"` |
| `Encounter.identifier:EncounterIdentifier.id` | `fixedString` | `"EncounterIdentifier"` |
| `Encounter.identifier:EncounterIdentifier.use` | `patternCode` | `"usual"` |
| `Encounter.identifier:EncounterIdentifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/Encounters"` |
| `Encounter.status` | `fixedCode` | `"finished"` |
| `Encounter.class.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v3-ActCode"` |
| `Encounter.class.code` | `fixedCode` | `"AMB"` |
| `Encounter.class.display` | `fixedString` | `"ambulatory"` |
| `Encounter.type:encounterModality.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianTechModality"` |
| `Encounter.type:encounterServiceGroup.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/GrupoServicios"` |
| `Encounter.type:encounterServiceGroup.coding.code` | `fixedCode` | `"01"` |
| `Encounter.type:encounterServiceGroup.coding.display` | `fixedString` | `"Consulta externa"` |
| `Encounter.type:encounterService.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/REPShealthcareServices"` |
| `Encounter.type:encounterEnvironment.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/EntornoAtencion"` |
| `Encounter.type:encounterAmbitosAtencionMipres.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/MipresAmbitosAtencion"` |
| `Encounter.serviceType.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/CUPS"` |
| `Encounter.participant:AttenderPhysician.id` | `patternString` | `"AttenderPhysician"` |
| `Encounter.participant:AttenderPhysician.type.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v3-ParticipationType"` |
| `Encounter.participant:AttenderPhysician.type.coding.code` | `fixedCode` | `"ATND"` |
| `Encounter.participant:AttenderPhysician.type.coding.display` | `fixedString` | `"attender"` |
| `Encounter.reasonCode.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/RIPSCausaExternaVersion2"` |
| `Encounter.diagnosis:MainDiagnosis.id` | `patternString` | `"MainDiagnosis"` |
| `Encounter.diagnosis:MainDiagnosis.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:MainDiagnosis.use.coding.code` | `fixedCode` | `"8319008"` |
| `Encounter.diagnosis:MainDiagnosis.use.coding.display` | `fixedString` | `"diagnóstico primario"` |
| `Encounter.diagnosis:MainDiagnosis.rank` | `fixedPositiveInt` | `1` |
| `Encounter.diagnosis:Comorbidity-1.id` | `patternString` | `"Comorbidity-1"` |
| `Encounter.diagnosis:Comorbidity-1.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:Comorbidity-1.use.coding.code` | `fixedCode` | `"398192003"` |
| `Encounter.diagnosis:Comorbidity-1.use.coding.display` | `fixedString` | `"comorbilidades"` |
| `Encounter.diagnosis:Comorbidity-1.rank` | `fixedPositiveInt` | `2` |
| `Encounter.diagnosis:Comorbidity-2.id` | `patternString` | `"Comorbidity-2"` |
| `Encounter.diagnosis:Comorbidity-2.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:Comorbidity-2.use.coding.code` | `fixedCode` | `"398192003"` |
| `Encounter.diagnosis:Comorbidity-2.use.coding.display` | `fixedString` | `"comorbilidades"` |
| `Encounter.diagnosis:Comorbidity-2.rank` | `fixedPositiveInt` | `3` |
| `Encounter.diagnosis:Comorbidity-3.id` | `patternString` | `"Comorbidity-3"` |
| `Encounter.diagnosis:Comorbidity-3.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:Comorbidity-3.use.coding.code` | `fixedCode` | `"398192003"` |
| `Encounter.diagnosis:Comorbidity-3.use.coding.display` | `fixedString` | `"comorbilidades"` |
| `Encounter.diagnosis:Comorbidity-3.rank` | `fixedPositiveInt` | `4` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Encounter.extension` | value:url | open | `ExtensionDischargeDisposition` 0..1 Extension(ExtensionDischargeDisposition) |
| `Encounter.identifier` | value:id ⚑ | closed | `EncounterIdentifier` 0..1 Identifier |
| `Encounter.type` | value:coding.system | closed | `encounterModality` 1..1 CodeableConcept<br>`encounterServiceGroup` 1..1 CodeableConcept<br>`encounterService` 0..1 CodeableConcept<br>`encounterEnvironment` 1..1 CodeableConcept<br>`encounterAmbitosAtencionMipres` 0..1 CodeableConcept |
| `Encounter.participant` | value:type | closed | `AttenderPhysician` 1..1 BackboneElement |
| `Encounter.diagnosis` | value:rank | closed | `MainDiagnosis` 1..1 BackboneElement<br>`Comorbidity-1` 0..1 BackboneElement<br>`Comorbidity-2` 0..1 BackboneElement<br>`Comorbidity-3` 0..1 BackboneElement |
| `Encounter.diagnosis:MainDiagnosis.extension` | value:url | open | `ExtensionDiagnosisType` 1..1 Extension(ExtensionDiagnosisType) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Encounter.type:encounterModality` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianTechModalityCodes` |
| `Encounter.type:encounterServiceGroup` | `https://fhir.minsalud.gov.co/rda/ValueSet/GrupoServiciosCodigos` |
| `Encounter.type:encounterService` | `https://fhir.minsalud.gov.co/rda/ValueSet/REPShealthcareServiceCodes` |
| `Encounter.type:encounterEnvironment` | `https://fhir.minsalud.gov.co/rda/ValueSet/EntornoAtencionCodigos` |
| `Encounter.type:encounterAmbitosAtencionMipres` | `https://fhir.minsalud.gov.co/rda/ValueSet/MipresAmbitosAtencionAmbulatorio` |
| `Encounter.serviceType` | `https://fhir.minsalud.gov.co/rda/ValueSet/CUPSConsultationCodes` |
| `Encounter.reasonCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/RIPSCausaExternaVersion2Codigos` |
| `Encounter.diagnosis:MainDiagnosis.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:Comorbidity-1.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:Comorbidity-2.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:Comorbidity-3.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |

### Invariantes del perfil

| Clave | Severidad | Elemento | Regla | Expresión |
| --- | --- | --- | --- | --- |
| `inv-enc-period-valid-range-enc-amb` | error | `Encounter.period` | La fecha del encuentro (start y end) no puede ser mayor a la fecha actual | `start.exists() and end.exists() and start <= end and start <= now() and end <= now()` |
| `inv-enc-period-max-1year-enc-amb` | error | `Encounter.period` | La fecha del encuentro (inicio y fin) no puede ser de hace más de un año. | `start.toDate() >= today() - 1 year and end.toDate() >= today() - 1 year` |
| `inv-period-full-date-enc-amb` | error | `Encounter.period` | Las fechas del periodo (start y end) deben incluir al menos día, mes y año (formato AAAA-MM-DD); no se acepta una fecha con solo el año (AAAA) o solo año y mes (AAAA-MM). | `(start.exists() implies start.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*')) and (end.exists() implies end.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*'))` |

## EncounterEmergencyRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/EncounterEmergencyRDA`
- Tipo: `Encounter`; base: `http://hl7.org/fhir/StructureDefinition/Encounter`
- Descripción: Perfil FHIR del encuentro de atención de urgencias en salud (urgencia que genera observación), para su intercambio en un documento RDA en Colombia.  Información sobre la atención de urgencias que se inicia cuando una persona acude o es llevada a un servicio de salud por una condición aguda, inesperada o potencialmente grave, que requiere atención médica inmediata, sin programación previa.  Este tipo de atención tiene como propósito estabilizar al paciente, resolver o controlar el evento agudo, y tomar decisiones oportunas sobre la necesidad de traslado, hospitalización o alta.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Encounter.meta.profile` | 1..* | canonical(StructureDefinition) | si `Encounter.meta` |
| `Encounter.identifier:EncounterIdentifier.id` | 1..1 | String | si `Encounter.identifier:EncounterIdentifier` |
| `Encounter.identifier:EncounterIdentifier.use` | 1..1 | code | si `Encounter.identifier:EncounterIdentifier` |
| `Encounter.identifier:EncounterIdentifier.system` | 1..1 | uri | si `Encounter.identifier:EncounterIdentifier` |
| `Encounter.identifier:EncounterIdentifier.value` | 1..1 | string | si `Encounter.identifier:EncounterIdentifier` |
| `Encounter.status` | 1..1 | code |  |
| `Encounter.statusHistory.status` | 1..1 | code | si `Encounter.statusHistory` |
| `Encounter.statusHistory.period` | 1..1 | Period | si `Encounter.statusHistory` |
| `Encounter.class` | 1..1 | Coding |  |
| `Encounter.class.code` | 1..1 | code |  |
| `Encounter.class.display` | 1..1 | string |  |
| `Encounter.classHistory.class` | 1..1 | Coding | si `Encounter.classHistory` |
| `Encounter.classHistory.period` | 1..1 | Period | si `Encounter.classHistory` |
| `Encounter.type` | 3..4 | CodeableConcept |  |
| `Encounter.type:encounterModality` | 1..1 | CodeableConcept |  |
| `Encounter.type:encounterModality.coding` | 1..1 | Coding |  |
| `Encounter.type:encounterModality.coding.system` | 1..1 | uri |  |
| `Encounter.type:encounterModality.coding.code` | 1..1 | code |  |
| `Encounter.type:encounterModality.coding.display` | 1..1 | string |  |
| `Encounter.type:encounterServiceGroup` | 1..1 | CodeableConcept |  |
| `Encounter.type:encounterServiceGroup.coding` | 1..1 | Coding |  |
| `Encounter.type:encounterServiceGroup.coding.system` | 1..1 | uri |  |
| `Encounter.type:encounterServiceGroup.coding.code` | 1..1 | code |  |
| `Encounter.type:encounterServiceGroup.coding.display` | 1..1 | string |  |
| `Encounter.type:encounterEnvironment` | 1..1 | CodeableConcept |  |
| `Encounter.type:encounterEnvironment.coding` | 1..1 | Coding |  |
| `Encounter.type:encounterEnvironment.coding.system` | 1..1 | uri |  |
| `Encounter.type:encounterEnvironment.coding.code` | 1..1 | code |  |
| `Encounter.type:encounterEnvironment.coding.display` | 1..1 | string |  |
| `Encounter.type:encounterAmbitosAtencionMipres.coding` | 1..1 | Coding | si `Encounter.type:encounterAmbitosAtencionMipres` |
| `Encounter.type:encounterAmbitosAtencionMipres.coding.system` | 1..1 | uri | si `Encounter.type:encounterAmbitosAtencionMipres` |
| `Encounter.type:encounterAmbitosAtencionMipres.coding.code` | 1..1 | code | si `Encounter.type:encounterAmbitosAtencionMipres` |
| `Encounter.type:encounterAmbitosAtencionMipres.coding.display` | 1..1 | string | si `Encounter.type:encounterAmbitosAtencionMipres` |
| `Encounter.subject` | 1..1 | Reference(PatientRDA) |  |
| `Encounter.participant` | 1..1 | BackboneElement |  |
| `Encounter.participant:DischargePhysician` | 1..1 | BackboneElement |  |
| `Encounter.participant:DischargePhysician.id` | 1..1 | String |  |
| `Encounter.participant:DischargePhysician.type` | 1..1 | CodeableConcept |  |
| `Encounter.participant:DischargePhysician.type.coding` | 1..1 | Coding |  |
| `Encounter.participant:DischargePhysician.type.coding.system` | 1..1 | uri |  |
| `Encounter.participant:DischargePhysician.type.coding.code` | 1..1 | code |  |
| `Encounter.participant:DischargePhysician.type.coding.display` | 1..1 | string |  |
| `Encounter.participant:DischargePhysician.individual` | 1..1 | Reference(PractitionerRDA) |  |
| `Encounter.period` | 1..1 | Period |  |
| `Encounter.period.start` | 1..1 | dateTime |  |
| `Encounter.period.end` | 1..1 | dateTime |  |
| `Encounter.reasonCode` | 1..1 | CodeableConcept |  |
| `Encounter.reasonCode.coding.system` | 1..1 | uri | si `Encounter.reasonCode.coding` |
| `Encounter.reasonCode.coding.code` | 1..1 | code | si `Encounter.reasonCode.coding` |
| `Encounter.reasonCode.coding.display` | 1..1 | string | si `Encounter.reasonCode.coding` |
| `Encounter.diagnosis` | 2..5 | BackboneElement |  |
| `Encounter.diagnosis.condition` | 1..1 | Reference(Condition, Procedure) |  |
| `Encounter.diagnosis:AdmissionDiagnosis` | 1..1 | BackboneElement |  |
| `Encounter.diagnosis:AdmissionDiagnosis.id` | 1..1 | String |  |
| `Encounter.diagnosis:AdmissionDiagnosis.extension` | 1..* | Extension |  |
| `Encounter.diagnosis:AdmissionDiagnosis.extension:ExtensionDiagnosisType` | 1..1 | Extension(ExtensionDiagnosisType) |  |
| `Encounter.diagnosis:AdmissionDiagnosis.condition` | 1..1 | Reference(ConditionRDA) |  |
| `Encounter.diagnosis:AdmissionDiagnosis.use` | 1..1 | CodeableConcept |  |
| `Encounter.diagnosis:AdmissionDiagnosis.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:AdmissionDiagnosis.use.coding` |
| `Encounter.diagnosis:AdmissionDiagnosis.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:AdmissionDiagnosis.use.coding` |
| `Encounter.diagnosis:AdmissionDiagnosis.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:AdmissionDiagnosis.use.coding` |
| `Encounter.diagnosis:AdmissionDiagnosis.rank` | 1..1 | positiveInt |  |
| `Encounter.diagnosis:DischargeDiagnosis` | 1..1 | BackboneElement |  |
| `Encounter.diagnosis:DischargeDiagnosis.id` | 1..1 | String |  |
| `Encounter.diagnosis:DischargeDiagnosis.extension` | 1..* | Extension |  |
| `Encounter.diagnosis:DischargeDiagnosis.extension:ExtensionDiagnosisType` | 1..1 | Extension(ExtensionDiagnosisType) |  |
| `Encounter.diagnosis:DischargeDiagnosis.condition` | 1..1 | Reference(ConditionRDA) |  |
| `Encounter.diagnosis:DischargeDiagnosis.use` | 1..1 | CodeableConcept |  |
| `Encounter.diagnosis:DischargeDiagnosis.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:DischargeDiagnosis.use.coding` |
| `Encounter.diagnosis:DischargeDiagnosis.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:DischargeDiagnosis.use.coding` |
| `Encounter.diagnosis:DischargeDiagnosis.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:DischargeDiagnosis.use.coding` |
| `Encounter.diagnosis:DischargeDiagnosis.rank` | 1..1 | positiveInt |  |
| `Encounter.diagnosis:DischargeComorbidity-1.id` | 1..1 | String | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-1.condition` | 1..1 | Reference(ConditionRDA) | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-1.use` | 1..1 | CodeableConcept | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-1.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-1.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-1.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-1.rank` | 1..1 | positiveInt | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-2.id` | 1..1 | String | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-2.condition` | 1..1 | Reference(ConditionRDA) | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-2.use` | 1..1 | CodeableConcept | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-2.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-2.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-2.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-2.rank` | 1..1 | positiveInt | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-3.id` | 1..1 | String | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:DischargeComorbidity-3.condition` | 1..1 | Reference(ConditionRDA) | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:DischargeComorbidity-3.use` | 1..1 | CodeableConcept | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:DischargeComorbidity-3.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:DischargeComorbidity-3.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:DischargeComorbidity-3.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:DischargeComorbidity-3.rank` | 1..1 | positiveInt | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:ComplicationDiagnosis.id` | 1..1 | String | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.diagnosis:ComplicationDiagnosis.condition` | 1..1 | Reference(ConditionRDA) | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.diagnosis:ComplicationDiagnosis.use` | 1..1 | CodeableConcept | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.diagnosis:ComplicationDiagnosis.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.diagnosis:ComplicationDiagnosis.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.diagnosis:ComplicationDiagnosis.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.diagnosis:ComplicationDiagnosis.rank` | 1..1 | positiveInt | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.diagnosis:CauseOfDeath.id` | 1..1 | String | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.diagnosis:CauseOfDeath.condition` | 1..1 | Reference(ConditionRDA) | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.diagnosis:CauseOfDeath.use` | 1..1 | CodeableConcept | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.diagnosis:CauseOfDeath.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.diagnosis:CauseOfDeath.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.diagnosis:CauseOfDeath.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.diagnosis:CauseOfDeath.rank` | 1..1 | positiveInt | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.hospitalization.admitSource.coding.system` | 1..1 | uri | si `Encounter.hospitalization` |
| `Encounter.hospitalization.admitSource.coding.code` | 1..1 | code | si `Encounter.hospitalization` |
| `Encounter.hospitalization.admitSource.coding.display` | 1..1 | string | si `Encounter.hospitalization` |
| `Encounter.hospitalization.dischargeDisposition.coding.system` | 1..1 | uri | si `Encounter.hospitalization` |
| `Encounter.hospitalization.dischargeDisposition.coding.code` | 1..1 | code | si `Encounter.hospitalization` |
| `Encounter.hospitalization.dischargeDisposition.coding.display` | 1..1 | string | si `Encounter.hospitalization` |
| `Encounter.location.location` | 1..1 | Reference(CareDeliveryLocationRDA) | si `Encounter.location` |

### Must-support opcionales

`Encounter.diagnosis:DischargeComorbidity-1` 0..1 · `Encounter.diagnosis:DischargeComorbidity-2` 0..1 · `Encounter.diagnosis:DischargeComorbidity-3` 0..1 · `Encounter.diagnosis:ComplicationDiagnosis` 0..1 · `Encounter.diagnosis:CauseOfDeath` 0..1 · `Encounter.hospitalization.extension:ExtensionDischargeDeceasedStatus` 0..1 · `Encounter.hospitalization.admitSource` 0..1 · `Encounter.hospitalization.destination` 0..1 · `Encounter.hospitalization.dischargeDisposition` 0..1 · `Encounter.location` 0..* · `Encounter.serviceProvider` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Encounter.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/EncounterEmergencyRDA"` |
| `Encounter.identifier:EncounterIdentifier.id` | `fixedString` | `"EncounterIdentifier"` |
| `Encounter.identifier:EncounterIdentifier.use` | `patternCode` | `"usual"` |
| `Encounter.identifier:EncounterIdentifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/Encounters"` |
| `Encounter.status` | `fixedCode` | `"finished"` |
| `Encounter.class.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v3-ActCode"` |
| `Encounter.class.code` | `fixedCode` | `"EMER"` |
| `Encounter.class.display` | `fixedString` | `"emergency"` |
| `Encounter.type:encounterModality.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianTechModality"` |
| `Encounter.type:encounterServiceGroup.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/GrupoServicios"` |
| `Encounter.type:encounterServiceGroup.coding.code` | `fixedCode` | `"05"` |
| `Encounter.type:encounterServiceGroup.coding.display` | `fixedString` | `"Atención inmediata"` |
| `Encounter.type:encounterEnvironment.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/EntornoAtencion"` |
| `Encounter.type:encounterEnvironment.coding.code` | `fixedCode` | `"05"` |
| `Encounter.type:encounterEnvironment.coding.display` | `fixedString` | `"Institucional"` |
| `Encounter.type:encounterAmbitosAtencionMipres.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/MipresAmbitosAtencion"` |
| `Encounter.participant:DischargePhysician.id` | `patternString` | `"DischargePhysician"` |
| `Encounter.participant:DischargePhysician.type.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v3-ParticipationType"` |
| `Encounter.participant:DischargePhysician.type.coding.code` | `fixedCode` | `"DIS"` |
| `Encounter.participant:DischargePhysician.type.coding.display` | `fixedString` | `"discharger"` |
| `Encounter.reasonCode.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/RIPSCausaExternaVersion2"` |
| `Encounter.diagnosis:AdmissionDiagnosis.id` | `patternString` | `"AdmissionDiagnosis"` |
| `Encounter.diagnosis:AdmissionDiagnosis.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:AdmissionDiagnosis.use.coding.code` | `fixedCode` | `"52870002"` |
| `Encounter.diagnosis:AdmissionDiagnosis.use.coding.display` | `fixedString` | `"diagnóstico de ingreso"` |
| `Encounter.diagnosis:AdmissionDiagnosis.rank` | `fixedPositiveInt` | `1` |
| `Encounter.diagnosis:DischargeDiagnosis.id` | `patternString` | `"DischargeDiagnosis"` |
| `Encounter.diagnosis:DischargeDiagnosis.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:DischargeDiagnosis.use.coding.code` | `fixedCode` | `"89100005"` |
| `Encounter.diagnosis:DischargeDiagnosis.use.coding.display` | `fixedString` | `"diagnóstico final (alta)"` |
| `Encounter.diagnosis:DischargeDiagnosis.rank` | `fixedPositiveInt` | `2` |
| `Encounter.diagnosis:DischargeComorbidity-1.id` | `patternString` | `"DischargeComorbidity-1"` |
| `Encounter.diagnosis:DischargeComorbidity-1.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:DischargeComorbidity-1.use.coding.code` | `fixedCode` | `"398192003"` |
| `Encounter.diagnosis:DischargeComorbidity-1.use.coding.display` | `fixedString` | `"comorbilidades"` |
| `Encounter.diagnosis:DischargeComorbidity-1.rank` | `fixedPositiveInt` | `3` |
| `Encounter.diagnosis:DischargeComorbidity-2.id` | `patternString` | `"DischargeComorbidity-2"` |
| `Encounter.diagnosis:DischargeComorbidity-2.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:DischargeComorbidity-2.use.coding.code` | `fixedCode` | `"398192003"` |
| `Encounter.diagnosis:DischargeComorbidity-2.use.coding.display` | `fixedString` | `"comorbilidades"` |
| `Encounter.diagnosis:DischargeComorbidity-2.rank` | `fixedPositiveInt` | `4` |
| `Encounter.diagnosis:DischargeComorbidity-3.id` | `patternString` | `"DischargeComorbidity-3"` |
| `Encounter.diagnosis:DischargeComorbidity-3.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:DischargeComorbidity-3.use.coding.code` | `fixedCode` | `"398192003"` |
| `Encounter.diagnosis:DischargeComorbidity-3.use.coding.display` | `fixedString` | `"comorbilidades"` |
| `Encounter.diagnosis:DischargeComorbidity-3.rank` | `fixedPositiveInt` | `5` |
| `Encounter.diagnosis:ComplicationDiagnosis.id` | `patternString` | `"ComplicationDiagnosis"` |
| `Encounter.diagnosis:ComplicationDiagnosis.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:ComplicationDiagnosis.use.coding.code` | `fixedCode` | `"263718001"` |
| `Encounter.diagnosis:ComplicationDiagnosis.use.coding.display` | `fixedString` | `"complicación"` |
| `Encounter.diagnosis:ComplicationDiagnosis.rank` | `fixedPositiveInt` | `7` |
| `Encounter.diagnosis:CauseOfDeath.id` | `patternString` | `"CauseOfDeath"` |
| `Encounter.diagnosis:CauseOfDeath.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:CauseOfDeath.use.coding.code` | `fixedCode` | `"16100001"` |
| `Encounter.diagnosis:CauseOfDeath.use.coding.display` | `fixedString` | `"diagnóstico de la causa de muerte"` |
| `Encounter.diagnosis:CauseOfDeath.rank` | `fixedPositiveInt` | `6` |
| `Encounter.hospitalization.admitSource.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ViaIngreso"` |
| `Encounter.hospitalization.dischargeDisposition.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/CondicionyDestinoUsuarioEgreso"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Encounter.identifier` | value:id ⚑ | closed | `EncounterIdentifier` 0..1 Identifier |
| `Encounter.type` | value:coding.system | closed | `encounterModality` 1..1 CodeableConcept<br>`encounterServiceGroup` 1..1 CodeableConcept<br>`encounterEnvironment` 1..1 CodeableConcept<br>`encounterAmbitosAtencionMipres` 0..1 CodeableConcept |
| `Encounter.participant` | value:type | closed | `DischargePhysician` 1..1 BackboneElement |
| `Encounter.diagnosis` | value:rank | closed | `AdmissionDiagnosis` 1..1 BackboneElement<br>`DischargeDiagnosis` 1..1 BackboneElement<br>`DischargeComorbidity-1` 0..1 BackboneElement<br>`DischargeComorbidity-2` 0..1 BackboneElement<br>`DischargeComorbidity-3` 0..1 BackboneElement<br>`ComplicationDiagnosis` 0..1 BackboneElement<br>`CauseOfDeath` 0..1 BackboneElement |
| `Encounter.diagnosis:AdmissionDiagnosis.extension` | value:url | open | `ExtensionDiagnosisType` 1..1 Extension(ExtensionDiagnosisType) |
| `Encounter.diagnosis:DischargeDiagnosis.extension` | value:url | open | `ExtensionDiagnosisType` 1..1 Extension(ExtensionDiagnosisType) |
| `Encounter.hospitalization.extension` | value:url | open | `ExtensionDischargeDeceasedStatus` 0..1 Extension(ExtensionDischargeDeceasedStatus) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Encounter.type:encounterModality` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianTechModalityCodes` |
| `Encounter.type:encounterServiceGroup` | `https://fhir.minsalud.gov.co/rda/ValueSet/GrupoServiciosCodigos` |
| `Encounter.type:encounterEnvironment` | `https://fhir.minsalud.gov.co/rda/ValueSet/EntornoAtencionCodigos` |
| `Encounter.type:encounterAmbitosAtencionMipres` | `https://fhir.minsalud.gov.co/rda/ValueSet/MipresAmbitosAtencionUrgencias` |
| `Encounter.reasonCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/RIPSCausaExternaVersion2Codigos` |
| `Encounter.diagnosis:AdmissionDiagnosis.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:DischargeDiagnosis.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:DischargeComorbidity-1.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:DischargeComorbidity-2.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:DischargeComorbidity-3.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:ComplicationDiagnosis.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:CauseOfDeath.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.hospitalization.admitSource` | `https://fhir.minsalud.gov.co/rda/ValueSet/ViaIngresoCodigos` |
| `Encounter.hospitalization.dischargeDisposition` | `https://fhir.minsalud.gov.co/rda/ValueSet/CondicionyDestinoUsuarioEgresoCodigos` |

### Invariantes del perfil

| Clave | Severidad | Elemento | Regla | Expresión |
| --- | --- | --- | --- | --- |
| `inv-enc-period-valid-range-enc-emerg` | error | `Encounter.period` | La fecha del encuentro (start y end) no puede ser mayor a la fecha actual | `start.exists() and end.exists() and start <= end and start <= now() and end <= now()` |
| `inv-enc-period-max-1year-enc-emerg` | error | `Encounter.period` | La fecha del encuentro (inicio y fin) no puede ser de hace más de un año. | `start.toDate() >= today() - 1 year and end.toDate() >= today() - 1 year` |
| `inv-period-full-date-enc-emerg` | error | `Encounter.period` | Las fechas del periodo (start y end) deben incluir al menos día, mes y año (formato AAAA-MM-DD); no se acepta una fecha con solo el año (AAAA) o solo año y mes (AAAA-MM). | `(start.exists() implies start.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*')) and (end.exists() implies end.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*'))` |

## EncounterHospitalizationRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/EncounterHospitalizationRDA`
- Tipo: `Encounter`; base: `http://hl7.org/fhir/StructureDefinition/Encounter`
- Descripción: Perfil FHIR del encuentro de hospitalización, para su intercambio en un documento RDA en Colombia.  Información sobre un encuentro de atención en el cual un paciente es admitido formalmente a una institución prestadora de servicios de salud (IPS) para recibir atención médica continua durante un periodo prolongado, que generalmente requiere al menos una noche de estancia, bajo supervisión clínica permanente.  Este tipo de encuentro se utiliza para tratar condiciones de salud que no pueden resolverse adecuadamente en un entorno ambulatorio o de urgencias, y que requieren monitoreo, intervenciones médicas, quirúrgicas, farmacológicas o de rehabilitación dentro de un entorno institucional.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Encounter.meta.profile` | 1..* | canonical(StructureDefinition) | si `Encounter.meta` |
| `Encounter.identifier:EncounterIdentifier.id` | 1..1 | String | si `Encounter.identifier:EncounterIdentifier` |
| `Encounter.identifier:EncounterIdentifier.use` | 1..1 | code | si `Encounter.identifier:EncounterIdentifier` |
| `Encounter.identifier:EncounterIdentifier.system` | 1..1 | uri | si `Encounter.identifier:EncounterIdentifier` |
| `Encounter.identifier:EncounterIdentifier.value` | 1..1 | string | si `Encounter.identifier:EncounterIdentifier` |
| `Encounter.status` | 1..1 | code |  |
| `Encounter.statusHistory.status` | 1..1 | code | si `Encounter.statusHistory` |
| `Encounter.statusHistory.period` | 1..1 | Period | si `Encounter.statusHistory` |
| `Encounter.class` | 1..1 | Coding |  |
| `Encounter.class.code` | 1..1 | code |  |
| `Encounter.class.display` | 1..1 | string |  |
| `Encounter.classHistory.class` | 1..1 | Coding | si `Encounter.classHistory` |
| `Encounter.classHistory.period` | 1..1 | Period | si `Encounter.classHistory` |
| `Encounter.type` | 3..4 | CodeableConcept |  |
| `Encounter.type:encounterModality` | 1..1 | CodeableConcept |  |
| `Encounter.type:encounterModality.coding` | 1..1 | Coding |  |
| `Encounter.type:encounterModality.coding.system` | 1..1 | uri |  |
| `Encounter.type:encounterModality.coding.code` | 1..1 | code |  |
| `Encounter.type:encounterModality.coding.display` | 1..1 | string |  |
| `Encounter.type:encounterServiceGroup` | 1..1 | CodeableConcept |  |
| `Encounter.type:encounterServiceGroup.coding` | 1..1 | Coding |  |
| `Encounter.type:encounterServiceGroup.coding.system` | 1..1 | uri |  |
| `Encounter.type:encounterServiceGroup.coding.code` | 1..1 | code |  |
| `Encounter.type:encounterServiceGroup.coding.display` | 1..1 | string |  |
| `Encounter.type:encounterEnvironment` | 1..1 | CodeableConcept |  |
| `Encounter.type:encounterEnvironment.coding` | 1..1 | Coding |  |
| `Encounter.type:encounterEnvironment.coding.system` | 1..1 | uri |  |
| `Encounter.type:encounterEnvironment.coding.code` | 1..1 | code |  |
| `Encounter.type:encounterEnvironment.coding.display` | 1..1 | string |  |
| `Encounter.type:encounterAmbitosAtencionMipres.coding` | 1..1 | Coding | si `Encounter.type:encounterAmbitosAtencionMipres` |
| `Encounter.type:encounterAmbitosAtencionMipres.coding.system` | 1..1 | uri | si `Encounter.type:encounterAmbitosAtencionMipres` |
| `Encounter.type:encounterAmbitosAtencionMipres.coding.code` | 1..1 | code | si `Encounter.type:encounterAmbitosAtencionMipres` |
| `Encounter.type:encounterAmbitosAtencionMipres.coding.display` | 1..1 | string | si `Encounter.type:encounterAmbitosAtencionMipres` |
| `Encounter.subject` | 1..1 | Reference(PatientRDA) |  |
| `Encounter.participant` | 1..1 | BackboneElement |  |
| `Encounter.participant:DischargePhysician` | 1..1 | BackboneElement |  |
| `Encounter.participant:DischargePhysician.id` | 1..1 | String |  |
| `Encounter.participant:DischargePhysician.type` | 1..1 | CodeableConcept |  |
| `Encounter.participant:DischargePhysician.type.coding` | 1..1 | Coding |  |
| `Encounter.participant:DischargePhysician.type.coding.system` | 1..1 | uri |  |
| `Encounter.participant:DischargePhysician.type.coding.code` | 1..1 | code |  |
| `Encounter.participant:DischargePhysician.type.coding.display` | 1..1 | string |  |
| `Encounter.participant:DischargePhysician.individual` | 1..1 | Reference(PractitionerRDA) |  |
| `Encounter.period` | 1..1 | Period |  |
| `Encounter.period.start` | 1..1 | dateTime |  |
| `Encounter.period.end` | 1..1 | dateTime |  |
| `Encounter.reasonCode` | 1..1 | CodeableConcept |  |
| `Encounter.reasonCode.coding.system` | 1..1 | uri | si `Encounter.reasonCode.coding` |
| `Encounter.reasonCode.coding.code` | 1..1 | code | si `Encounter.reasonCode.coding` |
| `Encounter.reasonCode.coding.display` | 1..1 | string | si `Encounter.reasonCode.coding` |
| `Encounter.diagnosis` | 2..7 | BackboneElement |  |
| `Encounter.diagnosis.condition` | 1..1 | Reference(Condition, Procedure) |  |
| `Encounter.diagnosis:AdmissionDiagnosis` | 1..1 | BackboneElement |  |
| `Encounter.diagnosis:AdmissionDiagnosis.id` | 1..1 | String |  |
| `Encounter.diagnosis:AdmissionDiagnosis.extension` | 1..* | Extension |  |
| `Encounter.diagnosis:AdmissionDiagnosis.extension:ExtensionDiagnosisType` | 1..1 | Extension(ExtensionDiagnosisType) |  |
| `Encounter.diagnosis:AdmissionDiagnosis.condition` | 1..1 | Reference(ConditionRDA) |  |
| `Encounter.diagnosis:AdmissionDiagnosis.use` | 1..1 | CodeableConcept |  |
| `Encounter.diagnosis:AdmissionDiagnosis.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:AdmissionDiagnosis.use.coding` |
| `Encounter.diagnosis:AdmissionDiagnosis.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:AdmissionDiagnosis.use.coding` |
| `Encounter.diagnosis:AdmissionDiagnosis.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:AdmissionDiagnosis.use.coding` |
| `Encounter.diagnosis:AdmissionDiagnosis.rank` | 1..1 | positiveInt |  |
| `Encounter.diagnosis:DischargeDiagnosis` | 1..1 | BackboneElement |  |
| `Encounter.diagnosis:DischargeDiagnosis.id` | 1..1 | String |  |
| `Encounter.diagnosis:DischargeDiagnosis.extension` | 1..* | Extension |  |
| `Encounter.diagnosis:DischargeDiagnosis.extension:ExtensionDiagnosisType` | 1..1 | Extension(ExtensionDiagnosisType) |  |
| `Encounter.diagnosis:DischargeDiagnosis.condition` | 1..1 | Reference(ConditionRDA) |  |
| `Encounter.diagnosis:DischargeDiagnosis.use` | 1..1 | CodeableConcept |  |
| `Encounter.diagnosis:DischargeDiagnosis.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:DischargeDiagnosis.use.coding` |
| `Encounter.diagnosis:DischargeDiagnosis.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:DischargeDiagnosis.use.coding` |
| `Encounter.diagnosis:DischargeDiagnosis.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:DischargeDiagnosis.use.coding` |
| `Encounter.diagnosis:DischargeDiagnosis.rank` | 1..1 | positiveInt |  |
| `Encounter.diagnosis:DischargeComorbidity-1.id` | 1..1 | String | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-1.condition` | 1..1 | Reference(ConditionRDA) | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-1.use` | 1..1 | CodeableConcept | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-1.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-1.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-1.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-1.rank` | 1..1 | positiveInt | si `Encounter.diagnosis:DischargeComorbidity-1` |
| `Encounter.diagnosis:DischargeComorbidity-2.id` | 1..1 | String | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-2.condition` | 1..1 | Reference(ConditionRDA) | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-2.use` | 1..1 | CodeableConcept | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-2.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-2.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-2.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-2.rank` | 1..1 | positiveInt | si `Encounter.diagnosis:DischargeComorbidity-2` |
| `Encounter.diagnosis:DischargeComorbidity-3.id` | 1..1 | String | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:DischargeComorbidity-3.condition` | 1..1 | Reference(ConditionRDA) | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:DischargeComorbidity-3.use` | 1..1 | CodeableConcept | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:DischargeComorbidity-3.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:DischargeComorbidity-3.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:DischargeComorbidity-3.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:DischargeComorbidity-3.rank` | 1..1 | positiveInt | si `Encounter.diagnosis:DischargeComorbidity-3` |
| `Encounter.diagnosis:CauseOfDeath.id` | 1..1 | String | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.diagnosis:CauseOfDeath.condition` | 1..1 | Reference(ConditionRDA) | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.diagnosis:CauseOfDeath.use` | 1..1 | CodeableConcept | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.diagnosis:CauseOfDeath.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.diagnosis:CauseOfDeath.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.diagnosis:CauseOfDeath.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.diagnosis:CauseOfDeath.rank` | 1..1 | positiveInt | si `Encounter.diagnosis:CauseOfDeath` |
| `Encounter.diagnosis:ComplicationDiagnosis.id` | 1..1 | String | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.diagnosis:ComplicationDiagnosis.condition` | 1..1 | Reference(ConditionRDA) | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.diagnosis:ComplicationDiagnosis.use` | 1..1 | CodeableConcept | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.diagnosis:ComplicationDiagnosis.use.coding.system` | 1..1 | uri | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.diagnosis:ComplicationDiagnosis.use.coding.code` | 1..1 | code | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.diagnosis:ComplicationDiagnosis.use.coding.display` | 1..1 | string | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.diagnosis:ComplicationDiagnosis.rank` | 1..1 | positiveInt | si `Encounter.diagnosis:ComplicationDiagnosis` |
| `Encounter.hospitalization.admitSource.coding.system` | 1..1 | uri | si `Encounter.hospitalization` |
| `Encounter.hospitalization.admitSource.coding.code` | 1..1 | code | si `Encounter.hospitalization` |
| `Encounter.hospitalization.admitSource.coding.display` | 1..1 | string | si `Encounter.hospitalization` |
| `Encounter.hospitalization.dischargeDisposition.coding.system` | 1..1 | uri | si `Encounter.hospitalization` |
| `Encounter.hospitalization.dischargeDisposition.coding.code` | 1..1 | code | si `Encounter.hospitalization` |
| `Encounter.hospitalization.dischargeDisposition.coding.display` | 1..1 | string | si `Encounter.hospitalization` |
| `Encounter.location.location` | 1..1 | Reference(CareDeliveryLocationRDA) | si `Encounter.location` |

### Must-support opcionales

`Encounter.diagnosis:DischargeComorbidity-1` 0..1 · `Encounter.diagnosis:DischargeComorbidity-2` 0..1 · `Encounter.diagnosis:DischargeComorbidity-3` 0..1 · `Encounter.diagnosis:CauseOfDeath` 0..1 · `Encounter.diagnosis:ComplicationDiagnosis` 0..1 · `Encounter.hospitalization.extension:ExtensionDischargeDeceasedStatus` 0..1 · `Encounter.hospitalization.admitSource` 0..1 · `Encounter.hospitalization.destination` 0..1 · `Encounter.hospitalization.dischargeDisposition` 0..1 · `Encounter.location` 0..* · `Encounter.serviceProvider` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Encounter.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/EncounterHospitalizationRDA"` |
| `Encounter.identifier:EncounterIdentifier.id` | `fixedString` | `"EncounterIdentifier"` |
| `Encounter.identifier:EncounterIdentifier.use` | `patternCode` | `"usual"` |
| `Encounter.identifier:EncounterIdentifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/Encounters"` |
| `Encounter.status` | `fixedCode` | `"finished"` |
| `Encounter.class.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v3-ActCode"` |
| `Encounter.class.code` | `fixedCode` | `"IMP"` |
| `Encounter.class.display` | `fixedString` | `"inpatient encounter"` |
| `Encounter.type:encounterModality.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianTechModality"` |
| `Encounter.type:encounterServiceGroup.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/GrupoServicios"` |
| `Encounter.type:encounterServiceGroup.coding.code` | `fixedCode` | `"03"` |
| `Encounter.type:encounterServiceGroup.coding.display` | `fixedString` | `"Internación"` |
| `Encounter.type:encounterEnvironment.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/EntornoAtencion"` |
| `Encounter.type:encounterAmbitosAtencionMipres.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/MipresAmbitosAtencion"` |
| `Encounter.participant:DischargePhysician.id` | `patternString` | `"DischargePhysician"` |
| `Encounter.participant:DischargePhysician.type.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v3-ParticipationType"` |
| `Encounter.participant:DischargePhysician.type.coding.code` | `fixedCode` | `"DIS"` |
| `Encounter.participant:DischargePhysician.type.coding.display` | `fixedString` | `"discharger"` |
| `Encounter.reasonCode.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/RIPSCausaExternaVersion2"` |
| `Encounter.diagnosis:AdmissionDiagnosis.id` | `patternString` | `"AdmissionDiagnosis"` |
| `Encounter.diagnosis:AdmissionDiagnosis.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:AdmissionDiagnosis.use.coding.code` | `fixedCode` | `"52870002"` |
| `Encounter.diagnosis:AdmissionDiagnosis.use.coding.display` | `fixedString` | `"diagnóstico de ingreso"` |
| `Encounter.diagnosis:AdmissionDiagnosis.rank` | `fixedPositiveInt` | `1` |
| `Encounter.diagnosis:DischargeDiagnosis.id` | `patternString` | `"DischargeDiagnosis"` |
| `Encounter.diagnosis:DischargeDiagnosis.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:DischargeDiagnosis.use.coding.code` | `fixedCode` | `"89100005"` |
| `Encounter.diagnosis:DischargeDiagnosis.use.coding.display` | `fixedString` | `"diagnóstico final (alta)"` |
| `Encounter.diagnosis:DischargeDiagnosis.rank` | `fixedPositiveInt` | `2` |
| `Encounter.diagnosis:DischargeComorbidity-1.id` | `patternString` | `"DischargeComorbidity-1"` |
| `Encounter.diagnosis:DischargeComorbidity-1.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:DischargeComorbidity-1.use.coding.code` | `fixedCode` | `"398192003"` |
| `Encounter.diagnosis:DischargeComorbidity-1.use.coding.display` | `fixedString` | `"comorbilidades"` |
| `Encounter.diagnosis:DischargeComorbidity-1.rank` | `fixedPositiveInt` | `3` |
| `Encounter.diagnosis:DischargeComorbidity-2.id` | `patternString` | `"DischargeComorbidity-2"` |
| `Encounter.diagnosis:DischargeComorbidity-2.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:DischargeComorbidity-2.use.coding.code` | `fixedCode` | `"398192003"` |
| `Encounter.diagnosis:DischargeComorbidity-2.use.coding.display` | `fixedString` | `"comorbilidades"` |
| `Encounter.diagnosis:DischargeComorbidity-2.rank` | `fixedPositiveInt` | `4` |
| `Encounter.diagnosis:DischargeComorbidity-3.id` | `patternString` | `"DischargeComorbidity-3"` |
| `Encounter.diagnosis:DischargeComorbidity-3.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:DischargeComorbidity-3.use.coding.code` | `fixedCode` | `"398192003"` |
| `Encounter.diagnosis:DischargeComorbidity-3.use.coding.display` | `fixedString` | `"comorbilidades"` |
| `Encounter.diagnosis:DischargeComorbidity-3.rank` | `fixedPositiveInt` | `5` |
| `Encounter.diagnosis:CauseOfDeath.id` | `patternString` | `"CauseOfDeath"` |
| `Encounter.diagnosis:CauseOfDeath.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:CauseOfDeath.use.coding.code` | `fixedCode` | `"16100001"` |
| `Encounter.diagnosis:CauseOfDeath.use.coding.display` | `fixedString` | `"diagnóstico de la causa de muerte"` |
| `Encounter.diagnosis:CauseOfDeath.rank` | `fixedPositiveInt` | `6` |
| `Encounter.diagnosis:ComplicationDiagnosis.id` | `patternString` | `"ComplicationDiagnosis"` |
| `Encounter.diagnosis:ComplicationDiagnosis.use.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole"` |
| `Encounter.diagnosis:ComplicationDiagnosis.use.coding.code` | `fixedCode` | `"263718001"` |
| `Encounter.diagnosis:ComplicationDiagnosis.use.coding.display` | `fixedString` | `"complicación"` |
| `Encounter.diagnosis:ComplicationDiagnosis.rank` | `fixedPositiveInt` | `7` |
| `Encounter.hospitalization.admitSource.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ViaIngreso"` |
| `Encounter.hospitalization.dischargeDisposition.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/CondicionyDestinoUsuarioEgreso"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Encounter.identifier` | value:id ⚑ | closed | `EncounterIdentifier` 0..1 Identifier |
| `Encounter.type` | value:coding.system | closed | `encounterModality` 1..1 CodeableConcept<br>`encounterServiceGroup` 1..1 CodeableConcept<br>`encounterEnvironment` 1..1 CodeableConcept<br>`encounterAmbitosAtencionMipres` 0..1 CodeableConcept |
| `Encounter.participant` | value:type | closed | `DischargePhysician` 1..1 BackboneElement |
| `Encounter.diagnosis` | value:rank | closed | `AdmissionDiagnosis` 1..1 BackboneElement<br>`DischargeDiagnosis` 1..1 BackboneElement<br>`DischargeComorbidity-1` 0..1 BackboneElement<br>`DischargeComorbidity-2` 0..1 BackboneElement<br>`DischargeComorbidity-3` 0..1 BackboneElement<br>`CauseOfDeath` 0..1 BackboneElement<br>`ComplicationDiagnosis` 0..1 BackboneElement |
| `Encounter.diagnosis:AdmissionDiagnosis.extension` | value:url | open | `ExtensionDiagnosisType` 1..1 Extension(ExtensionDiagnosisType) |
| `Encounter.diagnosis:DischargeDiagnosis.extension` | value:url | open | `ExtensionDiagnosisType` 1..1 Extension(ExtensionDiagnosisType) |
| `Encounter.hospitalization.extension` | value:url | open | `ExtensionDischargeDeceasedStatus` 0..1 Extension(ExtensionDischargeDeceasedStatus) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Encounter.type:encounterModality` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianTechModalityCodes` |
| `Encounter.type:encounterServiceGroup` | `https://fhir.minsalud.gov.co/rda/ValueSet/GrupoServiciosCodigos` |
| `Encounter.type:encounterEnvironment` | `https://fhir.minsalud.gov.co/rda/ValueSet/EntornoAtencionCodigos` |
| `Encounter.type:encounterAmbitosAtencionMipres` | `https://fhir.minsalud.gov.co/rda/ValueSet/MipresAmbitosAtencionHospitalario` |
| `Encounter.reasonCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/RIPSCausaExternaVersion2Codigos` |
| `Encounter.diagnosis:AdmissionDiagnosis.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:DischargeDiagnosis.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:DischargeComorbidity-1.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:DischargeComorbidity-2.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:DischargeComorbidity-3.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:CauseOfDeath.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.diagnosis:ComplicationDiagnosis.use` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianDiagnosisRoleCodes` |
| `Encounter.hospitalization.admitSource` | `https://fhir.minsalud.gov.co/rda/ValueSet/ViaIngresoCodigos` |
| `Encounter.hospitalization.dischargeDisposition` | `https://fhir.minsalud.gov.co/rda/ValueSet/CondicionyDestinoUsuarioEgresoCodigos` |

### Invariantes del perfil

| Clave | Severidad | Elemento | Regla | Expresión |
| --- | --- | --- | --- | --- |
| `inv-enc-period-valid-range-enc-hosp` | error | `Encounter.period` | La fecha del encuentro (start y end) no puede ser mayor a la fecha actual | `start.exists() and end.exists() and start <= end and start <= now() and end <= now()` |
| `inv-enc-period-max-1year-enc-hosp` | error | `Encounter.period` | La fecha del encuentro (inicio y fin) no puede ser de hace más de un año. | `start.toDate() >= today() - 1 year and end.toDate() >= today() - 1 year` |
| `inv-period-full-date-enc-hosp` | error | `Encounter.period` | Las fechas del periodo (start y end) deben incluir al menos día, mes y año (formato AAAA-MM-DD); no se acepta una fecha con solo el año (AAAA) o solo año y mes (AAAA-MM). | `(start.exists() implies start.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*')) and (end.exists() implies end.toString().matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}.*'))` |

## FamilyMemberHistoryRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/FamilyMemberHistoryRDA`
- Tipo: `FamilyMemberHistory`; base: `http://hl7.org/fhir/StructureDefinition/FamilyMemberHistory`
- Descripción: Perfil FHIR de un antecedente familiar en salud, para su intercambio en un documento RDA en Colombia.  Registro de información sobre la salud o las condiciones de salud de un familiar del paciente, relevante para la atención en salud, con el fin de apoyar la valoración de riesgos, el análisis de antecedentes y la toma de decisiones clínicas durante el proceso de atención.  El antecedente familiar de salud se documenta con base en la información suministrada por el paciente o sus cuidadores, y puede incluir enfermedades hereditarias, condiciones relevantes en familiares directos y antecedentes que puedan influir en el estado de salud o en la prevención de enfermedades del paciente, de acuerdo con los lineamientos establecidos por la normativa colombiana.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `FamilyMemberHistory.meta.profile` | 1..* | canonical(StructureDefinition) | si `FamilyMemberHistory.meta` |
| `FamilyMemberHistory.status` | 1..1 | code |  |
| `FamilyMemberHistory.patient` | 1..1 | Reference(PatientRDA) |  |
| `FamilyMemberHistory.relationship` | 1..1 | CodeableConcept |  |
| `FamilyMemberHistory.relationship.coding.code` | 1..1 | code | si `FamilyMemberHistory.relationship.coding` |
| `FamilyMemberHistory.relationship.coding.display` | 1..1 | string | si `FamilyMemberHistory.relationship.coding` |
| `FamilyMemberHistory.condition.code` | 1..1 | CodeableConcept | si `FamilyMemberHistory.condition` |
| `FamilyMemberHistory.condition.code.coding:ICD10.system` | 1..1 | uri | si `FamilyMemberHistory.condition` |
| `FamilyMemberHistory.condition.code.coding:ICD10.code` | 1..1 | code | si `FamilyMemberHistory.condition` |
| `FamilyMemberHistory.condition.code.coding:ICD10.display` | 1..1 | string | si `FamilyMemberHistory.condition` |
| `FamilyMemberHistory.condition.code.coding:ICD11.system` | 1..1 | uri | si `FamilyMemberHistory.condition` |
| `FamilyMemberHistory.condition.code.coding:ICD11.code` | 1..1 | code | si `FamilyMemberHistory.condition` |
| `FamilyMemberHistory.condition.code.coding:ICD11.display` | 1..1 | string | si `FamilyMemberHistory.condition` |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `FamilyMemberHistory.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/FamilyMemberHistoryRDA"` |
| `FamilyMemberHistory.relationship.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ParentescoAntecedente"` |
| `FamilyMemberHistory.condition.code.coding:ICD10.system` | `fixedUri` | `"http://hl7.org/fhir/sid/icd-10"` |
| `FamilyMemberHistory.condition.code.coding:ICD11.system` | `fixedUri` | `"http://hl7.org/fhir/sid/icd-11"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `FamilyMemberHistory.condition.code.coding` | value:system | closed | `ICD10` 0..1 Coding<br>`ICD11` 0..* Coding |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `FamilyMemberHistory.relationship` | `https://fhir.minsalud.gov.co/rda/ValueSet/ParentescoAntecedenteCodigos` |
| `FamilyMemberHistory.condition.code.coding:ICD10` | `https://fhir.minsalud.gov.co/rda/ValueSet/ICD10Codes` |
| `FamilyMemberHistory.condition.code.coding:ICD11` | `https://fhir.minsalud.gov.co/rda/ValueSet/ICD11Codes` |

## HealthBenefitPlanAdminOrganizationRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/HealthBenefitPlanAdminOrganizationRDA`
- Tipo: `Organization`; base: `http://hl7.org/fhir/StructureDefinition/Organization`
- Descripción: Perfil FHIR de la Entidad Administradora de Planes de Beneficios en Salud (EAPB), para su intercambio en un documento RDA en Colombia.  Información sobre una Entidad Administradora de Planes de Beneficios en Salud (EAPB). Es una entidad jurídica, pública o privada, autorizada y habilitada por la Superintendencia Nacional de Salud para afiliar y administrar los recursos de la Unidad de Pago por Capitación (UPC) y demás recursos destinados a la prestación de servicios de salud, garantizando a sus afiliados el acceso oportuno, integral y continuo a los servicios y tecnologías incluidas en el Plan de Beneficios en Salud, de acuerdo con las normas vigentes del Sistema General de Seguridad Social en Salud (SGSSS) de Colombia. Las EAPB son responsables de la gestión del riesgo en salud y financiero de su población afiliada, así como del aseguramiento de la calidad en la prestación de servicios, buscando la sostenibilidad del sistema y el bienestar de los usuarios.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Organization.meta.profile` | 1..* | canonical(StructureDefinition) | si `Organization.meta` |
| `Organization.identifier` | 1..1 | Identifier |  |
| `Organization.identifier:EAPBIdentifier` | 1..1 | Identifier |  |
| `Organization.identifier:EAPBIdentifier.use` | 1..1 | code |  |
| `Organization.identifier:EAPBIdentifier.type` | 1..1 | CodeableConcept |  |
| `Organization.identifier:EAPBIdentifier.type.coding` | 2..2 | Coding |  |
| `Organization.identifier:EAPBIdentifier.type.coding:InternationalCode` | 1..1 | Coding |  |
| `Organization.identifier:EAPBIdentifier.type.coding:InternationalCode.system` | 1..1 | uri |  |
| `Organization.identifier:EAPBIdentifier.type.coding:InternationalCode.code` | 1..1 | code |  |
| `Organization.identifier:EAPBIdentifier.type.coding:InternationalCode.display` | 1..1 | string |  |
| `Organization.identifier:EAPBIdentifier.type.coding:ColombianCode` | 1..1 | Coding |  |
| `Organization.identifier:EAPBIdentifier.type.coding:ColombianCode.system` | 1..1 | uri |  |
| `Organization.identifier:EAPBIdentifier.type.coding:ColombianCode.code` | 1..1 | code |  |
| `Organization.identifier:EAPBIdentifier.type.coding:ColombianCode.display` | 1..1 | string |  |
| `Organization.identifier:EAPBIdentifier.system` | 1..1 | uri |  |
| `Organization.identifier:EAPBIdentifier.value` | 1..1 | string |  |
| `Organization.active` | 1..1 | boolean |  |
| `Organization.name` | 1..1 | string |  |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Organization.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/HealthBenefitPlanAdminOrganizationRDA"` |
| `Organization.identifier:EAPBIdentifier.use` | `fixedCode` | `"official"` |
| `Organization.identifier:EAPBIdentifier.type.coding:InternationalCode.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v2-0203"` |
| `Organization.identifier:EAPBIdentifier.type.coding:InternationalCode.code` | `fixedCode` | `"NIIP"` |
| `Organization.identifier:EAPBIdentifier.type.coding:InternationalCode.display` | `fixedString` | `"National Insurance Payor Identifier"` |
| `Organization.identifier:EAPBIdentifier.type.coding:ColombianCode.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianOrganizationIdentifiers"` |
| `Organization.identifier:EAPBIdentifier.type.coding:ColombianCode.code` | `fixedCode` | `"EAPB"` |
| `Organization.identifier:EAPBIdentifier.type.coding:ColombianCode.display` | `fixedString` | `"Entidad Administradora de Planes de Beneficios"` |
| `Organization.identifier:EAPBIdentifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/EAPB"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Organization.identifier` | value:system | open | `EAPBIdentifier` 1..1 Identifier |
| `Organization.identifier:EAPBIdentifier.type.coding` | value:system | open | `InternationalCode` 1..1 Coding<br>`ColombianCode` 1..1 Coding |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Organization.identifier:EAPBIdentifier.type.coding:ColombianCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianOrganizationIdentifierCodes` |

## HealthTechProviderOrganization

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/HealthTechProviderOrganization`
- Tipo: `Organization`; base: `http://hl7.org/fhir/StructureDefinition/Organization`
- Descripción: Perfil FHIR de un Proveedor de Tecnologías en Salud PTS, para intercambio de información en Colombia. Información sobre un Proveedor de Tecnologías en Salud (PTS). Persona natural o jurídica que realice la disposición, almacenamiento, venta o entrega de tecnologías en salud.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Organization.meta.profile` | 1..* | canonical(StructureDefinition) | si `Organization.meta` |
| `Organization.identifier` | 1..1 | Identifier |  |
| `Organization.identifier:TaxIdentifier` | 1..1 | Identifier |  |
| `Organization.identifier:TaxIdentifier.id` | 1..1 | String |  |
| `Organization.identifier:TaxIdentifier.use` | 1..1 | code |  |
| `Organization.identifier:TaxIdentifier.type` | 1..1 | CodeableConcept |  |
| `Organization.identifier:TaxIdentifier.type.coding` | 2..2 | Coding |  |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode` | 1..1 | Coding |  |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode.system` | 1..1 | uri |  |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode.code` | 1..1 | code |  |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode.display` | 1..1 | string |  |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode` | 1..1 | Coding |  |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode.system` | 1..1 | uri |  |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode.code` | 1..1 | code |  |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode.display` | 1..1 | string |  |
| `Organization.identifier:TaxIdentifier.value` | 1..1 | string |  |
| `Organization.identifier:TaxIdentifier.period.start` | 1..1 | dateTime | si `Organization.identifier:TaxIdentifier.period` |
| `Organization.active` | 1..1 | boolean |  |
| `Organization.type` | 1..1 | CodeableConcept |  |
| `Organization.type:LegalNatureType.coding` | 1..1 | Coding | si `Organization.type:LegalNatureType` |
| `Organization.type:LegalNatureType.coding.system` | 1..1 | uri | si `Organization.type:LegalNatureType` |
| `Organization.type:LegalNatureType.coding.code` | 1..1 | code | si `Organization.type:LegalNatureType` |
| `Organization.type:LegalNatureType.coding.display` | 1..1 | string | si `Organization.type:LegalNatureType` |
| `Organization.name` | 1..1 | string |  |
| `Organization.telecom:TelecomPhone.id` | 1..1 | String | si `Organization.telecom:TelecomPhone` |
| `Organization.telecom:TelecomPhone.system` | 1..1 | code | si `Organization.telecom:TelecomPhone` |
| `Organization.telecom:TelecomPhone.value` | 1..1 | string | si `Organization.telecom:TelecomPhone` |
| `Organization.telecom:TelecomMobile.id` | 1..1 | String | si `Organization.telecom:TelecomMobile` |
| `Organization.telecom:TelecomMobile.system` | 1..1 | code | si `Organization.telecom:TelecomMobile` |
| `Organization.telecom:TelecomMobile.value` | 1..1 | string | si `Organization.telecom:TelecomMobile` |
| `Organization.telecom:TelecomMobile.use` | 1..1 | code | si `Organization.telecom:TelecomMobile` |
| `Organization.telecom:TelecomEmail.id` | 1..1 | String | si `Organization.telecom:TelecomEmail` |
| `Organization.telecom:TelecomEmail.system` | 1..1 | code | si `Organization.telecom:TelecomEmail` |
| `Organization.telecom:TelecomEmail.value` | 1..1 | string | si `Organization.telecom:TelecomEmail` |
| `Organization.telecom:TelecomURL.id` | 1..1 | String | si `Organization.telecom:TelecomURL` |
| `Organization.telecom:TelecomURL.system` | 1..1 | code | si `Organization.telecom:TelecomURL` |
| `Organization.telecom:TelecomURL.value` | 1..1 | string | si `Organization.telecom:TelecomURL` |
| `Organization.address` | 1..* | Address |  |
| `Organization.address.use` | 1..1 | code |  |
| `Organization.address.type` | 1..1 | code |  |
| `Organization.address.text` | 1..1 | string |  |
| `Organization.address.city` | 1..1 | string |  |
| `Organization.address.state` | 1..1 | string |  |
| `Organization.address.country` | 1..1 | string |  |

### Must-support opcionales

`Organization.type:LegalNatureType` 0..1 · `Organization.address.city.extension:ExtensionDivipolaMunicipality` 0..1 · `Organization.address.state.extension:ExtensionDivipolaDepartment` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Organization.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/HealthTechProviderOrganization"` |
| `Organization.identifier:TaxIdentifier.id` | `patternString` | `"TaxIdentifier-0"` |
| `Organization.identifier:TaxIdentifier.use` | `fixedCode` | `"official"` |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v2-0203"` |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode.code` | `fixedCode` | `"TAX"` |
| `Organization.identifier:TaxIdentifier.type.coding:InternationalCode.display` | `fixedString` | `"Tax ID number"` |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianOrganizationIdentifiers"` |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode.code` | `fixedCode` | `"NIT"` |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode.display` | `fixedString` | `"Número de Identificación Tributaria"` |
| `Organization.identifier:TaxIdentifier.system` | `patternUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/DIAN"` |
| `Organization.identifier:TaxIdentifier.assigner.display` | `fixedString` | `"DIAN"` |
| `Organization.type:LegalNatureType.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianLegalNatureType"` |
| `Organization.telecom:TelecomPhone.id` | `patternString` | `"TelecomPhone-0"` |
| `Organization.telecom:TelecomPhone.system` | `fixedCode` | `"phone"` |
| `Organization.telecom:TelecomMobile.id` | `patternString` | `"TelecomMobile-0"` |
| `Organization.telecom:TelecomMobile.system` | `fixedCode` | `"phone"` |
| `Organization.telecom:TelecomMobile.use` | `fixedCode` | `"mobile"` |
| `Organization.telecom:TelecomEmail.id` | `patternString` | `"TelecomEmail-0"` |
| `Organization.telecom:TelecomEmail.system` | `fixedCode` | `"email"` |
| `Organization.telecom:TelecomURL.id` | `patternString` | `"TelecomURL-0"` |
| `Organization.telecom:TelecomURL.system` | `fixedCode` | `"url"` |
| `Organization.address.use` | `fixedCode` | `"work"` |
| `Organization.address.type` | `fixedCode` | `"physical"` |
| `Organization.address.country` | `fixedString` | `"CO"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Organization.identifier` | value:id ⚑ | closed | `TaxIdentifier` 1..1 Identifier |
| `Organization.identifier:TaxIdentifier.type.coding` | value:system | closed | `InternationalCode` 1..1 Coding<br>`ColombianCode` 1..1 Coding |
| `Organization.type` | value:coding.system | closed | `LegalNatureType` 0..1 CodeableConcept |
| `Organization.telecom` | value:id ⚑ | closed | `TelecomPhone` 0..* ContactPoint<br>`TelecomMobile` 0..* ContactPoint<br>`TelecomEmail` 0..* ContactPoint<br>`TelecomURL` 0..* ContactPoint |
| `Organization.address.city.extension` | value:url | open | `ExtensionDivipolaMunicipality` 0..1 Extension(ExtensionDivipolaMunicipality) |
| `Organization.address.state.extension` | value:url | open | `ExtensionDivipolaDepartment` 0..1 Extension(ExtensionDivipolaDepartment) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Organization.identifier:TaxIdentifier.type.coding:ColombianCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianOrganizationIdentifierCodes` |
| `Organization.type:LegalNatureType` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianLegalNatureTypeCodes` |

## ImmunizationRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/ImmunizationRDA`
- Tipo: `Immunization`; base: `http://hl7.org/fhir/StructureDefinition/Immunization`
- Descripción: Perfil FHIR de inmunización o vacunación, para su intercambio en un documento RDA en Colombia.  Describe el caso de un paciente quién se le ha administrado una vacuna o un registro de inmunización según lo registrado en el sistema de información del Programa Ampliado de Inmunizaciones ([PAI](https://paiweb2.paiweb.gov.co)).  El perfil de inmunización RDA está diseñado para facilitar la consulta de los registros históricos de vacunas de pacientes en todos los ámbitos de atención y en todas las regiones.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Immunization.meta.profile` | 1..* | canonical(StructureDefinition) | si `Immunization.meta` |
| `Immunization.status` | 1..1 | code |  |
| `Immunization.vaccineCode` | 1..1 | CodeableConcept |  |
| `Immunization.vaccineCode.text` | 1..1 | string |  |
| `Immunization.patient` | 1..1 | Reference(PatientRDA) |  |
| `Immunization.occurrence[x]` | 1..1 | dateTime |  |
| `Immunization.manufacturer` | 1..1 | Reference(Organization) |  |
| `Immunization.manufacturer.display` | 1..1 | string |  |
| `Immunization.lotNumber` | 1..1 | string |  |
| `Immunization.performer` | 2..2 | BackboneElement |  |
| `Immunization.performer.actor` | 1..1 | Reference(Practitioner, PractitionerRole, Organization) |  |
| `Immunization.performer:organization` | 1..1 | BackboneElement |  |
| `Immunization.performer:organization.actor` | 1..1 | Reference(Practitioner, PractitionerRole, Organization) |  |
| `Immunization.performer:organization.actor.type` | 1..1 | uri |  |
| `Immunization.performer:organization.actor.display` | 1..1 | string |  |
| `Immunization.performer:practitioner` | 1..1 | BackboneElement |  |
| `Immunization.performer:practitioner.actor` | 1..1 | Reference(Practitioner, PractitionerRole, Organization) |  |
| `Immunization.performer:practitioner.actor.type` | 1..1 | uri |  |
| `Immunization.performer:practitioner.actor.display` | 1..1 | string |  |
| `Immunization.protocolApplied` | 1..1 | BackboneElement |  |
| `Immunization.protocolApplied.doseNumber[x]` | 1..1 | string |  |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Immunization.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/ImmunizationRDA"` |
| `Immunization.status` | `fixedCode` | `"completed"` |
| `Immunization.performer:organization.actor.type` | `fixedUri` | `"Organization"` |
| `Immunization.performer:practitioner.actor.type` | `fixedUri` | `"Practitioner"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Immunization.performer` | value:actor.type | closed | `organization` 1..1 BackboneElement<br>`practitioner` 1..1 BackboneElement |

## MedicationAdminRequestRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/MedicationAdminRequestRDA`
- Tipo: `MedicationRequest`; base: `http://hl7.org/fhir/StructureDefinition/MedicationRequest`
- Descripción: Perfil FHIR de la solicitud o prescripción de un medicamento administrado durante un encuentro de atención en salud, para su intercambio en un documento RDA en Colombia.  Orden o solicitud generada por un profesional de la salud autorizado para la administración de un medicamento a un paciente, en el marco de un proceso de atención en salud.  La prescripción de medicamentos es el resultado de un proceso clínico mediante el cual un profesional de la salud, autorizado y habilitado, determina la necesidad de un medicamento para un paciente con base en la evaluación de signos, síntomas, diagnóstico, antecedentes y criterios definidos por la ciencia médica, con el objetivo de tratar, controlar o prevenir condiciones de salud, garantizando el uso seguro, eficaz y racional de medicamentos.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `MedicationRequest.meta.profile` | 1..* | canonical(StructureDefinition) | si `MedicationRequest.meta` |
| `MedicationRequest.status` | 1..1 | code |  |
| `MedicationRequest.intent` | 1..1 | code |  |
| `MedicationRequest.category` | 1..1 | CodeableConcept |  |
| `MedicationRequest.category.coding:R866.system` | 1..1 | uri | si `MedicationRequest.category.coding:R866` |
| `MedicationRequest.category.coding:R866.code` | 1..1 | code | si `MedicationRequest.category.coding:R866` |
| `MedicationRequest.category.coding:R866.display` | 1..1 | string | si `MedicationRequest.category.coding:R866` |
| `MedicationRequest.reported[x]` | 1..1 | boolean |  |
| `MedicationRequest.medication[x]` | 1..1 | CodeableConcept |  |
| `MedicationRequest.medication[x].coding` | 1..3 | Coding |  |
| `MedicationRequest.medication[x].coding:IUM.system` | 1..1 | uri | si `MedicationRequest.medication[x].coding:IUM` |
| `MedicationRequest.medication[x].coding:IUM.code` | 1..1 | code | si `MedicationRequest.medication[x].coding:IUM` |
| `MedicationRequest.medication[x].coding:CUMS.system` | 1..1 | uri | si `MedicationRequest.medication[x].coding:CUMS` |
| `MedicationRequest.medication[x].coding:CUMS.code` | 1..1 | code | si `MedicationRequest.medication[x].coding:CUMS` |
| `MedicationRequest.subject` | 1..1 | Reference(PatientRDA) |  |
| `MedicationRequest.authoredOn` | 1..1 | dateTime |  |
| `MedicationRequest.reasonCode` | 1..1 | CodeableConcept |  |
| `MedicationRequest.reasonCode.coding.system` | 1..1 | uri | si `MedicationRequest.reasonCode.coding` |
| `MedicationRequest.reasonCode.coding.code` | 1..1 | code | si `MedicationRequest.reasonCode.coding` |
| `MedicationRequest.reasonCode.coding.display` | 1..1 | string | si `MedicationRequest.reasonCode.coding` |
| `MedicationRequest.dosageInstruction` | 1..1 | Dosage |  |
| `MedicationRequest.dosageInstruction.timing` | 1..1 | Timing |  |
| `MedicationRequest.dosageInstruction.timing.repeat` | 1..1 | Element |  |
| `MedicationRequest.dosageInstruction.timing.repeat.duration` | 1..1 | decimal |  |
| `MedicationRequest.dosageInstruction.timing.repeat.durationUnit` | 1..1 | code |  |
| `MedicationRequest.dosageInstruction.timing.code` | 1..1 | CodeableConcept |  |
| `MedicationRequest.dosageInstruction.timing.code.coding.system` | 1..1 | uri | si `MedicationRequest.dosageInstruction.timing.code.coding` |
| `MedicationRequest.dosageInstruction.timing.code.coding.code` | 1..1 | code | si `MedicationRequest.dosageInstruction.timing.code.coding` |
| `MedicationRequest.dosageInstruction.timing.code.coding.display` | 1..1 | string | si `MedicationRequest.dosageInstruction.timing.code.coding` |

### Must-support opcionales

`MedicationRequest.medication[x].coding:IUM.display` 0..1 · `MedicationRequest.medication[x].text` 0..1 · `MedicationRequest.encounter` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `MedicationRequest.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/MedicationAdminRequestRDA"` |
| `MedicationRequest.status` | `fixedCode` | `"completed"` |
| `MedicationRequest.intent` | `fixedCode` | `"order"` |
| `MedicationRequest.category.coding:R866.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianHealthTechnologyCategory"` |
| `MedicationRequest.medication[x].coding:IUM.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/IUM"` |
| `MedicationRequest.medication[x].coding:CUMS.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/CUMS"` |
| `MedicationRequest.reasonCode.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/RIPSFinalidadConsultaVersion2"` |
| `MedicationRequest.dosageInstruction.timing.code.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/MedicationTime"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `MedicationRequest.category.coding` | value:system | closed | `R866` 0..1 Coding |
| `MedicationRequest.medication[x].coding` | value:system | closed | `IUM` 0..1 Coding<br>`CUMS` 0..1 Coding |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `MedicationRequest.category.coding:R866` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianHealthTechnologyMedicationCodes` |
| `MedicationRequest.medication[x].coding:IUM` | `https://fhir.minsalud.gov.co/rda/ValueSet/IUMCodes` |
| `MedicationRequest.medication[x].coding:CUMS` | `https://fhir.minsalud.gov.co/rda/ValueSet/CUMSVS` |
| `MedicationRequest.reasonCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/RIPSFinalidadConsultaVersion2Codigos` |
| `MedicationRequest.dosageInstruction.timing.code.coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/MedicationTimeCodes` |

## MedicationAdministrationRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/MedicationAdministrationRDA`
- Tipo: `MedicationAdministration`; base: `http://hl7.org/fhir/StructureDefinition/MedicationAdministration`
- Descripción: Perfil FHIR de la administración de un medicamento, para su intercambio en un documento RDA en Colombia.  Registro de la administración de un medicamento a un paciente como parte de un proceso de atención en salud, incluyendo medicamentos prescritos, dispensados y efectivamente administrados durante la atención.  La administración de medicamentos es el resultado de un proceso clínico mediante el cual un profesional de la salud, autorizado y habilitado, suministra un medicamento a un paciente, con base en una prescripción válida y en las buenas prácticas de administración de medicamentos, con el objetivo de tratar, controlar o prevenir condiciones de salud, bajo criterios de seguridad, oportunidad y eficacia.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `MedicationAdministration.meta.profile` | 1..* | canonical(StructureDefinition) | si `MedicationAdministration.meta` |
| `MedicationAdministration.status` | 1..1 | code |  |
| `MedicationAdministration.category` | 1..1 | CodeableConcept |  |
| `MedicationAdministration.category.coding:R866.system` | 1..1 | uri | si `MedicationAdministration.category.coding:R866` |
| `MedicationAdministration.category.coding:R866.code` | 1..1 | code | si `MedicationAdministration.category.coding:R866` |
| `MedicationAdministration.category.coding:R866.display` | 1..1 | string | si `MedicationAdministration.category.coding:R866` |
| `MedicationAdministration.medication[x]` | 1..1 | CodeableConcept |  |
| `MedicationAdministration.medication[x].coding` | 1..3 | Coding |  |
| `MedicationAdministration.medication[x].coding:IUM.system` | 1..1 | uri | si `MedicationAdministration.medication[x].coding:IUM` |
| `MedicationAdministration.medication[x].coding:IUM.code` | 1..1 | code | si `MedicationAdministration.medication[x].coding:IUM` |
| `MedicationAdministration.medication[x].coding:CUMS.system` | 1..1 | uri | si `MedicationAdministration.medication[x].coding:CUMS` |
| `MedicationAdministration.medication[x].coding:CUMS.code` | 1..1 | code | si `MedicationAdministration.medication[x].coding:CUMS` |
| `MedicationAdministration.subject` | 1..1 | Reference(PatientRDA) |  |
| `MedicationAdministration.supportingInformation:CareDeliveryOrganization.id` | 1..1 | String | si `MedicationAdministration.supportingInformation:CareDeliveryOrganization` |
| `MedicationAdministration.supportingInformation:CareDeliveryOrganization.reference` | 1..1 | string | si `MedicationAdministration.supportingInformation:CareDeliveryOrganization` |
| `MedicationAdministration.effective[x]` | 1..1 | dateTime |  |
| `MedicationAdministration.performer.actor` | 1..1 | Reference(PractitionerRDA) | si `MedicationAdministration.performer` |
| `MedicationAdministration.request` | 1..1 | Reference(MedicationAdminRequestRDA) |  |
| `MedicationAdministration.dosage` | 1..1 | BackboneElement |  |
| `MedicationAdministration.dosage.route` | 1..1 | CodeableConcept |  |
| `MedicationAdministration.dosage.route.coding.system` | 1..1 | uri | si `MedicationAdministration.dosage.route.coding` |
| `MedicationAdministration.dosage.route.coding.code` | 1..1 | code | si `MedicationAdministration.dosage.route.coding` |
| `MedicationAdministration.dosage.route.coding.display` | 1..1 | string | si `MedicationAdministration.dosage.route.coding` |
| `MedicationAdministration.dosage.dose` | 1..1 | Quantity(SimpleQuantity) |  |
| `MedicationAdministration.dosage.dose.value` | 1..1 | decimal |  |
| `MedicationAdministration.dosage.dose.unit` | 1..1 | string |  |
| `MedicationAdministration.dosage.dose.system` | 1..1 | uri |  |
| `MedicationAdministration.dosage.dose.code` | 1..1 | code |  |
| `MedicationAdministration.dosage.rate[x]` | 1..1 | Quantity(SimpleQuantity) |  |
| `MedicationAdministration.dosage.rate[x].value` | 1..1 | decimal |  |
| `MedicationAdministration.dosage.rate[x].system` | 1..1 | uri |  |
| `MedicationAdministration.dosage.rate[x].code` | 1..1 | code |  |

### Must-support opcionales

`MedicationAdministration.medication[x].coding:IUM.display` 0..1 · `MedicationAdministration.medication[x].text` 0..1 · `MedicationAdministration.context` 0..1 · `MedicationAdministration.supportingInformation:CareDeliveryOrganization` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `MedicationAdministration.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/MedicationAdministrationRDA"` |
| `MedicationAdministration.status` | `fixedCode` | `"completed"` |
| `MedicationAdministration.category.coding:R866.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianHealthTechnologyCategory"` |
| `MedicationAdministration.medication[x].coding:IUM.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/IUM"` |
| `MedicationAdministration.medication[x].coding:CUMS.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/CUMS"` |
| `MedicationAdministration.supportingInformation:CareDeliveryOrganization.id` | `fixedString` | `"CareDeliveryOrganization"` |
| `MedicationAdministration.dosage.route.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/VAD"` |
| `MedicationAdministration.dosage.dose.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/UMM"` |
| `MedicationAdministration.dosage.rate[x].system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/MedicationTime"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `MedicationAdministration.extension` | value:url | open | `ExtensionMedicationQuantity` 0..1 Extension(ExtensionMedicationQuantity)<br>`ExtensionDoseQuantity` 0..1 Extension(ExtensionDoseQuantity) |
| `MedicationAdministration.category.coding` | value:system | closed | `R866` 0..1 Coding |
| `MedicationAdministration.medication[x].coding` | value:system | closed | `IUM` 0..1 Coding<br>`CUMS` 0..1 Coding |
| `MedicationAdministration.supportingInformation` | value:id ⚑ | closed | `CareDeliveryOrganization` 0..1 Reference(CareDeliveryOrganizationRDA) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `MedicationAdministration.category.coding:R866` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianHealthTechnologyMedicationCodes` |
| `MedicationAdministration.medication[x].coding:IUM` | `https://fhir.minsalud.gov.co/rda/ValueSet/IUMCodes` |
| `MedicationAdministration.medication[x].coding:CUMS` | `https://fhir.minsalud.gov.co/rda/ValueSet/CUMSVS` |
| `MedicationAdministration.dosage.route.coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/VADCodigos` |
| `MedicationAdministration.dosage.dose` | `https://fhir.minsalud.gov.co/rda/ValueSet/UMMCodigos` |
| `MedicationAdministration.dosage.rate[x]` | `https://fhir.minsalud.gov.co/rda/ValueSet/MedicationTimeCodes` |

## MedicationRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/MedicationRDA`
- Tipo: `Medication`; base: `http://hl7.org/fhir/StructureDefinition/Medication`
- Descripción: Perfil FHIR RDA de un medicamento en Colombia.  Este recurso es usado principalmente para la identificación y definición de un medicamento con el propósito de ser utilizado en la prescripción, dispensación y administración de medicamentos

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Medication.meta.profile` | 1..* | canonical(StructureDefinition) | si `Medication.meta` |
| `Medication.code.coding` | 1..3 | Coding | si `Medication.code` |
| `Medication.code.coding:CUMS.system` | 1..1 | uri | si `Medication.code` |
| `Medication.code.coding:CUMS.code` | 1..1 | code | si `Medication.code` |
| `Medication.code.coding:DCI.system` | 1..1 | uri | si `Medication.code` |
| `Medication.code.coding:DCI.code` | 1..1 | code | si `Medication.code` |
| `Medication.code.coding:IUM.system` | 1..1 | uri | si `Medication.code` |
| `Medication.code.coding:IUM.code` | 1..1 | code | si `Medication.code` |
| `Medication.ingredient.item[x]` | 1..1 | CodeableConcept | Reference(Substance, Medication) | si `Medication.ingredient` |

### Must-support opcionales

`Medication.code.coding:IUM.display` 0..1 · `Medication.status` 0..1 · `Medication.manufacturer` 0..1 · `Medication.form` 0..1 · `Medication.amount` 0..1 · `Medication.ingredient` 0..*

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Medication.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/MedicationRDA"` |
| `Medication.code.coding:CUMS.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/CUMS"` |
| `Medication.code.coding:DCI.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/MipresINN"` |
| `Medication.code.coding:IUM.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/IUM"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Medication.code.coding` | value:system | closed | `CUMS` 0..1 Coding<br>`DCI` 0..1 Coding<br>`IUM` 0..1 Coding |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Medication.code.coding:CUMS` | `https://fhir.minsalud.gov.co/rda/ValueSet/CUMSVS` |
| `Medication.code.coding:DCI` | `https://fhir.minsalud.gov.co/rda/ValueSet/MipresDCI` |
| `Medication.code.coding:IUM` | `https://fhir.minsalud.gov.co/rda/ValueSet/IUMCodes` |

## MedicationRequestRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/MedicationRequestRDA`
- Tipo: `MedicationRequest`; base: `http://hl7.org/fhir/StructureDefinition/MedicationRequest`
- Descripción: Perfil FHIR de la solicitud o prescripción de un medicamento, para su intercambio en un documento RDA en Colombia.  Orden o solicitud generada por un profesional de la salud autorizado para la dispensación y administración de un medicamento a un paciente, en el marco de un proceso de atención en salud.  La prescripción de medicamentos es el resultado de un proceso clínico mediante el cual un profesional de la salud, autorizado y habilitado, determina la necesidad de un medicamento para un paciente con base en la evaluación de signos, síntomas, diagnóstico, antecedentes y criterios definidos por la ciencia médica, con el objetivo de tratar, controlar o prevenir condiciones de salud, garantizando el uso seguro, eficaz y racional de medicamentos.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `MedicationRequest.meta.profile` | 1..* | canonical(StructureDefinition) | si `MedicationRequest.meta` |
| `MedicationRequest.identifier:PrescriptionNumber.id` | 1..1 | String | si `MedicationRequest.identifier:PrescriptionNumber` |
| `MedicationRequest.identifier:PrescriptionNumber.system` | 1..1 | uri | si `MedicationRequest.identifier:PrescriptionNumber` |
| `MedicationRequest.identifier:PrescriptionNumber.value` | 1..1 | string | si `MedicationRequest.identifier:PrescriptionNumber` |
| `MedicationRequest.identifier:MipresID.id` | 1..1 | String | si `MedicationRequest.identifier:MipresID` |
| `MedicationRequest.identifier:MipresID.system` | 1..1 | uri | si `MedicationRequest.identifier:MipresID` |
| `MedicationRequest.identifier:MipresID.value` | 1..1 | string | si `MedicationRequest.identifier:MipresID` |
| `MedicationRequest.status` | 1..1 | code |  |
| `MedicationRequest.intent` | 1..1 | code |  |
| `MedicationRequest.category` | 1..1 | CodeableConcept |  |
| `MedicationRequest.category.coding:R866.system` | 1..1 | uri | si `MedicationRequest.category.coding:R866` |
| `MedicationRequest.category.coding:R866.code` | 1..1 | code | si `MedicationRequest.category.coding:R866` |
| `MedicationRequest.category.coding:R866.display` | 1..1 | string | si `MedicationRequest.category.coding:R866` |
| `MedicationRequest.reported[x]` | 1..1 | boolean |  |
| `MedicationRequest.medication[x]` | 1..1 | CodeableConcept |  |
| `MedicationRequest.medication[x].coding` | 1..* | Coding |  |
| `MedicationRequest.medication[x].coding:DCI.system` | 1..1 | uri | si `MedicationRequest.medication[x].coding:DCI` |
| `MedicationRequest.medication[x].coding:DCI.code` | 1..1 | code | si `MedicationRequest.medication[x].coding:DCI` |
| `MedicationRequest.medication[x].coding:IUMPrimerNivel.system` | 1..1 | uri | si `MedicationRequest.medication[x].coding:IUMPrimerNivel` |
| `MedicationRequest.medication[x].coding:IUMPrimerNivel.code` | 1..1 | code | si `MedicationRequest.medication[x].coding:IUMPrimerNivel` |
| `MedicationRequest.subject` | 1..1 | Reference(PatientRDA) |  |
| `MedicationRequest.authoredOn` | 1..1 | dateTime |  |
| `MedicationRequest.reasonCode` | 1..1 | CodeableConcept |  |
| `MedicationRequest.reasonCode.coding.system` | 1..1 | uri | si `MedicationRequest.reasonCode.coding` |
| `MedicationRequest.reasonCode.coding.code` | 1..1 | code | si `MedicationRequest.reasonCode.coding` |
| `MedicationRequest.reasonCode.coding.display` | 1..1 | string | si `MedicationRequest.reasonCode.coding` |
| `MedicationRequest.groupIdentifier.system` | 1..1 | uri | si `MedicationRequest.groupIdentifier` |
| `MedicationRequest.groupIdentifier.value` | 1..1 | string | si `MedicationRequest.groupIdentifier` |
| `MedicationRequest.dosageInstruction` | 1..1 | Dosage |  |
| `MedicationRequest.dosageInstruction.additionalInstruction.coding.system` | 1..1 | uri | si `MedicationRequest.dosageInstruction.additionalInstruction` |
| `MedicationRequest.dosageInstruction.additionalInstruction.coding.code` | 1..1 | code | si `MedicationRequest.dosageInstruction.additionalInstruction` |
| `MedicationRequest.dosageInstruction.additionalInstruction.coding.display` | 1..1 | string | si `MedicationRequest.dosageInstruction.additionalInstruction` |
| `MedicationRequest.dosageInstruction.timing` | 1..1 | Timing |  |
| `MedicationRequest.dosageInstruction.timing.repeat` | 1..1 | Element |  |
| `MedicationRequest.dosageInstruction.timing.repeat.duration` | 1..1 | decimal |  |
| `MedicationRequest.dosageInstruction.timing.repeat.durationUnit` | 1..1 | code |  |
| `MedicationRequest.dosageInstruction.timing.code` | 1..1 | CodeableConcept |  |
| `MedicationRequest.dosageInstruction.timing.code.coding.system` | 1..1 | uri | si `MedicationRequest.dosageInstruction.timing.code.coding` |
| `MedicationRequest.dosageInstruction.timing.code.coding.code` | 1..1 | code | si `MedicationRequest.dosageInstruction.timing.code.coding` |
| `MedicationRequest.dosageInstruction.timing.code.coding.display` | 1..1 | string | si `MedicationRequest.dosageInstruction.timing.code.coding` |
| `MedicationRequest.dosageInstruction.route` | 1..1 | CodeableConcept |  |
| `MedicationRequest.dosageInstruction.route.coding.system` | 1..1 | uri | si `MedicationRequest.dosageInstruction.route.coding` |
| `MedicationRequest.dosageInstruction.route.coding.code` | 1..1 | code | si `MedicationRequest.dosageInstruction.route.coding` |
| `MedicationRequest.dosageInstruction.route.coding.display` | 1..1 | string | si `MedicationRequest.dosageInstruction.route.coding` |
| `MedicationRequest.dosageInstruction.doseAndRate` | 1..* | Element |  |
| `MedicationRequest.dosageInstruction.doseAndRate:UMM.dose[x]` | 1..1 | Quantity(SimpleQuantity) | si `MedicationRequest.dosageInstruction.doseAndRate:UMM` |
| `MedicationRequest.dosageInstruction.doseAndRate:UMM.dose[x].value` | 1..1 | decimal | si `MedicationRequest.dosageInstruction.doseAndRate:UMM` |
| `MedicationRequest.dosageInstruction.doseAndRate:UMM.dose[x].system` | 1..1 | uri | si `MedicationRequest.dosageInstruction.doseAndRate:UMM` |
| `MedicationRequest.dosageInstruction.doseAndRate:UMM.dose[x].code` | 1..1 | code | si `MedicationRequest.dosageInstruction.doseAndRate:UMM` |
| `MedicationRequest.dosageInstruction.doseAndRate:UMM.rate[x]` | 1..1 | Quantity(SimpleQuantity) | si `MedicationRequest.dosageInstruction.doseAndRate:UMM` |
| `MedicationRequest.dosageInstruction.doseAndRate:UMM.rate[x].value` | 1..1 | decimal | si `MedicationRequest.dosageInstruction.doseAndRate:UMM` |
| `MedicationRequest.dosageInstruction.doseAndRate:UMM.rate[x].system` | 1..1 | uri | si `MedicationRequest.dosageInstruction.doseAndRate:UMM` |
| `MedicationRequest.dosageInstruction.doseAndRate:UMM.rate[x].code` | 1..1 | code | si `MedicationRequest.dosageInstruction.doseAndRate:UMM` |
| `MedicationRequest.dosageInstruction.doseAndRate:MipresDoseForm.dose[x]` | 1..1 | Quantity(SimpleQuantity) | si `MedicationRequest.dosageInstruction.doseAndRate:MipresDoseForm` |
| `MedicationRequest.dosageInstruction.doseAndRate:MipresDoseForm.dose[x].value` | 1..1 | decimal | si `MedicationRequest.dosageInstruction.doseAndRate:MipresDoseForm` |
| `MedicationRequest.dosageInstruction.doseAndRate:MipresDoseForm.dose[x].system` | 1..1 | uri | si `MedicationRequest.dosageInstruction.doseAndRate:MipresDoseForm` |
| `MedicationRequest.dosageInstruction.doseAndRate:MipresDoseForm.dose[x].code` | 1..1 | code | si `MedicationRequest.dosageInstruction.doseAndRate:MipresDoseForm` |
| `MedicationRequest.substitution.allowed[x]` | 1..1 | boolean | CodeableConcept | si `MedicationRequest.substitution` |

### Must-support opcionales

`MedicationRequest.medication[x].text` 0..1 · `MedicationRequest.subject.extension:ExtensionPatientAddress` 0..1 · `MedicationRequest.subject.extension:ExtensionPatientPhone` 0..1 · `MedicationRequest.encounter` 0..1 · `MedicationRequest.requester.extension:ExtensionPrescriberAddress` 0..1 · `MedicationRequest.requester.extension:ExtensionPrescriberPhone` 0..1 · `MedicationRequest.dosageInstruction.text` 0..1 · `MedicationRequest.dosageInstruction.additionalInstruction` 0..1 · `MedicationRequest.dosageInstruction.patientInstruction` 0..1 · `MedicationRequest.dosageInstruction.doseAndRate:UMM.dose[x].unit` 0..1 · `MedicationRequest.dosageInstruction.doseAndRate:UMM.rate[x].unit` 0..1 · `MedicationRequest.dosageInstruction.doseAndRate:MipresDoseForm.dose[x].unit` 0..1 · `MedicationRequest.dispenseRequest.extension` 0..1 · `MedicationRequest.dispenseRequest.extension:ExtensionMedicationDispenseQuantity` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `MedicationRequest.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/MedicationRequestRDA"` |
| `MedicationRequest.identifier:PrescriptionNumber.id` | `patternString` | `"PrescriptionNumber"` |
| `MedicationRequest.identifier:MipresID.id` | `patternString` | `"MipresID"` |
| `MedicationRequest.identifier:MipresID.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/MIPRES"` |
| `MedicationRequest.status` | `fixedCode` | `"active"` |
| `MedicationRequest.intent` | `fixedCode` | `"order"` |
| `MedicationRequest.category.coding:R866.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianHealthTechnologyCategory"` |
| `MedicationRequest.medication[x].coding:DCI.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/MipresINN"` |
| `MedicationRequest.medication[x].coding:IUMPrimerNivel.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/IUMPrimerNivel"` |
| `MedicationRequest.reasonCode.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/RIPSFinalidadConsultaVersion2"` |
| `MedicationRequest.dosageInstruction.additionalInstruction.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/MipresSpecialInstruction"` |
| `MedicationRequest.dosageInstruction.timing.code.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/MedicationTime"` |
| `MedicationRequest.dosageInstruction.route.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/VAD"` |
| `MedicationRequest.dosageInstruction.doseAndRate:UMM.dose[x].system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/UMM"` |
| `MedicationRequest.dosageInstruction.doseAndRate:UMM.rate[x].system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/MedicationTime"` |
| `MedicationRequest.dosageInstruction.doseAndRate:MipresDoseForm.dose[x].system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/MipresDoseForm"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `MedicationRequest.identifier` | value:id ⚑ | open | `PrescriptionNumber` 0..1 Identifier<br>`MipresID` 0..1 Identifier |
| `MedicationRequest.category.coding` | value:system | closed | `R866` 0..1 Coding |
| `MedicationRequest.medication[x].coding` | value:system | closed | `DCI` 0..* Coding<br>`IUMPrimerNivel` 0..1 Coding |
| `MedicationRequest.subject.extension` | value:url | open | `ExtensionPatientAddress` 0..1 Extension(ExtensionAddress)<br>`ExtensionPatientPhone` 0..1 Extension(ExtensionTelecomPhone) |
| `MedicationRequest.requester.extension` | value:url | open | `ExtensionPrescriberAddress` 0..1 Extension(ExtensionAddress)<br>`ExtensionPrescriberPhone` 0..1 Extension(ExtensionTelecomPhone) |
| `MedicationRequest.dosageInstruction.doseAndRate` | value:dose.ofType(Quantity).system | closed | `UMM` 0..1 Element<br>`MipresDoseForm` 0..1 Element |
| `MedicationRequest.dispenseRequest.extension` | value:url | open | `ExtensionMedicationDispenseQuantity` 0..1 Extension(ExtensionMedicationDispenseQuantity) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `MedicationRequest.category.coding:R866` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianHealthTechnologyMedicationCodes` |
| `MedicationRequest.medication[x].coding:DCI` | `https://fhir.minsalud.gov.co/rda/ValueSet/MipresDCI` |
| `MedicationRequest.medication[x].coding:IUMPrimerNivel` | `https://fhir.minsalud.gov.co/rda/ValueSet/IUMPrimerNivelCodes` |
| `MedicationRequest.reasonCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/RIPSFinalidadConsultaVersion2Codigos` |
| `MedicationRequest.dosageInstruction.additionalInstruction.coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/MipresSpecialInstructionCodes` |
| `MedicationRequest.dosageInstruction.timing.code.coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/MedicationTimeCodes` |
| `MedicationRequest.dosageInstruction.route.coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/VADCodigos` |
| `MedicationRequest.dosageInstruction.doseAndRate:UMM.dose[x].code` | `https://fhir.minsalud.gov.co/rda/ValueSet/UMMCodigos` |
| `MedicationRequest.dosageInstruction.doseAndRate:UMM.rate[x].code` | `https://fhir.minsalud.gov.co/rda/ValueSet/MedicationTimeCodes` |
| `MedicationRequest.dosageInstruction.doseAndRate:MipresDoseForm.dose[x].code` | `https://fhir.minsalud.gov.co/rda/ValueSet/MipresDoseFormCodes` |

## MedicationStatementRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/MedicationStatementRDA`
- Tipo: `MedicationStatement`; base: `http://hl7.org/fhir/StructureDefinition/MedicationStatement`
- Descripción: Perfil FHIR de la declaración de uso de un medicamento (antecedente farmacológico) por parte de un paciente, para su intercambio en un documento RDA en Colombia.  Registro de medicamentos que un paciente afirma estar tomando o haber tomado, o que un profesional de la salud identifica como consumo actual o previo del paciente durante un proceso de atención.  La declaración de uso de medicamentos es la manifestación, por parte del paciente o de un informante autorizado, del uso de uno o más medicamentos, o el reconocimiento por parte de un profesional de salud de la utilización de medicamentos, con el objetivo de complementar la historia clínica, identificar posibles interacciones, prevenir eventos adversos y garantizar la continuidad y seguridad de la atención.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `MedicationStatement.meta.profile` | 1..* | canonical(StructureDefinition) | si `MedicationStatement.meta` |
| `MedicationStatement.status` | 1..1 | code |  |
| `MedicationStatement.medication[x]` | 1..1 | CodeableConcept |  |
| `MedicationStatement.medication[x].coding:DCI.system` | 1..1 | uri | si `MedicationStatement.medication[x].coding:DCI` |
| `MedicationStatement.medication[x].coding:DCI.code` | 1..1 | code | si `MedicationStatement.medication[x].coding:DCI` |
| `MedicationStatement.medication[x].coding:DCI.display` | 1..1 | string | si `MedicationStatement.medication[x].coding:DCI` |
| `MedicationStatement.subject` | 1..1 | Reference(PatientRDA) |  |

### Must-support opcionales

`MedicationStatement.medication[x].text` 0..1 · `MedicationStatement.dosage.text` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `MedicationStatement.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/MedicationStatementRDA"` |
| `MedicationStatement.medication[x].coding:DCI.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/MipresINN"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `MedicationStatement.medication[x].coding` | value:system | closed | `DCI` 0..* Coding |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `MedicationStatement.medication[x].coding:DCI` | `https://fhir.minsalud.gov.co/rda/ValueSet/MipresDCI` |

### Invariantes del perfil

| Clave | Severidad | Elemento | Regla | Expresión |
| --- | --- | --- | --- | --- |
| `ms-rda-0` | error | `MedicationStatement` | Debe existir al menos un código en medicationCodeableConcept.coding o, en su defecto, un texto descriptivo no vacío en medicationCodeableConcept.text. | `medication.coding.exists() or (medication.text.exists() and medication.text.trim().length() > 0)` |

## ObservationClarificationNoteRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/ObservationClarificationNoteRDA`
- Tipo: `Observation`; base: `http://hl7.org/fhir/StructureDefinition/Observation`
- Descripción: Perfil FHIR de notas aclaratorias, para su intercambio en un documento RDA en Colombia.  Una nota aclaratoria en la historia clínica es una anotación formal para corregir, ampliar o explicar información errónea o incompleta en un registro anterior, asegurando la integridad y exactitud del registro clínico, sin borrar lo escrito, y siempre priorizando la seguridad del paciente y la transparencia, indicando claramente el motivo de la corrección.   ## Propósito principal: - Rectificar errores: Corregir diagnósticos, tratamientos o evoluciones mal registrados. - Añadir detalles: Incorporar información olvidada o relevante que no estaba en la nota original. - Clarificar información: Explicar un dato ambiguo o malinterpretado.   Las notas aclaratorias son vitales para la precisión y legalidad de la Historia Clínica, debiendo ser diligenciadas siguiendo los principios de claridad, veracidad y confidencialidad establecidos por la normativa colombiana, especialmente para sistemas digitales.   El perfil **ObservationClarificationNoteRDA** define las restricciones y extensiones aplicables al recurso `Observation` para representar la **nota aclaratoria** sobre un documento RDA (Composition), previamente enviado a la plataforma de interoperabilidad de Historia Clínica Electrónica en Colombia.    El recurso `Observation` en FHIR se utiliza para registrar mediciones, evaluaciones o aserciones clínicas. En este caso, se adapta para registrar una **Nota aclaratoria**.    Este perfil forma parte del **Resumen Digital de Atención (RDA)** y contribuye a la interoperabilidad de la información ocupacional en el ecosistema de salud colombiano.  ## Cómo enviar una nota aclaratoria:  - La nota aclaratoria debe ser registrada como un recurso `Observation` siguiendo el perfil descrito en esta página. - Debe referenciar el documento RDA (Composition) del evento de atención que se requiere enmendar, ampliar o aclarar. - Debe ser realizada por un profesional de salud debidamente identificado. - La información de la nota aclaratoria debe ser clara, precisa y estar fechada. - La nota aclaratoria debe ser enviada a la plataforma de interoperabilidad de Historia Clínica Electrónica en Colombia, siguiendo los protocolos establecidos por el Ministerio de Salud y Protección Social. - Una o varias notas aclaratorias relacionadas con el documento RDA (Composition) de una atención pueden ser enviadas empleando un recurso `Bundle` tipo `transaction` que contenga los recursos `Observation` correspondientes. [Ver ejemplo de Bundle con notas aclaratorias](Bundle-Bundle-ObservationClarificationNotes.html).

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Observation.meta.profile` | 1..* | canonical(StructureDefinition) | si `Observation.meta` |
| `Observation.status` | 1..1 | code |  |
| `Observation.code` | 1..1 | CodeableConcept |  |
| `Observation.code.coding` | 1..1 | Coding |  |
| `Observation.code.coding.system` | 1..1 | uri |  |
| `Observation.code.coding.code` | 1..1 | code |  |
| `Observation.code.coding.display` | 1..1 | string |  |
| `Observation.code.text` | 1..1 | string |  |
| `Observation.subject` | 1..1 | Reference(PatientRDA) |  |
| `Observation.focus` | 1..* | Reference(Resource) |  |
| `Observation.focus:CompositionRDA` | 1..1 | Reference(CompositionAmbulatoryRDA, CompositionEmergencyRDA, CompositionHospitalizationRDA) |  |
| `Observation.focus:CompositionRDA.id` | 1..1 | String |  |
| `Observation.focus:Resource.id` | 1..1 | String | si `Observation.focus:Resource` |
| `Observation.effective[x]` | 1..1 | dateTime |  |
| `Observation.performer` | 1..1 | Reference(PractitionerRDA) |  |
| `Observation.value[x]` | 1..1 | string |  |

### Must-support opcionales

`Observation.focus:CompositionRDA.reference` 0..1 · `Observation.focus:Resource.reference` 0..1 · `Observation.encounter` 0..1 · `Observation.performer.reference` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Observation.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/ObservationClarificationNoteRDA"` |
| `Observation.status` | `fixedCode` | `"final"` |
| `Observation.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `Observation.code.coding.code` | `fixedCode` | `"445664008"` |
| `Observation.code.coding.display` | `fixedString` | `"informe enmendado"` |
| `Observation.code.text` | `fixedString` | `"Nota aclaratoria"` |
| `Observation.focus:CompositionRDA.id` | `fixedString` | `"CompositionRDA"` |
| `Observation.focus:Resource.id` | `patternString` | `"Resource-1"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Observation.focus` | value:id ⚑ | closed | `CompositionRDA` 1..1 Reference(CompositionAmbulatoryRDA, CompositionEmergencyRDA, CompositionHospitalizationRDA)<br>`Resource` 0..* Reference(ConditionRDA, AllergyIntoleranceRDA, MedicationAdministrationRDA, MedicationRequestRDA, MedicationAdminRequestRDA, ProcedureRDA, OtherTechnologyProcedureRDA, AttendanceAllowanceRDA, PatientOccupationAtEncounterRDA, RiskFactorRDA, ProcedureResultRDA, ServiceRequestRDA, OtherTechnologyServiceRequestRDA, ObservationTriageRDA) |

## ObservationTriageRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/ObservationTriageRDA`
- Tipo: `Observation`; base: `http://hl7.org/fhir/StructureDefinition/Observation`
- Descripción: Perfil FHIR de el Triage de urgencias, para su intercambio en un documento RDA en Colombia.   Triage es el proceso rápido y sistemático de clasificar a los pacientes según la gravedad de su condición clínica, con el fin de priorizar la atención y optimizar el uso de los recursos disponibles en situaciones de urgencias.  El perfil **ObservationTriageRDA** define las restricciones y extensiones aplicables al recurso `Observation` para representar la **clasificación de Triage de un paciente, durante un encuentro de atención de urgencias**.    El recurso `Observation` en FHIR se utiliza para registrar mediciones, evaluaciones o aserciones clínicas. En este caso, se adapta para documentar la **clasificación del Triage**.    Este perfil forma parte del **Resumen Digital de Atención (RDA)** y contribuye a la interoperabilidad de la información ocupacional en el ecosistema de salud colombiano.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Observation.meta.profile` | 1..* | canonical(StructureDefinition) | si `Observation.meta` |
| `Observation.status` | 1..1 | code |  |
| `Observation.code` | 1..1 | CodeableConcept |  |
| `Observation.code.coding` | 1..1 | Coding |  |
| `Observation.code.coding.system` | 1..1 | uri |  |
| `Observation.code.coding.code` | 1..1 | code |  |
| `Observation.code.coding.display` | 1..1 | string |  |
| `Observation.code.text` | 1..1 | string |  |
| `Observation.subject` | 1..1 | Reference(PatientRDA) |  |
| `Observation.effective[x]` | 1..1 | dateTime |  |
| `Observation.value[x]` | 1..1 | CodeableConcept |  |
| `Observation.value[x].coding` | 1..1 | Coding |  |
| `Observation.value[x].coding.system` | 1..1 | uri |  |
| `Observation.value[x].coding.code` | 1..1 | code |  |
| `Observation.value[x].coding.display` | 1..1 | string |  |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Observation.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/ObservationTriageRDA"` |
| `Observation.status` | `fixedCode` | `"final"` |
| `Observation.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `Observation.code.coding.code` | `fixedCode` | `"225390008"` |
| `Observation.code.coding.display` | `fixedString` | `"triaje"` |
| `Observation.code.text` | `fixedString` | `"Triage"` |
| `Observation.value[x].coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ClaseTriage"` |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Observation.value[x].coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/ClaseTriageCodigos` |

## OtherTechnologyProcedureRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/OtherTechnologyProcedureRDA`
- Tipo: `Procedure`; base: `http://hl7.org/fhir/StructureDefinition/Procedure`
- Descripción: Perfil FHIR de otras tecnologías en salud administradas durante la atención a un paciente, para su intercambio en un documento RDA en Colombia.  El perfil **OtherTechnologyProcedureRDA** define las restricciones y extensiones aplicables al recurso `Procedure` para representar **otras tecnologías en salud administradas durante la atención a un paciente**, incluyendo:  - Dispositivos médicos.   - Componentes sanguíneos.   - Fluidos orgánicos.   - Órganos.   - Tejidos.   - Células.   - Productos de soporte nutricional.   - Servicios complementarios.    En FHIR, el recurso `Procedure` describe una acción clínica llevada a cabo en un paciente, con un objetivo diagnóstico, terapéutico, preventivo o de soporte. Este perfil adapta dicho recurso al contexto del **Resumen Digital de Atención (RDA)**, permitiendo registrar la administración o aplicación de tecnologías en salud distintas a medicamentos, dentro de la atención clínica, de acuerdo con la normativa vigente en Colombia.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Procedure.meta.profile` | 1..* | canonical(StructureDefinition) | si `Procedure.meta` |
| `Procedure.extension` | 1..* | Extension |  |
| `Procedure.extension:ExtensionRequestDate` | 1..1 | Extension(ExtensionRequestDate) |  |
| `Procedure.status` | 1..1 | code |  |
| `Procedure.category` | 1..1 | CodeableConcept |  |
| `Procedure.category.coding.system` | 1..1 | uri | si `Procedure.category.coding` |
| `Procedure.category.coding.code` | 1..1 | code | si `Procedure.category.coding` |
| `Procedure.category.coding.display` | 1..1 | string | si `Procedure.category.coding` |
| `Procedure.code` | 1..1 | CodeableConcept |  |
| `Procedure.code.text` | 1..1 | string |  |
| `Procedure.subject` | 1..1 | Reference(PatientRDA) |  |
| `Procedure.performed[x]` | 1..1 | dateTime |  |
| `Procedure.reasonCode` | 1..1 | CodeableConcept |  |
| `Procedure.reasonCode.coding.system` | 1..1 | uri | si `Procedure.reasonCode.coding` |
| `Procedure.reasonCode.coding.code` | 1..1 | code | si `Procedure.reasonCode.coding` |
| `Procedure.reasonCode.coding.display` | 1..1 | string | si `Procedure.reasonCode.coding` |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Procedure.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/OtherTechnologyProcedureRDA"` |
| `Procedure.status` | `fixedCode` | `"completed"` |
| `Procedure.category.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianHealthTechnologyCategory"` |
| `Procedure.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `Procedure.reasonCode.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/RIPSFinalidadConsultaVersion2"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Procedure.extension` | value:url | open | `ExtensionRequestDate` 1..1 Extension(ExtensionRequestDate) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Procedure.category` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianOtherHealthTechnologyCategoryCodes` |
| `Procedure.reasonCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/RIPSFinalidadConsultaVersion2Codigos` |

## OtherTechnologyServiceRequestRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/OtherTechnologyServiceRequestRDA`
- Tipo: `ServiceRequest`; base: `http://hl7.org/fhir/StructureDefinition/ServiceRequest`
- Descripción: Perfil FHIR de otras tecnologías en salud ordenadas durante la atención a un paciente, para su intercambio en un documento RDA en Colombia.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `ServiceRequest.meta.profile` | 1..* | canonical(StructureDefinition) | si `ServiceRequest.meta` |
| `ServiceRequest.status` | 1..1 | code |  |
| `ServiceRequest.intent` | 1..1 | code |  |
| `ServiceRequest.category` | 1..1 | CodeableConcept |  |
| `ServiceRequest.category.coding:R866.system` | 1..1 | uri | si `ServiceRequest.category.coding:R866` |
| `ServiceRequest.category.coding:R866.code` | 1..1 | code | si `ServiceRequest.category.coding:R866` |
| `ServiceRequest.category.coding:R866.display` | 1..1 | string | si `ServiceRequest.category.coding:R866` |
| `ServiceRequest.code` | 1..1 | CodeableConcept |  |
| `ServiceRequest.code.text` | 1..1 | string |  |
| `ServiceRequest.subject` | 1..1 | Reference(PatientRDA) |  |
| `ServiceRequest.authoredOn` | 1..1 | dateTime |  |
| `ServiceRequest.reasonCode` | 1..1 | CodeableConcept |  |
| `ServiceRequest.reasonCode.coding.system` | 1..1 | uri | si `ServiceRequest.reasonCode.coding` |
| `ServiceRequest.reasonCode.coding.code` | 1..1 | code | si `ServiceRequest.reasonCode.coding` |
| `ServiceRequest.reasonCode.coding.display` | 1..1 | string | si `ServiceRequest.reasonCode.coding` |

### Must-support opcionales

`ServiceRequest.encounter` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `ServiceRequest.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/OtherTechnologyServiceRequestRDA"` |
| `ServiceRequest.status` | `fixedCode` | `"active"` |
| `ServiceRequest.intent` | `fixedCode` | `"order"` |
| `ServiceRequest.category.coding:R866.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianHealthTechnologyCategory"` |
| `ServiceRequest.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `ServiceRequest.reasonCode.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/RIPSFinalidadConsultaVersion2"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `ServiceRequest.category.coding` | value:system | closed | `R866` 0..1 Coding |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `ServiceRequest.category.coding:R866` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianOtherHealthTechnologyCategoryCodes` |
| `ServiceRequest.reasonCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/RIPSFinalidadConsultaVersion2Codigos` |

## PatientOccupationAtEncounterRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/PatientOccupationAtEncounterRDA`
- Tipo: `Observation`; base: `http://hl7.org/fhir/StructureDefinition/Observation`
- Descripción: Perfil FHIR de la ocupación de un paciente en el momento de un encuentro de atención en salud, para su intercambio en un documento RDA en Colombia.  El perfil **PatientOccupationAtEncounterRDA** define las restricciones y extensiones aplicables al recurso `Observation` para representar la **ocupación del paciente en el momento de un encuentro de atención en salud**, con base en el **Clasificador Internacional Uniforme de Ocupaciones CIUO-88 A.C.**.    El recurso `Observation` en FHIR se utiliza para registrar mediciones, evaluaciones o aserciones clínicas. En este caso, se adapta para documentar la **actividad laboral u ocupacional declarada por el paciente en el contexto de la atención en salud**, lo que permite disponer de información estandarizada sobre su ocupación, facilitando el análisis de factores sociales, económicos y ocupacionales en la prestación de servicios de salud en Colombia.    Este perfil forma parte del **Resumen Digital de Atención (RDA)** y contribuye a la interoperabilidad de la información ocupacional en el ecosistema de salud colombiano.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Observation.meta.profile` | 1..* | canonical(StructureDefinition) | si `Observation.meta` |
| `Observation.status` | 1..1 | code |  |
| `Observation.code` | 1..1 | CodeableConcept |  |
| `Observation.code.coding` | 1..1 | Coding |  |
| `Observation.code.coding.system` | 1..1 | uri |  |
| `Observation.code.coding.code` | 1..1 | code |  |
| `Observation.code.coding.display` | 1..1 | string |  |
| `Observation.code.text` | 1..1 | string |  |
| `Observation.subject` | 1..1 | Reference(PatientRDA) |  |
| `Observation.value[x]` | 1..1 | CodeableConcept |  |
| `Observation.value[x].coding` | 1..1 | Coding |  |
| `Observation.value[x].coding.system` | 1..1 | uri |  |
| `Observation.value[x].coding.code` | 1..1 | code |  |
| `Observation.value[x].coding.display` | 1..1 | string |  |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Observation.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/PatientOccupationAtEncounterRDA"` |
| `Observation.status` | `fixedCode` | `"final"` |
| `Observation.code.coding.system` | `fixedUri` | `"http://snomed.info/sct"` |
| `Observation.code.coding.code` | `fixedCode` | `"184104002"` |
| `Observation.code.coding.display` | `fixedString` | `"ocupación del paciente"` |
| `Observation.code.text` | `fixedString` | `"Ocupación del paciente en el momento de la atención"` |
| `Observation.value[x].coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/CIUO88AC"` |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Observation.value[x].coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/CIUO88ACCodes` |

## PatientRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/PatientRDA`
- Tipo: `Patient`; base: `http://hl7.org/fhir/StructureDefinition/Patient`
- Descripción: Perfil FHIR de un paciente, para su intercambio en un documento RDA en Colombia.  Información sobre una persona que desempeña el rol de paciente o usuario del sistema de salud y recibe servicios de atención en salud.  Incluye los datos de identificación, demográficos y administrativos sobre el usuario del sistema de salud, para el seguimiento de la información a través de todos los procesos de atención en salud.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Patient.meta.profile` | 1..* | canonical(StructureDefinition) | si `Patient.meta` |
| `Patient.extension` | 3..* | Extension |  |
| `Patient.extension:ExtensionPatientNationality` | 1..* | Extension(ExtensionPatientNationality) |  |
| `Patient.extension:ExtensionPatientEthnicity` | 1..1 | Extension(ExtensionPatientEthnicity) |  |
| `Patient.extension:ExtensionPatientDisability` | 1..* | Extension(ExtensionPatientDisability) |  |
| `Patient.identifier` | 1..* | Identifier |  |
| `Patient.identifier:NationalPersonIdentifier.id` | 1..1 | String | si `Patient.identifier:NationalPersonIdentifier` |
| `Patient.identifier:NationalPersonIdentifier.use` | 1..1 | code | si `Patient.identifier:NationalPersonIdentifier` |
| `Patient.identifier:NationalPersonIdentifier.type` | 1..1 | CodeableConcept | si `Patient.identifier:NationalPersonIdentifier` |
| `Patient.identifier:NationalPersonIdentifier.type.coding` | 2..2 | Coding | si `Patient.identifier:NationalPersonIdentifier` |
| `Patient.identifier:NationalPersonIdentifier.type.coding:InternationalCode` | 1..1 | Coding | si `Patient.identifier:NationalPersonIdentifier` |
| `Patient.identifier:NationalPersonIdentifier.type.coding:InternationalCode.system` | 1..1 | uri | si `Patient.identifier:NationalPersonIdentifier` |
| `Patient.identifier:NationalPersonIdentifier.type.coding:InternationalCode.code` | 1..1 | code | si `Patient.identifier:NationalPersonIdentifier` |
| `Patient.identifier:NationalPersonIdentifier.type.coding:InternationalCode.display` | 1..1 | string | si `Patient.identifier:NationalPersonIdentifier` |
| `Patient.identifier:NationalPersonIdentifier.type.coding:ColombianCode` | 1..1 | Coding | si `Patient.identifier:NationalPersonIdentifier` |
| `Patient.identifier:NationalPersonIdentifier.type.coding:ColombianCode.system` | 1..1 | uri | si `Patient.identifier:NationalPersonIdentifier` |
| `Patient.identifier:NationalPersonIdentifier.type.coding:ColombianCode.code` | 1..1 | code | si `Patient.identifier:NationalPersonIdentifier` |
| `Patient.identifier:NationalPersonIdentifier.type.coding:ColombianCode.display` | 1..1 | string | si `Patient.identifier:NationalPersonIdentifier` |
| `Patient.identifier:NationalPersonIdentifier.value` | 1..1 | string | si `Patient.identifier:NationalPersonIdentifier` |
| `Patient.active` | 1..1 | boolean |  |
| `Patient.name` | 1..1 | HumanName |  |
| `Patient.name:OfficialPatientName` | 1..1 | HumanName |  |
| `Patient.name:OfficialPatientName.use` | 1..1 | code |  |
| `Patient.name:OfficialPatientName.family` | 1..1 | string |  |
| `Patient.name:OfficialPatientName.given` | 1..2 | string |  |
| `Patient.name:PatientIdentifyingName.use` | 1..1 | code | si `Patient.name:PatientIdentifyingName` |
| `Patient.name:PatientIdentifyingName.text` | 1..1 | string | si `Patient.name:PatientIdentifyingName` |
| `Patient.gender.extension` | 1..* | Extension | si `Patient.gender` |
| `Patient.gender.extension:ExtensionBiologicalGender` | 1..1 | Extension(ExtensionBiologicalGender) | si `Patient.gender` |
| `Patient.birthDate` | 1..1 | date |  |
| `Patient.address` | 1..* | Address |  |
| `Patient.address:HomeAddress` | 1..1 | Address |  |
| `Patient.address:HomeAddress.id` | 1..1 | String |  |
| `Patient.address:HomeAddress.extension` | 1..* | Extension |  |
| `Patient.address:HomeAddress.extension:ExtensionResidenceZone` | 1..1 | Extension(ExtensionResidenceZone) |  |
| `Patient.address:HomeAddress.use` | 1..1 | code |  |
| `Patient.address:HomeAddress.type` | 1..1 | code |  |
| `Patient.address:HomeAddress.city` | 1..1 | string |  |
| `Patient.address:HomeAddress.country` | 1..1 | string |  |
| `Patient.address:HomeAddress.country.extension` | 1..* | Extension |  |
| `Patient.address:HomeAddress.country.extension:ExtensionCountryCode` | 1..1 | Extension(ExtensionCountryCode) |  |
| `Patient.link.other` | 1..1 | Reference(PatientRDA) | si `Patient.link` |
| `Patient.link.type` | 1..1 | code | si `Patient.link` |

### Must-support opcionales

`Patient.extension:ExtensionBirthPlace` 0..1 · `Patient.identifier:NationalPersonIdentifier` 0..1 · `Patient.name:OfficialPatientName.family.extension:FathersFamilyName` 0..1 · `Patient.name:OfficialPatientName.family.extension:MothersFamilyName` 0..1 · `Patient.gender` 0..1 · `Patient.birthDate.extension:ExtensionBirthTime` 0..1 · `Patient.address:HomeAddress.city.extension:ExtensionDivipolaMunicipality` 0..1 · `Patient.managingOrganization` 0..1 · `Patient.link` 0..*

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Patient.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/PatientRDA"` |
| `Patient.identifier:NationalPersonIdentifier.id` | `patternString` | `"NationalPersonIdentifier-0"` |
| `Patient.identifier:NationalPersonIdentifier.use` | `fixedCode` | `"official"` |
| `Patient.identifier:NationalPersonIdentifier.type.coding:InternationalCode.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v2-0203"` |
| `Patient.identifier:NationalPersonIdentifier.type.coding:InternationalCode.code` | `fixedCode` | `"PN"` |
| `Patient.identifier:NationalPersonIdentifier.type.coding:InternationalCode.display` | `fixedString` | `"Person number"` |
| `Patient.identifier:NationalPersonIdentifier.type.coding:ColombianCode.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianPersonIdentifier"` |
| `Patient.identifier:NationalPersonIdentifier.system` | `patternUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/RNEC"` |
| `Patient.name:OfficialPatientName.use` | `fixedCode` | `"official"` |
| `Patient.name:PatientIdentifyingName.use` | `fixedCode` | `"usual"` |
| `Patient.address:HomeAddress.id` | `patternString` | `"HomeAddress-0"` |
| `Patient.address:HomeAddress.use` | `fixedCode` | `"home"` |
| `Patient.address:HomeAddress.type` | `fixedCode` | `"physical"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Patient.extension` | value:url | open | `ExtensionPatientNationality` 1..* Extension(ExtensionPatientNationality)<br>`ExtensionBirthPlace` 0..1 Extension(ExtensionBirthPlace)<br>`ExtensionPatientEthnicity` 1..1 Extension(ExtensionPatientEthnicity)<br>`ExtensionPatientEthnicCommunity` 0..1 Extension(ExtensionPatientEthnicCommunity)<br>`ExtensionPatientDisability` 1..* Extension(ExtensionPatientDisability)<br>`ExtensionPatientGenderIdentity` 0..1 Extension(ExtensionPatientGenderIdentity) |
| `Patient.identifier` | value:id ⚑ | closed | `NationalPersonIdentifier` 0..1 Identifier |
| `Patient.identifier:NationalPersonIdentifier.type.coding` | value:system | closed | `InternationalCode` 1..1 Coding<br>`ColombianCode` 1..1 Coding |
| `Patient.name` | value:use | closed | `OfficialPatientName` 1..1 HumanName<br>`PatientIdentifyingName` 0..1 HumanName |
| `Patient.name:OfficialPatientName.family.extension` | value:url | open | `FathersFamilyName` 0..1 Extension(ExtensionFathersFamilyName)<br>`MothersFamilyName` 0..1 Extension(ExtensionMothersFamilyName) |
| `Patient.gender.extension` | value:url | open | `ExtensionBiologicalGender` 1..1 Extension(ExtensionBiologicalGender) |
| `Patient.birthDate.extension` | value:url | open | `ExtensionBirthTime` 0..1 Extension(ExtensionBirthTime) |
| `Patient.address` | value:id ⚑ | closed | `HomeAddress` 1..1 Address |
| `Patient.address:HomeAddress.extension` | value:url | open | `ExtensionResidenceZone` 1..1 Extension(ExtensionResidenceZone) |
| `Patient.address:HomeAddress.city.extension` | value:url | open | `ExtensionDivipolaMunicipality` 0..1 Extension(ExtensionDivipolaMunicipality) |
| `Patient.address:HomeAddress.country.extension` | value:url | open | `ExtensionCountryCode` 1..1 Extension(ExtensionCountryCode) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Patient.identifier:NationalPersonIdentifier.type.coding:ColombianCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianPersonIdentifierCodes` |

## PractitionerRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/PractitionerRDA`
- Tipo: `Practitioner`; base: `http://hl7.org/fhir/StructureDefinition/Practitioner`
- Descripción: Perfil FHIR de un profesional de salud, para su intercambio en un documento RDA en Colombia.  Información sobre una persona con una responsabilidad formal en la prestación de servicios de atención en salud o afines.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Practitioner.meta.profile` | 1..* | canonical(StructureDefinition) | si `Practitioner.meta` |
| `Practitioner.identifier` | 1..* | Identifier |  |
| `Practitioner.identifier:NationalPersonIdentifier` | 1..1 | Identifier |  |
| `Practitioner.identifier:NationalPersonIdentifier.id` | 1..1 | String |  |
| `Practitioner.identifier:NationalPersonIdentifier.use` | 1..1 | code |  |
| `Practitioner.identifier:NationalPersonIdentifier.type` | 1..1 | CodeableConcept |  |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding` | 2..2 | Coding |  |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding:InternationalCode` | 1..1 | Coding |  |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding:InternationalCode.system` | 1..1 | uri |  |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding:InternationalCode.code` | 1..1 | code |  |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding:InternationalCode.display` | 1..1 | string |  |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding:ColombianCode` | 1..1 | Coding |  |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding:ColombianCode.system` | 1..1 | uri |  |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding:ColombianCode.code` | 1..1 | code |  |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding:ColombianCode.display` | 1..1 | string |  |
| `Practitioner.identifier:NationalPersonIdentifier.value` | 1..1 | string |  |
| `Practitioner.active` | 1..1 | boolean |  |
| `Practitioner.name` | 1..1 | HumanName |  |
| `Practitioner.name.use` | 1..1 | code |  |
| `Practitioner.name.family` | 1..1 | string |  |
| `Practitioner.name.family.extension` | 1..* | Extension |  |
| `Practitioner.name.family.extension:FathersFamilyName` | 1..1 | Extension(ExtensionFathersFamilyName) |  |
| `Practitioner.name.given` | 1..* | string |  |
| `Practitioner.address.use` | 1..1 | code | si `Practitioner.address` |
| `Practitioner.address.type` | 1..1 | code | si `Practitioner.address` |
| `Practitioner.address.city` | 1..1 | string | si `Practitioner.address` |
| `Practitioner.address.state` | 1..1 | string | si `Practitioner.address` |
| `Practitioner.address.country` | 1..1 | string | si `Practitioner.address` |
| `Practitioner.qualification` | 1..* | BackboneElement |  |
| `Practitioner.qualification.code` | 1..1 | CodeableConcept |  |
| `Practitioner.qualification:Rethus.identifier` | 1..* | Identifier | si `Practitioner.qualification:Rethus` |
| `Practitioner.qualification:Rethus.identifier.use` | 1..1 | code | si `Practitioner.qualification:Rethus` |
| `Practitioner.qualification:Rethus.identifier.type` | 1..1 | CodeableConcept | si `Practitioner.qualification:Rethus` |
| `Practitioner.qualification:Rethus.identifier.type.coding.system` | 1..1 | uri | si `Practitioner.qualification:Rethus` |
| `Practitioner.qualification:Rethus.identifier.type.coding.code` | 1..1 | code | si `Practitioner.qualification:Rethus` |
| `Practitioner.qualification:Rethus.identifier.type.coding.display` | 1..1 | string | si `Practitioner.qualification:Rethus` |
| `Practitioner.qualification:Rethus.identifier.system` | 1..1 | uri | si `Practitioner.qualification:Rethus` |
| `Practitioner.qualification:Rethus.identifier.value` | 1..1 | string | si `Practitioner.qualification:Rethus` |
| `Practitioner.qualification:Rethus.code` | 1..1 | CodeableConcept | si `Practitioner.qualification:Rethus` |
| `Practitioner.qualification:Rethus.code.coding` | 1..1 | Coding | si `Practitioner.qualification:Rethus` |
| `Practitioner.qualification:Rethus.code.coding.system` | 1..1 | uri | si `Practitioner.qualification:Rethus` |
| `Practitioner.qualification:Rethus.code.coding.code` | 1..1 | code | si `Practitioner.qualification:Rethus` |
| `Practitioner.qualification:Rethus.code.coding.display` | 1..1 | string | si `Practitioner.qualification:Rethus` |
| `Practitioner.qualification:Sso.identifier` | 1..* | Identifier | si `Practitioner.qualification:Sso` |
| `Practitioner.qualification:Sso.identifier.use` | 1..1 | code | si `Practitioner.qualification:Sso` |
| `Practitioner.qualification:Sso.identifier.type` | 1..1 | CodeableConcept | si `Practitioner.qualification:Sso` |
| `Practitioner.qualification:Sso.identifier.type.coding.system` | 1..1 | uri | si `Practitioner.qualification:Sso` |
| `Practitioner.qualification:Sso.identifier.type.coding.code` | 1..1 | code | si `Practitioner.qualification:Sso` |
| `Practitioner.qualification:Sso.identifier.type.coding.display` | 1..1 | string | si `Practitioner.qualification:Sso` |
| `Practitioner.qualification:Sso.identifier.system` | 1..1 | uri | si `Practitioner.qualification:Sso` |
| `Practitioner.qualification:Sso.identifier.value` | 1..1 | string | si `Practitioner.qualification:Sso` |
| `Practitioner.qualification:Sso.code` | 1..1 | CodeableConcept | si `Practitioner.qualification:Sso` |
| `Practitioner.qualification:Sso.code.coding` | 1..1 | Coding | si `Practitioner.qualification:Sso` |
| `Practitioner.qualification:Sso.code.coding.system` | 1..1 | uri | si `Practitioner.qualification:Sso` |
| `Practitioner.qualification:Sso.code.coding.code` | 1..1 | code | si `Practitioner.qualification:Sso` |
| `Practitioner.qualification:Sso.code.coding.display` | 1..1 | string | si `Practitioner.qualification:Sso` |

### Must-support opcionales

`Practitioner.name.family.extension:MothersFamilyName` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Practitioner.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/PractitionerRDA"` |
| `Practitioner.identifier:NationalPersonIdentifier.id` | `fixedString` | `"NationalPersonIdentifier-0"` |
| `Practitioner.identifier:NationalPersonIdentifier.use` | `fixedCode` | `"official"` |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding:InternationalCode.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v2-0203"` |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding:InternationalCode.code` | `fixedCode` | `"PN"` |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding:InternationalCode.display` | `fixedString` | `"Person number"` |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding:ColombianCode.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianPersonIdentifier"` |
| `Practitioner.identifier:NationalPersonIdentifier.system` | `patternUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/RNEC"` |
| `Practitioner.name.use` | `fixedCode` | `"official"` |
| `Practitioner.address.use` | `fixedCode` | `"work"` |
| `Practitioner.address.type` | `fixedCode` | `"physical"` |
| `Practitioner.address.country` | `fixedString` | `"CO"` |
| `Practitioner.qualification:Rethus.identifier.use` | `fixedCode` | `"official"` |
| `Practitioner.qualification:Rethus.identifier.type.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v2-0203"` |
| `Practitioner.qualification:Rethus.identifier.type.coding.code` | `fixedCode` | `"LN"` |
| `Practitioner.qualification:Rethus.identifier.type.coding.display` | `patternString` | `"License number"` |
| `Practitioner.qualification:Rethus.identifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/RETHUS"` |
| `Practitioner.qualification:Rethus.identifier.assigner.type` | `fixedUri` | `"Organization"` |
| `Practitioner.qualification:Rethus.code.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/RETHUSqualification"` |
| `Practitioner.qualification:Sso.identifier.use` | `fixedCode` | `"official"` |
| `Practitioner.qualification:Sso.identifier.type.coding.system` | `fixedUri` | `"http://terminology.hl7.org/CodeSystem/v2-0203"` |
| `Practitioner.qualification:Sso.identifier.type.coding.code` | `fixedCode` | `"TRL"` |
| `Practitioner.qualification:Sso.identifier.type.coding.display` | `patternString` | `"Training License Number"` |
| `Practitioner.qualification:Sso.identifier.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/NamingSystem/SSO"` |
| `Practitioner.qualification:Sso.identifier.assigner.type` | `fixedUri` | `"Organization"` |
| `Practitioner.qualification:Sso.code.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/RETHUSqualification"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Practitioner.identifier` | value:id ⚑ | open | `NationalPersonIdentifier` 1..1 Identifier |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding` | value:system | open | `InternationalCode` 1..1 Coding<br>`ColombianCode` 1..1 Coding |
| `Practitioner.name.family.extension` | value:url | open | `FathersFamilyName` 1..1 Extension(ExtensionFathersFamilyName)<br>`MothersFamilyName` 0..1 Extension(ExtensionMothersFamilyName) |
| `Practitioner.address.city.extension` | value:url | open | `ExtensionDivipolaMunicipality` 0..1 Extension(ExtensionDivipolaMunicipality) |
| `Practitioner.address.state.extension` | value:url | open | `ExtensionDivipolaDepartment` 0..1 Extension(ExtensionDivipolaDepartment) |
| `Practitioner.qualification` | value:identifier.system ⚑ | open | `Rethus` 0..* BackboneElement<br>`Sso` 0..1 BackboneElement |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Practitioner.identifier:NationalPersonIdentifier.type.coding:ColombianCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianPersonIdentifierCodes` |
| `Practitioner.qualification:Rethus.code` | `https://fhir.minsalud.gov.co/rda/ValueSet/RETHUSqualificationCodes` |
| `Practitioner.qualification:Sso.code` | `https://fhir.minsalud.gov.co/rda/ValueSet/RETHUSqualificationCodes` |

## ProcedureRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/ProcedureRDA`
- Tipo: `Procedure`; base: `http://hl7.org/fhir/StructureDefinition/Procedure`
- Descripción: Perfil FHIR de un procedimiento realizado a un paciente durante un encuentro de atención en salud, para su intercambio en un documento RDA en Colombia.  Actividad o intervención realizada por un profesional de la salud autorizado y habilitado, con el objetivo de apoyar, diagnosticar, tratar o prevenir condiciones de salud, como parte de un proceso de atención en salud.  Un procedimiento en salud puede incluir intervenciones quirúrgicas, procedimientos diagnósticos, terapéuticos o de soporte, y se realiza con base en criterios clínicos y científicos, con el fin de contribuir al diagnóstico, tratamiento o recuperación de la salud de una persona, en concordancia con los lineamientos establecidos por la normativa colombiana.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Procedure.meta.profile` | 1..* | canonical(StructureDefinition) | si `Procedure.meta` |
| `Procedure.status` | 1..1 | code |  |
| `Procedure.category.coding.system` | 1..1 | uri | si `Procedure.category` |
| `Procedure.category.coding.code` | 1..1 | code | si `Procedure.category` |
| `Procedure.category.coding.display` | 1..1 | string | si `Procedure.category` |
| `Procedure.code` | 1..1 | CodeableConcept |  |
| `Procedure.code.coding.system` | 1..1 | uri | si `Procedure.code.coding` |
| `Procedure.code.coding.code` | 1..1 | code | si `Procedure.code.coding` |
| `Procedure.code.coding.display` | 1..1 | string | si `Procedure.code.coding` |
| `Procedure.subject` | 1..1 | Reference(PatientRDA) |  |
| `Procedure.performed[x]` | 1..1 | dateTime |  |
| `Procedure.performer` | 1..* | BackboneElement |  |
| `Procedure.performer.actor` | 1..1 | Reference(PractitionerRDA) |  |
| `Procedure.reasonCode` | 1..1 | CodeableConcept |  |
| `Procedure.reasonCode.coding.system` | 1..1 | uri | si `Procedure.reasonCode.coding` |
| `Procedure.reasonCode.coding.code` | 1..1 | code | si `Procedure.reasonCode.coding` |
| `Procedure.reasonCode.coding.display` | 1..1 | string | si `Procedure.reasonCode.coding` |
| `Procedure.reasonReference` | 2..* | Reference(Condition, Observation, Procedure, DiagnosticReport, DocumentReference) |  |
| `Procedure.reasonReference:MainDiagnosis` | 1..1 | Reference(ConditionRDA) |  |
| `Procedure.reasonReference:MainDiagnosis.id` | 1..1 | String |  |
| `Procedure.reasonReference:Comobility` | 1..1 | Reference(ConditionRDA) |  |
| `Procedure.reasonReference:Comobility.id` | 1..1 | String |  |
| `Procedure.complication.coding.system` | 1..1 | uri | si `Procedure.complication` |
| `Procedure.complication.coding.code` | 1..1 | code | si `Procedure.complication` |
| `Procedure.complication.coding.display` | 1..1 | string | si `Procedure.complication` |
| `Procedure.focalDevice.manipulated` | 1..1 | Reference(Device) | si `Procedure.focalDevice` |

### Must-support opcionales

`Procedure.extension:ExtensionSurgicalMethod` 0..1 · `Procedure.category` 0..1 · `Procedure.encounter` 0..1 · `Procedure.complication` 0..* · `Procedure.followUp` 0..*

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Procedure.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/ProcedureRDA"` |
| `Procedure.category.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianHealthTechnologyCategory"` |
| `Procedure.category.coding.code` | `fixedCode` | `"01"` |
| `Procedure.category.coding.display` | `fixedString` | `"Procedimiento en salud"` |
| `Procedure.code.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/CUPS"` |
| `Procedure.reasonCode.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/RIPSFinalidadConsultaVersion2"` |
| `Procedure.reasonReference:MainDiagnosis.id` | `patternString` | `"MainDiagnosis"` |
| `Procedure.reasonReference:Comobility.id` | `patternString` | `"Comobility-1"` |
| `Procedure.complication.coding.system` | `fixedUri` | `"http://hl7.org/fhir/sid/icd-10"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Procedure.extension` | value:url | open | `ExtensionSurgicalMethod` 0..1 Extension(ExtensionSurgicalMethod) |
| `Procedure.reasonReference` | value:id ⚑ | closed, ordenado | `MainDiagnosis` 1..1 Reference(ConditionRDA)<br>`Comobility` 1..1 Reference(ConditionRDA) |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Procedure.category` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianHealthTechnologyCategoryCodes` |
| `Procedure.code` | `https://fhir.minsalud.gov.co/rda/ValueSet/CoCUPSProcedures` |
| `Procedure.reasonCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/RIPSFinalidadConsultaVersion2Codigos` |
| `Procedure.complication` | `https://fhir.minsalud.gov.co/rda/ValueSet/ICD10Codes` |

## ProcedureResultRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/ProcedureResultRDA`
- Tipo: `Observation`; base: `http://hl7.org/fhir/StructureDefinition/Observation`
- Descripción: Perfil FHIR de resultado de un procedimiento realizado a un paciente durante un encuentro de atención en salud, para su intercambio en un documento RDA en Colombia.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `Observation.meta.profile` | 1..* | canonical(StructureDefinition) | si `Observation.meta` |
| `Observation.partOf` | 1..1 | Reference(ProcedureRDA) |  |
| `Observation.status` | 1..1 | code |  |
| `Observation.code` | 1..1 | CodeableConcept |  |
| `Observation.code.coding.system` | 1..1 | uri | si `Observation.code.coding` |
| `Observation.code.coding.code` | 1..1 | code | si `Observation.code.coding` |
| `Observation.code.coding.display` | 1..1 | string | si `Observation.code.coding` |
| `Observation.subject` | 1..1 | Reference(PatientRDA) |  |
| `Observation.effective[x]` | 1..1 | dateTime | Period | Timing | instant |  |
| `Observation.effective[x]:effectiveDateTime` | 1..1 | dateTime |  |
| `Observation.performer` | 1..1 | Reference(PractitionerRDA) |  |
| `Observation.device.identifier.value` | 1..1 | string | si `Observation.device` |
| `Observation.component` | 1..* | BackboneElement |  |
| `Observation.component.code` | 1..1 | CodeableConcept |  |
| `Observation.component.code.text` | 1..1 | string |  |

### Must-support opcionales

`Observation.encounter` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `Observation.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/ProcedureResultRDA"` |
| `Observation.status` | `fixedCode` | `"final"` |
| `Observation.code.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/CUPS"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `Observation.effective[x]` | type:$this | open | `effectiveDateTime` 1..1 dateTime |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `Observation.code` | `https://fhir.minsalud.gov.co/rda/ValueSet/CoCUPSProcedures` |

## RiskFactorRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/RiskFactorRDA`
- Tipo: `RiskAssessment`; base: `http://hl7.org/fhir/StructureDefinition/RiskAssessment`
- Descripción: Perfil FHIR de un factor de riesgo identificado a un paciente durante un encuentro de atención en salud, para su intercambio en un documento RDA en Colombia.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `RiskAssessment.meta.profile` | 1..* | canonical(StructureDefinition) | si `RiskAssessment.meta` |
| `RiskAssessment.status` | 1..1 | code |  |
| `RiskAssessment.code` | 1..1 | CodeableConcept |  |
| `RiskAssessment.code.coding` | 1..1 | Coding |  |
| `RiskAssessment.code.coding.system` | 1..1 | uri |  |
| `RiskAssessment.code.coding.code` | 1..1 | code |  |
| `RiskAssessment.code.coding.display` | 1..1 | string |  |
| `RiskAssessment.code.text` | 1..1 | string |  |
| `RiskAssessment.subject` | 1..1 | Reference(PatientRDA) |  |
| `RiskAssessment.encounter` | 1..1 | Reference(EncounterAmbulatoryRDA, EncounterEmergencyRDA, EncounterHospitalizationRDA) |  |

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `RiskAssessment.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/RiskFactorRDA"` |
| `RiskAssessment.status` | `fixedCode` | `"registered"` |
| `RiskAssessment.code.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/FactorRiesgo"` |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `RiskAssessment.code.coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/FactorRiesgoCodigos` |

## ServiceRequestRDA

- URL: `https://fhir.minsalud.gov.co/rda/StructureDefinition/ServiceRequestRDA`
- Tipo: `ServiceRequest`; base: `http://hl7.org/fhir/StructureDefinition/ServiceRequest`
- Descripción: Perfil FHIR para registrar un procedimiento o servicio (tecnología en salud - CUPS) ordenado a un paciente durante un encuentro de atención en salud, para su intercambio en un documento RDA en Colombia.

### Obligatorios (min ≥ 1)

Condicional: obligatorio solo si existe el ancestro opcional indicado.

| Elemento | Card. | Tipo | Condicional |
| --- | --- | --- | --- |
| `ServiceRequest.meta.profile` | 1..* | canonical(StructureDefinition) | si `ServiceRequest.meta` |
| `ServiceRequest.status` | 1..1 | code |  |
| `ServiceRequest.intent` | 1..1 | code |  |
| `ServiceRequest.category` | 1..1 | CodeableConcept |  |
| `ServiceRequest.category.coding:R866.system` | 1..1 | uri | si `ServiceRequest.category.coding:R866` |
| `ServiceRequest.category.coding:R866.code` | 1..1 | code | si `ServiceRequest.category.coding:R866` |
| `ServiceRequest.category.coding:R866.display` | 1..1 | string | si `ServiceRequest.category.coding:R866` |
| `ServiceRequest.code` | 1..1 | CodeableConcept |  |
| `ServiceRequest.code.coding.system` | 1..1 | uri | si `ServiceRequest.code.coding` |
| `ServiceRequest.code.coding.code` | 1..1 | code | si `ServiceRequest.code.coding` |
| `ServiceRequest.code.coding.display` | 1..1 | string | si `ServiceRequest.code.coding` |
| `ServiceRequest.subject` | 1..1 | Reference(PatientRDA) |  |
| `ServiceRequest.authoredOn` | 1..1 | dateTime |  |
| `ServiceRequest.reasonCode` | 1..1 | CodeableConcept |  |
| `ServiceRequest.reasonCode.coding.system` | 1..1 | uri | si `ServiceRequest.reasonCode.coding` |
| `ServiceRequest.reasonCode.coding.code` | 1..1 | code | si `ServiceRequest.reasonCode.coding` |
| `ServiceRequest.reasonCode.coding.display` | 1..1 | string | si `ServiceRequest.reasonCode.coding` |

### Must-support opcionales

`ServiceRequest.encounter` 0..1

### Valores fijos y patrones

| Elemento | Clave | Valor |
| --- | --- | --- |
| `ServiceRequest.meta.profile` | `fixedCanonical` | `"https://fhir.minsalud.gov.co/rda/StructureDefinition/ServiceRequestRDA"` |
| `ServiceRequest.status` | `fixedCode` | `"active"` |
| `ServiceRequest.intent` | `fixedCode` | `"order"` |
| `ServiceRequest.category.coding:R866.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianHealthTechnologyCategory"` |
| `ServiceRequest.category.coding:R866.code` | `fixedCode` | `"01"` |
| `ServiceRequest.category.coding:R866.display` | `fixedString` | `"Procedimiento en salud"` |
| `ServiceRequest.code.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/CUPS"` |
| `ServiceRequest.reasonCode.coding.system` | `fixedUri` | `"https://fhir.minsalud.gov.co/rda/CodeSystem/RIPSFinalidadConsultaVersion2"` |

### Slices

| Elemento | Discriminador | Reglas | Slices |
| --- | --- | --- | --- |
| `ServiceRequest.category.coding` | value:system | closed | `R866` 0..1 Coding |

### Bindings `required` de la guía

| Elemento | ValueSet |
| --- | --- |
| `ServiceRequest.category.coding:R866` | `https://fhir.minsalud.gov.co/rda/ValueSet/ColombianHealthTechnologyCodes` |
| `ServiceRequest.code.coding` | `https://fhir.minsalud.gov.co/rda/ValueSet/CUPSProcedureCodes` |
| `ServiceRequest.reasonCode` | `https://fhir.minsalud.gov.co/rda/ValueSet/RIPSFinalidadConsultaVersion2Codigos` |

## Extensiones

| Id | URL | Contexto | value[x] |
| --- | --- | --- | --- |
| ExtensionAddress | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionAddress` | MedicationRequest, MedicationAdministration, MedicationDispense | Address 1..1 |
| ExtensionBiologicalGender | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionBiologicalGender` | Patient | Coding 1..1 |
| ExtensionBirthPlace | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionBirthPlace` | Patient | Address 1..1 |
| ExtensionBirthTime | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionBirthTime` | Patient.birthDate | time 1..1 |
| ExtensionColombianGenderGroup | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionGenderGroup` | Patient.gender | code 1..1 |
| ExtensionContentSignatureRDA | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionContentSignatureRDA` | DocumentReference | base64Binary | boolean | canonical | code | date | dateTime | decimal | id | instant | integer | markdown | oid | positiveInt | string | time | unsignedInt | uri | url | uuid | Address | Age | Annotation | Attachment | CodeableConcept | Coding | ContactPoint | Count | Distance | Duration | HumanName | Identifier | Money | Period | Quantity | Range | Ratio | Reference | SampledData | Signature | Timing | ContactDetail | Contributor | DataRequirement | Expression | ParameterDefinition | RelatedArtifact | TriggerDefinition | UsageContext | Dosage | Meta 0..0 |
| ExtensionCountryCode | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionCountryCode` | Address.country | Coding 1..1 |
| ExtensionDeliveryNumber | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionDeliveryNumber` | MedicationRequest, MedicationDispense | positiveInt 1..1 |
| ExtensionDiagnosisType | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionDiagnosisType` | Procedure | Coding 1..1 |
| ExtensionDischargeDeceasedStatus | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionDischargeDeceasedStatus` | Encounter.hospitalization | Coding 1..1 |
| ExtensionDischargeDisposition | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionDischargeDisposition` | Encounter | base64Binary | boolean | canonical | code | date | dateTime | decimal | id | instant | integer | markdown | oid | positiveInt | string | time | unsignedInt | uri | url | uuid | Address | Age | Annotation | Attachment | CodeableConcept | Coding | ContactPoint | Count | Distance | Duration | HumanName | Identifier | Money | Period | Quantity | Range | Ratio | Reference | SampledData | Signature | Timing | ContactDetail | Contributor | DataRequirement | Expression | ParameterDefinition | RelatedArtifact | TriggerDefinition | UsageContext | Dosage | Meta 0..0 |
| ExtensionDivipolaDepartment | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionDivipolaDepartment` | Address.state | Coding 1..1 |
| ExtensionDivipolaMunicipality | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionDivipolaMunicipality` | Address.city | Coding 1..1 |
| ExtensionDoseQuantity | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionDoseQuantity` | MedicationRequest, MedicationAdministration | Quantity(SimpleQuantity) 1..1 |
| ExtensionFathersFamilyName | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionFathersFamilyName` | HumanName.family | string 1..1 |
| ExtensionMedicationDispenseQuantity | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionMedicationDispenseQuantity` | MedicationRequest, MedicationDispense | Quantity(SimpleQuantity) 1..1 |
| ExtensionMedicationQuantity | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionMedicationQuantity` | MedicationRequest, MedicationAdministration | Quantity(SimpleQuantity) 1..1 |
| ExtensionMothersFamilyName | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionMothersFamilyName` | HumanName.family | string 1..1 |
| ExtensionPatientDisability | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionPatientDisability` | Patient | Coding 1..1 |
| ExtensionPatientEthnicCommunity | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionPatientEthnicCommunity` | Patient | string 1..1 |
| ExtensionPatientEthnicity | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionPatientEthnicity` | Patient | Coding 1..1 |
| ExtensionPatientGenderIdentity | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionPatientGenderIdentity` | Patient | Coding 1..1 |
| ExtensionPatientNationality | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionPatientNationality` | Patient, Person | Coding 1..1 |
| ExtensionPharmacyLocation | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionPharmacyLocation` | MedicationRequest, MedicationDispense | Reference(PharmacyLocation) 1..1 |
| ExtensionRequestDate | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionRequestDate` | Procedure, ServiceRequest, MedicationRequest, MedicationAdministration | date 1..1 |
| ExtensionResidenceZone | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionResidenceZone` | Patient.address | Coding 1..1 |
| ExtensionSurgicalMethod | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionSurgicalMethod` | Procedure | Coding 1..1 |
| ExtensionTelecomPhone | `https://fhir.minsalud.gov.co/rda/StructureDefinition/ExtensionTelecomPhone` | MedicationRequest, MedicationAdministration, MedicationDispense | ContactPoint 1..1 |

## CodeSystems

`content = fragment`: la guía no trae el catálogo completo; los códigos que falten se cargan por sincronización (`GET /CodeSystem/{id}`) o por importación de las tablas SISPRO.

| Id | URL (`system`) | content | Conceptos |
| --- | --- | --- | --- |
| CIUO88AC | `https://fhir.minsalud.gov.co/rda/CodeSystem/CIUO88AC` | complete | 562 |
| CUMS | `https://fhir.minsalud.gov.co/rda/CodeSystem/CUMS` | fragment | 178 |
| CUPS | `https://fhir.minsalud.gov.co/rda/CodeSystem/CUPS` | fragment | 434 |
| ClaseTriage | `https://fhir.minsalud.gov.co/rda/CodeSystem/ClaseTriage` | complete | 5 |
| ColombianDiagnosisRole | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDiagnosisRole` | complete | 6 |
| ColombianDisabilityClassification | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDisabilityClassification` | complete | 8 |
| ColombianDischargeDeceasedStatus | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDischargeDeceasedStatus` | complete | 2 |
| ColombianDocumentTypes | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianDocumentTypes` | complete | 15 |
| ColombianEthnicGroup | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianEthnicGroup` | complete | 7 |
| ColombianGenderGroup | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianGenderGroup` | complete | 3 |
| ColombianGenderIdentity | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianGenderIdentity` | complete | 5 |
| ColombianHealthTechnologyCategory | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianHealthTechnologyCategory` | complete | 13 |
| ColombianHealthcareLevel | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianHealthcareLevel` | complete | 4 |
| ColombianLegalNatureType | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianLegalNatureType` | complete | 4 |
| ColombianLicenseScope | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianLicenseScope` | complete | 2 |
| ColombianOrganizationIdentifiers | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianOrganizationIdentifiers` | complete | 3 |
| ColombianPersonIdentifier | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianPersonIdentifier` | complete | 21 |
| ColombianProviderClass | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianProviderClass` | complete | 5 |
| ColombianResidenceZone | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianResidenceZone` | complete | 2 |
| ColombianSurgicalMethod | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianSurgicalMethod` | complete | 5 |
| ColombianTechModality | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianTechModality` | complete | 9 |
| CondicionyDestinoUsuarioEgreso | `https://fhir.minsalud.gov.co/rda/CodeSystem/CondicionyDestinoUsuarioEgreso` | complete | 8 |
| DIVIPOLA | `https://fhir.minsalud.gov.co/rda/CodeSystem/DIVIPOLA` | complete | 1154 |
| EntornoAtencion | `https://fhir.minsalud.gov.co/rda/CodeSystem/EntornoAtencion` | complete | 5 |
| FactorRiesgo | `https://fhir.minsalud.gov.co/rda/CodeSystem/FactorRiesgo` | complete | 6 |
| FormaFarmaceutica | `https://fhir.minsalud.gov.co/rda/CodeSystem/FormaFarmaceutica` | complete | 61 |
| GrupoServicios | `https://fhir.minsalud.gov.co/rda/CodeSystem/GrupoServicios` | complete | 5 |
| ICD10CO | `http://hl7.org/fhir/sid/icd-10` | fragment | 395 |
| ICD11CO | `http://hl7.org/fhir/sid/icd-11` | fragment | 1004 |
| ISO31661 | `https://fhir.minsalud.gov.co/rda/CodeSystem/ISO31661` | complete | 750 |
| IUM | `https://fhir.minsalud.gov.co/rda/CodeSystem/IUM` | fragment | 71 |
| IUMPrimerNivel | `https://fhir.minsalud.gov.co/rda/CodeSystem/IUMPrimerNivel` | fragment | 83 |
| MedicationDispensePerformerFunction | `https://fhir.minsalud.gov.co/rda/CodeSystem/MedicationDispensePerformerFunction` | complete | 2 |
| MedicationTime | `https://fhir.minsalud.gov.co/rda/CodeSystem/MedicationTime` | complete | 7 |
| MemoryDisorder | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianMemoryDisorder` | complete | 3 |
| MipresAmbitosAtencion | `https://fhir.minsalud.gov.co/rda/CodeSystem/MipresAmbitosAtencion` | complete | 5 |
| MipresCausasNoDireccionamiento | `https://fhir.minsalud.gov.co/rda/CodeSystem/MipresCausasNoDireccionamiento` | complete | 13 |
| MipresCausasNoDispensacion | `https://fhir.minsalud.gov.co/rda/CodeSystem/MipresCausasNoDispensacion` | complete | 15 |
| MipresDispenseUnit | `https://fhir.minsalud.gov.co/rda/CodeSystem/MipresDispenseUnit` | complete | 73 |
| MipresDoseForm | `https://fhir.minsalud.gov.co/rda/CodeSystem/MipresDoseForm` | complete | 39 |
| MipresINN | `https://fhir.minsalud.gov.co/rda/CodeSystem/MipresINN` | fragment | 71 |
| MipresOrphanDiseases | `https://fhir.minsalud.gov.co/rda/CodeSystem/MipresOrphanDiseases` | complete | 2237 |
| MipresSpecialInstruction | `https://fhir.minsalud.gov.co/rda/CodeSystem/MipresSpecialInstruction` | complete | 10 |
| ParentescoAntecedente | `https://fhir.minsalud.gov.co/rda/CodeSystem/ParentescoAntecedente` | complete | 4 |
| PharmacySupplyType | `https://fhir.minsalud.gov.co/rda/CodeSystem/PharmacySupplyType` | complete | 4 |
| REPShealthcareServices | `https://fhir.minsalud.gov.co/rda/CodeSystem/REPShealthcareServices` | complete | 157 |
| RETHUSqualification | `https://fhir.minsalud.gov.co/rda/CodeSystem/RETHUSqualification` | complete | 289 |
| RIPSCausaExternaVersion2 | `https://fhir.minsalud.gov.co/rda/CodeSystem/RIPSCausaExternaVersion2` | complete | 29 |
| RIPSFinalidadConsultaVersion2 | `https://fhir.minsalud.gov.co/rda/CodeSystem/RIPSFinalidadConsultaVersion2` | complete | 34 |
| RIPSMedicationAdminCategory | `https://fhir.minsalud.gov.co/rda/CodeSystem/RIPSMedicationAdminCategory` | complete | 2 |
| RIPSTipoDiagnosticoPrincipalVersion2 | `https://fhir.minsalud.gov.co/rda/CodeSystem/RIPSTipoDiagnosticoPrincipalVersion2` | complete | 3 |
| RetroactiveReason | `https://fhir.minsalud.gov.co/rda/CodeSystem/ColombianRetroactiveReason` | complete | 3 |
| TipoAlergia | `https://fhir.minsalud.gov.co/rda/CodeSystem/TipoAlergia` | complete | 6 |
| UMM | `https://fhir.minsalud.gov.co/rda/CodeSystem/UMM` | complete | 273 |
| VAD | `https://fhir.minsalud.gov.co/rda/CodeSystem/VAD` | complete | 119 |
| ViaIngreso | `https://fhir.minsalud.gov.co/rda/CodeSystem/ViaIngreso` | complete | 14 |
| allergyintolerance-clinical | `http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical` | complete | 3 |
| list-empty-reason | `http://terminology.hl7.org/CodeSystem/list-empty-reason` | complete | 6 |
