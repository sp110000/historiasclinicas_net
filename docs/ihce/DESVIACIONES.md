# Desviaciones, discrepancias y decisiones (IHCE/RDA)

Precedencia aplicada (regla 6): **estructura** → StructureDefinitions y terminologías de la guía fijada; **formato de transmisión** → colección Postman v1.5 → Manual de Operaciones v01.4 → narrativa de la guía; **obligaciones** → Anexo Técnico 1 de la Resolución 1888 de 2025; el requerimiento del propietario, al final. Versiones y huellas: `vendor/fhir/VERSIONS.lock`.

Cada discrepancia se resuelve en un único punto del código, conmutable por configuración (`config/ihce.env.example`).

## G1. Rama de trabajo y `push` (regla 1)

La regla 1 prohíbe `push`. La sesión de ejecución (Claude Code en la nube) asigna la rama `claude/new-session-04jvxz` y exige subir allí el trabajo porque el contenedor es efímero: sin `push` el trabajo se perdería. Se hizo `push` **solo** a esa rama de trabajo; nunca a `main`, sin `merge`, sin `--force`, sin reescritura de historia, sin despliegues. Commits atómicos por fase.

## D1. Prefijo `#` en las referencias

| Fuente | Forma |
| --- | --- |
| Manual §5.3 | `#Encounter-0`, `#CC-1234567890` |
| Colección Postman v1.5, los cuatro cuerpos `enviar-rda-*` | `#Tipo-n` / `#CC-…` en todas las referencias internas (194); la única sin `#` es la externa `Organization/MinSalud` |
| Ejemplo de la guía `Composition-74a4c2a5…` | sin `#` (`CC-80189301`, `Encounter-0`) |

**Resolución:** decide el cuerpo de envío de Postman → `IHCE_REFERENCE_STYLE=hash` (por defecto). `plain` queda disponible (`ReferenciasRda`, `lib/core/ihce/grafo/referencias.dart`).

**Efecto en la capa 2:** el validador estándar interpreta `#id` como recurso contenido (`ref-1`), no resuelve las referencias, considera inalcanzables las entradas y, en consecuencia, ninguna entrada que tenga referencias cumple su perfil de slice («a matching slice is required, but not found»). Todo eso se reproduce, con el mismo mensaje y en la ruta equivalente, en el cuerpo oficial `enviar-rda-consulta-externa` → 50 exclusiones de clase D1 en la línea base. La variante `plain` (opcional) no tiene evidencia oficial para sus hallazgos («Relative Reference appears inside Bundle whose entry is missing a fullUrl», «Found n matches…»): se valida y se reporta aparte (`build/ihce/validation-report-opcionales.json`, 58 errores) y **no** entra al gate. No se cambió el estilo por defecto para silenciar al validador.

## D2. `Encounter` dentro del Bundle

`BundleAmbulatoryRDA` cierra `entry` sin slice para `Encounter`, pero `Composition.encounter` es 1..1, el Manual lista el `Encounter` y **los tres cuerpos de Postman con atención (consulta, urgencias, hospitalización) lo incluyen como entrada** (el de resumen del paciente no tiene `Encounter`). **Resolución:** viaja como entrada (`IHCE_BUNDLE_ENCOUNTER_ENTRY=true`, por defecto). Con `false` el `Encounter` queda como referencia externa permitida (se validan ambas variantes: T18 y gate).

En la capa 2 el `Encounter` no genera un hallazgo propio: el slicing ya falla por D1 para todas las entradas (la entrada cae en el slice `ProcedureResources`, ver G-SLICE-RESOURCE).

## D3. `Bundle.identifier` en el envío

