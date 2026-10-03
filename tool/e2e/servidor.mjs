// Servidor estático para las pruebas, con las mismas cabeceras que en
// producción (las de build/web/_headers, formato de Netlify).
//
//   node tool/e2e/servidor.mjs [puerto] [carpeta]     (8765, build/web)
//
// Como módulo, `crearServidor` permite además publicar "otra versión" de un
// archivo y ver qué pidió el navegador.

import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const tipos = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
};

/** Lee `_headers`: [{patron: '/*', valores: {Cabecera: valor}}]. */
function leerCabeceras(sitio) {
  const archivo = path.join(sitio, '_headers');
  const reglas = [];
  if (!fs.existsSync(archivo)) return reglas;
  for (const linea of fs.readFileSync(archivo, 'utf8').split('\n')) {
    if (!linea.trim() || linea.trim().startsWith('#')) continue;
    if (!/^\s/.test(linea)) {
      reglas.push({ patron: linea.trim(), valores: {} });
    } else {
      const i = linea.indexOf(':');
      reglas.at(-1).valores[linea.slice(0, i).trim()] = linea.slice(i + 1).trim();
    }
  }
  return reglas;
}

export async function crearServidor({ sitio = 'build/web', puerto = 0 } = {}) {
  const raiz = path.resolve(sitio);
  const reglas = leerCabeceras(raiz);
  const cabecerasDe = (ruta) => {
    const r = {};
    for (const { patron, valores } of reglas) {
      const coincide = patron.endsWith('*')
        ? `/${ruta}`.startsWith(patron.slice(0, -1))
        : `/${ruta}` === patron;
      if (coincide) Object.assign(r, valores);
    }
    return r;
  };
  const estado = {
    /** Ruta → contenido que reemplaza al del disco. */
    reemplazos: {},
    /** Rutas pedidas, en orden. */
    servidos: [],
  };
  const servidor = http.createServer((pedido, respuesta) => {
    let ruta = decodeURIComponent(new URL(pedido.url, 'http://x').pathname).replace(/^\/+/, '');
    if (ruta === '' || ruta.endsWith('/')) ruta += 'index.html';
    estado.servidos.push(ruta);
    const archivo = path.join(raiz, ruta);
    const enDisco = archivo.startsWith(raiz) && fs.existsSync(archivo) && fs.statSync(archivo).isFile();
    const cuerpo = estado.reemplazos[ruta] ?? (enDisco ? fs.readFileSync(archivo) : null);
    if (cuerpo === null) {
      respuesta.writeHead(404).end();
      return;
    }
    respuesta.writeHead(200, {
      'Content-Type': tipos[path.extname(ruta)] ?? 'application/octet-stream',
      'Cache-Control': 'max-age=3600',
      ...cabecerasDe(ruta),
    });
    respuesta.end(cuerpo);
  });
  await new Promise((r) => servidor.listen(puerto, '127.0.0.1', r));
  // localhost cuenta como sitio seguro: el service worker funciona sin HTTPS.
  return {
    estado,
    base: `http://localhost:${servidor.address().port}/`,
    cerrar: () => servidor.close(),
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const s = await crearServidor({ puerto: Number(process.argv[2] ?? 8765), sitio: process.argv[3] });
  console.log(`Sirviendo en ${s.base} (Ctrl+C para terminar)`);
}
