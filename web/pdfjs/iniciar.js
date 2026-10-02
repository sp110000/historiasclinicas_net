// pdf.js 3.2.146 (Mozilla, licencia Apache 2.0, ver LICENSE) dibuja la vista
// previa de la receta. Se sirve desde el propio sitio, sin CDN, y su
// "worker" se carga en memoria al iniciar: así la vista previa funciona
// aunque después se pierda la conexión.
(function () {
  var base = new URL('pdfjs/', document.baseURI).href;
  // El paquete `printing` de Flutter usa esta ruta si necesita cargar pdf.js.
  window.dartPdfJsBaseUrl = base;
  fetch(base + 'pdf.worker.min.js')
    .then(function (respuesta) {
      if (!respuesta.ok) throw new Error('HTTP ' + respuesta.status);
      return respuesta.blob();
    })
    .then(function (blob) {
      if (window.pdfjsLib) {
        window.pdfjsLib.GlobalWorkerOptions.workerSrc = URL.createObjectURL(blob);
      }
    })
    .catch(function (error) {
      console.warn('pdf.js: no se pudo precargar el worker', error);
    });
})();
