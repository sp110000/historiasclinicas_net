# Publicar historiasclinicas.net

La app es un **sitio estático**: solo archivos. No hay servidor propio, base de datos ni cuentas. Las historias, recetas y datos del médico nunca salen del navegador; el hosting solo entrega los archivos de la app.

**Requisito obligatorio: HTTPS.** Sin HTTPS el navegador no activa el service worker, y la app no queda disponible sin conexión. Todos los proveedores de esta guía lo dan gratis.

---

## 1. Compilar

```bash
git pull
flutter clean && flutter pub get
./tool/construir_web.sh
```

El sitio queda en **`build/web/`** y eso es lo que se publica, **completo**. Incluye dos archivos de configuración del hosting: `_headers` y `.htaccess`, que es oculto.

`construir_web.sh` hace dos cosas:
1. `flutter build web --release --no-web-resources-cdn`: compila sin depender de CDN.
2. `dart run tool/pwa/generar_service_worker.dart`: crea `build/web/sw.js` con la lista de archivos y su huella SHA-256.

> **No publiques el resultado de `flutter build web` solo.** Sin `sw.js` la app funciona, pero no sin conexión. Y no mezcles archivos de compilaciones distintas: el service worker rechaza los que no coinciden con su huella.

**En una subcarpeta** (por ejemplo `https://dominio.com/historias/`):
```bash
./tool/construir_web.sh --base-href /historias/
```

**En Windows** (sin bash), los mismos dos pasos:
```powershell
flutter build web --release --no-web-resources-cdn
dart run tool/pwa/generar_service_worker.dart build/web
```

**Sin compilar en tu equipo:** cada push a GitHub compila el sitio (ver la sección 6). Descárgalo en *Actions* → la ejecución → *Artifacts* → `sitio-web`.

## 2. Probarlo en tu equipo

```bash
node tool/e2e/servidor.mjs        # http://localhost:8765, con las mismas cabeceras que en producción
# o, sin Node:  python3 -m http.server 8765 --directory build/web
```
`localhost` cuenta como sitio seguro, así que el modo sin conexión funciona aquí sin HTTPS.

## 3. Elegir dónde publicar

| Proveedor | Cómo se publica | Cabeceras de seguridad | Comentario |
|---|---|---|---|
| **Netlify** (recomendado) | Arrastrar `build/web` o un comando | `_headers`, ya incluido | El más sencillo |
| **Cloudflare Pages** | Un comando | `_headers`, ya incluido | Red muy rápida en Latinoamérica y España |
| **Firebase Hosting** | Un comando | `firebase.json`, ya incluido | Google |
| **Vercel** | Un comando | `vercel.json`, ya incluido | VERIFICAR: no pude probarlo |
| **Hosting tradicional** (cPanel, Apache) | Subir archivos por FTP o el administrador | `.htaccess`, ya incluido | Si ya tienes un hosting |
| **Nginx** (servidor propio) | Copiar archivos | Configuración abajo | |
| **GitHub Pages** | Rama `gh-pages` | ❌ No permite cabeceras | Funciona, pero sin las cabeceras de seguridad |

Las cuatro configuraciones (`_headers`, `firebase.json`, `vercel.json` y `.htaccess`) envían **exactamente las mismas cabeceras**; un test lo comprueba (`test/tool/despliegue_test.dart`). No pude probar ningún proveedor real desde aquí. Las cabeceras sí se probaron en Chromium con un servidor local que las aplica igual.

### Netlify
1. Crea una cuenta en netlify.com.
2. **Sin instalar nada:** entra en `app.netlify.com/drop` y arrastra la carpeta `build/web`.
3. **Con la línea de comandos:**
   ```bash
   npm install -g netlify-cli
   netlify deploy --dir=build/web --prod
   ```
