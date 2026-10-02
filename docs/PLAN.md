# Plan de trabajo: historiasclinicas.net (Flutter Web, offline)

> Estado: **plan aprobado. Fase 0 en curso.**
> Todo lo normativo sigue marcado **VERIFICAR**. La validación legal la hace el médico.

---

## Decisiones confirmadas (02/10/2026)

| # | Tema | Decisión |
|---|---|---|
| — | Entorno del médico | **Flutter 3.38.10 (stable), Dart 3.10.9**, macOS. El proyecto se fija a esa versión (`sdk: ^3.10.9`) y los paquetes se eligen compatibles con ella |
| — | Nombre y dominio | **historiasclinicas.net** |
| 1 | Países | **Colombia y España.** El país de ejercicio se elige en "Datos del médico" (ver "Perfiles por país") |
| 2 | Pacientes | Niños y gestantes: sí (edad en meses y días, nota de percentiles en el IMC, antecedentes gineco-obstétricos condicionales) |
| 3 | Nombre del paciente | Primer apellido, segundo apellido y nombres en campos separados |
| 4–5 | Bloqueo y sellado | "Finalizar y guardar PDF" sella la historia inicial. Cada evolución se sella al descargar |
| 6 | Varios médicos | Sí. Cada entrada guarda su autor y sus imágenes de firma y sello |
| 7 | Integridad fallida | Se permite agregar tras confirmar; el aviso queda visible y el problema se registra en la nueva entrada |
| 8 | Guardado | Nueva versión `_vN` por defecto; sobrescribir como opción en Chrome y Edge |
| 9 | Evolución | Texto libre, plantilla SOAP opcional, signos vitales opcionales |
| 10 | Receta | **A5 vertical** |
| 11 | Cantidad | En números y letras |
| 12 | Control especial | Fuera del alcance; solo un aviso |
| 13 | Registrar receta | Sí: se ofrece agregarla al plan o a la evolución en curso |
| 14 | Alergias | Coincidencias de texto y grupos; el aviso no bloquea |
| 15 | Medicamentos frecuentes | **Lista vacía al inicio**, pero preparada para crecer: agregar, importar y exportar JSON, y en el futuro cargar un catálogo |
| 16 | Numeración de recetas | Sí, `R-000001`, activable |
| 17 | CIE-10 | Sí, opcional, con carga diferida |
| 18–22 | Resto | Por defecto: un perfil de médico, guía de despliegue para varios proveedores, borrador que se borra al guardar, solo plataforma web |

### Perfiles por país

Todo es **VERIFICAR**: son referencias para orientar, no asesoría legal.

| Aspecto | Colombia | España |
|---|---|---|
| Norma de historia clínica | Res. 1995/1999, Ley 2015/2020, Res. 866/2021 | Ley 41/2002 (art. 15, contenido mínimo), normativa autonómica |
| Norma de prescripción | Decreto 2200/2005 (compilado en el Decreto 780/2016) | Real Decreto 1718/2010 (receta médica y órdenes de dispensación) |
| Profesional | "Registro profesional" (RETHUS) | "N.º de colegiado" |
| Documento del paciente | CC, TI, CE, PA, RC, PPT, … | DNI, NIE, pasaporte, CIP/TSI |
| Etiqueta de constantes | "Signos vitales" | "Constantes vitales" |
| Campos de receta adicionales posibles | cantidad en letras, n.º de historia, vigencia | n.º de envases y formato del envase, fecha prevista de dispensación, fecha de nacimiento del paciente |
| ⚠ Advertencia importante | — | **VERIFICAR:** en la asistencia privada, la receta en papel podría tener que imprimirse en talonarios oficiales que editan los Colegios de Médicos, o hacerse electrónica por los cauces oficiales. Si es así, la hoja que genera la app serviría como **hoja de tratamiento o instrucciones al paciente**, no como receta dispensable. La etiqueta del documento será configurable |
| Datos de salud | Ley 1581/2012 (datos sensibles) | RGPD y LOPDGDD (categoría especial) |
| Conservación de historias | Res. 839/2017 | Ley 41/2002 y normas autonómicas |

La conservación de las historias es responsabilidad del médico, porque el PDF es el único registro.

---

## 0. Lo que encontré antes de planificar