Los perfiles fijan `Bundle.identifier.system = https://fhir.minsalud.gov.co/rda/NamingSystem/identifier-RDA` (el VIDA, que solo existe tras la aceptación). **Los cuerpos de Postman no envían `identifier`.** **Resolución:** se omite (`IHCE_BUNDLE_IDENTIFIER=omitir`, por defecto); `uuid` emite un UUID v5 determinista de (tenant, atención, tipo, versión) (`uuidDeterminista`, `ensamblador.dart`). El hallazgo `bdl-9` del validador con `omitir` se reproduce en el cuerpo oficial (línea base, clase D3); con `uuid` desaparece.

## D4. Código de éxito

Aceptación = cualquier `2xx` cuyo cuerpo sea un `Bundle` (T01 parametrizada con 200 y 201). El VIDA se lee de `IHCE_VIDA_PATH` (por defecto `Bundle.identifier.value`) y se exige el `system` fijado por los perfiles; un `2xx` sin VIDA o con el eco del identificador enviado es `ACEPTADO_SIN_VIDA` con alerta (T10). `TODO(IHCE-VERIFICAR)`: la colección no trae respuestas de ejemplo; confirmar en sandbox.

## D5. Versionado de la guía

La guía declara `1.0.0` y cambia de compilación sin cambiar de número. Se fija por **huella SHA-256 de cada artefacto** y por compilación (`20260917200055`, último cambio `2026-08-31`) en `vendor/fhir/VERSIONS.lock`; `tool/ihce/fetch_fhir_tooling.sh` falla si la guía publicada cambia y obliga a `--actualizar`, regenerar `PERFILES_RDA.md` y repetir el gate.

## D6. `display` del CIE-10

El CodeSystem `http://hl7.org/fhir/sid/icd-10` de la guía es un `fragment` de 395 códigos con `display` en mayúsculas y minúsculas («Faringitis aguda, no especificada»); la tabla de referencia SISPRO que la app ya incluye (`assets/cie10/cie10_sispro.txt`) cubre todo el CIE-10 en mayúsculas («FARINGITIS AGUDA, NO ESPECIFICADA»). **Resolución:** `IHCE_DISPLAY_CIE10=sispro` (por defecto; cubre todos los códigos). `guia` usa el fragmento y bloquea los códigos que no estén en él. `TODO(IHCE-VERIFICAR)`: confirmar en sandbox contra qué `display` compara IHCE (un rechazo `code-invalid` marca el sistema para sincronizar, T06).

## D7. `attachment.contentType`

`DocumentReferenceEPIRDA` declara `content.attachment.contentType` **0..0**; el Manual §5.4.7 menciona `application/pdf` y la invariante `att-1` de FHIR R4 exige `contentType` cuando hay `data`. **Resolución:** manda la estructura (StructureDefinition): se omite y el tipo va en `content.format` (fijo del perfil). El hallazgo `att-1` se reproduce en el cuerpo oficial (línea base, clase D7). La matriz se corrigió en este sentido.

## D8. `emptyReason` fijo en las secciones de consulta

`CompositionAmbulatoryRDA` fija `emptyReason = nilknown` («nada conocido») en las secciones opcionales. **Resolución:** las secciones sin entradas codificadas van con `nilknown` y el texto estándar del Manual §5.4.3b; el texto libre que la historia tenga para esa sección (aseguradora, ocupación, hábitos, órdenes) se conserva en la narrativa `section.text`. Con alergias registradas **sin tipo codificado** el RDA se bloquea (`INVALIDO_LOCAL`): enviar `nilknown` afirmaría «sin alergias conocidas». Por eso existe el campo «Tipo» por alergia ([CAMBIOS_UI.md](CAMBIOS_UI.md)).

## Otras decisiones de formato de transmisión

