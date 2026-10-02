# Fase 4: PDF final, app sin conexión y despliegue (resultado)

**Estado: completada.** Con esta fase quedan terminadas las cuatro. Entorno: Flutter 3.38.10 y Dart 3.10.9.

## Qué incluye

### 1. CIE-10 de SISPRO incluido
- La app trae la **tabla de referencia CIE-10 de SISPRO completa**: 12.634 códigos, todos habilitados, actualizada el 15/09/2026. Es la que enviaste y se usa para Colombia y España.
  - Está en `assets/cie10/cie10_sispro.txt` (800 KB; unos 130 KB comprimida al enviarse).
  - Se lee la primera vez que se busca un diagnóstico y funciona sin conexión.
- **En "Diagnósticos":** se busca por palabras, sin importar tildes ni mayúsculas ("hipertension esencial" → I10X), o por código, con o sin punto ("J02.9" → J029). Al elegir una opción se completan el código y la descripción, que conservan el texto oficial de SISPRO.
- **Otra versión:** "Catálogo" → "Importar otro…" acepta **el Excel de SISPRO tal como se descarga** (.xlsx), además de CSV, TXT y JSON.
  - Omite las filas con "Habilitado" = NO.
  - La versión importada reemplaza a la incluida solo en ese navegador, y "Volver al incluido" la deshace.
- **Para actualizar la incluida** cuando SISPRO publique otra versión:
  ```bash
  dart run tool/cie10/generar_catalogo.dart TablaReferencia_CIE10.xlsx 2026-09-15
  ```
  Después hay que actualizar la cantidad y la fecha en `lib/core/cie10/catalogo_incluido.dart`. Un test comprueba que coincidan.
- **España:** la tabla de SISPRO usa los códigos de la OMS (4 caracteres, por ejemplo J029). La **CIE-10-ES** oficial de España tiene códigos más detallados (J02.9, S72.001A). Para la historia clínica sirven los de la OMS. Si en algún momento necesitas la CIE-10-ES, se importa con "Importar otro…".

### 2. PDF final de la historia
- **Los textos largos ya no bloquean el PDF.** Antes, un campo o una evolución de más de una página (por ejemplo, una enfermedad actual muy extensa) **impedían generar el PDF**. Ahora el texto continúa en la página siguiente. Lo mismo vale para la receta, en las indicaciones y en un ítem larguísimo.
- **Saltos de página más limpios:**
  - El título de cada sección va siempre con su primera fila de datos.
  - Las filas de datos no se parten.
  - "11. Evoluciones" va pegado a la primera evolución.
  - Una evolución corta no se parte entre páginas.
- **Cada evolución** tiene una línea superior con el número, la fecha y la huella; debajo, el texto, los signos vitales y la firma de su autor.
- **Se mantiene:**
  - A4.
  - Encabezado con logo, médico y paciente en cada página, y "Pág. X de Y".
  - Escala de grises, apta para blanco y negro.
  - Datos incrustados y cadena de huellas.
  - Nombres `Historia_{APELLIDO}_{documento}_vN.pdf`.
- **Tests nuevos:**
  - Todas las páginas son A4.
  - Un texto de varias páginas continúa y la historia se reabre intacta.
  - **Cambiar una letra de la evolución 2 da "Se detectaron alteraciones desde la evolución 2"**, incluso si quien la cambió reescribió el PDF completo con otro programa.
  - La receta larga ocupa varias hojas A5.

### 3. App instalable y sin conexión (PWA)
- **Service worker propio** (`tool/pwa/sw.plantilla.js`):
  - **Primera visita:** guarda en el navegador los 30 archivos de la app (8,6 MB): código, fuentes, iconos, el CIE-10 y pdf.js.
  - **Motor gráfico:** de sus variantes, guarda solo la que el navegador usó, sin descargar las demás (unos 12 MB).
  - **Sin conexión**, la app abre al recargar, en una pestaña nueva o desde el ícono instalado.
- **Avisos en la app:**
  - "Listo: la app quedó guardada en este navegador y ya funciona sin conexión" la primera vez.
  - "Hay una versión nueva de la app" con el botón **"Actualizar"**, que antes de recargar guarda el borrador, la receta y los datos del médico.