| Tema | Hallazgo | Consecuencia |
|---|---|---|
| Repositorio | Es la plantilla de `flutter create` (Dart `^3.10`), con todas las plataformas | Partimos de cero. Propongo dejar solo `web/` |
| Flutter | Se usa **3.38.10 (Dart 3.10.9)**, la misma versión del médico. Instalada en el contenedor para correr `flutter analyze` y los tests | Las últimas versiones de `pdf` y `printing` exigen Flutter 3.41, así que se fijan `pdf` 3.12.0 y `printing` 5.14.3, que funcionan con 3.38 y tienen todo lo necesario |
| `pdf` 3.12.0 (Apache-2.0) | **Ya trae `PdfaAttachedFiles`**, que escribe archivos incrustados (`/EmbeddedFiles` y `/AF`, el mecanismo de PDF/A-3 y Factur-X). **No puede leer PDF existentes.** Hay un detalle: declara `/Size` contando unidades UTF-16, así que con tildes el tamaño no cuadra | Escribir: resuelto. Leer: hace falta un lector propio pequeño. El problema de `/Size` se evita escribiendo el JSON solo con ASCII (`\u00e1` en lugar de `á`) |
| `syncfusion_flutter_pdf` 35.1.37 | Lee y escribe adjuntos de forma nativa. **Licencia comercial o Community License**: ingresos brutos anuales menores a USD 1 millón y menos de 5 desarrolladores, además de aceptar sus términos y condiciones. Arrastra `syncfusion_flutter_core`, `http`, `xml` e `intl` | Funciona, pero añade una condición de licencia y peso al sitio |
| `printing` 5.14.3 en web | La vista previa usa **pdf.js descargado de `unpkg.com`** (un CDN), salvo que exista la variable `dartPdfJsBaseUrl`. Para imprimir usa un iframe oculto | Incluiremos pdf.js (Apache-2.0) dentro de `web/`. En Safari y Firefox la impresión directa varía, así que se ofrecerá descargar como alternativa |
| Flutter Web sin conexión | Por defecto, CanvasKit se descarga de `gstatic.com`. El service worker propio de Flutter está obsoleto | Compilaremos con `--no-web-resources-cdn`, empaquetaremos las fuentes y escribiremos un service worker propio. Lo verifico en la Fase 4 con Chromium en modo sin conexión |

**Recomendación preliminar:** usar `pdf` y `printing` para generar, más un lector propio y pequeño del adjunto. Ventajas: licencias sin condiciones (Apache-2.0), menos peso y control total del formato. En la Fase 0 pruebo **las dos** opciones y te muestro la comparación antes de decidir.

---

## (a) Preguntas

**Para empezar la Fase 0 solo necesito tu aprobación.** Las demás preguntas pueden responderse antes de la Fase 1. Junto a cada una pongo lo que haría por defecto; basta con que respondas "ok" a lo que te parezca bien.

### Normativa
1. **¿País y norma?** Tu redacción mezcla términos: "funciones vitales" y "sello" son muy de Perú, mientras que "formular" y "registro profesional" son muy de Colombia. Las referencias que revisaría (todas **VERIFICAR**):
   - **Perú:** NTS N.° 139-MINSA (gestión de la historia clínica) y el Reglamento de Establecimientos Farmacéuticos (DS 014-2011-SA) para la receta.
   - **Colombia:** Res. 1995 de 1999, Ley 2015 de 2020 y Res. 866 de 2021 para la historia; Decreto 2200 de 2005 para la prescripción.
   - Sin país, uso campos genéricos y marco con VERIFICAR todo lo normativo.
2. **¿Atiendes niños o gestantes?** De eso depende mostrar la edad en meses y días, avisar que el IMC infantil se interpreta con percentiles y mostrar antecedentes gineco-obstétricos cuando el sexo es F. *Por defecto:* sí a las tres, en secciones que aparecen solo cuando aplican.

### Historia y evoluciones
3. **Nombre del paciente:** ¿separo apellidos y nombres? Lo necesito para el nombre de archivo `Historia_{apellido}_{documento}.pdf`. *Por defecto:* primer apellido, segundo apellido y nombres en campos separados.
4. **¿Cuándo se bloquea la historia inicial?** *Por defecto:* "Vista previa / Imprimir borrador" no bloquea nada. "Finalizar y guardar PDF" pide confirmación, sella la historia y la bloquea; desde ese momento solo se agregan evoluciones.
5. **¿Cuándo se sella una evolución?** *Por defecto:* se puede editar mientras no hayas descargado. Al pulsar "Descargar historia actualizada" se sella con su hash y queda bloqueada. En una misma sesión puedes agregar varias.
6. **¿Pueden escribir evoluciones médicos distintos en la misma historia?** *Por defecto:* sí. Cada entrada guarda una copia de los datos de su autor (nombre y registro) y de su firma y sello. Las imágenes van dentro del PDF y se guardan una sola vez aunque se repitan, para que al reabrirlo en otro equipo las firmas anteriores salgan igual.
7. **Si falla la verificación de integridad, ¿se pueden seguir agregando evoluciones?** *Por defecto:* sí, pero tras confirmar explícitamente. Un aviso rojo queda fijo en pantalla y la nueva entrada registra el problema ("se detectó alteración desde la evolución #N").
8. **Al guardar, ¿sobrescribir o crear una versión nueva?** *Por defecto:* "Guardar como nueva versión" (`Historia_PEREZ_123_v3.pdf`), que es lo más seguro. "Sobrescribir el archivo abierto" queda como opción en Chrome y Edge.
9. **Evolución:** ¿solo texto libre? *Por defecto:* texto libre, más un botón opcional "Insertar plantilla SOAP" y una fila opcional de signos vitales.

