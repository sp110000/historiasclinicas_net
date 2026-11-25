# Fase 5: el sistema de tu consultorio

> **Estado: 5.5 «Agenda» terminada, pendiente de tu visto bueno** (ver [«Avance»](#avance)). De la 5.0 a la 5.4 están aprobadas. Plan aprobado el 21/11/2026. Rama `claude/fase5-consultorio`, PR abierto hacia `main`.
> Todo lo nuevo va detrás de la bandera **`CONSULTORIO_ENABLED`** (`--dart-define`, apagada por defecto). Con la bandera apagada, el sitio público se comporta exactamente como hoy, y hay pruebas que lo comprueban (ver 5.0).
> Todo lo normativo va marcado **VERIFICAR**: son referencias para orientar, no asesoría legal. La validación legal la haces tú, idealmente con un abogado y un contador.

**Para qué es:** convertir la app en el sistema de tu consultorio en Santander de Quilichao, con dos líneas (medicina general con programa de peso, y contorno corporal con hidrolipoclasia), sin servidor y sin software de terceros.

**En una frase:** un almacén local cifrado con tu frase de acceso guarda el índice de pacientes, la copia de trabajo de las historias y los datos de gestión (agenda, caja, inventario, fotos). El PDF sellado sigue siendo el registro clínico legal, y un respaldo cifrado obligatorio protege todo contra la pérdida del equipo.

**Qué necesito de ti para seguir:** el visto bueno de la 5.5 y, sobre todo, revisar lo que quedó marcado VERIFICAR (textos de los consentimientos, certificados, incapacidad y órdenes; catálogo GLP-1, contraindicaciones, tamizajes y tu protocolo; los límites de la incapacidad del Decreto 1427 de 2022; los festivos y el mensaje del recordatorio por WhatsApp). Las preguntas de las subfases siguientes ya están aprobadas con su opción por defecto; si quieres cambiar alguna antes de la 5.6, dímelo.

---

## Decisiones confirmadas (21/11/2026)

| # | Tema | Decisión |
|---|---|---|
| 1 | Arquitectura | Aprobada con los ocho ajustes |
| 2 | Dónde corre | Otra dirección (subdominio), con la guía [fase5/PUBLICAR_CONSULTORIO.md](fase5/PUBLICAR_CONSULTORIO.md). No publico nada |
| 3 | Equipos | Portátil principal y celular secundario, con el paquete cifrado (5.2) |
| 4 | Frase y recuperación | Frase de 12 caracteres o más con medidor; código de recuperación de 24 caracteres con hoja PDF y confirmación de los últimos 4 |
| 5 | Derivación | PBKDF2-HMAC-SHA256 con 600.000 iteraciones; Argon2id se mide en tus equipos con «Medir la derivación» |
| 6 | Bloqueo | 10 minutos (de 2 a 60), «Bloquear ahora», llave descartada; borrador y receta cifrados con la bandera (llega en la 5.1, ver desviaciones) |
| 7 | Respaldo | Aviso a los 7 días; restaurar reemplaza todo. Ofrecer respaldo al cerrar la caja: en la 5.6 |
| 8 | Regla 10 | Acepta el inventario de este documento y la carpeta `lib/features/consultorio/` |
| 9 | Subfases | 5.0 «Cimientos» primero; el consentimiento informado pasa a la 5.3 |
| 10–51 | Todas las demás | Aprobadas con su opción *por defecto* («ok a todo», 21/11/2026). La 5.0 quedó aprobada el mismo día |

---

## Avance

### 5.6 Caja y paquetes ✅ (pendiente de tu visto bueno)

**Qué incluye**
- **Catálogo** con tus tarifas iniciales (pregunta 44), en **Ajustes → Caja**: cambiar una tarifa no toca lo ya cobrado; se agregan servicios (simples, valoración abonable o paquete de N sesiones de un procedimiento) y se desactivan los que no uses. El control del programa de peso usa la tarifa del control; si quieres otra, agrégala como servicio.
- **Caja** (en el riel, después de la historia: Agenda, Pacientes, Historia, Caja y Ajustes; el inventario llega en la 5.7):
  - el **día**, con los recibos (también los anulados, con su motivo), las sesiones de paquete usadas (sin recibo), las anulaciones de días cerrados que restan ese día y los **totales por medio de pago**;
  - los **saldos por cobrar** de todos los días, con «Abonar»;
  - el **informe del mes**: por servicio y por línea (lo cobrado neto, en el mes del cobro), el recaudo por medio (en el día de cada recibo), los créditos de valoración aplicados y el **volumen por técnica** (valoraciones y sesiones selladas). Todo baja en **CSV** con `;`, UTF-8 con BOM y CRLF (pregunta 47), igual que el día.
- **Cobrar** (desde la caja, la cita o la ficha):
  - paciente (o «Paciente nuevo»), servicios con cantidad, **descuento con motivo** obligatorio y el valor del catálogo;
  - desde la cita, el servicio sale de su tipo (primera vez, control, valoración o sesión), y la tarjeta de la cita queda «Cobrada» o con su saldo;
  - el **crédito de la valoración** se aplica solo cuando hay un tratamiento estético (se puede quitar), y si no se aplica, avisa;
  - si el paciente tiene un **paquete con sesiones**, el cobro lo ofrece primero: «Usar una sesión (sin cobro)»;
  - **pagos por medio** (efectivo, transferencia, Nequi, Daviplata y tarjeta) con referencia; el primero toma lo que falta, y se pueden combinar. Sin pago, el cobro queda con saldo y **no hay recibo** (pregunta 46).
- **Recibo RC-000001** en PDF A5 (en el equipo secundario, RC-S000001): tus datos, el paciente, lo cobrado con descuentos y crédito, este pago por medio, lo pagado a la fecha, el saldo, la firma y el aviso **«Este documento no es una factura electrónica de venta.»** (DIAN, VERIFICAR con tu contador). Queda cifrado y se vuelve a descargar desde la caja o la ficha.
- **Paquete:** cobrarlo crea el paquete de 4 sesiones (sin vencimiento, pregunta 45). Usar una sesión **no genera recibo**; agotado, no deja usar más y pide cobrar la sesión.
- **Crédito de la valoración abonable:** pagada del todo, deja su valor como crédito por **30 días**, que se descuenta del tratamiento.
- **Anular** con motivo:
  - un recibo: sale de los totales y el saldo vuelve. Si el crédito de esa valoración ya se usó, primero hay que anular el tratamiento;
  - un cobro sin recibos vigentes: libera el crédito que tenía aplicado y anula el paquete si no tiene sesiones usadas.
- **Cierre del día:** totales por medio, efectivo esperado, **efectivo contado** y la diferencia (sobra o falta), con notas. **No se reabre:** ese día no se registran más pagos ni se anulan recibos. Un recibo de un día cerrado se anula después y **resta en el día en que se anula**, con referencia al original. Al cerrar se ofrece **descargar el respaldo** (decisión 7).
- **En la ficha:** «Cobrar» entre las acciones y la sección **Caja** con el saldo, los cobros con saldo («Abonar»), los paquetes (quedan N de 4, «Usar una sesión»), el crédito vigente y los recibos.
- Todo queda en la **bitácora** (cobro, pago, anulaciones, sesión de paquete, cierre, catálogo y exportación).

**Verificación**

| Comprobación | Resultado |
|---|---|
| `dart format`, `flutter analyze` | Sin problemas |
| `flutter test` | **686 en verde** (644 en la 5.5). Por tabla: totales y saldos (5 casos) y 9 bloqueos del cobro; además, el crédito sin aplicar, los totales del día con la anulación de un día cerrado (resta el día en que se anula), el CSV (BOM, `;`, CRLF y comillas) y el informe del mes. En el servicio, cifrado y al reabrir: **consecutivo sin saltos ni repetidos** (un cobro sin pago no gasta número; un anulado lo conserva), serie S, **paquete agotado**, crédito de 30 días aplicado y liberado, **anulación** (también la de un día cerrado), **día cerrado inmutable**, el recibo PDF leído con `pdftotext` y la bitácora. 8 pruebas de interfaz, también a 390 y 320 px |
| Bandera apagada | La 5.6 no tocó ningún archivo compartido: el `main.dart.js` público **pesa lo mismo desde la 5.1** (5.333.404 bytes) y no lleva el módulo |
| Bandera encendida | El `main.dart.js` del consultorio pesa **6.172 KB** (6.077 KB en la 5.5) |
| Contraste | Textos con los colores del tema (≥ 4,5:1); lo que falta o sobra va en el color de aviso del tema |
| 320 px | Caja, cobro, cierre y la sección de la ficha sin desbordes, con prueba |
| e2e del consultorio en Chromium, **sin conexión y con la CSP** | **57 de 57 pasos** (50 de antes y 7 nuevos). Con el reloj fijado al lunes 30/11/2026, 9:15: **cobro desde la cita con abono** de $ 20.000 (recibo leído con `pdftotext`: saldo $ 25.000 y «no es una factura electrónica de venta»); valoración por transferencia con referencia; **paquete de 4 sesiones con el crédito de $ 70.000** aplicado, con tarjeta; **sesión del paquete sin recibo**; abono del saldo desde «Saldos por cobrar»; totales por medio ($ 925.000); **informe del mes y su CSV** (BOM, `;` y CRLF); **cierre del día** sin diferencia, con el respaldo ofrecido y descargado y sin «Anular» después; CSV del día; móvil y 320 px. Nada en claro (tampoco la referencia del pago ni el número de recibo). 0 peticiones externas, 0 fallidas, 0 errores de consola, 0 excepciones de Flutter |

**Problemas encontrados y corregidos en la 5.6**
1. **Con la caja de hoy cerrada, cada recibo seguía ofreciendo «Anular»**, que el servicio rechazaba al final. Ahora no se ofrece hasta el día siguiente, con prueba.
2. **Un día cerrado podía cambiar** si se anulaba ese mismo día uno de sus recibos (sumaba y restaba en el mismo día, distinto del cierre guardado). Por eso, con la caja de hoy cerrada no se anula nada hasta mañana.
3. Las capturas de la caja salían con el aviso «Recibo … descargado» encima. La e2e espera a que se vaya.
4. En la e2e, los valores en pesos se reescriben con el separador de miles mientras se escriben («20000» queda «20.000»). La e2e compara el valor ya formateado.
5. En una prueba, dos cobros hechos en el mismo minuto salían en cualquier orden. La prueba busca el del paquete por su servicio.

**Desviaciones del plan**
- **El valor de cada servicio sale del catálogo**; lo que cambie en un cobro va como descuento con motivo, para que el informe muestre los descuentos.
- **Un paquete se cobra de una vez** (con abonos si hace falta); no hay devolución parcial: se anula el recibo (y, sin sesiones usadas, el cobro). Una devolución por sesiones no usadas queda para cuando la definas (pregunta 45).
- **El día cerrado tampoco anula recibos de ese día:** la anulación se hace al día siguiente y resta allí (así el cierre guardado no cambia).
- **La caja no viaja en el paquete del equipo secundario:** sus recibos llevan la serie S para no chocar, y la caja lo avisa. Se lleva en el principal.
- «Registrar y ver recibo» del boceto es **«Registrar y descargar el recibo»**, como los demás documentos.

**Evidencias (`docs/fase5/`)**
- **Escritorio (1440 px):** [cobro con abono](fase5/escritorio_caja_cobro.png) · [caja del día](fase5/escritorio_caja_dia.png) · [informe del mes](fase5/escritorio_caja_informe.png) · [caja cerrada](fase5/escritorio_caja_cierre.png)
- **Móvil (390 px):** [caja](fase5/movil_caja.png)
- **320 px:** [caja](fase5/320_caja.png)
- **PDF:** [recibo con abono](fase5/pdf_recibo.png) · [recibo del paquete con el crédito](fase5/pdf_recibo_paquete.png)

### 5.5 Agenda ✅ (aprobada el 25/11/2026)

**Qué incluye**
- **La agenda es el inicio** con la bandera encendida y la primera del riel (pregunta 51). La historia sigue a un clic.
- **Citas por tipo, con duración, estado e historial:**
  - tipos y duraciones: primera vez 30 min, control 20, programa de peso 30, valoración estética 40 y sesión 60 (editables);
  - estados: agendada, confirmada, atendida, no asistió y cancelada. Cancelar pide motivo, y cada cambio queda con su fecha.
- **Vistas:**
  - de día, con el horario, los festivos y los bloqueos;
  - de semana, una columna por día con bloques por tipo, que se distinguen por color **y** por ícono;
  - en móvil solo la de día, deslizando entre días.
- **Agendar** (agenda → «+ Cita», o la ficha → «Agendar cita»):
  - paciente con buscador o «Paciente nuevo»;
  - tipo y procedimiento (en la valoración y la sesión);
  - día, hora y duración, con las **horas libres** de ese día.
- **Reglas puras con pruebas por tabla.**
  - **Bloquean:** falta el paciente o la duración no es válida; en una valoración estética o una sesión, un menor de 18 años o sin fecha de nacimiento (Ley 1799 de 2016, VERIFICAR); una **sesión sin un «apto» vigente el día de la cita** (falta, «no apto», «diferir» o vencido).
  - **Avisan sin bloquear:** cita en el pasado, festivo, fuera del horario, bloqueo y cruce con otra cita (pregunta 42).
- **Festivos de Colombia calculados**, con los que se trasladan al lunes y los que dependen de la Pascua (Ley 51 de 1983, VERIFICAR).
- **Recordatorios** (pregunta 43):
  - «Mañana: N citas sin recordatorio», con «Enviar» por cita;
  - WhatsApp con el **mensaje editable y sin datos de salud** ni el tipo de cita, al celular con +57; se abre en otra pestaña y la cita queda con el recordatorio enviado;
  - un **`.ics`** que solo dice «Cita médica», con la hora y el lugar.
- **Desde la cita:** estado, WhatsApp, `.ics`, Ficha, Reprogramar y **Atender**, que abre la evolución de la historia más reciente (o una historia nueva) con el paciente cargado y deja la cita atendida.
- **«Controles vencidos (N)»** en la agenda lleva a la lista de pacientes filtrada.
- **En la ficha:** «Agendar cita», la próxima cita, el contador de inasistencias y las citas en la línea de tiempo. «No asistió» no consume nada y deja vigente el control vencido.
- **Ajustes → Agenda:** horario por día («8:00–12:00, 14:00–18:00»), duraciones, mensaje del recordatorio y bloqueos (vacaciones, reuniones).

**Verificación**

| Comprobación | Resultado |
|---|---|
| `dart format`, `flutter analyze` | Sin problemas |
| `flutter test` | **644 en verde** (587 en la 5.4). Por tabla: 10 bloqueos y 6 avisos de la cita, 10 cambios de estado, los festivos de 2025 y 2026 (con San Pedro y el Sagrado Corazón el mismo lunes de 2025), franjas escritas a mano, horas libres, número de WhatsApp (8 casos), mensaje y URL codificada, y `.ics` sin datos de salud y con líneas de 75 octetos o menos. Además, el servicio (cifrado y al reabrir) y 12 pruebas de interfaz, también a 390 y 320 px |
| Bandera apagada | La 5.5 no tocó ningún archivo compartido: el `main.dart.js` público **pesa lo mismo desde la 5.1** (5.333.404 bytes) y no lleva el módulo |
| Bandera encendida | El `main.dart.js` del consultorio pesa **6.077 KB** (6.000 KB en la 5.4) |
| Contraste | Textos con los colores del tema (≥ 4,5:1); el color de cada tipo solo pinta la franja y el ícono, con el texto en tinta |
| 320 px | Agenda (solo de día) sin desbordes, con prueba |
| e2e del consultorio en Chromium, **sin conexión y con la CSP** | **50 de 50 pasos** (44 de antes, uno de ellos ahora «abre en la agenda», y 6 nuevos). Abre en la agenda. Con el reloj del navegador fijado al lunes 30/11/2026, 9:15: «Agendar cita» desde la ficha con una hora libre; dos citas más desde «+ Cita» (una buscada por nombre, otra para mañana); el aviso de mañana sin recordatorio; «Confirmada»; **WhatsApp interceptado** (`wa.me/57…`, sin datos de salud); el `.ics`; la semana; **«Atender»** con la historia prellenada y la cita atendida; móvil y 320 px. 0 peticiones externas, 0 fallidas, 0 errores de consola, 0 excepciones de Flutter |

**Problemas encontrados y corregidos en la 5.5**
1. **Un bloqueo que terminaba justo a la medianoche no tapaba ese día** en las horas libres (por ejemplo, unas vacaciones de domingo a lunes). Corregido, con prueba.
2. **A 390 y 320 px, el nombre del paciente en «Mañana: … sin recordatorio» empujaba «Enviar» fuera de la pantalla.** Ahora el nombre se parte, con prueba.
3. Al abrir en la agenda, el primer paso de la e2e esperaba la historia, y una prueba con la bandera esperaba las rutas de antes. Se actualizaron.
4. «Programa de peso» aparece dos veces en Ajustes (también es un tipo de cita); la prueba de la 5.3 busca ahora su tarjeta.
5. **Al angostar la ventana de la agenda, el motor web lanzaba «Null check…».** El gesto de deslizar entre días solo existía en móvil, y al cruzar el corte el área cambiaba de rol en el árbol de accesibilidad. Ahora el gesto está siempre y queda fuera de ese árbol; los lectores de pantalla usan «‹» y «›». Lo encontró la e2e, que lo reprodujo antes del arreglo y no después.
6. **En una cita de valoración estética, la tarjeta avisaba «sin «apto» vigente»**, y confundía: la valoración es la que da el «apto». Ese aviso (y el del consentimiento) sale ahora solo en las sesiones.
7. En la e2e: el riel nombra sus destinos «Agenda Pestaña 1 de 4», «Día» y «Semana» son radios, las horas libres son chips sin el rol de botón, y la franja de la historia dibuja la flecha como ícono. La e2e los busca así.

**Desviaciones del plan**
- **Una cita siempre es de una ficha.** Para una primera vez, «Paciente nuevo» crea la ficha con lo mínimo, en lugar de guardar en la cita un nombre y un teléfono provisionales.
- **Fuera del horario, festivo y bloqueo avisan, no bloquean.** El plan lo decía solo de los cruces.
- **WhatsApp solo se ofrece a celulares colombianos** (10 dígitos que empiezan por 3) o a números con «+indicativo». Un fijo no.
- **«Cobrar» llegó con la caja (5.6).** «Atender» marca la cita atendida al abrir la historia.
- **El aviso de recordatorios de mañana se ve siempre en la agenda**, no solo en la mañana.
- **El paquete del equipo secundario no lleva citas:** se agendan en el principal.

**Evidencias (`docs/fase5/`)**
- **Escritorio (1440 px):** [agenda del día](fase5/escritorio_agenda_dia.png) · [recordatorio por WhatsApp](fase5/escritorio_agenda_whatsapp.png) · [semana](fase5/escritorio_agenda_semana.png) · [«Atender»](fase5/escritorio_agenda_atender.png)
- **Móvil (390 px):** [agenda](fase5/movil_agenda.png)
- **320 px:** [agenda](fase5/320_agenda.png)

### 5.4 Documentos ✅ (aprobada el 25/11/2026)

**Qué incluye**
- **Cuatro documentos nuevos, con consecutivo propio:** certificado (CE-), incapacidad (IN-), orden de laboratorio o imágenes (OR-) y remisión o interconsulta (RM-) (pregunta 40).
  - Los expide el médico, sin la firma del paciente, con tus datos, tu firma y tu sello (los mismos interruptores de siempre).
  - Al emitirlo **se descarga su PDF** y queda en la ficha (pregunta 37).
  - Se **anulan** con motivo, no se revocan, y su número no se reutiliza.
- **Plantillas con versiones, varias por tipo**, todas en BORRADOR con espacios «______» (VERIFICAR):
  - certificado general, laboral, deportivo y de asistencia;
  - incapacidad;
  - órdenes de perfil metabólico, TSH, HbA1c, perfil lipídico, función hepática e imágenes diagnósticas (pregunta 41, sin códigos CUPS);
  - remisión o interconsulta.

  Se aprueban en Ajustes → Documentos clínicos (una tarjeta plegada, con el resumen «4 de 12 aprobadas») o en el mismo formulario. Puedes **agregar plantillas propias** (por ejemplo, otra orden frecuente). Cada documento guarda la plantilla y la versión con que se emitió.
- **El mismo formulario para todos** (ficha → «Documento»):
  - plantilla, datos del tipo y texto prellenado y editable;
  - **vista previa del PDF real**, como la receta: dos columnas desde 1100 px, y pestañas «Editar» y «Vista previa» en pantallas angostas;
  - botón fijo «Emitir y descargar» que **dice por qué** no se puede.
- **Los datos de cada tipo van aparte del texto**, en un bloque del PDF; así cambiar un dato no obliga a reescribir el texto:
  - certificado: «Se expide con destino a» (Ley 23 de 1981, art. 51, VERIFICAR). El diagnóstico solo va si el paciente lo autoriza;
  - incapacidad: diagnóstico con el **buscador CIE-10** de la historia, origen, días (también en letras), desde, hasta, prórroga y el prestador (nombre, NIT y código REPS);
  - orden: impresión diagnóstica;
  - remisión: especialidad o servicio, y diagnóstico.

  El diagnóstico principal de la última historia viene prellenado.
- **Reglas puras con pruebas por tabla.**
  - **Bloquean:** plantilla en borrador, tus datos de médico incompletos, texto vacío, certificado sin finalidad (o con el diagnóstico pedido y vacío), incapacidad sin diagnóstico o sin días, remisión sin destino, y un texto que viene de otra versión de la plantilla.
  - **Avisan:** diagnóstico sin CIE-10, falta el NIT o el código REPS, incapacidad retroactiva, más días o más retroactividad que tus límites, orden o remisión sin diagnóstico, y «______» sin completar.
  - Los **límites de días y de retroactividad** del Decreto 1427 de 2022 se escriben en Ajustes → Prestador **solo cuando los verifiques**; en blanco no avisan.
- **PDF A4** con `documento.json` incrustado y sellado, la huella en el pie y en el índice. La ficha lo muestra con sus datos («Días: 3 (tres) · Desde: …»).
- **Importación en lote de documentos y recetas** (Pacientes → Importar PDF), además de las historias:
  - verifica la huella de `documento.json` y `receta.json` y, si el documento ya estaba, que sea el mismo («Ya estaba, íntegro»);
  - un documento de otro equipo se liga a la ficha del mismo paciente (por id, por historia o por documento de identidad) sin tocar lo sellado, y adelanta el consecutivo para no repetir números;
  - un PDF alterado, uno con un número ya usado por otro documento o uno sin ficha **no se importa**, y el informe dice por qué.

**Verificación**

| Comprobación | Resultado |
|---|---|
| `dart format`, `flutter analyze` | Sin problemas |
| `flutter test` | **587 en verde** (540 en la 5.3). Por tabla: 9 bloqueos y 9 avisos de los documentos, más los válidos de cada tipo y «sin límites escritos no avisa». Además: días en letras, fecha final, filas del PDF desde lo sellado, plantillas de fábrica y propias, emitir los cuatro tipos (número, `documento.json` y texto del PDF con `pdftotext`), anular, e importar (ya estaba, otro equipo, alterado, número repetido, sin ficha, recetas y lote mezclado) |
| Bandera apagada | La 5.4 no tocó ningún archivo compartido: el `main.dart.js` público **pesa lo mismo que en la 5.1, la 5.2 y la 5.3** (5.333.404 bytes) y no lleva el módulo |
| Bandera encendida | El `main.dart.js` del consultorio pesa **6.000 KB** (5.946 KB en la 5.3) |
| Contraste | Textos y avisos con los colores del tema, ya probados (≥ 4,5:1) |
| 320 px | Los cuatro formularios sin desbordes, con prueba |
| e2e del consultorio en Chromium, **sin conexión y con la CSP** | **44 de 44 pasos** (37 de antes y 7 nuevos). Desde la ficha de Peña: **certificado** con la plantilla aprobada en el formulario, **incapacidad** de 3 días con CIE-10 y el aviso «Falta tu NIT», **orden** «Perfil metabólico» y **remisión**, cada uno descargado y leído con `pdftotext`. El formulario en 390 y 320 px. El certificado y la orden se **reimportan**: «Ya estaba, íntegro». 0 peticiones externas, 0 fallidas, 0 errores de consola, 0 excepciones de Flutter |

**Problemas encontrados y corregidos en la 5.4**
1. **A 320 px, la barra de «Emitir y descargar» se desbordaba 38 px.** En pantallas angostas, ahora el motivo va arriba y el botón abajo, con prueba en los cuatro tipos.
2. **En los interruptores solo respondía el botón**, no su texto («Es una prórroga»). Ahora responde toda la fila.
3. **La tarjeta de documentos clínicos ponía doce botones «Aprobar v1» en Ajustes**, y la e2e de la 5.3 aprueba «la primera pendiente». La tarjeta empieza plegada, con el resumen, y cada plantilla también se aprueba desde el formulario.
4. Una prueba de la 5.1 contaba cuatro plantillas en Ajustes; los documentos clínicos tienen ahora su propia tarjeta.
5. **La vista previa tardaba unos segundos en ponerse al día en Chromium sin GPU**, y las primeras capturas salieron con la anterior. La barra de progreso lleva ahora la etiqueta «Actualizando la vista previa», que también oye un lector de pantalla, y la e2e espera a que desaparezca.
6. En la e2e, el menú «Documento» expone sus elementos como botones, y el nodo de accesibilidad de «Unir con otra ficha» queda encima en el DOM y se llevaba el clic. La e2e envía el clic directo al elemento. Con el ratón o un lector de pantalla funciona bien.
7. La integración continua de los dos primeros commits de la 5.4 quedó en rojo: la e2e de la 5.3 aprobaba la primera «Aprobar v1» de Ajustes y encontraba una de documentos clínicos. Se arregló plegando esa tarjeta (punto 3).

**Desviaciones del plan**
- **Varias plantillas por tipo, y propias**, también en certificados y remisiones. El plan las preveía solo para las órdenes frecuentes.
- **Los datos del tipo van en un bloque aparte del PDF**, no como marcadores en el texto.
- **El certificado laboral es un certificado médico general con destino laboral.** Las evaluaciones médicas ocupacionales tienen su propia norma (VERIFICAR), y el formulario lo advierte.
- **Un documento o una receta sin ficha del paciente no se importa**, porque lo sellado no alcanza para llenarla bien. Importa primero su historia o crea la ficha.
- **El estado no viaja en el PDF.** Reimportar un documento anulado en el mismo equipo no lo revive; en otro equipo entra vigente.
- **Una receta repetida (mismo id) queda como «ya estaba»**, aunque su PDF se haya vuelto a guardar.
- **El origen de la incapacidad** (general, accidente de trabajo o enfermedad laboral) se registra, pero no cambia nada más. La de origen laboral la reconoce la ARL (VERIFICAR).

**Evidencias (`docs/fase5/`)**
- **Escritorio (1440 px):**
  - [certificado con la plantilla en borrador](fase5/escritorio_certificado_borrador.png) · [certificado listo, con la vista previa](fase5/escritorio_certificado.png)
  - [incapacidad con aviso](fase5/escritorio_incapacidad.png) · [orden](fase5/escritorio_orden.png)
  - [ficha con los documentos](fase5/escritorio_ficha_documentos.png) · [reimportación](fase5/escritorio_reimportacion.png) · [Ajustes → Documentos clínicos](fase5/escritorio_ajustes_documentos.png)
- **Móvil (390 px):** [formulario](fase5/movil_documento.png)
- **320 px:** [formulario](fase5/320_documento.png)
- **PDF (primera página):** [certificado](fase5/pdf_certificado.png) · [incapacidad](fase5/pdf_incapacidad.png) · [orden](fase5/pdf_orden.png) · [remisión](fase5/pdf_remision.png)

### 5.3 Programa de peso, valoración estética, consentimiento y sesiones ✅ (aprobada el 22/11/2026)

**Qué incluye**
- **Programa de peso** (ficha → Peso):
  - inicio, meta (peso, cintura y fecha) con el avance desde el inicio, y la meta en la gráfica del seguimiento (pregunta 27);
  - proteína indicada (la cantidad la fijas tú) y el recordatorio de proteína y fuerza en la ficha y en las indicaciones impresas (pregunta 26);
  - planes nutricional y de ejercicio tomados de **plantillas aprobadas** y ajustables por paciente. Las tres de fábrica traen solo los apartados en blanco («______»), sin cifras;
  - **indicaciones en PDF** con tu firma.
- **GLP-1** (pregunta 24):
  - catálogo editable: semaglutida subcutánea y oral, liraglutida y tirzepatida. **Solo OZEMPIC® trae registro** (2019M-0019473, para diabetes tipo 2); los demás dicen «registro Invima sin confirmar» hasta que escribas el número;
  - ningún esquema trae dosis: el esquema de titulación lo escribes y **lo apruebas** en Ajustes; aprobado, el cambio de dosis lo sugiere;
  - inicio, cambios de dosis, tolerancia, **eventos adversos** (con «reportado a Invima») y suspensión. El inicio, los cambios, los eventos y la suspensión se agregan a la evolución en curso.
- **Contraindicaciones del GLP-1** (pregunta 25): una absoluta en «sí» **o sin aclarar** impide iniciar; una precaución en «sí» o «no sabe» pide nota; embarazo, lactancia y anticoncepción solo se preguntan a mujeres (o si no hay sexo registrado). Todo VERIFICAR contra la ficha técnica.
- **Plantilla declarativa de procedimiento** (Ajustes → Procedimientos; hidrolipoclasia de fábrica, en borrador):
  - valoración: zonas, IMC desde el que avisa (30), vigencia del «apto» (90 días), contraindicaciones que dan «no apto» o «diferir», precauciones con nota, tamizajes y recomendaciones;
  - **tamizajes SCOFF y DCQ solo con su estructura** (número de ítems, escala y corte, VERIFICAR); el texto de los ítems lo cargas tú (pregunta 30);
  - **protocolo de la sesión vacío** (componentes, volumen máximo por zona y por sesión, intervalo, número de sesiones, anestésicos con concentración y máximo en mg/kg, lista de verificación, indicaciones y días hasta el control) y los riesgos y alternativas del consentimiento (pregunta 31). **Sin el protocolo completo la plantilla no se aprueba, y sin aprobar no se usa**. Agregar toxina o rellenos es agregar otra definición.
- **Valoración** (ficha → Estética → «Nueva valoración»):
  - candidato (peso, talla e IMC con aviso), zonas con grasa pinzable en cm, elasticidad y flacidez, expectativas, contraindicaciones, tamizajes y resultado;
  - las contraindicaciones fijan el **resultado mínimo**; «no apto» y «diferir» piden motivo; «apto» vale 90 días; recomendación de una lista editable;
  - **un menor de 18 años no puede tener valoración** (Ley 1799 de 2016, VERIFICAR) y sin fecha de nacimiento se pide en la ficha;
  - **se sella como evolución** en la historia más reciente: se genera y **descarga la versión nueva del PDF** y queda en el índice (pregunta 29).
- **Consentimiento informado por plan** (CI-, pregunta 39): plantilla en BORRADOR con los apartados del art. 16 del Proyecto de Ley 187 de 2026 (no es ley) y del art. 15 de la Ley 23 de 1981 (**VERIFICAR con tu abogado**). Cubre un plan (procedimiento, zonas, sesiones y producto) que viaja en `documento.json`; lleva tu registro, la certificación vigente, el REPS, la habilitación y la póliza. Se revoca o se anula con motivo; uno nuevo toma el número siguiente.
- **Sesión** (ficha → Estética → «Registrar sesión», pregunta 35):
  - lista de verificación previa (pregunta 33), zonas del consentimiento con su volumen, solución con lote y vencimiento, anestésico con la **dosis en mg y mg/kg** (con el peso de los últimos 30 días o el «peso de hoy», que queda como medición), equipo, insumos con lote, duración, eventos adversos, indicaciones y control;
  - **reglas puras con pruebas por tabla.** Bloquean: plantilla sin aprobar, menor de 18, valoración que falta, «no apto», «diferir» o vencida, consentimiento que falta o revocado, zona fuera del consentimiento, más sesiones que el plan, lista incompleta, volumen sobre el máximo, peso viejo, **dosis por encima del máximo**, lote sin escribir o **vencido**. Avisan: dosis desde el 80 %, menos días que el intervalo, protocolo de otra versión que el consentimiento y técnica sin certificación;
  - el botón de sellar va fijo abajo y **dice por qué** no se puede; en pantallas angostas, bloques plegables;
  - **se sella como evolución con todo lo clínico** y el próximo control, y se descarga la versión nueva del PDF.
- **Certificaciones por técnica** (Ajustes, pregunta 36): entidad, fecha, vigencia y soporte (PDF o foto, cifrado); se retiran sin borrarse. Sin certificación vigente, la sesión **avisa y queda en la bitácora**, sin bloquear.
- **Prestador y póliza** (Ajustes, pregunta 34): código REPS, NIT, habilitación del servicio y póliza de complicaciones (o «sin póliza»), que se copian al consentimiento y a la sesión.

**Verificación**

| Comprobación | Resultado |
|---|---|
| `dart format`, `flutter analyze` | Sin problemas |
| `flutter test` | **540 en verde** (469 en la 5.2). Las reglas van por tabla: contraindicaciones del GLP-1 (9 casos), edad y resultado mínimo de la valoración (8), y la sesión (16 bloqueos y 3 avisos): menor de 18, «no apto», «diferir», valoración vencida o faltante, consentimiento faltante o revocado, zona fuera del plan, más sesiones que el plan, plantilla sin aprobar, dosis por encima del máximo, lote vencido o sin escribir, peso viejo, lista incompleta, volumen sobre el máximo, dosis al 80 %, intervalo y técnica sin certificación (aviso registrado) |
| Bandera apagada | La 5.3 no tocó ningún archivo compartido: el `main.dart.js` público **pesa lo mismo que en la 5.1 y la 5.2** (5.333.404 bytes) y no lleva el módulo (`verificar_compilacion.dart`) |
| Bandera encendida | El `main.dart.js` del consultorio pesa **5.945 KB** (5.752 KB en la 5.2: +193 KB) |
| Contraste | Los textos y pastillas nuevos usan los colores del tema, ya probados (≥ 4,5:1). Los chips de selección (zonas, líneas de atención y filtros de la lista) ahora llevan el texto en blanco cuando están elegidos, con prueba |
| 320 px | Programa de peso, valoración y sesión plegable sin desbordes, con prueba |
| e2e del consultorio en Chromium, **sin conexión y con la CSP** | **37 de 37 pasos** (30 de antes y 7 nuevos). Aprobar el consentimiento informado y un plan; **escribir y aprobar el protocolo** (valores de prueba); prestador y póliza; **programa de peso** con la lista de contraindicaciones y semaglutida 0,25 mg; **valoración «apto»** sellada (historia v2); **sesión bloqueada sin consentimiento**; **consentimiento por plan** firmado en pantalla; **sesión bloqueada por un lote vencido**; corregida, **sellada** (historia v3, cuyo texto se lee con `pdftotext`: lote, dosis en mg/kg y control). 0 peticiones externas, 0 fallidas, 0 errores de consola, 0 excepciones de Flutter |

**Problemas encontrados y corregidos en la 5.3**
1. **Firmar cualquier documento que no fuera el consentimiento de imagen lo dejaba como «autorización de datos» de la ficha.** Con el consentimiento informado, firmar uno habría reemplazado la autorización. Ahora solo la autorización y el consentimiento de imagen tocan esos enlaces, con prueba.
2. **La e2e borró sin querer la lista de verificación del protocolo:** al escribir en otro campo de una página larga, borraba con Ctrl+A aunque el foco no hubiera llegado, y la plantilla no se aprobó por la lista vacía. La app estaba bien; ahora la e2e solo escribe con el foco en el campo correcto, lleva cada elemento a la vista antes de hacer clic y comprueba la lista y la aprobación.
3. Las pruebas de la 5.1 suponían tres plantillas de documentos y que «la última» era la política; ahora buscan dentro de la fila de cada una.
4. **El campo «Peso de hoy» de la sesión desaparecía al escribir la primera cifra:** la pantalla decidía si pedirlo con el peso que se estaba escribiendo. Ahora lo decide al abrir la sesión y el campo sigue a la vista; borrar el peso devuelve el anterior. Lo encontró la e2e; tiene prueba de widgets.
5. **Las zonas elegidas casi no se leían:** los chips de selección de Material dejaban el texto oscuro sobre el fondo petróleo. El tema es compartido con el sitio público, así que el arreglo va en un chip propio del consultorio (texto blanco, ≥ 4,5:1, con prueba), también en las líneas de atención y los filtros de la lista de pacientes de la 5.1.
6. **Texto sellado de la sesión:** las indicaciones que terminaban en punto salían con «..», y el aviso de certificación decía «se registrará el aviso» dentro de la evolución ya sellada. Ahora cada frase lleva un solo punto y el aviso dice solo lo que falta; la pantalla aclara que los avisos quedan en la evolución y en la bitácora.
7. **La familia de técnicas de fábrica decía «Lipólisis por infiltración (VERIFICAR)»** y ese nombre terminaba en el texto sellado. Ahora el VERIFICAR va en la etiqueta del editor y el nombre queda limpio.
8. En la e2e, los chips de las zonas cuentan como casillas en el árbol de semántica y se marcaban con la lista de verificación; ahora la lista se recorre por el nombre de cada elemento.
9. Durante la 5.3 se reinició el proceso de esta sesión; no se perdió nada (todo estaba en la rama o en el disco).

**Desviaciones del plan**
- **«No sabe» en una contraindicación absoluta también impide iniciar el GLP-1.** El plan decía solo «sí»; me pareció más prudente pedir que se aclare (por ejemplo, el embarazo).
- **El motivo es obligatorio en «no apto» y «diferir»**, no en «apto», donde queda opcional.
- **La lista de contraindicaciones del GLP-1 es fija en esta versión** (la de la pregunta 25, versión 1). Si la cambias, cada revisión guarda con qué versión se hizo; editarla en pantalla queda para la 5.8.
- **El consentimiento no exige la valoración**, pero la sesión exige las dos. La ficha los muestra en ese orden.
- **El intervalo entre sesiones y un protocolo de otra versión que el consentimiento avisan, no bloquean.** Si cambió la técnica o el producto, firma un consentimiento nuevo.
- **La sesión se guarda solo al sellarla** (no hay borradores de sesión).
- **Para sellar una valoración o una sesión,** la historia de ese paciente no puede tener cambios sin descargar en el editor (por ejemplo, una evolución en curso con el GLP-1); si los tiene, la app pide descargarla primero. Así la historia no se bifurca.
- **Lotes escritos a mano:** un lote vencido ya bloquea, pero descontar del inventario llega en la 5.7, como estaba previsto. Las citas de procedimiento (y su regla de mayoría de edad) llegan con la agenda (5.5).
- **El paquete del equipo secundario** sigue llevando fichas, mediciones, fotos y documentos (también un consentimiento informado firmado allí), pero no programas, valoraciones ni sesiones: esas se hacen en el principal.

**Evidencias (`docs/fase5/`)**
- **Escritorio (1440 px):**
  - [programa de peso](fase5/escritorio_programa_peso.png)
  - [protocolo en Ajustes](fase5/escritorio_protocolo.png)
  - [valoración](fase5/escritorio_valoracion.png)
  - [consentimiento informado con firma](fase5/escritorio_consentimiento_informado.png)
  - [sesión sin consentimiento](fase5/escritorio_sesion_sin_consentimiento.png) · [sesión con un lote vencido](fase5/escritorio_sesion_lote_vencido.png) · [sesión lista](fase5/escritorio_sesion.png)
  - [ficha → Estética](fase5/escritorio_estetica_ficha.png)
- **Tableta (820 px):** [sesión](fase5/tableta_sesion.png)
- **320 px:** [sesión plegable](fase5/320_sesion.png)
- **PDF:** [la sesión sellada en la historia](fase5/pdf_historia_sesion.png)

### 5.2 Seguimiento y fotos ✅ (aprobada el 22/11/2026)

**Qué incluye**
- **Mediciones** (pestaña «Seguimiento» de la ficha):
  - peso, talla, cintura, cadera, abdomen, flancos, muslos y brazos (derecho e izquierdo), presión arterial y % de grasa con su método (pregunta 18). La talla se arrastra de la última medición;
  - **IMC e índice cintura-cadera** calculados; rangos de cada campo validados;
  - también aparecen, de solo lectura, el peso, la talla y la presión **sellados en las historias** del paciente (origen «historia»);
  - **cambios** desde la primera medición (peso, IMC, cintura, ICC, con su %), **gráfica** con `CustomPainter` (eje de tiempo proporcional y marcas redondas) y tabla;
  - al guardar una medición, «Mediciones del día: …» se **agrega a la evolución en curso** (pregunta 17; casilla marcada por defecto si el paciente tiene historias). Se sella al descargar la historia.
- **Consentimiento de uso de imagen** (consecutivo CIM-): plantilla versionada (**VERIFICAR con tu abogado**), firmada en pantalla, con **tres permisos separados** (pregunta 22): registro clínico (obligatorio), docencia y publicidad. La ficha muestra cuáles autorizó. Sin consentimiento vigente **no aparece «Tomar fotos»**, y la capa de datos tampoco guarda la foto.
- **Fotos cifradas** (pestaña «Fotos»):
  - secuencia de cinco vistas (frontal, laterales, posterior y detalle, pregunta 19), cada una con **guía de encuadre** (hombros, ombligo, caderas) y la **foto anterior en transparencia** para alinear; repetir, saltar o terminar;
  - **cámara del sistema** con `capture` (pregunta 21a); en el computador, el selector de archivos;
  - en el navegador, la foto se endereza según su orientación, se reduce a **1600 px de lado mayor, JPEG al 80 %**, y se le **quitan los metadatos** (EXIF con GPS, XMP, IPTC, comentarios; pregunta 20). Se guarda cifrada, con una miniatura de 320 px, ligada al consentimiento con el que se tomó;
  - **comparación lado a lado** por vista y fecha, con los días de diferencia, y **cortina** (una sobre otra, con una línea que se desliza); galería por fecha; borrar una foto queda en la bitácora.
- **Informe de seguimiento en PDF**: cambios, gráficas de peso, IMC y cintura (`pw.Chart`), tabla de mediciones, firma y sello. Las fotos van **solo si marcas «Incluir fotos»**, que viene apagado (pregunta 23): la primera y la última de cada vista. **«Exportar fotos en PDF»** saca todas las fotos de la ficha, con confirmación. Toda salida de fotos queda en la bitácora.
- **Equipo secundario** (pregunta 3; Ajustes → «Equipo secundario»):
  - el celular se configura **restaurando un respaldo** del portátil (comparten la llave) y marcándolo como secundario. Sus documentos llevan **serie propia** («CIM-S000001»), para que los consecutivos no choquen;
  - «Exportar paquete de este equipo» descarga un **`.hcpaquete` cifrado** con lo creado allí desde la restauración: fichas, mediciones, fotos y documentos firmados;
  - en el portátil, «Combinar un paquete» lo verifica (otro consultorio o un byte cambiado se rechazan), muestra qué trae y lo agrega **sin duplicar**. Una ficha nueva del celular cuyo documento ya existe en el portátil se une a la de aquí.

**Verificación**

| Comprobación | Resultado |
|---|---|
| `dart format`, `flutter analyze` | Sin problemas |
| `flutter test` | **469 en verde** (eran 440 en la 5.1). 3 omitidas, las mismas de antes. Cubre lo que pedía el plan: cálculos (IMC, ICC, cambios, validaciones), sin consentimiento no hay fotos, las fotos no entran al PDF de la historia ni al informe sin pedirlo, EXIF y GPS eliminados, foto cifrada en reposo (ni «JFIF» en claro), paquete combinado sin duplicados (y otra vez el mismo: nada nuevo), paquete ajeno o alterado rechazado, e informe en PDF leído con `pdftotext` |
| Bandera apagada | `main.dart.js` público **del mismo tamaño que en la 5.1** (5.333.404 bytes) y sin el módulo (`verificar_compilacion.dart`). En los archivos compartidos, la 5.2 solo agregó `elegirFoto` y `elegirPaquete` a `archivos_web.dart`, que el sitio público no usa y el compilador descarta |
| Bandera encendida | El `main.dart.js` del consultorio pesa **5.752 KB** (5.709 KB en la 5.1) |
| Contraste | La gráfica, las píldoras de cambios y los diálogos usan los colores del tema, ya probados (≥ 4,5:1). Los rótulos de la guía de encuadre (blanco sobre negro al 55 %) dan unos 4,7:1 aun sobre una foto blanca, con prueba. «Registro clínico», marcado y fijo, ya no sale en el gris de lo deshabilitado |
| 320 px | Seguimiento, diálogo de medición, fotos, secuencia y firma del consentimiento sin desbordes, con prueba |
| e2e de siempre | `historia_offline.mjs` y `pwa_offline.mjs` en verde con el sitio público |
| e2e del consultorio en Chromium, **sin conexión y con la CSP** | **30 de 30 pasos** (23 de antes y 7 nuevos). Aprobar la plantilla y **firmar el consentimiento de imagen** (clínico y docencia; antes, sin él, no hay «Tomar fotos»). El **01/09/2026**: medición y **foto de «antes»** con el selector que pide la cámara (`capture`). **Hoy**: segunda medición, **copiada a la evolución**, y **foto de «después» con la anterior en transparencia**. Luego la **comparación** con los días de diferencia, la **cortina** y el **informe** (sin fotos por defecto; su texto, con `pdftotext`). Las **fotos exportadas en PDF** salen como dos JPEG de **1200 × 1600**, así que la de orientación EXIF 6 quedó derecha y redimensionada; tampoco conservan EXIF. Al final, la tarjeta del equipo secundario y nada de los pacientes en claro (tampoco «JFIF» ni «Exif»). 0 peticiones externas, 0 fallidas, 0 errores de consola, 0 excepciones de Flutter |

**Problemas encontrados y corregidos en la 5.2**
1. **Subí un commit con una prueba rota** (59ae629): la orden que encadenaba la suite y el commit no se detenía si fallaba. Lo corregí en el commit siguiente (5f5d2b6), y desde entonces cada commit solo se hace si la suite termina en verde.
2. La gráfica de la ficha rotulaba el eje con valores como «67,504». Ahora usa marcas redondas, las mismas del PDF.
3. En el informe, la gráfica repartía las mediciones a distancias iguales aunque estuvieran separadas por días o meses. Ahora el eje es de tiempo. Además, el rótulo «Fotos» podía quedar solo al pie de una página y la firma podía partirse entre dos.
4. En escritorio, las dos fotos de la comparación medían unos 700 px de alto. Ahora el bloque mide a lo sumo 760 px de ancho y se ven enteras.
5. Con un solo día de fotos, la comparación mostraba la misma foto dos veces y «Diferencia: 0 días». Ahora dice que hace falta otra sesión.
6. El aviso de documento firmado decía «Autorización … firmado» también para el consentimiento de imagen. Ahora dice «Documento firmado: …».

**Desviaciones del plan**
- **Fotos adjuntas a una evolución** (pregunta 23, «solo si eliges fotos concretas»): no está. Por ahora las fotos **nunca** entran a la historia, solo al informe (si lo pides) y a «Exportar fotos en PDF». Propongo hacerlo en la 5.4, con los documentos.
- **El paquete del secundario lleva lo creado desde la restauración**, no los cambios a lo que ya existía. Si en el celular editas una ficha que vino del portátil, ese cambio no viaja; las fichas, mediciones, fotos y documentos nuevos sí. El equipo secundario es para tomar fotos y firmar.
- **Las mediciones de las historias** salen de los signos sellados (peso, talla y presión). Son de solo lectura: se corrigen en la historia, no en el seguimiento.
- **Exportar fotos (y el informe con fotos) queda en la bitácora.** No estaba en el plan, pero es una salida de datos sensibles.
- **Revocar el consentimiento de imagen** oculta «Tomar fotos». Las fotos ya tomadas siguen en la ficha como parte de la historia (**VERIFICAR con tu abogado** si deben ocultarse o conservarse con otra marca).
- **Que las fotos tomadas con `capture` no queden en el carrete del celular** depende del navegador y del modelo (**VERIFICAR en tu celular**).
- En las pruebas de Dart (sin navegador), la foto solo pierde los metadatos, sin redimensionarla. El redimensionado y la orientación se comprueban en la e2e de Chromium.
- La e2e fija el reloj del navegador al 01/09/2026 para la foto de «antes». Playwright cambia solo la fecha; los temporizadores siguen.

**Evidencias (`docs/fase5/`)**
- **Escritorio (1440 px):**
  - [seguimiento](fase5/escritorio_seguimiento.png)
  - [firma del consentimiento de imagen](fase5/escritorio_consentimiento_imagen.png)
  - [guía de encuadre con la foto anterior](fase5/escritorio_fotos_guia.png)
  - [comparación de fotos](fase5/escritorio_fotos_comparacion.png) · [cortina](fase5/escritorio_fotos_cortina.png)
  - [informe: «Incluir fotos» apagado](fase5/escritorio_informe_dialogo.png)
  - [Ajustes → Equipo secundario](fase5/escritorio_equipo_secundario.png)
- **Móvil (390 px):** [seguimiento](fase5/movil_seguimiento.png) · [fotos](fase5/movil_fotos.png)
- **PDF:** [primera página del informe de seguimiento](fase5/pdf_informe_seguimiento.png)

### 5.1 Pacientes ✅ (aprobada el 22/11/2026)

**Qué incluye**
- **Índice de pacientes** cifrado (`lib/core/consultorio/indice/`):
  - una **ficha** por documento (tipo y número sin puntos ni espacios). Un paciente sin identificar (AS/MS) tiene una ficha por historia hasta que las unas;
  - cada historia se registra al **guardarla** o al **abrirla**, con sus datos sellados y su **PDF exacto**. Resultado: nueva, versión más nueva (la reemplaza), ya estaba, versión más vieja (no la reemplaza) o **versiones divergentes** (misma revisión, otro contenido; se marca en la ficha);
  - con el consultorio **bloqueado**, lo que se guarda queda pendiente en memoria y se registra al desbloquear (la pantalla de desbloqueo lo avisa);
  - si abres un PDF **más viejo** que el del índice, la historia ofrece abrir la versión más nueva;
  - un registro dañado o alterado **no impide abrir** el consultorio: se cuenta y la lista lo avisa.
- **Lista de pacientes** (`/pacientes`):
  - búsqueda sin tildes ni mayúsculas, por nombre o documento (con o sin puntos); Enter abre la primera ficha;
  - filtros por línea, última atención, etiquetas y **controles vencidos** (la fecha pasó y no volvió);
  - **importación en lote** de PDF (elegidos o soltados) con informe por archivo: importada, ya estaba, más nueva, más vieja, divergente, **con alteraciones (se indexa marcada)**, dañada, ajena;
  - paciente nuevo a mano; en móvil, botón flotante.
- **Ficha** (`/pacientes/:id`):
  - datos, líneas, etiquetas, notas internas, alergias vigentes y antecedentes **con su fuente** («de la historia del 02/10/2026»; «actualizadas el …» solo si una evolución las actualizó);
  - **línea de tiempo** con historias (integridad, revisión, evoluciones con su huella y próximo control), documentos y recetas, con «Abrir en la historia», «Ver PDF» y «Descargar PDF»;
  - acciones: historia nueva y evolución **prellenadas**, receta, **actualizar alergias** (agrega «Alergias actualizadas: …» a la evolución en curso, que se sella al descargarla), autorización de datos, editar datos y **unir fichas** (la otra queda marcada, no se borra; queda en la bitácora). En móvil, un menú «Acciones».
- **Historia con la bandera:** franja «← Ficha» sobre la historia que vino de una ficha, y campo **«Próximo control» en la evolución** (pregunta 15a).
- **Documentos** (`lib/core/consultorio/documentos/`):
  - **plantillas versionadas** de autorización de tratamiento de datos y de política de privacidad, con textos base según la Ley 1581 de 2012 y el Decreto 1377 de 2013 (**VERIFICAR con tu abogado**). No se usan hasta aprobarlas; editar una aprobada crea la versión siguiente en borrador;
  - **autorización firmada en pantalla** por el paciente: consecutivo AD-, `documento.json` sellado dentro del PDF (con la versión de la plantilla y la huella de la firma), firma y PDF cifrados, ligada a la ficha. Se puede registrar su **revocación** o **anularla**, con motivo; el número no se reutiliza. Sin autorización, la ficha avisa pero **no bloquea la atención** (pregunta 12);
  - **política de privacidad en PDF** para imprimir y exhibir (Ajustes → Plantillas).
- **Recetas con `receta.json`** (solo con la bandera) registradas en la ficha con su PDF exacto. Sin la bandera, la receta es el PDF de siempre.
- **Borrador de la historia y receta en curso cifrados** (pregunta 6): con el consultorio abierto van al almacén; bloqueado, solo en memoria y se cifran al desbloquear; lo que había en claro se migra. Tras recargar, el borrador vuelve al desbloquear.

**Verificación**

| Comprobación | Resultado |
|---|---|
| `dart format`, `flutter analyze` | Sin problemas |
| `flutter test` | **440 en verde** (eran 383: **+57**). 3 omitidas, las mismas de la 5.0 |
| Bandera apagada | La prueba ahora admite una **lista cerrada** de archivos compartidos (historia, evoluciones, receta, borrador) y exige que cada enganche esté dentro de `if (consultorioHabilitado …)`. `main.dart.js` público sin el módulo. Comparado con `main`: **+0,7 KB** (5.333.404 bytes frente a 5.332.699), por el «próximo control» de la evolución (pregunta 15a, aceptada) y el parámetro de adjuntos de la receta; la fuente de íconos pasa de 18 a 22 KB (mismo motivo que en la 5.0) |
| Bandera encendida | Rutas `/pacientes` y `/pacientes/:id`. El módulo pesa **+375 KB** en `main.dart.js` (5.709 KB) |
| Rendimiento con **5.000 pacientes sintéticos** | Descifrar y cargar el índice (10.000 registros): **0,8 a 0,95 s**; búsqueda: **15 a 17 ms por consulta** (máquina virtual de Dart con AES en Dart; en el navegador el cifrado lo hace WebCrypto). Antes de indexar las historias por paciente, la búsqueda tardaba 67 ms |
| Contraste | Píldoras de estado (fondo al 6 %), franja y avisos ≥ 4,5:1, con prueba |
| 320 px | Lista, ficha, menú «Acciones» y diálogo de firma sin desbordes, con prueba |
| e2e en Chromium, **sin conexión y con la CSP** | **23 de 23 pasos** (16 de la 5.0 y 7 nuevos): importar 4 PDF sintéticos (1 alterado, 1 ajeno) con su informe, buscar «pena jose» y abrir la ficha con Enter, aprobar la plantilla y **firmar la autorización** (PDF con `documento.json`), **evolución desde la ficha** con la franja y el próximo control (v3 descargada), receta con `receta.json`, **nada de los pacientes en claro en IndexedDB ni en `localStorage`**, ficha en móvil. 0 peticiones externas, 0 fallidas, 0 errores de consola y, desde ahora, **0 excepciones de Flutter** (antes no se vigilaban) |

**Problemas encontrados y corregidos en la 5.1**
1. **Accesibilidad rota al cruzar los 1100 px** (de escritorio a móvil o al girar la tableta) con un lector de pantalla: el motor web lanzaba «Null check operator…» y el árbol de accesibilidad dejaba de actualizarse. El contenedor construía dos árboles distintos a cada lado del corte; ahora conserva el cuerpo con una llave global. La e2e lo encontró y ahora falla si Flutter registra una excepción.
2. **Chromium descarta el nombre de una descarga con tildes o «ñ»** (quedaba «download»). Los PDF de documentos usan nombres solo ASCII, como la historia y la receta.
3. **Un registro ilegible impedía desbloquear** el consultorio. Ahora se cuenta como ilegible y la lista lo avisa.
4. La ficha decía «actualizadas el …» también cuando las alergias venían de la historia inicial.
5. El verde de «Íntegra» quedaba en 4,39:1 sobre su píldora; con el fondo al 6 % pasa a 4,62:1.

**Desviaciones del plan**
- **Receta prellenada:** la receta toma el paciente y las alergias de la historia en curso, así que «Receta» en la ficha continúa la historia más reciente del paciente (o empieza una prellenada) y abre la receta. No hizo falta otro mecanismo.
- **Pregunta 15a:** el campo se escribe solo con la bandera, pero el modelo, la vista sellada y el PDF de la evolución son compartidos; por eso el sitio público cambia en 0,7 KB (lo esperado al aprobar la opción a). Una evolución sin próximo control sella exactamente el mismo mapa que hoy, con prueba.
- **`documento.json` y `receta.json` llevan otra marca** (`aplicacion` en lugar de `app`): la historia de siempre no los confunde con una historia, y abrir esos PDF en ella se comporta como con cualquier PDF ajeno. Importarlos en el índice llega en la 5.4, como estaba previsto.
- **Lo pendiente con el consultorio bloqueado vive solo en memoria:** si se cierra la pestaña antes de desbloquear, la historia sigue en su PDF y se puede importar.
- **Firma en papel** (fotografía o escaneo del documento firmado, pregunta 38) y **consentimiento de uso de imagen**: llegan con los documentos (5.4) y las fotos (5.2).
- **Rendimiento medido en la máquina virtual de Dart**, no en tus equipos. Conviene repetirlo en tu portátil y en tu celular cuando tengas datos.

**Evidencias (`docs/fase5/`)**
- **Escritorio (1440 px):**
  - [informe de importación](fase5/escritorio_importacion_informe.png)
  - [lista de pacientes](fase5/escritorio_pacientes_lista.png) · [búsqueda sin tildes](fase5/escritorio_pacientes_busqueda.png)
  - [ficha](fase5/escritorio_ficha.png) · [ficha con la línea de tiempo](fase5/escritorio_ficha_linea_de_tiempo.png)
  - [plantillas en Ajustes](fase5/escritorio_ajustes_plantillas.png) · [firma de la autorización](fase5/escritorio_autorizacion_firma.png)
  - [evolución desde la ficha, con la franja](fase5/escritorio_evolucion_desde_ficha.png)
- **Móvil (390 px):** [ficha](fase5/movil_ficha.png) · [menú «Acciones»](fase5/movil_ficha_acciones.png)
- **PDF:** [autorización de tratamiento de datos](fase5/pdf_autorizacion_datos.png)

### 5.0 Cimientos ✅ (aprobada el 21/11/2026)

**Qué incluye**
- **Bandera `CONSULTORIO_ENABLED`** como constante (`lib/core/consultorio/config.dart`). Su único punto de entrada es `crearRouter()`, bajo `if (consultorioHabilitado)`.
- **Almacén cifrado propio** en IndexedDB (`historiasclinicas_consultorio`), con tres depósitos (`meta` en claro; `registros` y `binarios` cifrados) y escrituras atómicas en una transacción.
  - AES-256-GCM con AAD (colección e id). En el navegador, la llave se importa en WebCrypto como **no extraíble**.
  - Llave en sobre: la llave de datos se guarda envuelta con la frase (PBKDF2, 600.000 iteraciones) y con el código de recuperación.
  - Migraciones, candado entre pestañas (Web Locks), pedido de almacenamiento persistente y bitácora sin datos de pacientes.
  - **El código de IHCE no se tocó.**
- **Respaldo `.hcrespaldo`:** ZIP con manifiesto sellado.
  - Al importar se verifica la frase o el código, el sello del manifiesto, el SHA-256 de cada archivo, que cada registro se descifre con su AAD y los conteos.
  - Restaurar reemplaza todo, y si hay problemas solo restaura lo íntegro tras confirmar.
- **Interfaz:**
  - Riel lateral desde 1100 px (Historia y Ajustes por ahora) y menú lateral en pantallas angostas.
  - Crear la frase con medidor de fortaleza.
  - Código de recuperación mostrado una sola vez, con **hoja PDF para imprimir** y confirmación de los últimos 4 caracteres.
  - Desbloquear, recuperar con el código y bloqueo por inactividad.
  - Aviso de respaldo vencido con el texto de custodia.
  - **La historia, la receta y los datos del médico funcionan con el consultorio bloqueado.**
- **Ajustes:**
  - Seguridad: minutos de bloqueo, «Bloquear ahora», cambiar la frase, nuevo código de recuperación y «Medir la derivación».
  - Respaldo: respaldar, restaurar, días de aviso, espacio usado y almacenamiento persistente.
  - Bitácora.
- **Compilación:**
  - `./tool/construir_web.sh --salida DIR` permite compilar la versión del consultorio aparte.
  - `tool/consultorio/verificar_compilacion.dart` comprueba si el módulo quedó en `main.dart.js`.
  - Guía de publicación: [fase5/PUBLICAR_CONSULTORIO.md](fase5/PUBLICAR_CONSULTORIO.md).

**Verificación**

| Comprobación | Resultado |
|---|---|
| `dart format`, `flutter analyze` | Sin problemas |
| `flutter test` | **383 en verde** (eran 323: **+60**). 3 omitidas: las 2 que solo corren con la bandera encendida (la CI las corre en el job «consultorio») y 1 que ya existía |
| **Bandera apagada = sitio de hoy** | `main.dart.js` compilado **idéntico byte a byte** al de `main` (5.208 KB). Router con exactamente `/`, `/receta` y `/medico`. Menú «Más opciones» idéntico a 1920 y a 390 px. Nadie crea el servicio del consultorio. `pages.yml` sin la bandera. En la e2e de siempre no se crea la base del consultorio |
| Bandera encendida | `crearRouter()` usa el contenedor y las rutas del consultorio. El módulo pesa **+187 KB** en `main.dart.js` (5.395 KB) |
| Cifrado y respaldo | Vector conocido de PBKDF2; tildes compuestas o separadas dan la misma llave; un byte cambiado, otra AAD o un registro copiado sobre otra clave no se descifran; nada en claro en el almacén ni en el respaldo. Respaldo de ida y vuelta; se detectan el manifiesto modificado, archivos modificados, faltantes, sobrantes o intercambiados, el archivo ajeno o truncado y la versión nueva |
| e2e del consultorio en Chromium, **sin conexión y con la CSP** (`tool/e2e/consultorio_offline.mjs`) | **16 de 16 pasos.** Crear la frase, código y hoja PDF, base sin la frase ni el código en claro, medir la derivación, respaldar, bloquear, frase incorrecta, desbloquear, **otra pestaña no abre**, respaldo dañado y frase equivocada rechazados, restaurar, aviso de respaldo vencido tras recargar sin conexión, recuperar con el código, móvil y 320 px. 0 peticiones externas, 0 fallidas, 0 errores de consola |
| e2e de siempre (`historia_offline.mjs`, `pwa_offline.mjs`) | En verde, más el paso nuevo: sin la bandera no existe la base del consultorio |
| `tool/ihce/verificar.sh` | **En rojo por una causa externa a la Fase 5:** MinSalud recompiló la guía RDA (compilación `20261109215545`, del 09/11/2026), y el gate se detiene en el aprovisionamiento porque la huella ya no coincide con `vendor/fhir/VERSIONS.lock`. Lo mismo pasaría hoy en `main`. Las pruebas de IHCE (T01–T24 y capa 1) corren dentro de `flutter test` y pasan, y la regla 10 está en verde con el inventario de la Fase 5. Actualizar la guía (`--actualizar`, regenerar `PERFILES_RDA.md` y la línea base) es una tarea de IHCE aparte, que dejo propuesta |

**Derivación de la llave** (Chromium de este contenedor, 4 núcleos): PBKDF2-HMAC-SHA256 con 600.000 iteraciones, **unos 100 a 120 ms**; Argon2id con 19 MiB y 2 pasadas, **unos 1,1 a 1,2 s**. Argon2id es razonable en un escritorio, pero falta medirlo en tu Mac y en tu celular. Por ahora sigue PBKDF2. Los parámetros van guardados con la llave, así que cambiarlos después no rompe nada.

**Problemas encontrados y corregidos en la 5.0**
1. **La hoja de recuperación cortaba el último carácter del código** («TQP» en vez de «TQPV»): no cabía en una línea. Ahora va en dos líneas y se achica si hace falta. Una prueba lee el PDF con `pdftotext` y exige los 6 grupos; con la versión anterior falla.
2. **El riel y el aviso de respaldo no existían para los lectores de pantalla** sobre las pantallas con barra propia (historia, receta, médico). Cada pantalla vive en un `Navigator` anidado cuya barrera usa `BlockSemantics`, que oculta todo lo pintado antes. La pantalla va ahora en su propio contenedor semántico. Una prueba de accesibilidad lo vigila; sin el arreglo, falla.
3. **El aviso de respaldo salía sin el estilo del tema** (texto rojo con subrayado amarillo) y el motor intentaba descargar una fuente de respaldo, lo que **sin conexión fallaba**. Faltaba un `Material` alrededor del riel. Hay prueba.
4. El rótulo «CONSULTORIO» no cabía en el riel de 80 px y se quitó. El campo de la frase ya no toma el foco solo.

**Desviaciones del plan**
- **El borrador y la receta en curso cifrados (pregunta 6)** pasan a la 5.1. Allí se engancha la historia al índice, y es más seguro cambiar el borrador en el mismo paso. Hasta entonces quedan como hoy.
- **La historia no se tocó.** En vez de cambiar sus cortes a `LayoutBuilder`, el contenedor le pasa el ancho que queda a la derecha del riel (`MediaQuery`). El resultado es el mismo y no cambia ningún archivo de la historia.
- **El respaldo guarda un archivo por registro** en vez de «en lotes». Es más simple y permite informar cada problema por nombre.
- **La app abre en la historia** (`/`) y no en la agenda, porque la agenda llega en la 5.5.
- **Fuente de íconos del sitio público: +2 KB.** El recorte de íconos de Flutter ocurre antes de descartar el código, así que la fuente pública incluye unos pocos íconos del consultorio que nunca se muestran (18 → 20 KB). Es lo único del sitio público que cambia, junto con las huellas de `sw.js`. Al publicar, los navegadores descargan esa fuente y el `sw.js` nuevos.
- **Prueba local con Playwright 1.65:** en este contenedor, el Chromium instalado es de otra versión y lo enlacé fuera del repositorio. En la CI, Playwright instala el suyo.

**Evidencias (`docs/fase5/`)**
- **Escritorio (1440 px):**
  - [historia con el riel](fase5/escritorio_historia_con_riel.png)
  - [crear la frase](fase5/escritorio_crear_frase.png)
  - [código de recuperación](fase5/escritorio_codigo_recuperacion.png)
  - [Ajustes sin respaldo](fase5/escritorio_ajustes_sin_respaldo.png)
  - [bloqueado](fase5/escritorio_bloqueado.png)
  - [restaurar](fase5/escritorio_restaurar.png)
  - [aviso de respaldo vencido](fase5/escritorio_aviso_respaldo_vencido.png)
  - [recuperar con el código](fase5/escritorio_recuperar_con_codigo.png)
- **Móvil (390 px):** [Ajustes](fase5/movil_ajustes.png) · [menú](fase5/movil_menu.png) · [bloqueado](fase5/movil_bloqueado.png)
- **320 px:** [bloqueado](fase5/320_bloqueado.png) · [Ajustes](fase5/320_ajustes.png)
- **PDF:** [hoja de recuperación](fase5/pdf_hoja_recuperacion.png)

---

## 0. Lo que encontré antes de planificar

### Código

| Tema | Hallazgo | Consecuencia |
|---|---|---|
| Almacén de IHCE (`lib/core/ihce/almacen/`) | `AlmacenKv` guarda solo texto (`String → String`). La implementación web tiene fijos el nombre de la base (`historiasclinicas_ihce`) y del almacén (`kv`). No tiene transacciones de varias claves ni datos binarios. `claves()` lee todas las claves y filtra en Dart. Nada pide `navigator.storage.persist()` | El consultorio tiene **su propio almacén** en `lib/core/consultorio/almacen/`, con el mismo estilo de contrato (`leer`, `escribir`, `borrar`, `claves`) más lo que falta: bytes (las fotos se guardan como `Uint8Array`, sin base64), tres almacenes (`meta`, `registros`, `binarios`) y escritura atómica de varias claves en una transacción. Reutilizo el respaldo en memoria para las pruebas y el patrón de migraciones. **El código de IHCE no se toca** |
| `RepositorioIhce` | Es específico de IHCE (tipos del RDA). Los índices y los únicos viven en memoria y se reconstruyen al abrir. El único se comprueba antes de escribir, con un `await` en medio, así que dos escrituras simultáneas pueden saltárselo. Los metadatos del documento se guardan en claro | Para el consultorio hago una **colección genérica** (`Coleccion<T>`): registro completo cifrado, índices en memoria declarados, escrituras en serie (una cola) y un candado entre pestañas (`navigator.locks`) |
| Cifrado (`cifrador.dart`) | AES-256-GCM con WebCrypto, sobre JSON `{"v":1,"n","c","m"}`, sin datos asociados (AAD). La llave es aleatoria y se guarda en `flutter_secure_storage`. En la web, ese almacén guarda la llave que envuelve **junto a los datos**, en `localStorage` (oculta, no protege). Además, si la lectura falla devuelve `null`, y el cifrador genera una llave nueva que **sobrescribe la anterior en silencio** | El consultorio **no** usa `flutter_secure_storage`. La llave sale de tu frase de acceso y solo vive en memoria mientras está desbloqueado (ver «Decisión de arquitectura»). Reutilizo AES-256-GCM de `cryptography`, con AAD. El defecto de IHCE lo dejo anotado como tarea aparte |
| Derivar la llave de la frase | `cryptography` 2.9.0 trae **PBKDF2-HMAC-SHA256**, que en la web usa WebCrypto nativo (unos 0,2 a 1 s con 600.000 iteraciones). **Argon2id** está escrito en Dart puro: en el navegador corre en el hilo principal y podría tardar de 2 a 6 s en escritorio y más de 10 s en un celular modesto (estimado, sin medir) | Por defecto, PBKDF2 con 600.000 iteraciones (cifra recomendada por OWASP en 2023, **VERIFICAR** la vigente). En la 5.0 mido Argon2id en tu Mac y en tu celular. Si tarda menos de 2 s, lo propongo. Los parámetros quedan guardados junto a la llave envuelta, así que cambiarlos después no rompe nada (pregunta 5) |
| `historia.json` | No hay identificador del paciente: la clave natural es tipo + número de documento. La historia tiene `id` (UUID) y `revision`. **`proximoControl` existe solo en el plan de la historia inicial; las evoluciones no lo tienen.** El editor de evoluciones no pide talla ni perímetro abdominal | El índice identifica al paciente por documento normalizado (con unión manual de fichas duplicadas). El indicador de controles vencidos usa `plan.proximoControl` más las citas de la agenda (pregunta 15) |
| Momento de sellar | `HistoriaController.guardado()` corre al finalizar la historia (revisión 1) y al descargarla con evoluciones nuevas (revisión > 1). IHCE ya se engancha ahí sin esperar el resultado y sin lanzar errores | El índice se actualiza en ese mismo punto, con el mismo patrón y detrás de la bandera. Hace falta pasarle también los bytes del PDF, para guardar su huella |
| Leer un PDF de la app | `leerHistoriaDePdf` es Dart puro y síncrono, sin interfaz. Verifica el sobre, y `verificarIntegridad` verifica la cadena (alterada desde la evolución *n*) y las imágenes. Los selectores de archivo abren uno solo | La importación en lote es viable: un archivo a la vez, cediendo el hilo entre archivos. Hace falta un selector de varios archivos y soltar varios a la vez |
| Recetas | **El PDF de la receta no lleva datos incrustados.** La app guarda solo la receta en curso, y el contador es de cada navegador. La única huella de una receta vieja es el texto «Se formuló (R-…)» sellado en la historia | Las recetas viejas no se pueden importar como documentos; se listan desde ese texto. Con la bandera encendida, las recetas nuevas llevan `receta.json` incrustado y se registran en el índice. Con la bandera apagada, la receta no cambia (pregunta 14) |
| Piezas de PDF | `datosMedicoPdf`, `bloqueFirmaPdf` e `ImagenesPdf` son reutilizables. La ficha del paciente, la cabecera de sección y el encabezado de página son funciones internas de cada generador. `pdf` 3.12 trae gráficas (`pw.Chart`) | Se extraen a `piezas_pdf.dart` sin cambiar el resultado. Las pruebas de PDF de hoy solo comprueban la estructura (adjunto, revisión, imágenes, A4), así que **antes** de extraer agrego una prueba de regresión que compara el texto y su posición en cada página. Las gráficas del informe se hacen sin dependencias nuevas |
| Antecedentes y alergias en el tiempo | Las evoluciones solo tienen texto, signos vitales y autor. Una alergia descubierta después de la historia inicial no queda en ningún campo | La ficha muestra los antecedentes y las alergias de la historia inicial. Para actualizarlos, propongo «Actualizar alergias» en la ficha, que deja la línea sellada en la evolución en curso (pregunta 13) |
| Firma en pantalla | `LienzoFirma` exporta un PNG transparente y recortado. `DialogoFirma` está dentro de `medico_page.dart`, con los textos del médico fijos | Se generaliza (título y textos) y pasa a `lib/core/widgets/`, para la firma del paciente |
| Prellenar la historia | No hay forma hoy: `HistoriaPage` no recibe datos, y la receta toma el paciente de la historia en curso | Nuevo `HistoriaController.nuevaDesdePaciente(...)`, que debe subir `versionFormulario` (si no, los campos no se refrescan). La receta se prellena cargando antes al paciente en la historia |
| Navegación | `go_router` plano con 3 rutas (`/`, `/receta`, `/medico`), sin contenedor común. Las páginas tienen su propia barra. Cortes de ancho: 700 (móvil), 1100 y 1180 | Con la bandera encendida, un contenedor (`ShellRoute`) agrega la navegación del consultorio. Con la bandera apagada, el router es idéntico al de hoy. La historia calcula sus cortes con el ancho de la **ventana** (`MediaQuery`), así que con un riel de 80 px al lado se equivocaría entre unos 1180 y 1260 px. Pasa a usar el ancho disponible (`LayoutBuilder`), que sin riel es el mismo de hoy |
| Componentes | `CampoEntero` admite 3 cifras como máximo y `CampoEtiquetas` tiene el estilo de las alergias (ícono de aviso ámbar) | Hacen falta `CampoMoneda` (COP con separador de miles) y `CampoCantidad`, y una variante neutra de etiquetas |
| Cámara | `Permissions-Policy: camera=()` está en las 5 configuraciones de hosting, y una prueba exige que coincidan. Bloquea `getUserMedia` en todo el sitio. Elegir un archivo sí funciona | Las fotos se toman con `<input type=file accept=image/* capture>`, que en celulares y tabletas abre la cámara del sistema, sin tocar las cabeceras del sitio público (pregunta 21) |
| WhatsApp, `.ics` y `.csv` | La CSP no restringe la navegación: abrir `https://wa.me/…` funciona. Las descargas ya se hacen con `blob:` (`archivos.descargar`) | Sin cambios de cabeceras. La prueba e2e falla ante cualquier petición externa, así que intercepta el enlace de WhatsApp sin abrirlo |
| Pruebas e2e | Scripts de Playwright que manejan la app por el árbol de semántica, sin conexión y con la CSP de producción. Las capturas salen de esas corridas (1440 × 1000 y 390 × 844). Los 320 px solo se prueban con pruebas de widgets | Nuevo `tool/e2e/consultorio_offline.mjs`, que crece en cada subfase, con capturas de escritorio, móvil y 320 px en `docs/fase5/` |
| Regla 10 de IHCE | `tool/ihce/regla10.dart` (parte de `tool/ihce/verificar.sh`, no de CI) falla si cambia `lib/app/tema.dart` o `web/`, o si un archivo de `lib/features/`, `lib/core/widgets/` o `lib/app/` cambia sin figurar en `docs/ihce/CAMBIOS_UI.md` | La Fase 5 cambia interfaz a propósito, así que ese control se pondría en rojo. Hay que decidir su alcance (pregunta 8). Evito tocar `tema.dart` y `web/`: los colores de las gráficas y de la agenda se derivan de los tokens existentes |
| Lo guardado en el navegador | Está atado a la dirección del sitio. Safari puede borrarlo si no se usa en semanas (FASE4.md). Nadie pide almacenamiento persistente | Se pide `navigator.storage.persist()`, se muestra el espacio usado y el respaldo es obligatorio (pregunta 7). **Dónde se publica la versión con la bandera encendida decide qué comparte con el sitio público** (pregunta 2) |

### Normativa (todo VERIFICAR)

| Norma | Qué encontré | Qué hace la app |
|---|---|---|
| **Ley 1581 de 2012** y Decreto 1377 de 2013 (compilado en el Decreto 1074 de 2015) | Los datos de salud son sensibles: piden autorización explícita del titular, con finalidades claras, salvo las excepciones del art. 6. Hace falta una política de tratamiento y un aviso de privacidad. El Registro Nacional de Bases de Datos (SIC) obliga a sociedades con activos de más de 100.000 UVT (Decreto 090 de 2018), no a personas naturales | La ficha registra la **autorización de tratamiento de datos** firmada en pantalla, con la versión exacta del texto. Incluyo plantillas de autorización y de política de privacidad, marcadas BORRADOR, para que las revises con tu abogado |
| **Resolución 1995 de 1999** y Resolución 839 de 2017 | Custodiar la historia clínica es responsabilidad del prestador. Hay que conservarla al menos 15 años desde la última atención. Los consentimientos y las imágenes son anexos de la historia | El aviso de respaldo explica que **la custodia es tuya**. Los consentimientos y las fotos quedan ligados a la ficha y van en el respaldo |
| Ley 23 de 1981 (ética médica) | Consentimiento del paciente antes de exponerlo a riesgos (art. 15). Contenido y veracidad del certificado médico (arts. 50 a 52) | Plantillas de consentimiento y de certificados editables, con tus datos y tu firma |
| Ley 527 de 1999 y Decreto 2364 de 2012 (firma electrónica) | La ley distingue la firma electrónica de la firma digital certificada. Una firma dibujada en pantalla sería firma electrónica, y su validez depende de que se pueda atribuir al firmante y de la integridad del documento (VERIFICAR) | Cada documento firmado guarda la imagen de la firma, su huella SHA-256, la fecha y la hora, y su propio `documento.json` sellado dentro del PDF. Como alternativa, se puede adjuntar el documento firmado en papel |
| **Ley 1799 de 2016** | Prohíbe los procedimientos médicos y quirúrgicos estéticos en menores de 18 años, aun con permiso de los padres (art. 3), con excepciones (art. 4: nariz, orejas, reconstructivas, peelings, patologías acreditadas). La Sentencia C-246 de 2017 condicionó el art. 3 para adolescentes mayores de 14 con capacidad evolutiva (**VERIFICAR** el alcance) | Bloqueo duro: un paciente menor de 18 años no puede tener valoración estética, sesiones ni citas de esos tipos. Si no hay fecha de nacimiento, la valoración la pide |
| **Ley 2316 de 2023** y Decreto 545 de 2024 | Leí el texto: trata de las **sustancias modelantes** (rellenos inyectables), su listado oficial de sustancias permitidas, el consentimiento con los componentes del producto (art. 8) y la trazabilidad de su venta. **No cubre la hidrolipoclasia ni exige por sí misma registro Invima a todo insumo.** Ese requisito general viene del Decreto 677 de 1995 (medicamentos) y del Decreto 4725 de 2005 (dispositivos médicos) | El inventario pide el registro Invima de cada medicamento y dispositivo, y advierte si falta (con más fuerza en los inyectables). La categoría «sustancia modelante» queda prevista para cuando agregues rellenos |
| **Proyecto de Ley 187 de 2026 Senado** | **No es ley.** Ponencia para primer debate en la Comisión Séptima (Gaceta del Congreso 1571, 19/10/2026). Leí el texto propuesto en las páginas de esa Gaceta, en una copia alojada por un tercero (ver «Fuentes»; VERIFICAR contra la Gaceta oficial). El texto puede cambiar en cada debate. Lo pertinente: certificación de competencias por familias de técnicas, con recertificación cada 5 años y caducidad tras 24 meses sin práctica (art. 11). Servicio de Medicina Estética en el REPS (art. 12). Solo anestesia local, con dosis máximas en mg y mg/kg, nunca en volumen; registrar dosis, concentración y volumen; emulsión lipídica al 20 % en el sitio (art. 10). Protocolo escrito por procedimiento y **lista de verificación previa obligatoria** (art. 14). Registro Nacional de Procedimientos, sin datos que identifiquen al paciente (art. 15). Consentimiento escrito y previo, por plan de tratamiento en las series, con contenido mínimo (título y certificación del médico, número de habilitación, producto con registro Invima, alcance realista, obligación de medio, ruta de complicaciones y póliza) (art. 16). Póliza de complicaciones (art. 17). Publicidad sin rifas ni «promociones por tiempo limitado» (art. 18). Transición de 36 meses con volumen documentado (art. 19). El art. 3 f) define como cirugía estética la «extracción, aspiración o transferencia de tejido adiposo»; la hidrolipoclasia, sin aspiración, parece caer en el art. 7 (**VERIFICAR**) | Lo uso como guía de buenas prácticas sin darlo por vigente. **Certificaciones por técnica** con vigencia en la configuración, con aviso si una técnica se usa sin certificación. Lista de verificación previa en cada sesión. Dosis del anestésico en mg y mg/kg. Consentimiento por plan de tratamiento con esos apartados. Campo de póliza. Informe de volumen por técnica. Exportación anónima de procedimientos preparada para un futuro registro (Fase 6) |
| Decreto 1427 de 2022 (incapacidades, en el Decreto 780 de 2016) | Según resúmenes del decreto (no leí su texto completo): contenido mínimo del certificado de incapacidad con datos del prestador (nombre, NIT y código), diagnóstico, días y prórroga, y nombre, documento y firma de quien lo expide; límites de días y de retroactividad; y validación por la EPS cuando el profesional no es de su red. Todo VERIFICAR contra el texto | La plantilla de incapacidad pide esos campos y **avisa** (no bloquea) si faltan tu código de prestador o tu NIT. Los límites de días y de retroactividad entran como avisos solo cuando los verifiques |
| Resolución 3100 de 2019 (habilitación) | El profesional independiente se inscribe en el REPS y habilita cada servicio | Se agregan a la configuración el código de prestador, el NIT y el número de habilitación de cada servicio. Los usan el consentimiento y la incapacidad |
| GLP-1 (fichas técnicas de Invima) | Invima informó un **único** registro de semaglutida, OZEMPIC® (2019M-0019473), autorizado solo para el control glucémico en diabetes tipo 2. El registro de Wegovy en Colombia es contradictorio en las fuentes. Alerta de julio de 2025 por neuropatía óptica isquémica (NAION) con semaglutida, y alerta 090-2024 por semaglutida con B12 fraudulenta | Catálogo editable de medicamentos con registro Invima e indicación aprobada. Un medicamento sin registro confirmado queda marcado así y avisa. Si la indicación no corresponde al paciente, aviso de uso fuera de indicación (no bloquea). La lista de contraindicaciones incluye retinopatía y neuritis óptica. Todo **VERIFICAR** contra la ficha técnica vigente |
| Tamizaje de conducta alimentaria y dismorfia | **SCOFF**: versión española validada (García-Campayo, 2005; corte ≥ 2). **Dismorfia:** el BDDQ-AS (versión para estética, 7 ítems) tiene una **traducción** al español adaptada para Colombia, pero no confirmé que esté **validada**. Validados en español encontré el DCQ (Cuestionario de Preocupación Dismórfica, en universitarios españoles) y el autoinforme del BDDE (Raich). **No encontré la licencia de uso de ninguno** | La estructura del tamizaje va incluida; los textos de los ítems, solo cuando confirmes la licencia (pregunta 30) |
| DIAN | Los servicios médicos están excluidos del IVA (art. 476 num. 1 del Estatuto Tributario). **Las fuentes que encontré se contradicen** sobre si los tratamientos de belleza y las cirugías estéticas no reparadoras quedan exceptuados de esa exclusión, es decir, gravados (Leyes 1943 de 2018 y 2010 de 2019, y oficios de la DIAN). Tampoco confirmé si estás obligado a facturar electrónicamente | El recibo dice claramente «Este documento no es una factura electrónica de venta», con la nota de VERIFICAR tus obligaciones ante la DIAN con tu contador. Cada servicio trae un campo opcional de IVA, apagado por defecto, por si tu contador confirma que un procedimiento estético está gravado. La factura electrónica y los RIPS quedan para la Fase 6 |

---

## Decisión de arquitectura: la confirmo, con ocho ajustes

**Confirmo:** almacén local cifrado en IndexedDB, llave derivada de tu frase de acceso, bloqueo por inactividad, ningún dato sale del navegador, el PDF sigue siendo el registro clínico legal, el índice guarda la huella de cada documento, y el respaldo cifrado es obligatorio, con aviso de vencimiento, verificación al importar y la importación en lote de tus PDF.

**Ajustes que propongo:**

1. **Llave en sobre.** Una llave de datos aleatoria de 256 bits cifra todo. Esa llave se guarda envuelta dos veces:
   - con una llave derivada de tu frase (PBKDF2 o Argon2id);
   - con un **código de recuperación** de 24 caracteres que la app te muestra una sola vez para imprimirlo.

   Cambiar la frase no obliga a recifrar nada. Si olvidas la frase y el código, **los datos del consultorio no se pueden recuperar**; las historias sí, porque están en tus PDF.
2. **Todo cifrado, también los metadatos.** Nada de nombres, documentos ni huellas en las claves de IndexedDB: las claves son identificadores al azar (`pacientes/3f9a…`). Cada registro se cifra con su colección e identificador como datos asociados (AAD), así que no se puede cambiar un registro por otro sin que se note. Lo único en claro:
   - los parámetros de la llave y la versión del esquema;
   - la fecha y la huella del último respaldo;
   - cuántos registros hay de cada colección (también en el manifiesto del respaldo).

   **Lo que hoy guarda la app en claro, en `localStorage`:** el borrador de la historia, la receta en curso y tus datos de médico. Con la bandera encendida propongo mover el borrador y la receta en curso, que tienen datos de pacientes, al almacén cifrado (pregunta 6). Tus datos de médico (nombre, registro, firma y sello) siguen como hoy, porque la historia y la receta los necesitan aunque el consultorio esté bloqueado.
3. **Los índices viven en memoria.** Al desbloquear, se descifran los registros (no las fotos) y se arman los índices de búsqueda. Para unos miles de pacientes es rápido; lo mido en la 5.1 con 5.000 pacientes sintéticos. Las fotos se descifran solo cuando se ven, y las miniaturas se guardan aparte, también cifradas.
4. **Base y código aparte de IHCE.** Del pedido original reutilizo el algoritmo (AES-256-GCM de `cryptography`), el estilo del contrato del almacén y el patrón de migraciones. **No reutilizo `RepositorioIhce` ni la clase `CifradorDatos`**: el primero es específico del RDA y guarda metadatos en claro, y la segunda toma su llave de `flutter_secure_storage` (ver Hallazgos). El consultorio usa una **base aparte** (`historiasclinicas_consultorio`), con su propia llave, y el código de IHCE no cambia.
5. **Copia de trabajo de la historia sellada.** El índice guarda el último `historia.json` sellado de cada historia, y los bytes exactos de su último PDF y de cada documento. Así, desde la ficha:
   - «Abrir PDF» abre el archivo legal exacto;
   - «Agregar evolución» continúa la historia sin buscar el archivo;
   - una sesión de procedimiento se sella como evolución.

   Cada versión nueva **se descarga igual que hoy** (`_vN`), porque el PDF sigue siendo el registro. Si abres un PDF más viejo que la copia del índice, la app avisa, para que la historia no se bifurque.
6. **Bandera constante.** `const consultorioHabilitado = bool.fromEnvironment('CONSULTORIO_ENABLED')`. Con la bandera apagada, el compilador **elimina** el código del consultorio del sitio público. Una prueba lo comprueba: busca en `main.dart.js` una marca del módulo y no debe encontrarla.
7. **Dónde corre.** La versión con la bandera encendida se publica en **otra dirección** (pregunta 2), para que el sitio público no cambie y para que lo guardado en cada uno quede separado.
8. **Una pestaña a la vez.** Un candado entre pestañas (`navigator.locks`) evita que dos pestañas escriban a la vez. La historia y la receta siguen funcionando aunque el consultorio esté bloqueado. Si sellas una historia con el consultorio bloqueado, la app te pide la frase; si prefieres seguir, la registra al desbloquear, **guardándola solo en memoria** (nunca en claro). Si cierras la pestaña antes, la importación de PDF la recupera.

```
  frase de acceso ──PBKDF2/Argon2id──► llave de la frase ─┐
                                                          ├─► desenvuelve ► LLAVE DE DATOS (solo en memoria)
  código de recuperación ──PBKDF2────► llave del código ──┘                     │
                                                                                ▼
  IndexedDB «historiasclinicas_consultorio»                     AES-256-GCM (AAD = colección|id)
  ├─ meta      llavero (sal, parámetros, llave de datos envuelta ×2), esquema, último respaldo
  ├─ registros pacientes/…, historias/…, documentos/…, citas/…, cobros/…, insumos/…   (cifrados)
  └─ binarios  fotos, miniaturas, PDF exactos, firmas                                  (cifrados)
```

---

## (a) Preguntas

### Para empezar la 5.0
1. **¿Apruebas la arquitectura con los ocho ajustes de arriba?** *Por defecto:* sí.
2. **¿Dónde corre la versión con la bandera encendida?**
   - **(a)** Un subdominio propio, por ejemplo `consultorio.historiasclinicas.net`, en Cloudflare Pages o Netlify. Es otra dirección, con lo guardado aparte.
   - **(b)** Solo en tu Mac, servida en `localhost`. Funciona sin conexión, pero solo en ese equipo.
   - **(c)** El mismo `historiasclinicas.net`. No lo recomiendo: cambiaría el sitio público.

   En (a):
   - la página sería pública aunque los datos no: cada navegador guarda lo suyo, cifrado;
   - las cabeceras son **las mismas del sitio público** (misma CSP y misma `Permissions-Policy`), y la prueba que exige que coincidan las incluye. Solo cambiarían si eliges la cámara en vivo (pregunta 21 b);
   - se puede restringir el acceso con Cloudflare Access (VERIFICAR el plan gratuito). Agrega un inicio de sesión de Cloudflare al entrar con conexión; sin conexión, la app instalada abre igual desde su caché (VERIFICAR).

   *Por defecto:* (a), con la guía de publicación en la 5.0. La cuenta la creas tú; no publico nada.
3. **¿En qué equipos vas a trabajar?** Los datos viven en un navegador de un equipo, sin sincronización (eso es Fase 6).
   - Si atiendes en un portátil y tomas fotos o firmas con el celular, propongo: restauras el respaldo en el celular, que así comparte la llave, y lo usas como **equipo secundario**. Lo que hagas ahí (fotos, mediciones y documentos firmados) lo pasas al portátil en un **paquete cifrado** (`.hcpaquete`), que se combina con lo del portátil en vez de reemplazarlo.
   - Si usas una tableta para todo, no hace falta.

   *Por defecto:* portátil como equipo principal y celular como secundario, con el paquete cifrado (en la 5.2).
4. **Frase de acceso y recuperación.** *Por defecto:*
   - frase de 12 caracteres o más, con medidor de fortaleza;
   - código de recuperación de 24 caracteres, que se muestra una sola vez y se descarga en una hoja PDF para imprimir. Para confirmar que lo guardaste, la app te pide sus últimos 4 caracteres.
5. **Derivación de la llave.** *Por defecto:* PBKDF2-HMAC-SHA256 con 600.000 iteraciones. En la 5.0 mido Argon2id en tus equipos y te traigo los tiempos para decidir.
6. **Bloqueo.** *Por defecto:*
   - 10 minutos sin actividad, configurable de 2 a 60;
   - botón «Bloquear ahora»;
   - al bloquear, la pantalla se tapa y la app **descarta** la llave y los datos descifrados. El navegador no permite garantizar que la memoria se borre al instante, así que la llave se importa en WebCrypto como no extraíble: el código de la página puede usarla pero no leerla;
   - con la bandera encendida, el borrador de la historia y la receta en curso, que hoy quedan en claro en el navegador, se guardan cifrados en el almacén. Con el consultorio bloqueado, el borrador se guarda solo en memoria hasta desbloquear. Con la bandera apagada no cambia nada.
7. **Respaldo.** *Por defecto:*
   - aviso a los 7 días sin respaldo, configurable;
   - un archivo `.hcrespaldo` que se descarga y que conviene guardar en dos sitios (USB y tu nube; va cifrado);
   - restaurar reemplaza todo, tras confirmar. Combinar queda solo para el paquete del equipo secundario.

   ¿Quieres además que la app ofrezca el respaldo al cerrar el día de caja? *Por defecto:* sí.
8. **Regla 10 de IHCE.** La Fase 5 cambia la interfaz a propósito, y la regla compara archivo por archivo, así que se pondría en rojo. *Por defecto:*
   - la regla 10 sigue igual para todo lo demás;
   - acepta también el inventario de `docs/FASE5.md` (tabla «Archivos existentes que cambia la Fase 5», con la ruta completa de cada archivo) y la carpeta nueva `lib/features/consultorio/` completa;
   - `tema.dart` y `web/` siguen sin tocarse;
   - no hay dependencias nuevas (ver «Dependencias»). Si alguna hiciera falta, te la pregunto antes.

   Es el único control que cambia, y el cambio queda en su propio commit.
9. **Orden de las subfases.** Tu orden se mantiene, con dos ajustes:
   - una **5.0 «Cimientos»** antes de la 5.1: bandera, almacén cifrado, desbloqueo, respaldo y navegación;
   - el **consentimiento informado pasa a la 5.3**, porque la regla «firmado antes de la primera sesión» lo necesita ahí. La 5.4 hace los demás documentos.

   El motor de documentos (PDF con datos incrustados y firma del paciente) y el **editor de textos de plantillas** (con versiones y «aprobar») empiezan en la 5.1 con la autorización de tratamiento de datos, porque ninguna plantilla BORRADOR se puede usar sin aprobarla. Los editores de la plantilla del procedimiento y de los esquemas de GLP-1 llegan en la 5.3. *Por defecto:* así.

### Pacientes (5.1)
10. **Identidad.** *Por defecto:*
    - clave = tipo + número de documento, normalizados (sin puntos ni espacios);
    - para un adulto o menor sin identificar (AS/MS), un identificador interno;
    - si el documento cambia (TI → CC), «Unir fichas» manual, con registro en la bitácora.
11. **Líneas y etiquetas.** *Por defecto:*
    - un paciente puede estar en varias líneas a la vez. La app propone la línea según lo que registres (una valoración estética sugiere «Estética»), y tú la confirmas;
    - etiquetas libres, con sugerencias de las ya usadas.
12. **Autorización de tratamiento de datos.** *Por defecto:*
    - se pide en la primera atención: lectura, casilla y firma en pantalla;
    - si el paciente no la da, la ficha muestra un aviso permanente, pero **no se bloquea la atención clínica**, porque la historia es una obligación legal (VERIFICAR con tu abogado).
13. **Ficha y datos sellados.** *Por defecto:*
    - la ficha muestra los antecedentes y las alergias de la historia inicial más reciente, con la fuente («de la historia del 02/10/2026»);
    - «Actualizar alergias» en la ficha agrega «Alergias actualizadas: …» a la evolución en curso, que queda sellada, y actualiza la ficha y la alerta de la receta;
    - los datos administrativos (teléfono, dirección, etiquetas) se editan en la ficha y no alteran lo sellado.
14. **Recetas.** Con la bandera encendida, ¿incrusto `receta.json` en la receta nueva y la registro en la ficha? Con la bandera apagada, la receta queda como hoy. *Por defecto:* sí.
15. **Próximo control en las evoluciones.** Hoy solo lo tiene el plan de la historia inicial.
    - **(a)** Agregar a la evolución un campo opcional «Próximo control», solo con la bandera encendida. Toca el modelo, el editor, el PDF y la lectura de la evolución. Se sella en el PDF; antes compruebo con una prueba que la versión pública abra, verifique y continúe esas historias sin perder el campo.
    - **(b)** No tocar el formato: el indicador usa el plan y las citas futuras.

    *Por defecto:* (a).
16. **Importación en lote.** *Por defecto:*
    - se aceptan muchos PDF a la vez, elegidos o soltados;
    - por cada uno se informa: importada, ya estaba, versión más nueva (se actualiza), **alterada desde la evolución *n*** (se indexa marcada, nunca se oculta), dañada, o no es de la app;
    - si dos PDF de la misma historia se contradicen, se marcan como «versiones divergentes» para que elijas;
    - desde la 5.4 acepta también los PDF de documentos (`documento.json`) y de recetas nuevas (`receta.json`).

### Seguimiento y fotos (5.2)
17. **Mediciones.** Se guardan en el índice con su fecha. Si se toman durante una atención, ¿se copian al texto de la evolución al sellarla («Mediciones del día: …»)? *Por defecto:* sí, porque son datos clínicos y deben quedar en la historia.
18. **Perímetros.** *Por defecto:*
    - abdomen, flancos, muslos y brazos, con muslos y brazos derecho e izquierdo por separado;
    - el % de grasa es opcional y pide el método (bioimpedancia, pliegues u otro);
    - la talla se arrastra de la última medición.
19. **Vistas de las fotos.** *Por defecto:* frontal, lateral derecha, lateral izquierda, posterior y «detalle de zona». Cada vista trae una guía de encuadre (siluetas y líneas de hombros, ombligo y caderas) y la foto anterior en transparencia para alinear.
20. **Calidad y privacidad.** *Por defecto:*
    - lado mayor de 1600 px, JPEG al 80 % (unos 300 KB por foto);
    - **se quitan los metadatos EXIF**, que pueden incluir la ubicación GPS;
    - las fotos tomadas con `capture` no deberían quedar en el carrete del celular (VERIFICAR en tu modelo).
21. **Cámara.**
    - **(a)** Cámara del sistema mediante el selector de archivos: funciona en celulares y tabletas sin tocar las cabeceras. La guía y la foto anterior en transparencia se muestran justo después de tomarla, para repetirla si no quedó alineada.
    - **(b)** Vista en vivo con la guía encima: exige `camera=(self)` en las cabeceras de la versión del consultorio. Es más compleja, pero el sitio público no cambia.

    *Por defecto:* (a) en la 5.2; (b) como opción para la Fase 6.
22. **Consentimiento de uso de imagen.** *Por defecto:* tres permisos separados, cada uno revocable:
    - registro clínico, obligatorio para tomar fotos;
    - docencia o publicación académica sin rostro ni rasgos identificables;
    - publicidad o redes sociales.

    Sin el primero, el botón de fotos no aparece.
23. **Fotos en los PDF.** *Por defecto:*
    - nunca en la historia **sin que lo pidas**: solo si eliges fotos concretas para adjuntar a una evolución;
    - en el «Informe de seguimiento», solo si marcas «Incluir fotos», que viene apagado;
    - las fotos viven en el almacén y en el respaldo, que es su custodia. «Exportar fotos del paciente» las saca en un PDF, solo si lo pides.

### Programa de peso (5.3)
24. **Catálogo de medicamentos GLP-1.** *Por defecto:* semaglutida subcutánea semanal, semaglutida oral, liraglutida y tirzepatida (GIP/GLP-1). Cada uno lleva:
    - nombre comercial, registro Invima e indicación aprobada;
    - un esquema de titulación editable.

    Todo **VERIFICAR** contra la ficha técnica. Solo Ozempic tiene registro confirmado en lo que encontré (y para diabetes tipo 2), así que los demás vienen marcados «registro Invima sin confirmar» hasta que escribas el número. No pongo dosis por defecto que no hayas revisado: cada esquema queda como «sin aprobar» hasta que lo apruebes.
25. **Lista de contraindicaciones** (toda VERIFICAR contra la ficha técnica con registro Invima). *Por defecto:*
    - **absolutas** (bloquean el inicio): antecedente personal o familiar de carcinoma medular de tiroides o MEN2, antecedente de pancreatitis, embarazo, lactancia e hipersensibilidad. La pancreatitis la pongo aquí porque la nombraste; en algunas fichas figura como precaución;
    - **precauciones** (piden una nota): enfermedad biliar, retinopatía diabética, NAION o neuritis óptica, gastroparesia o enfermedad gastrointestinal grave, diabetes tipo 1, insuficiencia renal o riesgo de deshidratación, depresión o ideación suicida, cirugía o sedación programada, y uso de insulina o sulfonilureas;
    - en mujeres en edad fértil, anticoncepción y plan de embarazo (suspender antes, VERIFICAR el plazo).

    ¿Quitas o agregas alguna?
26. **Plantillas de plan nutricional y de ejercicio.** ¿Me envías las tuyas? *Por defecto:* tres plantillas de ejemplo marcadas BORRADOR, que no se pueden usar hasta que las edites y apruebes. El recordatorio de proteína suficiente y entrenamiento de fuerza aparece en el programa y en las indicaciones impresas; la cantidad de proteína la fijas tú.
27. **Meta.** *Por defecto:* peso meta, cintura meta y fecha, más el % de peso perdido calculado y la gráfica contra la meta.

### Valoración estética y sesiones (5.3)
28. **Criterios de candidato.** *Por defecto:* todos editables en la plantilla:
    - IMC máximo 30 como aviso (VERIFICAR tu criterio de «cerca del peso ideal»);
    - por zona: grasa pinzable sí/no y en cm, elasticidad (buena, regular o mala) y flacidez (0 a 3);
    - expectativas (realistas o no realistas), con nota.

    ¿Qué umbrales usas?

    Contraindicaciones por defecto, cualquiera en «sí» da «no apto» o «diferir» según el caso:
    - embarazo o lactancia;
    - anticoagulación o coagulopatía;
    - infección en la zona;
    - enfermedad descompensada;
    - alergia a anestésicos locales.

    Del proyecto de ley se suman, como precaución: antiagregación no suspendida según protocolo, cirugía previa en la zona e indicios de trastorno dismórfico corporal.
29. **Resultado.** *Por defecto:*
    - apto, no apto o diferir, con motivo obligatorio y una recomendación de una lista editable («primero programa de peso», «flacidez: remitir a cirugía plástica»);
    - «no apto» y «diferir» bloquean agendar y registrar sesiones de ese procedimiento hasta una valoración nueva;
    - «apto» vale 90 días.

    La valoración también se sella como evolución en la historia.
30. **Tamizaje** (VERIFICAR la validación y la licencia de cada instrumento). *Por defecto:*
    - conducta alimentaria: SCOFF (validado en español);
    - dismorfia: el DCQ, que está validado en español, o el BDDQ-AS si confirmas que su versión en español está validada. ¿Cuál prefieres?
    - un tamizaje positivo sugiere «diferir y remitir a psicología o psiquiatría»;
    - sin licencia confirmada no incluyo el texto de los ítems: la app trae la estructura, y tú cargas el texto o me confirmas que su uso es libre.
31. **Protocolo del procedimiento.** No voy a inventar la composición de la solución, los volúmenes ni los parámetros del equipo. *Por defecto:*
    - la plantilla de hidrolipoclasia trae los **campos**, y tú escribes tu protocolo: zonas, componentes, volumen máximo por zona y por sesión, intervalo entre sesiones y número de sesiones;
    - la plantilla queda «sin aprobar» hasta que la revises.

    ¿Me envías tu protocolo escrito?
32. **Dosis del anestésico.** *Por defecto:*
    - la dosis se calcula en mg y mg/kg a partir de la concentración, el volumen y el peso de la última medición. Si la medición tiene más de 30 días, pide pesar;
    - aviso ámbar desde el 80 % del máximo del protocolo y **bloqueo por encima del 100 %**;
    - el máximo por anestésico (con y sin epinefrina) lo fijas tú (VERIFICAR; el proyecto de ley lo dejaría a MinSalud).

    ¿Bloqueo o solo aviso?
33. **Lista de verificación previa a la sesión** (art. 14 del proyecto de ley, VERIFICAR). *Por defecto:* obligatoria, con ítems editables:
    - consentimiento vigente, valoración vigente y mayor de edad;
    - alergias, anticoagulación, embarazo, infección en la zona y signos vitales;
    - lotes vigentes, equipo verificado, y emulsión lipídica y protocolo de toxicidad disponibles.
34. **Póliza de complicaciones** (art. 17 del proyecto de ley, VERIFICAR). *Por defecto:* campo opcional (aseguradora y número, o «sin póliza») en la configuración, que se copia al consentimiento y a la sesión.
35. **Sesión sellada.** *Por defecto:*
    - se sella como evolución, y genera la versión nueva del PDF de la historia, que se descarga;
    - como el PDF es el registro legal, **el texto sellado lleva todo lo clínico**: zona, componentes y volúmenes, anestésico con lote, dosis en mg y mg/kg, equipo y parámetros, insumos con lote y vencimiento, resultado de la lista de verificación, duración, eventos adversos, indicaciones y control;
    - el índice guarda además los mismos datos estructurados, para el inventario y los informes.
36. **Certificaciones por técnica.** *Por defecto:*
    - en la configuración: técnica o familia, entidad, fecha, vigencia y el soporte (PDF o foto, cifrado);
    - usar una técnica sin certificación vigente da un **aviso** que queda registrado, pero no bloquea mientras el proyecto de ley no sea ley.

    ¿Aviso o bloqueo?

### Documentos (5.4)
37. **Textos.** ¿Me envías tus textos de consentimiento, certificados e incapacidad? *Por defecto:*
    - plantillas base con los apartados del art. 16 del proyecto de ley y del art. 8 de la Ley 2316 (VERIFICAR los dos), marcadas BORRADOR, que no se pueden usar hasta que las edites y apruebes;
    - cada documento lleva tus datos, tu firma y tu sello, con los mismos interruptores «Incluir firma» e «Incluir sello» de hoy, y al firmarlo **se descarga su PDF** igual que la historia (el índice guarda además el PDF exacto);
    - cada plantilla lleva versión, y cada documento guarda con cuál se firmó.
38. **Firma del paciente.** *Por defecto:* en pantalla, idealmente en tableta o celular. Como alternativa, imprimir, firmar en papel y adjuntar la foto o el escaneo.
39. **Consentimiento por plan de tratamiento.** *Por defecto:*
    - un consentimiento cubre el plan (procedimiento, zonas y número de sesiones);
    - se pide uno nuevo si cambian la técnica, el producto o las zonas;
    - revocarlo bloquea las sesiones siguientes y queda registrado con fecha y motivo.
40. **Numeración.** *Por defecto:*
    - un consecutivo por tipo: CI- (consentimientos informados), CIM- (consentimientos de uso de imagen), AD- (autorizaciones de datos), CE- (certificados), IN- (incapacidades), OR- (órdenes), RM- (remisiones), IS- (informes de seguimiento) y RC- (recibos);
    - la política de privacidad no lleva número: es una sola, con versión;
    - un documento no se borra: se **anula** con motivo.
41. **Órdenes.** *Por defecto:* texto con plantillas (perfil metabólico, TSH, HbA1c, perfil lipídico, función hepática), sin códigos CUPS porque no hay catálogo incluido. Se podría importar uno después.

### Agenda (5.5)
42. **Horario y duraciones.** *Por defecto:*
    - horario: lunes a viernes de 8:00 a 12:00 y de 14:00 a 18:00, sábado de 8:00 a 12:00;
    - duraciones: primera vez 30 min, control 20, programa de peso 30, valoración estética 40 y sesión 60;
    - festivos de Colombia calculados (Ley 51 de 1983, VERIFICAR) y bloqueos manuales;
    - si dos citas se cruzan, la app avisa y no bloquea;
    - «no asistió» no consume sesiones del paquete, cuenta en un contador de inasistencias de la ficha y deja vigente el control vencido.
43. **WhatsApp y calendario.** El mensaje sale de la app hacia WhatsApp, que es un tercero, y un `.ics` puede terminar en un calendario en la nube. *Por defecto:*
    - mensaje editable **sin datos de salud**: «Hola {nombre}, le recordamos su cita el {día} a las {hora} en {consultorio}, {dirección}. Por favor confirme respondiendo este mensaje.» No incluye el tipo de cita («sesión», «programa de peso»);
    - el `.ics` dice solo «Cita médica» con la hora y el lugar;
    - la autorización de tratamiento de datos incluye, como finalidad, el contacto por WhatsApp y teléfono (VERIFICAR con tu abogado);
    - cada mañana, la agenda lista las citas del día siguiente sin recordatorio, con un botón «Enviar» por cita. El navegador no deja abrir varias pestañas con un solo clic, así que se envían una por una;
    - la confirmación la marcas tú a mano.

### Caja y paquetes (5.6)
44. **Tarifas iniciales y valoración abonable.** *Por defecto:*
    - el catálogo arranca con tus tarifas, todas editables:

      | Servicio | Línea | Tarifa inicial |
      |---|---|---|
      | Consulta de primera vez | General | 80.000 |
      | Control | General | 45.000 |
      | Certificado | General | 40.000 |
      | Valoración estética (abonable al tratamiento) | Estética | 70.000 |
      | Sesión de hidrolipoclasia por zona | Estética | 240.000 |
      | Paquete de 4 sesiones | Estética | 880.000 |

      ¿El control del programa de peso tiene tarifa propia?
    - el valor de la valoración queda como crédito durante 30 días y se descuenta del primer pago del tratamiento.
45. **Paquetes.** *Por defecto:* el paquete de 4 sesiones es para una zona, sin vencimiento. ¿Hay devoluciones si el paciente no termina? Las promociones con plazo no se incluyen (art. 18 del proyecto de ley; Ley 1480 de 2011, VERIFICAR).
46. **Medios de pago.** *Por defecto:*
    - efectivo, transferencia, Nequi, Daviplata y tarjeta;
    - abonos parciales y saldo;
    - recibo RC-000001 en A5, solo cuando hay pago. Usar una sesión de un paquete ya pagado no genera recibo: queda en el saldo del paquete y en la sesión;
    - el cierre del día cuenta el efectivo y registra la diferencia, y no se reabre. Anular un recibo de un día cerrado cuenta en el día en que se anula, con referencia al recibo original.
47. **CSV.** *Por defecto:* separador `;` y codificación UTF-8 con BOM, para que Excel en español lo abra bien.

### Inventario (5.7)
48. **Insumos iniciales.** ¿Me envías tu lista? *Por defecto:*
    - inventario vacío, con categorías: medicamento, dispositivo médico, insumo y sustancia modelante (para el futuro);
    - el stock se lleva en la unidad de presentación (ampolla, frasco, unidad);
    - la concentración (mg/mL) sirve para calcular dosis.
49. **Lotes.** *Por defecto:*
    - se sugiere el lote que vence primero;
    - aviso 30 días antes del vencimiento;
    - **bloqueo** para usar un lote vencido o sin stock;
    - el registro Invima no se puede verificar sin conexión: botón «Consultar en Invima», que abre su sitio en otra pestaña sin enviarle datos.

### Presentación (5.8)
50. **Las notas «VERIFICAR» en pantalla.** Hoy se ven, por ejemplo:
    - «VERIFICAR su validez legal» (firma y sello);
    - «VERIFICAR cuáles exige la norma» (datos complementarios);
    - «VERIFICAR la norma de tu país» (control especial).

    Propuesta, sin cambiar la convención hasta que me digas:
    - **(a)** En pantalla, un chip discreto «Por verificar» con la nota completa en un globo de ayuda. En el **«modo presentación»**, que se activa con un botón cuando te ve un paciente o un auditor, los chips se ocultan. En los PDF nunca se imprimen.
    - **(b)** Un registro de verificaciones: marcas una nota como verificada, con fecha y fuente, y el chip cambia a «Verificado el 21/11/2026 · Res. 1995/1999».

    La marca VERIFICAR sigue en el código y en los documentos. *Por defecto:* (a) y (b), solo con la bandera encendida. El sitio público queda igual.
51. **Inicio y navegación.** *Por defecto:*
    - con la bandera encendida, la app abre en la **agenda de hoy**;
    - en escritorio (≥ 1100 px), riel lateral de 80 px: Agenda, Pacientes, Historia, Caja, Inventario y Ajustes;
    - en móvil, menú lateral desde la barra superior, para no chocar con la barra de acciones de la historia;
    - el nombre del consultorio va junto al logotipo.

---

## (b) Modelo de datos

Convenciones:
- Todos los registros llevan `id` (UUID), `creado`, `actualizado` y `version`.
- Nada clínico se borra: se **anula** con motivo y fecha.
- Las fechas siguen el formato de `historia.json` (`AAAA-MM-DD`, `AAAA-MM-DDTHH:MM` local).
- Los valores en pesos son enteros.
- `→` indica una referencia a otro registro.

### Almacén

| Almacén de IndexedDB | Clave | Contenido |
|---|---|---|
| `meta` (en claro) | `llavero` | Formato, algoritmo y parámetros de derivación, sal, llave de datos envuelta con la frase, llave de datos envuelta con el código de recuperación, verificador |
| | `esquema` | Versión del esquema (migraciones) |
| | `respaldo` | Fecha del último respaldo y huella del archivo |
| `registros` (cifrado) | `<colección>/<uuid>` | Un `Uint8Array`: `[formato 1 B][nonce 12 B][texto cifrado + etiqueta GCM]`, con AAD = `hcc1|<colección>|<uuid>`, sobre el JSON canónico del registro. El JSON lleva su propia versión de esquema; una migración descifra, transforma y vuelve a cifrar cada registro en una transacción |
| `binarios` (cifrado) | `<tipo>/<uuid>` | Fotos, miniaturas, PDF exactos, firmas y soportes, en el mismo formato |

Las colecciones solo revelan cuántos registros hay de cada tipo, nunca su contenido. Las imágenes de firma y sello que se repiten en muchas historias se guardan una sola vez: el registro cifrado lleva su SHA-256 (como `recursos` en `historia.json`), pero la clave de IndexedDB es un identificador al azar.

### Entidades

```
Paciente ─┬─< Historia (índice + copia de trabajo) ──< Evolución (dentro de la historia sellada)
          ├─< Receta            ├─< Documento (autorización, consentimientos, certificados, …)
          ├─< Medición          ├─< Foto ─> Consentimiento de imagen
          ├─< ProgramaPeso ──< Dosis / Tolerancia / Evento adverso
          ├─< Valoración ─> PlantillaProcedimiento ─< Sesión ─> Consentimiento, Lote(s), Cita
          ├─< Cita ─> Cobro ─< Pago            Paquete ─< uso por Sesión      Crédito (valoración abonable)
          └── Bitácora (sin datos del paciente)     Insumo ─< Lote ─< Movimiento (entrada, salida, ajuste, baja)
```

| Entidad | Campos principales | Reglas |
|---|---|---|
| **Paciente** | Tipo y número de documento (normalizado), apellidos y nombres, fecha de nacimiento o edad aproximada, sexo, teléfono en formato +57 (y si tiene WhatsApp), correo, dirección, ciudad, ocupación, aseguradora, contacto de emergencia, `lineas` {general, peso, estética}, `etiquetas[]`, notas internas, → autorización de datos vigente, → consentimiento de imagen vigente, `unidoEn` (si se fusionó) | Documento único (salvo AS/MS). Los datos clínicos (alergias, antecedentes) no se guardan aquí: se leen de la historia sellada más reciente y de las «Alergias actualizadas» selladas en evoluciones, con su fuente (pregunta 13) |
| **Historia** (índice) | `historiaId` (el `id` de `historia.json`), → paciente, revisión, `datos` sellados (copia de trabajo), fecha de la atención, diagnósticos (resumen), `proximoControl`, huellas, `archivos[]` {nombre, revisión, SHA-256 del PDF, fecha, origen: generado o importado}, → PDF exacto de la última revisión, integridad {estado, alterada desde, descripción} | Un `historiaId` por registro. Una revisión menor que la guardada no la reemplaza. Dos contenidos distintos con la misma revisión marcan «versiones divergentes» |
| Evolución | Vive dentro de `datos.evoluciones` (no se duplica). El índice guarda su tipo (evolución, valoración, sesión, control de peso) y → registro de origen | |
| **Receta** | → paciente, → historia, número R-, fecha, ítems, indicaciones, SHA-256 del PDF, → PDF exacto, origen (generada con `receta.json` o «registrada en la historia») | |
| **Documento** | → paciente, tipo, → plantilla y versión, número consecutivo, fecha y hora, contenido, firma del paciente (→ PNG + SHA-256), copia del médico (`Autor`), estado (vigente, revocado {fecha, motivo} o anulado {motivo}), SHA-256 de `documento.json`, → PDF exacto | El PDF lleva `documento.json` incrustado y sellado, como la historia, para poder importarlo y verificarlo después |
| **Medición** | → paciente, fecha, peso, talla, cintura, cadera, perímetros {abdomen, flanco D/I, muslo D/I, brazo D/I}, PA sistólica/diastólica, % de grasa y método, notas, origen (manual o → historia/evolución) | IMC (`calcularImc`) e índice cintura-cadera se calculan, no se guardan. Los valores fuera de rango avisan sin bloquear, como hoy |
| **Foto** | → paciente, fecha, vista, zona, → sesión, ancho y alto, SHA-256 del JPEG, → binario, → miniatura, → consentimiento de imagen, notas | No se puede crear sin consentimiento de imagen vigente para uso clínico. Sin EXIF |
| **ProgramaPeso** | → paciente, inicio, meta {peso, cintura, fecha}, plan nutricional y de ejercicio (texto, → plantilla), lista de contraindicaciones {ítem: sí, no o desconoce, nota, versión del catálogo}, `glp1?` {→ medicamento del catálogo, registro Invima, indicación aprobada, inicio, dosis[] {fecha, dosis, unidad}, tolerancia[] {fecha, síntomas, escala}, eventos adversos[] {fecha, descripción, gravedad, conducta, reportado a Invima}, suspensión}, estado (activo, pausado o terminado) | Una contraindicación absoluta en «sí» impide registrar el inicio del GLP-1. Una precaución en «sí» exige nota |
| **Valoración** | → paciente, → plantilla y versión, fecha, respuestas (por ítem de la plantilla), IMC (calculado de la medición), zonas[] {zona, pinzable cm, elasticidad, flacidez}, expectativas, contraindicaciones[], tamizajes[] {instrumento, versión, respuestas, puntaje, positivo}, resultado (apto, no apto o diferir), motivo, recomendación, vigente hasta, → evolución sellada | Un paciente menor de 18 años no puede tener valoración. El motivo es obligatorio. «No apto» y «diferir» bloquean las sesiones de ese procedimiento |
| **PlantillaProcedimiento** | id (`hidrolipoclasia`), nombre, familia de técnicas (para las certificaciones), versión, aprobada por el médico (fecha), definición declarativa de la valoración (secciones e ítems: sí/no, escala, número, texto u opciones, con su regla), criterios de candidato, contraindicaciones (absoluta o precaución), tamizajes requeridos, campos de la sesión, insumos sugeridos, → plantilla de consentimiento, lista de verificación previa, indicaciones posteriores, días hasta el control, protocolo escrito | Una plantilla sin aprobar no se puede usar. **Agregar toxina, rellenos o bioestimuladores = agregar una plantilla**, sin reescribir el módulo |
| **Sesión** | → paciente, → plantilla, → valoración, → consentimiento, → cita, fecha, número de sesión en el plan, lista de verificación previa (respuestas), zonas[] {zona, componentes[] {→ lote, concentración, volumen mL}, volumen total}, anestésico {→ lote, concentración mg/mL, volumen mL, dosis mg y mg/kg calculadas, peso usado}, equipo {nombre, serie, registro Invima, parámetros}, insumos[] {→ lote, cantidad}, duración, eventos adversos[], indicaciones posteriores, fecha de control, estado (borrador o sellada), huella de la evolución | Para sellar exige: mayor de edad, valoración «apto» vigente, consentimiento vigente y sin revocar, lista completa, lotes no vencidos y con stock, y dosis dentro del máximo. Avisa si falta la certificación de la técnica. Al sellar, descuenta del inventario |
| **Cita** | → paciente (o nombre y teléfono provisionales para una primera vez), tipo (primera vez, control, valoración estética, sesión de procedimiento o programa de peso), inicio, duración (la del tipo, editable), estado (agendada, confirmada, atendida, no asistió o cancelada) e historial {estado, fecha}, motivo, notas, recordatorio {enviado en}, → plantilla (si es sesión), → cobro, → atención (historia o evolución) | Una cita de sesión o valoración estética exige mayor de edad. La de sesión exige además valoración «apto» vigente |
| **Horario** | Días y franjas, duración por tipo, bloqueos {inicio, fin, motivo}, festivos calculados | |
| **Servicio** | Nombre, línea, tarifa, IVA (opcional, apagado), abonable, sesiones del paquete, → plantilla, activo | Las tarifas iniciales son las de tu tabla (pregunta 44), editables |
| **Cobro** | Número RC-, fecha, → paciente, ítems[] {→ servicio, descripción, cantidad, valor unitario, descuento y motivo}, total, pagos[] {medio, valor, referencia, fecha}, saldo, → paquete, → crédito aplicado, estado (vigente o anulado {motivo}), → PDF del recibo | El número se asigna al emitir, no se reutiliza y no se salta |
| **Paquete** | → paciente, → servicio, sesiones compradas, usos[] {→ sesión, fecha}, → cobro, estado | No se puede usar más sesiones de las compradas |
| **Crédito** | → paciente, valor, → cobro de origen, vence, aplicado en | |
| **CierreDiario** | Fecha, totales por medio de pago, efectivo contado, diferencia, notas, cerrado en | Un día cerrado no se modifica: una anulación posterior cuenta en el día en que se hace |
| **Insumo** | Nombre, categoría, presentación, unidad, concentración (mg/mL), registro Invima, inyectable, stock mínimo, activo | Sin registro Invima: aviso (más visible en los inyectables) |
| **Lote** | → insumo, número de lote, vencimiento, proveedor, factura, fecha de ingreso | Su existencia es la suma de sus movimientos |
| **Movimiento** | → lote, tipo (entrada, salida por sesión, ajuste o baja por vencimiento), cantidad, fecha, → sesión, motivo | Solo se agregan, nunca se editan |
| **Configuración** | Datos del prestador (nombre del consultorio, código REPS, NIT, habilitación por servicio), certificaciones[] {técnica o familia, entidad, fecha, vigencia, → soporte}, póliza, minutos de bloqueo, días de respaldo, consecutivos, plantillas, horario, notas verificadas, modo presentación | |
| **Bitácora** | Fecha, acción (crear, anular, unir, exportar, importar, respaldar, restaurar, desbloquear), colección, id, resumen **sin datos del paciente** | Solo se agrega. Sirve para auditoría |

### Archivo de respaldo (`.hcrespaldo`)

```
Respaldo_consultorio_2026-11-21.hcrespaldo        (ZIP sin compresión; el contenido ya va cifrado)
├─ LEEME.txt          en claro: qué es y cómo restaurarlo; sin datos
├─ manifiesto.json    en claro: formato, versión de la app, fecha, parámetros de la llave, sal,
│                     llave de datos envuelta ×2, conteos y el SHA-256 de cada archivo
├─ manifiesto.sello   AES-GCM(llave de datos) del SHA-256 del manifiesto: autentica el manifiesto
├─ registros/000001.bin …    los mismos bytes cifrados del almacén, en lotes
└─ binarios/<tipo>/<id>.bin  fotos, miniaturas, PDF exactos, firmas
```

**Al importar se verifica todo:**
1. La frase (o el código) abre la llave.
2. El sello autentica el manifiesto.
3. El SHA-256 de cada archivo coincide con el manifiesto.
4. Cada registro se descifra con su AAD.
5. Los conteos coinciden.

Si algo falla, la app lista exactamente qué y no restaura nada, salvo que confirmes «restaurar solo lo íntegro». Restaurar reemplaza el almacén, después de confirmar. El **paquete del equipo secundario** (`.hcpaquete`) usa el mismo formato, solo con lo creado en ese equipo (fotos, mediciones y documentos firmados), y se combina en vez de reemplazar: lo que ya existe con el mismo identificador no se duplica.

**Límite:** el respaldo se arma en memoria. Con miles de fotos puede pesar cientos de MB. Si se acerca al límite del navegador, la app ofrece partir el respaldo, por ejemplo con las fotos por año aparte.

---

## (c) Bocetos textuales

### Paleta y estilo
Se mantiene el diseño 2b «Clínico sobrio» ([DISENO.md](DISENO.md)), con los componentes de hoy (`TarjetaSeccion`, `Aviso`, `TituloDialogo`, `RecuadroIcono`, los campos de `campos.dart`) y sin tocar `lib/app/tema.dart`. Lo nuevo usa solo tokens existentes de `ColoresMarca`, todos con contraste ≥ 4,5:1 sobre blanco (ya lo comprueba `test/app/tema_test.dart`):

| Uso nuevo | Token | Además del color |
|---|---|---|
| Acción, selección, cita «confirmada», serie 1 de las gráficas | `primario` `#1E5A7A` | Ícono o etiqueta de texto |
| Cita «atendida», integridad correcta, «apto», serie 2 | `estadoOk` `#2E7D5B` | ✓ |
| Control vencido ⏰, vencimiento próximo ⏳, stock bajo, «diferir», «Por verificar», serie 3 | `aviso` `#8A5A0B` (sobre `avisoFondo`: `avisoTexto`) | Ícono |
| Bloqueo, «no apto», lote vencido, alteración, «no asistió» | `error` `#B3362F` | ✕ y el motivo en texto |
| Cita «agendada», texto secundario, serie 4 | `tintaSuave` `#3B4853` | |
| Cita «cancelada» | `textoSuave` `#556370` | Tachado |
| Bloqueos de agenda, fondo de selección | `bloqueado`, `tinte` | Rayado |

Nunca se distingue algo solo por el color: siempre va con ícono o texto. Las líneas de las gráficas superan 3:1 y sus textos 4,5:1. Las pruebas de contraste se amplían con cada combinación nueva (por ejemplo, texto `avisoTexto` sobre `avisoFondo` en los chips).

### Desbloqueo (primera vez y después)
```
┌──────────────────────────────────────────────────────────────┐
│          historiasclinicas.net · Consultorio                 │
│                                                              │
│   🔒 El consultorio está bloqueado                           │
│   Frase de acceso [••••••••••••••••••••] 👁                  │
│                                       [ Desbloquear ]        │
│   ¿Olvidaste la frase? Usar el código de recuperación        │
│   ─────────────────────────────────────────────────────────  │
│   Último respaldo: hace 3 días (18/11/2026)                  │
│   La historia y la receta funcionan sin desbloquear.         │
│                                       [Ir a la historia]     │
└──────────────────────────────────────────────────────────────┘
```
- **La primera vez** se pide la frase dos veces, con medidor de fortaleza. Después aparece el **código de recuperación**, con «Descargar hoja para imprimir», y la app pide sus últimos 4 caracteres antes de seguir. Se explica en una línea: «Sin la frase ni el código, nadie (tampoco nosotros) puede abrir estos datos».

### Escritorio (≥ 1100 px): contenedor y lista de pacientes
```
┌──────┬───────────────────────────────────────────────────────────────────────────────┐
│  ▣   │ historiasclinicas.net · Consultorio Dr. …   [🔍 Paciente o documento…] [🔒] [⋮] │
│Agenda├───────────────────────────────────────────────────────────────────────────────┤
│  👥  │ ┌ ⚠ Último respaldo hace 9 días. La custodia de las historias es tuya ────────┐ │
│Pacien│ │   (Res. 1995/1999): si este equipo se pierde, solo el respaldo las recupera. │ │
│  📄  │ │                                                    [Respaldar ahora]        │ │
│Histor│ └──────────────────────────────────────────────────────────────────────────────┘ │
│  $   │ PACIENTES · 412                              [+ Paciente] [⇪ Importar PDF]     │
│ Caja │ Buscar [nombre o documento_________]  Línea [Todas ▾]  Última atención [▾]     │
│  📦  │ Etiquetas [HTA ×] [+]    ☐ Solo controles vencidos (7)                         │
│Invent│ ┌────────────────────────────────────────────────────────────────────────────┐ │
│      │ │ PEÑA MUÑOZ, José Ángel    CC 1032456789  52 a  General · Peso  12/11  ⏰ venc │ │
│  ⚙   │ │ TORRES RUIZ, Juan         CC 79123456    45 a  General          02/10       │ │
│Ajuste│ │ …                                                                          │ │
└──────┴─┴────────────────────────────────────────────────────────────────────────────┴─┘
```
- La búsqueda no distingue tildes ni mayúsculas y acepta el documento con o sin puntos. Las flechas y Enter abren la ficha.
- **Historia** en el riel abre la pantalla de hoy, con su propia barra, a la derecha del riel. Si se abrió desde una ficha, la franja del paciente lleva «← Ficha».
- **Inicio:** con la bandera encendida, la app abre en `/agenda` (pregunta 51); la historia sigue en `/`. Con la bandera apagada no hay riel ni rutas nuevas, y la app abre en la historia, como hoy.
- **Tablet (700 a 1100 px):** el riel se vuelve un menú lateral. **Móvil (< 700 px):** menú lateral, lista de una columna y botón flotante «+ Paciente».

**La historia dentro del contenedor (escritorio, bandera encendida):**
```
┌──────┬────────────────────────────────────────────────────────────────────────────────┐
│  ▣   │ historiasclinicas.net   [Abrir historia existente] [Imprimir / Guardar PDF] [℞] [⋮] │
│Agenda│ ← Ficha · PEÑA MUÑOZ, José Ángel · CC 1032456789 · 52 a · ⚠ Penicilina          │
│  👥  ├──────────────┬─────────────────────────────────────────────────────────────────┤
│  📄● │ ÍNDICE       │ (la historia de hoy, sin cambios; los cortes se calculan con     │
│  $   │ ✓ 1 Paciente │  el ancho a la derecha del riel)                                 │
│  📦  │ ● 2 Motivo … │                                                                  │
└──────┴──────────────┴─────────────────────────────────────────────────────────────────┘
```

### Ficha longitudinal
```
┌ PEÑA MUÑOZ, José Ángel · CC 1032456789 · 52 a · M · ⚠ Penicilina ─────────────────────┐
│ Tel +57 300 000 0000 [WhatsApp]   Líneas: General · Peso   Etiquetas: HTA, GLP-1        │
│ Autorización de datos: firmada 02/10/2026 (AD-000031) · Imagen: uso clínico              │
│ [+ Historia nueva] [+ Evolución] [℞ Receta] [📅 Agendar] [$ Cobrar] [Documento ▾]        │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│ Resumen | Atenciones | Seguimiento | Fotos | Programa de peso | Estética | Documentos | Cobros │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│ LÍNEA DE TIEMPO                                            Ver [Todo ▾]                 │
│ 12/11/2026  Evolución #3 · Control de peso · 81bd·07aa            [Abrir PDF]           │
│ 12/11/2026  Receta R-000123                                       [Abrir PDF]           │
│ 05/11/2026  Valoración hidrolipoclasia · DIFERIR: primero programa de peso              │
│ 02/10/2026  Historia clínica · E66.0 Obesidad · ✅ íntegra (v3)    [Abrir PDF]          │
│ 02/10/2026  Autorización de tratamiento de datos · AD-000031      [Abrir PDF]           │
│ ANTECEDENTES (de la historia del 02/10/2026)    ALERGIAS ⚠ Penicilina (act. 12/11/2026) │
│ Personales: HTA… · Quirúrgicos: … · Medicación actual: …                                │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```
- En móvil, las pestañas pasan a una lista desplegable y las acciones a un menú «Acciones ▾».
- A 320 px, el nombre tiene prioridad (como la franja de hoy). Hay prueba.

### Seguimiento antropométrico
```
│ SEGUIMIENTO                                         [+ Medición] [⬇ Informe de seguimiento] │
│ Peso (kg)                 ┌─────────────────────────────┐   IMC   31,2 → 28,4  (−9 %)     │
│ 96 ●                       │ ●╲                          │   Cintura 104 → 96 cm            │
│ 88       ●──●──●  meta ‐ ‐ │    ●──●──●   ‐ ‐ ‐ 84 kg   │   ICC  0,98 → 0,94               │
│           oct   nov   dic  └─────────────────────────────┘   [Peso ▾] [Cintura] [Perímetros] │
│ Fecha      Peso  Talla IMC  Cint Cad  ICC  Abd  Flanco D/I  Muslo D/I  Brazo D/I  PA    %G │
│ 12/11/2026 88,0  176   28,4  96  102 0,94  98   …                                 128/82 —  │
```
- Gráficas con `CustomPainter` (sin dependencias) y colores derivados del tema, con contraste ≥ 3:1 para líneas y 4,5:1 para textos.

### Fotos y comparación
```
│ FOTOS · Consentimiento de imagen: uso clínico (CIM-000031, 02/10/2026)   [📷 Tomar fotos] │
│ Vista [Frontal ▾]     Comparar [02/10/2026 ▾]  con  [12/11/2026 ▾]      [⇆ Cortina]      │
│ ┌──────────────────┐ ┌──────────────────┐                                               │
│ │     (frontal)    │ │     (frontal)    │   Guía: hombros ─── ombligo ─── caderas       │
│ │    02/10/2026    │ │    12/11/2026    │   Diferencia de días: 41                      │
│ └──────────────────┘ └──────────────────┘                                               │
│ 02/10/2026  [frontal] [lat D] [lat I] [posterior] [detalle: abdomen]                     │
```
- **Tomar fotos** guía la secuencia de vistas. Después de cada foto aparece la guía de encuadre y la anterior en transparencia, con «Repetir» o «Aceptar».

### Programa de peso
```
│ PROGRAMA DE PESO · desde 02/10/2026 · activo                       [Editar plan] [⬇ Indicaciones] │
│ Meta  84 kg · cintura 90 cm · 02/04/2027      Hoy 88,0 kg (−8,3 %) · faltan 4 kg              │
│ ⓘ Recuerda: proteína suficiente y entrenamiento de fuerza para conservar masa muscular        │
│ Plan nutricional [plantilla «Déficit moderado» v2 ▾] …   Plan de ejercicio [plantilla ▾] …    │
│ GLP-1  Semaglutida SC semanal · INVIMA 2019M-0019473 · ⚠ indicación aprobada: DM2 (VERIFICAR) │
│        Contraindicaciones revisadas 02/10/2026 ✓ (0 absolutas · 1 precaución con nota)        │
│        Dosis  02/10 0,25 mg → 30/10 0,5 mg → [+ Cambio de dosis]                              │
│        Tolerancia  náuseas leves (30/10)   Eventos adversos  ninguno  [+ Registrar]           │
```

### Valoración para hidrolipoclasia
```
│ VALORACIÓN · Hidrolipoclasia (plantilla v1, aprobada 20/11/2026)        Paciente: 34 a ✓ │
│ 1 Candidato        IMC 26,1 (medición 12/11)  ·  ⚠ si > 30 (tu criterio)                 │
│   Zonas  [Abdomen inferior · pinzable 3 cm · elasticidad buena · flacidez 0] [+ zona]     │
│   Expectativas (•) Realistas ( ) No realistas   Nota [___________]                        │
│ 2 Contraindicaciones   Embarazo o lactancia (•)No ( )Sí   Anticoagulación (•)No ( )Sí  …  │
│ 3 Tamizaje         SCOFF 1/5 · negativo     BDDQ-AS · negativo                           │
│ 4 Resultado        ( ) Apto  ( ) No apto  (•) Diferir                                     │
│   Motivo* [Primero programa de peso ▾] [texto libre_____________]                         │
│                                                 [Sellar valoración en la historia]       │
```

### Registro de sesión
```
│ SESIÓN 2 de 4 · Hidrolipoclasia · 21/11/2026 10:30                                        │
│ ✓ Mayor de edad  ✓ Valoración apto (hasta 03/02/2027)  ✓ Consentimiento CI-000014         │
│ ⚠ Sin certificación registrada para «lipólisis por infiltración» (se registrará el aviso) │
│ Lista de verificación previa  ☑ Alergias ☑ Anticoagulación ☑ Embarazo ☑ Signos … (12/12)  │
│ Zona [Abdomen inferior ▾]  Componentes [del protocolo ▾] Volumen [___] mL                 │
│ Anestésico [Lidocaína 2 % ▾] Lote [L2345 · vence 03/2027 ✓] Volumen [10] mL               │
│            → 200 mg · 2,9 mg/kg (peso 69 kg, 12/11) · máximo del protocolo: [__] mg/kg     │
│ Equipo [________] Parámetros [____]   Duración [45] min   Eventos adversos [Ninguno ▾]     │
│ Insumos  Jeringa 10 mL × 2 (lote …)  [+]        → se descuentan del inventario al sellar  │
│ Indicaciones posteriores [de la plantilla…]   Control [28/11/2026]                        │
│                                                     [Sellar sesión en la historia]       │
```
- Si algo bloquea, el botón dice por qué («Falta el consentimiento firmado», «El lote L2345 venció el 01/11/2026»).

**Sesión en móvil (320 px):** una columna, un bloque plegable por paso (verificación, zona, anestésico, equipo, insumos, indicaciones) y el botón de sellar fijo abajo, con el motivo del bloqueo encima si lo hay:
```
┌──────────────────────────────┐
│ ← Sesión 2/4 · Hidrolipocl.  │
│ ✓ Apta ✓ Consent. ✓ ≥ 18     │
│ ▸ Verificación previa 12/12  │
│ ▾ Anestésico                 │
│   Lidocaína 2 % ▾            │
│   Lote L2345 · 03/2027 ✓     │
│   Volumen [10] mL            │
│   200 mg · 2,9 mg/kg ✓       │
│ ▸ Equipo  ▸ Insumos          │
│ [  Sellar sesión  ]          │
└──────────────────────────────┘
```

### Consentimiento con firma del paciente
```
│ CONSENTIMIENTO INFORMADO · Hidrolipoclasia · plan de 4 sesiones · CI-000014              │
│ ┌──────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ Procedimiento · Beneficios y alcance realista · Riesgos (frecuentes y graves) ·      │ │
│ │ Alternativas · Obligación de medio · Ruta de complicaciones · Póliza · Revocación    │ │
│ │ (texto de tu plantilla, desplazable)                                                 │ │
│ └──────────────────────────────────────────────────────────────────────────────────────┘ │
│ ☐ El paciente leyó el documento y resolvió sus dudas                                     │
│ Firma del paciente ┌──────────────── Firma aquí ────────────────┐   Médico: ✓ (tu firma) │
│                    └──────────────────────────────────────────────┘                      │
│                                                        [Firmar y guardar PDF]            │
```
- En tableta y celular, el lienzo ocupa el ancho completo. El PDF lleva las dos firmas, la fecha y la hora, la versión de la plantilla y la huella.

### Agenda
```
│ AGENDA   ‹  Hoy  ›  viernes 21/11/2026     [Día | Semana]     [+ Cita]   ⏰ Controles vencidos (7) │
│ 08:00 ┃ Primera vez · PEÑA MUÑOZ, José Á. · confirmada   [WhatsApp] [Ficha] [Atender] [$ Cobrar] │
│ 08:30 ┃ Control · TORRES RUIZ, Juan · agendada            [WhatsApp] …                          │
│ 09:00 ┃ ░░░░ Bloqueado: reunión ░░░░                                                            │
│ 10:30 ┃ Sesión hidrolipoclasia 2/4 · … · ✓ apta ✓ consentimiento                                │
│ Mañana: 3 citas sin recordatorio   PEÑA … 08:00 [Enviar]   TORRES … 08:30 [Enviar]   …        │
```
- **Semana:** una columna por día con bloques por tipo, distinguidos por color y por ícono, no solo por color.
- **Móvil:** solo la vista de día, deslizando entre días.
- **Atender** abre la historia nueva o la evolución, con el paciente cargado. **WhatsApp** abre `https://wa.me/57…?text=…` con el mensaje editable. Cada cita se puede exportar a `.ics`.

### Caja
```
│ CAJA · viernes 21/11/2026                         [+ Cobro] [Cierre del día] [Informes ▾] │
│ RC-000231  08:40  PEÑA MUÑOZ, José Á.  Consulta primera vez        80.000  Nequi    [Recibo] │
│ RC-000232  10:05  RÍOS …               Abono paquete 4 sesiones   440.000  Transfer. [Recibo] │
│ Sin recibo 10:45  …                    Sesión hidrolipoclasia (paquete 2/4) · saldo 2 sesiones │
│ Totales: efectivo 125.000 · transferencia 440.000 · Nequi 80.000 · Daviplata 0 · tarjeta 0     │
```
**Diálogo de cobro:**
```
┌ 💲 Cobro · PEÑA MUÑOZ, José Á. ────────────────────────────────────────────┐
│ [+ Servicio ▾]  Consulta de primera vez   1 ×  80.000            80.000    │
│                 Descuento [0] Motivo [______]                              │
│ Crédito disponible: valoración estética 70.000 (vence 05/12) [Aplicar]     │
│ Pagos  [Nequi ▾] [80.000] Ref. [____]   [+ Otro pago]                      │
│ Total 80.000 · Pagado 80.000 · Saldo 0                                     │
│                                   [Cancelar]  [Registrar y ver recibo]     │
└────────────────────────────────────────────────────────────────────────────┘
```
- **Cobro:** servicios del catálogo, descuento con motivo, crédito disponible por valoración abonable, abonos con medio y referencia, y saldo.
- **Informes:** mensual por servicio y por línea, volumen por técnica y exportación CSV.

### Inventario
```
│ INVENTARIO                         [+ Insumo] [+ Entrada]   ⚠ 2 bajo mínimo · ⏳ 1 vence en 30 días │
│ Lidocaína 2 % sin epinefrina · amp. 5 mL · INVIMA … · stock 14 (mín. 10) · 2 lotes            │
│ Jeringa 10 mL · ⚠ sin registro Invima · stock 40 (mín. 50)                                    │
│ Solución salina 0,9 % 500 mL · INVIMA … · lote S88 ⏳ vence 15/12/2026                          │
```

### Ajustes: consultorio, certificaciones y plantillas
```
│ AJUSTES   Consultorio | Certificaciones | Servicios y tarifas | Horario | Plantillas | Seguridad | Respaldo │
│ CONSULTORIO   Nombre [________]  Código de prestador (REPS) [__________]  NIT [__________]         │
│               Habilitación por servicio  Consulta externa medicina general [____] [+ servicio]     │
│               Póliza de complicaciones [aseguradora] [número] ( ) Sin póliza                       │
│ CERTIFICACIONES POR TÉCNICA                                                        [+ Agregar]     │
│   Lipólisis por infiltración / hidrolipoclasia · Entidad … · 10/06/2026 · vence 10/06/2031 ✓ [Soporte] │
│   Toxina botulínica · — · ⚠ sin certificación registrada                                           │
│ PLANTILLAS    Consentimiento hidrolipoclasia  v2 · aprobada 20/11/2026   [Editar] [Historial]      │
│               Autorización de datos           v1 · BORRADOR (sin aprobar) [Editar y aprobar]       │
```

### Modo presentación
```
│ Antes:  Firma y sello [ⓘ Por verificar]            Modo presentación: [ ○ ]   │
│ Después: Firma y sello                              Modo presentación: [ ● ]   │
```
- Un interruptor en la barra superior. Encendido, oculta los chips «Por verificar», las notas internas y los montos de la caja en las pantallas que ve el paciente. Se apaga solo al bloquear.

### Respaldo e importación (Ajustes)
```
│ RESPALDO     Último: 18/11/2026 10:12 · 412 pacientes · 1.284 fotos · 452 MB               │
│              [⬇ Respaldar ahora]  [⇪ Restaurar…]  [⇄ Paquete del equipo secundario]        │
│              Avisar cada [7] días · Espacio usado en este navegador: 0,5 GB de 40 GB       │
│              ✓ Almacenamiento persistente concedido                                        │
│ IMPORTAR PDF Resultado (38 archivos):  31 importadas · 4 ya estaban · 1 versión más nueva  │
│              ⚠ 1 alterada desde la evolución 2 (Historia_RIOS_…_v3.pdf)                    │
│              ✕ 1 no es de esta app (Factura.pdf)                                           │
```

### PDF nuevos (mismo estilo que hoy)
- **Informe de seguimiento (A4):**
  - encabezado y ficha del paciente iguales a la historia;
  - tabla de mediciones y gráficas de peso, IMC y cintura (`pw.Chart`), en escala de grises con el acento petróleo;
  - fotos, solo si las pides;
  - firma y sello.
- **Documentos (A4; recibo en A5):**
  - encabezado con logo y tus datos, título, número consecutivo, ficha del paciente y cuerpo;
  - firma del paciente cuando aplica, y tu firma y tu sello con los interruptores de hoy;
  - pie «historiasclinicas.net · CI-000014 · huella 3f9a·c21e · Pág. x de y»;
  - el recibo lleva en el cuerpo: «**Este documento no es una factura electrónica de venta.**» La nota sobre tus obligaciones ante la DIAN queda marcada VERIFICAR hasta que la revise tu contador.
- **Certificado, incapacidad, orden y remisión:** el mismo formulario corto para todos (plantilla, texto prellenado y editable, diagnóstico CIE-10 con el buscador de hoy, días o fechas cuando aplican) y vista previa del PDF real, como la receta.

---

## (d) Estructura de carpetas

```
lib/
  core/
    consultorio/                     # sin dependencias de interfaz
      config.dart                    # const consultorioHabilitado = bool.fromEnvironment(...)
      almacen/                       # base «historiasclinicas_consultorio»: registros y binarios,
                                     # transacciones, candado entre pestañas, persist(), migraciones
      seguridad/                     # llavero (sobre), derivación, AES-GCM con AAD, bloqueo
      modelos/                       # paciente, historia (índice), documento, medición, foto,
                                     # programa de peso, valoración, plantilla, sesión, cita,
                                     # servicio, cobro, paquete, insumo, lote, movimiento, configuración
      repositorio/                   # Coleccion<T>, índices en memoria, bitácora
      reglas/                        # bloqueos: menor de edad, no apto, consentimiento, lote, dosis,
                                     # certificación, contraindicaciones (puras, con pruebas por tabla)
      indice/                        # registrar historia, receta y documento; importación en lote
      respaldo/                      # .hcrespaldo y .hcpaquete: exportar, verificar, restaurar
      documentos/                    # PDF: informe, consentimiento, certificados, incapacidad,
                                     # orden, remisión, recibo; documento.json incrustado
      plantillas/                    # plantillas base (Dart const, marcadas BORRADOR). Los textos,
                                     # umbrales y protocolos se editan en la interfaz y se guardan
                                     # con versión en el almacén. Una técnica nueva (toxina, rellenos)
                                     # es un archivo de definición aquí, sin tocar el resto del módulo
      agenda/                        # disponibilidad, festivos, .ics, mensaje de WhatsApp
      caja/                          # totales, cierre, informes, CSV
      inventario/                    # existencias, vencimientos, FEFO
  features/
    consultorio/
      shell/                         # riel, menú lateral, búsqueda global, aviso de respaldo
      desbloqueo/                    # crear frase, desbloquear, recuperación, bloqueo por inactividad
      pacientes/  ficha/  seguimiento/  fotos/  peso/  estetica/  documentos/
      agenda/  caja/  inventario/  ajustes/  respaldo/  importacion/
      widgets/                       # gráficas, CampoMoneda, CampoCantidad, etiquetas neutras
test/consultorio/                    # unitarias y de widgets por subfase
tool/e2e/consultorio_offline.mjs     # flujo sin conexión con la bandera encendida
docs/FASE5.md, docs/fase5/           # este plan, resultados y capturas
```

**Archivos existentes que cambia la Fase 5.** Cada cambio va detrás de la bandera o no altera el comportamiento de hoy:

| Archivo | Cambio |
|---|---|
| `lib/app/router.dart` | `if (consultorioHabilitado)` usa las rutas del consultorio (5.0: `/ajustes`; después `/agenda`, `/pacientes`, `/pacientes/:id`, `/caja` e `/inventario`, con `initialLocation: '/agenda'` desde la 5.5). Apagada: las 3 rutas de hoy |
| `lib/features/historia/estado/historia_controller.dart` | Enganche en `guardado()` (sin esperar el resultado y sin lanzar errores, como IHCE) y `nuevaDesdePaciente()`. **5.1: no cambió**; el enganche quedó en la página, que tiene los bytes del PDF, y el prellenado usa `limpiar()` y `actualizar()` |
| `lib/features/historia/historia_page.dart` | Pasar los bytes del PDF al enganche. Cortes con el ancho disponible (`LayoutBuilder`), que sin riel es el de hoy. Con la bandera: «← Ficha» y aviso de versión más nueva en el índice. **5.1:** dentro de `if (consultorioHabilitado)`, registra lo que guarda (`registrarHistoriaGuardada`) y lo que abre (`alAbrirHistoria`, que avisa si el índice tiene una versión más nueva). La franja «← Ficha» va en el contenedor, no en la página |
| `lib/features/historia/secciones/seccion_evoluciones.dart`, `lib/core/models/evolucion.dart`, `lib/core/pdf/historia_pdf.dart`, `lib/core/presentacion/datos_historia.dart` | Solo si eliges 15 (a): «Próximo control» opcional en la evolución, con la bandera encendida. **5.1:** el campo del editor va dentro de `if (consultorioHabilitado)`; el modelo, la vista sellada y el PDF lo muestran si existe. `datos_historia.dart` no cambió |
| `lib/features/receta/estado/receta_controller.dart`, `lib/features/receta/receta_page.dart`, `lib/core/pdf/receta_pdf.dart` | Con la bandera: `receta.json` incrustado y registro en la ficha. **5.1:** `generarPdfReceta` recibe `adjuntos` (vacío: el PDF de siempre); la página los pasa y registra la receta dentro de `if (consultorioHabilitado)`; el provider del almacén de la receta elige el cifrado con la bandera |
| `lib/features/historia/estado/borrador_provider.dart` (en lugar de `lib/core/storage/borrador_store.dart` y `receta_store.dart`, que no cambian) | Con la bandera: borrador y receta en curso en el almacén cifrado (pregunta 6). **5.1:** los providers eligen `BorradorStoreConsultorio` y `RecetaStoreConsultorio` (subclases en `lib/features/consultorio/integracion/`) dentro de `if (consultorioHabilitado)` |
| `lib/core/pdf/lector_adjunto.dart`, `lib/core/pdf/adjuntos_pdf.dart` (nuevo) | **5.1:** función nueva `adjuntosConMarca` para leer `documento.json` y `receta.json` (lo demás no cambia) e `incrustarAdjuntos` para escribirlos |
| `lib/core/pdf/piezas_pdf.dart`, `lib/core/pdf/historia_pdf.dart` | Extraer ficha del paciente, cabecera de sección y encabezado de página, sin cambiar el PDF (prueba de regresión). **5.1: `piezas_pdf.dart` no cambió**; los documentos usan `datosMedicoPdf` y `bloqueFirmaPdf` tal como están |
| `lib/features/medico/medico_page.dart`, `lib/core/widgets/dialogo_firma.dart` (nuevo) | `DialogoFirma` pasa a `lib/core/widgets/` con título y textos como parámetros, sin cambiar cómo se ve el del médico. **5.1: no hizo falta**; la firma del paciente es un diálogo del consultorio con el `LienzoFirma` de siempre |
| `lib/core/widgets/campos.dart` | Variante neutra de `CampoEtiquetas` (sin el estilo de alergia). `CampoMoneda` y `CampoCantidad` van en archivos nuevos |
| `lib/core/archivos/archivos.dart`, `lib/core/archivos/archivos_web.dart`, `lib/core/archivos/archivos_stub.dart` | Elegir varios archivos, soltar varios y `capture` para la cámara. **5.1:** `elegirPdfs` y `escucharVariosSoltados`. **5.2:** `elegirFoto` (con `capture`) y `elegirPaquete`; `archivos.dart` no cambió |
| `tool/ihce/regla10.dart` | Aceptar el inventario de esta tabla y la carpeta `lib/features/consultorio/` (pregunta 8) |
| `tool/construir_web.sh`, `.github/workflows/ci.yml` | Carpeta de salida como parámetro, y un trabajo de CI que compila con la bandera encendida y corre el e2e del consultorio. **`pages.yml` no cambia** |
| `tool/e2e/historia_offline.mjs` | Paso nuevo: sin la bandera no existe la base del consultorio |

El código de IHCE (`lib/core/ihce/`, `lib/features/ihce/`) no cambia.

### Dependencias

**Ninguna nueva.** Todo sale de lo que ya está en `pubspec.yaml`:

| Necesidad | Con qué | Licencia |
|---|---|---|
| AES-256-GCM, PBKDF2 (WebCrypto) y Argon2id | `cryptography` ^2.9.0 (ya está, por IHCE) | Apache-2.0 |
| Llave no extraíble, `navigator.locks`, `navigator.storage.persist()`, IndexedDB con bytes, redimensionar la foto y quitar el EXIF (lienzo del navegador → JPEG) | `web` y `dart:js_interop` (ya están) | BSD-3 |
| ZIP del respaldo y del paquete | `archive` ^4.0.9 (ya está) | MIT |
| Gráficas en el PDF | `pdf` 3.12 (`pw.Chart`, ya está) | Apache-2.0 |
| Gráficas en pantalla | `CustomPainter` de Flutter | — |
| Huellas SHA-256 | `crypto` (ya está) | BSD-3 |

Si en la implementación algo exigiera un paquete nuevo (por ejemplo, `image` para procesar fotos fuera del lienzo del navegador), te lo pregunto antes, con su licencia y su peso.

---

## (e) Plan por subfases

**Cómo trabajo en todas las subfases:**
- Todo en la rama `claude/fase5-consultorio`, con el PR abierto hacia `main`. **Nunca hago push a `main`**, porque `pages.yml` publica en producción.
- **Antes de cada commit:** `dart format`, `flutter analyze` sin advertencias y `flutter test` en verde.
- **Al cerrar cada subfase:**
  - `./tool/construir_web.sh` compila, con y sin la bandera;
  - `tool/ihce/verificar.sh` en verde;
  - las e2e de siempre en verde, más la parte nueva de `tool/e2e/consultorio_offline.mjs`;
  - pruebas de **contraste** y de **320 px** de cada pantalla nueva;
  - `docs/FASE5.md` actualizado con lo hecho, las decisiones y las desviaciones;
  - capturas en `docs/fase5/` (escritorio 1440 px, móvil 390 px y 320 px).
- **Te muestro un resumen corto y las capturas, y me detengo hasta tu visto bueno.**

### 5.0 Cimientos
- La bandera `CONSULTORIO_ENABLED`, el contenedor y la navegación (solo lo construido hasta el momento).
- Almacén cifrado:
  - llavero en sobre, derivación (con la medición de PBKDF2 y Argon2id), AES-GCM con AAD;
  - colecciones, binarios, transacciones, candado entre pestañas, `persist()` y migraciones.
- Pantallas: crear frase, desbloquear, recuperar, bloqueo por inactividad y «Bloquear ahora».
- Respaldo: exportar, verificar y restaurar `.hcrespaldo`, aviso de vencimiento (con el texto de custodia) y bitácora.
- Guía para publicar la versión del consultorio (pregunta 2).
- **Pruebas de «bandera apagada = sitio de hoy»:**
  - configuración apagada por defecto;
  - el router tiene exactamente `/`, `/receta` y `/medico`, y `/pacientes` cae en la misma página de error que hoy;
  - el menú ⋮ y la barra de la historia tienen los mismos elementos que hoy, a 1920 y a 390 px;
  - con la bandera apagada no se abre ninguna base de IndexedDB del consultorio (se registra cada apertura, como se hace con las lecturas de secretos de IHCE);
  - `main.dart.js` compilado sin la bandera no contiene la marca del módulo;
  - en el e2e de siempre, `indexedDB.databases()` sigue vacío;
  - `pages.yml` no menciona `CONSULTORIO_ENABLED`.
- **Otras pruebas:**
  - cifrar y descifrar, y que un byte cambiado, otra AAD o una frase incorrecta fallen;
  - cambio de frase y recuperación con el código;
  - al bloquear, la app descarta la llave y ninguna operación del almacén funciona hasta desbloquear;
  - respaldo de ida y vuelta, y alteraciones detectadas (manifiesto, archivo, registro intercambiado, conteos);
  - contraste de los textos nuevos;
  - 320 px.
- **e2e:** crear frase, bloquear, desbloquear, respaldar y restaurar sin conexión, y que la compilación sin bandera no tenga nada del módulo.
- **Entrego:** capturas del desbloqueo, el respaldo y el aviso de respaldo vencido; la tabla de tiempos de PBKDF2 y Argon2id en tus equipos; la guía de publicación.

### 5.1 Pacientes
- Índice automático al finalizar la historia o descargar evoluciones. Si está bloqueado, la registra después.
- Importación en lote de PDF con el informe de resultados.
- Lista con búsqueda y filtros (última atención, línea, etiquetas, controles vencidos).
- Ficha longitudinal con línea de tiempo y «Abrir PDF».
- Historia, evolución y receta prellenadas desde la ficha. Aviso si se abre un PDF más viejo que el índice.
- Recetas con `receta.json` (bandera encendida).
- Autorización de tratamiento de datos, primer documento firmado. **Política de privacidad** en PDF para imprimir y exhibir en el consultorio (borrador para tu abogado). Unir fichas.
- **Pruebas:**
  - índice al sellar (revisión 1 y siguientes);
  - importación: íntegra, alterada desde *n*, dañada, ajena, duplicada, más nueva y divergente;
  - búsqueda sin tildes;
  - prellenado (sube `versionFormulario`);
  - la autorización firmada queda en la ficha, con su PDF y su huella;
  - rendimiento con 5.000 pacientes sintéticos.
- **e2e:** importar PDF de la Fase 4 (uno alterado), buscar, abrir la ficha, iniciar una evolución prellenada y verla en la línea de tiempo.
- **Entrego:** capturas de la lista, la ficha y el informe de importación; el resultado de rendimiento.

### 5.2 Seguimiento antropométrico y fotos
- Mediciones con IMC (`calcularImc`) e índice cintura-cadera, y gráficas con `CustomPainter`.
- Consentimiento de uso de imagen.
- Fotos cifradas: secuencia de vistas, guía de encuadre, foto anterior en transparencia, sin EXIF, miniaturas.
- Comparación lado a lado y cortina.
- Paquete del equipo secundario `.hcpaquete`.
- Informe de seguimiento en PDF (fotos solo si se piden).
- **Pruebas:**
  - cálculos;
  - sin consentimiento de imagen no hay fotos;
  - las fotos no entran al PDF de la historia ni al informe sin pedirlo;
  - EXIF eliminado;
  - foto cifrada en reposo;
  - paquete combinado sin duplicados;
  - informe en PDF.
- **e2e:** registrar mediciones, firmar el consentimiento de imagen, subir fotos (archivo de prueba), comparar y descargar el informe.
- **Entrego:** capturas del seguimiento, la comparación de fotos y la primera página del informe.

### 5.3 Programa de peso, valoración estética, consentimiento y sesiones
- **Programa de peso:**
  - meta, planes con plantillas y recordatorio de proteína y fuerza;
  - GLP-1 con catálogo, titulación, tolerancia y eventos adversos;
  - lista de contraindicaciones con bloqueo de las absolutas.
- **Valoración por plantilla declarativa (hidrolipoclasia):**
  - criterios, contraindicaciones y tamizajes;
  - resultado con motivo obligatorio y vigencia;
  - se sella como evolución.
- **Consentimiento informado** por plan de tratamiento, con firma del paciente, revocación y plantilla aprobada.
- **Sesión:**
  - lista de verificación previa, zonas, solución y anestésico con dosis en mg/kg;
  - lote y vencimiento escritos (un vencimiento pasado ya bloquea); el enlace con el inventario llega en la 5.7;
  - se sella como evolución.
- Certificaciones por técnica, con aviso.
- **Pruebas de reglas, por tabla:**
  - menor de 18 años;
  - «no apto» y «diferir»;
  - valoración vencida;
  - consentimiento faltante o revocado;
  - plantilla sin aprobar;
  - dosis por encima del máximo;
  - lote vencido;
  - contraindicación absoluta de GLP-1;
  - técnica sin certificación (aviso registrado).
- **e2e:** paciente → valoración → consentimiento firmado → sesión sellada (con una sesión bloqueada por consentimiento faltante y otra por lote vencido) → PDF de la historia con la evolución de la sesión.
- **Entrego:** capturas del programa de peso, la valoración, el consentimiento con firma y la sesión (escritorio, tableta y 320 px).

### 5.4 Documentos
- Certificado médico (general, laboral, deportivo y de asistencia), incapacidad (con los campos del Decreto 1427 de 2022), orden de laboratorio o imágenes con plantillas frecuentes, y remisión o interconsulta.
- Editor de plantillas con versiones.
- Numeración por tipo y anulación con motivo.
- **Pruebas:**
  - PDF de cada tipo, con `documento.json` incrustado y huella en el índice;
  - verificación al reabrir e importación en lote de documentos y recetas;
  - avisos de la incapacidad.
- **e2e:** un certificado y una orden con plantilla, descargados y reimportados.
- **Entrego:** capturas del formulario y la primera página de cada tipo de PDF.

### 5.5 Agenda
- Citas por tipo, duración y estado, con vista de día y de semana.
- Horario, bloqueos y festivos.
- WhatsApp con mensaje editable, lista de recordatorios del día siguiente y `.ics`.
- Desde la cita: ficha, atender y cobrar. Indicador de controles vencidos.
- **Pruebas:**
  - disponibilidad y cruces;
  - festivos;
  - estados;
  - URL de WhatsApp (codificación, número +57);
  - `.ics` válido y sin datos de salud;
  - no se agenda una sesión a un paciente no apto ni a un menor.
- **e2e:** agendar, cambiar estados, «Atender» con la historia prellenada y el enlace de WhatsApp interceptado (sin abrirlo).
- **Entrego:** capturas de la vista de día, la de semana y la de móvil.

### 5.6 Caja y paquetes
- Catálogo de servicios con tus tarifas iniciales.
- Cobros con medios de pago, abonos y saldo; paquetes con sesiones usadas y pendientes; crédito de la valoración abonable.
- Recibo PDF numerado con el aviso de que no es factura electrónica.
- Cierre diario e informe mensual por servicio y por línea, con CSV.
- Informe de volumen por técnica.
- **Pruebas:**
  - totales y saldos;
  - paquete agotado;
  - consecutivo sin saltos ni repetidos;
  - anulación (también la de un día cerrado);
  - día cerrado inmutable;
  - CSV.
- **e2e:** cobro con abono, paquete, recibo PDF (con el aviso de que no es factura) y cierre del día.
- **Entrego:** capturas de la caja, el cobro y el informe, y el recibo en PDF.

### 5.7 Inventario simple
- Insumos y lotes con stock mínimo, y entradas.
- Descuento automático al sellar la sesión. Sugerencia del lote que vence primero.
- Alertas de stock bajo y de vencimiento próximo. **Bloqueo de lote vencido o sin stock.**
- Registro Invima con aviso si falta (más visible en inyectables).
- **Pruebas:**
  - existencias por movimientos;
  - descuento al sellar;
  - lote vencido bloquea;
  - aviso sin registro Invima.
- **e2e:** entrada de un lote, sesión que lo descuenta y bloqueo con un lote vencido.
- **Entrego:** capturas del inventario con alertas.

### 5.8 Ajustes de presentación y cierre
- Notas «VERIFICAR» según tu respuesta a la pregunta 50, y modo presentación.
- Pulido de la navegación en escritorio y móvil.
- e2e completo sin conexión: paciente → valoración → consentimiento → sesión → cobro → respaldo.
- `docs/FASE5.md` con lo hecho, las decisiones y las desviaciones, y `README.md` con el estado y la estructura.
- **Pruebas:**
  - modo presentación (ningún «VERIFICAR» visible);
  - contraste de todo lo nuevo;
  - 320 px en cada pantalla.
- **Entrego:** el e2e completo en CI, las capturas finales y el README actualizado.

---

## Límites que conviene saber desde ya

- **Un navegador, un equipo.** Sin sincronización, el respaldo es lo único que te protege si el equipo se daña, se pierde o se borran los datos del sitio. Por eso es obligatorio y avisa.
- **Sin la frase ni el código de recuperación, los datos del consultorio no se pueden abrir.** Tampoco yo podría. Las historias sí se recuperan desde los PDF.
- **El cifrado protege el equipo apagado, perdido o curioseado; no un equipo comprometido.** Un programa malicioso en tu equipo podría ver lo que ves mientras está desbloqueado.
- **La cadena de huellas detecta alteraciones, pero no prueba la autoría** (igual que hoy).
- **La firma dibujada es una firma electrónica**, no una firma digital certificada (VERIFICAR su valor según el caso).
- **Las fotos y los datos de gestión no están en ningún PDF.** Su única custodia es el almacén y el respaldo.
- **No soy asesor legal.** Las plantillas de documentos y los textos normativos son borradores para que los revises tú y, idealmente, un abogado.

## Opciones para una Fase 6 (fuera de alcance)
- Varios usuarios con roles (auxiliar, recepción) y bitácora por usuario.
- Sincronización entre equipos o en la nube, cifrada de extremo a extremo.
- Recordatorios automáticos desde un servidor (WhatsApp Business API o SMS).
- Factura electrónica DIAN mediante un proveedor tecnológico, y RIPS (Resolución 2275 de 2023, VERIFICAR).
- Cámara en vivo con la guía encima (pregunta 21 b).
- Exportación al Registro Nacional de Procedimientos Médico-Estéticos, si el Proyecto de Ley 187 de 2026 se aprueba.
- Plantillas de toxina botulínica, rellenos (con el listado de sustancias modelantes permitidas de la Ley 2316) y bioestimuladores, según te certifiques.
- Envío de las valoraciones y sesiones a IHCE como RDA.

## Fuentes consultadas para este plan (todas VERIFICAR)
- Ley 2316 de 2023, texto compilado por Invima (arts. 1, 2, 4, 6 y 8 leídos): <https://normograma.invima.gov.co/normograma/compilacion/docs/ley_2316_2023.htm>; Decreto 545 de 2024 (según resultados de búsqueda, no leído): <https://normograma.invima.gov.co/normograma/compilacion/docs/decreto_0545_2024.htm>
- Proyecto de Ley 187 de 2026 Senado, ponencia para primer debate: páginas 28 a 32 de la Gaceta del Congreso 1571 de 2026, en una copia alojada por CER (un tercero; VERIFICAR contra la Gaceta oficial): <https://www.cerlatam.com/wp-content//uploads/2026/10/Ponencia-para-1er-debate-pl-187-1-1.pdf>. Resumen de CER: <https://www.cerlatam.com/?p=38709>
- Ley 1799 de 2016: <https://normograma.supersalud.gov.co/compilacion/docs/ley_1799_2016.htm>; Sentencia C-246 de 2017: <https://www.icbf.gov.co/cargues/avance/compilacion/docs/c-246_2017.htm>
- Decreto 1427 de 2022: <https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=191146>
- Invima, análogos de GLP-1 (único registro de semaglutida, OZEMPIC® 2019M-0019473, solo para diabetes tipo 2, según el resumen de búsqueda de esta página; fecha de la alerta por confirmar): <https://www.invima.gov.co/alertas-sanitarias/recomendaciones-de-uso-adecuado-de-medicamentos-con-el-grupo-de-principios-activos-analogos-a-glp-1>
- Invima, NAION con semaglutida: <https://www.invima.gov.co/alertas-sanitarias/riesgo-de-neuropatia-optica-isquemica-no-arterial-naion-con-el-uso-de-semaglutida>; alerta 090-2024 por semaglutida con vitamina B12: <https://www.invima.gov.co/biblioteca/alerta-sanitaria-semglutida-vitamina-b12-090-2024>
- Registro de Wegovy en Colombia, fuentes que se contradicen: <https://www.elcolombiano.com/inicio/medicamentos-aprobados-invima-bajar-peso-wegovy-ozempic-mounjaro-NA40373439> y Salud y Fármacos (<https://www.saludyfarmacos.org/?p=68782> o <https://www.saludyfarmacos.org/?p=68649>). Consultar el registro vigente en <https://consultaregistro.invima.gov.co>
- SCOFF, validación española (García-Campayo et al., *J Psychosom Res* 2005;59(2):51-55, doi:10.1016/j.jpsychores.2004.06.005)
- BDDQ-AS, traducción al español adaptada para Colombia (según el resultado de búsqueda; no leí el artículo completo): <https://scielo.isciii.es/pdf/cpil/v49n1/0376-7892-cpil-49-01-0035.pdf>. Instrumentos de dismorfia validados en español: <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5492913/>
- DIAN, servicios médicos excluidos de IVA y cirugía estética: <https://normograma.dian.gov.co/dian/compilacion/docs/oficio_dian_5421_2020.htm>
