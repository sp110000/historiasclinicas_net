# Publicar la versión del consultorio

La versión del consultorio es la misma app compilada con `CONSULTORIO_ENABLED=true`. Se publica en **otra dirección**, por ejemplo `consultorio.historiasclinicas.net` (pregunta 2 de [FASE5.md](../FASE5.md)). Así el sitio público `historiasclinicas.net` no cambia, y lo guardado en cada navegador queda separado.

> Yo no publico nada: la cuenta y la publicación las haces tú. Los menús de Cloudflare y Netlify cambian con el tiempo, así que los nombres exactos son **VERIFICAR**.

## 1. Obtener el sitio compilado

Elige una de estas dos formas:

- **Sin instalar nada (recomendado).** En GitHub, entra en *Actions* → *CI* y abre la última ejecución en verde de la rama que quieras publicar. Al final de la página, en *Artifacts*, descarga **`sitio-consultorio`** y descomprímelo. La carpeta resultante es el sitio.
- **En tu Mac:**
  ```bash
  git pull
  flutter clean && flutter pub get
  ./tool/construir_web.sh --dart-define=CONSULTORIO_ENABLED=true --salida build/web-consultorio
  dart run tool/consultorio/verificar_compilacion.dart build/web-consultorio --con-modulo
  ```
  El sitio queda en `build/web-consultorio/`.

**Nunca** pongas `CONSULTORIO_ENABLED` en `.github/workflows/pages.yml`: ese flujo publica `historiasclinicas.net`. Una prueba (`test/tool/consultorio_compilacion_test.dart`) falla si alguien lo hace.

## 2. Publicarlo

### Cloudflare Pages (recomendado)

1. Crea una cuenta gratuita en Cloudflare.
2. *Workers & Pages* → *Create* → *Pages* → **Upload assets** (subida directa, sin conectar GitHub).
3. Ponle un nombre al proyecto, por ejemplo `consultorio-hc`, y arrastra la **carpeta** del sitio. Debe incluir `_headers`, que trae la misma CSP y las mismas cabeceras del sitio público.
4. En el proyecto: *Custom domains* → *Set up a custom domain* → `consultorio.historiasclinicas.net`.
5. En Namecheap (DNS de `historiasclinicas.net`), crea el registro que pide Cloudflare: normalmente un `CNAME` con host `consultorio` que apunta a `consultorio-hc.pages.dev`.
6. Espera a que el certificado HTTPS esté activo. **El consultorio solo funciona con HTTPS**, porque el cifrado del navegador lo exige.

### Netlify (alternativa)

1. Entra en *app.netlify.com/drop* y arrastra la carpeta del sitio. También usa `_headers`.
2. *Domain management* → *Add a domain* → `consultorio.historiasclinicas.net`, y crea en Namecheap el `CNAME` que indique Netlify.

### Restringir quién entra (opcional)

Los datos no están en el servidor: cada navegador guarda los suyos, cifrados con su frase. Aun así, puedes impedir que otros abran la página con **Cloudflare Access** (*Zero Trust* → *Access* → *Applications* → *Self-hosted*).

- Dominio: `consultorio.historiasclinicas.net`.
- Regla: solo tu correo, con un código que llega por correo.
- **VERIFICAR**: el plan gratuito y cuánto dura la sesión. Con conexión, Access pide iniciar sesión cuando la sesión vence. Sin conexión, la app instalada abre igual desde lo guardado en el navegador.

## 3. Primera vez en cada equipo

1. Abre `https://consultorio.historiasclinicas.net` en Chrome o Edge (o Safari en iPhone/iPad) y espera el aviso **«ya funciona sin conexión»**.
2. Instálala:
   - Chrome o Edge: menú → *Instalar*.
   - Safari: *Compartir* → *Agregar a pantalla de inicio*. Así es menos probable que Safari borre lo guardado.
3. **Ajustes** → crea la frase de acceso, descarga e imprime la **hoja de recuperación** y confirma los últimos 4 caracteres.
4. **Ajustes → Respaldo → Respaldar ahora.** Guarda el archivo `.hcrespaldo` en dos lugares distintos, por ejemplo una memoria USB y tu nube.
5. **Ajustes → Seguridad → Medir la derivación.** Envíame los dos tiempos (PBKDF2 y Argon2id) de tu Mac y de tu celular.

**En un segundo equipo** (por ejemplo, el celular): abre la misma dirección, elige *«Tengo un respaldo: restaurarlo»* y usa el respaldo del equipo principal. Así los dos comparten la llave. El paso de datos entre equipos llega en la 5.2.

## 4. Actualizar

Cada versión nueva se publica igual: sube la carpeta nueva al mismo proyecto. La app instalada muestra **«Hay una versión nueva de la app»**, con el botón *Actualizar*, y los datos del consultorio se conservan.

## 5. No cambies de dirección

Lo guardado en el navegador está atado a la dirección exacta. `consultorio.historiasclinicas.net` y `www.consultorio.historiasclinicas.net` cuentan como sitios distintos.

Si alguna vez cambias de dirección:

1. Haz un respaldo en la dirección vieja.
2. Restáuralo en la nueva.