### Receta
10. **Formato:** *Por defecto:* A5 vertical (148 × 210 mm) sobre papel A5. Como alternativa configurable, "media A4": la mitad superior de una hoja A4 (210 × 148,5 mm, horizontal) con línea de corte. ¿Quieres también "2 copias en una A4" (original y copia)?
11. **¿Cantidad en números y letras?** Por ejemplo, "21 (veintiuno)". Algunas normas lo exigen (**VERIFICAR**). *Por defecto:* se genera automáticamente.
12. **Medicamentos de control especial:** quedan fuera del alcance porque requieren un recetario oficial. *Por defecto:* la app solo muestra un aviso.
13. **¿Registrar la receta en la historia?** *Por defecto:* al imprimirla, la app ofrece agregar "Se formuló: 1. … 2. …" al plan si la historia es nueva, o a la evolución en curso si es una historia abierta.
14. **Alertas de alergia:** *Por defecto:* busca coincidencias de texto sin distinguir tildes ni mayúsculas, y consulta una tabla local de grupos (penicilinas, cefalosporinas, AINEs, sulfas, etc.). El aviso no bloquea la receta. ¿Te parece bien?
15. **Medicamentos frecuentes:** ¿empiezo con una lista de unos 80 genéricos comunes, la dejo vacía o me envías la tuya? *Por defecto:* la lista de 80, editable, con opción de exportarla e importarla.
16. **Numeración de recetas:** *Por defecto:* formato `R-000001`, activable. Hay que avisar que el contador es de cada navegador, así que puede repetirse si usas varios equipos.

### Otros
17. **CIE-10:** ¿lo quieres? Usaría la tabla oficial de tu país (**VERIFICAR** sus términos de uso). Pesa unos 250 KB comprimida y se cargaría solo cuando se use. *Por defecto:* sí, opcional, en la Fase 3.
18. **Perfil del médico:** *Por defecto:* un solo perfil por navegador.
19. **Hosting y dominio:** ¿ya tienes el dominio `.net` y un proveedor? *Por defecto:* la guía cubre Netlify, Firebase Hosting, Vercel y hosting tradicional, y recomienda Netlify o Firebase.
20. **Nombre visible y logo:** *Por defecto:* "Historia Clínica", con la paleta propuesta más abajo.
21. **Borrador:** *Por defecto:* se borra automáticamente al guardar el PDF con éxito. También hay un botón "Borrar borrador" y la opción "No guardar borrador en este equipo".
22. **Plataformas:** *Por defecto:* elimino `android/`, `ios/`, `linux/`, `macos/` y `windows/`, porque la app es solo web.

---

## (b) Lista de campos propuesta

Convenciones: `*` = obligatorio, `auto` = lo calcula o llena la app, `VERIFICAR` = depende de la norma de tu país.

### Encabezado de la atención
| Campo | Tipo | Notas |
|---|---|---|
| Fecha y hora de la atención* | fecha y hora | auto (ahora), editable mientras no esté sellada |
| Tipo de consulta | primera vez / control / urgencia | opcional |
| N.º de historia | texto | auto = n.º de documento (**VERIFICAR**) |
| Consultorio / lugar | texto | auto, desde "Datos del médico" |

### 1. Datos del paciente
| Campo | Tipo | Notas |
|---|---|---|
| Primer apellido*, segundo apellido | texto | en mayúsculas en el PDF |
| Nombres* | texto | |
| Tipo de documento* | lista | opciones según país (**VERIFICAR**) |
| N.º de documento* | texto | |
| Fecha de nacimiento* | fecha | casilla "Fecha desconocida", que permite escribir una edad aproximada |
| Edad | auto | años; en menores de 2 años, meses y días; calculada a la fecha de la atención |
| Sexo* | opciones | categorías **VERIFICAR** |
| Teléfono | teléfono | |
| Dirección, ciudad o distrito | texto | |
| *Complementarios (sección plegable):* estado civil, ocupación, aseguradora o seguro, acompañante o responsable (nombre, parentesco, teléfono) | varios | **VERIFICAR** cuáles son obligatorios |

### 2. Motivo de consulta y enfermedad actual
| Motivo de consulta* | texto corto, en palabras del paciente |
|---|---|
| Enfermedad actual* | texto largo (tiempo de evolución, forma de inicio, curso) |

### 3. Antecedentes
| Campo | Tipo | Notas |
|---|---|---|
| Alergias* | etiquetas, más casilla **"Niega alergias conocidas"** | Distingue "no preguntado" de "niega". Las etiquetas alimentan la alerta de la receta |
| Personales patológicos | texto | |
| Medicación actual | texto | |
| Quirúrgicos | texto | |
| Familiares | texto | |
| Hábitos (tabaco, alcohol, otras sustancias) | texto | opcional |
| Gineco-obstétricos (FUM, G P A C, anticoncepción) | varios | aparece solo si sexo = F |
| Otros | texto | |

