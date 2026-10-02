# Fase 0: prueba de concepto (resultado)

**Estado: completada. Pendiente: que el médico elija la librería (A o B) antes de iniciar la Fase 1.**
Entorno: Flutter 3.38.10 (stable) y Dart 3.10.9, la misma versión que usa el médico.

## Qué se validó

| # | Requisito | Resultado | Cómo se comprobó |
|---|---|---|---|
| 1 | Generar un PDF con `historia.json` incrustado | ✅ | Se usan `/EmbeddedFiles` y `/AF` con tipo `application/json`. **pikepdf (qpdf) lo reconoce como adjunto**, igual que Acrobat |
| 2 | Reabrir el PDF en la app y leer los datos | ✅ | Tests de ida y vuelta (ñ, tildes, emoji, comillas) y prueba en Chromium |
| 3 | Agregar una evolución y descargar la versión actualizada | ✅ | Se genera `Historia_PENA_1032456789_v2.pdf` con revisión 2; la evolución anterior aparece sellada al reabrir |
| 4 | Todo sin conexión | ✅ | Chromium: se carga la app, **se corta la red** y se hace el ciclo completo. **0 peticiones fuera del sitio, 0 fallidas, 0 errores de consola** |
| 5 | Sobrescribir el mismo archivo (Chrome y Edge) | ✅ | Con la API de acceso a archivos simulada: "Guardar como…", sobrescribir y reabrir con el selector moderno |
| 6 | Navegadores sin esa API (Firefox, Safari) | ✅ | Selector clásico y descarga normal |
| 7 | PDF ajeno o dañado: mensaje claro y ofrecer historia nueva | ✅ | PDF de Chromium ("imprimir a PDF"), archivo que no es PDF, PDF truncado, JSON alterado, esquema más nuevo |
| 8 | Robustez frente a otro programa | ✅ | PDF de la app reescrito con pikepdf (adjunto comprimido y objetos en flujos de objetos): se lee bien |

`flutter analyze`: sin problemas. `flutter test`: 28 tests en verde.

## Comparación de librerías

| Criterio | **A: `pdf` + lector propio** | **B: `syncfusion_flutter_pdf`** |
|---|---|---|
| Licencia | `pdf` y `printing`: Apache-2.0; `archive`: MIT; `crypto`: BSD-3. **Sin condiciones** | **Comercial o Community License** (ver abajo) |
| Compatible con Flutter 3.38.10 | Sí (`pdf` 3.12.0, `printing` 5.14.3) | **Solo la 33.2.13.** La 35.x choca con `pdf` 3.12 por el paquete `xml` |
| Escribir el adjunto | Sí (`PdfaAttachedFiles`, mecanismo estándar) | Sí (`PdfAttachment`) |
| Leer el adjunto | Lector propio (unas 230 líneas, cubierto por tests) | Nativo |
| Lee PDF reescritos por otro programa | Sí (fixture de pikepdf) | Sí |
| Interoperabilidad | Lee PDF escritos por Syncfusion | Lee los PDF de la app |
| Peso añadido al JavaScript de la app | 0 (referencia) | **+338 KB** (+111 KB gzip, +87 KB brotli), solo por leer y escribir adjuntos |
| Lectura (PDF de 49 KB con 40 evoluciones) | 1,3 ms | 3,2 ms |
| Generación de PDF e impresión | `pdf` + `printing` (ya integrados) | Seguiría haciendo falta `pdf` + `printing`, o reescribir todo con Syncfusion |
| Mantenimiento | Código propio acotado a nuestros PDF | Dependencia grande, con versiones atadas a las de Flutter |

### Condiciones de la Syncfusion Community License (verificadas el 02/10/2026)
- **Archivo LICENSE del paquete:** ingresos brutos menores a USD 1.000.000 al año, **menos de 5 desarrolladores** y aceptar los términos de `syncfusion_license.pdf`.
- **Web de Syncfusion:** como máximo 5 desarrolladores y **10 empleados en total**; la entidad **nunca debe haber recibido más de USD 3.000.000** de capital externo; **excluye organizaciones gubernamentales** (financiadas con impuestos).
- Sin la Community License o una licencia comercial **no se puede usar** el paquete.

