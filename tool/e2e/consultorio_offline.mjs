// Prueba de extremo a extremo del consultorio (Fase 5.0) en Chromium, SIN
// CONEXIÓN y con la CSP de producción.
//
// Uso:
//   ./tool/construir_web.sh --dart-define=CONSULTORIO_ENABLED=true --salida build/web-consultorio
//   node tool/e2e/servidor.mjs 8766 build/web-consultorio &
//   node tool/e2e/consultorio_offline.mjs
//
// Variables: BASE_URL (http://localhost:8766/) y OUT_DIR
// (build/e2e-consultorio).
//
// Recorre: crear la frase, guardar el código de recuperación (hoja PDF y
// últimos 4 caracteres), medir la derivación, respaldar, bloquear, frase
// incorrecta, desbloquear, candado entre pestañas, restaurar (un archivo
// dañado y una frase equivocada se rechazan), aviso de respaldo vencido,
// recuperar con el código, móvil y 320 px. Falla si hay peticiones fuera
// del sitio, peticiones fallidas o errores de consola (incluida la CSP).

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const BASE = process.env.BASE_URL ?? 'http://localhost:8766/';
const OUT = path.resolve(process.env.OUT_DIR ?? 'build/e2e-consultorio');
fs.mkdirSync(OUT, { recursive: true });

const FRASE = 'mango azul en la loma del consultorio';
const FRASE_NUEVA = 'otra frase larga para recuperar';

const informe = { externas: [], fallidas: [], erroresConsola: [], pasos: [], derivacion: '' };
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

function vigilar(context, page) {
  context.on('request', (r) => {
    const u = r.url();
    if (!u.startsWith(BASE) && !u.startsWith('blob:') && !u.startsWith('data:')) informe.externas.push(u);
  });
  context.on('requestfailed', (r) => {
    if (r.url().startsWith('blob:')) return;
    informe.fallidas.push(`${r.url()} ${r.failure()?.errorText}`);
  });
  page.on('console', (m) => {
    consola.push(`[${m.type()}] ${m.text()}`);
    if (m.type() === 'error') informe.erroresConsola.push(m.text());
  });
  page.on('pageerror', (e) => {
    consola.push(`[pageerror] ${e.message}`);
    informe.erroresConsola.push(e.message);
  });
}

const boton = (page, nombre) => page.getByRole('button', { name: nombre }).first();
const texto = (page, t) => {
  const l = page
    .getByText(t, { exact: false })
    .or(page.locator(`flt-semantics[aria-label*="${t.replaceAll('"', '\\"')}"]`))
    .first();
  return {
    waitFor: (o = {}) => l.waitFor({ state: 'attached', ...o }),
    desaparece: (o = {}) => l.waitFor({ state: 'detached', ...o }),
  };
};
const comienzo = (t) => new RegExp('^' + t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
// Los campos con texto oculto (frases) son <input type=password>: no tienen
// el rol «textbox», se buscan por su etiqueta.
const campo = (page, etiqueta) =>
  page.getByRole('textbox', { name: comienzo(etiqueta) }).or(page.getByLabel(comienzo(etiqueta))).first();

async function escribir(page, etiqueta, valor) {
  const c = campo(page, etiqueta);
  for (let intento = 0; intento < 4; intento++) {
    await c.scrollIntoViewIfNeeded();
    await page.waitForTimeout(150 + intento * 300);
    await c.click();
    await page.waitForTimeout(150 + intento * 300);
    // Si un intento anterior dejó texto, se borra antes de escribir.
    await page.keyboard.press('Control+A');
    await page.keyboard.press('Delete');
    await c.fill(valor);
    await page.waitForTimeout(100);
    if (await c.evaluate((el, v) => document.activeElement === el && el.value === v, valor)) return;
  }
  throw new Error(`No se pudo escribir en "${etiqueta}"`);
}

async function pulsar(page, nombre) {
  const l = page
    .getByRole('button', { name: nombre })
    .or(page.getByRole('tab', { name: nombre }))
    .or(page.locator(`flt-semantics[flt-tappable][aria-label*="${nombre}"]`))
    .or(page.locator('flt-semantics[flt-tappable]').filter({ hasText: nombre }))
    .first();
  await l.scrollIntoViewIfNeeded();
  await page.waitForTimeout(150);
  await l.click();
  await page.waitForTimeout(250);
}

async function captura(page, nombre) {
  await page.waitForTimeout(450);
  await page.screenshot({ path: path.join(OUT, nombre) });
}

async function descargar(page, accion) {
  const [d] = await Promise.all([page.waitForEvent('download', { timeout: 60000 }), accion()]);
  const destino = path.join(OUT, d.suggestedFilename());
  await d.saveAs(destino);
  return destino;
}

async function elegirArchivo(page, nombreBoton, ruta) {
  const [selector] = await Promise.all([page.waitForEvent('filechooser'), pulsar(page, nombreBoton)]);
  await selector.setFiles(ruta);
}

async function cargar(page, ruta = '') {
  await page.goto(BASE + ruta);
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60000 });
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
  await page.waitForTimeout(800);
}