### 4. Funciones vitales
| Campo | Unidad | Notas |
|---|---|---|
| PA sistólica / diastólica | mmHg | dos casillas: `[120] / [80]` |
| FC | lpm | |
| FR | rpm | |
| Temperatura | °C | |
| SpO₂ | % | |
| Peso | kg | |
| Talla | cm | |
| **IMC** | kg/m² | auto, con la clasificación de la OMS desde los 18 años; en menores muestra el valor con la nota "interpretar con percentiles" |
| Glucemia capilar, perímetro abdominal | mg/dL, cm | opcionales |

Los valores fuera de rango se resaltan en ámbar como aviso, pero nunca bloquean.

### 5. Examen físico
Estado general y un texto largo, con un botón opcional "Insertar plantilla por sistemas" (cabeza y cuello, tórax, cardiopulmonar, abdomen, extremidades, neurológico, piel).

### 6. Diagnósticos (lista ordenable)
| Campo | Notas |
|---|---|
| Descripción* | texto libre |
| Código CIE-10 | opcional; se autocompleta si se incluye la tabla |
| Tipo | principal / relacionado |
| Carácter | presuntivo / definitivo / repetido (nombres según país, **VERIFICAR**) |

### 7. Plan de tratamiento e indicaciones
Plan terapéutico, exámenes solicitados, interconsultas, indicaciones y signos de alarma, próximo control (fecha opcional).

### 8. Firma y sello
Se toman de "Datos del médico": nombre, especialidad y registro. Hay interruptores "Incluir firma" e "Incluir sello" para cada documento.

### 9. Evoluciones (solo se agregan, nunca se editan las anteriores)
| Campo | Notas |
|---|---|
| N.º | auto, correlativo |
| Fecha y hora | auto; editable solo mientras la entrada no esté sellada |
| Autor | auto, copia del perfil del médico |
| Texto* | libre, con plantilla SOAP opcional |
| Signos vitales | opcional |
| Incluir firma / sello | interruptores |
| Hash y huella | auto; el hash completo va en el JSON y una huella corta (`3f9a·c21e`) se imprime en el PDF |

### Metadatos (solo en el JSON incrustado)
`app`, `schemaVersion`, `appVersion`, `historiaId` (UUID), `creada`, `actualizada`, `hashBase`, `evoluciones[]` (cada una con su `hash` y `hashPrevio`), `recursos{}` (imágenes de firma y sello en base64, identificadas por su SHA-256).

### Campos normativos adicionales
**Pendiente del país.** Cada campo que la norma exija se añadirá marcado y con su referencia, y quedará **VERIFICAR** si no tengo certeza.

### Receta
| Bloque | Campos |
|---|---|
| Encabezado | médico, especialidad, registro, consultorio (dirección y teléfono), logo, fecha, n.º de receta (opcional) |
| Paciente | nombre, documento, edad, diagnóstico(s); se precargan y son editables |
| Ítems 1…n | medicamento (DCI o genérico)*, concentración*, forma*, dosis*, vía*, frecuencia*, duración*, cantidad* (en números y letras), nota opcional |
| Pie | indicaciones generales, firma y sello (activables), nombre y registro debajo de la firma |

---

## (c) Bocetos textuales

### Paleta y estilo
- **Primario:** azul petróleo `#1E6A8D`. **Secundario:** verde salvia `#2E9E83`. **Aviso:** ámbar `#C98A1B`. **Error:** `#C2413B`.
- **Fondo:** `#F4F7F9`. **Tarjetas:** blancas, borde `#DCE4EA` y radio de 16 px.
- **Tipografía:** Inter (licencia OFL), incluida dentro de la app, la misma en la interfaz y en el PDF. Espaciado sobre una cuadrícula de 8 px.
- **Iconos:** Material Symbols, incluidos con la app.
- **Impresión:** solo negro y grises, sin fondos de color, con líneas finas.