- **Actualizaciones eficientes y seguras:**
  - Cada archivo lleva su huella SHA-256, y una versión nueva solo descarga lo que cambió.
  - Si el servidor entrega un archivo que no coincide con su huella (por ejemplo, un CDN con caché vieja), la versión nueva **se rechaza** y la instalada sigue funcionando.
- **Un solo comando para compilar:** `./tool/construir_web.sh` compila y genera `sw.js`.
- **Iconos propios:** una hoja clínica con la cruz, en los colores de la app. Hay versiones normal, *maskable* (Android), para iPhone (apple-touch) y favicon. El manifest tiene `id` y `scope`, y la app se puede instalar desde el navegador.
- **Funciona en subcarpetas** (`--base-href /historias/`), comprobado sin conexión.

### 4. Seguridad
- Cabeceras recomendadas, con la misma configuración para Netlify, Cloudflare, Firebase, Vercel, Apache y Nginx:
  - **Content-Security-Policy** estricta: solo código del propio sitio, sin `eval`, y la app solo se conecta a su propio dominio.
  - HSTS, `nosniff`, `Referrer-Policy`, `Permissions-Policy` y `Cross-Origin-Opener-Policy`.
- **Vista previa de la receta sin `eval`:** el paquete `printing` usaba `eval` para dibujarla. La CSP lo bloquea, así que ahora la app dibuja la vista previa con pdf.js directamente (`web/pdfjs/iniciar.js` y `lib/core/pdf/rasterizar_web.dart`).
- **Imprimir con la CSP activa:** `printing` imprime con un pequeño `<script>` en línea. La CSP lo permite por su huella, y hay una copia en un archivo del sitio por si una versión nueva del paquete lo cambia. Un test avisa si la huella deja de coincidir.
- Las dos pruebas en Chromium corren con estas cabeceras. Cualquier bloqueo de la CSP cuenta como error, y no hubo ninguno.

### 5. Despliegue e integración continua
- **[docs/DESPLIEGUE.md](DESPLIEGUE.md):**
  - Compilar.
  - Probar en tu equipo.
  - Netlify (recomendado), Cloudflare Pages, Firebase, Vercel, hosting tradicional (cPanel/Apache), Nginx y GitHub Pages.
  - Dominio `historiasclinicas.net`.
  - Comprobaciones después de publicar.
  - Cómo se actualiza la app.
  - Qué hace cada cabecera.
  - Notas para tu aviso de privacidad.
- **Configuraciones listas:**
  - En `build/web`, que es lo que se publica: `_headers` (Netlify/Cloudflare) y `.htaccess` (Apache).
  - En la raíz del proyecto: `firebase.json`, `vercel.json` y `.vercelignore`.
- **GitHub Actions** (`.github/workflows/ci.yml`), en cada push y pull request:
  - Formato, análisis y tests.
  - Compila el sitio y lo deja como artefacto **`sitio-web`**, listo para publicar.
  - Ejecuta las dos pruebas en Chromium con las cabeceras de producción.
  - No publica nada por sí solo.

## Verificación
| Comprobación | Resultado |
|---|---|
| `flutter analyze` y `dart format` | Sin problemas |
| `flutter test` | **174 tests en verde** (eran 160; **+14**). **CIE-10 incluido:** los 12.634 códigos, sin repetidos, con búsquedas reales. **Excel:** columnas, celdas vacías y "Habilitado". **PDF:** A4, textos de varias páginas, alteración en la evolución 2 y receta larga. **Service worker:** lista de archivos, exclusiones y versión. **Avisos:** "Actualizar" guarda antes lo pendiente. **Despliegue:** las cinco configuraciones (Netlify/Cloudflare, Firebase, Vercel, Apache, Nginx) iguales y la huella de `printing` |
| Prueba en Chromium sin conexión (`historia_offline.mjs`), **con la CSP de producción** | **23 de 23 pasos.** Ahora la red se corta cuando la app ya quedó guardada, y **cualquier petición fallida cuenta como error**. Antes las fallidas del sitio se toleraban |
| Prueba de la app instalada (`pwa_offline.mjs`), con la CSP | **8 de 8 pasos.** Guardado en la primera visita; sin conexión, recargar, abrir otra pestaña, buscar en el CIE-10, vista previa y PDF A5 de la receta. Versión nueva con descarga solo de lo que cambió; "Actualizar" conserva lo escrito; un archivo alterado hace rechazar la versión |
| Subcarpeta (`--base-href /historias/`) | Se instala y abre sin conexión |
| En todas las pruebas | **0 peticiones externas, 0 fallidas, 0 errores de consola** (incluidos los bloqueos de la CSP) |

