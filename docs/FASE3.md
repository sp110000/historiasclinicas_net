# Fase 3: receta de media hoja (resultado)

**Estado: completada.** Entorno: Flutter 3.38.10 y Dart 3.10.9.

## Qué incluye

### Pantalla de la receta (`/receta`)
- **Escritorio:** el editor a la izquierda y la **vista previa real** a la derecha.
- **Móvil:** pestañas "Editar" y "Vista previa", con "Guardar PDF" e "Imprimir" en la barra inferior.
- **Paciente precargado desde la historia:** nombre, documento, edad, diagnósticos con su CIE-10 y alergias. En España también la fecha de nacimiento (VERIFICAR).
  - Se puede corregir en la receta sin tocar la historia. Lo corregido se marca y se puede **restablecer**.
- **Medicamentos:**
  - Cada uno lleva medicamento (DCI o genérico), concentración, forma farmacéutica, dosis, vía, frecuencia, duración, cantidad, unidad y una indicación particular opcional.
  - **Numeración automática.** Se pueden agregar, quitar (con "Deshacer") y reordenar, arrastrando o con ↑↓.
  - **Sugerencias** al escribir la forma, la vía, la frecuencia, la duración y la unidad. Se puede escribir cualquier otro valor.
  - **Cantidad en números y letras:** 21 (veintiuno).
  - **Cantidad sugerida:** el botón "Usar 21" calcula dosis × tomas al día × días cuando la dosis se cuenta en unidades (tabletas, cápsulas, sobres…). Con jarabes, gotas o "si hay dolor" no adivina.
  - La unidad se propone según la forma: cápsula → cápsulas, jarabe → frascos, crema → tubos.
- **"Mis medicamentos":** la lista empieza vacía, como acordamos.
  - Cada medicamento se guarda con el botón 🔖 y se sugiere al escribir. Al elegirlo se rellenan todos sus campos.
  - El diálogo "Mis medicamentos" permite buscar, quitar, **exportar e importar JSON** (un respaldo o la lista de otro equipo). Queda listo para cargar un catálogo más adelante.
- **Alertas de alergia (no bloquean):** comparan las alergias con cada medicamento sin tener en cuenta tildes ni mayúsculas.
  - **Coincidencia directa:** penicilina → penicilina G benzatínica.
  - **Mismo principio activo:** acetaminofén ↔ paracetamol, dipirona ↔ metamizol.
  - **Mismo grupo:** penicilinas, cefalosporinas, carbapenémicos, sulfonamidas, macrólidos, quinolonas, tetraciclinas, aminoglucósidos, AINE, pirazolonas, opioides y anestésicos locales tipo amida.
  - **Posible reactividad cruzada**, en ámbar: penicilinas ↔ cefalosporinas, AINE ↔ pirazolonas.
  - Cada alerta indica el ítem y se marca como leída con "Entendido". Antes de imprimir, la app avisa si queda alguna sin revisar.
  - Si la historia no registra alergias, lo recuerda.
- **Control especial:** aviso para opioides, benzodiacepinas, metilfenidato, etc.: "podría requerir recetario oficial (VERIFICAR)". No bloquea.
- **Numeración `R-000001` (activable):**
  - El número se asigna al imprimir o guardar, y la vista previa ya lo muestra.
  - Al reimprimir, la receta conserva su número.
  - "Continuar numeración desde…" sirve para seguir un talonario o la numeración de otro equipo. El contador es de este navegador.
- **Opciones de la hoja:**
  - Fecha de la receta.
  - Título: "Receta médica", "Fórmula médica", "Prescripción médica" u "Hoja de tratamiento". En España, VERIFICAR si debe ser hoja de tratamiento.
  - Incluir firma e incluir sello.