### Pantalla 1: Historia clínica, escritorio (≥ 1200 px)
```
┌────────────────────────────────────────────────────────────────────────────────────┐
│ 🩺 Historia Clínica                 [📂 Abrir historia existente] [👤 Datos médico] │
│                       [🗑 Limpiar] [🖨 Imprimir / Guardar PDF] [ ℞ FORMULAR RECETA ] │
├───────────────────┬────────────────────────────────────────────────────────────────┤
│ ÍNDICE            │ ┌ 🔒 Tus datos no salen de este navegador. El único registro ──┐│
│ ✓ 1 Paciente      │ │   es el PDF que descargas: guarda copias. [Más info] [✕]     ││
│ ● 2 Motivo        │ └──────────────────────────────────────────────────────────────┘│
│ ○ 3 Antecedentes  │ ┌ 1 · Datos del paciente ─────────────────────────────── 👤 ┐  │
│ ○ 4 F. vitales    │ │ 1er apellido [________] 2º apellido [________]            │  │
│ ○ 5 Examen físico │ │ Nombres [______________________]                          │  │
│ ○ 6 Diagnósticos  │ │ Tipo doc [DNI ▾]  N.º [__________]                        │  │
│ ○ 7 Plan          │ │ F. nac. [dd/mm/aaaa] 📅   Edad  ⟨ 34 a 2 m ⟩ (auto)       │  │
│ ○ 8 Firma         │ │ Sexo (•)F ( )M ( )X   Tel [_______]  Dirección [________] │  │
│ ○ 9 Evoluciones   │ │ ▸ Datos complementarios                                   │  │
│                   │ └───────────────────────────────────────────────────────────┘  │
│ ─────────────     │ ┌ 4 · Funciones vitales ──────────────────────────────── ❤ ┐  │
│ 💾 Borrador       │ │ PA [120]/[80] mmHg  FC [78] lpm  FR [16] rpm  T [36.8] °C │  │
│ guardado 10:42    │ │ SpO₂ [98] %  Peso [72] kg  Talla [170] cm                 │  │
│ [Borrar borrador] │ │                     IMC ⟨ 24,9 kg/m² · Normal ⟩           │  │
│                   │ └───────────────────────────────────────────────────────────┘  │
│                   │ ┌ 6 · Diagnósticos ───────────────────────────────────── 🩻 ┐  │
│                   │ │ ⠿ 1 [Faringitis aguda          ] [J02.9] Principal ▾ ✕    │  │
│                   │ │ [+ Agregar diagnóstico]                                   │  │
│                   │ └───────────────────────────────────────────────────────────┘  │
│                   │ ┌ 9 · Evoluciones ────────────────────────────────────── 🕒 ┐  │
│                   │ │ Aún no hay evoluciones. [+ Agregar evolución]             │  │
│                   │ └───────────────────────────────────────────────────────────┘  │
└───────────────────┴────────────────────────────────────────────────────────────────┘
```
- El índice lateral está fijo, marca el avance de cada sección y salta a ella al hacer clic.
- La tecla Tab sigue el orden visual dentro de cada tarjeta y pasa a la siguiente.
- Atajos: `Ctrl+S` guarda el PDF y `Ctrl+Shift+R` abre la receta.
- **Tablet (600 a 1200 px):** el índice pasa a una barra de pestañas horizontal arriba y los campos se acomodan en 2 columnas.
- **Móvil (< 600 px):** una sola columna con secciones plegables, las acciones en una barra inferior y un botón flotante "℞ Receta".

### Pantalla 2: Receta
```
┌────────────────────────────────────────────────────────────────────────────────────┐
│ ← Volver a la historia   Receta   Formato [A5 vertical ▾]  N.º correlativo [✓]     │
│                                                     [🖨 Imprimir / Guardar PDF]      │
├──────────────── EDITOR ─────────────────────┬──────── VISTA PREVIA (el PDF real) ───┤
│ Paciente  (precargado desde la historia)    │      ┌───────────────────┐            │
│ [TORRES RUIZ, Juan] [DNI 12345678] [45 a]   │      │ ▓ Dra. Ana Pérez  │            │
│ Dx [J02.9 Faringitis aguda            ]     │      │   Medicina Int.   │            │
│ ┌ ⚠ ALERGIA: el paciente refiere            │      │ ───────────────── │            │
│ │ "penicilina". "Amoxicilina" (ítem 1)      │      │ Paciente: ...     │            │
│ │ pertenece a ese grupo. [Entendido]        │      │ ℞                 │            │
│ └───────────────────────────────────────────│      │ 1. AMOXICILINA... │            │
│ Medicamentos                                │      │ 2. PARACETAMOL... │            │
│ ┌ 1 ⠿ [Amoxicilina      ▾][500 mg][Cáps ▾]  │      │                   │            │
│ │     Dosis[1 cáps] Vía[Oral ▾] Cada[8 h]   │      │       firma sello │            │
│ │     Durante[7 días] Cant[21]→"veintiuno"  │      └───────────────────┘            │
│ │                              [↑][↓][🗑]   │       [−] 100 % [+]   Pág. 1/1        │
│ ├ 2 ⠿ [Paracetamol ...]                     │                                       │
│ [+ Agregar medicamento]                     │                                       │
│ Indicaciones generales [________________]   │                                       │
│ ☑ Incluir firma   ☑ Incluir sello           │                                       │
└─────────────────────────────────────────────┴───────────────────────────────────────┘
```
- **La vista previa es el PDF real** dibujado en pantalla con pdf.js local, y se actualiza unos 300 ms después de cada cambio. Así lo que ves es exactamente lo que se imprime. Lo recomiendo frente a imitar la hoja con widgets, que tarde o temprano difiere del papel.
- Los números de los ítems se recalculan al agregar, eliminar o arrastrar (⠿) y con los botones ↑↓.
- El autocompletado sale de la lista local de medicamentos; al elegir uno se proponen su concentración y su forma.
- En móvil, el editor y la vista previa van en pestañas: "Editar | Vista previa".

