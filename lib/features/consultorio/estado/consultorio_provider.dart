import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/consultorio/almacen/almacen.dart';
import '../../../core/consultorio/almacen/navegador.dart';
import '../../../core/consultorio/modelos/configuracion.dart';
import '../../../core/consultorio/respaldo/respaldo.dart';
import '../../../core/consultorio/seguridad/boveda.dart';
import '../../../core/consultorio/seguridad/motor_aes.dart';
import '../../../core/consultorio/servicio.dart';
import 'pacientes_provider.dart';

/// El servicio del consultorio. Solo se crea si una pantalla del
/// consultorio lo pide, y esas pantallas solo existen con la bandera
/// encendida. Las pruebas lo sustituyen por uno en memoria.
final servicioConsultorioProvider = Provider<ServicioConsultorio>(
  (ref) => ServicioConsultorio(
    almacen: crearAlmacenDePlataforma(),
    motor: crearMotorAes(),
    candado: crearCandadoPestanas(),
  ),
);

enum FaseConsultorio { cargando, sinConfigurar, bloqueado, desbloqueado }

class EstadoConsultorio {
  const EstadoConsultorio({
    this.fase = FaseConsultorio.cargando,
    this.configuracion = const ConfiguracionConsultorio(),
    this.respaldo,
    this.codigoPendiente,
  });

  final FaseConsultorio fase;
  final ConfiguracionConsultorio configuracion;
  final InfoRespaldo? respaldo;

  /// Código de recuperación recién creado que el médico todavía no
  /// confirmó haber guardado. Solo vive en memoria.
  final String? codigoPendiente;

  bool get desbloqueado => fase == FaseConsultorio.desbloqueado;

  EstadoConsultorio copyWith({
    FaseConsultorio? fase,
    ConfiguracionConsultorio? configuracion,
    InfoRespaldo? respaldo,
    bool borrarRespaldo = false,
    String? codigoPendiente,
    bool borrarCodigo = false,
  }) => EstadoConsultorio(
    fase: fase ?? this.fase,
    configuracion: configuracion ?? this.configuracion,
    respaldo: borrarRespaldo ? null : respaldo ?? this.respaldo,
    codigoPendiente: borrarCodigo
        ? null
        : codigoPendiente ?? this.codigoPendiente,
  );
}

/// Estado del consultorio para la interfaz: fase (bloqueado, abierto…),
/// ajustes y último respaldo. Las operaciones lanzan las excepciones del
/// servicio (`SecretoIncorrecto`, `OtraPestanaAbierta`…) para que la
/// pantalla muestre el mensaje.
class ControladorConsultorio extends Notifier<EstadoConsultorio> {
  ServicioConsultorio get _s => ref.read(servicioConsultorioProvider);

  @override
  EstadoConsultorio build() {
    unawaited(_cargar());
    return const EstadoConsultorio();
  }

  Future<void> _cargar() async {
    try {
      final e = await _s.estado();
      final r = await _s.infoRespaldo();
      state = EstadoConsultorio(
        fase: switch (e) {
          EstadoBoveda.sinConfigurar => FaseConsultorio.sinConfigurar,
          EstadoBoveda.bloqueada => FaseConsultorio.bloqueado,
          EstadoBoveda.desbloqueada => FaseConsultorio.desbloqueado,
        },
        configuracion: _s.configuracion,
        respaldo: r,
      );
    } catch (_) {
      // Sin almacén (p. ej. navegación privada que no deja abrir
      // IndexedDB): se muestra como bloqueado y el error sale al desbloquear.
      state = const EstadoConsultorio(fase: FaseConsultorio.bloqueado);
    }
  }

  Future<void> _abierto({String? codigo}) async {
    state = EstadoConsultorio(
      fase: FaseConsultorio.desbloqueado,
      configuracion: _s.configuracion,
      respaldo: await _s.infoRespaldo(),
      codigoPendiente: codigo,
    );
    // El índice ya se cargó (y registró lo pendiente) al abrir.
    ref.read(versionIndiceProvider.notifier).cambio();
    unawaited(pedirPersistencia());
  }

  /// Primera vez. Deja el código de recuperación pendiente de confirmar.
  Future<void> crear(String frase) async {
    final codigo = await _s.crear(frase);
    await _abierto(codigo: codigo);
  }

  void confirmarCodigoGuardado() => state = state.copyWith(borrarCodigo: true);

  Future<void> desbloquear(String frase) async {
    await _s.desbloquear(frase);
    await _abierto();
  }

  Future<void> recuperar(String codigo, String nuevaFrase) async {
    await _s.recuperar(codigo, nuevaFrase);
    await _abierto();
  }

  Future<void> cambiarFrase(String actual, String nueva) =>
      _s.cambiarFrase(actual, nueva);

  /// Devuelve el código nuevo (se muestra una sola vez).
  Future<String> regenerarCodigo(String frase) => _s.regenerarCodigo(frase);

  Future<void> bloquear({bool automatico = false}) async {
    await _s.bloquear(automatico: automatico);
    state = EstadoConsultorio(
      fase: FaseConsultorio.bloqueado,
      respaldo: state.respaldo,
    );
    ref.read(versionIndiceProvider.notifier).cambio();
  }

  Future<void> guardarConfiguracion(ConfiguracionConsultorio c) async {
    await _s.guardarConfiguracion(c);
    state = state.copyWith(configuracion: _s.configuracion);
  }

  Future<ArchivoRespaldo> respaldar() async {
    final archivo = await _s.respaldar();
    state = state.copyWith(respaldo: archivo.info);
    return archivo;
  }

  Future<VerificacionRespaldo> verificar(
    List<int> bytes,
    String secreto, {
    bool esCodigo = false,
  }) => _s.verificar(
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    secreto,
    esCodigo: esCodigo,
  );

  Future<void> restaurar(
    VerificacionRespaldo v, {
    bool aceptarParcial = false,
  }) async {
    await _s.restaurar(v, aceptarParcial: aceptarParcial);
    await _abierto();
  }
}

final consultorioProvider =
    NotifierProvider<ControladorConsultorio, EstadoConsultorio>(
      ControladorConsultorio.new,
    );