- **Antes de imprimir** la app revisa que haya medicamentos, lista lo que falta en cada uno, avisa de las alergias sin revisar y de que faltan los datos del médico. Siempre se puede continuar.
- **Imprimir / Guardar PDF:**
  - "Imprimir" abre el diálogo del navegador con el mismo PDF.
  - "Guardar PDF" descarga `Receta_{APELLIDO}_{AAAA-MM-DD}.pdf`.
- **Registrar en la historia:** después de imprimir o guardar, la app ofrece agregar "Se formuló (R-000001) el 02/10/2026: 1. … 2. …" al **plan de tratamiento** (historia nueva) o a la **evolución en curso** (historia abierta, donde la crea si hace falta).
- **"Volver a la historia" conserva todo.** La receta se guarda sola en el navegador. Respeta "No guardar borrador en este equipo" y se borra con el borrador.

### PDF de la receta (A5 vertical, 148 × 210 mm)
- **Encabezado en cada hoja:**
  - Logo, médico, especialidad · registro y consultorio.
  - Título, n.º de receta y fecha.
  - Datos del paciente: nombre, documento, edad, diagnóstico y alergias destacadas.
- **℞** y los ítems numerados: medicamento, concentración y forma; posología; cantidad en números y letras.
- **Indicaciones** y, al pie de la última hoja, **firma y sello** sobre la línea, con el nombre y el registro.
- Si los medicamentos no caben, la receta **continúa en otra hoja A5**: "Continúa en la página siguiente", "(continuación)" y "Pág. X de Y".
- **La vista previa es el PDF real** dibujado con **pdf.js 3.2.146** (Mozilla, licencia Apache 2.0). Se sirve desde el propio sitio (`web/pdfjs/`, con su LICENSE), sin CDN, y su *worker* se carga en memoria al iniciar. Se actualiza 300 ms después del último cambio.

### CIE-10 (opcional, carga diferida)
> **Actualizado en la Fase 4:** la app ya incluye la tabla de referencia de SISPRO completa e importa el Excel tal como se descarga (ver [FASE4.md](FASE4.md)).

- **La app no trae un catálogo.** Desde aquí no pude acceder a las fuentes oficiales: SISPRO y eCIE-Maps no responden, y datos.gov.co solo tiene datos de morbilidad. Además, sus términos de uso son **VERIFICAR**. En su lugar, **el médico importa una vez el archivo oficial de su país**:
  - Colombia: tabla de referencia CIE-10 de SISPRO.
  - España: CIE-10-ES del Ministerio de Sanidad.
- **Formatos que acepta:**
  - CSV, TSV o TXT, separados por punto y coma, coma, tabulador o `|`, con o sin encabezado y con o sin comillas.
  - JSON: una lista de objetos o un mapa código → descripción.
  - Codificación UTF-8 o Windows-1252 (la de los CSV de Excel).
  - En cada fila toma el primer campo con forma de código y el siguiente texto como descripción.
- **Dónde se guarda:** en **IndexedDB**, donde cabe incluso la CIE-10-ES completa. Solo se lee la primera vez que el médico entra en un campo de diagnóstico.
- **En "Diagnósticos":** al escribir el diagnóstico o el código aparecen las coincidencias, por palabras o por código, con o sin punto. Al elegir una se completan los dos campos.
- **Dónde se gestiona:** en "Diagnósticos" ("Cargar catálogo" o "Gestionar") y en "Datos del médico". Se puede importar, reemplazar y quitar.