### Hoja de receta A5 (148 × 210 mm, vertical)
```
┌──────────────────────────────────────────────┐
│ [logo]  DRA. ANA PÉREZ GÓMEZ                 │
│         Medicina Interna · Reg. 012345       │
│         Consultorio San Juan · Av. X 123     │
│         Tel. 999 999 999        N.º R-000123 │
│                         Fecha: 02/10/2026    │
├──────────────────────────────────────────────┤
│ Paciente: TORRES RUIZ, Juan    DNI 12345678  │
│ Edad: 45 años                                │
│ Dx: J02.9 Faringitis aguda                   │
├──────────────────────────────────────────────┤
│ ℞                                            │
│ 1. AMOXICILINA 500 mg · cápsula              │
│    1 cápsula vía oral cada 8 h por 7 días.   │
│    Cantidad: 21 (veintiuno)                  │
│ 2. PARACETAMOL 500 mg · tableta              │
│    1 tableta vía oral cada 8 h si hay dolor  │
│    o fiebre, por 3 días.                     │
│    Cantidad: 9 (nueve)                       │
├──────────────────────────────────────────────┤
│ Indicaciones: abundantes líquidos...         │
│                                              │
│                        ⟨firma⟩    ⟨sello⟩    │
│                    ______________________    │
│                    Dra. Ana Pérez Gómez      │
│                    Reg. 012345               │
└──────────────────────────────────────────────┘
```
- **Media A4:** la misma información en una franja horizontal de 210 × 148,5 mm. El encabezado va a lo ancho, los ítems en una columna y la firma abajo a la derecha. Una línea de corte punteada marca la mitad de la hoja A4.
- Si los ítems no caben, la receta continúa en una segunda hoja con "(continúa)" y la numeración sigue.

### Modo "historia abierta"
```
┌ 📂 HISTORIA ABIERTA · Historia_TORRES_12345678_v3.pdf ──────────────────────────────┐
│ Creada 12/09/2026 · 3 evoluciones · ✅ Integridad verificada (4 sellos encadenados) │
│ ⓘ Solo puedes agregar evoluciones. El bloqueo lo aplica esta app, no el PDF. [Info] │
└─────────────────────────────────────────────────────────────────────────────────────┘
┌ 1 · Datos del paciente ─────────────── 🔒 Solo lectura ┐   ← fondo gris azulado,
│ TORRES RUIZ, Juan · DNI 12345678 · 45 a · M  [▾ ver]    │     se muestra como texto,
└─────────────────────────────────────────────────────────┘     plegada con un resumen
  … (secciones 2 a 8 iguales: bloqueadas y plegadas) …  [Expandir todo]

╔ 9 · EVOLUCIONES ─────────────────────────────── ZONA ACTIVA ╗  ← borde primario de 2 px
║ ● #1 12/09/2026 10:30 · Dra. Pérez · 🔒 sellada · 3f9a·c21e ║
║   Paciente refiere mejoría...                               ║
║ ● #2 19/09/2026 09:05 · Dra. Pérez · 🔒 sellada · 81bd·07aa ║
║   ...                                                        ║
║ ◉ NUEVA · [02/10/2026 09:14 ✎]                     [Descartar]║
║   [ Texto de la evolución ...                              ] ║
║   ☑ Firma ☑ Sello   [Plantilla SOAP] [+ Signos vitales]     ║
║ [+ Agregar evolución]                                        ║
╚══════════════════════════════════════════════════════════════╝
Barra: [⬇ Descargar historia actualizada ▾ (Nueva versión | Sobrescribir archivo)]
       [℞ Formular receta]  [✕ Cerrar historia]
```
- **Si la integridad falla:** el aviso superior se pone rojo ("⚠ Se detectaron alteraciones desde la evolución #2"). Esas entradas llevan un borde rojo y la etiqueta "No coincide". Agregar una evolución pide confirmación (pregunta 7).
- **Si el PDF no es de la app o está dañado:** aparece el diálogo "Este PDF no contiene datos de esta aplicación (o están dañados). Solo se pueden reabrir PDF generados aquí." con los botones [Elegir otro archivo] [Empezar historia nueva].
- **Al abrir:** hay un selector de archivos y una zona para arrastrar y soltar. En Chrome y Edge se usa `showOpenFilePicker`, que permite **sobrescribir ese mismo archivo** después. Si no está disponible, se usa `<input type=file>` y se guarda con una descarga normal.

---

## (d) Estructura de carpetas