### Recomendación: **A**
Cumple todos los requisitos sin condiciones de licencia, pesa menos, no ata el proyecto a Syncfusion y ya está integrada y probada. Si en el futuro hiciera falta editar PDF ajenos, B se podría reconsiderar.

## Hallazgos técnicos y cómo se resolvieron
1. **Flutter Web pedía fuentes a Google** (`fonts.gstatic.com`): Roboto al arrancar y Noto Symbols para los caracteres que faltan.
   - Solución: un `web/flutter_bootstrap.js` propio con `fontFallbackBaseUrl: 'fonts/'` y Roboto (63 KB) servida localmente.
   - Inter se recorta con latín, griego (β, µ, γ), flechas, operadores matemáticos y símbolos (✓ ✗ ℞ ₂ °).
   - Límite: lo que Inter no cubre (emoji, alfabetos asiáticos, ♀ ♂) se verá como un recuadro sin conexión. La ruta de Roboto depende de la versión de Flutter; si se actualiza Flutter, solo se pierde esa fuente de respaldo, sin peticiones externas.
2. **CanvasKit local:** compilar siempre con `flutter build web --release --no-web-resources-cdn`.
3. **`pdf` 3.12:** el parámetro se llama `AFRelationship`; en la 3.13 pasa a ser `afRelationship`. Está comentado en el código.
4. **`printing`** solo descarga pdf.js de `unpkg.com` para la *vista previa*, no para imprimir. En la Fase 3 se incluirá pdf.js en el sitio.
5. **Primera carga:** en esta fase la app debe cargarse con conexión al menos una vez por sesión. El service worker (Fase 4) la dejará disponible sin red desde la segunda visita.
6. **Imprimir** abre el diálogo del navegador. No se puede automatizar en modo sin ventana: **verifícalo en tu Chrome**.
7. **Fallo real encontrado por la prueba y corregido:** las fuentes del PDF se cargaban en el primer guardado. Si la conexión se perdía antes, guardar fallaba (aparecía de forma intermitente, 2 de cada ~10 ejecuciones). Ahora se precargan al iniciar la app y se reintenta si fallan. Se verificó con un servidor **sin caché** (`Cache-Control: no-store`), que antes reproducía el fallo siempre: 3 de 3 correctas tras la corrección.
8. **Entorno de pruebas:** sin `LANG`, Chromium del contenedor reporta el idioma `en-US@posix` (inválido) y Flutter no arranca. No ocurre en navegadores reales; las pruebas fijan `es-CO`.

## Formato del adjunto (`historia.json`)
JSON canónico: claves ordenadas, solo ASCII, sin espacios.
```
{"app":"historiasclinicas.net","datos":{…},"guardadoEn":"…Z","revision":2,"schemaVersion":1,"sha256":"<hash de datos>"}
```
`sha256` detecta adjuntos dañados o truncados. La cadena de hashes por evolución llega en la Fase 4.

## Cómo reproducirlo
```bash
flutter pub get
flutter analyze && flutter test
flutter build web --release --no-web-resources-cdn
python3 -m http.server 8765 --directory build/web    # en otra terminal
cd tool/e2e && npm install && npx playwright install chromium && node fase0_offline.mjs
# Variante exigente: un servidor que no deja cachear (Cache-Control: no-store)
# y BASE_URL=http://localhost:PUERTO/ node fase0_offline.mjs
```
En tu Mac también puedes probarla a mano con `flutter run -d chrome --release --no-web-resources-cdn`.

## Evidencias
- `docs/fase0/historia_nueva.png`, `historia_abierta.png`, `error_pdf_ajeno.png`: capturas de la prueba sin conexión.
- `docs/fase0/pdf_historia_v2.png`: vista del PDF generado.
- `docs/fase0/Historia_PENA_1032456789.pdf` y `_v2.pdf`: ábrelos en Acrobat y mira el panel de adjuntos (📎): verás `historia.json`.