4. **Dominio:** *Domain management* → *Add a domain* → `historiasclinicas.net`. Netlify indica los registros DNS y activa HTTPS (Let's Encrypt) automáticamente.

### Cloudflare Pages
```bash
npx wrangler pages deploy build/web --project-name historiasclinicas
```
El dominio se configura en *Custom domains*. Si `historiasclinicas.net` ya usa los DNS de Cloudflare, es inmediato.

### Firebase Hosting
```bash
npm install -g firebase-tools
firebase login
firebase use --add                # elige o crea el proyecto
firebase deploy --only hosting    # usa firebase.json: publica build/web
```
Si ejecutas `firebase init hosting`, **no sobrescribas `firebase.json`**. El dominio se configura en *Hosting* → *Add custom domain*.

### Vercel (VERIFICAR)
```bash
npm install -g vercel
vercel deploy --prod              # desde la raíz del proyecto
```
`.vercelignore` sube solo `build/web` y `vercel.json`. `vercel.json` indica que no hay que compilar y publica `build/web` con las cabeceras. No pude probarlo desde aquí: después de publicar, revisa las cabeceras (sección 5).

### Hosting tradicional (cPanel, Apache)
1. Sube **el contenido** de `build/web` (no la carpeta) a `public_html/`, o a la carpeta del dominio.
   - Incluye `.htaccess`. En el administrador de archivos activa "Mostrar archivos ocultos".
2. Activa HTTPS: en cPanel, *SSL/TLS Status* → *AutoSSL* (o Let's Encrypt).
3. Si el hosting no redirige a HTTPS por sí solo, quita los `#` de las tres últimas líneas de `.htaccess`.
4. `.htaccess` necesita `mod_headers`, que casi todos los hostings tienen. Si no lo tiene, la app funciona igual, pero sin las cabeceras de seguridad.

### Nginx
```nginx
server {
    listen 443 ssl http2;
    server_name historiasclinicas.net;
    root /var/www/historiasclinicas/build/web;

    types { application/wasm wasm; }
    gzip on;
    gzip_types text/plain text/javascript application/javascript application/json application/wasm font/ttf font/otf;

    # Las mismas que web/_headers (cópialas de ahí si cambian).
    add_header Cache-Control "no-cache" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'wasm-unsafe-eval' 'sha256-+M0fGRkOqgYlCQCff9oNQn6k6a7Si4Et8iofLMceadE='; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' data: blob:; worker-src 'self' blob:; frame-src 'self' blob:; object-src 'none'; base-uri 'self'; form-action 'none'; frame-ancestors 'none'" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer" always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=(), usb=()" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Strict-Transport-Security "max-age=31536000" always;

    location ~ /\.  { deny all; }   # .htaccess y otros ocultos
    location = /_headers { deny all; }
}
```

### GitHub Pages
Funciona con HTTPS y sin conexión, pero no permite cabeceras propias, así que no lleva la Content-Security-Policy. En un repositorio de proyecto (`usuario.github.io/historiasclinicas_net/`) compila con `--base-href /historiasclinicas_net/`.

## 4. Dominio historiasclinicas.net

En el registrador del dominio, apunta los DNS a lo que indique el proveedor:
- `historiasclinicas.net` (raíz): un registro **A**, o **ALIAS**/**ANAME** si el proveedor lo pide.
- `www`: un **CNAME** al dominio que te dé el proveedor. Redirige `www` a la raíz, o al revés: elige una sola dirección.

El HTTPS se activa solo cuando los DNS ya apuntan bien. Puede tardar desde minutos hasta 24 h.

> **Elige bien la dirección definitiva.** Lo que el médico deja en el navegador (borrador, datos del médico, firma, numeración de recetas, "Mis medicamentos", catálogo importado) se guarda **por dirección**. `https://historiasclinicas.net` y `https://www.historiasclinicas.net` son direcciones distintas. Si cambias de dirección más adelante, esos datos no se pasan solos: el médico debe volver a configurarlos. Las historias no se pierden, porque están en los PDF.

## 5. Comprobar después de publicar

1. Abre el sitio con conexión y espera el aviso **"Listo: la app quedó guardada en este navegador y ya funciona sin conexión"**.
2. Activa el modo avión (o en Chrome: F12 → *Network* → *Offline*) y recarga: la app debe abrir igual.
3. Revisa las cabeceras:
   ```bash
   curl -sI https://historiasclinicas.net/ | grep -iE "content-security|strict-transport|x-content-type|cache-control"
   ```
4. Opcional: securityheaders.com y la pestaña *Lighthouse* de Chrome (PWA, accesibilidad).
5. Prueba una historia y una receta completas, **imprimir** incluido: la CSP lo permite expresamente (ver la sección 7).

## 6. Actualizar la app

1. Compila con `./tool/construir_web.sh` y publica `build/web` completo, como la primera vez.
2. Cada navegador descubre la versión nueva al abrir la app con conexión:
   - La descarga en segundo plano, solo lo que cambió (cada archivo se identifica por su huella).
   - Muestra **"Hay una versión nueva de la app"** con el botón **"Actualizar"**.
   - Lo que el médico esté escribiendo se guarda antes de recargar.
3. Si un archivo publicado no coincide con su huella (por ejemplo, un CDN que entrega un archivo viejo), la versión nueva se rechaza y la instalada sigue funcionando.

**Integración continua:** `.github/workflows/ci.yml` corre en cada push y pull request:
- formato, análisis y tests;
- compila el sitio y lo guarda como artefacto `sitio-web`;
- ejecuta las dos pruebas en Chromium con las cabeceras de producción.

No publica nada por sí solo. Si quieres que publique automáticamente en Netlify o Firebase al subir a `main`, se puede agregar con un token del proveedor guardado como *secret* del repositorio.

## 7. Qué hace cada cabecera

| Cabecera | Valor | Para qué |
|---|---|---|
| `Cache-Control` | `no-cache` | El navegador revalida cada archivo con el servidor. Los nombres no cambian entre versiones, y la velocidad la da el service worker, que sirve todo desde el equipo |
| `Content-Security-Policy` | ver `web/_headers` | Solo se ejecuta código del propio sitio, y la app solo puede conectarse a su propio dominio. Aunque alguien lograra inyectar código, no podría enviar datos a otro sitio. Detalle abajo |
| `X-Content-Type-Options` | `nosniff` | El navegador no adivina tipos de archivo |
| `Referrer-Policy` | `no-referrer` | No se informa la dirección de la app a otros sitios |
| `Permissions-Policy` | sin cámara, micrófono, ubicación, pagos ni USB | La app no los usa. Subir una foto del sello sigue funcionando, porque es un selector de archivos |
| `Cross-Origin-Opener-Policy` | `same-origin` | Aísla la ventana de otras pestañas |
| `Strict-Transport-Security` | `max-age=31536000` | Durante un año, el navegador solo entra por HTTPS |

**Detalle de la Content-Security-Policy:**
- `script-src 'self' 'wasm-unsafe-eval'`: el motor gráfico de Flutter es WebAssembly. No se permite `eval`.
  - La vista previa de la receta usa pdf.js sin `eval` (`web/pdfjs/iniciar.js`).
- `'sha256-+M0f…'`: es la huella del pequeño `<script>` con el que el paquete `printing` lanza la impresión.
  - Si una versión nueva del paquete lo cambia, un test avisa. Imprimir sigue funcionando gracias a una copia en `web/pdfjs/iniciar.js`.
- `worker-src blob:`, `frame-src blob:` e `img-src data: blob:`: el *worker* de pdf.js, el PDF que se imprime y las imágenes de firma y sello se crean en memoria.
- `frame-ancestors 'none'`: nadie puede incrustar la app en otra página.

## 8. Privacidad (para tu aviso de privacidad)

- Los datos clínicos se escriben y guardan solo en el navegador del médico, y el PDF se descarga a su equipo. No se envían a ningún servidor.
- El hosting registra las visitas como cualquier sitio web (dirección IP, fecha, archivo pedido). No ve ningún dato clínico.
- Borrar los datos del navegador borra el borrador en curso, los datos del médico, la numeración de recetas y "Mis medicamentos". **Las historias no se pierden: están en los PDF.**
- El catálogo CIE-10 incluido viene de la tabla de referencia de SISPRO (Ministerio de Salud y Protección Social de Colombia). La CIE-10 es una clasificación de la OMS: **VERIFICAR** las condiciones de redistribución si el sitio se vuelve comercial.
