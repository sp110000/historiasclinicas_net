/// Reduce la foto a 1600 px, la codifica en JPEG al 80 % y quita sus
/// metadatos (EXIF con la ubicación GPS). En el navegador usa el lienzo;
/// en la VM (pruebas) solo quita los metadatos.
library;

export 'foto_procesada.dart';
export 'procesar_foto_stub.dart'
    if (dart.library.js_interop) 'procesar_foto_web.dart';
