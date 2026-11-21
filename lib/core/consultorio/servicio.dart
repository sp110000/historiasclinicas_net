import 'dart:typed_data';

import '../ihce/reloj.dart';
import 'almacen/almacen.dart';
import 'almacen/navegador.dart';
import 'indice/indice_pacientes.dart';
import 'modelos/registro_historia.dart';
import 'modelos/configuracion.dart';
import 'repositorio/bitacora.dart';
import 'repositorio/migraciones.dart';
import 'repositorio/repositorio.dart';
import 'respaldo/respaldo.dart';
import 'seguridad/boveda.dart';
import 'seguridad/llavero.dart';
import 'seguridad/motor_aes.dart';

/// El consultorio ya está abierto en otra pestaña de este navegador.
class OtraPestanaAbierta implements Exception {
  const OtraPestanaAbierta();

  @override
  String toString() => 'OtraPestanaAbierta';
}

/// Historia guardada o abierta con el consultorio bloqueado: se registra
/// en el índice al desbloquearlo. Solo vive en memoria (nunca se escribe en
/// claro); si se cierra la pestaña antes, el PDF se puede importar.
class HistoriaPendiente {
  const HistoriaPendiente({
    required this.datos,
    required this.revision,
    required this.origen,
    this.nombreArchivo = '',
    this.bytesPdf,
  });

  final Map<String, Object?> datos;
  final int revision;
  final OrigenArchivo origen;
  final String nombreArchivo;
  final Uint8List? bytesPdf;
}

/// Punto de entrada del consultorio, sin interfaz: bóveda, repositorio,
/// migraciones, ajustes, bitácora y respaldo.
class ServicioConsultorio {
  ServicioConsultorio({
    required AlmacenConsultorio almacen,
    required this.motor,
    required CandadoPestanas candado,
    FabricaLlavero? fabrica,
    this.reloj = const RelojSistema(),
    this.versionApp = '',
  }) : _candado = candado,
       _fabrica = fabrica ?? FabricaLlavero(motor) {
    boveda = Boveda(
      almacen: almacen,
      motor: motor,
      fabrica: _fabrica,
      reloj: reloj,
    );
    repositorio = RepositorioConsultorio(boveda);
    indice = IndicePacientes(repositorio, reloj: reloj);
  }

  final MotorAes motor;
  final CandadoPestanas _candado;
  final FabricaLlavero _fabrica;
  final Reloj reloj;
  final String versionApp;

  late final Boveda boveda;
  late final RepositorioConsultorio repositorio;

  /// Fichas e historias descifradas; vacío mientras está bloqueado.
  late final IndicePacientes indice;

  final _pendientes = <HistoriaPendiente>[];

  /// Historias que esperan a que se desbloquee el consultorio.
  int get historiasPendientes => _pendientes.length;

  ConfiguracionConsultorio _configuracion = const ConfiguracionConsultorio();

  ConfiguracionConsultorio get configuracion => _configuracion;

  AlmacenConsultorio get almacen => boveda.almacen;

  Future<EstadoBoveda> estado() => boveda.leerEstado();

  Future<InfoRespaldo?> infoRespaldo() => leerInfoRespaldo(almacen);

  /// Toma el candado, migra el esquema y carga los ajustes. Si algo falla,
  /// vuelve a bloquear.
  Future<void> _alAbrir(AccionBitacora accion) async {
    try {
      if (!await _candado.tomar()) throw const OtraPestanaAbierta();
      await migrar(repositorio);
      final c = await repositorio.leer(
        ConfiguracionConsultorio.coleccion,
        ConfiguracionConsultorio.id,
      );
      _configuracion = c == null
          ? const ConfiguracionConsultorio()
          : ConfiguracionConsultorio.desdeMapa(c);
      await indice.cargar();
      await registrarEnBitacora(repositorio, accion, fecha: reloj.ahora());
    } catch (_) {
      _cerrarSesion();
      rethrow;
    }
    await _registrarPendientes();
  }

  Future<void> _registrarPendientes() async {
    while (_pendientes.isNotEmpty && boveda.desbloqueada) {
      final p = _pendientes.removeAt(0);
      try {
        await indice.registrarHistoria(
          p.datos,
          revision: p.revision,
          origen: p.origen,
          nombreArchivo: p.nombreArchivo,
          bytesPdf: p.bytesPdf,
        );
      } on Object {
        // Datos que no son una historia: no hay nada que registrar.
      }
    }
  }

