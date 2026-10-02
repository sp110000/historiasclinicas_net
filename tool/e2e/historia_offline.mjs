// Prueba de extremo a extremo de la historia clínica en Chromium.
//
// Uso:
//   flutter build web --release --no-web-resources-cdn
//   python3 -m http.server 8765 --directory build/web &
//   node tool/e2e/historia_offline.mjs
//
// Variables: BASE_URL (http://localhost:8765/), OUT_DIR (build/e2e).
// Opcional: python3 + pikepdf para el caso "PDF alterado" y para inspeccionar
// lo que guarda cada PDF (médico, autores e imágenes).
//
// Recorre, SIN CONEXIÓN: validación, llenado completo (edad e IMC
// calculados), ir a la receta y volver, configurar los datos del médico
// (firma dibujada con el ratón, sello y logo subidos), finalizar y guardar
// el PDF, agregar una evolución, descargar la v2, reabrirla, detectar un PDF
// alterado y rechazar un PDF ajeno. Con conexión: recuperación del borrador
// al recargar. Falla si hay peticiones fuera del sitio.

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const BASE = process.env.BASE_URL ?? 'http://localhost:8765/';
const OUT = path.resolve(process.env.OUT_DIR ?? 'build/e2e');
const AQUI = path.dirname(fileURLToPath(import.meta.url));
fs.mkdirSync(OUT, { recursive: true });

const informe = { externas: [], fallidas: [], erroresConsola: [], pasos: [] };
const consola = [];
let paginaActual;
const paso = (t) => {
  informe.pasos.push(t);
  console.log('✓', t);
};
const alFallar = async (e) => {
  console.error('✗ Falló la prueba:', e.message);
  console.error('Últimos mensajes de consola:\n  ' + consola.slice(-25).join('\n  '));
  if (paginaActual) await paginaActual.screenshot({ path: path.join(OUT, 'ERROR.png') }).catch(() => {});
  process.exit(1);
};
process.on('unhandledRejection', alFallar);
process.on('uncaughtException', alFallar);

const browser = await chromium.launch();

async function nuevaPagina({ ancho = 1440, alto = 1000, sinRed = true, initScript } = {}) {
  const context = await browser.newContext({
    acceptDownloads: true,
    viewport: { width: ancho, height: alto },
    locale: 'es-CO',
    timezoneId: 'America/Bogota',
  });
  if (initScript) await context.addInitScript(initScript);
  context.on('request', (r) => {
    const u = r.url();
    if (!u.startsWith(BASE) && !u.startsWith('blob:') && !u.startsWith('data:')) informe.externas.push(u);
  });
  context.on('requestfailed', (r) => {
    // Recargar sin red falla por diseño hasta la Fase 4 (service worker).
    if (!r.url().startsWith(BASE) || !sinRed) informe.fallidas.push(`${r.url()} ${r.failure()?.errorText}`);
  });
  const page = await context.newPage();
  page.on('console', (m) => {
    consola.push(`[${m.type()}] ${m.text()}`);
    if (m.type() === 'error') informe.erroresConsola.push(m.text());
  });
  page.on('pageerror', (e) => {
    consola.push(`[pageerror] ${e.message}`);
    informe.erroresConsola.push(e.message);
  });
  paginaActual = page;
  await cargar(page);
  if (sinRed) await context.setOffline(true);
  return { context, page };
}

async function cargar(page) {
  await page.goto(BASE);
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60000 });
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
  // "Formular receta" en escritorio; "Receta" en la barra inferior del móvil.
  await page.getByRole('button', { name: /receta/i }).first().waitFor({ timeout: 30000 });
  await page.waitForLoadState('networkidle');
}

