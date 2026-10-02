// Prueba de la app instalada (service worker) en Chromium.
//
// Uso:
//   ./tool/construir_web.sh
//   node tool/e2e/pwa_offline.mjs
//
// Variables: SITIO (build/web), OUT_DIR (build/e2e) y LENTITUD (por ejemplo
// 4: la CPU 4 veces más lenta, como en la CI).
//
// Levanta su propio servidor para poder publicar "otra versión":
// 1. Primera visita con conexión: la app queda guardada y lo avisa.
// 2. Sin conexión: recargar, abrir otra pestaña, buscar en el CIE-10
//    incluido, vista previa de la receta y guardar su PDF.
// 3. Versión nueva: se instala en segundo plano descargando solo lo que
//    cambió, la app ofrece "Actualizar" y no se pierde lo escrito.
// 4. Un archivo que no coincide con su huella: la versión nueva se rechaza y
//    la instalada sigue funcionando.
// Falla si hay peticiones fuera del sitio o errores de consola.

import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

import { crearServidor } from './servidor.mjs';

const SITIO = path.resolve(process.env.SITIO ?? 'build/web');
const OUT = path.resolve(process.env.OUT_DIR ?? 'build/e2e');
fs.mkdirSync(OUT, { recursive: true });
if (!fs.existsSync(path.join(SITIO, 'sw.js'))) {
  console.error(`Falta ${SITIO}/sw.js: compila con ./tool/construir_web.sh`);
  process.exit(1);
}

// ─────────────── Servidor con "versiones" ───────────────
const servidor = await crearServidor({ sitio: SITIO });
const { base: BASE, estado: sitio } = servidor;
const servidos = sitio.servidos;

const swOriginal = fs.readFileSync(path.join(SITIO, 'sw.js'), 'utf8');
const archivosDe = (sw) => JSON.parse(sw.match(/const ARCHIVOS = (\{[\s\S]*?\});/)[1]);
const huella = (contenido) => crypto.createHash('sha256').update(contenido).digest('hex').slice(0, 16);
/** sw.js de una versión nueva en la que [ruta] cambió a [contenido]. */
function versionNueva(version, ruta, contenido, { huellaFalsa = false } = {}) {
  const archivos = archivosDe(swOriginal);
  archivos[ruta] = huellaFalsa ? '0000000000000000' : huella(contenido);
  return swOriginal
    .replace(/const VERSION = '\w+';/, `const VERSION = '${version}';`)
    .replace(/const ARCHIVOS = \{[\s\S]*?\};/, `const ARCHIVOS = ${JSON.stringify(archivos, null, 2)};`);
}