async function nuevaPagina(context, ruta = '') {
  const page = await context.newPage();
  vigilar(context, page);
  paginaActual = page;
  await cargar(page, ruta);
  return page;
}

async function desbloquear(page, frase = FRASE) {
  await texto(page, 'El consultorio está bloqueado').waitFor({ timeout: 30000 });
  await escribir(page, 'Frase de acceso', frase);
  await pulsar(page, 'Desbloquear');
}

// ─────────────── 1. Primera vez, sin conexión ───────────────
const context = await browser.newContext({
  acceptDownloads: true,
  viewport: { width: 1440, height: 1000 },
  locale: 'es-CO',
  timezoneId: 'America/Bogota',
});
await context.addInitScript(() =>
  document.addEventListener('securitypolicyviolation', (e) =>
    console.error(`CSP: ${e.violatedDirective} bloqueó ${e.blockedURI} (${e.sourceFile}:${e.lineNumber})`),
  ),
);
const page = await nuevaPagina(context);
await texto(page, 'ya funciona sin conexión').waitFor({ timeout: 60000 });
await texto(page, 'ya funciona sin conexión').desaparece({ timeout: 20000 });
await context.setOffline(true);
await page.getByRole('button', { name: /receta/i }).first().waitFor({ timeout: 30000 });
await captura(page, 'c0_historia_con_riel.png');
paso('Con la bandera: la historia de siempre, con el riel del consultorio (sin conexión)');

await pulsar(page, 'Ajustes');
await texto(page, 'Crea tu frase de acceso').waitFor({ timeout: 30000 });
await escribir(page, 'Frase de acceso', 'corta');
await texto(page, 'Muy corta').waitFor();
await escribir(page, 'Frase de acceso', FRASE);
await escribir(page, 'Repite la frase', FRASE);
await captura(page, 'c1_crear_frase.png');
await pulsar(page, 'Crear frase');
await texto(page, 'Guarda tu código de recuperación').waitFor({ timeout: 60000 });
// El código está en la etiqueta semántica del recuadro (aria-label o texto,
// según la versión del motor).
const codigo = await page.evaluate(() => {
  for (const e of document.querySelectorAll('flt-semantics')) {
    const t = `${e.getAttribute('aria-label') ?? ''} ${e.textContent ?? ''}`;
    const m = t.match(/Código de recuperación: ([0-9A-Z]{4}(?:-[0-9A-Z]{4}){5})/);
    if (m) return m[1];
  }
  return '';
});
if (!/^[0-9A-Z]{4}(-[0-9A-Z]{4}){5}$/.test(codigo)) throw new Error(`Código inesperado: ${codigo}`);
await captura(page, 'c2_codigo_recuperacion.png');
paso('Frase creada: se muestra el código de recuperación (6 grupos de 4)');

const hoja = await descargar(page, () => pulsar(page, 'Descargar hoja para imprimir'));
const pdf = fs.readFileSync(hoja);
if (pdf.subarray(0, 5).toString('latin1') !== '%PDF-') throw new Error('La hoja no es un PDF');
try {
  const textoPdf = execFileSync('pdftotext', ['-layout', hoja, '-']).toString();
  for (const g of codigo.split('-')) {
    if (!textoPdf.includes(g)) throw new Error(`La hoja no tiene el grupo ${g}`);
  }
  if (textoPdf.includes(FRASE)) throw new Error('La hoja contiene la frase');
  paso('Hoja de recuperación en PDF con el código y sin la frase');
} catch (e) {
  if (e.code !== 'ENOENT') throw e;
  paso('Hoja de recuperación descargada (sin pdftotext para leerla)');
}

await escribir(page, 'Últimos 4 caracteres del código', codigo.slice(-4));
await pulsar(page, 'Ya lo guardé, continuar');
await texto(page, 'Ajustes del consultorio').waitFor({ timeout: 30000 });
await texto(page, 'Todavía no has respaldado el consultorio').waitFor();
await captura(page, 'c3_ajustes_sin_respaldo.png');
paso('Código confirmado con sus últimos 4 caracteres; Ajustes abiertos y aviso de respaldo');

