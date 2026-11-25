/// Abrir un enlace externo (WhatsApp) en otra pestaña. En la VM (tests) no
/// hace nada.
library;

export 'enlaces_stub.dart' if (dart.library.js_interop) 'enlaces_web.dart';
