# historiasclinicas.net

Historia clínica y receta en el navegador. Sin servidor, sin base de datos y sin conexión tras la primera carga. El único registro es el PDF que descarga el médico: lleva los datos incrustados (`historia.json`) y una cadena de huellas SHA-256, para reabrirlo otro día y añadir evoluciones al final.

**Estado:** Fase 2 completada (historia clínica, y datos del médico con firma y sello). Ver [docs/FASE2.md](docs/FASE2.md), [docs/FASE1.md](docs/FASE1.md), [docs/FASE0.md](docs/FASE0.md) y el plan en [docs/PLAN.md](docs/PLAN.md).

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
El resultado queda en `build/web/`. CanvasKit y las fuentes se sirven desde el propio sitio, sin peticiones a terceros.

## Prueba de extremo a extremo (Chromium, sin conexión)
```bash
python3 -m http.server 8765 --directory build/web &
cd tool/e2e && npm install && npx playwright install chromium
node historia_offline.mjs          # opcional: pip install pikepdf (PDF alterado e inspección del PDF)
```

## Estructura
```
lib/
  app/              tema, rutas (go_router: /, /receta y /medico), MaterialApp
  core/
    archivos/       abrir PDF e imágenes, guardar, sobrescribir y soltar (web)
    clinica/        edad, IMC, gestación, rangos de signos vitales
    imagenes/       firma, sello y logo: quitar fondo, recortar, reducir
    integridad/     JSON canónico y cadena SHA-256
    models/         historia, paciente, antecedentes, revisión por sistemas, signos, diagnósticos, evoluciones, médico
    pais/           perfiles Colombia y España
    pdf/            historia.json incrustado (escritura y lectura), PDF de la historia, fuentes
    presentacion/   textos de cada sección (pantalla y PDF)
    storage/        preferencias, borrador y datos del médico (localStorage)
    widgets/        campos de formulario, tarjeta de sección, lienzo de firma
  features/
    historia/       pantalla, estado (Riverpod), formularios, evoluciones
    medico/         datos del médico, firma (dibujada o subida), sello y logo
    receta/         receta (Fase 3)
test/               unitarios, PDF y widgets
tool/e2e/           prueba en Chromium sin conexión, inspección y alteración de PDF
```
