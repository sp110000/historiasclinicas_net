import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../config.dart';
import 'navegador.dart';

/// Pide que el navegador no borre lo guardado cuando le falte espacio.
/// Devuelve si quedó concedido.
Future<bool> pedirPersistencia() async {
  try {
    return (await web.window.navigator.storage.persist().toDart).toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> estaPersistido() async {
  try {
    return (await web.window.navigator.storage.persisted().toDart).toDart;
  } catch (_) {
    return false;
  }
}

Future<EspacioAlmacen?> estimarEspacio() async {
  try {
    final e = await web.window.navigator.storage.estimate().toDart;
    return EspacioAlmacen(usado: e.usage, cuota: e.quota);
  } catch (_) {
    return null;
  }
}

CandadoPestanas crearCandadoPestanas() => _CandadoWebLocks();

/// Web Locks API: el candado se pide con `ifAvailable` (no espera) y se
/// conserva mientras no se resuelva la promesa devuelta al navegador.
class _CandadoWebLocks implements CandadoPestanas {
  Completer<void>? _liberar;

  @override
  Future<bool> tomar() async {
    if (_liberar != null) return true;
    final concedido = Completer<bool>();
    final liberar = Completer<void>();
    JSPromise<JSAny?>? alObtener(web.Lock? candado) {
      if (candado == null) {
        concedido.complete(false);
        return null;
      }
      concedido.complete(true);
      return liberar.future.then((_) => null).toJS;
    }

    try {
      web.window.navigator.locks.request(
        baseDeDatosConsultorio,
        web.LockOptions(ifAvailable: true),
        alObtener.toJS,
      );
    } catch (_) {
      // Navegador sin Web Locks: se permite seguir, como antes.
      return true;
    }
    final ok = await concedido.future;
    if (ok) _liberar = liberar;
    return ok;
  }

  @override
  void soltar() {
    _liberar?.complete();
    _liberar = null;
  }
}
