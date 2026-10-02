# historiasclinicas.net

Historia clínica y receta en el navegador. Sin servidor, sin base de datos y sin conexión tras la primera carga. El único registro es el PDF que descarga el médico, que lleva los datos incrustados (`historia.json`) para poder reabrirlo y añadir evoluciones.

**Estado:** Fase 0 (prueba de concepto) completada. Ver [docs/FASE0.md](docs/FASE0.md) y el plan en [docs/PLAN.md](docs/PLAN.md).

## Requisitos
- Flutter **3.38.10** (stable), Dart 3.10.9.

## Desarrollo
```bash
flutter pub get
flutter run -d chrome                      # desarrollo
flutter analyze
flutter test
```

## Compilar el sitio (sin CDN)
```bash
flutter build web --release --no-web-resources-cdn
```
El resultado queda en `build/web/`. CanvasKit y las fuentes se sirven desde el propio sitio, sin peticiones a terceros.

## Prueba sin conexión en Chromium
```bash
python3 -m http.server 8765 --directory build/web &
cd tool/e2e && npm install && npx playwright install chromium
node fase0_offline.mjs
```

## Estructura
```
lib/
  app/            tema visual
  core/
    archivos/     abrir, guardar, sobrescribir y soltar PDF (web)
    integridad/   JSON canónico y SHA-256
    pdf/          adjunto historia.json (escritura y lectura), fuentes
    utils/        fechas, nombres de archivo, texto
  features/poc/   pantalla de la Fase 0
test/             tests unitarios, de PDF y de widgets
tool/e2e/         prueba de extremo a extremo sin conexión
```
