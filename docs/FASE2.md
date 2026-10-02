# Fase 2: datos del médico, firma y sello (resultado)

**Estado: completada.** Entorno: Flutter 3.38.10 y Dart 3.10.9.

## Cambios en la historia pedidos durante la fase
- **Sección 4 · Revisión de síntomas por sistemas** (después de Antecedentes):
  - 12 sistemas: generales, piel y faneras, cabeza y cuello, respiratorio, cardiovascular, gastrointestinal, genitourinario, endocrino, musculoesquelético, neurológico, mental y hematológico.
  - En cada uno, **Niega** o **Refiere**. Con "Refiere" se abre un campo para escribir qué refiere.
  - Botón **"Marcar los pendientes como «Niega»"** para terminar rápido, y un campo de observaciones.
  - Contador "N de 12 sistemas registrados". En el PDF y en modo abierta se resume como "Refiere · sistema: detalle" y "Niega síntomas en: …".
- **Sección 7 · Análisis** (después del Examen físico): texto libre.
- **Tipo de consulta:** nueva opción **"Interconsulta"**.
- La historia tiene ahora **11 secciones**, en el formulario, el índice, el modo abierta y el PDF. Las dos nuevas son opcionales para finalizar.

## Qué incluye

### Pantalla "Datos del médico" (`/medico`)
- **Cómo se llega:**
  - Menú ⋮ → "Datos del médico".
  - Aviso "Configura tus datos de médico" en una historia nueva, mientras no estén configurados.
  - Sección 10 "Firma y sello".
  - Al finalizar sin datos, un diálogo ofrece **"Configurar ahora"**, **"Guardar sin mis datos"** o "Cancelar".
- **Datos profesionales:**
  - Nombre completo\*, especialidad y registro\*.
  - El registro se llama "Registro profesional" en Colombia y "N.º de colegiado" en España (**VERIFICAR**).
  - Documento de identidad (opcional) y país de ejercicio.
- **Consultorio:** nombre, dirección, ciudad, teléfono y correo.
- **Firma:**
  - **Dibujarla** con el ratón, el dedo o un lápiz. El trazo se suaviza y hay botones para deshacer y borrar. Se guarda como PNG transparente, recortado al trazo y a 3× de resolución para que se imprima nítido.
  - O **subir** una foto o un escaneo.
- **Sello y logo:** se suben en PNG o JPG.
  - **"Quitar el fondo claro (papel)":** el umbral se calcula a partir del borde de la imagen, así que funciona también con el papel grisáceo de una foto. Después se recorta al contenido.
  - Se reducen al tamaño útil: firma hasta 1200×480, sello hasta 800×800 y logo hasta 900×360.
  - Una imagen de más de 15 MB, o un archivo que no es imagen, se rechaza con un mensaje claro.
- **Vista previa en vivo** de cómo quedarán el encabezado y el bloque de firma.
- **Guardado en este navegador** (localStorage, clave `hc.medico.v1`) 0,4 s después de cada cambio.
- **"Borrar mis datos de este navegador"**, con confirmación.
- **Aviso legal:** la firma y el sello son imágenes, no una firma digital certificada (**VERIFICAR** su validez). Cualquiera con acceso al navegador podría usarlas: hay que borrarlas en un equipo compartido.

### En la historia
- **Sección 10 · Firma y sello:**
  - Muestra cómo quedará la firma: sello y firma sobre la línea, nombre, registro y especialidad.
  - Botón "Editar datos del médico".
  - Los interruptores "Incluir firma" e "Incluir sello" avisan si esa imagen no está cargada.
- **Evoluciones nuevas:**
  - Indican "Quedará a nombre de …", o que se guardarán sin nombre ni registro.
  - Cada una tiene sus propios interruptores de firma y sello.
- **Historia abierta:**
  - La sección 10 muestra **el médico que la finalizó**, tomado de la copia guardada en el PDF, no del navegador actual.
  - Cada evolución sellada muestra su autor ("Dra. … · Registro profesional …").
- La pantalla de receta (provisional) ya muestra al médico.

### En el PDF
- **Encabezado en cada página:**
  - A la izquierda: logo, nombre, especialidad · registro, y consultorio · dirección · ciudad · teléfono.
  - A la derecha: HISTORIA CLÍNICA, paciente, fecha de la atención y "Pág. X de Y".
- **Bloque de firma:** sello y firma sobre la línea, nombre y registro. El título "10. Firma y sello" y la firma nunca se separan entre páginas.
- **Cada evolución** lleva la firma y el sello de su autor, más pequeños, si los incluyó.
- Cada imagen se guarda **una sola vez** en el archivo, aunque se dibuje en varias páginas (el logo, en todas).

### Cómo se guarda en `historia.json`
| Clave | Contenido | ¿Dentro de la cadena de hashes? |
|---|---|---|
| `medico` | Copia de los datos del médico al finalizar, más el SHA-256 de cada imagen incluida (logo, firma, sello) | **Sí** (la cubre `hashBase`) |
| `evoluciones[i].autor` | Copia de quien escribió esa evolución (sin logo). Un mismo PDF puede tener evoluciones de varios médicos | **Sí** (cada una en su eslabón) |
| `recursos` | `{ sha256: PNG en base64 }`, compartido por todos | No, pero cada imagen se identifica por su SHA-256 y esa referencia sí está sellada |

