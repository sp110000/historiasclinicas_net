/// Avisos de «se recuperó la conexión» para disparar el worker del RDA: el
/// evento `online` del navegador en la web; nada en las pruebas.
library;

export 'conectividad_stub.dart'
    if (dart.library.js_interop) 'conectividad_web.dart';