## Verificación
| Comprobación | Resultado |
|---|---|
| `flutter analyze` y `dart format` | Sin problemas |
| `flutter test` | **160 tests en verde** (eran 107; **+53**). **Receta:** número en letras (incluido "veintiún mil" y "un millón"), título, posología y cantidad, cantidad sugerida, alergias (directa, sinónimos, grupos, reactividad cruzada y sin falsas alarmas como "sulfato ferroso"), control especial, "Mis medicamentos" (ordenar, buscar, aplicar, exportar e importar), numeración al agregar, quitar y reordenar, autoguardado, R-000001, documento y registro en el plan o la evolución. **PDF A5:** medidas, imágenes y varias hojas. **CIE-10:** CSV, TSV, JSON, Windows-1252, búsqueda, importar y quitar. **Pantallas:** alerta, "Usar 21", vista previa, orden con deshacer, faltantes, "Mis medicamentos", móvil y diagnóstico con catálogo |
| Prueba en Chromium **sin conexión** | **23 de 23 pasos.** Nuevos: catálogo CIE-10 importado y diagnóstico completado; receta con alerta de alergia, dos medicamentos, cantidades en letras y vista previa con pdf.js local. El PDF se guarda y se comprueba con `pdfinfo`/`pdftotext`: A5, R-000001, paciente, CIE-10, ítems, cantidades y firma. También: imprimir sin bloquear la pantalla, la receta registrada en el plan, y el móvil. **0 peticiones externas, 0 fallidas, 0 errores de consola** |

## Problemas encontrados y corregidos
1. **Fallo de la Fase 1: "Limpiar formulario" dejaba el texto anterior en pantalla.** Los datos sí se vaciaban; lo que quedaba era el texto visible. Lo mismo pasaba al recuperar un borrador, al cambiar de país y al registrar la receta en el plan. La causa era que las claves que permiten saltar a cada sección conservaban los campos viejos. Ahora el contenido de cada sección se recrea. Hay un test que lo cubre.
2. **Imprimir podía dejar la receta bloqueada.** El paquete `printing` espera a que el navegador cargue el PDF; en navegadores sin visor de PDF eso nunca ocurre. Ahora no se espera al diálogo de impresión.
3. **Riverpod 3:** el autoguardado del médico y de la receta usaba `ref` al cerrarse, y eso no está permitido. Ahora guarda lo pendiente sin `ref`.
4. **Tests:** la caché de fuentes del PDF guardaba un `Future` ligado a la zona del primer test, así que los siguientes se colgaban. Ahora guarda las fuentes ya cargadas.
5. **Pantallas estrechas:** el título de las secciones y el desplegable del título de la hoja se desbordaban.

## Límites que conviene recordar
- **Medicamentos de control especial:** quedan fuera del alcance; la app solo avisa.
- **España:** VERIFICAR si en la asistencia privada la hoja debe ir en talonario oficial o ser receta electrónica. Si es así, sirve como hoja de tratamiento (el título es configurable).
- **Las alertas son una ayuda orientativa,** no una base de datos de interacciones ni de alergias completa.
- **La numeración es de este navegador.** En varios equipos, usa "Continuar numeración desde…".
- **Tamaño de papel al imprimir:** el PDF es A5. Si la impresora tiene A4, elige "Ajustar a la página" o papel A5 en el diálogo de impresión.

## Cómo probarla en tu Mac
```bash
git pull
flutter clean && flutter pub get
flutter run -d chrome              # "Formular receta" desde la historia
# o, como en producción:
flutter build web --release --no-web-resources-cdn
python3 -m http.server 8765 --directory build/web   # y abre http://localhost:8765
```
Para probar el CIE-10 sin el archivo oficial: `test/fixtures/cie10_muestra.csv` (30 códigos, **muestra de prueba, no oficial**).

## Evidencias (`docs/fase3/`)
- `receta_escritorio.png`: editor y vista previa real, con la alerta revisada y la cantidad en letras.
- `pdf_receta_a5.png` y `Receta_TORRES_2026-10-02.pdf`: la hoja A5 con número, CIE-10, firma y sello.
- `receta_movil_editar.png`, `receta_movil_vista_previa.png`: receta en el móvil.
- `registrar_en_historia.png`, `plan_con_receta.png`: registro de lo formulado en el plan.
- `cie10_importar.png`, `cie10_sugerencia.png`: importación del catálogo y búsqueda en "Diagnósticos".

## Siguiente: Fase 4 (PDF final, PWA sin conexión y despliegue)