const bases = await page.evaluate(async () => (await indexedDB.databases()).map((d) => d.name));
if (!bases.includes('historiasclinicas_consultorio')) throw new Error(`Falta la base del consultorio: ${bases}`);
// Nada legible en la base: ni la frase ni el código.
const contenido = await page.evaluate(
  () =>
    new Promise((listo, falla) => {
      const p = indexedDB.open('historiasclinicas_consultorio');
      p.onerror = () => falla(p.error);
      p.onsuccess = () => {
        const bd = p.result;
        const salida = [];
        const tx = bd.transaction(['meta', 'registros', 'binarios']);
        for (const n of ['meta', 'registros', 'binarios']) {
          const r = tx.objectStore(n).getAll();
          r.onsuccess = () => {
            for (const v of r.result) salida.push(new TextDecoder('latin1').decode(v));
          };
        }
        tx.oncomplete = () => {
          bd.close();
          listo(salida.join('\n'));
        };
      };
    }),
);
if (contenido.includes(FRASE) || contenido.includes(codigo.replaceAll('-', ''))) {
  throw new Error('La base del consultorio guarda la frase o el código en claro');
}
paso('IndexedDB «historiasclinicas_consultorio» creada, sin la frase ni el código en claro');

await pulsar(page, 'Medir la derivación');
await texto(page, 'pasadas:').waitFor({ timeout: 120000 });
informe.derivacion = await page.evaluate(() => {
  for (const e of document.querySelectorAll('flt-semantics')) {
    const t = `${e.getAttribute('aria-label') ?? ''} ${e.textContent ?? ''}`;
    const m = t.match(/PBKDF2[^\n]*?\d+ ms[\s\S]*?Argon2id[^\n]*?\d+ ms/);
    if (m) return m[0].replace(/\s+/g, ' ');
  }
  return '';
});
if (!informe.derivacion) throw new Error('No se leyó la medición de la derivación');
paso(`Derivación medida en Chromium: ${informe.derivacion}`);

const respaldo = await descargar(page, () => pulsar(page, 'Respaldar ahora'));
const bytesRespaldo = fs.readFileSync(respaldo);
if (bytesRespaldo.subarray(0, 2).toString('latin1') !== 'PK') throw new Error('El respaldo no es un ZIP');
if (!bytesRespaldo.includes(Buffer.from('manifiesto.json'))) throw new Error('El respaldo no tiene manifiesto');
if (bytesRespaldo.includes(Buffer.from(FRASE))) throw new Error('El respaldo contiene la frase');
if (!path.basename(respaldo).endsWith('.hcrespaldo')) throw new Error(`Nombre inesperado: ${respaldo}`);
await texto(page, 'Todavía no has respaldado el consultorio').desaparece({ timeout: 15000 });
paso(`Respaldo descargado (${path.basename(respaldo)}, ${bytesRespaldo.length} bytes): ZIP con manifiesto y sin la frase; el aviso desaparece`);

// ─────────────── 2. Bloquear y desbloquear ───────────────
await pulsar(page, 'Bloquear ahora');
await texto(page, 'El consultorio está bloqueado').waitFor({ timeout: 15000 });
await captura(page, 'c4_bloqueado.png');
await escribir(page, 'Frase de acceso', 'esta no es la frase correcta');
await pulsar(page, 'Desbloquear');
await texto(page, 'La frase o el código no son correctos.').waitFor({ timeout: 30000 });
paso('Bloqueado: una frase incorrecta no abre');
await desbloquear(page);
await texto(page, 'Ajustes del consultorio').waitFor({ timeout: 30000 });
paso('La frase correcta abre');

// Candado entre pestañas: con el consultorio abierto aquí, otra pestaña no
// puede abrirlo.
const otra = await nuevaPagina(context, '#/ajustes');
await desbloquear(otra);
await texto(otra, 'abierto en otra pestaña').waitFor({ timeout: 30000 });
await otra.close();
paginaActual = page;
paso('Otra pestaña no abre el consultorio mientras está abierto en esta');

// ─────────────── 3. Restaurar ───────────────
const danado = path.join(OUT, 'danado.hcrespaldo');
const copia = Buffer.from(bytesRespaldo);
copia[Math.floor(copia.length / 2)] ^= 0xff;
fs.writeFileSync(danado, copia);
await elegirArchivo(page, 'Restaurar…', danado);
await escribir(page, 'Frase de acceso', FRASE);
await pulsar(page, 'Abrir y verificar');
await texto(page, 'no es un respaldo de esta app o está incompleto').waitFor({ timeout: 60000 });
await pulsar(page, 'Cancelar');
paso('Un respaldo dañado se rechaza');