```
historiasclinicas_net/
├─ lib/
│  ├─ main.dart
│  ├─ app/
│  │  ├─ app.dart                    # MaterialApp.router y ProviderScope
│  │  ├─ router.dart                 # go_router: "/" y "/receta"
│  │  └─ theme/                      # colores, tipografía, espaciados, componentes
│  ├─ core/
│  │  ├─ models/                     # historia, paciente, signos, diagnostico, evolucion,
│  │  │                              # medico, receta, item_receta (inmutables, toJson/fromJson)
│  │  ├─ pdf/
│  │  │  ├─ historia_pdf.dart        # A4: encabezado, secciones, evoluciones, paginación
│  │  │  ├─ receta_pdf.dart          # A5, media A4, 2 copias en A4
│  │  │  ├─ pdf_estilos.dart         # fuentes empaquetadas y estilos aptos para B/N
│  │  │  ├─ adjunto_writer.dart      # incrusta historia.json (PdfaAttachedFiles)
│  │  │  └─ adjunto_reader.dart      # lector propio: /EmbeddedFile, FlateDecode
│  │  ├─ integridad/
│  │  │  ├─ json_canonico.dart       # claves ordenadas, UTF-8, sin espacios
│  │  │  ├─ cadena_hash.dart         # sellar(base, evoluciones), SHA-256 encadenado
│  │  │  └─ verificacion.dart        # resultado: ok, alterado desde #n, inválido
│  │  ├─ storage/
│  │  │  ├─ borrador_store.dart      # autoguardado con debounce
│  │  │  ├─ medico_store.dart        # perfil, firma y sello (PNG)
│  │  │  ├─ medicamentos_store.dart  # lista editable, importar y exportar
│  │  │  └─ contador_recetas.dart
│  │  ├─ archivos/                   # abrir y guardar en web: showOpenFilePicker,
│  │  │                              # showSaveFilePicker, descarga, arrastrar y soltar
│  │  ├─ utils/                      # edad.dart, imc.dart, numero_a_letras.dart,
│  │  │                              # normalizar.dart (tildes), fechas.dart, nombres_archivo.dart
│  │  └─ widgets/                    # TarjetaSeccion, CampoEtiquetado, ChipsInput,
│  │                                 # BloqueoSoloLectura, BannerAviso...
│  └─ features/
│     ├─ historia/
│     │  ├─ historia_page.dart
│     │  ├─ estado/                  # HistoriaController (Riverpod), modo nueva/abierta
│     │  └─ secciones/               # un widget por sección, evoluciones_timeline.dart
│     ├─ receta/
│     │  ├─ receta_page.dart
│     │  ├─ estado/                  # RecetaController, numeración de ítems
│     │  ├─ widgets/                 # editor_item, vista_previa_hoja
│     │  └─ alertas_alergia.dart     # coincidencias de texto y grupos
│     ├─ medico/                     # panel "Datos del médico", lienzo de firma
│     └─ abrir/                      # diálogo de apertura, zona de soltar, errores
├─ assets/
│  ├─ fonts/                         # Inter (OFL) en TTF, para la interfaz y el PDF
│  └─ data/                          # medicamentos_base.json, grupos_alergia.json,
│                                    # cie10_es.json (opcional, carga diferida)
├─ web/
│  ├─ index.html, manifest.json, icons/
│  ├─ sw.js                          # service worker propio (precarga todo)
│  └─ pdfjs/                         # pdf.js local para la vista previa
├─ test/
│  ├─ unit/                          # edad, imc, numeración, número a letras, JSON canónico,
│  │                                 # cadena de hash y alteración, alertas
│  ├─ pdf/                           # generación de PDF, ida y vuelta del JSON incrustado
│  └─ widget/                        # formulario, modo bloqueado, receta
├─ tool/
│  └─ build_web.sh                   # build, lista de precarga del SW y versión
├─ docs/
│  ├─ PLAN.md (este archivo), DESPLIEGUE.md, DECISIONES.md, LICENCIAS.md
└─ pubspec.yaml, analysis_options.yaml, README.md
```

### Dependencias previstas
Todas se verifican en la Fase 0.

| Paquete | Uso | Licencia |
|---|---|---|
| `flutter_riverpod` | estado | MIT |
| `go_router` | rutas | BSD-3 |
| `pdf` y `printing` | generar, previsualizar e imprimir | Apache-2.0 |
| `crypto` | SHA-256 | BSD-3 |
| `archive` | inflar flujos Flate al leer | MIT |
| `shared_preferences` | perfil, borrador, listas | BSD-3 |
| `web` | interoperabilidad con el navegador (selectores de archivos, descarga) | BSD-3 |

- *Sin* `freezed` ni `build_runner`: los modelos se escriben a mano, porque así se controla el esquema versionado.
- La firma se dibuja con un lienzo propio (`CustomPainter` que exporta PNG transparente), sin dependencia extra.
- `syncfusion_flutter_pdf` solo se usaría si gana la comparación de la Fase 0 y tú aceptas su licencia.