// ─────────────── Informe y ayudas ───────────────
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
  if (paginaActual) await paginaActual.screenshot({ path: path.join(OUT, 'ERROR_pwa.png') }).catch(() => {});
  process.exit(1);
};
process.on('unhandledRejection', alFallar);
process.on('uncaughtException', alFallar);

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
const boton = (page, nombre) => page.getByRole('button', { name: nombre }).first();
const comienzo = (t) => new RegExp('^' + t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
const campo = (page, etiqueta) => page.getByRole('textbox', { name: comienzo(etiqueta) }).first();

// Vale solo si el foco está en ESE campo y tiene el valor (en un equipo lento
// el foco puede seguir en el campo anterior).
async function escribir(page, etiqueta, valor) {
  const c = campo(page, etiqueta);
  for (let intento = 0; intento < 4; intento++) {
    await c.scrollIntoViewIfNeeded();
    await page.waitForTimeout(150 + intento * 300);
    await c.click();
    await page.waitForTimeout(150 + intento * 300);
    await c.fill(valor);
    await page.waitForTimeout(100);
    if (await c.evaluate((el, v) => document.activeElement === el && el.value === v, valor)) return;
  }
  throw new Error(`No se pudo escribir "${valor}" en "${etiqueta}"`);
}

async function valorDe(page, etiqueta) {
  const c = campo(page, etiqueta);
  await c.scrollIntoViewIfNeeded();
  await c.click();
  // Solo vale lo leído si el foco llegó a ESTE campo: en un equipo lento el
  // clic tarda un fotograma y el foco sigue en el campo anterior (la CI leyó
  // así el diagnóstico en vez del código). Si no llega, devuelve ''.
  return c.evaluate(
    (el) =>
      new Promise((listo) => {
        const inicio = Date.now();
        (function mirar() {
          if (document.activeElement === el) {
            // Flutter copia el valor al <input> un instante después.
            setTimeout(() => listo(el.value), 150);
          } else if (Date.now() - inicio > 3000) {
            listo('');
          } else {
            requestAnimationFrame(mirar);
          }
        })();
      }),
  );
}

// Flutter pasa el valor al <input> del árbol semántico un instante después de
// enfocarlo; en un equipo lento (la CI) puede tardar. Se reintenta hasta que
// [cumple] (un texto exacto o una función) o hasta ~10 s, y se devuelve lo
// último leído para el mensaje de error.
async function esperarValor(page, etiqueta, cumple) {
  const ok = typeof cumple === 'function' ? cumple : (v) => v === cumple;
  let v = '';
  for (let intento = 0; intento < 8; intento++) {
    await page.waitForTimeout(intento * 250);
    v = await valorDe(page, etiqueta);
    if (ok(v)) return v;
  }
  return v;
}

/** Espera a que la app esté lista (con o sin conexión) y activa la semántica. */
async function esperarApp(page) {
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60000 });
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
  await page.getByRole('button', { name: /receta/i }).first().waitFor({ timeout: 30000 });
}

const captura = (page, nombre) => page.screenshot({ path: path.join(OUT, nombre) });

const browser = await chromium.launch();
const context = await browser.newContext({
  acceptDownloads: true,
  viewport: { width: 1440, height: 1000 },
  locale: 'es-CO',
  timezoneId: 'America/Bogota',
});
// "Guardar PDF" como descarga normal (sin el selector de archivos nativo).
await context.addInitScript(() => {
  delete window.showOpenFilePicker;
  delete window.showSaveFilePicker;
  // Lo que bloquee la Content-Security-Policy cuenta como error.
  document.addEventListener('securitypolicyviolation', (e) =>
    console.error(`CSP: ${e.violatedDirective} bloqueó ${e.blockedURI} (${e.sourceFile}:${e.lineNumber})`),
  );
});
context.on('request', (r) => {
  const u = r.url();
  if (!u.startsWith(BASE) && !u.startsWith('blob:') && !u.startsWith('data:')) informe.externas.push(u);
});
context.on('requestfailed', (r) => {
  if (r.url().startsWith('blob:')) return;
  informe.fallidas.push(`${r.url()} ${r.failure()?.errorText}`);
});
async function vigilar(page) {
  if (process.env.LENTITUD) {
    const cdp = await page.context().newCDPSession(page);
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: Number(process.env.LENTITUD) });
  }
  page.on('console', (m) => {
    consola.push(`[${m.type()}] ${m.text()}`);
    if (m.type() === 'error') informe.erroresConsola.push(m.text());
  });
  page.on('pageerror', (e) => {
    consola.push(`[pageerror] ${e.message}`);
    informe.erroresConsola.push(e.message);
  });
  paginaActual = page;
  return page;
}

