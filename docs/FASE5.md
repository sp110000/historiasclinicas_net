# Fase 5: el sistema de tu consultorio

> **Estado: 5.0 «Cimientos» terminada, pendiente de tu visto bueno** (ver [«Avance»](#avance)). Plan aprobado el 21/11/2026 con las respuestas 1 a 9 por defecto. Rama `claude/fase5-consultorio`, PR abierto hacia `main`.
> Todo lo nuevo va detrás de la bandera **`CONSULTORIO_ENABLED`** (`--dart-define`, apagada por defecto). Con la bandera apagada, el sitio público se comporta exactamente como hoy, y hay pruebas que lo comprueban (ver 5.0).
> Todo lo normativo va marcado **VERIFICAR**: son referencias para orientar, no asesoría legal. La validación legal la haces tú, idealmente con un abogado y un contador.

**Para qué es:** convertir la app en el sistema de tu consultorio en Santander de Quilichao, con dos líneas (medicina general con programa de peso, y contorno corporal con hidrolipoclasia), sin servidor y sin software de terceros.

**En una frase:** un almacén local cifrado con tu frase de acceso guarda el índice de pacientes, la copia de trabajo de las historias y los datos de gestión (agenda, caja, inventario, fotos). El PDF sellado sigue siendo el registro clínico legal, y un respaldo cifrado obligatorio protege todo contra la pérdida del equipo.

**Qué necesito de ti para seguir:** el visto bueno de la 5.0 y, antes de la 5.1, las preguntas 10 a 16 (bloque «Pacientes»). Junto a cada pregunta pongo lo que haría por defecto; basta con que respondas «ok» a lo que te parezca bien.

---

## Decisiones confirmadas (21/11/2026)

| # | Tema | Decisión |
|---|---|---|
| 1 | Arquitectura | Aprobada con los ocho ajustes |
| 2 | Dónde corre | Otra dirección (subdominio), con la guía [fase5/PUBLICAR_CONSULTORIO.md](fase5/PUBLICAR_CONSULTORIO.md). No publico nada |
| 3 | Equipos | Portátil principal y celular secundario, con el paquete cifrado (5.2) |
| 4 | Frase y recuperación | Frase de 12 caracteres o más con medidor; código de recuperación de 24 caracteres con hoja PDF y confirmación de los últimos 4 |
| 5 | Derivación | PBKDF2-HMAC-SHA256 con 600.000 iteraciones; Argon2id se mide en tus equipos con «Medir la derivación» |
| 6 | Bloqueo | 10 minutos (de 2 a 60), «Bloquear ahora», llave descartada; borrador y receta cifrados con la bandera (llega en la 5.1, ver desviaciones) |
| 7 | Respaldo | Aviso a los 7 días; restaurar reemplaza todo. Ofrecer respaldo al cerrar la caja: en la 5.6 |
| 8 | Regla 10 | Acepta el inventario de este documento y la carpeta `lib/features/consultorio/` |
| 9 | Subfases | 5.0 «Cimientos» primero; el consentimiento informado pasa a la 5.3 |

---

## Avance

### 5.0 Cimientos ✅ (pendiente de tu visto bueno)

**Qué incluye**
- **Bandera `CONSULTORIO_ENABLED`** como constante (`lib/core/consultorio/config.dart`). Su único punto de entrada es `crearRouter()`, bajo `if (consultorioHabilitado)`.
- **Almacén cifrado propio** en IndexedDB (`historiasclinicas_consultorio`), con tres depósitos (`meta` en claro; `registros` y `binarios` cifrados) y escrituras atómicas en una transacción.
  - AES-256-GCM con AAD (colección e id). En el navegador, la llave se importa en WebCrypto como **no extraíble**.
  - Llave en sobre: la llave de datos se guarda envuelta con la frase (PBKDF2, 600.000 iteraciones) y con el código de recuperación.
  - Migraciones, candado entre pestañas (Web Locks), pedido de almacenamiento persistente y bitácora sin datos de pacientes.
  - **El código de IHCE no se tocó.**
- **Respaldo `.hcrespaldo`:** ZIP con manifiesto sellado.
  - Al importar se verifica la frase o el código, el sello del manifiesto, el SHA-256 de cada archivo, que cada registro se descifre con su AAD y los conteos.
  - Restaurar reemplaza todo, y si hay problemas solo restaura lo íntegro tras confirmar.
- **Interfaz:**
  - Riel lateral desde 1100 px (Historia y Ajustes por ahora) y menú lateral en pantallas angostas.
  - Crear la frase con medidor de fortaleza.
  - Código de recuperación mostrado una sola vez, con **hoja PDF para imprimir** y confirmación de los últimos 4 caracteres.
  - Desbloquear, recuperar con el código y bloqueo por inactividad.
  - Aviso de respaldo vencido con el texto de custodia.
  - **La historia, la receta y los datos del médico funcionan con el consultorio bloqueado.**
- **Ajustes:**
  - Seguridad: minutos de bloqueo, «Bloquear ahora», cambiar la frase, nuevo código de recuperación y «Medir la derivación».
  - Respaldo: respaldar, restaurar, días de aviso, espacio usado y almacenamiento persistente.
  - Bitácora.
- **Compilación:**
  - `./tool/construir_web.sh --salida DIR` permite compilar la versión del consultorio aparte.
  - `tool/consultorio/verificar_compilacion.dart` comprueba si el módulo quedó en `main.dart.js`.
  - Guía de publicación: [fase5/PUBLICAR_CONSULTORIO.md](fase5/PUBLICAR_CONSULTORIO.md).

**Verificación**

| Comprobación | Resultado |
|---|---|
| `dart format`, `flutter analyze` | Sin problemas |
| `flutter test` | **383 en verde** (eran 323: **+60**). 3 omitidas: las 2 que solo corren con la bandera encendida (la CI las corre en el job «consultorio») y 1 que ya existía |
| **Bandera apagada = sitio de hoy** | `main.dart.js` compilado **idéntico byte a byte** al de `main` (5.208 KB). Router con exactamente `/`, `/receta` y `/medico`. Menú «Más opciones» idéntico a 1920 y a 390 px. Nadie crea el servicio del consultorio. `pages.yml` sin la bandera. En la e2e de siempre no se crea la base del consultorio |
| Bandera encendida | `crearRouter()` usa el contenedor y las rutas del consultorio. El módulo pesa **+187 KB** en `main.dart.js` (5.395 KB) |
| Cifrado y respaldo | Vector conocido de PBKDF2; tildes compuestas o separadas dan la misma llave; un byte cambiado, otra AAD o un registro copiado sobre otra clave no se descifran; nada en claro en el almacén ni en el respaldo. Respaldo de ida y vuelta; se detectan el manifiesto modificado, archivos modificados, faltantes, sobrantes o intercambiados, el archivo ajeno o truncado y la versión nueva |
| e2e del consultorio en Chromium, **sin conexión y con la CSP** (`tool/e2e/consultorio_offline.mjs`) | **16 de 16 pasos.** Crear la frase, código y hoja PDF, base sin la frase ni el código en claro, medir la derivación, respaldar, bloquear, frase incorrecta, desbloquear, **otra pestaña no abre**, respaldo dañado y frase equivocada rechazados, restaurar, aviso de respaldo vencido tras recargar sin conexión, recuperar con el código, móvil y 320 px. 0 peticiones externas, 0 fallidas, 0 errores de consola |
| e2e de siempre (`historia_offline.mjs`, `pwa_offline.mjs`) | En verde, más el paso nuevo: sin la bandera no existe la base del consultorio |
| `tool/ihce/verificar.sh` | **En rojo por una causa externa a la Fase 5:** MinSalud recompiló la guía RDA (compilación `20261109215545`, del 09/11/2026), y el gate se detiene en el aprovisionamiento porque la huella ya no coincide con `vendor/fhir/VERSIONS.lock`. Lo mismo pasaría hoy en `main`. Las pruebas de IHCE (T01–T24 y capa 1) corren dentro de `flutter test` y pasan, y la regla 10 está en verde con el inventario de la Fase 5. Actualizar la guía (`--actualizar`, regenerar `PERFILES_RDA.md` y la línea base) es una tarea de IHCE aparte, que dejo propuesta |

**Derivación de la llave** (Chromium de este contenedor, 4 núcleos): PBKDF2-HMAC-SHA256 con 600.000 iteraciones, **unos 100 a 120 ms**; Argon2id con 19 MiB y 2 pasadas, **unos 1,1 a 1,2 s**. Argon2id es razonable en un escritorio, pero falta medirlo en tu Mac y en tu celular. Por ahora sigue PBKDF2. Los parámetros van guardados con la llave, así que cambiarlos después no rompe nada.

**Problemas encontrados y corregidos en la 5.0**
1. **La hoja de recuperación cortaba el último carácter del código** («TQP» en vez de «TQPV»): no cabía en una línea. Ahora va en dos líneas y se achica si hace falta. Una prueba lee el PDF con `pdftotext` y exige los 6 grupos; con la versión anterior falla.
2. **El riel y el aviso de respaldo no existían para los lectores de pantalla** sobre las pantallas con barra propia (historia, receta, médico). Cada pantalla vive en un `Navigator` anidado cuya barrera usa `BlockSemantics`, que oculta todo lo pintado antes. La pantalla va ahora en su propio contenedor semántico. Una prueba de accesibilidad lo vigila; sin el arreglo, falla.
3. **El aviso de respaldo salía sin el estilo del tema** (texto rojo con subrayado amarillo) y el motor intentaba descargar una fuente de respaldo, lo que **sin conexión fallaba**. Faltaba un `Material` alrededor del riel. Hay prueba.
4. El rótulo «CONSULTORIO» no cabía en el riel de 80 px y se quitó. El campo de la frase ya no toma el foco solo.

**Desviaciones del plan**
- **El borrador y la receta en curso cifrados (pregunta 6)** pasan a la 5.1. Allí se engancha la historia al índice, y es más seguro cambiar el borrador en el mismo paso. Hasta entonces quedan como hoy.
- **La historia no se tocó.** En vez de cambiar sus cortes a `LayoutBuilder`, el contenedor le pasa el ancho que queda a la derecha del riel (`MediaQuery`). El resultado es el mismo y no cambia ningún archivo de la historia.
- **El respaldo guarda un archivo por registro** en vez de «en lotes». Es más simple y permite informar cada problema por nombre.
- **La app abre en la historia** (`/`) y no en la agenda, porque la agenda llega en la 5.5.
- **Fuente de íconos del sitio público: +2 KB.** El recorte de íconos de Flutter ocurre antes de descartar el código, así que la fuente pública incluye unos pocos íconos del consultorio que nunca se muestran (18 → 20 KB). Es lo único del sitio público que cambia, junto con las huellas de `sw.js`. Al publicar, los navegadores descargan esa fuente y el `sw.js` nuevos.
- **Prueba local con Playwright 1.65:** en este contenedor, el Chromium instalado es de otra versión y lo enlacé fuera del repositorio. En la CI, Playwright instala el suyo.

**Evidencias (`docs/fase5/`)**
- **Escritorio (1440 px):**
  - [historia con el riel](fase5/escritorio_historia_con_riel.png)
  - [crear la frase](fase5/escritorio_crear_frase.png)
  - [código de recuperación](fase5/escritorio_codigo_recuperacion.png)
  - [Ajustes sin respaldo](fase5/escritorio_ajustes_sin_respaldo.png)
  - [bloqueado](fase5/escritorio_bloqueado.png)
  - [restaurar](fase5/escritorio_restaurar.png)
  - [aviso de respaldo vencido](fase5/escritorio_aviso_respaldo_vencido.png)
  - [recuperar con el código](fase5/escritorio_recuperar_con_codigo.png)
- **Móvil (390 px):** [Ajustes](fase5/movil_ajustes.png) · [menú](fase5/movil_menu.png) · [bloqueado](fase5/movil_bloqueado.png)
- **320 px:** [bloqueado](fase5/320_bloqueado.png) · [Ajustes](fase5/320_ajustes.png)
- **PDF:** [hoja de recuperación](fase5/pdf_hoja_recuperacion.png)

---

## 0. Lo que encontré antes de planificar

### Código

| Tema | Hallazgo | Consecuencia |
|---|---|---|
| Almacén de IHCE (`lib/core/ihce/almacen/`) | `AlmacenKv` guarda solo texto (`String → String`). La implementación web tiene fijos el nombre de la base (`historiasclinicas_ihce`) y del almacén (`kv`). No tiene transacciones de varias claves ni datos binarios. `claves()` lee todas las claves y filtra en Dart. Nada pide `navigator.storage.persist()` | El consultorio tiene **su propio almacén** en `lib/core/consultorio/almacen/`, con el mismo estilo de contrato (`leer`, `escribir`, `borrar`, `claves`) más lo que falta: bytes (las fotos se guardan como `Uint8Array`, sin base64), tres almacenes (`meta`, `registros`, `binarios`) y escritura atómica de varias claves en una transacción. Reutilizo el respaldo en memoria para las pruebas y el patrón de migraciones. **El código de IHCE no se toca** |
| `RepositorioIhce` | Es específico de IHCE (tipos del RDA). Los índices y los únicos viven en memoria y se reconstruyen al abrir. El único se comprueba antes de escribir, con un `await` en medio, así que dos escrituras simultáneas pueden saltárselo. Los metadatos del documento se guardan en claro | Para el consultorio hago una **colección genérica** (`Coleccion<T>`): registro completo cifrado, índices en memoria declarados, escrituras en serie (una cola) y un candado entre pestañas (`navigator.locks`) |
| Cifrado (`cifrador.dart`) | AES-256-GCM con WebCrypto, sobre JSON `{"v":1,"n","c","m"}`, sin datos asociados (AAD). La llave es aleatoria y se guarda en `flutter_secure_storage`. En la web, ese almacén guarda la llave que envuelve **junto a los datos**, en `localStorage` (oculta, no protege). Además, si la lectura falla devuelve `null`, y el cifrador genera una llave nueva que **sobrescribe la anterior en silencio** | El consultorio **no** usa `flutter_secure_storage`. La llave sale de tu frase de acceso y solo vive en memoria mientras está desbloqueado (ver «Decisión de arquitectura»). Reutilizo AES-256-GCM de `cryptography`, con AAD. El defecto de IHCE lo dejo anotado como tarea aparte |
| Derivar la llave de la frase | `cryptography` 2.9.0 trae **PBKDF2-HMAC-SHA256**, que en la web usa WebCrypto nativo (unos 0,2 a 1 s con 600.000 iteraciones). **Argon2id** está escrito en Dart puro: en el navegador corre en el hilo principal y podría tardar de 2 a 6 s en escritorio y más de 10 s en un celular modesto (estimado, sin medir) | Por defecto, PBKDF2 con 600.000 iteraciones (cifra recomendada por OWASP en 2023, **VERIFICAR** la vigente). En la 5.0 mido Argon2id en tu Mac y en tu celular. Si tarda menos de 2 s, lo propongo. Los parámetros quedan guardados junto a la llave envuelta, así que cambiarlos después no rompe nada (pregunta 5) |
| `historia.json` | No hay identificador del paciente: la clave natural es tipo + número de documento. La historia tiene `id` (UUID) y `revision`. **`proximoControl` existe solo en el plan de la historia inicial; las evoluciones no lo tienen.** El editor de evoluciones no pide talla ni perímetro abdominal | El índice identifica al paciente por documento normalizado (con unión manual de fichas duplicadas). El indicador de controles vencidos usa `plan.proximoControl` más las citas de la agenda (pregunta 15) |
| Momento de sellar | `HistoriaController.guardado()` corre al finalizar la historia (revisión 1) y al descargarla con evoluciones nuevas (revisión > 1). IHCE ya se engancha ahí sin esperar el resultado y sin lanzar errores | El índice se actualiza en ese mismo punto, con el mismo patrón y detrás de la bandera. Hace falta pasarle también los bytes del PDF, para guardar su huella |
| Leer un PDF de la app | `leerHistoriaDePdf` es Dart puro y síncrono, sin interfaz. Verifica el sobre, y `verificarIntegridad` verifica la cadena (alterada desde la evolución *n*) y las imágenes. Los selectores de archivo abren uno solo | La importación en lote es viable: un archivo a la vez, cediendo el hilo entre archivos. Hace falta un selector de varios archivos y soltar varios a la vez |
| Recetas | **El PDF de la receta no lleva datos incrustados.** La app guarda solo la receta en curso, y el contador es de cada navegador. La única huella de una receta vieja es el texto «Se formuló (R-…)» sellado en la historia | Las recetas viejas no se pueden importar como documentos; se listan desde ese texto. Con la bandera encendida, las recetas nuevas llevan `receta.json` incrustado y se registran en el índice. Con la bandera apagada, la receta no cambia (pregunta 14) |
| Piezas de PDF | `datosMedicoPdf`, `bloqueFirmaPdf` e `ImagenesPdf` son reutilizables. La ficha del paciente, la cabecera de sección y el encabezado de página son funciones internas de cada generador. `pdf` 3.12 trae gráficas (`pw.Chart`) | Se extraen a `piezas_pdf.dart` sin cambiar el resultado. Las pruebas de PDF de hoy solo comprueban la estructura (adjunto, revisión, imágenes, A4), así que **antes** de extraer agrego una prueba de regresión que compara el texto y su posición en cada página. Las gráficas del informe se hacen sin dependencias nuevas |
| Antecedentes y alergias en el tiempo | Las evoluciones solo tienen texto, signos vitales y autor. Una alergia descubierta después de la historia inicial no queda en ningún campo | La ficha muestra los antecedentes y las alergias de la historia inicial. Para actualizarlos, propongo «Actualizar alergias» en la ficha, que deja la línea sellada en la evolución en curso (pregunta 13) |
| Firma en pantalla | `LienzoFirma` exporta un PNG transparente y recortado. `DialogoFirma` está dentro de `medico_page.dart`, con los textos del médico fijos | Se generaliza (título y textos) y pasa a `lib/core/widgets/`, para la firma del paciente |
| Prellenar la historia | No hay forma hoy: `HistoriaPage` no recibe datos, y la receta toma el paciente de la historia en curso | Nuevo `HistoriaController.nuevaDesdePaciente(...)`, que debe subir `versionFormulario` (si no, los campos no se refrescan). La receta se prellena cargando antes al paciente en la historia |
| Navegación | `go_router` plano con 3 rutas (`/`, `/receta`, `/medico`), sin contenedor común. Las páginas tienen su propia barra. Cortes de ancho: 700 (móvil), 1100 y 1180 | Con la bandera encendida, un contenedor (`ShellRoute`) agrega la navegación del consultorio. Con la bandera apagada, el router es idéntico al de hoy. La historia calcula sus cortes con el ancho de la **ventana** (`MediaQuery`), así que con un riel de 80 px al lado se equivocaría entre unos 1180 y 1260 px. Pasa a usar el ancho disponible (`LayoutBuilder`), que sin riel es el mismo de hoy |
| Componentes | `CampoEntero` admite 3 cifras como máximo y `CampoEtiquetas` tiene el estilo de las alergias (ícono de aviso ámbar) | Hacen falta `CampoMoneda` (COP con separador de miles) y `CampoCantidad`, y una variante neutra de etiquetas |
| Cámara | `Permissions-Policy: camera=()` está en las 5 configuraciones de hosting, y una prueba exige que coincidan. Bloquea `getUserMedia` en todo el sitio. Elegir un archivo sí funciona | Las fotos se toman con `<input type=file accept=image/* capture>`, que en celulares y tabletas abre la cámara del sistema, sin tocar las cabeceras del sitio público (pregunta 21) |
| WhatsApp, `.ics` y `.csv` | La CSP no restringe la navegación: abrir `https://wa.me/…` funciona. Las descargas ya se hacen con `blob:` (`archivos.descargar`) | Sin cambios de cabeceras. La prueba e2e falla ante cualquier petición externa, así que intercepta el enlace de WhatsApp sin abrirlo |
| Pruebas e2e | Scripts de Playwright que manejan la app por el árbol de semántica, sin conexión y con la CSP de producción. Las capturas salen de esas corridas (1440 × 1000 y 390 × 844). Los 320 px solo se prueban con pruebas de widgets | Nuevo `tool/e2e/consultorio_offline.mjs`, que crece en cada subfase, con capturas de escritorio, móvil y 320 px en `docs/fase5/` |
| Regla 10 de IHCE | `tool/ihce/regla10.dart` (parte de `tool/ihce/verificar.sh`, no de CI) falla si cambia `lib/app/tema.dart` o `web/`, o si un archivo de `lib/features/`, `lib/core/widgets/` o `lib/app/` cambia sin figurar en `docs/ihce/CAMBIOS_UI.md` | La Fase 5 cambia interfaz a propósito, así que ese control se pondría en rojo. Hay que decidir su alcance (pregunta 8). Evito tocar `tema.dart` y `web/`: los colores de las gráficas y de la agenda se derivan de los tokens existentes |
| Lo guardado en el navegador | Está atado a la dirección del sitio. Safari puede borrarlo si no se usa en semanas (FASE4.md). Nadie pide almacenamiento persistente | Se pide `navigator.storage.persist()`, se muestra el espacio usado y el respaldo es obligatorio (pregunta 7). **Dónde se publica la versión con la bandera encendida decide qué comparte con el sitio público** (pregunta 2) |

### Normativa (todo VERIFICAR)

| Norma | Qué encontré | Qué hace la app |
|---|---|---|
| **Ley 1581 de 2012** y Decreto 1377 de 2013 (compilado en el Decreto 1074 de 2015) | Los datos de salud son sensibles: piden autorización explícita del titular, con finalidades claras, salvo las excepciones del art. 6. Hace falta una política de tratamiento y un aviso de privacidad. El Registro Nacional de Bases de Datos (SIC) obliga a sociedades con activos de más de 100.000 UVT (Decreto 090 de 2018), no a personas naturales | La ficha registra la **autorización de tratamiento de datos** firmada en pantalla, con la versión exacta del texto. Incluyo plantillas de autorización y de política de privacidad, marcadas BORRADOR, para que las revises con tu abogado |
| **Resolución 1995 de 1999** y Resolución 839 de 2017 | Custodiar la historia clínica es responsabilidad del prestador. Hay que conservarla al menos 15 años desde la última atención. Los consentimientos y las imágenes son anexos de la historia | El aviso de respaldo explica que **la custodia es tuya**. Los consentimientos y las fotos quedan ligados a la ficha y van en el respaldo |
| Ley 23 de 1981 (ética médica) | Consentimiento del paciente antes de exponerlo a riesgos (art. 15). Contenido y veracidad del certificado médico (arts. 50 a 52) | Plantillas de consentimiento y de certificados editables, con tus datos y tu firma |
| Ley 527 de 1999 y Decreto 2364 de 2012 (firma electrónica) | La ley distingue la firma electrónica de la firma digital certificada. Una firma dibujada en pantalla sería firma electrónica, y su validez depende de que se pueda atribuir al firmante y de la integridad del documento (VERIFICAR) | Cada documento firmado guarda la imagen de la firma, su huella SHA-256, la fecha y la hora, y su propio `documento.json` sellado dentro del PDF. Como alternativa, se puede adjuntar el documento firmado en papel |
| **Ley 1799 de 2016** | Prohíbe los procedimientos médicos y quirúrgicos estéticos en menores de 18 años, aun con permiso de los padres (art. 3), con excepciones (art. 4: nariz, orejas, reconstructivas, peelings, patologías acreditadas). La Sentencia C-246 de 2017 condicionó el art. 3 para adolescentes mayores de 14 con capacidad evolutiva (**VERIFICAR** el alcance) | Bloqueo duro: un paciente menor de 18 años no puede tener valoración estética, sesiones ni citas de esos tipos. Si no hay fecha de nacimiento, la valoración la pide |
| **Ley 2316 de 2023** y Decreto 545 de 2024 | Leí el texto: trata de las **sustancias modelantes** (rellenos inyectables), su listado oficial de sustancias permitidas, el consentimiento con los componentes del producto (art. 8) y la trazabilidad de su venta. **No cubre la hidrolipoclasia ni exige por sí misma registro Invima a todo insumo.** Ese requisito general viene del Decreto 677 de 1995 (medicamentos) y del Decreto 4725 de 2005 (dispositivos médicos) | El inventario pide el registro Invima de cada medicamento y dispositivo, y advierte si falta (con más fuerza en los inyectables). La categoría «sustancia modelante» queda prevista para cuando agregues rellenos |
| **Proyecto de Ley 187 de 2026 Senado** | **No es ley.** Ponencia para primer debate en la Comisión Séptima (Gaceta del Congreso 1571, 19/10/2026). Leí el texto propuesto en las páginas de esa Gaceta, en una copia alojada por un tercero (ver «Fuentes»; VERIFICAR contra la Gaceta oficial). El texto puede cambiar en cada debate. Lo pertinente: certificación de competencias por familias de técnicas, con recertificación cada 5 años y caducidad tras 24 meses sin práctica (art. 11). Servicio de Medicina Estética en el REPS (art. 12). Solo anestesia local, con dosis máximas en mg y mg/kg, nunca en volumen; registrar dosis, concentración y volumen; emulsión lipídica al 20 % en el sitio (art. 10). Protocolo escrito por procedimiento y **lista de verificación previa obligatoria** (art. 14). Registro Nacional de Procedimientos, sin datos que identifiquen al paciente (art. 15). Consentimiento escrito y previo, por plan de tratamiento en las series, con contenido mínimo (título y certificación del médico, número de habilitación, producto con registro Invima, alcance realista, obligación de medio, ruta de complicaciones y póliza) (art. 16). Póliza de complicaciones (art. 17). Publicidad sin rifas ni «promociones por tiempo limitado» (art. 18). Transición de 36 meses con volumen documentado (art. 19). El art. 3 f) define como cirugía estética la «extracción, aspiración o transferencia de tejido adiposo»; la hidrolipoclasia, sin aspiración, parece caer en el art. 7 (**VERIFICAR**) | Lo uso como guía de buenas prácticas sin darlo por vigente. **Certificaciones por técnica** con vigencia en la configuración, con aviso si una técnica se usa sin certificación. Lista de verificación previa en cada sesión. Dosis del anestésico en mg y mg/kg. Consentimiento por plan de tratamiento con esos apartados. Campo de póliza. Informe de volumen por técnica. Exportación anónima de procedimientos preparada para un futuro registro (Fase 6) |
| Decreto 1427 de 2022 (incapacidades, en el Decreto 780 de 2016) | Según resúmenes del decreto (no leí su texto completo): contenido mínimo del certificado de incapacidad con datos del prestador (nombre, NIT y código), diagnóstico, días y prórroga, y nombre, documento y firma de quien lo expide; límites de días y de retroactividad; y validación por la EPS cuando el profesional no es de su red. Todo VERIFICAR contra el texto | La plantilla de incapacidad pide esos campos y **avisa** (no bloquea) si faltan tu código de prestador o tu NIT. Los límites de días y de retroactividad entran como avisos solo cuando los verifiques |
| Resolución 3100 de 2019 (habilitación) | El profesional independiente se inscribe en el REPS y habilita cada servicio | Se agregan a la configuración el código de prestador, el NIT y el número de habilitación de cada servicio. Los usan el consentimiento y la incapacidad |
| GLP-1 (fichas técnicas de Invima) | Invima informó un **único** registro de semaglutida, OZEMPIC® (2019M-0019473), autorizado solo para el control glucémico en diabetes tipo 2. El registro de Wegovy en Colombia es contradictorio en las fuentes. Alerta de julio de 2025 por neuropatía óptica isquémica (NAION) con semaglutida, y alerta 090-2024 por semaglutida con B12 fraudulenta | Catálogo editable de medicamentos con registro Invima e indicación aprobada. Un medicamento sin registro confirmado queda marcado así y avisa. Si la indicación no corresponde al paciente, aviso de uso fuera de indicación (no bloquea). La lista de contraindicaciones incluye retinopatía y neuritis óptica. Todo **VERIFICAR** contra la ficha técnica vigente |
| Tamizaje de conducta alimentaria y dismorfia | **SCOFF**: versión española validada (García-Campayo, 2005; corte ≥ 2). **Dismorfia:** el BDDQ-AS (versión para estética, 7 ítems) tiene una **traducción** al español adaptada para Colombia, pero no confirmé que esté **validada**. Validados en español encontré el DCQ (Cuestionario de Preocupación Dismórfica, en universitarios españoles) y el autoinforme del BDDE (Raich). **No encontré la licencia de uso de ninguno** | La estructura del tamizaje va incluida; los textos de los ítems, solo cuando confirmes la licencia (pregunta 30) |
| DIAN | Los servicios médicos están excluidos del IVA (art. 476 num. 1 del Estatuto Tributario). **Las fuentes que encontré se contradicen** sobre si los tratamientos de belleza y las cirugías estéticas no reparadoras quedan exceptuados de esa exclusión, es decir, gravados (Leyes 1943 de 2018 y 2010 de 2019, y oficios de la DIAN). Tampoco confirmé si estás obligado a facturar electrónicamente | El recibo dice claramente «Este documento no es una factura electrónica de venta», con la nota de VERIFICAR tus obligaciones ante la DIAN con tu contador. Cada servicio trae un campo opcional de IVA, apagado por defecto, por si tu contador confirma que un procedimiento estético está gravado. La factura electrónica y los RIPS quedan para la Fase 6 |

---

## Decisión de arquitectura: la confirmo, con ocho ajustes

**Confirmo:** almacén local cifrado en IndexedDB, llave derivada de tu frase de acceso, bloqueo por inactividad, ningún dato sale del navegador, el PDF sigue siendo el registro clínico legal, el índice guarda la huella de cada documento, y el respaldo cifrado es obligatorio, con aviso de vencimiento, verificación al importar y la importación en lote de tus PDF.

**Ajustes que propongo:**

1. **Llave en sobre.** Una llave de datos aleatoria de 256 bits cifra todo. Esa llave se guarda envuelta dos veces:
   - con una llave derivada de tu frase (PBKDF2 o Argon2id);
   - con un **código de recuperación** de 24 caracteres que la app te muestra una sola vez para imprimirlo.

   Cambiar la frase no obliga a recifrar nada. Si olvidas la frase y el código, **los datos del consultorio no se pueden recuperar**; las historias sí, porque están en tus PDF.
2. **Todo cifrado, también los metadatos.** Nada de nombres, documentos ni huellas en las claves de IndexedDB: las claves son identificadores al azar (`pacientes/3f9a…`). Cada registro se cifra con su colección e identificador como datos asociados (AAD), así que no se puede cambiar un registro por otro sin que se note. Lo único en claro:
   - los parámetros de la llave y la versión del esquema;
   - la fecha y la huella del último respaldo;
   - cuántos registros hay de cada colección (también en el manifiesto del respaldo).

   **Lo que hoy guarda la app en claro, en `localStorage`:** el borrador de la historia, la receta en curso y tus datos de médico. Con la bandera encendida propongo mover el borrador y la receta en curso, que tienen datos de pacientes, al almacén cifrado (pregunta 6). Tus datos de médico (nombre, registro, firma y sello) siguen como hoy, porque la historia y la receta los necesitan aunque el consultorio esté bloqueado.
3. **Los índices viven en memoria.** Al desbloquear, se descifran los registros (no las fotos) y se arman los índices de búsqueda. Para unos miles de pacientes es rápido; lo mido en la 5.1 con 5.000 pacientes sintéticos. Las fotos se descifran solo cuando se ven, y las miniaturas se guardan aparte, también cifradas.
4. **Base y código aparte de IHCE.** Del pedido original reutilizo el algoritmo (AES-256-GCM de `cryptography`), el estilo del contrato del almacén y el patrón de migraciones. **No reutilizo `RepositorioIhce` ni la clase `CifradorDatos`**: el primero es específico del RDA y guarda metadatos en claro, y la segunda toma su llave de `flutter_secure_storage` (ver Hallazgos). El consultorio usa una **base aparte** (`historiasclinicas_consultorio`), con su propia llave, y el código de IHCE no cambia.
5. **Copia de trabajo de la historia sellada.** El índice guarda el último `historia.json` sellado de cada historia, y los bytes exactos de su último PDF y de cada documento. Así, desde la ficha:
   - «Abrir PDF» abre el archivo legal exacto;
   - «Agregar evolución» continúa la historia sin buscar el archivo;
   - una sesión de procedimiento se sella como evolución.

   Cada versión nueva **se descarga igual que hoy** (`_vN`), porque el PDF sigue siendo el registro. Si abres un PDF más viejo que la copia del índice, la app avisa, para que la historia no se bifurque.
6. **Bandera constante.** `const consultorioHabilitado = bool.fromEnvironment('CONSULTORIO_ENABLED')`. Con la bandera apagada, el compilador **elimina** el código del consultorio del sitio público. Una prueba lo comprueba: busca en `main.dart.js` una marca del módulo y no debe encontrarla.
7. **Dónde corre.** La versión con la bandera encendida se publica en **otra dirección** (pregunta 2), para que el sitio público no cambie y para que lo guardado en cada uno quede separado.
8. **Una pestaña a la vez.** Un candado entre pestañas (`navigator.locks`) evita que dos pestañas escriban a la vez. La historia y la receta siguen funcionando aunque el consultorio esté bloqueado. Si sellas una historia con el consultorio bloqueado, la app te pide la frase; si prefieres seguir, la registra al desbloquear, **guardándola solo en memoria** (nunca en claro). Si cierras la pestaña antes, la importación de PDF la recupera.

```
  frase de acceso ──PBKDF2/Argon2id──► llave de la frase ─┐
                                                          ├─► desenvuelve ► LLAVE DE DATOS (solo en memoria)
  código de recuperación ──PBKDF2────► llave del código ──┘                     │
                                                                                ▼
  IndexedDB «historiasclinicas_consultorio»                     AES-256-GCM (AAD = colección|id)
  ├─ meta      llavero (sal, parámetros, llave de datos envuelta ×2), esquema, último respaldo
  ├─ registros pacientes/…, historias/…, documentos/…, citas/…, cobros/…, insumos/…   (cifrados)
  └─ binarios  fotos, miniaturas, PDF exactos, firmas                                  (cifrados)
```

---

## (a) Preguntas

### Para empezar la 5.0
1. **¿Apruebas la arquitectura con los ocho ajustes de arriba?** *Por defecto:* sí.
2. **¿Dónde corre la versión con la bandera encendida?**
   - **(a)** Un subdominio propio, por ejemplo `consultorio.historiasclinicas.net`, en Cloudflare Pages o Netlify. Es otra dirección, con lo guardado aparte.
   - **(b)** Solo en tu Mac, servida en `localhost`. Funciona sin conexión, pero solo en ese equipo.
   - **(c)** El mismo `historiasclinicas.net`. No lo recomiendo: cambiaría el sitio público.

   En (a):
   - la página sería pública aunque los datos no: cada navegador guarda lo suyo, cifrado;
   - las cabeceras son **las mismas del sitio público** (misma CSP y misma `Permissions-Policy`), y la prueba que exige que coincidan las incluye. Solo cambiarían si eliges la cámara en vivo (pregunta 21 b);
   - se puede restringir el acceso con Cloudflare Access (VERIFICAR el plan gratuito). Agrega un inicio de sesión de Cloudflare al entrar con conexión; sin conexión, la app instalada abre igual desde su caché (VERIFICAR).

   *Por defecto:* (a), con la guía de publicación en la 5.0. La cuenta la creas tú; no publico nada.
3. **¿En qué equipos vas a trabajar?** Los datos viven en un navegador de un equipo, sin sincronización (eso es Fase 6).
   - Si atiendes en un portátil y tomas fotos o firmas con el celular, propongo: restauras el respaldo en el celular, que así comparte la llave, y lo usas como **equipo secundario**. Lo que hagas ahí (fotos, mediciones y documentos firmados) lo pasas al portátil en un **paquete cifrado** (`.hcpaquete`), que se combina con lo del portátil en vez de reemplazarlo.
   - Si usas una tableta para todo, no hace falta.

   *Por defecto:* portátil como equipo principal y celular como secundario, con el paquete cifrado (en la 5.2).
4. **Frase de acceso y recuperación.** *Por defecto:*
   - frase de 12 caracteres o más, con medidor de fortaleza;
   - código de recuperación de 24 caracteres, que se muestra una sola vez y se descarga en una hoja PDF para imprimir. Para confirmar que lo guardaste, la app te pide sus últimos 4 caracteres.
5. **Derivación de la llave.** *Por defecto:* PBKDF2-HMAC-SHA256 con 600.000 iteraciones. En la 5.0 mido Argon2id en tus equipos y te traigo los tiempos para decidir.
6. **Bloqueo.** *Por defecto:*
   - 10 minutos sin actividad, configurable de 2 a 60;
   - botón «Bloquear ahora»;
   - al bloquear, la pantalla se tapa y la app **descarta** la llave y los datos descifrados. El navegador no permite garantizar que la memoria se borre al instante, así que la llave se importa en WebCrypto como no extraíble: el código de la página puede usarla pero no leerla;
   - con la bandera encendida, el borrador de la historia y la receta en curso, que hoy quedan en claro en el navegador, se guardan cifrados en el almacén. Con el consultorio bloqueado, el borrador se guarda solo en memoria hasta desbloquear. Con la bandera apagada no cambia nada.
7. **Respaldo.** *Por defecto:*
   - aviso a los 7 días sin respaldo, configurable;
   - un archivo `.hcrespaldo` que se descarga y que conviene guardar en dos sitios (USB y tu nube; va cifrado);
   - restaurar reemplaza todo, tras confirmar. Combinar queda solo para el paquete del equipo secundario.

   ¿Quieres además que la app ofrezca el respaldo al cerrar el día de caja? *Por defecto:* sí.
8. **Regla 10 de IHCE.** La Fase 5 cambia la interfaz a propósito, y la regla compara archivo por archivo, así que se pondría en rojo. *Por defecto:*
   - la regla 10 sigue igual para todo lo demás;
   - acepta también el inventario de `docs/FASE5.md` (tabla «Archivos existentes que cambia la Fase 5», con la ruta completa de cada archivo) y la carpeta nueva `lib/features/consultorio/` completa;
   - `tema.dart` y `web/` siguen sin tocarse;
   - no hay dependencias nuevas (ver «Dependencias»). Si alguna hiciera falta, te la pregunto antes.

   Es el único control que cambia, y el cambio queda en su propio commit.
9. **Orden de las subfases.** Tu orden se mantiene, con dos ajustes:
   - una **5.0 «Cimientos»** antes de la 5.1: bandera, almacén cifrado, desbloqueo, respaldo y navegación;
   - el **consentimiento informado pasa a la 5.3**, porque la regla «firmado antes de la primera sesión» lo necesita ahí. La 5.4 hace los demás documentos.

   El motor de documentos (PDF con datos incrustados y firma del paciente) y el **editor de textos de plantillas** (con versiones y «aprobar») empiezan en la 5.1 con la autorización de tratamiento de datos, porque ninguna plantilla BORRADOR se puede usar sin aprobarla. Los editores de la plantilla del procedimiento y de los esquemas de GLP-1 llegan en la 5.3. *Por defecto:* así.

### Pacientes (5.1)
10. **Identidad.** *Por defecto:*
    - clave = tipo + número de documento, normalizados (sin puntos ni espacios);
    - para un adulto o menor sin identificar (AS/MS), un identificador interno;
    - si el documento cambia (TI → CC), «Unir fichas» manual, con registro en la bitácora.
11. **Líneas y etiquetas.** *Por defecto:*
    - un paciente puede estar en varias líneas a la vez. La app propone la línea según lo que registres (una valoración estética sugiere «Estética»), y tú la confirmas;
    - etiquetas libres, con sugerencias de las ya usadas.
12. **Autorización de tratamiento de datos.** *Por defecto:*
    - se pide en la primera atención: lectura, casilla y firma en pantalla;
    - si el paciente no la da, la ficha muestra un aviso permanente, pero **no se bloquea la atención clínica**, porque la historia es una obligación legal (VERIFICAR con tu abogado).
13. **Ficha y datos sellados.** *Por defecto:*
    - la ficha muestra los antecedentes y las alergias de la historia inicial más reciente, con la fuente («de la historia del 02/10/2026»);
    - «Actualizar alergias» en la ficha agrega «Alergias actualizadas: …» a la evolución en curso, que queda sellada, y actualiza la ficha y la alerta de la receta;
    - los datos administrativos (teléfono, dirección, etiquetas) se editan en la ficha y no alteran lo sellado.
14. **Recetas.** Con la bandera encendida, ¿incrusto `receta.json` en la receta nueva y la registro en la ficha? Con la bandera apagada, la receta queda como hoy. *Por defecto:* sí.
15. **Próximo control en las evoluciones.** Hoy solo lo tiene el plan de la historia inicial.
    - **(a)** Agregar a la evolución un campo opcional «Próximo control», solo con la bandera encendida. Toca el modelo, el editor, el PDF y la lectura de la evolución. Se sella en el PDF; antes compruebo con una prueba que la versión pública abra, verifique y continúe esas historias sin perder el campo.
    - **(b)** No tocar el formato: el indicador usa el plan y las citas futuras.

    *Por defecto:* (a).
16. **Importación en lote.** *Por defecto:*
    - se aceptan muchos PDF a la vez, elegidos o soltados;
    - por cada uno se informa: importada, ya estaba, versión más nueva (se actualiza), **alterada desde la evolución *n*** (se indexa marcada, nunca se oculta), dañada, o no es de la app;
    - si dos PDF de la misma historia se contradicen, se marcan como «versiones divergentes» para que elijas;
    - desde la 5.4 acepta también los PDF de documentos (`documento.json`) y de recetas nuevas (`receta.json`).

### Seguimiento y fotos (5.2)
17. **Mediciones.** Se guardan en el índice con su fecha. Si se toman durante una atención, ¿se copian al texto de la evolución al sellarla («Mediciones del día: …»)? *Por defecto:* sí, porque son datos clínicos y deben quedar en la historia.
18. **Perímetros.** *Por defecto:*
    - abdomen, flancos, muslos y brazos, con muslos y brazos derecho e izquierdo por separado;
    - el % de grasa es opcional y pide el método (bioimpedancia, pliegues u otro);
    - la talla se arrastra de la última medición.
19. **Vistas de las fotos.** *Por defecto:* frontal, lateral derecha, lateral izquierda, posterior y «detalle de zona». Cada vista trae una guía de encuadre (siluetas y líneas de hombros, ombligo y caderas) y la foto anterior en transparencia para alinear.
20. **Calidad y privacidad.** *Por defecto:*
    - lado mayor de 1600 px, JPEG al 80 % (unos 300 KB por foto);
    - **se quitan los metadatos EXIF**, que pueden incluir la ubicación GPS;
    - las fotos tomadas con `capture` no deberían quedar en el carrete del celular (VERIFICAR en tu modelo).
21. **Cámara.**
    - **(a)** Cámara del sistema mediante el selector de archivos: funciona en celulares y tabletas sin tocar las cabeceras. La guía y la foto anterior en transparencia se muestran justo después de tomarla, para repetirla si no quedó alineada.
    - **(b)** Vista en vivo con la guía encima: exige `camera=(self)` en las cabeceras de la versión del consultorio. Es más compleja, pero el sitio público no cambia.

    *Por defecto:* (a) en la 5.2; (b) como opción para la Fase 6.
22. **Consentimiento de uso de imagen.** *Por defecto:* tres permisos separados, cada uno revocable:
    - registro clínico, obligatorio para tomar fotos;
    - docencia o publicación académica sin rostro ni rasgos identificables;
    - publicidad o redes sociales.

    Sin el primero, el botón de fotos no aparece.
23. **Fotos en los PDF.** *Por defecto:*
    - nunca en la historia **sin que lo pidas**: solo si eliges fotos concretas para adjuntar a una evolución;
    - en el «Informe de seguimiento», solo si marcas «Incluir fotos», que viene apagado;
    - las fotos viven en el almacén y en el respaldo, que es su custodia. «Exportar fotos del paciente» las saca en un PDF, solo si lo pides.

### Programa de peso (5.3)
24. **Catálogo de medicamentos GLP-1.** *Por defecto:* semaglutida subcutánea semanal, semaglutida oral, liraglutida y tirzepatida (GIP/GLP-1). Cada uno lleva:
    - nombre comercial, registro Invima e indicación aprobada;
    - un esquema de titulación editable.

    Todo **VERIFICAR** contra la ficha técnica. Solo Ozempic tiene registro confirmado en lo que encontré (y para diabetes tipo 2), así que los demás vienen marcados «registro Invima sin confirmar» hasta que escribas el número. No pongo dosis por defecto que no hayas revisado: cada esquema queda como «sin aprobar» hasta que lo apruebes.
25. **Lista de contraindicaciones** (toda VERIFICAR contra la ficha técnica con registro Invima). *Por defecto:*
    - **absolutas** (bloquean el inicio): antecedente personal o familiar de carcinoma medular de tiroides o MEN2, antecedente de pancreatitis, embarazo, lactancia e hipersensibilidad. La pancreatitis la pongo aquí porque la nombraste; en algunas fichas figura como precaución;
    - **precauciones** (piden una nota): enfermedad biliar, retinopatía diabética, NAION o neuritis óptica, gastroparesia o enfermedad gastrointestinal grave, diabetes tipo 1, insuficiencia renal o riesgo de deshidratación, depresión o ideación suicida, cirugía o sedación programada, y uso de insulina o sulfonilureas;
    - en mujeres en edad fértil, anticoncepción y plan de embarazo (suspender antes, VERIFICAR el plazo).

    ¿Quitas o agregas alguna?
26. **Plantillas de plan nutricional y de ejercicio.** ¿Me envías las tuyas? *Por defecto:* tres plantillas de ejemplo marcadas BORRADOR, que no se pueden usar hasta que las edites y apruebes. El recordatorio de proteína suficiente y entrenamiento de fuerza aparece en el programa y en las indicaciones impresas; la cantidad de proteína la fijas tú.
27. **Meta.** *Por defecto:* peso meta, cintura meta y fecha, más el % de peso perdido calculado y la gráfica contra la meta.

### Valoración estética y sesiones (5.3)
28. **Criterios de candidato.** *Por defecto:* todos editables en la plantilla:
    - IMC máximo 30 como aviso (VERIFICAR tu criterio de «cerca del peso ideal»);
    - por zona: grasa pinzable sí/no y en cm, elasticidad (buena, regular o mala) y flacidez (0 a 3);
    - expectativas (realistas o no realistas), con nota.

    ¿Qué umbrales usas?

    Contraindicaciones por defecto, cualquiera en «sí» da «no apto» o «diferir» según el caso:
    - embarazo o lactancia;
    - anticoagulación o coagulopatía;
    - infección en la zona;
    - enfermedad descompensada;
    - alergia a anestésicos locales.

    Del proyecto de ley se suman, como precaución: antiagregación no suspendida según protocolo, cirugía previa en la zona e indicios de trastorno dismórfico corporal.
29. **Resultado.** *Por defecto:*
    - apto, no apto o diferir, con motivo obligatorio y una recomendación de una lista editable («primero programa de peso», «flacidez: remitir a cirugía plástica»);
    - «no apto» y «diferir» bloquean agendar y registrar sesiones de ese procedimiento hasta una valoración nueva;
    - «apto» vale 90 días.

    La valoración también se sella como evolución en la historia.
30. **Tamizaje** (VERIFICAR la validación y la licencia de cada instrumento). *Por defecto:*
    - conducta alimentaria: SCOFF (validado en español);
    - dismorfia: el DCQ, que está validado en español, o el BDDQ-AS si confirmas que su versión en español está validada. ¿Cuál prefieres?
    - un tamizaje positivo sugiere «diferir y remitir a psicología o psiquiatría»;
    - sin licencia confirmada no incluyo el texto de los ítems: la app trae la estructura, y tú cargas el texto o me confirmas que su uso es libre.
31. **Protocolo del procedimiento.** No voy a inventar la composición de la solución, los volúmenes ni los parámetros del equipo. *Por defecto:*
    - la plantilla de hidrolipoclasia trae los **campos**, y tú escribes tu protocolo: zonas, componentes, volumen máximo por zona y por sesión, intervalo entre sesiones y número de sesiones;
    - la plantilla queda «sin aprobar» hasta que la revises.

    ¿Me envías tu protocolo escrito?
32. **Dosis del anestésico.** *Por defecto:*
    - la dosis se calcula en mg y mg/kg a partir de la concentración, el volumen y el peso de la última medición. Si la medición tiene más de 30 días, pide pesar;
    - aviso ámbar desde el 80 % del máximo del protocolo y **bloqueo por encima del 100 %**;
    - el máximo por anestésico (con y sin epinefrina) lo fijas tú (VERIFICAR; el proyecto de ley lo dejaría a MinSalud).

    ¿Bloqueo o solo aviso?
33. **Lista de verificación previa a la sesión** (art. 14 del proyecto de ley, VERIFICAR). *Por defecto:* obligatoria, con ítems editables:
    - consentimiento vigente, valoración vigente y mayor de edad;
    - alergias, anticoagulación, embarazo, infección en la zona y signos vitales;
    - lotes vigentes, equipo verificado, y emulsión lipídica y protocolo de toxicidad disponibles.
34. **Póliza de complicaciones** (art. 17 del proyecto de ley, VERIFICAR). *Por defecto:* campo opcional (aseguradora y número, o «sin póliza») en la configuración, que se copia al consentimiento y a la sesión.
35. **Sesión sellada.** *Por defecto:*
    - se sella como evolución, y genera la versión nueva del PDF de la historia, que se descarga;
    - como el PDF es el registro legal, **el texto sellado lleva todo lo clínico**: zona, componentes y volúmenes, anestésico con lote, dosis en mg y mg/kg, equipo y parámetros, insumos con lote y vencimiento, resultado de la lista de verificación, duración, eventos adversos, indicaciones y control;
    - el índice guarda además los mismos datos estructurados, para el inventario y los informes.
36. **Certificaciones por técnica.** *Por defecto:*
    - en la configuración: técnica o familia, entidad, fecha, vigencia y el soporte (PDF o foto, cifrado);
    - usar una técnica sin certificación vigente da un **aviso** que queda registrado, pero no bloquea mientras el proyecto de ley no sea ley.

    ¿Aviso o bloqueo?

### Documentos (5.4)
37. **Textos.** ¿Me envías tus textos de consentimiento, certificados e incapacidad? *Por defecto:*
    - plantillas base con los apartados del art. 16 del proyecto de ley y del art. 8 de la Ley 2316 (VERIFICAR los dos), marcadas BORRADOR, que no se pueden usar hasta que las edites y apruebes;
    - cada documento lleva tus datos, tu firma y tu sello, con los mismos interruptores «Incluir firma» e «Incluir sello» de hoy, y al firmarlo **se descarga su PDF** igual que la historia (el índice guarda además el PDF exacto);
    - cada plantilla lleva versión, y cada documento guarda con cuál se firmó.
38. **Firma del paciente.** *Por defecto:* en pantalla, idealmente en tableta o celular. Como alternativa, imprimir, firmar en papel y adjuntar la foto o el escaneo.
39. **Consentimiento por plan de tratamiento.** *Por defecto:*
    - un consentimiento cubre el plan (procedimiento, zonas y número de sesiones);
    - se pide uno nuevo si cambian la técnica, el producto o las zonas;
    - revocarlo bloquea las sesiones siguientes y queda registrado con fecha y motivo.
40. **Numeración.** *Por defecto:*
    - un consecutivo por tipo: CI- (consentimientos informados), CIM- (consentimientos de uso de imagen), AD- (autorizaciones de datos), CE- (certificados), IN- (incapacidades), OR- (órdenes), RM- (remisiones), IS- (informes de seguimiento) y RC- (recibos);
    - la política de privacidad no lleva número: es una sola, con versión;
    - un documento no se borra: se **anula** con motivo.
41. **Órdenes.** *Por defecto:* texto con plantillas (perfil metabólico, TSH, HbA1c, perfil lipídico, función hepática), sin códigos CUPS porque no hay catálogo incluido. Se podría importar uno después.

### Agenda (5.5)
42. **Horario y duraciones.** *Por defecto:*
    - horario: lunes a viernes de 8:00 a 12:00 y de 14:00 a 18:00, sábado de 8:00 a 12:00;
    - duraciones: primera vez 30 min, control 20, programa de peso 30, valoración estética 40 y sesión 60;
    - festivos de Colombia calculados (Ley 51 de 1983, VERIFICAR) y bloqueos manuales;
    - si dos citas se cruzan, la app avisa y no bloquea;
    - «no asistió» no consume sesiones del paquete, cuenta en un contador de inasistencias de la ficha y deja vigente el control vencido.
43. **WhatsApp y calendario.** El mensaje sale de la app hacia WhatsApp, que es un tercero, y un `.ics` puede terminar en un calendario en la nube. *Por defecto:*
    - mensaje editable **sin datos de salud**: «Hola {nombre}, le recordamos su cita el {día} a las {hora} en {consultorio}, {dirección}. Por favor confirme respondiendo este mensaje.» No incluye el tipo de cita («sesión», «programa de peso»);
    - el `.ics` dice solo «Cita médica» con la hora y el lugar;
    - la autorización de tratamiento de datos incluye, como finalidad, el contacto por WhatsApp y teléfono (VERIFICAR con tu abogado);
    - cada mañana, la agenda lista las citas del día siguiente sin recordatorio, con un botón «Enviar» por cita. El navegador no deja abrir varias pestañas con un solo clic, así que se envían una por una;
    - la confirmación la marcas tú a mano.

### Caja y paquetes (5.6)
44. **Tarifas iniciales y valoración abonable.** *Por defecto:*
    - el catálogo arranca con tus tarifas, todas editables:

      | Servicio | Línea | Tarifa inicial |
      |---|---|---|
      | Consulta de primera vez | General | 80.000 |
      | Control | General | 45.000 |
      | Certificado | General | 40.000 |
      | Valoración estética (abonable al tratamiento) | Estética | 70.000 |
      | Sesión de hidrolipoclasia por zona | Estética | 240.000 |
      | Paquete de 4 sesiones | Estética | 880.000 |

      ¿El control del programa de peso tiene tarifa propia?
    - el valor de la valoración queda como crédito durante 30 días y se descuenta del primer pago del tratamiento.
45. **Paquetes.** *Por defecto:* el paquete de 4 sesiones es para una zona, sin vencimiento. ¿Hay devoluciones si el paciente no termina? Las promociones con plazo no se incluyen (art. 18 del proyecto de ley; Ley 1480 de 2011, VERIFICAR).
46. **Medios de pago.** *Por defecto:*
    - efectivo, transferencia, Nequi, Daviplata y tarjeta;
    - abonos parciales y saldo;
    - recibo RC-000001 en A5, solo cuando hay pago. Usar una sesión de un paquete ya pagado no genera recibo: queda en el saldo del paquete y en la sesión;
    - el cierre del día cuenta el efectivo y registra la diferencia, y no se reabre. Anular un recibo de un día cerrado cuenta en el día en que se anula, con referencia al recibo original.
47. **CSV.** *Por defecto:* separador `;` y codificación UTF-8 con BOM, para que Excel en español lo abra bien.

### Inventario (5.7)
48. **Insumos iniciales.** ¿Me envías tu lista? *Por defecto:*
    - inventario vacío, con categorías: medicamento, dispositivo médico, insumo y sustancia modelante (para el futuro);
    - el stock se lleva en la unidad de presentación (ampolla, frasco, unidad);
    - la concentración (mg/mL) sirve para calcular dosis.
49. **Lotes.** *Por defecto:*
    - se sugiere el lote que vence primero;
    - aviso 30 días antes del vencimiento;
    - **bloqueo** para usar un lote vencido o sin stock;
    - el registro Invima no se puede verificar sin conexión: botón «Consultar en Invima», que abre su sitio en otra pestaña sin enviarle datos.

### Presentación (5.8)
50. **Las notas «VERIFICAR» en pantalla.** Hoy se ven, por ejemplo:
    - «VERIFICAR su validez legal» (firma y sello);
    - «VERIFICAR cuáles exige la norma» (datos complementarios);
    - «VERIFICAR la norma de tu país» (control especial).

    Propuesta, sin cambiar la convención hasta que me digas:
    - **(a)** En pantalla, un chip discreto «Por verificar» con la nota completa en un globo de ayuda. En el **«modo presentación»**, que se activa con un botón cuando te ve un paciente o un auditor, los chips se ocultan. En los PDF nunca se imprimen.
    - **(b)** Un registro de verificaciones: marcas una nota como verificada, con fecha y fuente, y el chip cambia a «Verificado el 21/11/2026 · Res. 1995/1999».

    La marca VERIFICAR sigue en el código y en los documentos. *Por defecto:* (a) y (b), solo con la bandera encendida. El sitio público queda igual.
51. **Inicio y navegación.** *Por defecto:*
    - con la bandera encendida, la app abre en la **agenda de hoy**;
    - en escritorio (≥ 1100 px), riel lateral de 80 px: Agenda, Pacientes, Historia, Caja, Inventario y Ajustes;
    - en móvil, menú lateral desde la barra superior, para no chocar con la barra de acciones de la historia;
    - el nombre del consultorio va junto al logotipo.

---

## (b) Modelo de datos

Convenciones:
- Todos los registros llevan `id` (UUID), `creado`, `actualizado` y `version`.
- Nada clínico se borra: se **anula** con motivo y fecha.
- Las fechas siguen el formato de `historia.json` (`AAAA-MM-DD`, `AAAA-MM-DDTHH:MM` local).
- Los valores en pesos son enteros.
- `→` indica una referencia a otro registro.

### Almacén

| Almacén de IndexedDB | Clave | Contenido |
|---|---|---|
| `meta` (en claro) | `llavero` | Formato, algoritmo y parámetros de derivación, sal, llave de datos envuelta con la frase, llave de datos envuelta con el código de recuperación, verificador |
| | `esquema` | Versión del esquema (migraciones) |
| | `respaldo` | Fecha del último respaldo y huella del archivo |
| `registros` (cifrado) | `<colección>/<uuid>` | Un `Uint8Array`: `[formato 1 B][nonce 12 B][texto cifrado + etiqueta GCM]`, con AAD = `hcc1|<colección>|<uuid>`, sobre el JSON canónico del registro. El JSON lleva su propia versión de esquema; una migración descifra, transforma y vuelve a cifrar cada registro en una transacción |
| `binarios` (cifrado) | `<tipo>/<uuid>` | Fotos, miniaturas, PDF exactos, firmas y soportes, en el mismo formato |

Las colecciones solo revelan cuántos registros hay de cada tipo, nunca su contenido. Las imágenes de firma y sello que se repiten en muchas historias se guardan una sola vez: el registro cifrado lleva su SHA-256 (como `recursos` en `historia.json`), pero la clave de IndexedDB es un identificador al azar.

### Entidades

```
Paciente ─┬─< Historia (índice + copia de trabajo) ──< Evolución (dentro de la historia sellada)
          ├─< Receta            ├─< Documento (autorización, consentimientos, certificados, …)
          ├─< Medición          ├─< Foto ─> Consentimiento de imagen
          ├─< ProgramaPeso ──< Dosis / Tolerancia / Evento adverso
          ├─< Valoración ─> PlantillaProcedimiento ─< Sesión ─> Consentimiento, Lote(s), Cita
          ├─< Cita ─> Cobro ─< Pago            Paquete ─< uso por Sesión      Crédito (valoración abonable)
          └── Bitácora (sin datos del paciente)     Insumo ─< Lote ─< Movimiento (entrada, salida, ajuste, baja)
```

| Entidad | Campos principales | Reglas |
|---|---|---|
| **Paciente** | Tipo y número de documento (normalizado), apellidos y nombres, fecha de nacimiento o edad aproximada, sexo, teléfono en formato +57 (y si tiene WhatsApp), correo, dirección, ciudad, ocupación, aseguradora, contacto de emergencia, `lineas` {general, peso, estética}, `etiquetas[]`, notas internas, → autorización de datos vigente, → consentimiento de imagen vigente, `unidoEn` (si se fusionó) | Documento único (salvo AS/MS). Los datos clínicos (alergias, antecedentes) no se guardan aquí: se leen de la historia sellada más reciente y de las «Alergias actualizadas» selladas en evoluciones, con su fuente (pregunta 13) |
| **Historia** (índice) | `historiaId` (el `id` de `historia.json`), → paciente, revisión, `datos` sellados (copia de trabajo), fecha de la atención, diagnósticos (resumen), `proximoControl`, huellas, `archivos[]` {nombre, revisión, SHA-256 del PDF, fecha, origen: generado o importado}, → PDF exacto de la última revisión, integridad {estado, alterada desde, descripción} | Un `historiaId` por registro. Una revisión menor que la guardada no la reemplaza. Dos contenidos distintos con la misma revisión marcan «versiones divergentes» |
| Evolución | Vive dentro de `datos.evoluciones` (no se duplica). El índice guarda su tipo (evolución, valoración, sesión, control de peso) y → registro de origen | |
| **Receta** | → paciente, → historia, número R-, fecha, ítems, indicaciones, SHA-256 del PDF, → PDF exacto, origen (generada con `receta.json` o «registrada en la historia») | |
| **Documento** | → paciente, tipo, → plantilla y versión, número consecutivo, fecha y hora, contenido, firma del paciente (→ PNG + SHA-256), copia del médico (`Autor`), estado (vigente, revocado {fecha, motivo} o anulado {motivo}), SHA-256 de `documento.json`, → PDF exacto | El PDF lleva `documento.json` incrustado y sellado, como la historia, para poder importarlo y verificarlo después |
| **Medición** | → paciente, fecha, peso, talla, cintura, cadera, perímetros {abdomen, flanco D/I, muslo D/I, brazo D/I}, PA sistólica/diastólica, % de grasa y método, notas, origen (manual o → historia/evolución) | IMC (`calcularImc`) e índice cintura-cadera se calculan, no se guardan. Los valores fuera de rango avisan sin bloquear, como hoy |
| **Foto** | → paciente, fecha, vista, zona, → sesión, ancho y alto, SHA-256 del JPEG, → binario, → miniatura, → consentimiento de imagen, notas | No se puede crear sin consentimiento de imagen vigente para uso clínico. Sin EXIF |
| **ProgramaPeso** | → paciente, inicio, meta {peso, cintura, fecha}, plan nutricional y de ejercicio (texto, → plantilla), lista de contraindicaciones {ítem: sí, no o desconoce, nota, versión del catálogo}, `glp1?` {→ medicamento del catálogo, registro Invima, indicación aprobada, inicio, dosis[] {fecha, dosis, unidad}, tolerancia[] {fecha, síntomas, escala}, eventos adversos[] {fecha, descripción, gravedad, conducta, reportado a Invima}, suspensión}, estado (activo, pausado o terminado) | Una contraindicación absoluta en «sí» impide registrar el inicio del GLP-1. Una precaución en «sí» exige nota |
| **Valoración** | → paciente, → plantilla y versión, fecha, respuestas (por ítem de la plantilla), IMC (calculado de la medición), zonas[] {zona, pinzable cm, elasticidad, flacidez}, expectativas, contraindicaciones[], tamizajes[] {instrumento, versión, respuestas, puntaje, positivo}, resultado (apto, no apto o diferir), motivo, recomendación, vigente hasta, → evolución sellada | Un paciente menor de 18 años no puede tener valoración. El motivo es obligatorio. «No apto» y «diferir» bloquean las sesiones de ese procedimiento |
| **PlantillaProcedimiento** | id (`hidrolipoclasia`), nombre, familia de técnicas (para las certificaciones), versión, aprobada por el médico (fecha), definición declarativa de la valoración (secciones e ítems: sí/no, escala, número, texto u opciones, con su regla), criterios de candidato, contraindicaciones (absoluta o precaución), tamizajes requeridos, campos de la sesión, insumos sugeridos, → plantilla de consentimiento, lista de verificación previa, indicaciones posteriores, días hasta el control, protocolo escrito | Una plantilla sin aprobar no se puede usar. **Agregar toxina, rellenos o bioestimuladores = agregar una plantilla**, sin reescribir el módulo |
| **Sesión** | → paciente, → plantilla, → valoración, → consentimiento, → cita, fecha, número de sesión en el plan, lista de verificación previa (respuestas), zonas[] {zona, componentes[] {→ lote, concentración, volumen mL}, volumen total}, anestésico {→ lote, concentración mg/mL, volumen mL, dosis mg y mg/kg calculadas, peso usado}, equipo {nombre, serie, registro Invima, parámetros}, insumos[] {→ lote, cantidad}, duración, eventos adversos[], indicaciones posteriores, fecha de control, estado (borrador o sellada), huella de la evolución | Para sellar exige: mayor de edad, valoración «apto» vigente, consentimiento vigente y sin revocar, lista completa, lotes no vencidos y con stock, y dosis dentro del máximo. Avisa si falta la certificación de la técnica. Al sellar, descuenta del inventario |
| **Cita** | → paciente (o nombre y teléfono provisionales para una primera vez), tipo (primera vez, control, valoración estética, sesión de procedimiento o programa de peso), inicio, duración (la del tipo, editable), estado (agendada, confirmada, atendida, no asistió o cancelada) e historial {estado, fecha}, motivo, notas, recordatorio {enviado en}, → plantilla (si es sesión), → cobro, → atención (historia o evolución) | Una cita de sesión o valoración estética exige mayor de edad. La de sesión exige además valoración «apto» vigente |
| **Horario** | Días y franjas, duración por tipo, bloqueos {inicio, fin, motivo}, festivos calculados | |
| **Servicio** | Nombre, línea, tarifa, IVA (opcional, apagado), abonable, sesiones del paquete, → plantilla, activo | Las tarifas iniciales son las de tu tabla (pregunta 44), editables |
| **Cobro** | Número RC-, fecha, → paciente, ítems[] {→ servicio, descripción, cantidad, valor unitario, descuento y motivo}, total, pagos[] {medio, valor, referencia, fecha}, saldo, → paquete, → crédito aplicado, estado (vigente o anulado {motivo}), → PDF del recibo | El número se asigna al emitir, no se reutiliza y no se salta |
| **Paquete** | → paciente, → servicio, sesiones compradas, usos[] {→ sesión, fecha}, → cobro, estado | No se puede usar más sesiones de las compradas |
| **Crédito** | → paciente, valor, → cobro de origen, vence, aplicado en | |
| **CierreDiario** | Fecha, totales por medio de pago, efectivo contado, diferencia, notas, cerrado en | Un día cerrado no se modifica: una anulación posterior cuenta en el día en que se hace |
| **Insumo** | Nombre, categoría, presentación, unidad, concentración (mg/mL), registro Invima, inyectable, stock mínimo, activo | Sin registro Invima: aviso (más visible en los inyectables) |
| **Lote** | → insumo, número de lote, vencimiento, proveedor, factura, fecha de ingreso | Su existencia es la suma de sus movimientos |
| **Movimiento** | → lote, tipo (entrada, salida por sesión, ajuste o baja por vencimiento), cantidad, fecha, → sesión, motivo | Solo se agregan, nunca se editan |
| **Configuración** | Datos del prestador (nombre del consultorio, código REPS, NIT, habilitación por servicio), certificaciones[] {técnica o familia, entidad, fecha, vigencia, → soporte}, póliza, minutos de bloqueo, días de respaldo, consecutivos, plantillas, horario, notas verificadas, modo presentación | |
| **Bitácora** | Fecha, acción (crear, anular, unir, exportar, importar, respaldar, restaurar, desbloquear), colección, id, resumen **sin datos del paciente** | Solo se agrega. Sirve para auditoría |

### Archivo de respaldo (`.hcrespaldo`)

```
Respaldo_consultorio_2026-11-21.hcrespaldo        (ZIP sin compresión; el contenido ya va cifrado)
├─ LEEME.txt          en claro: qué es y cómo restaurarlo; sin datos
├─ manifiesto.json    en claro: formato, versión de la app, fecha, parámetros de la llave, sal,
│                     llave de datos envuelta ×2, conteos y el SHA-256 de cada archivo
├─ manifiesto.sello   AES-GCM(llave de datos) del SHA-256 del manifiesto: autentica el manifiesto
├─ registros/000001.bin …    los mismos bytes cifrados del almacén, en lotes
└─ binarios/<tipo>/<id>.bin  fotos, miniaturas, PDF exactos, firmas
```

**Al importar se verifica todo:**
1. La frase (o el código) abre la llave.
2. El sello autentica el manifiesto.
3. El SHA-256 de cada archivo coincide con el manifiesto.
4. Cada registro se descifra con su AAD.
5. Los conteos coinciden.

Si algo falla, la app lista exactamente qué y no restaura nada, salvo que confirmes «restaurar solo lo íntegro». Restaurar reemplaza el almacén, después de confirmar. El **paquete del equipo secundario** (`.hcpaquete`) usa el mismo formato, solo con lo creado en ese equipo (fotos, mediciones y documentos firmados), y se combina en vez de reemplazar: lo que ya existe con el mismo identificador no se duplica.

**Límite:** el respaldo se arma en memoria. Con miles de fotos puede pesar cientos de MB. Si se acerca al límite del navegador, la app ofrece partir el respaldo, por ejemplo con las fotos por año aparte.

---

## (c) Bocetos textuales

### Paleta y estilo
Se mantiene el diseño 2b «Clínico sobrio» ([DISENO.md](DISENO.md)), con los componentes de hoy (`TarjetaSeccion`, `Aviso`, `TituloDialogo`, `RecuadroIcono`, los campos de `campos.dart`) y sin tocar `lib/app/tema.dart`. Lo nuevo usa solo tokens existentes de `ColoresMarca`, todos con contraste ≥ 4,5:1 sobre blanco (ya lo comprueba `test/app/tema_test.dart`):

| Uso nuevo | Token | Además del color |
|---|---|---|
| Acción, selección, cita «confirmada», serie 1 de las gráficas | `primario` `#1E5A7A` | Ícono o etiqueta de texto |
| Cita «atendida», integridad correcta, «apto», serie 2 | `estadoOk` `#2E7D5B` | ✓ |
| Control vencido ⏰, vencimiento próximo ⏳, stock bajo, «diferir», «Por verificar», serie 3 | `aviso` `#8A5A0B` (sobre `avisoFondo`: `avisoTexto`) | Ícono |
| Bloqueo, «no apto», lote vencido, alteración, «no asistió» | `error` `#B3362F` | ✕ y el motivo en texto |
| Cita «agendada», texto secundario, serie 4 | `tintaSuave` `#3B4853` | |
| Cita «cancelada» | `textoSuave` `#556370` | Tachado |
| Bloqueos de agenda, fondo de selección | `bloqueado`, `tinte` | Rayado |

Nunca se distingue algo solo por el color: siempre va con ícono o texto. Las líneas de las gráficas superan 3:1 y sus textos 4,5:1. Las pruebas de contraste se amplían con cada combinación nueva (por ejemplo, texto `avisoTexto` sobre `avisoFondo` en los chips).

### Desbloqueo (primera vez y después)
```
┌──────────────────────────────────────────────────────────────┐
│          historiasclinicas.net · Consultorio                 │
│                                                              │
│   🔒 El consultorio está bloqueado                           │
│   Frase de acceso [••••••••••••••••••••] 👁                  │
│                                       [ Desbloquear ]        │
│   ¿Olvidaste la frase? Usar el código de recuperación        │
│   ─────────────────────────────────────────────────────────  │
│   Último respaldo: hace 3 días (18/11/2026)                  │
│   La historia y la receta funcionan sin desbloquear.         │
│                                       [Ir a la historia]     │
└──────────────────────────────────────────────────────────────┘
```
- **La primera vez** se pide la frase dos veces, con medidor de fortaleza. Después aparece el **código de recuperación**, con «Descargar hoja para imprimir», y la app pide sus últimos 4 caracteres antes de seguir. Se explica en una línea: «Sin la frase ni el código, nadie (tampoco nosotros) puede abrir estos datos».

### Escritorio (≥ 1100 px): contenedor y lista de pacientes
```
┌──────┬───────────────────────────────────────────────────────────────────────────────┐
│  ▣   │ historiasclinicas.net · Consultorio Dr. …   [🔍 Paciente o documento…] [🔒] [⋮] │
│Agenda├───────────────────────────────────────────────────────────────────────────────┤
│  👥  │ ┌ ⚠ Último respaldo hace 9 días. La custodia de las historias es tuya ────────┐ │
│Pacien│ │   (Res. 1995/1999): si este equipo se pierde, solo el respaldo las recupera. │ │
│  📄  │ │                                                    [Respaldar ahora]        │ │
│Histor│ └──────────────────────────────────────────────────────────────────────────────┘ │
│  $   │ PACIENTES · 412                              [+ Paciente] [⇪ Importar PDF]     │
│ Caja │ Buscar [nombre o documento_________]  Línea [Todas ▾]  Última atención [▾]     │
│  📦  │ Etiquetas [HTA ×] [+]    ☐ Solo controles vencidos (7)                         │
│Invent│ ┌────────────────────────────────────────────────────────────────────────────┐ │
│      │ │ PEÑA MUÑOZ, José Ángel    CC 1032456789  52 a  General · Peso  12/11  ⏰ venc │ │
│  ⚙   │ │ TORRES RUIZ, Juan         CC 79123456    45 a  General          02/10       │ │
│Ajuste│ │ …                                                                          │ │
└──────┴─┴────────────────────────────────────────────────────────────────────────────┴─┘
```
- La búsqueda no distingue tildes ni mayúsculas y acepta el documento con o sin puntos. Las flechas y Enter abren la ficha.
- **Historia** en el riel abre la pantalla de hoy, con su propia barra, a la derecha del riel. Si se abrió desde una ficha, la franja del paciente lleva «← Ficha».
- **Inicio:** con la bandera encendida, la app abre en `/agenda` (pregunta 51); la historia sigue en `/`. Con la bandera apagada no hay riel ni rutas nuevas, y la app abre en la historia, como hoy.
- **Tablet (700 a 1100 px):** el riel se vuelve un menú lateral. **Móvil (< 700 px):** menú lateral, lista de una columna y botón flotante «+ Paciente».

**La historia dentro del contenedor (escritorio, bandera encendida):**
```
┌──────┬────────────────────────────────────────────────────────────────────────────────┐
│  ▣   │ historiasclinicas.net   [Abrir historia existente] [Imprimir / Guardar PDF] [℞] [⋮] │
│Agenda│ ← Ficha · PEÑA MUÑOZ, José Ángel · CC 1032456789 · 52 a · ⚠ Penicilina          │
│  👥  ├──────────────┬─────────────────────────────────────────────────────────────────┤
│  📄● │ ÍNDICE       │ (la historia de hoy, sin cambios; los cortes se calculan con     │
│  $   │ ✓ 1 Paciente │  el ancho a la derecha del riel)                                 │
│  📦  │ ● 2 Motivo … │                                                                  │
└──────┴──────────────┴─────────────────────────────────────────────────────────────────┘
```

### Ficha longitudinal
```
┌ PEÑA MUÑOZ, José Ángel · CC 1032456789 · 52 a · M · ⚠ Penicilina ─────────────────────┐
│ Tel +57 300 000 0000 [WhatsApp]   Líneas: General · Peso   Etiquetas: HTA, GLP-1        │
│ Autorización de datos: firmada 02/10/2026 (AD-000031) · Imagen: uso clínico              │
│ [+ Historia nueva] [+ Evolución] [℞ Receta] [📅 Agendar] [$ Cobrar] [Documento ▾]        │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│ Resumen | Atenciones | Seguimiento | Fotos | Programa de peso | Estética | Documentos | Cobros │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│ LÍNEA DE TIEMPO                                            Ver [Todo ▾]                 │
│ 12/11/2026  Evolución #3 · Control de peso · 81bd·07aa            [Abrir PDF]           │
│ 12/11/2026  Receta R-000123                                       [Abrir PDF]           │
│ 05/11/2026  Valoración hidrolipoclasia · DIFERIR: primero programa de peso              │
│ 02/10/2026  Historia clínica · E66.0 Obesidad · ✅ íntegra (v3)    [Abrir PDF]          │
│ 02/10/2026  Autorización de tratamiento de datos · AD-000031      [Abrir PDF]           │
│ ANTECEDENTES (de la historia del 02/10/2026)    ALERGIAS ⚠ Penicilina (act. 12/11/2026) │
│ Personales: HTA… · Quirúrgicos: … · Medicación actual: …                                │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```
- En móvil, las pestañas pasan a una lista desplegable y las acciones a un menú «Acciones ▾».
- A 320 px, el nombre tiene prioridad (como la franja de hoy). Hay prueba.

### Seguimiento antropométrico
```
│ SEGUIMIENTO                                         [+ Medición] [⬇ Informe de seguimiento] │
│ Peso (kg)                 ┌─────────────────────────────┐   IMC   31,2 → 28,4  (−9 %)     │
│ 96 ●                       │ ●╲                          │   Cintura 104 → 96 cm            │
│ 88       ●──●──●  meta ‐ ‐ │    ●──●──●   ‐ ‐ ‐ 84 kg   │   ICC  0,98 → 0,94               │
│           oct   nov   dic  └─────────────────────────────┘   [Peso ▾] [Cintura] [Perímetros] │
│ Fecha      Peso  Talla IMC  Cint Cad  ICC  Abd  Flanco D/I  Muslo D/I  Brazo D/I  PA    %G │
│ 12/11/2026 88,0  176   28,4  96  102 0,94  98   …                                 128/82 —  │
```
- Gráficas con `CustomPainter` (sin dependencias) y colores derivados del tema, con contraste ≥ 3:1 para líneas y 4,5:1 para textos.

### Fotos y comparación
```
│ FOTOS · Consentimiento de imagen: uso clínico (CIM-000031, 02/10/2026)   [📷 Tomar fotos] │
│ Vista [Frontal ▾]     Comparar [02/10/2026 ▾]  con  [12/11/2026 ▾]      [⇆ Cortina]      │
│ ┌──────────────────┐ ┌──────────────────┐                                               │
│ │     (frontal)    │ │     (frontal)    │   Guía: hombros ─── ombligo ─── caderas       │
│ │    02/10/2026    │ │    12/11/2026    │   Diferencia de días: 41                      │
│ └──────────────────┘ └──────────────────┘                                               │
│ 02/10/2026  [frontal] [lat D] [lat I] [posterior] [detalle: abdomen]                     │
```
- **Tomar fotos** guía la secuencia de vistas. Después de cada foto aparece la guía de encuadre y la anterior en transparencia, con «Repetir» o «Aceptar».

### Programa de peso
```
│ PROGRAMA DE PESO · desde 02/10/2026 · activo                       [Editar plan] [⬇ Indicaciones] │
│ Meta  84 kg · cintura 90 cm · 02/04/2027      Hoy 88,0 kg (−8,3 %) · faltan 4 kg              │
│ ⓘ Recuerda: proteína suficiente y entrenamiento de fuerza para conservar masa muscular        │
│ Plan nutricional [plantilla «Déficit moderado» v2 ▾] …   Plan de ejercicio [plantilla ▾] …    │
│ GLP-1  Semaglutida SC semanal · INVIMA 2019M-0019473 · ⚠ indicación aprobada: DM2 (VERIFICAR) │
│        Contraindicaciones revisadas 02/10/2026 ✓ (0 absolutas · 1 precaución con nota)        │
│        Dosis  02/10 0,25 mg → 30/10 0,5 mg → [+ Cambio de dosis]                              │
│        Tolerancia  náuseas leves (30/10)   Eventos adversos  ninguno  [+ Registrar]           │
```

### Valoración para hidrolipoclasia
```
│ VALORACIÓN · Hidrolipoclasia (plantilla v1, aprobada 20/11/2026)        Paciente: 34 a ✓ │
│ 1 Candidato        IMC 26,1 (medición 12/11)  ·  ⚠ si > 30 (tu criterio)                 │
│   Zonas  [Abdomen inferior · pinzable 3 cm · elasticidad buena · flacidez 0] [+ zona]     │
│   Expectativas (•) Realistas ( ) No realistas   Nota [___________]                        │
│ 2 Contraindicaciones   Embarazo o lactancia (•)No ( )Sí   Anticoagulación (•)No ( )Sí  …  │
│ 3 Tamizaje         SCOFF 1/5 · negativo     BDDQ-AS · negativo                           │
│ 4 Resultado        ( ) Apto  ( ) No apto  (•) Diferir                                     │
│   Motivo* [Primero programa de peso ▾] [texto libre_____________]                         │
│                                                 [Sellar valoración en la historia]       │
```

### Registro de sesión
```
│ SESIÓN 2 de 4 · Hidrolipoclasia · 21/11/2026 10:30                                        │
│ ✓ Mayor de edad  ✓ Valoración apto (hasta 03/02/2027)  ✓ Consentimiento CI-000014         │
│ ⚠ Sin certificación registrada para «lipólisis por infiltración» (se registrará el aviso) │
│ Lista de verificación previa  ☑ Alergias ☑ Anticoagulación ☑ Embarazo ☑ Signos … (12/12)  │
│ Zona [Abdomen inferior ▾]  Componentes [del protocolo ▾] Volumen [___] mL                 │
│ Anestésico [Lidocaína 2 % ▾] Lote [L2345 · vence 03/2027 ✓] Volumen [10] mL               │
│            → 200 mg · 2,9 mg/kg (peso 69 kg, 12/11) · máximo del protocolo: [__] mg/kg     │
│ Equipo [________] Parámetros [____]   Duración [45] min   Eventos adversos [Ninguno ▾]     │
│ Insumos  Jeringa 10 mL × 2 (lote …)  [+]        → se descuentan del inventario al sellar  │
│ Indicaciones posteriores [de la plantilla…]   Control [28/11/2026]                        │
│                                                     [Sellar sesión en la historia]       │
```
- Si algo bloquea, el botón dice por qué («Falta el consentimiento firmado», «El lote L2345 venció el 01/11/2026»).

**Sesión en móvil (320 px):** una columna, un bloque plegable por paso (verificación, zona, anestésico, equipo, insumos, indicaciones) y el botón de sellar fijo abajo, con el motivo del bloqueo encima si lo hay:
```
┌──────────────────────────────┐
│ ← Sesión 2/4 · Hidrolipocl.  │
│ ✓ Apta ✓ Consent. ✓ ≥ 18     │
│ ▸ Verificación previa 12/12  │
│ ▾ Anestésico                 │
│   Lidocaína 2 % ▾            │
│   Lote L2345 · 03/2027 ✓     │
│   Volumen [10] mL            │
│   200 mg · 2,9 mg/kg ✓       │
│ ▸ Equipo  ▸ Insumos          │
│ [  Sellar sesión  ]          │
└──────────────────────────────┘
```

### Consentimiento con firma del paciente
```
│ CONSENTIMIENTO INFORMADO · Hidrolipoclasia · plan de 4 sesiones · CI-000014              │
│ ┌──────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ Procedimiento · Beneficios y alcance realista · Riesgos (frecuentes y graves) ·      │ │
│ │ Alternativas · Obligación de medio · Ruta de complicaciones · Póliza · Revocación    │ │
│ │ (texto de tu plantilla, desplazable)                                                 │ │
│ └──────────────────────────────────────────────────────────────────────────────────────┘ │
│ ☐ El paciente leyó el documento y resolvió sus dudas                                     │
│ Firma del paciente ┌──────────────── Firma aquí ────────────────┐   Médico: ✓ (tu firma) │
│                    └──────────────────────────────────────────────┘                      │
│                                                        [Firmar y guardar PDF]            │
```
- En tableta y celular, el lienzo ocupa el ancho completo. El PDF lleva las dos firmas, la fecha y la hora, la versión de la plantilla y la huella.

### Agenda
```
│ AGENDA   ‹  Hoy  ›  viernes 21/11/2026     [Día | Semana]     [+ Cita]   ⏰ Controles vencidos (7) │
│ 08:00 ┃ Primera vez · PEÑA MUÑOZ, José Á. · confirmada   [WhatsApp] [Ficha] [Atender] [$ Cobrar] │
│ 08:30 ┃ Control · TORRES RUIZ, Juan · agendada            [WhatsApp] …                          │
│ 09:00 ┃ ░░░░ Bloqueado: reunión ░░░░                                                            │
│ 10:30 ┃ Sesión hidrolipoclasia 2/4 · … · ✓ apta ✓ consentimiento                                │
│ Mañana: 3 citas sin recordatorio   PEÑA … 08:00 [Enviar]   TORRES … 08:30 [Enviar]   …        │
```
- **Semana:** una columna por día con bloques por tipo, distinguidos por color y por ícono, no solo por color.
- **Móvil:** solo la vista de día, deslizando entre días.
- **Atender** abre la historia nueva o la evolución, con el paciente cargado. **WhatsApp** abre `https://wa.me/57…?text=…` con el mensaje editable. Cada cita se puede exportar a `.ics`.

### Caja
```
│ CAJA · viernes 21/11/2026                         [+ Cobro] [Cierre del día] [Informes ▾] │
│ RC-000231  08:40  PEÑA MUÑOZ, José Á.  Consulta primera vez        80.000  Nequi    [Recibo] │
│ RC-000232  10:05  RÍOS …               Abono paquete 4 sesiones   440.000  Transfer. [Recibo] │
│ Sin recibo 10:45  …                    Sesión hidrolipoclasia (paquete 2/4) · saldo 2 sesiones │
│ Totales: efectivo 125.000 · transferencia 440.000 · Nequi 80.000 · Daviplata 0 · tarjeta 0     │
```
**Diálogo de cobro:**
```
┌ 💲 Cobro · PEÑA MUÑOZ, José Á. ────────────────────────────────────────────┐
│ [+ Servicio ▾]  Consulta de primera vez   1 ×  80.000            80.000    │
│                 Descuento [0] Motivo [______]                              │
│ Crédito disponible: valoración estética 70.000 (vence 05/12) [Aplicar]     │
│ Pagos  [Nequi ▾] [80.000] Ref. [____]   [+ Otro pago]                      │
│ Total 80.000 · Pagado 80.000 · Saldo 0                                     │
│                                   [Cancelar]  [Registrar y ver recibo]     │
└────────────────────────────────────────────────────────────────────────────┘
```
- **Cobro:** servicios del catálogo, descuento con motivo, crédito disponible por valoración abonable, abonos con medio y referencia, y saldo.
- **Informes:** mensual por servicio y por línea, volumen por técnica y exportación CSV.

### Inventario
```
│ INVENTARIO                         [+ Insumo] [+ Entrada]   ⚠ 2 bajo mínimo · ⏳ 1 vence en 30 días │
│ Lidocaína 2 % sin epinefrina · amp. 5 mL · INVIMA … · stock 14 (mín. 10) · 2 lotes            │
│ Jeringa 10 mL · ⚠ sin registro Invima · stock 40 (mín. 50)                                    │
│ Solución salina 0,9 % 500 mL · INVIMA … · lote S88 ⏳ vence 15/12/2026                          │
```

### Ajustes: consultorio, certificaciones y plantillas
```
│ AJUSTES   Consultorio | Certificaciones | Servicios y tarifas | Horario | Plantillas | Seguridad | Respaldo │
│ CONSULTORIO   Nombre [________]  Código de prestador (REPS) [__________]  NIT [__________]         │
│               Habilitación por servicio  Consulta externa medicina general [____] [+ servicio]     │
│               Póliza de complicaciones [aseguradora] [número] ( ) Sin póliza                       │
│ CERTIFICACIONES POR TÉCNICA                                                        [+ Agregar]     │
│   Lipólisis por infiltración / hidrolipoclasia · Entidad … · 10/06/2026 · vence 10/06/2031 ✓ [Soporte] │
│   Toxina botulínica · — · ⚠ sin certificación registrada                                           │
│ PLANTILLAS    Consentimiento hidrolipoclasia  v2 · aprobada 20/11/2026   [Editar] [Historial]      │
│               Autorización de datos           v1 · BORRADOR (sin aprobar) [Editar y aprobar]       │
```

### Modo presentación
```
│ Antes:  Firma y sello [ⓘ Por verificar]            Modo presentación: [ ○ ]   │
│ Después: Firma y sello                              Modo presentación: [ ● ]   │
```
- Un interruptor en la barra superior. Encendido, oculta los chips «Por verificar», las notas internas y los montos de la caja en las pantallas que ve el paciente. Se apaga solo al bloquear.

### Respaldo e importación (Ajustes)
```
│ RESPALDO     Último: 18/11/2026 10:12 · 412 pacientes · 1.284 fotos · 452 MB               │
│              [⬇ Respaldar ahora]  [⇪ Restaurar…]  [⇄ Paquete del equipo secundario]        │
│              Avisar cada [7] días · Espacio usado en este navegador: 0,5 GB de 40 GB       │
│              ✓ Almacenamiento persistente concedido                                        │
│ IMPORTAR PDF Resultado (38 archivos):  31 importadas · 4 ya estaban · 1 versión más nueva  │
│              ⚠ 1 alterada desde la evolución 2 (Historia_RIOS_…_v3.pdf)                    │
│              ✕ 1 no es de esta app (Factura.pdf)                                           │
```

### PDF nuevos (mismo estilo que hoy)
- **Informe de seguimiento (A4):**
  - encabezado y ficha del paciente iguales a la historia;
  - tabla de mediciones y gráficas de peso, IMC y cintura (`pw.Chart`), en escala de grises con el acento petróleo;
  - fotos, solo si las pides;
  - firma y sello.
- **Documentos (A4; recibo en A5):**
  - encabezado con logo y tus datos, título, número consecutivo, ficha del paciente y cuerpo;
  - firma del paciente cuando aplica, y tu firma y tu sello con los interruptores de hoy;
  - pie «historiasclinicas.net · CI-000014 · huella 3f9a·c21e · Pág. x de y»;
  - el recibo lleva en el cuerpo: «**Este documento no es una factura electrónica de venta.**» La nota sobre tus obligaciones ante la DIAN queda marcada VERIFICAR hasta que la revise tu contador.
- **Certificado, incapacidad, orden y remisión:** el mismo formulario corto para todos (plantilla, texto prellenado y editable, diagnóstico CIE-10 con el buscador de hoy, días o fechas cuando aplican) y vista previa del PDF real, como la receta.

---

## (d) Estructura de carpetas

```
lib/
  core/
    consultorio/                     # sin dependencias de interfaz
      config.dart                    # const consultorioHabilitado = bool.fromEnvironment(...)
      almacen/                       # base «historiasclinicas_consultorio»: registros y binarios,
                                     # transacciones, candado entre pestañas, persist(), migraciones
      seguridad/                     # llavero (sobre), derivación, AES-GCM con AAD, bloqueo
      modelos/                       # paciente, historia (índice), documento, medición, foto,
                                     # programa de peso, valoración, plantilla, sesión, cita,
                                     # servicio, cobro, paquete, insumo, lote, movimiento, configuración
      repositorio/                   # Coleccion<T>, índices en memoria, bitácora
      reglas/                        # bloqueos: menor de edad, no apto, consentimiento, lote, dosis,
                                     # certificación, contraindicaciones (puras, con pruebas por tabla)
      indice/                        # registrar historia, receta y documento; importación en lote
      respaldo/                      # .hcrespaldo y .hcpaquete: exportar, verificar, restaurar
      documentos/                    # PDF: informe, consentimiento, certificados, incapacidad,
                                     # orden, remisión, recibo; documento.json incrustado
      plantillas/                    # plantillas base (Dart const, marcadas BORRADOR). Los textos,
                                     # umbrales y protocolos se editan en la interfaz y se guardan
                                     # con versión en el almacén. Una técnica nueva (toxina, rellenos)
                                     # es un archivo de definición aquí, sin tocar el resto del módulo
      agenda/                        # disponibilidad, festivos, .ics, mensaje de WhatsApp
      caja/                          # totales, cierre, informes, CSV
      inventario/                    # existencias, vencimientos, FEFO
  features/
    consultorio/
      shell/                         # riel, menú lateral, búsqueda global, aviso de respaldo
      desbloqueo/                    # crear frase, desbloquear, recuperación, bloqueo por inactividad
      pacientes/  ficha/  seguimiento/  fotos/  peso/  estetica/  documentos/
      agenda/  caja/  inventario/  ajustes/  respaldo/  importacion/
      widgets/                       # gráficas, CampoMoneda, CampoCantidad, etiquetas neutras
test/consultorio/                    # unitarias y de widgets por subfase
tool/e2e/consultorio_offline.mjs     # flujo sin conexión con la bandera encendida
docs/FASE5.md, docs/fase5/           # este plan, resultados y capturas
```

**Archivos existentes que cambia la Fase 5.** Cada cambio va detrás de la bandera o no altera el comportamiento de hoy:

| Archivo | Cambio |
|---|---|
| `lib/app/router.dart` | `if (consultorioHabilitado)` usa las rutas del consultorio (5.0: `/ajustes`; después `/agenda`, `/pacientes`, `/pacientes/:id`, `/caja` e `/inventario`, con `initialLocation: '/agenda'` desde la 5.5). Apagada: las 3 rutas de hoy |
| `lib/features/historia/estado/historia_controller.dart` | Enganche en `guardado()` (sin esperar el resultado y sin lanzar errores, como IHCE) y `nuevaDesdePaciente()` |
| `lib/features/historia/historia_page.dart` | Pasar los bytes del PDF al enganche. Cortes con el ancho disponible (`LayoutBuilder`), que sin riel es el de hoy. Con la bandera: «← Ficha» y aviso de versión más nueva en el índice |
| `lib/features/historia/secciones/seccion_evoluciones.dart`, `lib/core/models/evolucion.dart`, `lib/core/pdf/historia_pdf.dart`, `lib/core/presentacion/datos_historia.dart` | Solo si eliges 15 (a): «Próximo control» opcional en la evolución, con la bandera encendida |
| `lib/features/receta/estado/receta_controller.dart`, `lib/features/receta/receta_page.dart`, `lib/core/pdf/receta_pdf.dart` | Con la bandera: `receta.json` incrustado y registro en la ficha |
| `lib/core/storage/borrador_store.dart`, `lib/core/storage/receta_store.dart` | Con la bandera: borrador y receta en curso en el almacén cifrado (pregunta 6) |
| `lib/core/pdf/piezas_pdf.dart`, `lib/core/pdf/historia_pdf.dart` | Extraer ficha del paciente, cabecera de sección y encabezado de página, sin cambiar el PDF (prueba de regresión) |
| `lib/features/medico/medico_page.dart`, `lib/core/widgets/dialogo_firma.dart` (nuevo) | `DialogoFirma` pasa a `lib/core/widgets/` con título y textos como parámetros, sin cambiar cómo se ve el del médico |
| `lib/core/widgets/campos.dart` | Variante neutra de `CampoEtiquetas` (sin el estilo de alergia). `CampoMoneda` y `CampoCantidad` van en archivos nuevos |
| `lib/core/archivos/archivos.dart`, `lib/core/archivos/archivos_web.dart`, `lib/core/archivos/archivos_stub.dart` | Elegir varios archivos, soltar varios y `capture` para la cámara |
| `tool/ihce/regla10.dart` | Aceptar el inventario de esta tabla y la carpeta `lib/features/consultorio/` (pregunta 8) |
| `tool/construir_web.sh`, `.github/workflows/ci.yml` | Carpeta de salida como parámetro, y un trabajo de CI que compila con la bandera encendida y corre el e2e del consultorio. **`pages.yml` no cambia** |
| `tool/e2e/historia_offline.mjs` | Paso nuevo: sin la bandera no existe la base del consultorio |

El código de IHCE (`lib/core/ihce/`, `lib/features/ihce/`) no cambia.

### Dependencias

**Ninguna nueva.** Todo sale de lo que ya está en `pubspec.yaml`:

| Necesidad | Con qué | Licencia |
|---|---|---|
| AES-256-GCM, PBKDF2 (WebCrypto) y Argon2id | `cryptography` ^2.9.0 (ya está, por IHCE) | Apache-2.0 |
| Llave no extraíble, `navigator.locks`, `navigator.storage.persist()`, IndexedDB con bytes, redimensionar la foto y quitar el EXIF (lienzo del navegador → JPEG) | `web` y `dart:js_interop` (ya están) | BSD-3 |
| ZIP del respaldo y del paquete | `archive` ^4.0.9 (ya está) | MIT |
| Gráficas en el PDF | `pdf` 3.12 (`pw.Chart`, ya está) | Apache-2.0 |
| Gráficas en pantalla | `CustomPainter` de Flutter | — |
| Huellas SHA-256 | `crypto` (ya está) | BSD-3 |

Si en la implementación algo exigiera un paquete nuevo (por ejemplo, `image` para procesar fotos fuera del lienzo del navegador), te lo pregunto antes, con su licencia y su peso.

---

## (e) Plan por subfases

**Cómo trabajo en todas las subfases:**
- Todo en la rama `claude/fase5-consultorio`, con el PR abierto hacia `main`. **Nunca hago push a `main`**, porque `pages.yml` publica en producción.
- **Antes de cada commit:** `dart format`, `flutter analyze` sin advertencias y `flutter test` en verde.
- **Al cerrar cada subfase:**
  - `./tool/construir_web.sh` compila, con y sin la bandera;
  - `tool/ihce/verificar.sh` en verde;
  - las e2e de siempre en verde, más la parte nueva de `tool/e2e/consultorio_offline.mjs`;
  - pruebas de **contraste** y de **320 px** de cada pantalla nueva;
  - `docs/FASE5.md` actualizado con lo hecho, las decisiones y las desviaciones;
  - capturas en `docs/fase5/` (escritorio 1440 px, móvil 390 px y 320 px).
- **Te muestro un resumen corto y las capturas, y me detengo hasta tu visto bueno.**

### 5.0 Cimientos
- La bandera `CONSULTORIO_ENABLED`, el contenedor y la navegación (solo lo construido hasta el momento).
- Almacén cifrado:
  - llavero en sobre, derivación (con la medición de PBKDF2 y Argon2id), AES-GCM con AAD;
  - colecciones, binarios, transacciones, candado entre pestañas, `persist()` y migraciones.
- Pantallas: crear frase, desbloquear, recuperar, bloqueo por inactividad y «Bloquear ahora».
- Respaldo: exportar, verificar y restaurar `.hcrespaldo`, aviso de vencimiento (con el texto de custodia) y bitácora.
- Guía para publicar la versión del consultorio (pregunta 2).
- **Pruebas de «bandera apagada = sitio de hoy»:**
  - configuración apagada por defecto;
  - el router tiene exactamente `/`, `/receta` y `/medico`, y `/pacientes` cae en la misma página de error que hoy;
  - el menú ⋮ y la barra de la historia tienen los mismos elementos que hoy, a 1920 y a 390 px;
  - con la bandera apagada no se abre ninguna base de IndexedDB del consultorio (se registra cada apertura, como se hace con las lecturas de secretos de IHCE);
  - `main.dart.js` compilado sin la bandera no contiene la marca del módulo;
  - en el e2e de siempre, `indexedDB.databases()` sigue vacío;
  - `pages.yml` no menciona `CONSULTORIO_ENABLED`.
- **Otras pruebas:**
  - cifrar y descifrar, y que un byte cambiado, otra AAD o una frase incorrecta fallen;
  - cambio de frase y recuperación con el código;
  - al bloquear, la app descarta la llave y ninguna operación del almacén funciona hasta desbloquear;
  - respaldo de ida y vuelta, y alteraciones detectadas (manifiesto, archivo, registro intercambiado, conteos);
  - contraste de los textos nuevos;
  - 320 px.
- **e2e:** crear frase, bloquear, desbloquear, respaldar y restaurar sin conexión, y que la compilación sin bandera no tenga nada del módulo.
- **Entrego:** capturas del desbloqueo, el respaldo y el aviso de respaldo vencido; la tabla de tiempos de PBKDF2 y Argon2id en tus equipos; la guía de publicación.

### 5.1 Pacientes
- Índice automático al finalizar la historia o descargar evoluciones. Si está bloqueado, la registra después.
- Importación en lote de PDF con el informe de resultados.
- Lista con búsqueda y filtros (última atención, línea, etiquetas, controles vencidos).
- Ficha longitudinal con línea de tiempo y «Abrir PDF».
- Historia, evolución y receta prellenadas desde la ficha. Aviso si se abre un PDF más viejo que el índice.
- Recetas con `receta.json` (bandera encendida).
- Autorización de tratamiento de datos, primer documento firmado. **Política de privacidad** en PDF para imprimir y exhibir en el consultorio (borrador para tu abogado). Unir fichas.
- **Pruebas:**
  - índice al sellar (revisión 1 y siguientes);
  - importación: íntegra, alterada desde *n*, dañada, ajena, duplicada, más nueva y divergente;
  - búsqueda sin tildes;
  - prellenado (sube `versionFormulario`);
  - la autorización firmada queda en la ficha, con su PDF y su huella;
  - rendimiento con 5.000 pacientes sintéticos.
- **e2e:** importar PDF de la Fase 4 (uno alterado), buscar, abrir la ficha, iniciar una evolución prellenada y verla en la línea de tiempo.
- **Entrego:** capturas de la lista, la ficha y el informe de importación; el resultado de rendimiento.

### 5.2 Seguimiento antropométrico y fotos
- Mediciones con IMC (`calcularImc`) e índice cintura-cadera, y gráficas con `CustomPainter`.
- Consentimiento de uso de imagen.
- Fotos cifradas: secuencia de vistas, guía de encuadre, foto anterior en transparencia, sin EXIF, miniaturas.
- Comparación lado a lado y cortina.
- Paquete del equipo secundario `.hcpaquete`.
- Informe de seguimiento en PDF (fotos solo si se piden).
- **Pruebas:**
  - cálculos;
  - sin consentimiento de imagen no hay fotos;
  - las fotos no entran al PDF de la historia ni al informe sin pedirlo;
  - EXIF eliminado;
  - foto cifrada en reposo;
  - paquete combinado sin duplicados;
  - informe en PDF.
- **e2e:** registrar mediciones, firmar el consentimiento de imagen, subir fotos (archivo de prueba), comparar y descargar el informe.
- **Entrego:** capturas del seguimiento, la comparación de fotos y la primera página del informe.

### 5.3 Programa de peso, valoración estética, consentimiento y sesiones
- **Programa de peso:**
  - meta, planes con plantillas y recordatorio de proteína y fuerza;
  - GLP-1 con catálogo, titulación, tolerancia y eventos adversos;
  - lista de contraindicaciones con bloqueo de las absolutas.
- **Valoración por plantilla declarativa (hidrolipoclasia):**
  - criterios, contraindicaciones y tamizajes;
  - resultado con motivo obligatorio y vigencia;
  - se sella como evolución.
- **Consentimiento informado** por plan de tratamiento, con firma del paciente, revocación y plantilla aprobada.
- **Sesión:**
  - lista de verificación previa, zonas, solución y anestésico con dosis en mg/kg;
  - lote y vencimiento escritos (un vencimiento pasado ya bloquea); el enlace con el inventario llega en la 5.7;
  - se sella como evolución.
- Certificaciones por técnica, con aviso.
- **Pruebas de reglas, por tabla:**
  - menor de 18 años;
  - «no apto» y «diferir»;
  - valoración vencida;
  - consentimiento faltante o revocado;
  - plantilla sin aprobar;
  - dosis por encima del máximo;
  - lote vencido;
  - contraindicación absoluta de GLP-1;
  - técnica sin certificación (aviso registrado).
- **e2e:** paciente → valoración → consentimiento firmado → sesión sellada (con una sesión bloqueada por consentimiento faltante y otra por lote vencido) → PDF de la historia con la evolución de la sesión.
- **Entrego:** capturas del programa de peso, la valoración, el consentimiento con firma y la sesión (escritorio, tableta y 320 px).

### 5.4 Documentos
- Certificado médico (general, laboral, deportivo y de asistencia), incapacidad (con los campos del Decreto 1427 de 2022), orden de laboratorio o imágenes con plantillas frecuentes, y remisión o interconsulta.
- Editor de plantillas con versiones.
- Numeración por tipo y anulación con motivo.
- **Pruebas:**
  - PDF de cada tipo, con `documento.json` incrustado y huella en el índice;
  - verificación al reabrir e importación en lote de documentos y recetas;
  - avisos de la incapacidad.
- **e2e:** un certificado y una orden con plantilla, descargados y reimportados.
- **Entrego:** capturas del formulario y la primera página de cada tipo de PDF.

### 5.5 Agenda
- Citas por tipo, duración y estado, con vista de día y de semana.
- Horario, bloqueos y festivos.
- WhatsApp con mensaje editable, lista de recordatorios del día siguiente y `.ics`.
- Desde la cita: ficha, atender y cobrar. Indicador de controles vencidos.
- **Pruebas:**
  - disponibilidad y cruces;
  - festivos;
  - estados;
  - URL de WhatsApp (codificación, número +57);
  - `.ics` válido y sin datos de salud;
  - no se agenda una sesión a un paciente no apto ni a un menor.
- **e2e:** agendar, cambiar estados, «Atender» con la historia prellenada y el enlace de WhatsApp interceptado (sin abrirlo).
- **Entrego:** capturas de la vista de día, la de semana y la de móvil.

### 5.6 Caja y paquetes
- Catálogo de servicios con tus tarifas iniciales.
- Cobros con medios de pago, abonos y saldo; paquetes con sesiones usadas y pendientes; crédito de la valoración abonable.
- Recibo PDF numerado con el aviso de que no es factura electrónica.
- Cierre diario e informe mensual por servicio y por línea, con CSV.
- Informe de volumen por técnica.
- **Pruebas:**
  - totales y saldos;
  - paquete agotado;
  - consecutivo sin saltos ni repetidos;
  - anulación (también la de un día cerrado);
  - día cerrado inmutable;
  - CSV.
- **e2e:** cobro con abono, paquete, recibo PDF (con el aviso de que no es factura) y cierre del día.
- **Entrego:** capturas de la caja, el cobro y el informe, y el recibo en PDF.

### 5.7 Inventario simple
- Insumos y lotes con stock mínimo, y entradas.
- Descuento automático al sellar la sesión. Sugerencia del lote que vence primero.
- Alertas de stock bajo y de vencimiento próximo. **Bloqueo de lote vencido o sin stock.**
- Registro Invima con aviso si falta (más visible en inyectables).
- **Pruebas:**
  - existencias por movimientos;
  - descuento al sellar;
  - lote vencido bloquea;
  - aviso sin registro Invima.
- **e2e:** entrada de un lote, sesión que lo descuenta y bloqueo con un lote vencido.
- **Entrego:** capturas del inventario con alertas.

### 5.8 Ajustes de presentación y cierre
- Notas «VERIFICAR» según tu respuesta a la pregunta 50, y modo presentación.
- Pulido de la navegación en escritorio y móvil.
- e2e completo sin conexión: paciente → valoración → consentimiento → sesión → cobro → respaldo.
- `docs/FASE5.md` con lo hecho, las decisiones y las desviaciones, y `README.md` con el estado y la estructura.
- **Pruebas:**
  - modo presentación (ningún «VERIFICAR» visible);
  - contraste de todo lo nuevo;
  - 320 px en cada pantalla.
- **Entrego:** el e2e completo en CI, las capturas finales y el README actualizado.

---

## Límites que conviene saber desde ya

- **Un navegador, un equipo.** Sin sincronización, el respaldo es lo único que te protege si el equipo se daña, se pierde o se borran los datos del sitio. Por eso es obligatorio y avisa.
- **Sin la frase ni el código de recuperación, los datos del consultorio no se pueden abrir.** Tampoco yo podría. Las historias sí se recuperan desde los PDF.
- **El cifrado protege el equipo apagado, perdido o curioseado; no un equipo comprometido.** Un programa malicioso en tu equipo podría ver lo que ves mientras está desbloqueado.
- **La cadena de huellas detecta alteraciones, pero no prueba la autoría** (igual que hoy).
- **La firma dibujada es una firma electrónica**, no una firma digital certificada (VERIFICAR su valor según el caso).
- **Las fotos y los datos de gestión no están en ningún PDF.** Su única custodia es el almacén y el respaldo.
- **No soy asesor legal.** Las plantillas de documentos y los textos normativos son borradores para que los revises tú y, idealmente, un abogado.

## Opciones para una Fase 6 (fuera de alcance)
- Varios usuarios con roles (auxiliar, recepción) y bitácora por usuario.
- Sincronización entre equipos o en la nube, cifrada de extremo a extremo.
- Recordatorios automáticos desde un servidor (WhatsApp Business API o SMS).
- Factura electrónica DIAN mediante un proveedor tecnológico, y RIPS (Resolución 2275 de 2023, VERIFICAR).
- Cámara en vivo con la guía encima (pregunta 21 b).
- Exportación al Registro Nacional de Procedimientos Médico-Estéticos, si el Proyecto de Ley 187 de 2026 se aprueba.
- Plantillas de toxina botulínica, rellenos (con el listado de sustancias modelantes permitidas de la Ley 2316) y bioestimuladores, según te certifiques.
- Envío de las valoraciones y sesiones a IHCE como RDA.

## Fuentes consultadas para este plan (todas VERIFICAR)
- Ley 2316 de 2023, texto compilado por Invima (arts. 1, 2, 4, 6 y 8 leídos): <https://normograma.invima.gov.co/normograma/compilacion/docs/ley_2316_2023.htm>; Decreto 545 de 2024 (según resultados de búsqueda, no leído): <https://normograma.invima.gov.co/normograma/compilacion/docs/decreto_0545_2024.htm>
- Proyecto de Ley 187 de 2026 Senado, ponencia para primer debate: páginas 28 a 32 de la Gaceta del Congreso 1571 de 2026, en una copia alojada por CER (un tercero; VERIFICAR contra la Gaceta oficial): <https://www.cerlatam.com/wp-content//uploads/2026/10/Ponencia-para-1er-debate-pl-187-1-1.pdf>. Resumen de CER: <https://www.cerlatam.com/?p=38709>
- Ley 1799 de 2016: <https://normograma.supersalud.gov.co/compilacion/docs/ley_1799_2016.htm>; Sentencia C-246 de 2017: <https://www.icbf.gov.co/cargues/avance/compilacion/docs/c-246_2017.htm>
- Decreto 1427 de 2022: <https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=191146>
- Invima, análogos de GLP-1 (único registro de semaglutida, OZEMPIC® 2019M-0019473, solo para diabetes tipo 2, según el resumen de búsqueda de esta página; fecha de la alerta por confirmar): <https://www.invima.gov.co/alertas-sanitarias/recomendaciones-de-uso-adecuado-de-medicamentos-con-el-grupo-de-principios-activos-analogos-a-glp-1>
- Invima, NAION con semaglutida: <https://www.invima.gov.co/alertas-sanitarias/riesgo-de-neuropatia-optica-isquemica-no-arterial-naion-con-el-uso-de-semaglutida>; alerta 090-2024 por semaglutida con vitamina B12: <https://www.invima.gov.co/biblioteca/alerta-sanitaria-semglutida-vitamina-b12-090-2024>
- Registro de Wegovy en Colombia, fuentes que se contradicen: <https://www.elcolombiano.com/inicio/medicamentos-aprobados-invima-bajar-peso-wegovy-ozempic-mounjaro-NA40373439> y Salud y Fármacos (<https://www.saludyfarmacos.org/?p=68782> o <https://www.saludyfarmacos.org/?p=68649>). Consultar el registro vigente en <https://consultaregistro.invima.gov.co>
- SCOFF, validación española (García-Campayo et al., *J Psychosom Res* 2005;59(2):51-55, doi:10.1016/j.jpsychores.2004.06.005)
- BDDQ-AS, traducción al español adaptada para Colombia (según el resultado de búsqueda; no leí el artículo completo): <https://scielo.isciii.es/pdf/cpil/v49n1/0376-7892-cpil-49-01-0035.pdf>. Instrumentos de dismorfia validados en español: <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5492913/>
- DIAN, servicios médicos excluidos de IVA y cirugía estética: <https://normograma.dian.gov.co/dian/compilacion/docs/oficio_dian_5421_2020.htm>
