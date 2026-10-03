# Diseño visual 2b «Clínico sobrio»

Rediseño propuesto por Claude Design y aplicado sobre la Fase 4. Solo cambia la capa visual: no cambian los providers, las rutas, los campos, los textos clínicos, `historia.json`, las huellas ni el orden de los bloques del PDF.

La entrega de Claude Design trajo 14 archivos Dart ya modificados y una nota de cambios. No trajo los mockups (`Rediseño.dc.html`, `Sistema 2b.dc.html`), así que la referencia fue ese código.

## Qué cambió

| Zona | Antes | Ahora |
|---|---|---|
| Paleta | Primario `#1E6A8D`, verde salvia `#2E9E83` para el ℞ y los estados | Petróleo `#1E5A7A` para todo lo que es acción (también el ℞); verde `#2E7D5B` solo para estados correctos |
| Contraste | Ámbar 2,9:1, verde 3,3:1 | Todos los textos ≥ 4,5:1 (test en `test/app/tema_test.dart`) |
| Barra superior | Ícono y nombre | Wordmark «**historiasclinicas**.net» y, debajo, la **franja del paciente**: nombre, documento, edad y alergias |
| Tarjeta de sección | Ícono en recuadro y «n · título» | Rótulo «SECCIÓN n» sobre el título; separador bajo la cabecera; sin sombra |
| Índice lateral | Ícono de cada sección | Círculo numerado que se rellena según el estado |
| Historia abierta | Una tarjeta por sección | Secciones 1 a 10 en una sola tarjeta con filas desplegables; evoluciones aparte |
| Avisos y alertas | Franja de color a la izquierda | Borde completo e ícono en recuadro con tinte |
| Diálogos | Ícono y título centrados | Título a la izquierda con el ícono en un recuadro; acciones apiladas, con la principal arriba, si no caben |
| Campos | Etiqueta dentro del campo vacío | Etiqueta siempre visible sobre el borde (13 px) |
| Datos del médico | Vista previa al final | Desde 1100 px, vista previa fija en una columna de 400 px a la derecha |
| PDF de la historia | Títulos con fondo gris | Número de sección en petróleo, versalitas y filete; ficha del paciente antes de la sección 1 |
| PDF de la receta | Paciente entre líneas | Paciente en un recuadro de filete fino; «Cantidad» en seminegrita |

## Tokens

En `lib/app/tema.dart`:

- **`ColoresMarca`:** la paleta, más tokens para los colores que el diseño traía sueltos en el código. Por ejemplo `tintaSuave`, `pista`, `separador`, `deshabilitado` y `avisoFondo`/`avisoBorde`/`avisoTexto`.
- **`RadiosMarca`:** `control` 8, `recuadro` 10, `tarjeta` 12, `dialogo` 14 y `pildora`.
- **`EstilosMarca`:** `rotulo` (versalitas de 11) y `titulo` (19 w600).

Componentes compartidos nuevos en `lib/core/widgets/`:

- **`TituloDialogo`:** título de diálogo con el ícono en un recuadro.
- **`RecuadroIcono`:** el recuadro con tinte que usan los avisos, las alertas y los diálogos.

La franja del paciente está en `lib/features/historia/widgets/franja_paciente.dart`.

## Decisiones donde el diseño no era claro

1. **PDF en color.** El plan decía «solo negro y grises». Se acepta un único acento, el petróleo de los números de sección, que en blanco y negro sale gris oscuro.
2. **«Niega alergias».** El diseño lo mostraba en ámbar con ⚠, como si fuera una alergia. Ahora va en un chip neutro, y el ámbar queda solo para alergias registradas.
3. **Franja en móvil.** En móvil el chip de alergias se recorta (hasta el 42 % del ancho) para que el nombre tenga prioridad. Así no se desborda en pantallas de 320 px (hay test).
4. **Pistas de los campos.** El diseño usaba `#8995A0` (3,1:1); ahora `#6B7782` (4,6:1).
5. **Verde fuera del diseño.** El chip «Niega» de revisión por sistemas, la edad gestacional y el número de cada medicamento siguen al primario, como el ℞. El mensaje de éxito de «Mis medicamentos» pasa a verde de estado, igual que el del CIE-10.
6. **Etiqueta fuera del campo.** El diseño la dejó pendiente. Se mantiene sobre el borde, siempre visible.
7. **`TituloDialogo`** va en `lib/core/widgets`, con el resto de los widgets compartidos, en lugar de en `tema.dart`.