// ─────────────── 1. Primera visita ───────────────
const page = await vigilar(await context.newPage());
await page.goto(BASE);
await esperarApp(page);
await texto(page, 'ya funciona sin conexión').waitFor({ timeout: 60000 });
await captura(page, 'p1_lista_sin_conexion.png');
const caches = await page.evaluate(async () => {
  const r = {};
  for (const n of await self.caches.keys()) {
    r[n] = (await (await self.caches.open(n)).keys()).map((q) => new URL(q.url).pathname.slice(1));
  }
  return r;
});
const nombreApp = Object.keys(caches).find((n) => n.startsWith('hc-app-'));
const nombreMotor = Object.keys(caches).find((n) => n.startsWith('hc-motor-'));
const esperados = Object.keys(archivosDe(swOriginal));
const faltan = esperados.filter((r) => !caches[nombreApp]?.includes(r));
if (faltan.length) throw new Error(`No quedaron guardados: ${faltan.join(', ')}`);
const motor = caches[nombreMotor] ?? [];
if (!motor.some((r) => r.endsWith('canvaskit.wasm')) || !motor.some((r) => r.endsWith('canvaskit.js'))) {
  throw new Error(`Motor sin guardar: ${JSON.stringify(motor)}`);
}
paso(`Primera visita: ${esperados.length} archivos guardados más el motor de este navegador (${motor.join(', ')}); la app lo avisa`);

// ─────────────── 2. Sin conexión ───────────────
await context.setOffline(true);
servidos.length = 0;
await page.reload();
await esperarApp(page);
if (servidos.length) throw new Error(`Sin conexión se pidió al servidor: ${servidos.join(', ')}`);
paso('Sin conexión: recargar la página abre la app desde el navegador');

const otra = await vigilar(await context.newPage());
await otra.goto(BASE);
await esperarApp(otra);
await otra.close();
paginaActual = page;
paso('Sin conexión: una pestaña nueva también abre la app');

await escribir(page, 'Primer apellido *', 'Ríos');
await escribir(page, 'Nombres *', 'Marta');
await escribir(page, 'Número de documento *', '52111222');
await page.getByRole('button', { name: 'Diagnósticos' }).first().click().catch(() => {});
await boton(page, 'Agregar diagnóstico').click();
await escribir(page, 'Diagnóstico *', 'hiper');
await page.waitForTimeout(1500); // el catálogo se carga al entrar al campo
await escribir(page, 'Diagnóstico *', 'hipertension esencial');
await texto(page, 'HIPERTENSION ESENCIAL (PRIMARIA)').waitFor();
await captura(page, 'p2_cie10_sin_conexion.png');
await page.keyboard.press('Enter');
await page.waitForTimeout(300);
const codigo = await esperarValor(page, 'CIE-10', 'I10X');
if (codigo !== 'I10X') throw new Error(`El CIE-10 no se completó: "${codigo}"`);
paso('Sin conexión: el CIE-10 de SISPRO incluido sugiere y completa el código (I10X)');

await page.getByRole('button', { name: /receta/i }).first().click();
await texto(page, 'Vista previa de la receta, hoja 1 de 1').waitFor({ timeout: 20000 });
await escribir(page, 'Medicamento (DCI o genérico) *', 'Losartán');
for (const [etiqueta, valor] of [
  ['Concentración *', '50 mg'],
  ['Forma farmacéutica *', 'tableta'],
  ['Dosis *', '1 tableta'],
  ['Vía *', 'oral'],
  ['Frecuencia *', 'cada 24 horas'],
  ['Duración *', '30 días'],
]) {
  await escribir(page, etiqueta, valor);
  await page.keyboard.press('Escape');
}
await escribir(page, 'Cantidad *', '30');
await page.waitForTimeout(800);
await captura(page, 'p3_receta_sin_conexion.png');
const [descarga] = await Promise.all([
  page.waitForEvent('download'),
  (async () => {
    await boton(page, 'Guardar PDF').click();
    await boton(page, 'Continuar sin mis datos').click();
  })(),
]);
const pdf = path.join(OUT, 'pwa_receta.pdf');
await descarga.saveAs(pdf);
const info = execFileSync('pdfinfo', [pdf]).toString();
if (!/Page size:\s+419\.5\d* x 595\.2\d* pts/.test(info)) throw new Error(`El PDF no es A5:\n${info}`);
const contenido = execFileSync('pdftotext', [pdf, '-']).toString();
if (!contenido.includes('LOSARTÁN') || !contenido.includes('I10X')) throw new Error(`PDF incompleto:\n${contenido}`);
paso('Sin conexión: la receta se ve en la vista previa y su PDF A5 se guarda');
await page.getByRole('button', { name: 'Ahora no' }).first().click().catch(() => {});
await page.getByRole('button', { name: 'Volver a la historia' }).first().click();
await page.waitForTimeout(1200); // autoguardado del borrador