await elegirArchivo(page, 'Restaurar…', respaldo);
await escribir(page, 'Frase de acceso', 'frase que no corresponde');
await pulsar(page, 'Abrir y verificar');
await texto(page, 'no corresponden a este respaldo').waitFor({ timeout: 60000 });
await escribir(page, 'Frase de acceso', FRASE);
await pulsar(page, 'Abrir y verificar');
await texto(page, '¿Restaurar este respaldo?').waitFor({ timeout: 60000 });
await captura(page, 'c5_restaurar_confirmar.png');
await pulsar(page, 'Reemplazar y restaurar');
await texto(page, 'Respaldo restaurado').waitFor({ timeout: 60000 });
paso('Restaurar: frase equivocada rechazada; con la correcta se verifica y se restaura');

// ─────────────── 4. Aviso de respaldo vencido ───────────────
await page.evaluate(
  () =>
    new Promise((listo, falla) => {
      const p = indexedDB.open('historiasclinicas_consultorio');
      p.onerror = () => falla(p.error);
      p.onsuccess = () => {
        const bd = p.result;
        const hace10 = new Date(Date.now() - 10 * 24 * 3600 * 1000).toISOString();
        const valor = new TextEncoder().encode(JSON.stringify({ fecha: hace10, huella: '', tamano: 0 }));
        const tx = bd.transaction('meta', 'readwrite');
        tx.objectStore('meta').put(valor, 'respaldo');
        tx.oncomplete = () => {
          bd.close();
          listo();
        };
      };
    }),
);
// Recarga real (sin conexión, desde el service worker): cambiar solo el
// «#» no recarga la página.
await page.evaluate(() => (location.hash = '#/ajustes'));
await page.reload();
await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60000 });
await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
await desbloquear(page);
await texto(page, 'Último respaldo hace 10 días').waitFor({ timeout: 30000 });
await captura(page, 'c6_aviso_respaldo_vencido.png');
paso('Recargada sin conexión: el aviso de respaldo vencido (10 días) aparece al abrir');

// ─────────────── 5. Recuperar con el código ───────────────
await pulsar(page, 'Bloquear ahora');
await pulsar(page, '¿Olvidaste la frase? Usar el código');
await escribir(page, 'Código de recuperación', codigo.toLowerCase());
await escribir(page, 'Frase nueva', FRASE_NUEVA);
await escribir(page, 'Repite la frase nueva', FRASE_NUEVA);
await captura(page, 'c7_recuperar.png');
await pulsar(page, 'Recuperar');
await texto(page, 'Ajustes del consultorio').waitFor({ timeout: 60000 });
await pulsar(page, 'Bloquear ahora');
await desbloquear(page, FRASE_NUEVA);
await texto(page, 'Ajustes del consultorio').waitFor({ timeout: 30000 });
paso('Recuperado con el código (en minúsculas): la frase nueva abre');

// ─────────────── 6. Móvil y 320 px ───────────────
await page.setViewportSize({ width: 390, height: 844 });
await page.waitForTimeout(600);
await captura(page, 'c8_movil_ajustes.png');
await pulsar(page, 'Menú del consultorio');
await texto(page, 'CONSULTORIO').waitFor();
await captura(page, 'c9_movil_menu.png');
await page.keyboard.press('Escape');
await page.waitForTimeout(400);
await pulsar(page, 'Bloquear el consultorio');
await texto(page, 'El consultorio está bloqueado').waitFor({ timeout: 15000 });
await captura(page, 'c10_movil_bloqueado.png');
paso('Móvil (390 px): menú lateral, Ajustes y bloqueo');

await page.setViewportSize({ width: 320, height: 640 });
await page.waitForTimeout(600);
await captura(page, 'c11_320_bloqueado.png');
await desbloquear(page, FRASE_NUEVA);
await texto(page, 'Ajustes del consultorio').waitFor({ timeout: 30000 });
await captura(page, 'c12_320_ajustes.png');
paso('320 px: desbloqueo y Ajustes');

await context.close();
await browser.close();
informe.externas = [...new Set(informe.externas)];
fs.writeFileSync(path.join(OUT, 'informe.json'), JSON.stringify(informe, null, 2));
console.log('\nPeticiones fuera del sitio:', informe.externas.length ? informe.externas : 'ninguna');
console.log('Peticiones fallidas:', informe.fallidas.length ? informe.fallidas : 'ninguna');
console.log('Errores de consola:', informe.erroresConsola.length ? informe.erroresConsola : 'ninguno');
if (informe.externas.length || informe.fallidas.length || informe.erroresConsola.length) process.exit(1);
