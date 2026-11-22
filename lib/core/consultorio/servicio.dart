import 'dart:convert';
import 'dart:typed_data';

import '../ihce/reloj.dart';
import 'almacen/almacen.dart';
import 'almacen/navegador.dart';
import 'documentos/documentos.dart';
import 'seguimiento/seguimiento.dart';
import 'indice/indice_pacientes.dart';
import '../models/paciente.dart';
import 'modelos/registro_historia.dart';
import 'modelos/configuracion.dart';
import 'repositorio/bitacora.dart';
import 'repositorio/migraciones.dart';
import 'repositorio/repositorio.dart';
import 'respaldo/paquete.dart';
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

/// Receta emitida con el consultorio bloqueado: se registra al
/// desbloquearlo. Solo en memoria, como [HistoriaPendiente].
class RecetaPendiente {
  const RecetaPendiente({
    required this.recetaId,
    required this.paciente,
    required this.fecha,
    required this.bytesPdf,
    this.numero,
    this.historiaId = '',
    this.items = const [],
    this.indicaciones = '',
    this.nombreArchivo = '',
  });

  final String recetaId;
  final Paciente paciente;
  final DateTime fecha;
  final Uint8List bytesPdf;
  final String? numero;
  final String historiaId;
  final List<String> items;
  final String indicaciones;
  final String nombreArchivo;
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
    documentos = DocumentosConsultorio(repositorio, indice, reloj: reloj);
    seguimiento = SeguimientoConsultorio(
      repositorio,
      indice,
      documentos,
      reloj: reloj,
    );
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

  /// Plantillas y documentos firmados; vacío mientras está bloqueado.
  late final DocumentosConsultorio documentos;

  /// Mediciones y fotos; vacío mientras está bloqueado.
  late final SeguimientoConsultorio seguimiento;

  final _pendientes = <HistoriaPendiente>[];
  final _recetasPendientes = <RecetaPendiente>[];

  /// Historias y recetas que esperan a que se desbloquee el consultorio.
  int get historiasPendientes => _pendientes.length;
  int get recetasPendientes => _recetasPendientes.length;

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
      await documentos.cargar();
      documentos.serie = await esEquipoSecundario() ? 'S' : '';
      await seguimiento.cargar();
      await registrarEnBitacora(repositorio, accion, fecha: reloj.ahora());
    } catch (_) {
      _cerrarSesion();
      rethrow;
    }
    await _registrarPendientes();
  }

  Future<void> _registrarPendientes() async {
    while (_recetasPendientes.isNotEmpty && boveda.desbloqueada) {
      try {
        await _registrarReceta(_recetasPendientes.removeAt(0));
      } on Object {
        // Sin paciente reconocible: la receta sigue en su PDF.
      }
    }
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

  /// Registra una receta emitida. Con el consultorio bloqueado la deja
  /// pendiente y devuelve `null`; si no, devuelve la ficha.
  Future<String?> registrarReceta(RecetaPendiente r) async {
    if (!boveda.desbloqueada) {
      _recetasPendientes
        ..removeWhere((p) => p.recetaId == r.recetaId)
        ..add(r);
      return null;
    }
    return _registrarReceta(r);
  }

  Future<String> _registrarReceta(RecetaPendiente r) => indice.registrarReceta(
    recetaId: r.recetaId,
    paciente: r.paciente,
    fecha: r.fecha,
    bytesPdf: r.bytesPdf,
    numero: r.numero,
    historiaId: r.historiaId,
    items: r.items,
    indicaciones: r.indicaciones,
    nombreArchivo: r.nombreArchivo,
  );

  void _cerrarSesion() {
    indice.olvidar();
    documentos.olvidar();
    seguimiento.olvidar();
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
    await restaurarRespaldo(
      boveda,
      v,
      aceptarParcial: aceptarParcial,
      ahora: reloj.ahora(),
    );
    await _alAbrir(AccionBitacora.restaurar);
  }

  Future<List<EntradaBitacora>> bitacora() => leerBitacora(repositorio);

  // ─────────────────────── Equipo secundario ───────────────────────

  Future<bool> esEquipoSecundario() async {
    final b = await almacen.leer(Deposito.meta, ClavesMeta.rolEquipo);
    return b != null && utf8.decode(b) == 'secundario';
  }

  /// Cuándo se restauró aquí un respaldo (el paquete lleva lo de después).
  Future<DateTime?> restauradoEn() => leerRestauradoEn(almacen);

  Future<void> cambiarEquipoSecundario(bool secundario) async {
    await almacen.aplicar([
      if (secundario)
        Cambio(
          Deposito.meta,
          ClavesMeta.rolEquipo,
          Uint8List.fromList(utf8.encode('secundario')),
        )
      else
        Cambio.borrar(Deposito.meta, ClavesMeta.rolEquipo),
    ]);
    documentos.serie = secundario ? 'S' : '';
  }

  /// Paquete con lo creado en este equipo desde que se restauró en él el
  /// respaldo del principal. Lanza [StateError] si nunca se restauró.
  Future<ArchivoRespaldo> exportarPaqueteSecundario() async {
    final desde = await restauradoEn();
    if (desde == null) {
      throw StateError(
        'Este equipo no se configuró restaurando un respaldo del equipo '
        'principal: no hay un paquete que exportar.',
      );
    }
    await repositorio.esperarEscrituras();
    final p = await exportarPaquete(
      boveda,
      repositorio,
      desde: desde,
      ahora: reloj.ahora(),
    );
    await registrarEnBitacora(
      repositorio,
      AccionBitacora.exportarPaquete,
      fecha: reloj.ahora(),
    );
    return p;
  }

  /// Verifica un paquete con la llave de este consultorio. Lanza
  /// [FormatException] con el motivo.
  Future<PaqueteVerificado> verificarPaqueteSecundario(Uint8List bytes) =>
      verificarPaquete(bytes, boveda);

  /// Combina el paquete (sin duplicar) y recarga lo descifrado.
  Future<ResultadoPaquete> combinarPaqueteSecundario(
    PaqueteVerificado p,
  ) async {
    final r = await combinarPaquete(
      p,
      repositorio,
      indice,
      ahora: reloj.ahora(),
    );
    await documentos.cargar();
    await seguimiento.cargar();
    await registrarEnBitacora(
      repositorio,
      AccionBitacora.combinarPaquete,
      fecha: reloj.ahora(),
      resumen: '${r.totalAgregados} agregados, ${r.yaEstaban} ya estaban',
    );
    return r;
  }
}