| # | Tema | Fuente | Decisión |
| --- | --- | --- | --- |
| G2 | `Content-Type` del envío | Postman: cuerpo `raw` con lenguaje `json` (Postman envía `application/json`); FHIR R4 HTTP: `application/fhir+json` | `application/fhir+json` y `Accept: application/fhir+json`. `TODO(IHCE-VERIFICAR)` en sandbox |
| G3 | `grant_type` del token | Postman: `Client_Credentials`; RFC 6749 §4.4.2: `client_credentials` | `client_credentials` (valor del estándar) |
| G4 | Clave de suscripción | Postman: `Ocp-Apim-Subscription-Key` en las 21 peticiones al API (variable `APIMsubsKey`); el Manual de llaves no detalla en texto qué llaves entrega | campo oculto «Clave de suscripción de MinSalud»; la cabecera se omite si no hay clave. `TODO(IHCE-VERIFICAR)`: si es por ambiente o por prestador |
| G5 | `Composition.id` | Postman: sin `id` | sin `id` (nadie lo referencia) |
| G6 | `x-functions-key` | Postman la añade a `enviar-nota-aclaratoria` y `consultar-inmunizacion`; el Manual no la documenta | no se envía; esas operaciones son P1. `TODO(IHCE-VERIFICAR)` |
| G7 | Firma digital del Bundle | Anexo Técnico §3.2.1 la menciona; ni el Manual ni Postman definen el formato | puerto `Firmador` con `IHCE_SIGNING_MODE=off`. `TODO(IHCE-VERIFICAR)` |
| G8 | Dosis en `MedicationRequestRDA` | semántica de `doseAndRate:UMM.rate[x]` no explicada; Postman usa una cantidad con unidad `MedicationTime` | frecuencia como tasa por unidad de tiempo. Hoy no se emite (la app no captura medicamentos codificados). `TODO(IHCE-VERIFICAR)` |

## Línea base de la capa 2

Archivo versionado: [`validation-baseline.json`](validation-baseline.json), generado por `dart tool/ihce/linea_base.dart generar` y comprobado en cada corrida de `tool/ihce/verificar.sh` (`comparar`). Un hallazgo `error`/`fatal` se excluye **solo** si se reproduce, con el mismo mensaje y en la ruta equivalente, al validar con el mismo comando un artefacto oficial (los cuatro cuerpos de envío de Postman con su perfil `Bundle*RDA` y los 59 ejemplos de la guía), o si lo causa `-tx n/a`. La evidencia se recalcula en cada corrida: si un artefacto oficial deja de reproducir un hallazgo, la exclusión deja de valer.

Normalización para «mismo mensaje y ruta equivalente»: los índices de `entry` se reemplazan por el tipo de recurso de esa posición; los demás índices por `[*]`; se quitan los comentarios `/*Tipo/id*/` del validador y los identificadores de las referencias (`'#CC-123'` → `'<ref>'`). El resto del texto debe coincidir. Nota: el validador numera las entradas de «isn't reachable by traversing links» corridas en uno; ocurre igual en el cuerpo oficial.

| Clase | Exclusiones | Hallazgo | Causa | Evidencia |
| --- | --- | --- | --- | --- |
| D1 | 50 | `ref-1`, «Unable to resolve resource with reference», «fullUrl», «isn't reachable», slices requeridos no encontrados | referencias `#` de la colección (D1) | `postman-enviar-rda-consulta-externa.json` (48) y `Bundle-Output-ConsultarInmunizacion.json` de la guía (2) |
| D3 | 1 | `bdl-9` | sin `Bundle.identifier`, como Postman | cuerpo de consulta |
| D7 | 1 | `att-1` | `contentType` 0..0 en el perfil | cuerpo de consulta |
| G-CONTEXTO-EXTENSION | 3 | `ExtensionBiologicalGender` en `Patient.gender` y `ExtensionDiagnosisType` en `Encounter.diagnosis` «not allowed to be used at this point» | el contexto declarado de esas extensiones no incluye el elemento donde los propios perfiles las ponen (defecto de la guía) | cuerpo de consulta y ejemplos `Patient-…`, `Encounter-…` |
| G-FHIRPATH-TODATE | 1 | «The name toDate is not a known function name» en la invariante de `Encounter.period` | la invariante usa `toDate()`, que no existe en el FHIRPath de R4 (defecto de la guía) | cuerpo de consulta y ejemplos `Encounter-…`, `Composition-d8f12171…` |
| G-SLICE-PARTICIPANT | 1 | «Slicing cannot be evaluated… Encounter.participant:AttenderPhysician» | el discriminador es `value` sobre `type`, pero los valores fijos están en `type.coding.system/code/display`, no en `type` (defecto de la guía) | cuerpo de consulta y ejemplos `Encounter-…` |
| G-MINSALUD-REF | 1 | «Found n matches for 'Organization/MinSalud'» | `DocumentReference.custodian` fijado por el perfil a `Organization/MinSalud` | cuerpo de consulta |