- Al abrir un PDF se comprueba que **cada imagen coincide con su SHA-256** y que **no falta ninguna** de las referenciadas. Si algo falla, aparece "Se detectaron alteraciones en las imágenes de firma, sello o logo".
- Si cambias o borras tus datos en el navegador, **los PDF ya guardados no cambian**: cada uno conserva su copia.

## Verificación
| Comprobación | Resultado |
|---|---|
| `flutter analyze` y `dart format` | Sin problemas |
| `flutter test` | **107 tests en verde** (eran 79; **+28**). Imágenes: quitar fondo blanco y gris, recorte, reducción, imagen ya transparente, archivo no válido e imagen en blanco. Firma dibujada: transparente y recortada; deshacer y limpiar. Datos del médico: ida y vuelta con imágenes, "configurado", borrar, JSON dañado y autoguardado. Copia en los documentos: SHA-256 de cada imagen, interruptores y etiqueta de España. Cadena: las imágenes quedan fuera del hash; una imagen cambiada, reemplazada o ausente se detecta; las evoluciones de otro médico conservan la cadena sin duplicar imágenes. Guardado: historia con médico, interruptores, sin médico, y evolución con autor. PDF: 3 imágenes con transparencia y sin imágenes cuando no hay médico. Pantallas: aviso → configurar → firma; etiqueta del registro por país; borrar con confirmación; interruptores; diálogo al finalizar sin médico; autores en la historia abierta |
| Prueba en Chromium **sin conexión** (`tool/e2e/historia_offline.mjs`) | **15 de 15 pasos.** Nuevos: configurar al médico desde el diálogo de finalizar, **firma dibujada con el ratón**, **sello fotografiado sobre papel gris** (se le quita el fondo) y logo. Con pikepdf se comprueba que `historia.json` lleva los signos, el médico y 3 imágenes válidas, que el logo aparece en todas las páginas y la firma y el sello al final, y que la evolución de la v2 lleva su autor sin duplicar imágenes. **0 peticiones externas, 0 fallidas, 0 errores de consola** |

## Problemas encontrados y corregidos
1. **Petición de una fuente a internet:** el texto "Firma aquí" del lienzo se pintaba sin la fuente de la app, y Flutter Web intentaba descargar "Noto Sans Symbols", lo que sin conexión falla. Ahora usa la fuente del tema. La prueba sin conexión lo detectó en la consola.
2. **PDF:** el título "10. Firma y sello" podía quedar solo al final de una página, con la firma en la siguiente. Ahora van juntos (`pw.Inseparable`).
3. **Desbordamiento** del resumen de firma cuando el texto era muy ancho. Lo detectó un test de pantalla.
4. En las miniaturas, la rúbrica fina se veía cortada al reducirla. Ahora se dibujan con filtrado de mejor calidad.
5. **Prueba e2e:** con la nueva sección 4, el campo "PA sistólica" quedaba fuera de la pantalla y la prueba escribía antes de que recibiera el foco, así que el PDF salía con "PA —/76". La app no tenía el fallo: una persona no puede escribir en un campo que no ve. Ahora la prueba desplaza hasta el campo, comprueba lo escrito, reintenta si hace falta, y verifica los signos guardados en el PDF.

## Límites que conviene recordar
- La firma y el sello son **imágenes**. No prueban la autoría ni equivalen a una firma digital certificada (**VERIFICAR** la norma de cada país).
- Los datos del médico viven **solo en este navegador**. Si se borran los datos del sitio, hay que configurarlos de nuevo. En un equipo compartido conviene borrarlos al terminar.
- Sin servidor ni clave secreta, alguien con conocimientos podría rehacer la cadena con otras imágenes. La cadena detecta las ediciones ingenuas; el papel firmado sigue siendo el ancla.

## Cómo probarla en tu Mac
```bash
git pull
flutter clean && flutter pub get
flutter run -d chrome              # menú ⋮ → "Datos del médico"
# o, como en producción:
flutter build web --release --no-web-resources-cdn
python3 -m http.server 8765 --directory build/web   # y abre http://localhost:8765
```

## Evidencias (`docs/fase2/`)
- `datos_medico.png`: datos profesionales, consultorio y firma.
- `firma_dibujada.png`: diálogo para dibujar la firma.
- `vista_previa_medico.png`: logo, aviso legal y vista previa del encabezado y la firma (sello sin fondo).
- `firma_en_historia.png`: sección 10 con el médico configurado.
- `evolucion_con_autor.png`: historia reabierta, con el médico de la sección 10 y el autor de la evolución.
- `pdf_historia_medico.png` y los PDF `Historia_PENA_1032456789.pdf` / `_v2.pdf`: encabezado con logo, firma y sello, y evolución firmada.

## Siguiente: Fase 3 (receta de media hoja A5)
