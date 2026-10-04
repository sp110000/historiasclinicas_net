/// Almacenamiento clave → texto del módulo IHCE: IndexedDB en la web (base
/// propia `historiasclinicas_ihce`, aparte de la del CIE-10) y memoria en
/// las pruebas y en las plataformas sin IndexedDB.
library;

import 'almacen_kv_memoria.dart'
    if (dart.library.js_interop) 'almacen_kv_web.dart'
    as plataforma;

abstract interface class AlmacenKv {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
  Future<void> borrar(String clave);

  /// Todas las claves que empiezan por [prefijo].
  Future<List<String>> claves([String prefijo = '']);
}

/// El almacén persistente de la plataforma.
AlmacenKv almacenKvDePlataforma() => plataforma.crearAlmacenKv();

class AlmacenKvMemoria implements AlmacenKv {
  final datos = <String, String>{};

  @override
  Future<String?> leer(String clave) async => datos[clave];

  @override
  Future<void> escribir(String clave, String valor) async =>
      datos[clave] = valor;

  @override
  Future<void> borrar(String clave) async => datos.remove(clave);

  @override
  Future<List<String>> claves([String prefijo = '']) async => [
    for (final k in datos.keys)
      if (k.startsWith(prefijo)) k,
  ];
}
