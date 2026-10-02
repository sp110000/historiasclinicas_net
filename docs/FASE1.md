# Fase 1: historia clínica (resultado)

**Estado: completada.** Entorno: Flutter 3.38.10 y Dart 3.10.9. Librería de PDF: opción **A** (`pdf` + lector propio).

> Después de esta fase se añadieron "Revisión de síntomas por sistemas", "Análisis" y el tipo "Interconsulta": la historia tiene ahora 11 secciones. Ver [FASE2.md](FASE2.md).

## Qué incluye

### Pantalla de historia clínica (`/`)
- **9 secciones** en tarjetas: paciente, motivo y enfermedad actual, antecedentes, signos vitales, examen físico, diagnósticos, plan, firma y sello, evoluciones.
- **Índice de avance:**
  - Escritorio: índice lateral.
  - Tablet: chips horizontales.
  - Móvil: una sola columna y barra inferior con "Guardar PDF" y "Receta".
  - Cada sección indica si está vacía, incompleta o completa, y al pulsarla salta a ella.
- **Rápida de llenar:**
  - Fechas con máscara `dd/mm/aaaa` (también "9/" → "09/") y calendario.
  - Hora `hh:mm`.
  - Números con coma decimal y unidad.
  - El tabulador sigue el orden visual.
- **Cálculos automáticos:**
  - Edad a la fecha de la atención: en años; con meses en menores de 18; con meses y días en menores de 2. Tiene en cuenta los bisiestos.
  - IMC con la clasificación de la OMS para adultos. En menores de 18 años y gestantes no se clasifica y se explica por qué.
  - Edad gestacional y FPP calculadas desde la FUM.
- **Signos vitales:**
  - En **ámbar**, lo que está fuera del rango habitual en adultos. Solo avisa, nunca bloquea.
  - En **rojo**, lo imposible (por ejemplo FC 780), porque casi seguro es un error de digitación. Esto sí impide finalizar.
- **Alergias:**
  - Se registran como etiquetas, más la casilla "Niega alergias conocidas" (así se distingue "niega" de "no se preguntó").
  - Las etiquetas alimentarán la alerta de la receta.
- **Diagnósticos:**
  - Lista ordenable (arrastrando o con ↑↓) con CIE-10, tipo (principal o relacionado) y carácter según el país.
  - Colombia: impresión diagnóstica, confirmado nuevo, confirmado repetido.
  - España: sospecha, confirmado.
- **Gineco-obstétricos** solo si el sexo es F: G P C A V, FUM, anticoncepción y gestante.
- **Plantillas:** examen por sistemas y SOAP en las evoluciones.
- **Perfiles por país:** Colombia o España. Cambian los tipos de documento, "Signos vitales" o "Constantes vitales", municipio o localidad, EPS o mutua. El país queda guardado en cada historia.

### Ciclo de la historia
1. **Imprimir / Guardar PDF:**
   - **Vista previa e impresión (borrador):** lleva marca de agua BORRADOR y **no** incrusta datos, para que un borrador nunca pueda reabrirse como historia finalizada.
   - **Finalizar y guardar PDF:**
     - Valida lo obligatorio y lo lista por sección, con un botón "Ir a…".
     - Pide confirmación.
     - **Sella** la historia: `hashBase`, más una "huella" impresa en el papel.
2. **Historia abierta:**
   - Las secciones 1 a 8 quedan bloqueadas y plegadas, con un resumen de una línea; se despliegan al pulsarlas.
   - La sección 9 queda como zona activa.
   - El aviso superior muestra la revisión, el archivo y la integridad.
3. **Evoluciones:**
   - Cada una tiene fecha y hora automáticas (editables mientras no está sellada), texto, signos opcionales y firma y sello.
   - Se pueden descartar antes de guardar.
   - Al **descargar la historia actualizada** se sellan, encadenadas con SHA-256.
   - Opciones de guardado: nueva versión `_vN`, o sobrescribir el archivo en Chrome y Edge.
