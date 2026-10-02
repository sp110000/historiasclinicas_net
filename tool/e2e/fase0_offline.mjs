// Prueba de extremo a extremo de la Fase 0 en Chromium, SIN CONEXIÓN.
//
// Uso:
//   flutter build web --release --no-web-resources-cdn
//   python3 -m http.server 8765 --directory build/web &
//   node tool/e2e/fase0_offline.mjs
//
// Variables: BASE_URL (por defecto http://localhost:8765/), OUT_DIR
// (por defecto build/e2e). Requiere el paquete `playwright` de Node.
//
// Escenario A: navegador sin API de acceso a archivos (Firefox, Safari):
//   selector clásico y descarga normal.
// Escenario B: API de acceso a archivos simulada (Chrome y Edge): guardar
//   con "Guardar como…", sobrescribir el mismo archivo y reabrirlo.

import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const BASE = process.env.BASE_URL ?? 'http://localhost:8765/';
const OUT = path.resolve(process.env.OUT_DIR ?? 'build/e2e');
fs.mkdirSync(OUT, { recursive: true });

const informe = { externas: [], fallidas: [], erroresConsola: [], pasos: [] };
const consola = [];
let paginaActual;
const alFallar = async (e) => {
  console.error('✗ Falló la prueba:', e.message);
  console.error('Últimos mensajes de consola:\n  ' + consola.slice(-25).join('\n  '));
  if (paginaActual) await paginaActual.screenshot({ path: path.join(OUT, 'ERROR.png') }).catch(() => {});
  process.exit(1);
};
process.on('unhandledRejection', alFallar);
process.on('uncaughtException', alFallar);
const paso = (texto) => {
  informe.pasos.push(texto);
  console.log('✓', texto);
};

const browser = await chromium.launch();

async function nuevaPagina(initScript) {
  const context = await browser.newContext({
    acceptDownloads: true,
    viewport: { width: 1280, height: 900 },
    deviceScaleFactor: 1,
    locale: 'es-CO',
    timezoneId: 'America/Bogota',
  });
  if (initScript) await context.addInitScript(initScript);
  context.on('request', (r) => {
    const u = r.url();
    if (!u.startsWith(BASE) && !u.startsWith('blob:') && !u.startsWith('data:')) {
      informe.externas.push(u);
    }
  });
  context.on('requestfailed', (r) =>
    informe.fallidas.push(`${r.url()} ${r.failure()?.errorText}`),
  );
  const page = await context.newPage();
  page.on('console', (m) => {
    consola.push(`[${m.type()}] ${m.text()}`);
    if (m.type() === 'error') informe.erroresConsola.push(m.text());
  });
  page.on('pageerror', (e) => consola.push(`[pageerror] ${e.message}`));
  paginaActual = page;
  await page.goto(BASE);
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60000 });
  // Activa el árbol de accesibilidad de Flutter para localizar botones.
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
  await boton(page, 'Finalizar y guardar PDF').waitFor({ timeout: 30000 });
  // La app precarga lo que necesita (fuentes del PDF); se espera a que termine.
  await page.waitForLoadState('networkidle');
  // A partir de aquí, sin red.
  await context.setOffline(true);
  return { context, page };
}

const boton = (page, nombre) => page.getByRole('button', { name: nombre, exact: false }).first();
const texto = (page, t) => page.getByText(t, { exact: false }).first();

async function captura(page, nombre) {
  await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(OUT, nombre), fullPage: true });
}

async function descargar(page, accion) {
  const [descarga] = await Promise.all([page.waitForEvent('download'), accion()]);
  const destino = path.join(OUT, descarga.suggestedFilename());
  await descarga.saveAs(destino);
  return destino;
}

async function abrirArchivo(page, ruta) {
  const [selector] = await Promise.all([
    page.waitForEvent('filechooser'),
    boton(page, 'Abrir historia existente').click(),
  ]);
  await selector.setFiles(ruta);
}

async function nuevaHistoria(page) {
  await boton(page, 'Nueva historia').click();
  await boton(page, 'Continuar').click();
  await boton(page, 'Finalizar y guardar PDF').waitFor();
}

async function escribirEvolucion(page, contenido) {
  const campo = page.getByRole('textbox', { name: 'Nueva evolución' });
  await campo.click();
  await campo.fill(contenido);
  await boton(page, 'Agregar evolución').click();
}

