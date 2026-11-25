// Prueba de extremo a extremo del consultorio (Fase 5.0 a 5.8) en Chromium, SIN
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
// firmar la autorización de datos, evolución y receta desde la ficha; luego
// (5.2) mediciones, consentimiento de imagen, fotos de antes y después
// (con el reloj del navegador fijado), comparación y cortina, informe de
// seguimiento y fotos en PDF; (5.3) protocolo, programa de peso con GLP-1,
// valoración, consentimiento informado y sesión (bloqueada sin
// consentimiento y con un lote vencido, luego sellada); (5.4) documentos;
// (5.5) agenda; (5.6) caja: cobro con abono, paquete con el crédito de la
// valoración, recibos en PDF, informe y cierre del día; (5.7) inventario:
// entrada de lotes, sesión que los descuenta y bloqueo con un lote vencido;
// un cobro con un insumo usado que se descuenta y vuelve al anularlo;
// (5.8) notas «VERIFICAR» con su registro y modo presentación; y comprobar que
// nada de los pacientes queda en claro. Falla si hay
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
// Con la bandera abre en la agenda (pregunta 51); la primera vez, cerrada,
// pide crear la frase. La historia sigue a un clic en el riel.
await texto(page, 'Crea tu frase de acceso').waitFor({ timeout: 30000 });
await pulsar(page, 'Historia');
await page.getByRole('button', { name: /receta/i }).first().waitFor({ timeout: 30000 });
await captura(page, 'c0_historia_con_riel.png');
paso('Con la bandera abre en la agenda; la historia de siempre sigue en el riel (sin conexión)');

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

  // ─────────────── 3. Seguimiento y fotos (5.2) ───────────────
  // Elementos por nombre exacto (los chips «Fotos» y «Seguimiento» se
  // confunden con «Tomar fotos» o «Informe de seguimiento»).
  const exacto = (nombre) =>
    p
      .getByRole('button', { name: nombre, exact: true })
      .or(p.getByRole('checkbox', { name: nombre, exact: true }))
      .or(p.getByRole('radio', { name: nombre, exact: true }))
      .or(p.getByRole('switch', { name: comienzo(nombre) }))
      .first();
  async function tocar(nombre) {
    const l = exacto(nombre);
    await l.scrollIntoViewIfNeeded();
    await p.waitForTimeout(150);
    await l.click();
    await p.waitForTimeout(300);
  }
  async function firmarEnPantalla() {
    const r = await p
      .locator('flt-semantics')
      .filter({ hasText: /^FIRMA DEL PACIENTE$/ })
      .or(p.locator('flt-semantics[aria-label="FIRMA DEL PACIENTE"]'))
      .first()
      .boundingBox();
    if (!r) throw new Error('No se encontró el lienzo de la firma');
    const fx = r.x + 40;
    const fy = r.y + r.height + 60;
    await p.mouse.move(fx, fy);
    await p.mouse.down();
    for (let i = 1; i <= 12; i++) await p.mouse.move(fx + i * 18, fy + (i % 2 ? -25 : 25), { steps: 2 });
    await p.mouse.up();
  }
  async function medir(valores, { copiar }) {
    await tocar('Medición');
    await texto(p, 'Medición nueva').waitFor();
    for (const [etiqueta, valor] of valores) await escribir(p, etiqueta, valor);
    const casilla = p.getByRole('checkbox', { name: /Agregar a la evolución en curso/ }).first();
    if ((await casilla.isChecked()) !== copiar) await casilla.click();
    await pulsar(p, 'Guardar medición');
    await texto(p, 'Medición nueva').desaparece({ timeout: 15000 });
  }
  async function tomarFoto(ruta, { conAnterior = false } = {}) {
    await pulsar(p, 'Tomar fotos');
    await texto(p, 'Frontal (1 de 5)').waitFor();
    if (conAnterior) {
      await texto(p, 'Ver la anterior en transparencia').waitFor();
      await captura(p, 'f1_secuencia_con_anterior.png');
    }
    const [selector] = await Promise.all([p.waitForEvent('filechooser'), pulsar(p, 'Tomar o elegir foto')]);
    if (!(await selector.element().getAttribute('capture'))) {
      throw new Error('El selector de fotos no pide la cámara (capture)');
    }
    await selector.setFiles(ruta);
    await exacto('Aceptar').waitFor({ timeout: 30000 });
    await tocar('Aceptar');
    await texto(p, 'Lateral derecha (2 de 5)').waitFor({ timeout: 30000 });
    await pulsar(p, 'Terminar');
    await texto(p, '1 foto guardada').waitFor();
  }

  // El 01/09/2026 (reloj del navegador fijado con Playwright: solo cambia
  // Date; los temporizadores siguen): plantilla del consentimiento de
  // imagen, la firma, la primera medición y la foto de «antes».
  await p.clock.setFixedTime(new Date('2026-09-01T10:00:00-05:00'));
  await pulsar(p, 'Ajustes');
  await texto(p, 'Plantillas de documentos').waitFor();
  await pulsar(p, 'Aprobar v1'); // La primera pendiente: consentimiento de imagen.
  await texto(p, '¿Aprobar').waitFor();
  await texto(p, 'Consentimiento de uso de imagen').waitFor();
  await p.getByRole('button', { name: 'Aprobar', exact: true }).click();
  await texto(p, 'aprobada el 01/09/2026').waitFor();
  await pulsar(p, 'Pacientes');
  await escribir(p, 'Buscar paciente', '1032456789');
  await p.keyboard.press('Enter');
  await texto(p, 'Ficha del paciente').waitFor();
  await tocar('Fotos');
  await texto(p, 'hace falta el consentimiento de uso de imagen').waitFor();
  if (await p.getByRole('button', { name: 'Tomar fotos' }).count()) {
    throw new Error('Sin consentimiento aparece «Tomar fotos»');
  }
  await pulsar(p, 'Pedir consentimiento');
  await texto(p, 'USOS QUE AUTORIZA').waitFor();
  await p.getByRole('checkbox', { name: /Docencia/ }).click();
  await p.getByRole('checkbox', { name: /El paciente leyó/ }).click();
  await firmarEnPantalla();
  await captura(p, 'f0_consentimiento_imagen.png');
  const cim = await descargar(p, () => pulsar(p, 'Firmar y descargar PDF'));
  if (!/^Consentimiento_imagen_.*_CIM-000001\.pdf$/.test(path.basename(cim))) {
    throw new Error(`Nombre del consentimiento: ${path.basename(cim)}`);
  }
  await exacto('Tomar fotos').waitFor({ timeout: 15000 });
  paso(`Sin consentimiento no hay «Tomar fotos»; consentimiento de imagen firmado (clínico y docencia) → ${path.basename(cim)}`);

  await tocar('Seguimiento');
  await medir(
    [
      ['Peso', '67'],
      ['Talla', '162'],
      ['Cintura', '90'],
      ['Cadera', '100'],
    ],
    { copiar: false },
  );
  await tocar('Fotos');
  await tomarFoto(path.join(FIXTURES, 'foto_frontal_antes.jpg'));
  paso('01/09/2026: primera medición y foto frontal de «antes» (cámara del sistema con capture)');

  // Hoy: segunda medición (copiada a la evolución en curso) y la foto de
  // «después» con orientación EXIF 6, alineada con la anterior.
  await p.clock.setFixedTime(new Date());
  await tocar('Seguimiento');
  await medir(
    [
      ['Peso', '62,8'],
      ['Cintura', '85'],
      ['Cadera', '98'],
    ],
    { copiar: true },
  );
  await texto(p, 'agregada a la evolución en curso').waitFor();
  await texto(p, 'Peso 67 → 62,8 kg').waitFor();
  await texto(p, 'agregada a la evolución en curso').desaparece({ timeout: 15000 });
  await captura(p, 's1_seguimiento.png');
  paso('Hoy: segunda medición, copiada a la evolución; cambios, gráfica (con la de la historia) y tabla');

  await tocar('Fotos');
  await tomarFoto(path.join(FIXTURES, 'foto_frontal_despues.jpg'), { conAnterior: true });
  await texto(p, 'COMPARAR').waitFor();
  const hoy = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Bogota' }).format(new Date());
  const dias = Math.round((Date.parse(hoy) - Date.parse('2026-09-01')) / 86400000);
  await texto(p, `Diferencia: ${dias} días`).waitFor();
  // Que se vean los selectores y las dos fotos enteras.
  await p.getByText('Diferencia:').first().scrollIntoViewIfNeeded().catch(() => {});
  await p.mouse.move(700, 600);
  await p.mouse.wheel(0, 420);
  await p.waitForTimeout(400);
  await captura(p, 'f2_fotos_comparacion.png');
  await tocar('Cortina');
  await p.getByRole('slider').first().waitFor({ state: 'attached' });
  await captura(p, 'f3_fotos_cortina.png');
  await tocar('Cortina');
  paso(`Foto de «después» con la anterior en transparencia; comparación lado a lado (${dias} días) y cortina`);

  // Informe de seguimiento: sin fotos salvo que se pidan.
  await tocar('Seguimiento');
  await pulsar(p, 'Informe de seguimiento');
  await texto(p, 'Incluir fotos').waitFor();
  const incluir = p.getByRole('checkbox', { name: /Incluir fotos/ }).first();
  if (await incluir.isChecked()) throw new Error('«Incluir fotos» viene marcado');
  await captura(p, 's2_informe_dialogo.png');
  const informePdf = await descargar(p, () => pulsar(p, 'Descargar'));
  if (!/^Informe_seguimiento_PENA_\d{4}-\d{2}-\d{2}\.pdf$/.test(path.basename(informePdf))) {
    throw new Error(`Nombre del informe: ${path.basename(informePdf)}`);
  }
  if (fs.readFileSync(informePdf).toString('latin1').includes('/DCTDecode')) {
    throw new Error('El informe lleva fotos sin pedirlas');
  }
  try {
    const t = execFileSync('pdftotext', ['-layout', informePdf, '-'], { encoding: 'utf8' });
    for (const esperado of ['INFORME DE SEGUIMIENTO', 'PEÑA MUÑOZ, José Ángel', 'Peso 67 → 62,8 kg', 'MEDICIONES', '01/09/2026', '02/10/2026']) {
      if (!t.includes(esperado)) throw new Error(`El informe no dice «${esperado}»`);
    }
    execFileSync('pdftoppm', ['-r', '110', '-png', '-f', '1', '-l', '1', '-singlefile', informePdf, path.join(OUT, 'pdf_informe_seguimiento')]);
  } catch (e) {
    if (e.code !== 'ENOENT') throw e;
  }
  paso(`Informe de seguimiento sin fotos (por defecto) → ${path.basename(informePdf)}`);

  // Exportar las fotos en PDF: las dos, ya sin EXIF y derechas.
  await tocar('Fotos');
  await pulsar(p, 'Exportar fotos en PDF');
  await texto(p, '¿Exportar las fotos?').waitFor();
  const fotosPdf = await descargar(p, () => p.getByRole('button', { name: 'Exportar', exact: true }).click());
  try {
    const lista = execFileSync('pdfimages', ['-list', fotosPdf], { encoding: 'utf8' })
      .split('\n')
      .slice(2)
      .filter((l) => /\bjpeg\b/.test(l))
      .map((l) => l.trim().split(/\s+/));
    const tamanos = lista.map((c) => `${c[3]}x${c[4]}`);
    if (tamanos.length !== 2 || tamanos.some((t) => t !== '1200x1600')) {
      throw new Error(`Fotos del PDF: ${tamanos} (se esperaban dos de 1200x1600, derechas)`);
    }
    const dir = fs.mkdtempSync(path.join(OUT, 'fotos-'));
    execFileSync('pdfimages', ['-j', fotosPdf, path.join(dir, 'f')]);
    for (const f of fs.readdirSync(dir)) {
      const b = fs.readFileSync(path.join(dir, f));
      if (b.includes('Exif') || b.includes('CamaraDePrueba')) throw new Error(`La foto ${f} conserva EXIF`);
    }
    fs.rmSync(dir, { recursive: true });
  } catch (e) {
    if (e.code !== 'ENOENT') throw e;
  }
  await texto(p, 'Fotos exportadas el').desaparece({ timeout: 20000 });
  paso(`Fotos exportadas en PDF → ${path.basename(fotosPdf)}: 2 JPEG de 1200×1600 (la de orientación 6 quedó derecha) y sin EXIF`);

  // Ajustes → Equipo secundario (en el principal: combinar un paquete).
  await pulsar(p, 'Ajustes');
  await texto(p, 'Equipo secundario').waitFor();
  // Flutter dibuja en un lienzo: se baja con la rueda hasta ver la tarjeta.
  const combinar = p.getByRole('button', { name: 'Combinar un paquete' }).first();
  for (let i = 0; i < 20; i++) {
    const c = await combinar.boundingBox().catch(() => null);
    if (c && c.y > 300 && c.y < 900) break;
    await p.mouse.move(700, 600);
    await p.mouse.wheel(0, 300);
    await p.waitForTimeout(250);
  }
  await captura(p, 'a1_equipo_secundario.png');
  await pulsar(p, 'Pacientes');
  await escribir(p, 'Buscar paciente', '1032456789');
  await p.keyboard.press('Enter');
  await texto(p, 'Ficha del paciente').waitFor();
  paso('Ajustes: tarjeta «Equipo secundario» (en el principal, «Combinar un paquete»)');

  // ─────────────── 4. Programa de peso, estética y sesión (5.3) ───────────────
  // Todos los elementos con ese nombre exacto (chips de un selector).
  const todos = (nombre) =>
    p
      .getByRole('button', { name: nombre, exact: true })
      .or(p.getByRole('checkbox', { name: nombre, exact: true }))
      .or(p.getByRole('radio', { name: nombre, exact: true }));
  // En las páginas largas, el árbol de accesibilidad puede no seguir al
  // desplazamiento: se baja o se sube con la rueda hasta que el elemento
  // esté de verdad a la vista (debajo del aviso y la barra) y solo entonces
  // se le hace clic.
  async function aLaVista(locator) {
    let antes = null;
    for (let i = 0; i < 50; i++) {
      if (await locator.count()) {
        const c = await locator.first().boundingBox().catch(() => null);
        const alto = p.viewportSize().height;
        if (c && c.y >= 200 && c.y + Math.min(c.height, 50) <= alto - 70) return;
        // Ya no se mueve (principio o final de la página): basta con que se
        // vea entero.
        if (c && antes && Math.abs(c.y - antes.y) < 1 && c.y >= 185 && c.y + c.height <= alto) return;
        antes = c;
        await p.mouse.move(700, Math.min(600, alto - 100));
        await p.mouse.wheel(0, !c || c.y > alto / 2 ? 280 : -280);
      } else {
        await p.mouse.move(700, 600);
        await p.mouse.wheel(0, 350);
      }
      await p.waitForTimeout(200);
    }
    throw new Error(`No se pudo ver: ${locator}`);
  }
  const alcanzar = (locator) => aLaVista(locator);
  // Texto visible o etiqueta de accesibilidad (Flutter une los textos de un
  // bloque en una sola etiqueta).
  const conTexto = (t) =>
    p.getByText(t, { exact: false }).or(p.locator(`flt-semantics[aria-label*="${t.replaceAll('"', '\\"')}"]`)).first();
  // Escribe sin tocar otros campos: no borra nada si el foco no está en el
  // campo correcto.
  async function escribirAbajo(etiqueta, valor) {
    const c = campo(p, etiqueta);
    for (let intento = 0; intento < 5; intento++) {
      await aLaVista(c);
      await p.waitForTimeout(120 + intento * 200);
      await c.click();
      await p.waitForTimeout(120 + intento * 200);
      if (!(await c.evaluate((el) => document.activeElement === el))) continue;
      await p.keyboard.press('Control+A');
      await p.keyboard.press('Delete');
      await c.fill(valor);
      await p.waitForTimeout(100);
      if (await c.evaluate((el, v) => document.activeElement === el && el.value === v, valor)) return;
    }
    throw new Error(`No se pudo escribir en "${etiqueta}"`);
  }
  async function hacerClic(locator) {
    await aLaVista(locator);
    await locator.first().click();
    await p.waitForTimeout(300);
  }
  const tocarAbajo = (nombre) => hacerClic(exacto(nombre));
  async function alInicio() {
    await p.mouse.move(700, 500);
    for (let i = 0; i < 6; i++) await p.mouse.wheel(0, -3000);
    await p.waitForTimeout(400);
  }
  // Pulsa todos los chips [nombre] de la página (o del diálogo), en orden.
  async function pulsarTodosBajando(nombre) {
    const n = await todos(nombre).count();
    for (let i = 0; i < n; i++) {
      const l = todos(nombre).nth(i);
      await aLaVista(l);
      await l.click();
      await p.waitForTimeout(80);
    }
    return n;
  }
  async function abrirFicha(documento) {
    await pulsar(p, 'Pacientes');
    await escribir(p, 'Buscar paciente', documento);
    await p.keyboard.press('Enter');
    await texto(p, 'Ficha del paciente').waitFor();
  }
  async function aprobarConfirmando() {
    await p.getByRole('button', { name: 'Aprobar', exact: true }).click();
    await p.waitForTimeout(700);
  }

  // Ajustes: consentimiento informado, política, plan, protocolo y prestador.
  await pulsar(p, 'Ajustes');
  await texto(p, 'Plantillas de documentos').waitFor();
  await pulsar(p, 'Aprobar v1'); // La primera pendiente: el consentimiento informado.
  await texto(p, 'Consentimiento informado de procedimiento').waitFor();
  await aprobarConfirmando();
  await pulsar(p, 'Aprobar v1'); // La política.
  await aprobarConfirmando();
  await hacerClic(p.getByRole('button', { name: 'Aprobar v1' })); // «Déficit moderado».
  await texto(p, 'Déficit moderado').waitFor();
  await aprobarConfirmando();
  await hacerClic(p.getByRole('button', { name: 'Editar borrador' }).last());
  await texto(p, 'Hidrolipoclasia · borrador v1').waitFor({ timeout: 15000 });
  // Protocolo sintético de prueba (no es una recomendación clínica).
  await escribirAbajo('Componentes de la solución (uno por línea)', 'Componente A de prueba\nComponente B de prueba');
  await escribirAbajo('Volumen máximo por zona', '500');
  await escribirAbajo('Volumen máximo por sesión', '1000');
  await escribirAbajo('Intervalo entre sesiones', '7');
  await escribirAbajo('Número de sesiones', '4');
  await escribirAbajo('Días hasta el control', '7');
  await hacerClic(p.getByRole('button', { name: 'Quitar el anestésico' }).last());
  await escribirAbajo('Anestésico', 'Anestésico de prueba');
  await escribirAbajo('Concentración', '20');
  await escribirAbajo('Máximo', '7');
  await escribirAbajo('Indicaciones posteriores', 'Indicaciones de prueba.');
  await escribirAbajo('Riesgos (frecuentes y graves)', 'Riesgos de prueba.');
  await escribirAbajo('Alternativas', 'Alternativas de prueba.');
  await captura(p, 'h0_editor_protocolo.png');
  await tocarAbajo('Guardar borrador');
  await texto(p, 'Borrador v1 guardado').waitFor();
  await hacerClic(p.getByRole('button', { name: 'Aprobar v1' }).last());
  await texto(p, '¿Aprobar la versión 1?').waitFor();
  await aprobarConfirmando();
  if (await p.getByText(/Para aprobarla falta/).count()) {
    throw new Error('La plantilla del procedimiento no se aprobó');
  }
  await escribirAbajo('Código de prestador (REPS)', '00000-PRUEBA');
  await escribirAbajo('Habilitación del servicio', 'Servicio de prueba');
  await escribirAbajo('Aseguradora de la póliza', 'Aseguradora de prueba');
  await escribirAbajo('Número de la póliza', 'P-0001');
  await hacerClic(p.getByRole('button', { name: 'Guardar datos del prestador' }));
  await texto(p, 'Datos del prestador guardados').waitFor();
  paso('Ajustes: consentimiento informado y plan aprobados; protocolo de hidrolipoclasia escrito y aprobado; prestador y póliza');

  // Programa de peso (Peña): meta, plan, contraindicaciones y GLP-1.
  await abrirFicha('1032456789');
  await tocar('Peso');
  await texto(p, 'Sin programa de peso.').waitFor();
  await tocar('Iniciar programa');
  await escribir(p, 'Peso meta', '58');
  await escribir(p, 'Proteína indicada', '1,2 g/kg/día');
  await p.getByText('Sin plan').first().click();
  await p.waitForTimeout(400);
  await p
    .getByRole('menuitem', { name: /Déficit moderado \(v1\)/ })
    .or(p.getByRole('option', { name: /Déficit moderado \(v1\)/ }))
    .or(p.locator('flt-semantics[aria-label*="Déficit moderado (v1)"]'))
    .or(p.locator('flt-semantics[flt-tappable]').filter({ hasText: 'Déficit moderado (v1)' }))
    .last()
    .click();
  await p.waitForTimeout(400);
  await todos('Iniciar programa').last().click();
  await texto(p, 'PROGRAMA DE PESO · desde').waitFor();
  await tocar('Revisar contraindicaciones');
  await texto(p, 'Contraindicaciones del GLP-1').waitFor();
  await pulsarTodosBajando('No');
  await pulsar(p, 'Guardar revisión');
  await texto(p, 'Contraindicaciones revisadas el').waitFor();
  await tocar('Iniciar GLP-1');
  await texto(p, 'Invima 2019M-0019473').waitFor();
  await escribir(p, 'Dosis', '0,25');
  await todos('Iniciar').last().click();
  await texto(p, 'Dosis  ').waitFor();
  await alInicio();
  await alcanzar(conTexto('PROGRAMA DE PESO · desde'));
  await captura(p, 'w1_programa_peso.png');
  paso('Programa de peso: meta 58 kg, plan «Déficit moderado», contraindicaciones en «no» y semaglutida 0,25 mg (copiada a la evolución)');

  // Valoración estética (Muñoz).
  await abrirFicha('52222333');
  await tocar('Estética');
  await texto(p, 'Sin valoración').waitFor();
  await tocar('Nueva valoración');
  await texto(p, 'Valoración · Hidrolipoclasia').waitFor();
  await tocarAbajo('Abdomen inferior');
  await tocarAbajo('Flancos');
  // Todo en «No» y en 0 (contraindicaciones, SCOFF, DCQ; también la grasa
  // pinzable y la flacidez de las zonas, que se corrigen después).
  await pulsarTodosBajando('No');
  await pulsarTodosBajando('0');
  await hacerClic(todos('Sí').nth(0)); // Grasa pinzable: Abdomen inferior.
  await hacerClic(todos('Sí').nth(1)); // Grasa pinzable: Flancos.
  await escribirAbajo('Pinzable (Abdomen inferior)', '3');
  await escribirAbajo('Pinzable (Flancos)', '2');
  await tocarAbajo('Realistas');
  await tocarAbajo('Apto');
  await texto(p, 'Vale 90 días desde hoy').waitFor();
  await alInicio();
  await captura(p, 'v1_valoracion.png');
  await aLaVista(todos('Sellar valoración en la historia'));
  const hv2 = await descargar(p, () => todos('Sellar valoración en la historia').first().click());
  if (path.basename(hv2) !== 'Historia_MUNOZ_52222333_v2.pdf') throw new Error(`Historia: ${path.basename(hv2)}`);
  await texto(p, 'Ficha del paciente').waitFor();
  paso(`Valoración «apto» sellada como evolución → ${path.basename(hv2)}`);

  // Sesión sin consentimiento: el botón dice por qué.
  await tocar('Estética');
  await tocarAbajo('Registrar sesión');
  await texto(p, 'Falta el consentimiento firmado.').waitFor();
  await captura(p, 's0_sesion_sin_consentimiento.png');
  if (await p.getByRole('button', { name: 'Sellar sesión' }).isEnabled()) {
    throw new Error('Sin consentimiento se puede sellar la sesión');
  }
  paso('Sesión bloqueada por falta de consentimiento: «Falta el consentimiento firmado.»');

  // Consentimiento informado con firma.
  await pulsar(p, 'Volver a la ficha');
  await texto(p, 'Ficha del paciente').waitFor();
  await tocar('Estética');
  await tocarAbajo('Firmar consentimiento');
  await texto(p, 'Plan de tratamiento · Hidrolipoclasia').waitFor();
  await pulsar(p, 'Continuar a la firma');
  await texto(p, 'Hidrolipoclasia, en Abdomen inferior, Flancos, en 4 sesiones').waitFor();
  await p.getByRole('checkbox', { name: /El paciente leyó/ }).click();
  await firmarEnPantalla();
  await captura(p, 'c1_consentimiento_informado.png');
  const ci = await descargar(p, () => pulsar(p, 'Firmar y descargar PDF'));
  if (path.basename(ci) !== 'Consentimiento_informado_MUNOZ_CI-000001.pdf') throw new Error(`CI: ${path.basename(ci)}`);
  await texto(p, 'CI-000001 · 4 sesiones').waitFor();
  paso(`Consentimiento informado por plan (4 sesiones, abdomen inferior y flancos) firmado → ${path.basename(ci)}`);

  // Sesión: un lote vencido bloquea; corregido, se sella.
  await tocarAbajo('Registrar sesión');
  await texto(p, 'Sesión 1 de 4 · Hidrolipoclasia').waitFor();
  // Solo la lista de verificación (los chips de zona también son casillas).
  const verificacion = [
    'Consentimiento vigente',
    'Valoración vigente',
    'Mayor de edad',
    'Alergias revisadas',
    'Anticoagulación descartada',
    'Embarazo descartado',
    'Sin infección en la zona',
    'Signos vitales tomados',
    'Lotes vigentes',
    'Equipo verificado',
    'Emulsión lipídica y protocolo de toxicidad disponibles',
  ];
  for (const item of verificacion) {
    const c = p.getByRole('checkbox', { name: item, exact: true });
    if (!(await c.isChecked())) await hacerClic(c);
    if (!(await c.isChecked())) throw new Error(`«${item}» sin marcar`);
  }
  await escribirAbajo('Volumen (Abdomen inferior)', '300');
  await escribirAbajo('Volumen (Flancos)', '200');
  for (const n of ['Componente A de prueba', 'Componente B de prueba']) {
    await escribirAbajo(`Lote (${n})`, 'C-0001');
    await escribirAbajo(`Vence (${n})`, '31/03/2027');
  }
  await escribirAbajo('Volumen del anestésico', '10');
  await escribirAbajo('Lote (Anestésico de prueba)', 'L2345');
  await escribirAbajo('Vence (Anestésico de prueba)', '01/11/2026');
  await escribirAbajo('Peso de hoy', '64');
  await escribirAbajo('Duración', '45');
  await texto(p, 'El lote L2345 de «Anestésico de prueba» venció el 01/11/2026.').waitFor();
  await aLaVista(campo(p, 'Volumen del anestésico'));
  await captura(p, 's1_sesion_lote_vencido.png');
  paso('Sesión bloqueada por lote vencido: «El lote L2345 … venció el 01/11/2026.»');
  await escribirAbajo('Vence (Anestésico de prueba)', '31/03/2027');
  await texto(p, 'Lista para sellar').waitFor();
  await texto(p, '200 mg · 3,1 mg/kg').waitFor();
  await captura(p, 's2_sesion.png');
  await alInicio();
  await p.setViewportSize({ width: 820, height: 1180 });
  await p.waitForTimeout(900);
  await captura(p, 's3_sesion_tableta.png');
  await p.setViewportSize({ width: 320, height: 640 });
  await p.waitForTimeout(900);
  await captura(p, 's4_sesion_320.png');
  await p.setViewportSize({ width: 1440, height: 1000 });
  await p.waitForTimeout(900);
  const hv3 = await descargar(p, () => pulsar(p, 'Sellar sesión'));
  if (path.basename(hv3) !== 'Historia_MUNOZ_52222333_v3.pdf') throw new Error(`Historia: ${path.basename(hv3)}`);
  try {
    const t = execFileSync('pdftotext', [hv3, '-'], { encoding: 'utf8' }).replace(/\s+/g, ' ');
    for (const esperado of ['Valoración para Hidrolipoclasia', 'Sesión 1 de 4 de Hidrolipoclasia', 'Anestésico de prueba 20 mg/mL, 10 mL', 'lote L2345, vence 31/03/2027', '200 mg · 3,1 mg/kg']) {
      if (!t.includes(esperado)) throw new Error(`La historia no dice «${esperado}»`);
    }
    const paginas = Number(/Pages:\s+(\d+)/.exec(execFileSync('pdfinfo', [hv3], { encoding: 'utf8' }))[1]);
    execFileSync('pdftoppm', ['-r', '90', '-png', '-f', String(paginas), '-l', String(paginas), '-singlefile', hv3, path.join(OUT, 'pdf_historia_sesion')]);
  } catch (e) {
    if (e.code !== 'ENOENT') throw e;
  }
  await texto(p, 'Ficha del paciente').waitFor();
  await tocar('Estética');
  await alcanzar(conTexto('Sesión 1 de 4 ·'));
  await captura(p, 'e1_estetica_ficha.png');
  paso(`Sesión sellada como evolución (lotes, dosis en mg/kg y control) → ${path.basename(hv3)}`);
  // Lo que sigue (móvil) es con la ficha de Peña, la que tiene fotos.
  await abrirFicha('1032456789');

  // ─────────────── 5. Documentos clínicos (5.4) ───────────────
  // Certificado, incapacidad, orden y remisión de Peña desde «Documento»:
  // la plantilla (en borrador) se aprueba en el mismo formulario, se emite
  // y el PDF se lee con pdftotext; después, el certificado y la orden se
  // reimportan y se verifican.
  async function abrirDocumento(menu, titulo) {
    await alInicio();
    await hacerClic(p.getByRole('button', { name: 'Documento', exact: true }));
    // Flutter expone los elementos del menú como botones, pero en el DOM el
    // nodo de accesibilidad de un botón de la ficha («Unir con otra ficha»)
    // queda encima del menú y se lleva el clic: el evento se envía directo
    // al nodo del elemento.
    const item = p
      .getByRole('menuitem', { name: menu, exact: true })
      .or(p.getByRole('button', { name: menu, exact: true }))
      .first();
    await item.waitFor();
    await item.dispatchEvent('click');
    await texto(p, titulo).waitFor();
    await p.waitForTimeout(600);
  }
  async function aprobarAqui() {
    await hacerClic(p.getByRole('button', { name: 'Aprobar v1', exact: true }));
    await texto(p, '¿Aprobar la versión 1?').waitFor();
    await aprobarConfirmando();
    await texto(p, 'Versión 1 · aprobada').waitFor();
  }
  // La vista previa se vuelve a dibujar 300 ms después del último cambio;
  // en Chromium sin GPU puede tardar unos segundos.
  async function vistaPreviaAlDia() {
    await p.waitForTimeout(700);
    await texto(p, 'Actualizando la vista previa').desaparece({ timeout: 60000 });
    await p.waitForTimeout(300);
  }
  async function emitirDocumento(nombreEsperado) {
    const ruta = await descargar(p, () =>
      hacerClic(p.getByRole('button', { name: 'Emitir y descargar', exact: true })),
    );
    if (path.basename(ruta) !== nombreEsperado) throw new Error(`Documento: ${path.basename(ruta)}`);
    await texto(p, 'Ficha del paciente').waitFor();
    return ruta;
  }
  // El texto del PDF (sin pdftotext, no se lee) y la imagen de su primera
  // página para las evidencias.
  function leerDocumento(ruta, esperados, imagen) {
    try {
      const t = execFileSync('pdftotext', [ruta, '-'], { encoding: 'utf8' }).replace(/\s+/g, ' ');
      for (const e of esperados) if (!t.includes(e)) throw new Error(`${path.basename(ruta)} no dice «${e}»`);
      execFileSync('pdftoppm', ['-r', '90', '-png', '-f', '1', '-l', '1', '-singlefile', ruta, path.join(OUT, imagen)]);
      return true;
    } catch (e) {
      if (e.code !== 'ENOENT') throw e;
      return false;
    }
  }

  await abrirDocumento('Certificado', 'Certificado médico ·');
  await texto(p, 'La plantilla «General» está en borrador').waitFor();
  await captura(p, 'd0_certificado_borrador.png');
  await aprobarAqui();
  await escribirAbajo('Se expide con destino a', 'Empresa de prueba S. A. S.');
  await escribirAbajo(
    'Texto del documento',
    'El suscrito médico, Dra. Ana Pérez Gómez, registro profesional RM 54321, certifica que valoró a ' +
      'PEÑA MUÑOZ, José Ángel, identificado(a) con CC 1032456789.\n\n' +
      'Hallazgos: examen físico sin hallazgos de importancia (dato de prueba).\n\n' +
      'Concepto: sin contraindicación para la actividad descrita (dato de prueba).',
  );
  await texto(p, 'Listo para emitir.').waitFor();
  await vistaPreviaAlDia();
  await captura(p, 'd1_certificado.png');
  const ce = await emitirDocumento('Certificado_PENA_CE-000001.pdf');
  leerDocumento(ce, ['CERTIFICADO MÉDICO', 'CE-000001', 'Se expide con destino a', 'Empresa de prueba S. A. S.', 'Hallazgos: examen físico'], 'pdf_certificado');
  paso(`Certificado: plantilla aprobada en el formulario, finalidad y texto → ${path.basename(ce)} (con documento.json)`);

  await abrirDocumento('Incapacidad', 'Incapacidad médica ·');
  await aprobarAqui();
  await escribirAbajo('Diagnóstico', 'Diarrea y gastroenteritis de presunto origen infeccioso');
  await escribirAbajo('CIE-10', 'A09X');
  await escribirAbajo('Días', '3');
  await escribirAbajo(
    'Texto del documento',
    'El suscrito médico, Dra. Ana Pérez Gómez, registro profesional RM 54321, certifica que PEÑA MUÑOZ, ' +
      'José Ángel, identificado(a) con CC 1032456789, requiere incapacidad médica por el diagnóstico, los ' +
      'días y las fechas que se indican en este documento.\n\nRecomendaciones: reposo e hidratación (dato de prueba).',
  );
  await texto(p, 'Falta tu NIT').waitFor();
  await texto(p, 'Listo para emitir, con 1 aviso.').waitFor();
  await vistaPreviaAlDia();
  await captura(p, 'd2_incapacidad.png');
  const inc = await emitirDocumento('Incapacidad_PENA_IN-000001.pdf');
  leerDocumento(inc, ['IN-000001', 'A09X Diarrea y gastroenteritis', '3 (tres)', 'Desde', 'Hasta', 'código REPS 00000-PRUEBA'], 'pdf_incapacidad');
  paso(`Incapacidad de 3 días con CIE-10 y aviso «Falta tu NIT» (no bloquea) → ${path.basename(inc)}`);

  await abrirDocumento('Orden de laboratorio o imágenes', 'Orden de laboratorio o imágenes ·');
  // El texto de un campo sin foco no está en el DOM: se mira la plantilla.
  await texto(p, 'Perfil metabólico').waitFor();
  await aprobarAqui();
  await escribirAbajo('Impresión diagnóstica', 'Obesidad, no especificada');
  await escribirAbajo('CIE-10', 'E669');
  await texto(p, 'Listo para emitir, con 1 aviso.').waitFor();
  await vistaPreviaAlDia();
  await captura(p, 'd3_orden.png');
  const or = await emitirDocumento('Orden_PENA_OR-000001.pdf');
  leerDocumento(or, ['OR-000001', 'Glucosa en ayunas', 'Impresión diagnóstica', 'E669 Obesidad'], 'pdf_orden');
  paso(`Orden con la plantilla «Perfil metabólico» → ${path.basename(or)}`);

  await abrirDocumento('Remisión o interconsulta', 'Remisión o interconsulta ·');
  await aprobarAqui();
  await escribirAbajo('Remitido a', 'Endocrinología');
  await escribirAbajo('Diagnóstico', 'Obesidad, no especificada');
  await escribirAbajo('CIE-10', 'E669');
  await escribirAbajo(
    'Texto del documento',
    'Remito al paciente para valoración y manejo por la especialidad o el servicio que se indica.\n\n' +
      'Motivo de la remisión: dato de prueba.\n\nResumen de la historia clínica: dato de prueba.\n\n' +
      'Tratamiento actual: dato de prueba.\n\nPregunta o solicitud concreta: dato de prueba.',
  );
  await texto(p, 'Listo para emitir.').waitFor();
  const rm = await emitirDocumento('Remision_PENA_RM-000001.pdf');
  leerDocumento(rm, ['RM-000001', 'Remitido a', 'Endocrinología', 'E669 Obesidad'], 'pdf_remision');
  paso(`Remisión a Endocrinología → ${path.basename(rm)}`);

  // El formulario en móvil y a 320 px (pestañas «Editar» y «Vista previa»),
  // sin el aviso de «emitido» encima.
  await texto(p, 'emitido: el PDF se descargó').desaparece({ timeout: 20000 });
  await abrirDocumento('Certificado', 'Certificado médico ·');
  await p.setViewportSize({ width: 390, height: 844 });
  await p.waitForTimeout(900);
  await captura(p, 'd4_formulario_movil.png');
  await p.setViewportSize({ width: 320, height: 640 });
  await p.waitForTimeout(900);
  await captura(p, 'd5_formulario_320.png');
  await p.setViewportSize({ width: 1440, height: 1000 });
  await p.waitForTimeout(900);
  // Está en la barra de arriba (fuera de la zona que mira aLaVista).
  await p.getByRole('button', { name: 'Volver a la ficha' }).first().click();
  await texto(p, 'Ficha del paciente').waitFor();
  await alcanzar(conTexto('RM-000001'));
  await captura(p, 'd6_ficha_documentos.png');
  paso('Formulario en móvil (390 px) y 320 px; la ficha muestra los cuatro documentos con sus datos');

  // Reimportar el certificado y la orden: se verifican contra lo registrado.
  await pulsar(p, 'Pacientes');
  const [selDocs] = await Promise.all([p.waitForEvent('filechooser'), pulsar(p, 'Importar PDF')]);
  await selDocs.setFiles([ce, or]);
  await texto(p, 'Importación terminada').waitFor({ timeout: 60000 });
  await texto(p, '2 de 2 archivos en el índice').waitFor();
  await texto(p, 'Ya estaba, íntegro · CE-000001').waitFor();
  await texto(p, 'Ya estaba, íntegro · OR-000001').waitFor();
  await captura(p, 'd7_reimportacion.png');
  await pulsar(p, 'Cerrar');
  paso('Certificado y orden descargados y reimportados: «Ya estaba, íntegro» (documento.json verificado)');

  // Ajustes → Documentos clínicos: las plantillas con sus versiones.
  await pulsar(p, 'Ajustes');
  await alcanzar(conTexto('Documentos clínicos'));
  await hacerClic(p.getByRole('button', { name: 'Ver las plantillas' }));
  await texto(p, '4 de 12 aprobadas').waitFor();
  await alcanzar(conTexto('Perfil metabólico'));
  await captura(p, 'd8_ajustes_documentos.png');
  paso('Ajustes → Documentos clínicos: 4 de 12 plantillas aprobadas, con versiones y «Agregar plantilla»');
  await abrirFicha('1032456789');

  // ─────────────── 6. Agenda (5.5) ───────────────
  // Reloj del navegador fijado al lunes 30/11/2026, 9:15 (las capturas no
  // dependen del día de la corrida). WhatsApp no se abre: window.open queda
  // interceptado y solo se anota el enlace.
  await p.clock.setFixedTime(new Date('2026-11-30T09:15:00-05:00'));
  // Botones por su nombre exacto («Agenda» no es «Agendar cita»; «Día» no
  // es «Día anterior»).
  // (el riel nombra sus destinos «Agenda Pestaña 1 de 4»; «Día» y «Semana»
  // son radios).
  const exactoBoton = (nombre) =>
    p
      .getByRole('button', { name: nombre, exact: true })
      .or(p.getByRole('tab', { name: nombre, exact: true }))
      .or(p.getByRole('radio', { name: nombre, exact: true }))
      .or(p.getByRole('button', { name: new RegExp(`^${nombre}\\s+Pestaña`) }))
      .first();
  async function pulsarExacto(nombre) {
    await exactoBoton(nombre).click();
    await p.waitForTimeout(400);
  }
  // Las horas libres son chips: no siempre tienen el rol «button». El clic
  // va directo al nodo (en un diálogo, otro nodo de atrás puede taparlo).
  async function elegirHora(hora) {
    const chip = p
      .getByRole('button', { name: hora, exact: true })
      .or(p.locator(`flt-semantics[aria-label="${hora}"]`))
      .or(p.locator('flt-semantics[flt-tappable]').filter({ hasText: new RegExp(`^${hora}$`) }))
      .last();
    await chip.waitFor();
    await chip.dispatchEvent('click');
    await p.waitForTimeout(400);
  }
  await p.evaluate(() => {
    window.__enlaces = [];
    window.open = (url) => {
      window.__enlaces.push(String(url));
      return null;
    };
  });
  // Desde la ficha de Peña: «Agendar cita», un control a las 10:00.
  await alInicio();
  await hacerClic(p.getByRole('button', { name: 'Agendar cita', exact: true }));
  await texto(p, 'Nueva cita').waitFor();
  await elegirHora('10:00');
  await escribir(p, 'Motivo', 'Control de tiroides');
  await p.getByRole('button', { name: 'Agendar', exact: true }).click();
  await texto(p, 'Próxima cita 30/11/2026 10:00 · Control').waitFor();
  paso('Desde la ficha: «Agendar cita» con la hora libre de las 10:00; la ficha muestra la próxima cita');

  // En la agenda: otra cita hoy (Muñoz, valoración estética, buscada por
  // nombre) y una para mañana (Gómez, primera vez).
  await pulsarExacto('Agenda');
  await texto(p, 'lunes 30/11/2026').waitFor();
  async function nuevaCita({ busqueda, tipo, dia, hora }) {
    await p.getByRole('button', { name: 'Cita', exact: true }).click();
    await texto(p, 'Nueva cita').waitFor();
    await escribir(p, 'Paciente', busqueda);
    await p.waitForTimeout(500);
    await p.keyboard.press('Enter'); // la primera sugerencia
    await p.waitForTimeout(400);
    // El nombre queda en el campo (sin foco no está en el DOM): basta con
    // que ya no falte el paciente.
    await texto(p, 'Elige el paciente.').desaparece({ timeout: 10000 });
    if (tipo) {
      // La lista se llama «Tipo de cita Control».
      await p.getByRole('button', { name: /^Tipo de cita/ }).last().dispatchEvent('click');
      await p.waitForTimeout(400);
      await p
        .getByRole('menuitem', { name: tipo, exact: true })
        .or(p.getByRole('option', { name: tipo, exact: true }))
        .or(p.locator(`flt-semantics[aria-label="${tipo}"]`))
        .or(p.locator('flt-semantics[flt-tappable]').filter({ hasText: new RegExp(`^${tipo}$`) }))
        .last()
        .dispatchEvent('click');
      await p.waitForTimeout(400);
    }
    if (dia) {
      await escribir(p, 'Día', dia);
      await p.keyboard.press('Tab');
      await p.waitForTimeout(400);
    }
    await elegirHora(hora);
    await p.getByRole('button', { name: 'Agendar', exact: true }).click();
    await texto(p, 'Cita agendada').waitFor();
    await texto(p, 'Cita agendada').desaparece({ timeout: 20000 });
  }
  await nuevaCita({ busqueda: 'munoz maria', tipo: 'Valoración estética', hora: '10:20' });
  await nuevaCita({ busqueda: 'gomez', dia: '01/12/2026', hora: '08:00' });
  await pulsarExacto('Hoy');
  await texto(p, 'lunes 30/11/2026').waitFor();
  await texto(p, '10:00–10:20').waitFor();
  await texto(p, '10:20–11:00').waitFor();
  await texto(p, 'Mañana: 1 cita sin recordatorio').waitFor();
  await captura(p, 'g1_agenda_dia.png');
  paso('Agenda del día: dos citas (una buscada por nombre, con su procedimiento) y el aviso de la de mañana sin recordatorio');

  // Estado, WhatsApp interceptado y .ics.
  await alInicio();
  await p.getByRole('button', { name: 'Estado', exact: true }).last().click();
  await p.waitForTimeout(300);
  await p
    .getByRole('menuitem', { name: 'Confirmada', exact: true })
    .or(p.getByRole('button', { name: 'Confirmada', exact: true }))
    .last()
    .dispatchEvent('click');
  await texto(p, 'Confirmada').waitFor();
  await p.getByRole('button', { name: 'WhatsApp', exact: true }).first().click();
  await texto(p, 'Recordatorio por WhatsApp').waitFor();
  await captura(p, 'g2_whatsapp.png');
  await p.getByRole('button', { name: 'Abrir WhatsApp', exact: true }).click();
  await texto(p, 'Recordatorio enviado').waitFor();
  const enlaces = await p.evaluate(() => window.__enlaces);
  if (enlaces.length !== 1 || !enlaces[0].startsWith('https://wa.me/573001234567?text=Hola%20Jos%C3%A9')) {
    throw new Error(`Enlace de WhatsApp: ${enlaces}`);
  }
  const mensaje = decodeURIComponent(enlaces[0].split('text=')[1]);
  for (const prohibido of ['Control', 'tiroides', 'Valoración']) {
    if (mensaje.includes(prohibido)) throw new Error(`El mensaje dice «${prohibido}»: ${mensaje}`);
  }
  const ics = await descargar(p, () => p.getByRole('button', { name: '.ics', exact: true }).first().click());
  if (path.basename(ics) !== 'Cita_2026-11-30_1000.ics') throw new Error(`.ics: ${path.basename(ics)}`);
  const textoIcs = fs.readFileSync(ics, 'utf8');
  if (!textoIcs.includes('SUMMARY:Cita médica') || /PEÑA|tiroides|Control/.test(textoIcs)) {
    throw new Error(`.ics con datos de más: ${textoIcs}`);
  }
  paso(`Estado «Confirmada»; WhatsApp interceptado (wa.me/57…, sin datos de salud) y ${path.basename(ics)} solo con «Cita médica»`);

  // Semana.
  await pulsarExacto('Semana');
  await texto(p, 'Semana del 30/11/2026 al 06/12/2026').waitFor();
  await texto(p, 'martes 1').waitFor();
  await captura(p, 'g3_agenda_semana.png');
  await pulsarExacto('Día');
  paso('Vista de semana: una columna por día con bloques por tipo (color e ícono)');

  // Atender: la historia más reciente de Peña con una evolución nueva.
  await texto(p, 'lunes 30/11/2026').waitFor();
  await p.getByRole('button', { name: 'Atender', exact: true }).first().click();
  await p.waitForTimeout(800);
  if (await p.getByText('¿Reemplazar la historia en curso?').count()) {
    await p.getByRole('button', { name: 'Reemplazar', exact: true }).click();
  }
  // La franja lleva la flecha como ícono y «Ficha» como texto.
  await texto(p, 'Historia abierta').waitFor({ timeout: 30000 });
  await texto(p, 'PEÑA MUÑOZ, José Ángel').waitFor();
  await captura(p, 'g4_atender_historia.png');
  await pulsarExacto('Agenda');
  await texto(p, 'Atendida').waitFor();
  paso('«Atender»: la historia de Peña con la evolución nueva y la franja «← Ficha»; la cita queda atendida');

  // Móvil: solo la vista de día.
  await p.setViewportSize({ width: 390, height: 844 });
  await p.waitForTimeout(900);
  await captura(p, 'g5_agenda_movil.png');
  await p.setViewportSize({ width: 320, height: 640 });
  await p.waitForTimeout(900);
  await captura(p, 'g6_agenda_320.png');
  await p.setViewportSize({ width: 1440, height: 1000 });
  await p.waitForTimeout(900);
  paso('Agenda en móvil (390 px) y 320 px: solo la vista de día');

  // ─────────────── 7. Caja (5.6) ───────────────
  // Los valores en pesos llevan separador de miles al escribirlos.
  async function escribirPesos(etiqueta, valor) {
    const esperado = Number(valor).toLocaleString('de-DE');
    const c = campo(p, etiqueta);
    for (let intento = 0; intento < 4; intento++) {
      await c.scrollIntoViewIfNeeded();
      await p.waitForTimeout(150 + intento * 300);
      await c.click();
      await p.waitForTimeout(150 + intento * 300);
      await p.keyboard.press('Control+A');
      await p.keyboard.press('Delete');
      await c.fill(valor);
      await p.waitForTimeout(300);
      if (await c.evaluate((el, v) => el.value === v, esperado)) return;
    }
    throw new Error(`No se pudo escribir ${valor} en "${etiqueta}"`);
  }
  // Una opción de una lista desplegable (se llama «Etiqueta Valor»).
  async function elegirOpcion(lista, opcion) {
    await p.getByRole('button', { name: new RegExp(`^${lista}`) }).last().dispatchEvent('click');
    await p.waitForTimeout(400);
    await p
      .getByRole('menuitem', { name: opcion, exact: true })
      .or(p.getByRole('option', { name: opcion, exact: true }))
      .or(p.locator(`flt-semantics[aria-label="${opcion}"]`))
      .or(p.locator('flt-semantics[flt-tappable]').filter({ hasText: new RegExp(`^${opcion}$`) }))
      .last()
      .dispatchEvent('click');
    await p.waitForTimeout(400);
  }
  const registrarRecibo = (nombre) =>
    descargar(p, async () => {
      await p.getByRole('button', { name: 'Registrar y descargar el recibo', exact: true }).click();
    }).then((ruta) => {
      if (path.basename(ruta) !== nombre) throw new Error(`Recibo: ${path.basename(ruta)}`);
      return ruta;
    });
  async function elegirPacienteCobro(busqueda) {
    await escribir(p, 'Paciente', busqueda);
    await p.waitForTimeout(500);
    await p.keyboard.press('Enter');
    await p.waitForTimeout(400);
    await texto(p, 'Elige el paciente.').desaparece({ timeout: 10000 });
  }

  // Desde la cita atendida de Peña: «Cobrar» sugiere el control; abona
  // 20.000 en efectivo y queda el saldo.
  await alInicio();
  await texto(p, 'lunes 30/11/2026').waitFor();
  await p.getByRole('button', { name: 'Cobrar', exact: true }).first().click();
  await texto(p, 'SERVICIOS').waitFor();
  await texto(p, 'Control').waitFor();
  await escribirPesos('Valor', '20000');
  await texto(p, 'Es un abono: queda un saldo de $ 25.000.').waitFor();
  await captura(p, 'h1_cobro.png');
  const rc1 = await registrarRecibo('Recibo_RC-000001.pdf');
  await texto(p, 'Saldo $ 25.000').waitFor();
  const leidoRc1 = leerDocumento(
    rc1,
    [
      'RECIBO DE CAJA',
      'RC-000001',
      'PEÑA MUÑOZ, José Ángel',
      'Control',
      'Efectivo',
      '$ 20.000',
      'Saldo $ 25.000',
      'Este documento no es una factura electrónica de venta.',
    ],
    'pdf_recibo',
  );
  paso(
    `Cobro desde la cita con abono de $ 20.000 → ${path.basename(rc1)}` +
      (leidoRc1 ? ' (pdftotext: saldo $ 25.000 y «no es una factura electrónica de venta»)' : ''),
  );

  // La valoración de Muñoz, por transferencia con referencia: deja el
  // crédito de 30 días.
  await p.getByRole('button', { name: 'Cobrar', exact: true }).nth(1).click();
  await texto(p, 'Valoración estética (abonable al tratamiento)').waitFor();
  await elegirOpcion('Medio de pago 1', 'Transferencia');
  await escribir(p, 'Referencia', 'TR-0042');
  const rc2 = await registrarRecibo('Recibo_RC-000002.pdf');
  await texto(p, 'Cobrada').waitFor();

  // En la caja: el paquete de 4 sesiones con el crédito aplicado, con tarjeta.
  await pulsarExacto('Caja');
  await texto(p, 'Caja abierta').waitFor();
  await p.getByRole('button', { name: 'Cobrar', exact: true }).first().click();
  await texto(p, 'SERVICIOS').waitFor();
  await elegirPacienteCobro('munoz maria');
  await elegirOpcion('Servicio', 'Paquete de 4 sesiones');
  await texto(p, 'Aplicar el crédito de la valoración').waitFor();
  await texto(p, '$ 810.000').waitFor();
  await elegirOpcion('Medio de pago 1', 'Tarjeta');
  const rc3 = await registrarRecibo('Recibo_RC-000003.pdf');
  leerDocumento(rc3, ['RC-000003', 'Paquete de 4 sesiones', 'Crédito de la valoración', '$ 810.000', 'Tarjeta'], 'pdf_recibo_paquete');
  paso(`Valoración por transferencia (${path.basename(rc2)}) y paquete de 4 sesiones con su crédito de $ 70.000 → ${path.basename(rc3)}`);

  // Usar una sesión del paquete: sin cobro ni recibo.
  await p.getByRole('button', { name: 'Cobrar', exact: true }).first().click();
  await texto(p, 'SERVICIOS').waitFor();
  await elegirPacienteCobro('munoz maria');
  await texto(p, 'Paquete de 4 sesiones: quedan 4 de 4.').waitFor();
  await p.getByRole('button', { name: 'Usar una sesión (sin cobro)', exact: true }).click();
  await p.getByRole('button', { name: 'Usar la sesión', exact: true }).click();
  await texto(p, 'sesión 1 de 4 usada (sin recibo)').waitFor();
  await texto(p, 'Sesiones de paquete').waitFor();
  paso('Sesión 1 de 4 del paquete usada desde el cobro: sin recibo; la caja la lista aparte');

  // Saldos por cobrar → Abonar: el pago toma el saldo de Peña.
  await hacerClic(p.getByRole('button', { name: 'Abonar', exact: true }));
  await texto(p, 'Saldo').waitFor();
  const rc4 = await registrarRecibo('Recibo_RC-000004.pdf');
  await texto(p, 'Nadie debe nada.').waitFor();
  await alInicio();
  await texto(p, 'Totales del día').waitFor();
  await texto(p, '$ 925.000').waitFor();
  await texto(p, 'Recibo RC-000004 descargado').desaparece({ timeout: 20000 });
  await captura(p, 'h2_caja_dia.png');
  paso(`Abono del saldo de Peña → ${path.basename(rc4)}; totales por medio: efectivo $ 45.000, transferencia $ 70.000, tarjeta $ 810.000`);

  // Informe del mes y su CSV (Excel en español).
  await pulsarExacto('Informe del mes');
  await texto(p, 'Noviembre de 2026').waitFor();
  await texto(p, 'Volumen por técnica').waitFor();
  await captura(p, 'h3_informe.png');
  const csvMes = await descargar(p, () => hacerClic(p.getByRole('button', { name: 'CSV del mes', exact: true })));
  const bytesCsv = fs.readFileSync(csvMes);
  const textoCsv = bytesCsv.toString('utf8');
  if (
    path.basename(csvMes) !== 'Informe_caja_2026-11.csv' ||
    bytesCsv[0] !== 0xef ||
    bytesCsv[1] !== 0xbb ||
    bytesCsv[2] !== 0xbf ||
    !textoCsv.includes('Mes;Sección;Concepto;Línea;Cantidad;Bruto;Descuentos;Neto\r\n') ||
    !textoCsv.includes('2026-11;Servicio;Paquete de 4 sesiones;Estética;1;880000;0;880000') ||
    !textoCsv.includes('2026-11;Créditos aplicados;Valoraciones abonadas;;;;70000;-70000') ||
    !textoCsv.includes('2026-11;Recaudo;Tarjeta;;;;;810000')
  ) {
    throw new Error(`CSV del mes: ${path.basename(csvMes)}\n${textoCsv}`);
  }
  paso(`Informe del mes por servicio, línea, recaudo y volumen por técnica → ${path.basename(csvMes)} (UTF-8 con BOM, «;»)`);

  // Cierre del día: efectivo contado, sin diferencia; se ofrece el respaldo.
  await pulsarExacto('Día');
  await texto(p, 'Totales del día').waitFor();
  await hacerClic(p.getByRole('button', { name: 'Cerrar la caja', exact: true }));
  await texto(p, 'Cerrar la caja de hoy').waitFor();
  await escribirPesos('Efectivo contado', '45000');
  await texto(p, 'Sin diferencia').waitFor();
  await p.getByRole('button', { name: 'Cerrar la caja', exact: true }).last().click();
  await texto(p, '¿Descargas ahora un respaldo').waitFor();
  const respaldoCierre = await descargar(p, () =>
    p.getByRole('button', { name: 'Descargar el respaldo', exact: true }).click(),
  );
  if (!respaldoCierre.endsWith('.hcrespaldo')) throw new Error(`Respaldo: ${respaldoCierre}`);
  await texto(p, 'Caja cerrada a las 09:15').waitFor();
  await texto(p, 'Respaldo descargado').desaparece({ timeout: 20000 });
  if (await p.getByRole('button', { name: 'Anular RC-000001', exact: true }).count()) {
    throw new Error('Con la caja cerrada no se ofrece anular');
  }
  await alInicio();
  await captura(p, 'h4_cierre.png');
  const csvDia = fs.readFileSync(
    await descargar(p, () => hacerClic(p.getByRole('button', { name: 'CSV del día', exact: true }))),
    'utf8',
  );
  if (!csvDia.includes(';Efectivo contado;Efectivo;45000;Cierre') || !csvDia.includes('RC-000004')) {
    throw new Error(`CSV del día:\n${csvDia}`);
  }
  paso(`Cierre del día con el efectivo contado (sin diferencia), respaldo ofrecido y descargado (${path.basename(respaldoCierre)}) y CSV del día`);

  await p.setViewportSize({ width: 390, height: 844 });
  await p.waitForTimeout(900);
  await captura(p, 'h5_caja_movil.png');
  await p.setViewportSize({ width: 320, height: 640 });
  await p.waitForTimeout(900);
  await captura(p, 'h6_caja_320.png');
  await p.setViewportSize({ width: 1440, height: 1000 });
  await p.waitForTimeout(900);
  paso('Caja en móvil (390 px) y 320 px');

  // ─────────────── 8. Inventario (5.7) ───────────────
  async function nuevoInsumo({ nombre, unidad, contenido, concentracion, minimo, registro, inyectable }) {
    await p.getByRole('button', { name: 'Insumo', exact: true }).click();
    await texto(p, 'Insumo nuevo').waitFor();
    await escribir(p, 'Nombre', nombre);
    await escribir(p, 'Unidad', unidad);
    if (contenido) await escribir(p, 'Contenido por unidad', contenido);
    if (concentracion) await escribir(p, 'Concentración', concentracion);
    if (minimo) await escribir(p, 'Mínimo', minimo);
    if (registro) await escribir(p, 'Registro Invima', registro);
    if (inyectable) {
      await p
        .getByRole('switch', { name: /Inyectable/ })
        .or(p.getByRole('checkbox', { name: /Inyectable/ }))
        .first()
        .click();
      await p.waitForTimeout(300);
    }
    if (!registro) await texto(p, 'no tiene registro Invima').waitFor();
    await p.getByRole('button', { name: 'Guardar el insumo', exact: true }).click();
    await texto(p, `Insumo «${nombre}» guardado.`).waitFor();
  }
  async function nuevaEntrada({ insumo, lote, vence, cantidad, aviso }) {
    await p.getByRole('button', { name: 'Entrada', exact: true }).first().click();
    await texto(p, 'Entrada de un lote').waitFor();
    await elegirOpcion('Insumo', insumo);
    await escribir(p, 'Lote', lote);
    await escribir(p, 'Cantidad', cantidad);
    await escribir(p, 'Vence', vence);
    await p.keyboard.press('Tab');
    if (aviso) await texto(p, aviso).waitFor();
    await p.getByRole('button', { name: 'Registrar la entrada', exact: true }).click();
    await texto(p, `Entrada registrada: lote ${lote}`).waitFor();
    await texto(p, `Entrada registrada: lote ${lote}`).desaparece({ timeout: 20000 });
  }

  await pulsarExacto('Inventario');
  await texto(p, 'Inventario vacío').waitFor();
  await nuevoInsumo({
    nombre: 'Anestésico de prueba',
    unidad: 'ampolla',
    contenido: '5',
    concentracion: '20',
    minimo: '5',
    registro: 'INVIMA PRUEBA-0001',
  });
  await nuevoInsumo({ nombre: 'Componente A de prueba', unidad: 'frasco', inyectable: true });
  await texto(p, '«Componente A de prueba» es inyectable y no tiene registro Invima').waitFor();
  // Un lote que se ingresó el 01/10/2026 y venció el 31/10/2026.
  await p.clock.setFixedTime(new Date('2026-10-01T09:00:00-05:00'));
  await nuevaEntrada({ insumo: 'Anestésico de prueba', lote: 'L-OCT', vence: '31/10/2026', cantidad: '2', aviso: 'Vence en 30 días.' });
  await p.clock.setFixedTime(new Date('2026-11-30T09:15:00-05:00'));
  // Hoy: un lote vencido no se ingresa.
  await p.getByRole('button', { name: 'Entrada', exact: true }).first().click();
  await texto(p, 'Entrada de un lote').waitFor();
  await elegirOpcion('Insumo', 'Anestésico de prueba');
  await escribir(p, 'Lote', 'L0000');
  await escribir(p, 'Cantidad', '1');
  await escribir(p, 'Vence', '01/11/2026');
  await p.keyboard.press('Tab');
  await texto(p, 'El lote L0000 venció el 01/11/2026: no se ingresa.').waitFor();
  if (await p.getByRole('button', { name: 'Registrar la entrada', exact: true }).isEnabled()) {
    throw new Error('Un lote vencido se puede ingresar');
  }
  await p.getByRole('button', { name: 'Cancelar', exact: true }).click();
  await nuevaEntrada({ insumo: 'Anestésico de prueba', lote: 'L7788', vence: '15/12/2026', cantidad: '6', aviso: 'Vence en 15 días.' });
  await nuevaEntrada({ insumo: 'Componente A de prueba', lote: 'CA-01', vence: '30/06/2027', cantidad: '3' });
  paso('Inventario: un insumo con registro y uno inyectable sin él (aviso); un lote ingresado el 01/10/2026 que ya venció; un lote vencido no se ingresa');

  await alInicio();
  await texto(p, '1 lote vencido con existencias').waitFor();
  await texto(p, '1 lote vence en 30 días o menos').waitFor();
  await texto(p, '1 insumo sin registro Invima').waitFor();
  await texto(p, 'Vence en 15 días').waitFor();
  await captura(p, 'i1_inventario.png');
  await p.getByRole('button', { name: 'Consultar en Invima', exact: true }).first().click();
  await p.waitForTimeout(400);
  const invima = (await p.evaluate(() => window.__enlaces)).at(-1);
  if (invima !== 'https://consultaregistro.invima.gov.co/') throw new Error(`Invima: ${invima}`);
  await pulsarExacto('Agenda');
  await texto(p, 'Inventario: 1 lote vencido · 1 por vencer').waitFor();
  paso('Alertas: lote vencido con existencias, por vencer y sin registro Invima (también en la agenda); «Consultar en Invima» en otra pestaña');

  // Sesión 2 de Muñoz: sugiere el lote que vence primero (L7788, no el
  // vencido); con el vencido elegido a propósito, no se sella.
  await abrirFicha('52222333');
  await tocar('Estética');
  await tocarAbajo('Registrar sesión');
  await texto(p, 'Sesión 2 de 4 · Hidrolipoclasia').waitFor();
  for (const item of verificacion) {
    const c = p.getByRole('checkbox', { name: item, exact: true });
    if (!(await c.isChecked())) await hacerClic(c);
    if (!(await c.isChecked())) throw new Error(`«${item}» sin marcar`);
  }
  await escribirAbajo('Volumen (Abdomen inferior)', '300');
  await escribirAbajo('Volumen (Flancos)', '200');
  await escribirAbajo('Lote (Componente B de prueba)', 'C-0002');
  await escribirAbajo('Vence (Componente B de prueba)', '31/03/2027');
  await escribirAbajo('Volumen del anestésico', '10');
  await escribirAbajo('Duración', '45');
  await texto(p, 'Del inventario: lote L7788 · vence 15/12/2026').waitFor();
  await texto(p, 'Del inventario: lote CA-01 · vence 30/06/2027').waitFor();
  await texto(p, 'se descuentan 2 ampollas al sellar').waitFor();
  await texto(p, 'Lista para sellar').waitFor();
  async function elegirLote(numero) {
    await hacerClic(p.getByRole('button', { name: 'Cambiar lote', exact: true }).last());
    await texto(p, 'Lote de «Anestésico de prueba»').waitFor();
    await p
      .getByRole('button', { name: new RegExp(`^Lote ${numero}`) })
      .or(p.locator('flt-semantics[flt-tappable]').filter({ hasText: new RegExp(`Lote ${numero}`) }))
      .last()
      .dispatchEvent('click');
    await p.waitForTimeout(500);
  }
  await elegirLote('L-OCT');
  await texto(p, 'El lote L-OCT de «Anestésico de prueba» venció el 31/10/2026.').waitFor();
  await texto(p, 'Vencido: con este lote no se sella la sesión.').waitFor();
  if (await p.getByRole('button', { name: 'Sellar sesión' }).isEnabled()) {
    throw new Error('Con un lote vencido se puede sellar');
  }
  await aLaVista(conTexto('Vencido: con este lote no se sella la sesión.'));
  await captura(p, 'i2_sesion_lote_vencido.png');
  paso('Sesión 2 de 4: sugiere el lote que vence primero; con el lote vencido del inventario no se sella');

  await elegirLote('L7788');
  await texto(p, 'Lista para sellar').waitFor();
  await aLaVista(conTexto('Del inventario: lote L7788'));
  await captura(p, 'i3_sesion_inventario.png');
  const hv4 = await descargar(p, () => pulsar(p, 'Sellar sesión'));
  if (path.basename(hv4) !== 'Historia_MUNOZ_52222333_v4.pdf') throw new Error(`Historia: ${path.basename(hv4)}`);
  try {
    const t = execFileSync('pdftotext', [hv4, '-'], { encoding: 'utf8' }).replace(/\s+/g, ' ');
    for (const esperado of ['Sesión 2 de 4 de Hidrolipoclasia', 'lote L7788, vence 15/12/2026', 'Componente A de prueba (lote CA-01, vence 30/06/2027)']) {
      if (!t.includes(esperado)) throw new Error(`La historia no dice «${esperado}»`);
    }
  } catch (e) {
    if (e.code !== 'ENOENT') throw e;
  }
  await texto(p, 'Ficha del paciente').waitFor();
  paso(`Sesión sellada con los lotes del inventario → ${path.basename(hv4)} (lote L7788 y CA-01)`);

  // El inventario: 2 ampollas y 1 frasco descontados; bajo el mínimo; el
  // lote vencido se da de baja.
  await pulsarExacto('Inventario');
  await texto(p, 'Existencia: 4 ampollas (mínimo 5)').waitFor();
  await texto(p, '1 bajo el mínimo').waitFor();
  await hacerClic(p.getByRole('button', { name: 'Movimientos (3)', exact: true }));
  await texto(p, 'Salida · lote L7788 · -2 · Sesión 2 de 4: Anestésico de prueba').waitFor();
  await texto(p, 'Vence el 30/06/2027 · quedan 2 frascos').waitFor();
  await hacerClic(p.getByRole('button', { name: 'Dar de baja L-OCT', exact: true }));
  await escribir(p, 'Motivo', 'Vencido');
  await p.getByRole('button', { name: 'Dar de baja', exact: true }).click();
  await texto(p, 'Lote L-OCT dado de baja.').waitFor();
  await texto(p, 'Lote L-OCT dado de baja.').desaparece({ timeout: 20000 });
  if (await p.getByText('lote vencido con existencias').count()) {
    throw new Error('Sigue la alerta del lote vencido');
  }
  await alInicio();
  await captura(p, 'i4_inventario_despues.png');
  paso('El inventario descontó 2 ampollas y 1 frasco (queda bajo el mínimo, con la salida de la sesión); el lote vencido se da de baja');

  // Caja ↔ inventario: un cobro con una ampolla usada (sin pago: la caja de
  // hoy ya se cerró). Se descuenta del lote que vence primero y, al anular
  // el cobro, vuelve.
  await pulsarExacto('Caja');
  await p.getByRole('button', { name: 'Cobrar', exact: true }).first().click();
  await texto(p, 'INSUMOS USADOS').waitFor();
  await elegirPacienteCobro('munoz maria');
  await hacerClic(p.getByRole('button', { name: 'Quitar el pago 1', exact: true }));
  await hacerClic(p.getByRole('button', { name: 'Agregar un insumo', exact: true }));
  await texto(p, 'L7788 · vence 15/12/2026 · quedan 4 ampollas').waitFor();
  await aLaVista(conTexto('INSUMOS USADOS'));
  await captura(p, 'i7_cobro_con_insumo.png');
  await p.getByRole('button', { name: 'Registrar sin pago', exact: true }).click();
  await texto(p, 'Se descontó 1 insumo del inventario.').waitFor();
  await texto(p, 'Insumos: Anestésico de prueba, 1 ampolla (lote L7788)').waitFor();
  await texto(p, 'Se descontó 1 insumo del inventario.').desaparece({ timeout: 20000 });
  await pulsarExacto('Inventario');
  await texto(p, 'Existencia: 3 ampollas (mínimo 5)').waitFor();
  await hacerClic(p.getByRole('button', { name: /^Movimientos \(/ }).first());
  await texto(p, 'Salida · lote L7788 · -1 · Cobro: ').waitFor();
  paso('Cobro con un insumo usado: sugiere el lote que vence primero y lo descuenta del inventario (1 ampolla de L7788)');

  await pulsarExacto('Caja');
  await hacerClic(p.getByRole('button', { name: 'Anular el cobro', exact: true }));
  await texto(p, 'Sus insumos vuelven al inventario').waitFor();
  await escribir(p, 'Motivo de la anulación', 'Prueba de anulación');
  await p.getByRole('button', { name: 'Anular', exact: true }).click();
  await texto(p, 'Cobro anulado: sus insumos volvieron al inventario.').waitFor();
  await texto(p, 'Cobro anulado: sus insumos volvieron al inventario.').desaparece({ timeout: 20000 });
  await pulsarExacto('Inventario');
  await texto(p, 'Existencia: 4 ampollas (mínimo 5)').waitFor();
  paso('Al anular el cobro, la ampolla vuelve al inventario');

  await p.setViewportSize({ width: 390, height: 844 });
  await p.waitForTimeout(900);
  await captura(p, 'i5_inventario_movil.png');
  await p.setViewportSize({ width: 320, height: 640 });
  await p.waitForTimeout(900);
  await captura(p, 'i6_inventario_320.png');
  await p.setViewportSize({ width: 1440, height: 1000 });
  await p.waitForTimeout(900);
  paso('Inventario en móvil (390 px) y 320 px');

  // ─────────────── 9. Notas «VERIFICAR» y modo presentación (5.8) ───────────────
  // Lo que se ve de la pantalla (texto y etiquetas de accesibilidad).
  const cuantas = (t) =>
    p.evaluate((t) => {
      let n = 0;
      for (const e of document.querySelectorAll('flt-semantics, flt-semantics-container')) {
        const a = `${e.getAttribute('aria-label') ?? ''}`;
        if (a.includes(t)) n++;
      }
      for (const e of document.querySelectorAll('flt-semantics')) {
        if (!e.getAttribute('aria-label') && (e.textContent ?? '').includes(t)) n++;
      }
      return n;
    }, t);
  async function ir(ruta, esperado) {
    await p.evaluate((r) => (location.hash = r), `#${ruta}`);
    await texto(p, esperado).waitFor({ timeout: 20000 });
    await p.waitForTimeout(600);
  }

  // Ajustes: la nota de la DIAN se marca como verificada, con fecha y fuente.
  await ir('/ajustes', 'Servicios y tarifas');
  await texto(p, 'Ninguna nota verificada todavía').waitFor();
  const chipDian = p.getByRole('button', { name: /^Por verificar: DIAN, VERIFICAR con tu contador/ });
  await hacerClic(chipDian);
  await texto(p, 'Nota por verificar').waitFor();
  await escribir(p, 'Fuente', 'Concepto del contador (prueba)');
  await p.getByRole('button', { name: 'Marcar como verificada', exact: true }).click();
  await texto(p, 'Verificado el 30/11/2026 · Concepto del contador (prueba)').waitFor();
  await texto(p, '1 nota verificada').waitFor();
  await aLaVista(p.getByRole('button', { name: /^Verificado el 30\/11\/2026/ }));
  await captura(p, 'j1_verificada.png');
  if (!(await cuantas('Por verificar'))) throw new Error('No hay chips «Por verificar» en Ajustes');
  paso('Ajustes: chips «Por verificar» con la nota completa; la de la DIAN, verificada el 30/11/2026 con su fuente');

  // Modo presentación: ningún «VERIFICAR» ni chip en las pantallas, ni
  // notas internas ni montos de la caja en las que ve el paciente.
  await p.getByRole('button', { name: 'Modo presentación', exact: true }).click();
  await texto(p, 'Modo presentación: sin notas por verificar').waitFor();
  const pantallas = [
    ['/agenda', 'lunes 30/11/2026'],
    ['/pacientes', 'Pacientes'],
    ['/caja', 'Totales del día'],
    ['/inventario', 'Anestésico de prueba'],
    ['/ajustes', 'Servicios y tarifas'],
    ['/medico', 'Datos del médico'],
    ['/receta', 'Receta'],
    ['/', 'Historia'],
  ];
  for (const [ruta, esperado] of pantallas) {
    await ir(ruta, esperado);
    for (const t of ['VERIFICAR', 'Por verificar', 'Verificado el']) {
      const n = await cuantas(t);
      if (n) throw new Error(`Modo presentación: «${t}» en ${ruta} (${n})`);
    }
  }
  await ir('/agenda', 'lunes 30/11/2026');
  if (await cuantas('Saldo $') || await cuantas('Control de tiroides')) {
    throw new Error('Modo presentación: la agenda muestra montos o el motivo');
  }
  await abrirFicha('1032456789');
  if (await p.getByRole('button', { name: /^Caja$/ }).count()) {
    throw new Error('Modo presentación: la ficha ofrece la sección Caja');
  }
  await captura(p, 'j2_presentacion_ficha.png');
  await ir('/ajustes', 'Servicios y tarifas');
  await alInicio();
  await captura(p, 'j3_presentacion_ajustes.png');
  paso('Modo presentación: ningún «VERIFICAR» ni chip en agenda, pacientes, caja, inventario, ajustes, datos del médico, receta e historia; sin montos ni el motivo de la cita; la ficha sin la sección Caja');

  // Se apaga al bloquear.
  await p.getByRole('button', { name: 'Bloquear el consultorio', exact: true }).click();
  await desbloquear(p);
  await texto(p, 'Servicios y tarifas').waitFor({ timeout: 30000 });
  await p.waitForTimeout(600);
  if (await cuantas('Modo presentación: sin notas')) throw new Error('El modo presentación sigue tras bloquear');
  if (!(await cuantas('Por verificar'))) throw new Error('Tras bloquear no volvieron los chips');
  paso('Al bloquear, el modo presentación se apaga: al desbloquear vuelven los chips');
  await abrirFicha('1032456789');

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
            listo(
              ['1032456789', 'Metformina', 'PEÑA', 'Penicilina', 'JFIF', 'Exif', 'Empresa de prueba', 'Endocrinolog', 'tiroides', 'TR-0042', 'RC-000001', 'PRUEBA-0001', 'L7788'].filter((t) =>
                todo.includes(t),
              ),
            );
          };
        };
      }),
  );
  if (enClaro.length) throw new Error(`Datos de pacientes en claro: ${enClaro}`);
  paso('IndexedDB y localStorage sin datos de pacientes en claro (índice, documentos, recetas, borrador, mediciones y fotos cifrados)');

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
  await p.waitForTimeout(400);
  async function bajar(px) {
    await p.mouse.move(200, 600);
    await p.mouse.wheel(0, px);
    await p.waitForTimeout(400);
  }
  await tocar('Seguimiento');
  await texto(p, 'Informe de seguimiento').waitFor();
  await bajar(560);
  await captura(p, 'p10_movil_seguimiento.png');
  await bajar(-2000);
  await tocar('Fotos');
  await texto(p, 'COMPARAR').waitFor();
  await bajar(640);
  await captura(p, 'p11_movil_fotos.png');
  paso('Móvil (390 px): ficha con el menú «Acciones», seguimiento y fotos');
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
