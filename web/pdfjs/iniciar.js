// pdf.js 3.2.146 (Mozilla, licencia Apache 2.0, ver LICENSE) dibuja la vista
// previa de la receta. Se sirve desde el propio sitio, sin CDN, y su
// "worker" se carga en memoria al iniciar: así la vista previa funciona
// aunque se pierda la conexión antes de que el service worker termine.
(function () {
  var base = new URL('pdfjs/', document.baseURI).href;
  var lib = window.pdfjsLib;

  var listo = fetch(base + 'pdf.worker.min.js')
    .then(function (respuesta) {
      if (!respuesta.ok) throw new Error('HTTP ' + respuesta.status);
      return respuesta.blob();
    })
    .then(function (blob) {
      lib.GlobalWorkerOptions.workerSrc = URL.createObjectURL(blob);
    })
    .catch(function (error) {
      console.warn('pdf.js: no se pudo precargar el worker', error);
      lib.GlobalWorkerOptions.workerSrc = base + 'pdf.worker.min.js';
    });

  // Dibuja cada página del PDF como PNG (escala 1 = 72 ppp). Sin eval
  // (isEvalSupported: false): compatible con una Content-Security-Policy
  // sin 'unsafe-eval'. Lo usa lib/core/pdf/rasterizar_web.dart.
  window.hcRasterizarPdf = async function (datos, escala) {
    await listo;
    // Copia: pdf.js puede transferir el búfer al worker.
    var tarea = lib.getDocument({ data: new Uint8Array(datos), isEvalSupported: false });
    var documento = await tarea.promise;
    var imagenes = [];
    try {
      for (var n = 1; n <= documento.numPages; n++) {
        var pagina = await documento.getPage(n);
        var vista = pagina.getViewport({ scale: escala });
        var lienzo = document.createElement('canvas');
        lienzo.width = Math.ceil(vista.width);
        lienzo.height = Math.ceil(vista.height);
        await pagina.render({ canvasContext: lienzo.getContext('2d'), viewport: vista }).promise;
        var png = await new Promise(function (r) {
          lienzo.toBlob(r, 'image/png');
        });
        imagenes.push(new Uint8Array(await png.arrayBuffer()));
        pagina.cleanup();
      }
    } finally {
      await documento.destroy();
    }
    return imagenes;
  };

  // El paquete `printing` imprime el PDF desde un iframe con esta función,
  // que define con un <script> en línea. La Content-Security-Policy solo
  // permite ese script por su huella: si una versión nueva del paquete lo
  // cambia, esta copia sigue funcionando.
  window.__net_nfet_printing___print = function () {
    var f = document.getElementById('__net_nfet_printing__');
    f.focus();
    f.contentWindow.print();
  };
})();
