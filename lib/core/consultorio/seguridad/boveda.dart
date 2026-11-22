import 'dart:typed_data';

import '../../ihce/reloj.dart';
import '../almacen/almacen.dart';
import 'cifrado_registros.dart';
import 'llavero.dart';
import 'motor_aes.dart';

enum EstadoBoveda { sinConfigurar, bloqueada, desbloqueada }

/// Se intentó leer o escribir con el consultorio bloqueado.
class BovedaBloqueada implements Exception {
  const BovedaBloqueada();

  @override
  String toString() => 'BovedaBloqueada';
}

/// Claves del depósito `meta` (en claro).
abstract final class ClavesMeta {
  static const llavero = 'llavero';
  static const esquema = 'esquema';
  static const respaldo = 'respaldo';

  /// Cuándo se restauró un respaldo en este equipo (el paquete del equipo
  /// secundario lleva lo creado desde entonces).
  static const restauradoEn = 'restauradoEn';

  /// `secundario` si este equipo es el secundario (su serie de documentos
  /// lleva «S»). Es de este equipo: no viaja en el respaldo.
  static const rolEquipo = 'rolEquipo';
}

/// El llavero y la llave de datos en memoria.
///
/// Desbloqueada, la llave de datos vive solo como llave **no extraíble** del
/// motor (en el navegador, un `CryptoKey` de WebCrypto); sus bytes se borran
/// en cuanto se importa. Al bloquear se descarta esa referencia.
class Boveda {
  Boveda({
    required this.almacen,
    required MotorAes motor,
    FabricaLlavero? fabrica,
    this.reloj = const RelojSistema(),
  }) : _motor = motor,
       _fabrica = fabrica ?? FabricaLlavero(motor);

  final AlmacenConsultorio almacen;
  final MotorAes _motor;
  final FabricaLlavero _fabrica;
  final Reloj reloj;

  CifradoRegistros? _cifrado;

  bool get desbloqueada => _cifrado != null;

  CifradoRegistros get cifrado => _cifrado ?? (throw const BovedaBloqueada());

  Future<Llavero?> leerLlavero() async {
    final b = await almacen.leer(Deposito.meta, ClavesMeta.llavero);
    return b == null ? null : Llavero.desdeBytes(b);
  }

  Future<EstadoBoveda> leerEstado() async {
    if (desbloqueada) return EstadoBoveda.desbloqueada;
    return await leerLlavero() == null
        ? EstadoBoveda.sinConfigurar
        : EstadoBoveda.bloqueada;
  }

  Future<void> _usarLlave(Uint8List llaveDatos) async {
    try {
      _cifrado = CifradoRegistros(_motor, await _motor.importar(llaveDatos));
    } finally {
      llaveDatos.fillRange(0, llaveDatos.length, 0);
    }
  }

  /// Crea el llavero y deja la bóveda desbloqueada. Devuelve el código de
  /// recuperación, que no se guarda en ningún lado.
  Future<String> crear(String frase) async {
    if (await leerLlavero() != null) {
      throw StateError('El consultorio ya tiene una frase de acceso.');
    }
    final r = await _fabrica.crear(frase, ahora: reloj.ahora());
    await almacen.aplicar([
      Cambio(Deposito.meta, ClavesMeta.llavero, r.llavero.aBytes()),
    ]);
    await _usarLlave(r.llaveDatos);
    return r.codigo;
  }

  Future<Llavero> _llaveroExistente() async =>
      await leerLlavero() ??
      (throw StateError('El consultorio no tiene frase de acceso.'));

  /// Lanza [SecretoIncorrecto] si la frase no es la correcta.
  Future<void> desbloquear(String frase) async {
    final llavero = await _llaveroExistente();
    await _usarLlave(await _fabrica.abrirConFrase(llavero, frase));
  }

  /// Abre con el código de recuperación y pone [nuevaFrase]. Lanza
  /// [SecretoIncorrecto] si el código no es el correcto.
  Future<void> recuperar(String codigo, String nuevaFrase) async {
    final llavero = await _llaveroExistente();
    final llave = await _fabrica.abrirConCodigo(llavero, codigo);
    try {
      final nuevo = await _fabrica.cambiarFrase(llavero, llave, nuevaFrase);
      await almacen.aplicar([
        Cambio(Deposito.meta, ClavesMeta.llavero, nuevo.aBytes()),
      ]);
      await _usarLlave(Uint8List.fromList(llave));
    } finally {
      llave.fillRange(0, llave.length, 0);
    }
  }

  /// Lanza [SecretoIncorrecto] si [actual] no es la frase de hoy.
  Future<void> cambiarFrase(String actual, String nueva) async {
    final llavero = await _llaveroExistente();
    final llave = await _fabrica.abrirConFrase(llavero, actual);
    try {
      final nuevo = await _fabrica.cambiarFrase(llavero, llave, nueva);
      await almacen.aplicar([
        Cambio(Deposito.meta, ClavesMeta.llavero, nuevo.aBytes()),
      ]);
    } finally {
      llave.fillRange(0, llave.length, 0);
    }
  }

  /// Genera un código de recuperación nuevo; el anterior deja de servir.
  /// Lanza [SecretoIncorrecto] si [frase] no es la de hoy.
  Future<String> regenerarCodigo(String frase) async {
    final llavero = await _llaveroExistente();
    final llave = await _fabrica.abrirConFrase(llavero, frase);
    try {
      final r = await _fabrica.cambiarCodigo(llavero, llave);
      await almacen.aplicar([
        Cambio(Deposito.meta, ClavesMeta.llavero, r.llavero.aBytes()),
      ]);
      return r.codigo;
    } finally {
      llave.fillRange(0, llave.length, 0);
    }
  }

  /// Descarta la llave. Lo cifrado sigue en el almacén.
  void bloquear() => _cifrado = null;

  /// Usa la llave de datos que trae un respaldo restaurado (ya abierto con
  /// su frase): el llavero del respaldo reemplaza al de este equipo.
  Future<void> adoptarLlave(Uint8List llaveDatos) => _usarLlave(llaveDatos);
}