## Correcciones al código del diseño

Salieron al compilarlo y compararlo en pantalla:

- **No compilaba:** había un `num` donde se esperaba un `double` en la franja, y un import sin usar.
- **Inter se perdía.** El tema reemplazaba los estilos de texto en lugar de mezclarlos, y los de botones, chips y campos no llevaban familia. Casi todo salía con la fuente de respaldo (Roboto). Lo vigila un test.
- **Etiquetas diminutas.** Flutter dibuja la etiqueta flotante al 75 %, así que con 13 px salía a 9,75. Ahora se ve a 13 px.
- **Desplegables en negrita.** Usan `titleMedium`, que el tema subía a 17 w600. Ahora tienen el mismo texto que los demás campos.
- **Semántica.** El rótulo «SECCIÓN n» no se lee dos veces, y el título conserva la etiqueta «n · título». En la historia abierta, las filas no tienen esquinas redondeadas en el efecto de pulsación.

## Pendiente

- Con la etiqueta siempre visible, los **ejemplos de los campos vacíos** («Dra. Ana Pérez Gómez», «500 mg») se ven todo el tiempo, en gris. Si confunden con datos ya escritos, se pueden poner en cursiva o más claros (sin bajar de 4,5:1).
- **Radios.** Las tarjetas propias de *Datos del médico* y de la *Receta*, y los ítems de la receta, conservan su radio de 14–16 px y su ícono. El diseño no las tocó.
- **Índice horizontal** (de 700 a 1180 px). Sigue con candados y sin círculos numerados; el diseño no lo cubría.

## Logo

El logo es una cruz con un trazo de electrocardiograma y un documento. Se recortó de la imagen original con fondo transparente, y el original de 496 px está en `docs/marca/logo.png`. De ahí salen todos los íconos de `web/`:

| Uso | Archivo | Fondo |
|---|---|---|
| Pestaña | `favicon.ico` (16, 32 y 48), `icons/logo-16/32/48/96/192.png` | Transparente |
| App instalada | `icons/logo-192.png`, `icons/logo-512.png` | Transparente |
| Android (máscara redonda) | `icons/logo-maskable-192/512.png` | Blanco; logo dentro de la zona segura |
| iPhone y iPad | `icons/logo-apple-180.png` | Blanco (iOS no admite transparencia) |

Los nombres cambiaron junto con el logo. Los móviles guardan el ícono por su dirección, aparte de los datos del sitio, y con el nombre anterior seguían mostrando el logo viejo. `test/tool/iconos_test.dart` comprueba que cada ícono declarado existe, que tiene su tamaño y que ninguno usa los nombres anteriores. El color de la barra del sistema (`theme-color`) pasó al petróleo 2b.

## Capturas

Antes y después, con los mismos datos.

- **Escritorio (1440 px):**
  - [historia nueva con paciente](diseno/escritorio_historia_nueva.png)
  - [historia abierta](diseno/escritorio_historia_abierta.png)
  - [diálogo «Faltan datos»](diseno/escritorio_dialogo.png)
  - [receta](diseno/escritorio_receta.png)
  - [datos del médico](diseno/escritorio_medico.png)
- **Intermedio (1120 px):** [historia abierta, con el índice horizontal y la franja](diseno/intermedio_historia_abierta.png)
- **Móvil (390 px):**
  - [historia nueva](diseno/movil_historia_nueva.png)
  - [historia abierta](diseno/movil_historia_abierta.png)
- **PDF:**
  - historia: [página 1](diseno/pdf_historia.png) · [PDF](diseno/Historia_PENA_1032456789_v2.pdf)
  - receta: [página 1](diseno/pdf_receta.png) · [PDF](diseno/Receta_TORRES_2026-10-02.pdf)

## Verificación

- **Comprobaciones de código:** `dart format`, `flutter analyze` y 188 tests en verde (9 nuevos: tema, franja del paciente y columna del médico).
- **Prueba sin conexión de historia, receta y PDF** (`tool/e2e/historia_offline.mjs`): pasa entera, sin errores de consola ni peticiones externas.
- **Prueba de la app instalada** (`tool/e2e/pwa_offline.mjs`): instalación, uso sin conexión y actualización.