  /// Registra en el índice una historia que se guardó o se abrió. Con el
  /// consultorio bloqueado la deja pendiente y devuelve `null`.
  Future<ResultadoRegistro?> registrarHistoria(HistoriaPendiente h) async {
    if (!boveda.desbloqueada) {
      _pendientes
        ..removeWhere(
          (p) => p.datos['id'] == h.datos['id'] && p.revision <= h.revision,
        )
        ..add(h);
      return null;
    }
    return indice.registrarHistoria(
      h.datos,
      revision: h.revision,
      origen: h.origen,
      nombreArchivo: h.nombreArchivo,
      bytesPdf: h.bytesPdf,
    );
  }

  void _cerrarSesion() {
    indice.olvidar();
    boveda.bloquear();
    _candado.soltar();
    _configuracion = const ConfiguracionConsultorio();
  }

  /// Primera vez: crea la frase. Devuelve el código de recuperación.
  Future<String> crear(String frase) async {
    final codigo = await boveda.crear(frase);
    await _alAbrir(AccionBitacora.crearFrase);
    return codigo;
  }

  /// Lanza [SecretoIncorrecto] u [OtraPestanaAbierta].
  Future<void> desbloquear(String frase) async {
    await boveda.desbloquear(frase);
    await _alAbrir(AccionBitacora.desbloquear);
  }

  /// Con el código de recuperación y una frase nueva.
  Future<void> recuperar(String codigo, String nuevaFrase) async {
    await boveda.recuperar(codigo, nuevaFrase);
    await _alAbrir(AccionBitacora.recuperar);
  }

  Future<void> cambiarFrase(String actual, String nueva) async {
    await boveda.cambiarFrase(actual, nueva);
    await registrarEnBitacora(
      repositorio,
      AccionBitacora.cambiarFrase,
      fecha: reloj.ahora(),
    );
  }

  /// El código anterior deja de servir. Lanza [SecretoIncorrecto].
  Future<String> regenerarCodigo(String frase) async {
    final codigo = await boveda.regenerarCodigo(frase);
    await registrarEnBitacora(
      repositorio,
      AccionBitacora.regenerarCodigo,
      fecha: reloj.ahora(),
    );
    return codigo;
  }

  Future<void> bloquear({bool automatico = false}) async {
    if (!boveda.desbloqueada) return;
    try {
      await registrarEnBitacora(
        repositorio,
        automatico ? AccionBitacora.bloqueoAutomatico : AccionBitacora.bloquear,
        fecha: reloj.ahora(),
      );
      await repositorio.esperarEscrituras();
    } finally {
      _cerrarSesion();
    }
  }

  Future<void> guardarConfiguracion(ConfiguracionConsultorio c) async {
    await repositorio.guardar(
      ConfiguracionConsultorio.coleccion,
      ConfiguracionConsultorio.id,
      c.aMapa(),
    );
    _configuracion = c;
    await registrarEnBitacora(
      repositorio,
      AccionBitacora.cambiarAjustes,
      fecha: reloj.ahora(),
    );
  }

  Future<ArchivoRespaldo> respaldar() async {
    await registrarEnBitacora(
      repositorio,
      AccionBitacora.respaldar,
      fecha: reloj.ahora(),
    );
    await repositorio.esperarEscrituras();
    return exportarRespaldo(
      boveda,
      ahora: reloj.ahora(),
      versionApp: versionApp,
    );
  }

  Future<VerificacionRespaldo> verificar(
    Uint8List bytes,
    String secreto, {
    bool esCodigo = false,
  }) => verificarRespaldo(
    bytes,
    secreto,
    motor: motor,
    esCodigo: esCodigo,
    fabrica: _fabrica,
  );

  /// Reemplaza todo por el respaldo y deja el consultorio abierto con él.
  Future<void> restaurar(
    VerificacionRespaldo v, {
    bool aceptarParcial = false,
  }) async {
    await repositorio.esperarEscrituras();
    if (!boveda.desbloqueada && !await _candado.tomar()) {
      throw const OtraPestanaAbierta();
    }
    await restaurarRespaldo(boveda, v, aceptarParcial: aceptarParcial);
    await _alAbrir(AccionBitacora.restaurar);
  }

  Future<List<EntradaBitacora>> bitacora() => leerBitacora(repositorio);
}
