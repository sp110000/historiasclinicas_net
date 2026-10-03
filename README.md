# historiasclinicas.net

Historia clínica y receta en el navegador. Sin servidor, sin base de datos y sin conexión tras la primera carga. El único registro es el PDF que descarga el médico: lleva los datos incrustados (`historia.json`) y una cadena de huellas SHA-256, para reabrirlo otro día y añadir evoluciones al final.

**Estado:** las cuatro fases están completadas: historia clínica, datos del médico con firma y sello, receta A5, CIE-10 de SISPRO incluido, PDF final, app instalable sin conexión y guía de despliegue. Diseño visual 2b «Clínico sobrio» en [docs/DISENO.md](docs/DISENO.md). Ver [docs/FASE4.md](docs/FASE4.md), [docs/FASE3.md](docs/FASE3.md), [docs/FASE2.md](docs/FASE2.md), [docs/FASE1.md](docs/FASE1.md), [docs/FASE0.md](docs/FASE0.md) y el plan en [docs/PLAN.md](docs/PLAN.md). **Para publicar: [docs/DESPLIEGUE.md](docs/DESPLIEGUE.md).**

## Requisitos
- Flutter **3.38.10** (stable), Dart 3.10.9.

## Desarrollo
```bash
flutter clean && flutter pub get   # tras cambiar dependencias o hacer git pull
flutter run -d chrome
flutter analyze
flutter test
```

## Compilar el sitio (sin CDN, sin conexión)
```bash
./tool/construir_web.sh
```
El resultado queda en `build/web/` y es lo que se publica (ver [docs/DESPLIEGUE.md](docs/DESPLIEGUE.md)). El script compila con `--no-web-resources-cdn` y genera `sw.js`, el service worker que guarda la app en el navegador para usarla sin conexión. CanvasKit, las fuentes, el CIE-10 y pdf.js (vista previa de la receta, en `web/pdfjs/`) se sirven desde el propio sitio, sin peticiones a terceros.

## Pruebas de extremo a extremo (Chromium, sin conexión)
```bash
cd tool/e2e && npm install && npx playwright install chromium && cd ../..
node tool/e2e/servidor.mjs &       # build/web con las cabeceras de producción (CSP)
node tool/e2e/historia_offline.mjs # historia, receta y PDF; pide pikepdf (pip) y poppler-utils (pdfinfo, pdftotext)
node tool/e2e/pwa_offline.mjs      # app instalada: recargar sin conexión, actualizar, integridad
```
GitHub Actions: `.github/workflows/ci.yml` ejecuta formato, análisis, tests, compilación y las dos pruebas en cada push, y `.github/workflows/pages.yml` publica el sitio en GitHub Pages (`historiasclinicas.net`) en cada push a `main`. Pasos en [docs/DESPLIEGUE.md](docs/DESPLIEGUE.md).

## Estructura
```
lib/
  app/              tema, rutas (go_router: /, /receta y /medico), MaterialApp
  core/
    archivos/       abrir PDF, imágenes, JSON y catálogos; guardar, descargar y soltar (web)
    cie10/          catálogo CIE-10: el incluido (SISPRO) y el importado (Excel, CSV, JSON; IndexedDB)
    clinica/        edad, IMC, gestación, rangos de signos vitales
    imagenes/       firma, sello y logo: quitar fondo, recortar, reducir
    integridad/     JSON canónico y cadena SHA-256
    models/         historia, paciente, antecedentes, revisión por sistemas, signos, diagnósticos, evoluciones, médico
    pais/           perfiles Colombia y España
    pdf/            historia.json incrustado (escritura y lectura), PDF de la historia y de la receta, fuentes, vista previa con pdf.js
    presentacion/   textos de cada sección (pantalla y PDF)
    pwa/            avisos del service worker (sin conexión, versión nueva)
    receta/         ítems, número en letras, cantidad sugerida, alertas, "Mis medicamentos"
    storage/        preferencias, borrador, médico, receta y "Mis medicamentos" (localStorage)
    widgets/        campos de formulario (con sugerencias), tarjeta de sección, lienzo de firma
  features/
    historia/       pantalla, estado (Riverpod), formularios, evoluciones
    cie10/          estado del catálogo e importación
    medico/         datos del médico, firma (dibujada o subida), sello y logo
    receta/         receta A5: editor, vista previa real, alertas, numeración
    pwa/            mostrar los avisos y recargar sin perder lo pendiente
assets/cie10/       tabla de referencia CIE-10 de SISPRO (12.634 códigos)
test/               unitarios, PDF, widgets, service worker y configuraciones de despliegue
web/                index.html, manifest, iconos, cabeceras (_headers, .htaccess) y pdfjs/
web/pdfjs/          pdf.js 3.2.146 (Mozilla, Apache 2.0) para la vista previa, sin CDN ni eval
tool/construir_web.sh  compila el sitio y genera el service worker
tool/pwa/           plantilla y generador del service worker; CSP dentro del HTML (GitHub Pages)
tool/cie10/         genera el catálogo incluido desde el Excel de SISPRO
tool/e2e/           servidor con cabeceras, pruebas en Chromium, inspección y alteración de PDF
firebase.json, vercel.json, .vercelignore   configuración de esos proveedores
.github/workflows/  CI (análisis, tests, compilación, pruebas en Chromium) y publicación en GitHub Pages
```

## Licencias de terceros
- **Inter** (fuentes de la interfaz y de los PDF): SIL Open Font License 1.1.
- **pdf.js** 3.2.146 de Mozilla (`web/pdfjs/`): Apache License 2.0 (ver `web/pdfjs/LICENSE`).
- **CIE-10** (`assets/cie10/`): tabla de referencia de SISPRO, del Ministerio de Salud y Protección Social de Colombia, actualizada el 15/09/2026. La CIE-10 es una clasificación de la OMS: **VERIFICAR** las condiciones de redistribución si el sitio se vuelve comercial.