### Diseño de integridad
- `hashBase = SHA-256("HC1|" + JSON canónico de la historia inicial)`
- `hash_i = SHA-256(JSON canónico de la evolución i (sin su hash) + "|" + hash_(i-1))`, con `hash_0 = hashBase`.
- Al abrir, se recalcula toda la cadena y se informa de la **primera** entrada que no coincide. Desde ahí, todo se considera no verificado.
- **Límite que debe quedar claro:** sin servidor y sin clave secreta, alguien con conocimientos podría modificar los datos y recalcular los hashes. La cadena detecta alteraciones accidentales y ediciones ingenuas del JSON, pero no prueba la autoría. Como respaldo, la huella corta de cada entrada se imprime en el papel, y el papel firmado sirve de ancla.
- Si alguien edita el *texto visible* del PDF con otro programa, la app lo ignora: siempre regenera el documento desde el JSON.

---

## (e) Plan por fases

Cada fase termina con `flutter analyze` sin advertencias, `flutter test` en verde y un resumen. Las capturas se toman con Chromium sin interfaz gráfica, que viene instalado en el contenedor.

### Fase 0: prueba de concepto (incrustar, reabrir y agregar)
- Instalar Flutter estable y limpiar la plantilla.
- Crear una pantalla mínima: "Generar PDF de prueba" → "Abrir PDF" → "Agregar evolución" → "Descargar actualizado".
- Prototipo **A:** `pdf` (`PdfaAttachedFiles`) y lector propio. Prototipo **B:** `syncfusion_flutter_pdf`.
- Comparar: funciona la ida y vuelta, robustez (PDF reabierto, flujos comprimidos), peso añadido a `main.dart.js` y licencia.
- Verificar sin conexión: compilar con `--no-web-resources-cdn` y ejecutar en Chromium en modo offline.
- **Entrego:** los PDF de ejemplo (puedes abrirlos en Acrobat y ver el adjunto), capturas, una tabla comparativa y la licencia exacta. **Me detengo hasta que elijas.**
- **Tests:** ida y vuelta del JSON (incluidas tildes y ñ), y PDF sin adjunto o truncado dan un error claro.

### Fase 1: historia clínica (diseño final)
- Tema Material 3 personalizado, fuentes empaquetadas, diseño adaptable (escritorio, tablet y móvil).
- Las 9 secciones con validación, orden de tabulación, índice lateral y cálculo automático de edad e IMC.
- Etiquetas de alergias, lista ordenable de diagnósticos y sección de evoluciones (crear, editar mientras está abierta, descartar).
- Autoguardado del borrador con debounce, aviso "guardado 10:42", botón para borrarlo y "Limpiar formulario" con confirmación.
- Avisos de privacidad y limitaciones.
- **Tests:** edad (incluidos años bisiestos y menores de 2 años), IMC y clasificación, serialización del modelo, widgets básicos del formulario y del borrador.

### Fase 2: datos del médico, firma y sello
- Panel con perfil, logo, firma subida o dibujada (PNG transparente con recorte automático) y sello.
- Guardado en el navegador, con opciones para cambiar o borrar.
- Interruptores de firma y sello por documento, más el aviso "imagen ≠ firma digital certificada".
- **Tests:** guardar y recuperar el perfil, y que el PNG de la firma sea transparente.

### Fase 3: receta de media hoja
- Ruta `/receta` con editor, vista previa real (pdf.js local) y formatos A5, media A4 y 2 copias en A4 (si lo apruebas).
- Ítems con numeración automática, agregar, eliminar y reordenar (arrastre y ↑↓). Cantidad en letras.
- Autocompletado desde la lista editable de medicamentos.
- Precarga desde la historia, alertas de alergia, contador correlativo opcional.
- "Volver a la historia" conserva todo lo escrito. CIE-10 opcional.
- **Tests:** numeración tras agregar, eliminar y reordenar; número a letras; alertas (tildes, grupos); precarga.

### Fase 4: PDF final, reapertura, PWA y despliegue
- PDF A4 final de la historia: encabezado, secciones, evoluciones con huella, firma y sello, paginación "Pág. X de Y", apto para blanco y negro.
- Nombres automáticos de archivo y sufijo de versión.
- Reapertura completa con verificación de la cadena, modo "historia abierta" y guardado con `showSaveFilePicker` o descarga normal.
- PWA: service worker propio, manifest e iconos. Prueba sin conexión automatizada con Playwright.
- `docs/DESPLIEGUE.md` para Netlify, Vercel, Firebase y hosting tradicional: HTTPS, cabeceras de caché y una Content-Security-Policy recomendada.
- GitHub Actions (opcional) con análisis y tests en cada push.
- **Tests:** generación de los dos PDF (tamaño de página, número de páginas, contenido), ida y vuelta completa con evoluciones, **detección de alteración** (cambiar un carácter en la evolución #2 da "alterado desde #2"), receta en todos sus formatos.
