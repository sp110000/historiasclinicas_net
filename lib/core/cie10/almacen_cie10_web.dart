import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const _baseDeDatos = 'historiasclinicas';
const _almacen = 'catalogos';
const _clave = 'cie10';

Future<web.IDBDatabase> _abrir() {
  final completer = Completer<web.IDBDatabase>();
  final peticion = web.window.indexedDB.open(_baseDeDatos, 1);
  peticion.onupgradeneeded = ((web.Event _) {
    final bd = peticion.result! as web.IDBDatabase;
    if (!bd.objectStoreNames.contains(_almacen)) {
      bd.createObjectStore(_almacen);
    }
  }).toJS;
  peticion.onsuccess = ((web.Event _) {
    completer.complete(peticion.result! as web.IDBDatabase);
  }).toJS;
  peticion.onerror = ((web.Event _) {
    completer.completeError(
      StateError('No se pudo abrir IndexedDB: ${peticion.error?.message}'),
    );
  }).toJS;
  return completer.future;
}

/// Ejecuta [operacion] en una transacción y espera a que termine.
Future<JSAny?> _transaccion(
  String modo,
  web.IDBRequest Function(web.IDBObjectStore almacen) operacion,
) async {
  final bd = await _abrir();
  try {
    final tx = bd.transaction(_almacen.toJS, modo);
    final peticion = operacion(tx.objectStore(_almacen));
    final completer = Completer<JSAny?>();
    tx.oncomplete = ((web.Event _) {
      completer.complete(peticion.result);
    }).toJS;
    tx.onerror = ((web.Event _) {
      completer.completeError(
        StateError(
          'IndexedDB: ${tx.error?.message ?? peticion.error?.message}',
        ),
      );
    }).toJS;
    return await completer.future;
  } finally {
    bd.close();
  }
}

Future<String?> leerCatalogoGuardado() async {
  final r = await _transaccion('readonly', (a) => a.get(_clave.toJS));
  return r.isA<JSString>() ? (r! as JSString).toDart : null;
}

Future<void> guardarCatalogo(String json) =>
    _transaccion('readwrite', (a) => a.put(json.toJS, _clave.toJS));

Future<void> borrarCatalogo() =>
    _transaccion('readwrite', (a) => a.delete(_clave.toJS));
