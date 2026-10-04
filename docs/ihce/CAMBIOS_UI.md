# Cambios de interfaz del módulo IHCE/RDA (regla 10)

Inventario de **todo** campo, botón y aviso añadido para el RDA. Criterios aplicados:

- Solo lo necesario para que el RDA de consulta externa sea válido frente a los perfiles fijados en `vendor/fhir/VERSIONS.lock` ([MATRIZ_RDA.md](MATRIZ_RDA.md), vía **(3)**), más las credenciales y la línea de estado que exige el envío.
- Los mismos componentes de la app (`CampoTexto`, `CampoDesplegable`, `FilaCampos`, `Aviso`, `FilledButton`, `TextButton`), sin temas, estilos, colores, tipografías ni librerías de UI nuevas.
- Con `IHCE_ENABLED=false` (por defecto) **ningún** widget del módulo muestra nada: cada uno devuelve `SizedBox.shrink()` (prueba T23, «con IHCE_ENABLED=false los campos no aparecen»).
- **Ningún campo nuevo es obligatorio ni bloquea el guardado** de la historia ni de los datos del médico: ningún `CampoTexto` del módulo usa `requerido`. Un dato faltante solo deja el RDA en `INVALIDO_LOCAL` con su motivo (la atención se guarda igual).
- Toda la lógica está en la capa de servicios/estado (`lib/features/ihce/ihce_provider.dart`, `lib/core/ihce/`); los widgets solo leen y escriben providers.

La comprobación automática está en `tool/ihce/regla10.dart` (paso 5 de `tool/ihce/verificar.sh`): sin dependencias de UI nuevas, sin cambios en archivos de tema o estilo y todo archivo de presentación tocado listado aquí.

## 1. Archivos de presentación tocados

| Archivo | Cambio | Líneas |
| --- | --- | --- |
| `lib/features/ihce/campos_ihce.dart` | **Nuevo.** Widgets del módulo (secciones 2–4) | — |
| `lib/features/ihce/ihce_provider.dart` | **Nuevo.** Providers (configuración, secretos, servicio, estado del RDA, catálogo); sin widgets | — |
| `lib/features/medico/medico_page.dart` | Import + `const CamposIhceProfesional()` en «Datos profesionales» + `const CamposIhcePrestador()` en «Consultorio» | `:139`, `:195` |
| `lib/features/historia/secciones/formulario_paciente.dart` | Import + `const CampoCausaExterna()` tras los datos de la atención + `const CamposIhcePaciente()` al final de «Datos del paciente» | `:87`, `:225` |
| `lib/features/historia/secciones/formularios_clinicos.dart` | Import + `TiposAlergiaIhce(antecedentes: a)` bajo las alergias | `:199` |
| `lib/features/historia/historia_page.dart` | Import + `AvisoRdaAtencion(...)` en la historia abierta, junto a los avisos existentes | `:501–502` |
| `lib/features/historia/estado/historia_controller.dart` | **Punto de enganche** (capa de estado, sin UI): `procesarPendientes()` al iniciar y `alCerrarAtencion(...)` tras guardar; ambos `unawaited`, con el servicio `null` si el módulo está apagado | `:52`, `:170–181` |
| `lib/core/widgets/campos.dart` | `CampoTexto` gana dos parámetros opcionales con valor por defecto que no cambian nada para los usos existentes: `oculto` (`obscureText`, sin sugerencias ni autocorrección; para secretos) y `validador` (validación propia, mostrada al escribir con el mismo mecanismo que `requerido`). Sin cambios visuales | — |