// ─────────────── Escenario A: selector clásico y descarga ───────────────
{
  const { context, page } = await nuevaPagina(() => {
    delete window.showOpenFilePicker;
    delete window.showSaveFilePicker;
  });
  await captura(page, 'A1_historia_nueva.png');

  const v1 = await descargar(page, () => boton(page, 'Finalizar y guardar PDF').click());
  await texto(page, 'Historia abierta').waitFor();
  paso(`A: historia finalizada sin conexión → ${path.basename(v1)}`);
  await captura(page, 'A2_historia_sellada.png');

  await nuevaHistoria(page);
  await abrirArchivo(page, v1);
  await texto(page, 'revisión 1').waitFor();
  paso('A: PDF reabierto sin conexión, datos leídos del adjunto');

  await escribirEvolucion(
    page,
    'Afebril. Mejoría de la odinofagia. Continúa tratamiento sintomático.',
  );
  await captura(page, 'A3_evolucion_nueva.png');
  const v2 = await descargar(page, () => boton(page, 'Descargar historia actualizada').click());
  paso(`A: versión actualizada descargada → ${path.basename(v2)}`);

  await nuevaHistoria(page);
  await abrirArchivo(page, v2);
  await texto(page, 'Evolución 1 ·').waitFor();
  await texto(page, 'sellada').waitFor();
  paso('A: v2 reabierta: la evolución aparece sellada');
  await captura(page, 'A4_reabierta_v2.png');

  // PDF ajeno: generado por Chromium ("imprimir a PDF"), sin adjunto.
  const ajenoPage = await context.newPage();
  await ajenoPage.setContent('<h1>Documento cualquiera</h1><p>Sin datos de la app.</p>');
  const ajeno = path.join(OUT, 'pdf_ajeno.pdf');
  await ajenoPage.pdf({ path: ajeno });
  await ajenoPage.close();
  await nuevaHistoria(page);
  await abrirArchivo(page, ajeno);
  await texto(page, 'No se pudo abrir la historia').waitFor();
  paso('A: PDF ajeno → mensaje claro y opción de empezar historia nueva');
  await captura(page, 'A5_error_pdf_ajeno.png');
  await boton(page, 'Empezar historia nueva').click();
  await context.close();
}

// ─────────────── Escenario B: API de acceso a archivos ───────────────
{
  const { context, page } = await nuevaPagina(() => {
    // Disco simulado: nombre → Blob.
    const disco = (window.__disco = {});
    window.__escrituras = 0;
    const manejador = (nombre) => ({
      kind: 'file',
      name: nombre,
      async getFile() {
        return new File([disco[nombre]], nombre, { type: 'application/pdf' });
      },
      async createWritable() {
        const partes = [];
        return {
          async write(d) { partes.push(d); },
          async close() {
            disco[nombre] = new Blob(partes, { type: 'application/pdf' });
            window.__escrituras++;
          },
        };
      },
      async requestPermission() { return 'granted'; },
    });
    window.showSaveFilePicker = async (o) => manejador(o.suggestedName);
    window.showOpenFilePicker = async () => [manejador(window.__abrir)];
  });

  await boton(page, 'Finalizar y guardar PDF').click();
  await texto(page, 'Historia abierta').waitFor();
  const nombre = 'Historia_PENA_1032456789.pdf';
  await boton(page, `Sobrescribir ${nombre}`).waitFor();
  paso('B: guardado con "Guardar como…"; se ofrece sobrescribir el mismo archivo');

  await escribirEvolucion(page, 'Control: paciente asintomático. Alta.');
  await boton(page, `Sobrescribir ${nombre}`).click();
  await page.waitForFunction(() => window.__escrituras === 2);
  paso('B: el mismo archivo se sobrescribió con la versión actualizada');

  await nuevaHistoria(page);
  await page.evaluate((n) => (window.__abrir = n), nombre);
  await boton(page, 'Abrir historia existente').click();
  await texto(page, 'se puede sobrescribir').waitFor();
  await texto(page, 'Evolución 1 ·').waitFor();
  paso('B: reabierto con el selector moderno: revisión 2 con su evolución');
  await captura(page, 'B1_sobrescrito_reabierto.png');

  const bytes = await page.evaluate(async (n) =>
    Array.from(new Uint8Array(await window.__disco[n].arrayBuffer())), nombre);
  fs.writeFileSync(path.join(OUT, 'B_sobrescrito.pdf'), Buffer.from(bytes));
  await context.close();
}

await browser.close();

informe.externas = [...new Set(informe.externas)];
fs.writeFileSync(path.join(OUT, 'informe.json'), JSON.stringify(informe, null, 2));
console.log('\nPeticiones fuera del sitio:', informe.externas.length ? informe.externas : 'ninguna');
console.log('Peticiones fallidas:', informe.fallidas.length ? informe.fallidas : 'ninguna');
console.log('Errores de consola:', informe.erroresConsola.length ? informe.erroresConsola : 'ninguno');
if (informe.externas.length || informe.fallidas.length) process.exit(1);
