import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'aviso_pwa.dart';

export 'aviso_pwa.dart';

/// Los avisos que recoge web/flutter_bootstrap.js desde que abre la página.
@JS('hcAvisosPwa')
external _AvisosPwa? get _avisosPwa;

extension type _AvisosPwa._(JSObject _) implements JSObject {
  external JSArray<JSString> get pendientes;
  external set alAvisar(JSFunction? funcion);
}

/// Avisos del service worker: primero los que llegaron mientras la app
/// arrancaba, después los nuevos.
Stream<AvisoPwa> escucharAvisosPwa() {
  final avisos = StreamController<AvisoPwa>();
  final js = _avisosPwa;
  // Con `flutter run` (sin service worker) no hay nada que escuchar.
  if (js == null) return avisos.stream;
  void recibir(String tipo) {
    for (final a in AvisoPwa.values) {
      if (a.name == tipo) avisos.add(a);
    }
  }

  for (final tipo in js.pendientes.toDart) {
    recibir(tipo.toDart);
  }
  js.alAvisar = ((JSString tipo) => recibir(tipo.toDart)).toJS;
  return avisos.stream;
}

void recargarApp() => web.window.location.reload();
