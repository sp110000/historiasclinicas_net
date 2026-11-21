/// Almacén del consultorio: tres depósitos de bytes con escritura atómica.
///
/// En la web es la base de IndexedDB `historiasclinicas_consultorio`; en la
/// VM (tests), un almacén en memoria. Los valores de `registros` y
/// `binarios` llegan ya cifrados: este nivel no ve datos en claro.
library;

import 'dart:typed_data';

export 'almacen_memoria.dart'
    if (dart.library.js_interop) 'almacen_web.dart'
    show crearAlmacenDePlataforma;

/// Los depósitos (object stores) de la base.
enum Deposito {
  /// En claro: llavero, versión del esquema y último respaldo.
  meta,

  /// Registros cifrados, con clave `<colección>/<id>`.
  registros,

  /// Binarios cifrados (fotos, PDF exactos, firmas), con clave
  /// `<tipo>/<id>`.
  binarios,
}

/// Escribir ([valor]) o borrar (`valor == null`) una clave.
class Cambio {
  const Cambio(this.deposito, this.clave, this.valor);

  const Cambio.borrar(this.deposito, this.clave) : valor = null;

  final Deposito deposito;
  final String clave;
  final Uint8List? valor;
}

abstract interface class AlmacenConsultorio {
  Future<Uint8List?> leer(Deposito deposito, String clave);

  /// Todas las entradas cuya clave empieza por [prefijo], en orden de clave.
  Future<Map<String, Uint8List>> leerTodo(
    Deposito deposito, {
    String prefijo = '',
  });

  /// Aplica [cambios] en **una** transacción: o se aplican todos o ninguno.
  /// Con [vaciarAntes], primero borra los tres depósitos (restaurar).
  Future<void> aplicar(List<Cambio> cambios, {bool vaciarAntes = false});

  Future<void> cerrar();
}

/// Almacén en memoria (pruebas y VM). [datos] queda a la vista para que las
/// pruebas comprueben que nada se guarda en claro.
class AlmacenMemoria implements AlmacenConsultorio {
  final datos = {for (final d in Deposito.values) d: <String, Uint8List>{}};

  /// Si es `true`, la siguiente llamada a [aplicar] falla sin cambiar nada
  /// (para probar la atomicidad).
  bool fallarProximaEscritura = false;

  @override
  Future<Uint8List?> leer(Deposito deposito, String clave) async {
    final v = datos[deposito]![clave];
    return v == null ? null : Uint8List.fromList(v);
  }

  @override
  Future<Map<String, Uint8List>> leerTodo(
    Deposito deposito, {
    String prefijo = '',
  }) async {
    final claves =
        datos[deposito]!.keys.where((k) => k.startsWith(prefijo)).toList()
          ..sort();
    return {
      for (final k in claves) k: Uint8List.fromList(datos[deposito]![k]!),
    };
  }

  @override
  Future<void> aplicar(List<Cambio> cambios, {bool vaciarAntes = false}) async {
    if (fallarProximaEscritura) {
      fallarProximaEscritura = false;
      throw StateError('Fallo simulado de escritura');
    }
    if (vaciarAntes) {
      for (final d in datos.values) {
        d.clear();
      }
    }
    for (final c in cambios) {
      final valor = c.valor;
      if (valor == null) {
        datos[c.deposito]!.remove(c.clave);
      } else {
        datos[c.deposito]![c.clave] = Uint8List.fromList(valor);
      }
    }
  }

  @override
  Future<void> cerrar() async {}
}
