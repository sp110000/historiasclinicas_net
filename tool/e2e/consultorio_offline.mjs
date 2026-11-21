// Prueba de extremo a extremo del consultorio (Fase 5.0 y 5.1) en Chromium, SIN
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
// recuperar con el código, móvil y 320 px. Luego, en un navegador nuevo
// (5.1): importar PDF sintéticos (uno alterado), buscar, abrir la ficha,
// firmar la autorización de datos, evolución y receta desde la ficha, y
// comprobar que nada de los pacientes queda en claro. Falla si hay
// peticiones fuera del sitio, peticiones fallidas o errores de consola
// (incluida la CSP).

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
  consola.push(`--- paso: ${t}`);
  informe.pasos.push(t);
  console.log('✓', t);
};
const alFallar = async (e) => {
  console.error('✗ Falló la prueba:', e.message);
  console.error('Últimos mensajes de consola:\n  ' + consola.slice(-25).join('\n  '));
  fs.writeFileSync(path.join(OUT, 'consola.txt'), consola.join('\n'));
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

// ─────────────── 2. Pacientes (5.1), en un navegador nuevo ───────────────
{
  const FIXTURES = path.join(path.dirname(new URL(import.meta.url).pathname), 'fixtures', 'consultorio');
  // Médico configurado como lo deja «Datos del médico» (sintético); sin el
  // selector de archivos del sistema, para que los PDF se descarguen.
  const MEDICO = {
    nombre: 'Dra. Ana Pérez Gómez',
    registro: 'RM 54321',
    tipoDocumento: 'CC',
    documento: '52111222',
    direccion: 'Calle 5 # 10-20',
    ciudad: 'Santander de Quilichao',
    telefono: '602 555 0101',
    correo: 'consultorio@ejemplo.invalid',
  };
  const ctx = await browser.newContext({
    acceptDownloads: true,
    viewport: { width: 1440, height: 1000 },
    locale: 'es-CO',
    timezoneId: 'America/Bogota',
  });
  await ctx.addInitScript((medico) => {
    delete window.showOpenFilePicker;
    delete window.showSaveFilePicker;
    if (!localStorage.getItem('flutter.hc.medico.v1')) {
      localStorage.setItem('flutter.hc.medico.v1', JSON.stringify(JSON.stringify(medico)));
    }
    document.addEventListener('securitypolicyviolation', (e) =>
      console.error(`CSP: ${e.violatedDirective} bloqueó ${e.blockedURI}`),
    );
  }, MEDICO);
  const p = await nuevaPagina(ctx);
  await texto(p, 'ya funciona sin conexión').waitFor({ timeout: 60000 });
  await texto(p, 'ya funciona sin conexión').desaparece({ timeout: 20000 });
  await ctx.setOffline(true);

  await pulsar(p, 'Pacientes');
  await texto(p, 'Crea tu frase de acceso').waitFor({ timeout: 30000 });
  await escribir(p, 'Frase de acceso', FRASE);
  await escribir(p, 'Repite la frase', FRASE);
  await pulsar(p, 'Crear frase');
  await texto(p, 'Guarda tu código de recuperación').waitFor({ timeout: 60000 });
  const cod = await p.evaluate(() => {
    for (const e of document.querySelectorAll('flt-semantics')) {
      const t = `${e.getAttribute('aria-label') ?? ''} ${e.textContent ?? ''}`;
      const m = t.match(/Código de recuperación: ([0-9A-Z]{4}(?:-[0-9A-Z]{4}){5})/);
      if (m) return m[1];
    }
    return '';
  });
  await escribir(p, 'Últimos 4 caracteres del código', cod.slice(-4));
  await pulsar(p, 'Ya lo guardé, continuar');
  await texto(p, 'Todavía no hay pacientes').waitFor({ timeout: 30000 });
  await captura(p, 'p0_pacientes_vacia.png');

  // Importar los PDF sintéticos: tres historias (una alterada) y uno ajeno.
  const archivos = fs.readdirSync(FIXTURES).filter((f) => f.endsWith('.pdf')).map((f) => path.join(FIXTURES, f));
  const [selector] = await Promise.all([p.waitForEvent('filechooser'), pulsar(p, 'Importar PDF')]);
  await selector.setFiles(archivos);
  await texto(p, 'Importación terminada').waitFor({ timeout: 60000 });
  await texto(p, '3 de 4 archivos en el índice').waitFor();
  await texto(p, 'Importada con alteraciones').waitFor();
  await texto(p, 'No es de la app').waitFor();
  await captura(p, 'p1_informe_importacion.png');
  paso('Importación de 4 PDF: 3 en el índice (1 alterada, marcada) y 1 ajeno, con informe por archivo');
  await pulsar(p, 'Cerrar');
  await texto(p, 'Pacientes · 3').waitFor();
  await texto(p, 'Control vencido').waitFor();
  await captura(p, 'p2_lista_pacientes.png');

  // Buscar sin tildes y abrir la ficha con Enter.
  await escribir(p, 'Buscar paciente', 'pena jose');
  await texto(p, '1 paciente').waitFor();
  await captura(p, 'p3_busqueda.png');
  await p.keyboard.press('Enter');
  await texto(p, 'Ficha del paciente').waitFor();
  await texto(p, 'Control vencido (15/11/2026)').waitFor();
  await texto(p, 'Sin autorización de tratamiento de datos').waitFor();
  await captura(p, 'p4_ficha.png');
  paso('Búsqueda sin tildes («pena jose») y Enter abre la ficha: alergias, control vencido y línea de tiempo');

  // Aprobar la plantilla de autorización y firmarla en pantalla.
  await pulsar(p, 'Ajustes');
  await texto(p, 'Plantillas de documentos').waitFor();
  await pulsar(p, 'Aprobar v1');
  await p.getByRole('button', { name: 'Aprobar', exact: true }).click();
  await texto(p, 'aprobada el').waitFor();
  await texto(p, 'Plantillas de documentos').waitFor();
  await p.getByText('Plantillas de documentos').first().scrollIntoViewIfNeeded().catch(() => {});
  await captura(p, 'p4b_ajustes_plantillas.png');
  await pulsar(p, 'Pacientes');
  await escribir(p, 'Buscar paciente', '1032456789');
  await p.keyboard.press('Enter');
  await texto(p, 'Ficha del paciente').waitFor();
  await pulsar(p, 'Pedir autorización');
  await texto(p, 'Plantilla versión 1').waitFor();
  await p.getByRole('checkbox', { name: /El paciente leyó/ }).click();
  const rotulo = await p
    .locator('flt-semantics')
    .filter({ hasText: /^FIRMA DEL PACIENTE$/ })
    .or(p.locator('flt-semantics[aria-label="FIRMA DEL PACIENTE"]'))
    .first()
    .boundingBox();
  if (!rotulo) throw new Error('No se encontró el lienzo de la firma');
  const x0 = rotulo.x + 40;
  const y0 = rotulo.y + rotulo.height + 60;
  await p.mouse.move(x0, y0);
  await p.mouse.down();
  for (let i = 1; i <= 12; i++) await p.mouse.move(x0 + i * 18, y0 + (i % 2 ? -25 : 25), { steps: 2 });
  await p.mouse.up();
  await captura(p, 'p5_autorizacion_firma.png');
  const autorizacion = await descargar(p, () => pulsar(p, 'Firmar y descargar PDF'));
  if (!/^Autorizacion_datos_.*_AD-000001\.pdf$/.test(path.basename(autorizacion))) {
    throw new Error(`Nombre de la autorización: ${path.basename(autorizacion)}`);
  }
  const pdfAut = fs.readFileSync(autorizacion).toString('latin1');
  if (!pdfAut.includes('(documento.json)')) throw new Error('La autorización no lleva documento.json');
  await texto(p, 'Autorización de datos firmada el').waitFor();
  paso(`Autorización de datos firmada en pantalla → ${path.basename(autorizacion)} (con documento.json)`);

  // Evolución prellenada desde la ficha: se guarda y aparece en la línea de tiempo.
  await p.getByRole('button', { name: 'Evolución', exact: true }).click();
  await texto(p, 'Historia abierta').waitFor({ timeout: 30000 });
  await escribir(p, 'Nueva evolución *', 'Control. Peso estable, buena tolerancia.');
  await escribir(p, 'Próximo control', '15/12/2026');
  await captura(p, 'p6_evolucion_con_franja.png');
  await pulsar(p, 'Descargar historia actualizada');
  const opcion = p.getByText('Guardar como nueva versión', { exact: false }).first();
  const v3 = await descargar(p, async () => {
    await p.waitForTimeout(500);
    if (await opcion.count()) await opcion.click();
  });
  await texto(p, 'Integridad verificada (3 sellos encadenados)').waitFor({ timeout: 30000 });
  paso(`Evolución desde la ficha, con la franja «← Ficha» y próximo control → ${path.basename(v3)}`);

  // Receta desde la ficha, con receta.json, registrada en la ficha.
  await pulsar(p, 'Ficha');
  await texto(p, 'Evolución 2').waitFor({ timeout: 30000 });
  await texto(p, 'Íntegra · revisión 3').waitFor();
  await p.getByRole('button', { name: 'Receta', exact: true }).click();
  await texto(p, 'Vista previa de la receta').waitFor({ timeout: 30000 });
  for (const [etiqueta, valor] of [
    ['Medicamento (DCI o genérico) *', 'Metformina'],
    ['Concentración *', '850 mg'],
    ['Forma farmacéutica *', 'tableta'],
    ['Dosis *', '1 tableta'],
    ['Vía *', 'oral'],
    ['Frecuencia *', 'cada 12 horas'],
    ['Duración *', '30 días'],
  ]) {
    await escribir(p, etiqueta, valor);
    await p.keyboard.press('Escape');
  }
  // La cantidad sugerida completa el campo obligatorio. El chip se expone
  // como casilla, con su tooltip delante en el nombre («… Usar 60»).
  const usar = p
    .getByRole('button', { name: /Usar 60/ })
    .or(p.getByRole('checkbox', { name: /Usar 60/ }))
    .or(p.locator('flt-semantics[flt-tappable][aria-label*="Usar 60"]'))
    .first();
  await usar.scrollIntoViewIfNeeded();
  await usar.click();
  await texto(p, '(sesenta)').waitFor();
  const receta = await descargar(p, () => pulsar(p, 'Guardar PDF'));
  if (!fs.readFileSync(receta).toString('latin1').includes('(receta.json)')) {
    throw new Error('La receta no lleva receta.json');
  }
  const registrar = p.getByRole('button', { name: 'Registrar en la historia' });
  await registrar.waitFor({ timeout: 15000 });
  await registrar.click();
  await pulsar(p, 'Pacientes');
  await escribir(p, 'Buscar paciente', 'pena');
  await p.keyboard.press('Enter');
  await texto(p, 'METFORMINA 850 mg').waitFor({ timeout: 30000 });
  await texto(p, 'Evolución 2 · Control. Peso estable').waitFor();
  await captura(p, 'p7_ficha_linea_de_tiempo.png');
  paso(`Receta con receta.json → ${path.basename(receta)}; la ficha muestra la evolución, la receta y la autorización`);

  // Nada de los pacientes en claro en IndexedDB ni en localStorage.
  const enClaro = await p.evaluate(
    () =>
      new Promise((listo, falla) => {
        const r = indexedDB.open('historiasclinicas_consultorio');
        r.onerror = () => falla(r.error);
        r.onsuccess = () => {
          const bd = r.result;
          const textos = [];
          const tx = bd.transaction(['registros', 'binarios']);
          for (const n of ['registros', 'binarios']) {
            const c = tx.objectStore(n).openCursor();
            c.onsuccess = () => {
              const k = c.result;
              if (!k) return;
              const v = k.value;
              textos.push(new TextDecoder('latin1').decode(v instanceof ArrayBuffer ? new Uint8Array(v) : v));
              k.continue();
            };
          }
          tx.oncomplete = () => {
            bd.close();
            const todo = textos.join('\n') + '\n' + Object.values(localStorage).join('\n');
            listo(['1032456789', 'Metformina', 'PEÑA', 'Penicilina'].filter((t) => todo.includes(t)));
          };
        };
      }),
  );
  if (enClaro.length) throw new Error(`Datos de pacientes en claro: ${enClaro}`);
  paso('IndexedDB y localStorage sin datos de pacientes en claro (índice, documentos, recetas y borrador cifrados)');

  // Móvil: lista y ficha.
  await p.setViewportSize({ width: 390, height: 844 });
  await p.waitForTimeout(800);
  await captura(p, 'p8_ficha_movil.png');
  // La lista construye solo lo visible: se sube hasta «Acciones».
  const acciones = p.getByRole('button', { name: 'Acciones', exact: true });
  for (let i = 0; i < 15 && !(await acciones.count()); i++) {
    await p.mouse.move(200, 500);
    await p.mouse.wheel(0, -400);
    await p.waitForTimeout(250);
  }
  // Se pulsa el nodo visible (al cambiar de tamaño pueden quedar otros).
  let pulsado = false;
  for (const l of await acciones.all()) {
    const c = await l.boundingBox();
    if (c && c.width > 0 && c.y >= 0 && c.y < 844) {
      await p.mouse.click(c.x + c.width / 2, c.y + c.height / 2);
      pulsado = true;
      break;
    }
  }
  if (!pulsado) throw new Error('No se encontró el botón «Acciones» visible');
  await texto(p, 'Unir con otra ficha').waitFor();
  await captura(p, 'p9_ficha_movil_acciones.png');
  await p.keyboard.press('Escape');
  paso('Móvil (390 px): ficha con el menú «Acciones»');
  await ctx.close();
}

await browser.close();
informe.externas = [...new Set(informe.externas)];
fs.writeFileSync(path.join(OUT, 'informe.json'), JSON.stringify(informe, null, 2));
console.log('\nPeticiones fuera del sitio:', informe.externas.length ? informe.externas : 'ninguna');
console.log('Peticiones fallidas:', informe.fallidas.length ? informe.fallidas : 'ninguna');
console.log('Errores de consola:', informe.erroresConsola.length ? informe.erroresConsola : 'ninguno');
// Flutter informa sus excepciones como mensajes normales de la consola.
informe.excepciones = consola.filter((l) =>
  /Another exception was thrown|EXCEPTION CAUGHT|Null check operator used on a null value/.test(l),
);
console.log('Excepciones de Flutter:', informe.excepciones.length ? informe.excepciones.slice(0, 5) : 'ninguna');
fs.writeFileSync(path.join(OUT, 'informe.json'), JSON.stringify(informe, null, 2));
if (
  informe.externas.length ||
  informe.fallidas.length ||
  informe.erroresConsola.length ||
  informe.excepciones.length
) {
  fs.writeFileSync(path.join(OUT, 'consola.txt'), consola.join('\n'));
  process.exit(1);
}
