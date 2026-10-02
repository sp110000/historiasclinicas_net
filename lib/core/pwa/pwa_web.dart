import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'aviso_pwa.dart';

export 'aviso_pwa.dart';

/// Avisos del service worker. Los que llegan antes de escuchar se guardan.
Stream<AvisoPwa> escucharAvisosPwa() {
  final avisos = StreamController<AvisoPwa>();
  // Sin HTTPS (o en navegadores sin service worker) no hay nada que escuchar.
  if (!web.window.navigator.has('serviceWorker')) return avisos.stream;
  final sw = web.window.navigator.serviceWorker;
  // Si la página ya estaba controlada al abrir, un controlador nuevo es una
  // versión nueva. Si no, es la primera instalación.
  final habiaControlador = sw.controller != null;
  sw
    ..addEventListener(
      'message',
      (web.MessageEvent e) {
        final datos = e.data.dartify();
        if (datos is Map &&
            datos['tipo'] == 'lista' &&
            datos['completa'] == true &&
            !habiaControlador) {
          avisos.add(AvisoPwa.listaSinConexion);
        }
      }.toJS,
    )
    ..addEventListener(
      'controllerchange',
      (web.Event _) {
        if (habiaControlador) avisos.add(AvisoPwa.versionNueva);
      }.toJS,
    )
    ..startMessages();
  return avisos.stream;
}

void recargarApp() => web.window.location.reload();
