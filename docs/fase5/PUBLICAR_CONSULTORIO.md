# El consultorio en historiasclinicas.net

Desde el 25/11/2026 el consultorio se publica en la misma dirección del sitio, **`https://historiasclinicas.net`**. Así lo decidiste ese día, en lugar del subdominio que preveía la decisión 2 de [FASE5.md](../FASE5.md). No hace falta otro dominio, otra cuenta ni otro hosting.

`.github/workflows/pages.yml` compila el sitio con `--dart-define=CONSULTORIO_ENABLED=true` en cada push a `main` y lo publica en GitHub Pages, como siempre. Antes de publicar corre las pruebas con la bandera apagada y encendida, y comprueba que el consultorio quedó dentro de `main.dart.js`.

> Los datos **no** van a GitHub ni a ningún servidor. Cada navegador guarda lo suyo, cifrado con la frase que creas en él. La página es pública, como antes; lo que hay en tu navegador, no.

## 1. Qué ve quien abre la página

- **El menú del consultorio** (agenda, pacientes, caja, inventario, ajustes) y, a un clic, la **historia clínica**, la **receta** y los **datos del médico**, que funcionan igual que antes y sin frase.
- Las pantallas del consultorio piden **crear una frase de acceso** la primera vez en ese navegador. Quien no la crea no guarda nada del consultorio.
- **El borrador de la historia y la receta en curso:** si en ese navegador nadie ha creado el consultorio, se guardan como siempre, para no perder lo escrito al cerrar la pestaña. En cuanto se crea el consultorio, pasan al almacén cifrado y se borran de donde estaban en claro (pregunta 6).

## 2. La frase de acceso

**No hay una clave de fábrica.** La frase la inventas tú la primera vez, en tu navegador, y nadie más la conoce: ni yo, ni GitHub. Las frases que aparecen en las pruebas automáticas son de ejemplo.

- 12 caracteres o más. Mejor varias palabras que solo tú relaciones, por ejemplo cuatro palabras sueltas.
- Si la olvidas, entras con el **código de recuperación** de la hoja que imprimes al crearla.
- Sin la frase y sin el código, los datos cifrados no se pueden abrir. Por eso el respaldo es obligatorio.

## 3. Primera vez en cada equipo

1. Abre **`https://historiasclinicas.net`** en Chrome o Edge (o Safari en iPhone/iPad) y espera el aviso **«ya funciona sin conexión»**.
2. Instálala:
   - Chrome o Edge: menú → *Instalar*.
   - Safari: *Compartir* → *Agregar a pantalla de inicio*. Así es menos probable que Safari borre lo guardado.
3. **Ajustes** → crea la frase de acceso, descarga e imprime la **hoja de recuperación** y confirma los últimos 4 caracteres.
4. **Ajustes → Respaldo → Respaldar ahora.** Guarda el archivo `.hcrespaldo` en dos lugares distintos, por ejemplo una memoria USB y tu nube.
5. **Ajustes → Seguridad → Medir la derivación.** Envíame los dos tiempos (PBKDF2 y Argon2id) de tu Mac y de tu celular.

**En un segundo equipo** (por ejemplo, el celular): abre la misma dirección, elige *«Tengo un respaldo: restaurarlo»* y usa el respaldo del equipo principal. Así los dos comparten la llave. Luego, en **Ajustes → Equipo secundario**, marca el celular como secundario: lo que hagas allí vuelve al principal en un paquete cifrado (*«Exportar paquete de este equipo»* en el celular y *«Combinar un paquete»* en el portátil).

## 4. Actualizar

No tienes que hacer nada: cada cambio que llega a `main` se publica solo. La app instalada muestra **«Hay una versión nueva de la app»**, con el botón *Actualizar*, y los datos del consultorio se conservan.

## 5. Usa siempre la misma dirección

Lo guardado en el navegador está atado a la dirección exacta. Usa siempre `https://historiasclinicas.net`, sin `www` (`www.historiasclinicas.net` redirige ahí). La página debe abrir con `https://`: el cifrado del navegador lo exige, y GitHub Pages lo obliga con *Enforce HTTPS* ([DESPLIEGUE.md](../DESPLIEGUE.md), paso E).

Si alguna vez cambias de dirección:

1. Haz un respaldo en la dirección vieja.
2. Restáuralo en la nueva.

## 6. Volver a apagarlo

Quita `--dart-define=CONSULTORIO_ENABLED=true` de la línea *Compilar* de `pages.yml` y ajusta la prueba `test/tool/consultorio_compilacion_test.dart`, que exige que esté. El sitio vuelve a ser el de antes y el código del consultorio sale de `main.dart.js`.

Lo guardado en los navegadores no se borra, pero deja de verse hasta que lo vuelvas a encender. Haz un respaldo antes.

## 7. Si algún día lo quieres en otra dirección (opcional)

También puedes publicarlo aparte, por ejemplo en `consultorio.historiasclinicas.net`. **Tampoco es comprar otro dominio:** es un registro DNS gratuito en Namecheap y un proyecto gratuito en Cloudflare Pages. Los menús de Cloudflare cambian con el tiempo, así que los nombres exactos son **VERIFICAR**.

1. En GitHub, *Actions* → *CI* → la última ejecución en verde de `main` → *Artifacts* → descarga **`sitio-consultorio`** y descomprímelo.
2. Cloudflare: *Workers & Pages* → *Create* → *Pages* → **Upload assets**, y arrastra la carpeta.
3. En el proyecto: *Custom domains* → `consultorio.historiasclinicas.net`, y crea en Namecheap el `CNAME` que pida Cloudflare.
4. Restaura allí un respaldo de `historiasclinicas.net`: son direcciones distintas y no comparten lo guardado.