Archivos de tema y estilo **sin cambios** frente al commit base (`ecc16a4`): `lib/app/tema.dart`, `lib/core/pdf/fuentes_pdf.dart`, `web/`, `assets/fonts/`. Dependencias nuevas: `cryptography`, `flutter_secure_storage`, `http`, `json_schema`; ninguna es de UI (justificación en [README.md](README.md#dependencias)).

## 2. Pantalla «Datos del médico» (`medico_page.dart`)

### «Datos profesionales» — `CamposIhceProfesional`

| Campo | Componente | Elemento FHIR / justificación |
| --- | --- | --- |
| Tipo de documento | `CampoDesplegable` (tabla `perfilColombia.tiposDocumento` de la app) | `Practitioner.identifier.type` (slice `NationalPersonIdentifier`, 1..1). El número ya existía |
| Primer apellido | `CampoTexto` | `Practitioner.name.family` (1..1); el nombre de la app es un solo texto y no se puede partir sin adivinar |
| Segundo apellido | `CampoTexto` | extensión de segundo apellido de `name.family` (opcional; se envía si existe) |
| Nombres | `CampoTexto` | `Practitioner.name.given` (1..*) |
| Profesión (código RETHUS) | `CampoTexto` con validación contra el catálogo y nombre del código como ayuda | `Practitioner.qualification:Rethus` (1..1) |

### «Consultorio» — `CamposIhcePrestador`

| Campo | Componente | Elemento FHIR / justificación |
| --- | --- | --- |
| Código de habilitación (REPS) | `CampoTexto` | `Composition.custodian`, `Encounter.serviceProvider`, `DocumentReference.author` → `Organization` de la IPS por código REPS (Manual §5.3 c) |
| Modalidad de la atención | `CampoDesplegable` (ValueSet de la guía) | `Encounter.type:encounterModality` (1..1) |
| Entorno de la atención | `CampoDesplegable` (ValueSet de la guía) | `Encounter.type:encounterEnvironment` (1..1) |
| CUPS consulta de primera vez / de control / interconsulta | `CampoTexto` ×3 | `Encounter.serviceType` (CUPS de la consulta, ValueSet `CUPSConsultationCodes`); la app solo guarda el *tipo* de consulta y el CUPS depende del prestador |

Se guarda solo en el navegador (`hc.ihce.prestador.v1`), como el resto de la configuración del consultorio.

### Credenciales — `CredencialesMinSalud` (dentro de «Consultorio»)

| Campo / botón | Componente | Justificación |
| --- | --- | --- |
| **ClientID de MinSalud** | `CampoTexto` | OAuth 2.0 `client_credentials` (variable `clientid` de la colección Postman v1.5) |
| **ClientSecret de MinSalud** | `CampoTexto(oculto: true)` | variable `clientsecret` de la colección |
| Clave de suscripción de MinSalud | `CampoTexto(oculto: true)` | cabecera `Ocp-Apim-Subscription-Key` presente en las 21 peticiones al API de la colección (variable `APIMsubsKey`). Sin ella el API no se puede invocar desde la app. Opcional en el código: si no se escribe, la cabecera no se envía |
| Guardar credenciales | `FilledButton` | escribe **solo** en `AlmacenSecretos` (`flutter_secure_storage`) por ambiente y limpia los campos; nada en preferencias, estado o logs (T22, T23) |
| «MinSalud rechazó las credenciales…» | texto de error con el color de error existente | solo si algún documento quedó en `ERROR_AUTH` |

Al reabrir la pantalla los secretos **no** se muestran: el ClientID y el secreto se escriben de nuevo para reemplazarlos y la ayuda dice «Guardado…» / «Configurado».

## 3. Historia clínica

| Pantalla / sección | Campo | Componente | Elemento FHIR / justificación |
| --- | --- | --- | --- |
| Datos de la atención (`formulario_paciente.dart:87`) | Causa externa | `CampoDesplegable` (ValueSet `RIPSCausaExternaVersion2`) | `Encounter.reasonCode` (causa externa RIPS, Anexo Técnico 1) |
| Datos del paciente (`formulario_paciente.dart:225`) | Nacionalidad (código país), País de residencia (código) | `CampoTexto` con validación contra ISO 3166-1 numérico y nombre como ayuda | nacionalidad: extensión de `PatientRDA`; país de residencia: extensión de `Patient.address.country` (1..1) |
| ídem | Pertenencia étnica, Discapacidad, Zona de residencia | `CampoDesplegable` ×3 (ValueSets de la guía) | etnia y discapacidad: extensiones de `PatientRDA`; zona: extensión `ExtensionResidenceZone` de `Patient.address` (1..1) |
| Antecedentes (`formularios_clinicos.dart:199`) | «Tipo: ‹alergia›» por cada alergia registrada | `CampoDesplegable` (ValueSet de tipo de alergia de la guía) | `AllergyIntoleranceRDA.code` (1..1). Solo aparece si hay alergias y no se marcó «niega alergias». Sin tipo, la sección de alergias solo admite `emptyReason = nilknown` (fijo en el perfil), que con alergias registradas sería falso (D8) |

## 4. Línea de estado y reintento (`historia_page.dart:501–502`) — `AvisoRdaAtencion`

| Elemento | Componente | Cuándo aparece |
| --- | --- | --- |
| «El resumen (RDA) no se envió a MinSalud» + motivo en lenguaje llano | `Aviso` existente (icono y color de aviso existentes) | solo si el último documento de la atención está en `RECHAZADO`, `INVALIDO_LOCAL` o `AGOTADO` |
| Reintentar | `TextButton` | ídem; crea una nueva `version_doc` con el médico y el prestador vigentes (los datos clínicos sellados no cambian) |

Aceptado, en cola, en curso o sin transporte: no se muestra nada. El motivo nunca contiene el `OperationOutcome` crudo, rutas FHIR, códigos ni datos del paciente (T24).