// ─────────────── 3. Versión nueva ───────────────
await context.setOffline(false);
const notices = Buffer.concat([fs.readFileSync(path.join(SITIO, 'assets/NOTICES')), Buffer.from('\nversión de prueba\n')]);
sitio.reemplazos = {
  'sw.js': versionNueva('prueba00002', 'assets/NOTICES', notices),
  'assets/NOTICES': notices,
};
servidos.length = 0;
await page.evaluate(() => navigator.serviceWorker.getRegistration().then((r) => r.update()));
await texto(page, 'Hay una versión nueva').waitFor({ timeout: 60000 });
await captura(page, 'p4_version_nueva.png');
const descargados = [...new Set(servidos)].sort();
if (JSON.stringify(descargados) !== JSON.stringify(['assets/NOTICES', 'sw.js'])) {
  throw new Error(`La actualización descargó de más: ${descargados.join(', ')}`);
}
paso('Versión nueva: se instala en segundo plano y solo descarga lo que cambió (sw.js y NOTICES)');

await boton(page, 'Actualizar').click();
await page.waitForLoadState('load');
await esperarApp(page);
await texto(page, 'Se recuperó el borrador').waitFor().catch(() => {});
const apellido = await esperarValor(page, 'Primer apellido *', 'Ríos');
if (apellido !== 'Ríos') throw new Error(`Se perdió lo escrito al actualizar: "${apellido}"`);
const version = await page.evaluate(async () => (await self.caches.keys()).find((n) => n.startsWith('hc-app-')));
if (version !== 'hc-app-prueba00002') throw new Error(`Versión en uso: ${version}`);
paso('"Actualizar" recarga con la versión nueva y conserva lo escrito');

// ─────────────── 4. Archivo que no coincide con su huella ───────────────
sitio.reemplazos = {
  ...sitio.reemplazos,
  'sw.js': versionNueva('prueba00003', 'index.html', 'no importa', { huellaFalsa: true }),
};
const estado = await page.evaluate(async () => {
  const r = await navigator.serviceWorker.getRegistration();
  await r.update().catch(() => {});
  const nuevo = r.installing;
  if (!nuevo) return 'sin instalación';
  return new Promise((listo) => nuevo.addEventListener('statechange', () => {
    if (nuevo.state === 'redundant' || nuevo.state === 'activated') listo(nuevo.state);
  }));
});
if (estado !== 'redundant') throw new Error(`Se aceptó una versión con un archivo alterado (${estado})`);
await context.setOffline(true);
await page.reload();
await esperarApp(page);
paso('Un archivo que no coincide con su huella hace rechazar la versión; la instalada sigue funcionando sin conexión');

await browser.close();
servidor.cerrar();
informe.externas = [...new Set(informe.externas)];
fs.writeFileSync(path.join(OUT, 'informe_pwa.json'), JSON.stringify(informe, null, 2));
console.log('\nPeticiones fuera del sitio:', informe.externas.length ? informe.externas : 'ninguna');
console.log('Peticiones fallidas:', informe.fallidas.length ? informe.fallidas : 'ninguna');
console.log('Errores de consola:', informe.erroresConsola.length ? informe.erroresConsola : 'ninguno');
if (informe.externas.length || informe.fallidas.length || informe.erroresConsola.length) process.exit(1);
