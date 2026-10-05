import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'almacen_kv.dart';

AlmacenKv crearAlmacenKv() => AlmacenKvIndexedDb();

/// IndexedDB, como el catálogo CIE-10 importado (`almacen_cie10_web.dart`),
/// pero en una base propia para no tocar la versión de la existente.
class AlmacenKvIndexedDb implements AlmacenKv {
  static const _baseDeDatos = 'historiasclinicas_ihce';
  static const _almacen = 'kv';

  Future<web.IDBDatabase>? _bd;

  Future<web.IDBDatabase> _abrir() => _bd ??= () {
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
  }();

  Future<JSAny?> _transaccion(
    String modo,
    web.IDBRequest Function(web.IDBObjectStore almacen) operacion,
  ) async {
    final bd = await _abrir();
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
    return completer.future;
  }

  @override
  Future<String?> leer(String clave) async {
    final r = await _transaccion('readonly', (a) => a.get(clave.toJS));
    return r.isA<JSString>() ? (r! as JSString).toDart : null;
  }

  @override
  Future<void> escribir(String clave, String valor) =>
      _transaccion('readwrite', (a) => a.put(valor.toJS, clave.toJS));

  @override
  Future<void> borrar(String clave) =>
      _transaccion('readwrite', (a) => a.delete(clave.toJS));

  @override
  Future<List<String>> claves([String prefijo = '']) async {
    final r = await _transaccion('readonly', (a) => a.getAllKeys());
    final lista = (r as JSArray<JSAny?>?)?.toDart ?? const [];
    return [
      for (final k in lista)
        if (k.isA<JSString>() && (k! as JSString).toDart.startsWith(prefijo))
          (k as JSString).toDart,
    ];
  }
}