const boton = (page, nombre) => page.getByRole('button', { name: nombre }).first();
// Flutter expone los textos en el árbol semántico (span o aria-label) con
// tamaño cero: se comprueba que existan, no que sean "visibles".
const texto = (page, t) => {
  const l = page
    .getByText(t, { exact: false })
    .or(page.locator(`flt-semantics[aria-label*="${t.replaceAll('"', '\\"')}"]`))
    .first();
  return { waitFor: (o = {}) => l.waitFor({ state: 'attached', ...o }) };
};
// El nombre accesible puede incluir la pista ("Motivo de consulta * En
// palabras del paciente"): se busca por el comienzo de la etiqueta.
const comienzo = (t) => new RegExp('^' + t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
const campo = (page, etiqueta) => page.getByRole('textbox', { name: comienzo(etiqueta) }).first();

// Flutter necesita un fotograma para enfocar el campo nuevo: se espera un
// instante tras el clic (una persona nunca escribe en 0 ms). Si el campo
// estaba fuera de la pantalla, el desplazamiento puede robar ese fotograma:
// se comprueba lo escrito y se reintenta con más calma.
async function escribir(page, etiqueta, valor) {
  const c = campo(page, etiqueta);
  for (let intento = 0; intento < 3; intento++) {
    await c.scrollIntoViewIfNeeded();
    await page.waitForTimeout(150 + intento * 300);
    await c.click();
    await page.waitForTimeout(150 + intento * 300);
    await c.fill(valor);
    await page.waitForTimeout(100);
    if ((await page.evaluate(() => document.activeElement?.value)) === valor) return;
  }
  throw new Error(`No se pudo escribir "${valor}" en "${etiqueta}"`);
}

// Para campos con máscara (fechas): se teclea como lo haría una persona.
async function teclear(page, etiqueta, valor) {
  await campo(page, etiqueta).click();
  await page.waitForTimeout(200);
  await page.keyboard.type(valor, { delay: 30 });
  await page.waitForTimeout(100);
}

// Los ChoiceChip de Flutter se exponen como casillas (role=checkbox).
async function elegir(page, etiqueta) {
  for (const rol of ['checkbox', 'radio', 'button']) {
    const l = page.getByRole(rol, { name: etiqueta, exact: true });
    if (await l.count()) return l.first().click();
  }
  return page.getByText(etiqueta, { exact: true }).first().click();
}

async function captura(page, nombre) {
  await page.waitForTimeout(450);
  await page.screenshot({ path: path.join(OUT, nombre) });
}

async function descargar(page, accion) {
  const [d] = await Promise.all([page.waitForEvent('download', { timeout: 30000 }), accion()]);
  const destino = path.join(OUT, d.suggestedFilename());
  await d.saveAs(destino);
  return destino;
}

async function abrirArchivo(page, ruta) {
  const [selector] = await Promise.all([
    page.waitForEvent('filechooser'),
    boton(page, 'Abrir historia existente').click(),
  ]);
  await selector.setFiles(ruta);
}

// Resumen del PDF con pikepdf (null si no está disponible).
function inspeccionar(ruta) {
  try {
    const salida = execFileSync('python3', [path.join(AQUI, 'inspeccionar_pdf.py'), ruta], { stdio: 'pipe' });
    return JSON.parse(salida.toString());
  } catch (e) {
    if (String(e.stderr ?? '').includes('pikepdf')) {
      console.log('  (sin python3/pikepdf: no se inspecciona el PDF)');
      return null;
    }
    throw e;
  }
}

// El lienzo de la firma: su nodo semántico tiene el tamaño del área.
async function areaDeFirma(page) {
  const nodo = page
    .locator('flt-semantics[aria-label="Área para dibujar la firma"]')
    .or(page.locator('flt-semantics:has(> span:text-is("Área para dibujar la firma"))'))
    .first();
  await nodo.waitFor({ state: 'attached' });
  const caja = await nodo.boundingBox();
  if (!caja || caja.width < 100) throw new Error(`Área de firma no encontrada: ${JSON.stringify(caja)}`);
  return caja;
}

// Una firma con bucles y una rúbrica, trazada como lo haría una persona.
async function dibujarFirma(page, caja) {
  const p = (fx, fy) => [caja.x + caja.width * fx, caja.y + caja.height * fy];
  const trazo = async (puntos) => {
    await page.mouse.move(...p(...puntos[0]));
    await page.mouse.down();
    for (const pt of puntos.slice(1)) await page.mouse.move(...p(...pt), { steps: 2 });
    await page.mouse.up();
  };
  const curva = [];
  for (let i = 0; i <= 90; i++) {
    const t = i / 90;
    curva.push([
      0.12 + 0.62 * t + 0.035 * Math.sin(2 * Math.PI * 5 * t),
      0.5 - 0.2 * Math.sin(2 * Math.PI * 2.5 * t + 0.5) * (1 - 0.35 * t) - 0.06 * Math.cos(2 * Math.PI * 5 * t),
    ]);
  }
  await trazo(curva);
  await trazo([[0.14, 0.8], [0.35, 0.76], [0.6, 0.74], [0.84, 0.7]]);
  await trazo([[0.78, 0.3], [0.8, 0.38]]);
}

async function subirImagen(page, ruta) {
  const [selector] = await Promise.all([
    page.waitForEvent('filechooser'),
    boton(page, 'Subir imagen').click(),
  ]);
  await selector.setFiles(ruta);
}

async function irASeccion(page, nombre) {
  await page.getByRole('button', { name: nombre }).first().click().catch(() => {});
  await page.waitForTimeout(450);
}

// ─────────────── 1. Historia nueva, sin conexión ───────────────
let v1;
let v2;
{
  const { context, page } = await nuevaPagina({
    initScript: () => {
      delete window.showOpenFilePicker;
      delete window.showSaveFilePicker;
    },
  });
  await captura(page, '01_historia_vacia.png');

  // Validación al finalizar con el formulario vacío.
  await boton(page, 'Imprimir / Guardar PDF').click();
  await page.getByText('Finalizar y guardar PDF', { exact: true }).first().click();
  await texto(page, 'Faltan datos para finalizar').waitFor();
  paso('Validación: lista lo que falta para finalizar');
  await captura(page, '02_faltan_datos.png');
  await page.getByRole('button', { name: /^Ir a/ }).click();

  // Paciente.
  await escribir(page, 'Primer apellido *', 'Peña');
  await escribir(page, 'Segundo apellido', 'Muñoz');
  await escribir(page, 'Nombres *', 'José Ángel');
  await escribir(page, 'Número de documento *', '1032456789');
  await teclear(page, 'Fecha de nacimiento *', '15031990');
  await elegir(page, 'Femenino');
  await escribir(page, 'Teléfono', '300 123 4567');
  await texto(page, '36 años').waitFor();
  paso('Edad calculada a la fecha de la atención: 36 años');

  // Motivo.
  await escribir(page, 'Motivo de consulta *', 'Dolor de garganta y fiebre');
  await escribir(page, 'Enfermedad actual *', 'Odinofagia y fiebre de 2 días de evolución, 38,5 °C.');

  // Antecedentes: alergias como etiquetas.
  const alergia = campo(page, 'Alergia (medicamento, alimento, otro)');
  await alergia.click();
  await alergia.fill('Penicilina');
  await page.keyboard.press('Enter');
  await escribir(page, 'Medicación actual', 'Levotiroxina 50 µg/día');

  // Signos vitales e IMC.
  await escribir(page, 'PA sistólica', '118');
  await escribir(page, 'PA diastólica', '76');
  await escribir(page, 'FC', '92');
  await escribir(page, 'Temperatura', '38,5');
  await escribir(page, 'SpO₂', '97');
  await escribir(page, 'Peso', '64,5');
  await escribir(page, 'Talla', '162');
  await texto(page, '24,6 kg/m² · Normal').waitFor();
  paso('IMC calculado: 24,6 kg/m² · Normal');

  // Examen y diagnóstico.
  await escribir(page, 'Hallazgos del examen físico', 'Faringe eritematosa con exudado.');
  await boton(page, 'Agregar diagnóstico').click();
  await escribir(page, 'Diagnóstico *', 'Faringitis aguda');
  await escribir(page, 'CIE-10', 'J02.9');
  await escribir(page, 'Plan terapéutico', 'Manejo sintomático. Control en 7 días.');
  await captura(page, '03_historia_llena.png');

  // Receta: precarga y volver conserva lo escrito.
  await boton(page, 'Formular receta').click();
  await texto(page, 'PEÑA MUÑOZ, José Ángel').waitFor();
  await texto(page, 'J02.9 Faringitis aguda').waitFor();
  await captura(page, '04_receta_precarga.png');
  await page.getByRole('button', { name: 'Volver a la historia' }).last().click();
  await texto(page, '24,6 kg/m² · Normal').waitFor();
  paso('Receta: precarga paciente y diagnóstico; al volver se conserva todo');

  // Al finalizar sin datos del médico, la app ofrece configurarlos.
  await texto(page, 'Configura tus datos de médico').waitFor();
  await boton(page, 'Imprimir / Guardar PDF').click();
  await page.getByText('Finalizar y guardar PDF', { exact: true }).first().click();
  await texto(page, 'Aún no configuraste tus datos de médico').waitFor();
  await page.getByRole('button', { name: 'Configurar ahora' }).last().click();
  await texto(page, 'Datos profesionales').waitFor();
  await escribir(page, 'Nombre completo *', 'Dra. Ana Pérez Gómez');
  await escribir(page, 'Especialidad', 'Medicina interna');
  await escribir(page, 'Registro profesional *', 'RM 54321');
  await escribir(page, 'Nombre del consultorio o institución', 'Consultorio Salud Plena');
  await escribir(page, 'Dirección', 'Cra. 15 # 93-60, cons. 402');
  await escribir(page, 'Ciudad', 'Bogotá');
  await escribir(page, 'Teléfono', '601 555 0101');
  await texto(page, 'Guardado en este navegador').waitFor();

  // Firma dibujada con el ratón.
  await boton(page, 'Dibujar firma').click();
  await texto(page, 'Dibuja tu firma').waitFor();
  await page.waitForTimeout(400);
  const caja = await areaDeFirma(page);
  await dibujarFirma(page, caja);
  await captura(page, 'm1_firma_dibujada.png');
  await page.getByRole('button', { name: 'Usar esta firma' }).click();
  await boton(page, 'Dibujar de nuevo').waitFor();

  // Sello fotografiado sobre papel gris (se le quita el fondo) y logo.
  await subirImagen(page, path.join(AQUI, 'fixtures', 'sello_foto.jpg'));
  await page.getByRole('button', { name: 'Reemplazar con imagen' }).nth(1).waitFor();
  await subirImagen(page, path.join(AQUI, 'fixtures', 'logo.png'));
  await page.getByRole('button', { name: 'Reemplazar con imagen' }).nth(2).waitFor();
  await captura(page, 'm2_datos_medico.png');
  await page.mouse.move(700, 600);
  await page.mouse.wheel(0, 5000);
  await captura(page, 'm3_vista_previa_medico.png');
  paso('Datos del médico: firma dibujada, sello sin fondo y logo, sin conexión');

  await page.getByRole('button', { name: 'Volver a la historia' }).first().click();
  await boton(page, 'Editar datos del médico').waitFor({ state: 'attached' });
  await irASeccion(page, 'Firma y sello');
  await captura(page, 'm4_firma_en_historia.png');

  // Finalizar y guardar (ya no pregunta por el médico).
  await boton(page, 'Imprimir / Guardar PDF').click();
  await page.getByText('Finalizar y guardar PDF', { exact: true }).first().click();
  await texto(page, 'Finalizar y guardar la historia').waitFor();
  v1 = await descargar(page, () =>
    page.getByRole('button', { name: 'Finalizar y guardar PDF' }).last().click(),
  );
  await texto(page, 'Historia abierta · ').waitFor();
  await texto(page, 'Integridad verificada').waitFor();
  paso(`Historia finalizada y sellada sin conexión → ${path.basename(v1)}`);
  const i1 = inspeccionar(v1);
  if (i1) {
    if (i1.medico?.nombre !== 'Dra. Ana Pérez Gómez' || i1.medico?.registro !== 'RM 54321') {
      throw new Error(`Médico no guardado en historia.json: ${JSON.stringify(i1.medico)}`);
    }
    if (i1.recursos !== 3 || !i1.recursosCorrectos) throw new Error(`Recursos: ${JSON.stringify(i1)}`);
    const sv = i1.signos ?? {};
    if (sv.paSistolica !== 118 || sv.paDiastolica !== 76 || sv.peso !== 64.5) {
      throw new Error(`Signos vitales guardados: ${JSON.stringify(sv)}`);
    }
    // Logo en el encabezado de cada página; firma y sello al final. Cada
    // imagen se guarda una sola vez aunque se dibuje en varias páginas.
    const pags = i1.imagenesPorPagina;
    if (pags.some((n) => n < 1) || pags.at(-1) < 3 || i1.imagenesUnicas !== 3) {
      throw new Error(`Imágenes por página ${pags}, únicas ${i1.imagenesUnicas}`);
    }
    paso(`PDF v1: signos, médico, firma, sello y logo (${pags.length} págs., 3 imágenes sin repetir)`);
  }
  await page.mouse.wheel(0, -5000);
  await captura(page, '05_historia_abierta.png');

  // Agregar evolución y descargar v2.
  await boton(page, 'Agregar evolución').click();
  await escribir(page, 'Nueva evolución *', 'Afebril. Mejoría de la odinofagia. Continúa manejo.');
  await captura(page, '06_evolucion_nueva.png');
  await boton(page, 'Descargar historia actualizada').click();
  v2 = await descargar(page, () =>
    page.getByText('Guardar como nueva versión (_v2)', { exact: true }).first().click(),
  );
  await texto(page, 'Integridad verificada (2 sellos encadenados)').waitFor();
  paso(`Evolución sellada y v2 descargada → ${path.basename(v2)}`);
  const i2 = inspeccionar(v2);
  if (i2) {
    const autor = i2.autores[0];
    if (autor?.nombre !== 'Dra. Ana Pérez Gómez' || !autor.firma || !autor.sello || autor.logo) {
      throw new Error(`Autor de la evolución: ${JSON.stringify(autor)}`);
    }
    if (i2.recursos !== 3 || i2.imagenesUnicas !== 3) {
      throw new Error(`Las imágenes se duplicaron: ${i2.recursos} / ${i2.imagenesUnicas}`);
    }
    paso('PDF v2: la evolución lleva su autor con firma y sello, sin duplicar imágenes');
  }

  // Reabrir v2 desde cero.
  await boton(page, 'Cerrar historia').click();
  await abrirArchivo(page, v2);
  await texto(page, 'Evolución 1 ·').waitFor();
  await texto(page, 'Integridad verificada (2 sellos encadenados)').waitFor();
  paso('v2 reabierta: evolución sellada e integridad verificada');
  await captura(page, '07_v2_reabierta.png');
  await irASeccion(page, 'Evoluciones');
  await texto(page, 'Dra. Ana Pérez Gómez · Registro profesional RM 54321').waitFor();
  paso('v2 reabierta: cada evolución muestra quién la firmó');
  await captura(page, 'm5_evolucion_con_autor.png');

  // PDF alterado fuera de la app (requiere pikepdf).
  const alterado = path.join(OUT, 'Historia_alterada.pdf');
  let hayPikepdf = true;
  try {
    execFileSync('python3', [path.join(AQUI, 'alterar_pdf.py'), v2, alterado, '1'], { stdio: 'pipe' });
  } catch {
    hayPikepdf = false;
    console.log('  (sin python3/pikepdf: se omite el caso "PDF alterado")');
  }
  if (hayPikepdf) {
    await boton(page, 'Cerrar historia').click();
    await abrirArchivo(page, alterado);
    await texto(page, 'Se detectaron alteraciones desde la evolución 1').waitFor();
    await texto(page, 'No coincide').waitFor();
    paso('PDF alterado: se detecta y se marca la evolución que no coincide');
    await captura(page, '08_pdf_alterado.png');
  }

  // PDF ajeno.
  const ajenoPage = await context.newPage();
  await ajenoPage.setContent('<h1>Documento cualquiera</h1>');
  const ajeno = path.join(OUT, 'pdf_ajeno.pdf');
  await ajenoPage.pdf({ path: ajeno });
  await ajenoPage.close();
  await boton(page, 'Cerrar historia').click();
  await abrirArchivo(page, ajeno);
  await texto(page, 'No se pudo abrir la historia').waitFor();
  paso('PDF ajeno: mensaje claro y opción de empezar una historia nueva');
  await boton(page, 'Empezar historia nueva').click();
  await context.close();
}

// ─────────────── 2. Borrador: se recupera al recargar ───────────────
{
  const { context, page } = await nuevaPagina({ sinRed: false });
  await escribir(page, 'Primer apellido *', 'Gómez');
  await escribir(page, 'Nombres *', 'Lucía');
  await page.waitForTimeout(1200);
  await cargar(page);
  await texto(page, 'Se recuperó el borrador').waitFor();
  // Flutter copia el valor al <input> del árbol semántico al enfocarlo.
  await campo(page, 'Primer apellido *').click();
  await page.waitForTimeout(200);
  const apellido = await page.evaluate(() => document.activeElement?.value);
  if (apellido !== 'Gómez') throw new Error(`Borrador no restaurado: "${apellido}"`);
  paso('Borrador: al recargar la pestaña se recupera lo escrito');
  await captura(page, '09_borrador_recuperado.png');
  await context.close();
}

// ─────────────── 3. Móvil: historia abierta ───────────────
{
  const { context, page } = await nuevaPagina({
    ancho: 390,
    alto: 844,
    initScript: () => {
      delete window.showOpenFilePicker;
      delete window.showSaveFilePicker;
    },
  });
  const [selector] = await Promise.all([
    page.waitForEvent('filechooser'),
    (async () => {
      await page.getByRole('button', { name: 'Más opciones' }).click();
      await page.getByText('Abrir historia existente', { exact: true }).first().click();
    })(),
  ]);
  await selector.setFiles(v2);
  await texto(page, 'Historia abierta · ').waitFor();
  paso('Móvil: abrir una historia desde el menú');
  await captura(page, '10_movil_abierta.png');
  await context.close();
}

await browser.close();
informe.externas = [...new Set(informe.externas)];
fs.writeFileSync(path.join(OUT, 'informe.json'), JSON.stringify(informe, null, 2));
console.log('\nPeticiones fuera del sitio:', informe.externas.length ? informe.externas : 'ninguna');
console.log('Peticiones fallidas:', informe.fallidas.length ? informe.fallidas : 'ninguna');
console.log('Errores de consola:', informe.erroresConsola.length ? informe.erroresConsola : 'ninguno');
if (informe.externas.length || informe.fallidas.length || informe.erroresConsola.length) process.exit(1);
