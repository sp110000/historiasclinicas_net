import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../almacen/almacen.dart';
import '../seguridad/boveda.dart';

/// Escribir ([datos]) o borrar (`datos == null`) un registro.
class Escritura {
  const Escritura(this.coleccion, this.id, this.datos);

  final String coleccion;
  final String id;
  final Map<String, Object?>? datos;
}

/// Registros (JSON) y binarios del consultorio, cifrados con la llave de la
/// [Boveda]. Las escrituras van en cola, una tras otra, y cada llamada es
/// atómica: o se guardan todos sus registros o ninguno.
class RepositorioConsultorio {
  RepositorioConsultorio(this.boveda);

  final Boveda boveda;

  AlmacenConsultorio get _almacen => boveda.almacen;

  Future<void> _cola = Future.value();

  static String claveRegistro(String coleccion, String id) {
    if (coleccion.contains('/') || coleccion.isEmpty || id.isEmpty) {
      throw ArgumentError('Colección o id no válidos: $coleccion/$id');
    }
    return '$coleccion/$id';
  }

  static String aadRegistro(String clave) => 'hcc1|$clave';

  static String aadBinario(String clave) => 'hcc1|bin|$clave';

  Future<T> _enCola<T>(Future<T> Function() operacion) {
    final resultado = _cola.then((_) => operacion());
    _cola = resultado.then((_) {}, onError: (_) {});
    return resultado;
  }

  Future<Uint8List> _cifrarRegistro(String clave, Map<String, Object?> datos) =>
      boveda.cifrado.cifrar(
        Uint8List.fromList(utf8.encode(jsonEncode(datos))),
        aadRegistro(clave),
      );

  Future<Map<String, Object?>> _descifrarRegistro(
    String clave,
    Uint8List sobre,
  ) async {
    final claro = await boveda.cifrado.descifrar(sobre, aadRegistro(clave));
    return (jsonDecode(utf8.decode(claro)) as Map).cast<String, Object?>();
  }

  Future<Map<String, Object?>?> leer(String coleccion, String id) async {
    final clave = claveRegistro(coleccion, id);
    final sobre = await _almacen.leer(Deposito.registros, clave);
    return sobre == null ? null : _descifrarRegistro(clave, sobre);
  }

  /// Todos los registros de [coleccion], por id.
  Future<Map<String, Map<String, Object?>>> leerColeccion(
    String coleccion,
  ) async {
    final prefijo = '$coleccion/';
    final todos = await _almacen.leerTodo(Deposito.registros, prefijo: prefijo);
    return {
      for (final e in todos.entries)
        e.key.substring(prefijo.length): await _descifrarRegistro(
          e.key,
          e.value,
        ),
    };
  }

  /// Como [leerColeccion], pero un registro que no se puede descifrar (dañado
  /// o alterado) no detiene la lectura: su id va en `ilegibles`.
  Future<
    ({Map<String, Map<String, Object?>> registros, List<String> ilegibles})
  >
  leerColeccionTolerante(String coleccion) async {
    final prefijo = '$coleccion/';
    final todos = await _almacen.leerTodo(Deposito.registros, prefijo: prefijo);
    final registros = <String, Map<String, Object?>>{};
    final ilegibles = <String>[];
    for (final e in todos.entries) {
      final id = e.key.substring(prefijo.length);
      try {
        registros[id] = await _descifrarRegistro(e.key, e.value);
      } on Object {
        ilegibles.add(id);
      }
    }
    return (registros: registros, ilegibles: ilegibles);
  }

  Future<void> guardar(
    String coleccion,
    String id,
    Map<String, Object?> datos,
  ) => guardarVarios([Escritura(coleccion, id, datos)]);

  Future<void> guardarVarios(List<Escritura> escrituras) => _enCola(() async {
    final cambios = <Cambio>[];
    for (final e in escrituras) {
      final clave = claveRegistro(e.coleccion, e.id);
      final datos = e.datos;
      cambios.add(
        datos == null
            ? Cambio.borrar(Deposito.registros, clave)
            : Cambio(
                Deposito.registros,
                clave,
                await _cifrarRegistro(clave, datos),
              ),
      );
    }
    await _almacen.aplicar(cambios);
  });

  Future<void> guardarBinario(String tipo, String id, Uint8List bytes) =>
      _enCola(() async {
        final clave = claveRegistro(tipo, id);
        await _almacen.aplicar([
          Cambio(
            Deposito.binarios,
            clave,
            await boveda.cifrado.cifrar(bytes, aadBinario(clave)),
          ),
        ]);
      });

  Future<Uint8List?> leerBinario(String tipo, String id) async {
    final clave = claveRegistro(tipo, id);
    final sobre = await _almacen.leer(Deposito.binarios, clave);
    return sobre == null
        ? null
        : boveda.cifrado.descifrar(sobre, aadBinario(clave));
  }

  /// Espera a que terminen las escrituras pendientes.
  Future<void> esperarEscrituras() => _cola;
}

/// Colección con su caché en memoria. Los índices se calculan sobre la
/// caché: con unos miles de registros, buscar en memoria es inmediato.
class Coleccion<T> {
  Coleccion(
    this._repositorio,
    this.nombre, {
    required this.idDe,
    required this.aMapa,
    required this.desdeMapa,
  });

  final RepositorioConsultorio _repositorio;
  final String nombre;
  final String Function(T) idDe;
  final Map<String, Object?> Function(T) aMapa;
  final T Function(Map<String, Object?>) desdeMapa;

  final _items = <String, T>{};
  bool _cargada = false;

  bool get cargada => _cargada;

  Iterable<T> get todos => _items.values;

  T? porId(String id) => _items[id];

  Future<void> cargar() async {
    final datos = await _repositorio.leerColeccion(nombre);
    _items
      ..clear()
      ..addAll({for (final e in datos.entries) e.key: desdeMapa(e.value)});
    _cargada = true;
  }

  Future<void> guardar(T item) async {
    await _repositorio.guardar(nombre, idDe(item), aMapa(item));
    _items[idDe(item)] = item;
  }

  /// Descarta la caché (al bloquear).
  void olvidar() {
    _items.clear();
    _cargada = false;
  }
}
