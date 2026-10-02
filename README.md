# historiasclinicas.net

Historia clínica y receta en el navegador. Sin servidor, sin base de datos y sin conexión tras la primera carga. El único registro es el PDF que descarga el médico: lleva los datos incrustados (`historia.json`) y una cadena de huellas SHA-256, para reabrirlo otro día y añadir evoluciones al final.

**Estado:** Fase 1 completada (historia clínica). Ver [docs/FASE1.md](docs/FASE1.md), [docs/FASE0.md](docs/FASE0.md) y el plan en [docs/PLAN.md](docs/PLAN.md).

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
node historia_offline.mjs          # opcional: pip install pikepdf (caso "PDF alterado")
```

## Estructura
```
lib/
  app/              tema, rutas (go_router: / y /receta), MaterialApp
  core/
    archivos/       abrir, guardar, sobrescribir y soltar PDF (web)
    clinica/        edad, IMC, gestación, rangos de signos vitales
    integridad/     JSON canónico y cadena SHA-256
    models/         historia, paciente, antecedentes, signos, diagnósticos, evoluciones
    pais/           perfiles Colombia y España
    pdf/            historia.json incrustado (escritura y lectura), PDF de la historia, fuentes
    presentacion/   textos de cada sección (pantalla y PDF)
    storage/        preferencias y borrador (localStorage)
    widgets/        campos de formulario, tarjeta de sección
  features/
    historia/       pantalla, estado (Riverpod), formularios, evoluciones
    receta/         receta (Fase 3)
test/               unitarios, PDF y widgets
tool/e2e/           prueba en Chromium sin conexión
```