## Problemas encontrados y corregidos
1. **El PDF no se generaba con textos de más de una página.** Un campo o una evolución muy largos rompían la generación. En la versión publicada podía fallar o quedarse cargando sin terminar. Ahora el texto continúa en la página siguiente (punto 2).
2. **La vista previa de la receta usaba `eval`** (dentro del paquete `printing`), que una política de seguridad estricta bloquea. Se reemplazó por un dibujo propio con pdf.js, sin `eval`.
3. **Imprimir** dependía de un `<script>` en línea del mismo paquete. La CSP lo permite por su huella, y hay una copia de respaldo.
4. **Los iconos eran los de Flutter:** ahora son propios.
5. **En equipos lentos se perdía el aviso "ya funciona sin conexión".** La app quedaba guardada igual, pero no lo avisaba. Lo detectó la primera ejecución en GitHub Actions y lo reproduje con la CPU 6 veces más lenta (0 de 3). Si el service worker terminaba antes de que la app arrancara, el aviso se perdía o se tomaba la primera instalación por una actualización. Ahora `flutter_bootstrap.js` recoge los avisos desde que abre la página y se los entrega a la app cuando está lista (3 de 3).

## Límites que conviene recordar
- **La primera visita necesita conexión y HTTPS.** El aviso "ya funciona sin conexión" confirma que quedó guardada.
- **Lo guardado en el navegador depende de la dirección.** `historiasclinicas.net` y `www.historiasclinicas.net` cuentan como sitios distintos: elige una sola dirección definitiva. Esto afecta al borrador, los datos del médico, la numeración y "Mis medicamentos".
- **Safari (iPhone, iPad, Mac):** si la app no se abre durante varias semanas, Safari puede borrar lo guardado en el navegador. Instalarla en la pantalla de inicio lo evita en buena medida (VERIFICAR según la versión de iOS). Las historias no se pierden, porque están en los PDF.
- **Proveedores de hosting:** no pude publicar en ninguno desde aquí. Las configuraciones se probaron con un servidor local que aplica las mismas cabeceras. Vercel queda como **VERIFICAR**.
- **CIE-10:** es una clasificación de la OMS, y la tabla de referencia es pública en SISPRO. **VERIFICAR** las condiciones de redistribución si el sitio se vuelve comercial.

## Cómo probarla en tu Mac
```bash
git pull
flutter clean && flutter pub get
flutter run -d chrome                 # desarrollo (sin service worker)

# Como en producción, con el modo sin conexión:
./tool/construir_web.sh
node tool/e2e/servidor.mjs            # o: python3 -m http.server 8765 --directory build/web
```
Abre `http://localhost:8765` y espera el aviso "ya funciona sin conexión". Después prueba sin red: F12 → *Network* → *Offline* (o desconecta el wifi) y recarga. Para publicar, sigue [DESPLIEGUE.md](DESPLIEGUE.md).

## Evidencias (`docs/fase4/`)
- `lista_sin_conexion.png`: el aviso tras la primera visita.
- `cie10_sin_conexion.png`, `receta_sin_conexion.png`: CIE-10 y receta con vista previa, recargada **sin conexión**.
- `version_nueva.png`: el aviso de versión nueva con "Actualizar".
- `catalogo_cie10.png`: el catálogo de SISPRO incluido.
- `pdf_historia_final.png` y `Historia_PENA_1032456789_v2.pdf`: el PDF final (de la prueba en Chromium), con una evolución firmada.
- `pdf_texto_largo.png` y `historia_texto_largo.pdf`: un texto de varias páginas que continúa.
- `iconos.png`: iconos normal, maskable, pequeño y favicon.
