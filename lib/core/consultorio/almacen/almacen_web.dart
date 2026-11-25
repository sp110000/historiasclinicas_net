import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../config.dart';
import 'almacen.dart';

AlmacenConsultorio crearAlmacenDePlataforma() => AlmacenIndexedDb();

/// IndexedDB `historiasclinicas_consultorio`, versión 1, con un object store
/// por [Deposito]. Es una base aparte de la del CIE-10 y de la de IHCE, para
/// no tocar sus versiones.
class AlmacenIndexedDb implements AlmacenConsultorio {
  static const _version = 1;

  Future<web.IDBDatabase>? _bd;

  static String _nombre(Deposito d) => d.name;

  Future<web.IDBDatabase> _abrir() => _bd ??= () {
    final completer = Completer<web.IDBDatabase>();
    final peticion = web.window.indexedDB.open(
      baseDeDatosConsultorio,
      _version,
    );
    peticion.onupgradeneeded = ((web.Event _) {
      final bd = peticion.result! as web.IDBDatabase;
      for (final d in Deposito.values) {
        if (!bd.objectStoreNames.contains(_nombre(d))) {
          bd.createObjectStore(_nombre(d));
        }
      }
    }).toJS;
    peticion.onsuccess = ((web.Event _) {
      final bd = peticion.result! as web.IDBDatabase;
      // Otra pestaña con una versión nueva de la app pide actualizar la
      // base: se cierra esta conexión para no bloquearla.
      bd.onversionchange = ((web.Event _) {
        bd.close();
        _bd = null;
      }).toJS;
      completer.complete(bd);
    }).toJS;
    peticion.onerror = ((web.Event _) {
      _bd = null;
      completer.completeError(
        StateError('No se pudo abrir el almacén: ${peticion.error?.message}'),
      );
    }).toJS;
    peticion.onblocked = ((web.Event _) {
      _bd = null;
      completer.completeError(
        StateError(
          'El almacén está bloqueado por otra pestaña: ciérrala y vuelve a '
          'intentarlo.',
        ),
      );
    }).toJS;
    return completer.future;
  }();

  /// Abre una transacción sobre [depositos] y la resuelve al completarse
  /// (`oncomplete`), cuando lo escrito ya es durable.
  Future<T> _transaccion<T>(
    List<Deposito> depositos,
    String modo,
    T Function(web.IDBTransaction tx) operar,
  ) async {
    final bd = await _abrir();
    final tx = bd.transaction(
      [for (final d in depositos) _nombre(d).toJS].toJS,
      modo,
    );
    final completer = Completer<T>();
    late final T resultado;
    tx.oncomplete = ((web.Event _) {
      if (!completer.isCompleted) completer.complete(resultado);
    }).toJS;
    void fallar(web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Error del almacén: ${tx.error?.message ?? 'abortado'}'),
        );
      }
    }

    tx.onerror = fallar.toJS;
    tx.onabort = fallar.toJS;
    try {
      resultado = operar(tx);
    } catch (e) {
      tx.abort();
      rethrow;
    }
    return completer.future;
  }

  static Uint8List? _bytes(JSAny? v) {
    if (v == null || !v.isA<JSUint8Array>()) return null;
    return (v as JSUint8Array).toDart;
  }

  @override
  Future<Uint8List?> leer(Deposito deposito, String clave) async {
    late final web.IDBRequest peticion;
    await _transaccion([deposito], 'readonly', (tx) {
      peticion = tx.objectStore(_nombre(deposito)).get(clave.toJS);
    });
    return _bytes(peticion.result);
  }

  @override
  Future<Map<String, Uint8List>> leerTodo(
    Deposito deposito, {
    String prefijo = '',
  }) async {
    late final web.IDBRequest claves;
    late final web.IDBRequest valores;
    await _transaccion([deposito], 'readonly', (tx) {
      final almacen = tx.objectStore(_nombre(deposito));
      final rango = prefijo.isEmpty
          ? null
          : web.IDBKeyRange.bound(prefijo.toJS, '$prefijo￿'.toJS);
      claves = rango == null ? almacen.getAllKeys() : almacen.getAllKeys(rango);
      valores = rango == null ? almacen.getAll() : almacen.getAll(rango);
    });
    final k = (claves.result as JSArray<JSAny?>?)?.toDart ?? const [];
    final v = (valores.result as JSArray<JSAny?>?)?.toDart ?? const [];
    return {
      for (var i = 0; i < k.length && i < v.length; i++)
        if (k[i].isA<JSString>() && _bytes(v[i]) != null)
          (k[i]! as JSString).toDart: _bytes(v[i])!,
    };
  }

  @override
  Future<void> aplicar(List<Cambio> cambios, {bool vaciarAntes = false}) =>
      _transaccion(Deposito.values, 'readwrite', (tx) {
        if (vaciarAntes) {
          for (final d in Deposito.values) {
            tx.objectStore(_nombre(d)).clear();
          }
        }
        for (final c in cambios) {
          final almacen = tx.objectStore(_nombre(c.deposito));
          final valor = c.valor;
          if (valor == null) {
            almacen.delete(c.clave.toJS);
          } else {
            almacen.put(valor.toJS, c.clave.toJS);
          }
        }
      });

  @override
  Future<void> cerrar() async {
    final bd = _bd;
    _bd = null;
    if (bd != null) (await bd).close();
  }
}
