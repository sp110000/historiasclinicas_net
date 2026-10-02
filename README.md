# historiasclinicas.net

Historia clínica y receta en el navegador. Sin servidor, sin base de datos y sin conexión tras la primera carga. El único registro es el PDF que descarga el médico: lleva los datos incrustados (`historia.json`) y una cadena de huellas SHA-256, para reabrirlo otro día y añadir evoluciones al final.

**Estado:** Fase 3 completada (historia clínica, datos del médico con firma y sello, y receta A5). Ver [docs/FASE3.md](docs/FASE3.md), [docs/FASE2.md](docs/FASE2.md), [docs/FASE1.md](docs/FASE1.md), [docs/FASE0.md](docs/FASE0.md) y el plan en [docs/PLAN.md](docs/PLAN.md).

## Requisitos
- Flutter **3.38.10** (stable), Dart 3.10.9.

## Desarrollo
```bash
flutter clean && flutter pub get   # tras cambiar dependencias o hacer git pull
flutter run -d chrome
flutter analyze
flutter test
```

## Compilar el sitio (sin CDN)
```bash
flutter build web --release --no-web-resources-cdn
```
El resultado queda en `build/web/`. CanvasKit, las fuentes y pdf.js (vista previa de la receta, en `web/pdfjs/`) se sirven desde el propio sitio, sin peticiones a terceros.

## Prueba de extremo a extremo (Chromium, sin conexión)
```bash
python3 -m http.server 8765 --directory build/web &
cd tool/e2e && npm install && npx playwright install chromium
node historia_offline.mjs          # opcional: pikepdf (pip) y poppler-utils (pdfinfo, pdftotext) para inspeccionar los PDF
```

## Estructura
```
lib/
  app/              tema, rutas (go_router: /, /receta y /medico), MaterialApp
  core/
    archivos/       abrir PDF, imágenes, JSON y catálogos; guardar, descargar y soltar (web)
    cie10/          catálogo CIE-10 importado (lectura, búsqueda, IndexedDB)
    clinica/        edad, IMC, gestación, rangos de signos vitales
    imagenes/       firma, sello y logo: quitar fondo, recortar, reducir
    integridad/     JSON canónico y cadena SHA-256
    models/         historia, paciente, antecedentes, revisión por sistemas, signos, diagnósticos, evoluciones, médico
    pais/           perfiles Colombia y España
    pdf/            historia.json incrustado (escritura y lectura), PDF de la historia y de la receta, fuentes
    presentacion/   textos de cada sección (pantalla y PDF)
    receta/         ítems, número en letras, cantidad sugerida, alertas, "Mis medicamentos"
    storage/        preferencias, borrador, médico, receta y "Mis medicamentos" (localStorage)
    widgets/        campos de formulario (con sugerencias), tarjeta de sección, lienzo de firma
  features/
    historia/       pantalla, estado (Riverpod), formularios, evoluciones
    cie10/          estado del catálogo e importación
    medico/         datos del médico, firma (dibujada o subida), sello y logo
    receta/         receta A5: editor, vista previa real, alertas, numeración
test/               unitarios, PDF y widgets (fixtures: PDF reescrito, muestra CIE-10 no oficial)
web/pdfjs/          pdf.js 3.2.146 (Mozilla, Apache 2.0) para la vista previa, sin CDN
tool/e2e/           prueba en Chromium sin conexión, inspección y alteración de PDF
```

## Licencias de terceros
- **Inter** (fuentes de la interfaz y de los PDF): SIL Open Font License 1.1.
- **pdf.js** 3.2.146 de Mozilla (`web/pdfjs/`): Apache License 2.0 (ver `web/pdfjs/LICENSE`).