Total en la última corrida: 5 Bundles del gate, 269 hallazgos `error`, 264 cubiertos por la línea base con evidencia vigente, 60 advertencias (listadas en `build/ihce/validation-report.json`).

### Hallazgo sin evidencia oficial: G-SLICE-RESOURCE (el gate queda en rojo)

`Bundle.entry[Practitioner]`: «Profile …/BundleAmbulatoryRDA|1.0.0, Element matches more than one slice - PractitionerResource, ProcedureResources» (1 por Bundle, 5 en total).

- **Causa:** en `StructureDefinition-BundleAmbulatoryRDA` el slice `Bundle.entry:ProcedureResources` declara `resource` de tipo `Resource` **sin perfil**, con discriminador `(type, profile)` sobre `resource`. Toda entrada que cumple su propio perfil coincide también con ese slice. El `Practitioner` generado cumple `PractitionerRDA`; las demás entradas no lo cumplen por D1, por eso solo él lo dispara. El slice debería ser `Procedure` / `ProcedureRDA` (defecto de la guía).
- **Por qué no se reproduce en los artefactos oficiales:** el `Practitioner` del cuerpo oficial de consulta **no cumple** `PractitionerRDA` (le faltan `active` y `qualification`, ambos 1..1), así que nunca coincide con su slice. Ningún cuerpo de Postman, ningún ejemplo de la guía y el reporte de calidad publicado de la guía (`qa.html`, 308 errores) contienen el mensaje.
- **Demostración (no es evidencia de línea base):** `tool/ihce/demostrar_slice.sh` toma el cuerpo oficial, le completa **solo** `active` y `qualification` del `Practitioner` y lo valida con el mismo comando: aparece exactamente el mismo mensaje en `Bundle.entry[3]` (el `Practitioner`).
- **Qué no se hizo:** no se quitó el `Practitioner` (la plataforma lo exige, 1..1) ni se degradó para que deje de cumplir su perfil.
- **Decisión del propietario:** reportarlo a MinSalud con la demostración y, si decide aceptarlo mientras tanto, agregarlo a `decisionesPropietario` en `validation-baseline.json` con `aprobadoPor`, `fecha` y `motivo` (la herramienta solo acepta entradas con los tres campos; `generar` nunca las crea).

## Defectos observados en artefactos oficiales (documentados, no corregidos)

- Capa 1 (JSON Schema FHIR R4): los 59 ejemplos de la guía pasan con cero errores (T20, `build/ihce/ejemplos-capa1.json`).
- Capa 2: 85 hallazgos `error` en los ejemplos de la guía (`build/ihce/oficiales/ejemplos.report.json`), entre ellos `Composition.text` presente con `max = 0` en `Composition-74a4c2a5…`, `Condition.verificationStatus` fuera del ValueSet requerido de R4, códigos inexistentes en `MipresDoseForm`, `RIPSFinalidadConsultaVersion2` y `ColombianRetroactiveReason`, y URLs `example.org` en identificadores.
- El reporte de calidad publicado de la guía declara 308 errores y 1 427 advertencias (IG Publisher 2.0.16).
