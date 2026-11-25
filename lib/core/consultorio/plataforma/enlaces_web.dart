import 'package:web/web.dart' as web;

/// Abre [url] en otra pestaña, sin darle acceso a esta (`noopener`) ni
/// decirle de dónde viene (`noreferrer`).
void abrirEnlaceExterno(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}
