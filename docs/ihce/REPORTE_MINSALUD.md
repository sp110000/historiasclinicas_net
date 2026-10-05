# Reporte para la mesa de ayuda de IHCE (borrador, NO enviado)

> Borrador preparado el 2026-10-05 para que el propietario lo envíe por el canal oficial de soporte de IHCE. No contiene credenciales ni datos de pacientes: la demostración usa el cuerpo de ejemplo de la colección Postman oficial y datos sintéticos.

---

**Asunto:** Defecto en el perfil `BundleAmbulatoryRDA`: el slice `Bundle.entry:ProcedureResources` acepta cualquier recurso y hace fallar Bundles de consulta externa correctos

Buen día.

Al validar Bundles del RDA de consulta externa con el validador oficial de HL7 encontramos un defecto en el perfil `BundleAmbulatoryRDA` de la guía `minsalud.fhir.co.rda`. Bundles correctos quedan marcados con un error.

## 1. Versiones

| Artefacto | Versión |
| --- | --- |
| Guía `minsalud.fhir.co.rda` | 1.0.0 declarada; compilación `20260917200055` (último cambio 2026-08-31), publicada en https://vulcano.ihcecol.gov.co |
| `StructureDefinition-BundleAmbulatoryRDA.json` | `https://fhir.minsalud.gov.co/rda/StructureDefinition/BundleAmbulatoryRDA` 1.0.0 (SHA-256 `33d09b27331cdf71b1bb0238b72555f705fe487933ee1e8a356d51b6e15d16c5`) |
| Colección Postman | v1.5 «sandbox prestadores», petición `enviar-rda-consulta-externa` |
| Validador | HL7 FHIR Validator 6.10.4 (`validator_cli.jar`), FHIR 4.0.1 |

## 2. Qué pasa

En `BundleAmbulatoryRDA`, `Bundle.entry` tiene slicing cerrado con discriminadores `type` y `profile` sobre `resource`. El slice `Bundle.entry:ProcedureResources` declara:

```json
"id": "Bundle.entry:ProcedureResources.resource",
"type": [ { "code": "Resource" } ]
```

Es decir, **cualquier tipo de recurso y sin perfil**. Una entrada que cumple su propio perfil coincide entonces con dos slices: el suyo y `ProcedureResources`. El validador lo reporta como error:

```
Bundle.entry[3]: Profile https://fhir.minsalud.gov.co/rda/StructureDefinition/BundleAmbulatoryRDA|1.0.0,
Element matches more than one slice - PractitionerResource, ProcedureResources
```

En los otros perfiles de la guía el mismo slice está bien definido:

| Perfil | `Bundle.entry:ProcedureResources.resource` |
| --- | --- |
| `BundleEmergencyRDA` | `Procedure`, perfil `ProcedureRDA` |
| `BundleHospitalizationRDA` | `Procedure`, perfil `ProcedureRDA` |
| **`BundleAmbulatoryRDA`** | **`Resource`, sin perfil** |

## 3. Cómo reproducirlo

1. Tomar el cuerpo de la petición `enviar-rda-consulta-externa` de la colección Postman v1.5 (sin los comentarios `//`).
2. Completar **solo** los dos elementos que a su `Practitioner` le faltan frente a `PractitionerRDA`, ambos 1..1: `active: true` y una `qualification` del slice `Rethus`. No se cambia nada más.
3. Validar:

   ```bash
   java -jar validator_cli.jar postman-consulta-practitioner-completo.json \
     -version 4.0.1 -ig minsalud.fhir.co.rda -tx n/a \
     -profile https://fhir.minsalud.gov.co/rda/StructureDefinition/BundleAmbulatoryRDA
   ```

4. Resultado: aparece el error de la sección 2 en `Bundle.entry[3]`, el `Practitioner`. Con el cuerpo original no aparece, porque su `Practitioner` no cumple `PractitionerRDA` y por eso nunca coincide con su propio slice.

El script que hace estos pasos es `tool/ihce/demostrar_slice.sh` (repositorio del prestador; podemos enviarlo si lo necesitan).

## 4. Qué pedimos

1. Confirmar si es un defecto de la guía y corregirlo en `BundleAmbulatoryRDA`: definir `ProcedureResources.resource` como `Procedure` con perfil `ProcedureRDA` (como en urgencias y hospitalización) o retirar el slice si el RDA de consulta externa no admite procedimientos.
2. Confirmar si la validación del servidor de IHCE aplica este slicing y, si es así, cómo se comporta con un Bundle cuyo `Practitioner` cumple `PractitionerRDA`.
3. Indicar en qué compilación de la guía quedaría corregido.

## 5. Otras observaciones, por si les sirven

Encontradas con el mismo validador sobre el cuerpo oficial de Postman y los ejemplos de la guía:

- `ExtensionBiologicalGender` (en `Patient.gender`) y `ExtensionDiagnosisType` (en `Encounter.diagnosis`): «is not allowed to be used at this point». Su contexto declarado no incluye el elemento donde los perfiles las ponen.
- La invariante de `Encounter.period` en `EncounterAmbulatoryRDA` usa `toDate()`, que no existe en FHIRPath de R4: «The name toDate is not a known function name».
- `Encounter.participant:AttenderPhysician`: el discriminador es `value` sobre `type`, pero los valores fijos están en `type.coding`; el validador no puede evaluar el slicing.
- `DocumentReferenceEPIRDA` prohíbe `attachment.contentType` (0..0), mientras que el Manual de Operaciones §5.4.7 menciona `application/pdf` y la invariante `att-1` de FHIR R4 lo exige cuando hay `data`. ¿Cuál debemos seguir?

## 6. Pregunta adicional: datos registrados sin codificar

Las secciones de `CompositionAmbulatoryRDA` fijan `emptyReason = nilknown`. Cuando la atención tiene información que el software solo guarda como texto (ocupación, aseguradora, hábitos, órdenes, fórmula), enviar la sección vacía con «nada conocido» sería falso. Hoy no enviamos esos RDA. Dos preguntas:

1. ¿Cómo esperan recibir una sección con información no codificada? ¿Hay un `emptyReason` distinto de `nilknown` admisible, o alguna otra vía?
2. ¿Acepta la plataforma una entrada con el `coding.system` fijo y `coding.code`/`display` sin valor, solo con la extensión estándar `originalText` (patrón de datos faltantes de FHIR R4)? El validador de HL7 la acepta para `PatientOccupationAtEncounterRDA` y `RiskFactorRDA`.

Quedamos atentos.

---

*Datos de contacto y número de radicado: los completa el propietario al enviar.*