4. **Abrir historia existente:**
   - Con el selector de archivos o arrastrando y soltando el PDF.
   - Verifica la cadena: muestra "Integridad verificada (N sellos)" o un **aviso rojo** con la primera evolución que no coincide.
   - Para agregar sobre una historia alterada pide confirmación, y la nueva evolución lo deja registrado.
5. **Borrador automático:**
   - Se guarda en el navegador 0,7 s después de cada cambio.
   - Al recargar la pestaña se recupera ("Continuar" o "Descartar borrador").
   - Se borra solo al guardar el PDF. También se puede borrar a mano o desactivar ("No guardar borrador en este equipo").
6. **Formular receta** (`/receta`): de momento muestra los datos que se precargarán (paciente, documento, edad, diagnósticos, alergias). Al volver, lo escrito se conserva. La receta llega en la Fase 3.

### Avisos visibles
- Privacidad: los datos no salen del navegador; el único registro es el PDF; hay que guardar copias.
- Limitaciones: solo se reabren PDF de la app; otro programa puede perder el adjunto; el bloqueo lo aplica la app; la firma y el sello son imágenes.

## Cambios respecto al plan
- **La cadena de hashes y la reapertura completa se adelantaron** de la Fase 4 a esta fase. La nueva pantalla reemplaza a la de la Fase 0 y no debía perder funciones, y el esquema de datos queda estable desde ya. La Fase 4 se concentra en el diseño final del PDF, la PWA sin conexión y el despliegue.
- **El PDF es provisional.** Ya incluye todas las secciones, las evoluciones y las huellas impresas. El encabezado del médico y las imágenes de firma y sello llegan con la Fase 2, y el diseño final con la Fase 4.

## Verificación
| Comprobación | Resultado |
|---|---|
| `flutter analyze` | Sin problemas |
| `flutter test` | **75 tests en verde**: edad, IMC, gestación, rangos, modelo, cadena de hashes (alteración, borrado, reordenamiento), borrador, validación, país, PDF (ida y vuelta, reescrito por pikepdf, truncado, alterado, esquema futuro, borrador no reabrible) y widgets (secciones, IMC en vivo, avisos ámbar y rojo, validación, alergias, modo abierta, receta) |
| Prueba en Chromium **sin conexión** (`tool/e2e/historia_offline.mjs`) | 11 de 11 pasos: validación, edad e IMC, receta y volver, finalizar, evolución y v2, reabrir v2, **PDF alterado detectado**, PDF ajeno, borrador recuperado, móvil. **0 peticiones externas, 0 fallidas, 0 errores de consola** |

## Problemas encontrados y corregidos
1. **Edad mal calculada en fin de mes:** quien nació un 31 de enero daba "1 mes −2 días" el 1 de marzo. Se reescribió el algoritmo con meses completos; los bisiestos tienen tests.
2. **El plugin web de almacenamiento no se registraba** tras añadir dependencias: Flutter no regeneró su registro de plugins. Se resuelve con `flutter clean`. **En tu Mac:** después de `git pull`, ejecuta `flutter clean && flutter pub get`.
3. **Accesibilidad:** el campo de alergias absorbía el título del bloque en su nombre accesible. Ahora el encabezado es un nodo propio.
4. Al descartar una evolución nueva, los campos de las siguientes podían desordenarse. Ahora cada evolución tiene un `id` estable.

## Cómo probarla en tu Mac
```bash
git pull
flutter clean && flutter pub get
flutter run -d chrome              # desarrollo
# o, como en producción:
flutter build web --release --no-web-resources-cdn
python3 -m http.server 8765 --directory build/web   # y abre http://localhost:8765
```

## Evidencias (`docs/fase1/`)
- `escritorio_historia_llena.png`, `tablet_historia_nueva.png`, `movil_historia_abierta.png`
- `validacion_faltan_datos.png`, `historia_abierta.png`, `evoluciones.png`
- `pdf_alterado.png`, `borrador_recuperado.png`
- `pdf_historia_v2.png` y los PDF `Historia_PENA_1032456789.pdf` / `_v2.pdf` (en Acrobat, panel de adjuntos 📎 → `historia.json`)
