import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../models/medico.dart';
import '../../utils/ids.dart';
import '../almacen/repositorio_ihce.dart';
import '../canonico/jcs.dart';
import '../cifrado/cifrador.dart';
import '../cliente/registro.dart';
import '../cliente/resultado.dart';
import '../cliente/transporte.dart';
import '../cliente/validador_vida_client.dart';
import '../config/config_ihce.dart';
import '../ensamblado/ensamblador.dart';
import '../ensamblado/pdf_soporte.dart';
import '../extraccion/entrada_atencion.dart';
import '../firma/firmador.dart';
import '../mappers/contexto.dart';
import '../modelo/documento_rda.dart';
import '../modelo/prestador_ihce.dart';
import '../reloj.dart';
import '../secretos/almacen_secretos.dart';
import '../terminologia/catalogo_terminologia.dart';
import '../validacion/esquema_fhir.dart';
import '../validacion/reglas_locales.dart';

/// Estado de interoperabilidad de una atención (API de solo lectura).
class EstadoRdaAtencion {
  const EstadoRdaAtencion({
    required this.documentoId,
    required this.estado,
    required this.version,
    this.vida,
    this.motivo,
  });

  final String documentoId;
  final EstadoDocumento estado;
  final int version;
  final String? vida;

  /// Motivo en lenguaje llano, sin `OperationOutcome` ni datos clínicos.
  final String? motivo;

  /// Un rechazo que el médico puede corregir y reintentar.
  bool get corregible => estado.corregible;
}

/// Orquestación asíncrona del RDA (Fase 6): outbox, worker, máquina de
/// estados, reintentos, idempotencia y bitácora. Nada de esto bloquea ni
/// altera el flujo clínico: ninguna excepción sale de [alCerrarAtencion] ni
/// de [procesarPendientes].
class ServicioIhce {
  ServicioIhce({
    required this.config,
    required this.repositorio,
    required this.cifrador,
    required this.credenciales,
    required this.cargarCatalogo,
    required this.cargarEsquema,
    required this.pdf,
    TransporteIhce? transporte,
    FirmadorDocumento? firmador,
    Reloj? reloj,
    RegistroIhce? registro,
    Random? azar,
    this.crearCliente,
    this.alCambiar,
  }) : _transporte = transporte ?? const TransporteNoDisponible(),
       firmador = firmador ?? firmadorPara(config.modoFirma),
       reloj = reloj ?? const RelojSistema(),
       registro = registro ?? RegistroIhce(),
       _azar = azar ?? Random();

  final ConfigIhce config;
  final RepositorioIhce repositorio;
  final CifradorDatos cifrador;
  final ServicioCredenciales credenciales;
  final Future<CatalogoTerminologia> Function() cargarCatalogo;
  final Future<ValidadorEsquemaFhir> Function() cargarEsquema;
  final GeneradorPdfSoporte pdf;
  final FirmadorDocumento firmador;
  final Reloj reloj;
  final RegistroIhce registro;
  final Random _azar;

  /// Se llama tras cada cambio de estado (la interfaz relee el estado).
  final void Function()? alCambiar;

  /// Fábrica del cliente (las pruebas inyectan uno con transporte simulado).
  final ValidadorVidaClient Function(TransporteIhce t)? crearCliente;

  TransporteIhce _transporte;
  ValidadorVidaClient? _cliente;
  Future<void>? _barrido;
  final _enProceso = <String>{};
  int _fallosSeguidos = 0;
  DateTime? _circuitoAbiertoHasta;

  bool get habilitado => config.habilitado;

  TransporteIhce get transporte => _transporte;

  /// Registra un adaptador de transporte (p. ej. un relevo de servidor):
  /// los documentos en `SIN_TRANSPORTE` se envían sin reconstruirse.
  Future<void> registrarTransporte(TransporteIhce t) async {
    _transporte = t;
    _cliente = null;
    await procesarPendientes();
  }

  ValidadorVidaClient _clienteActual() => _cliente ??=
      crearCliente?.call(_transporte) ??
      ValidadorVidaClient(
        config: config,
        credenciales: credenciales,
        transporte: _transporte,
        reloj: reloj,
        registro: registro,
      );

  // ───────────────────────── Outbox ─────────────────────────

  /// Enganche del cierre de la atención (capa de estado). Con el módulo
  /// deshabilitado no hace nada. Si la inserción falla, la atención ya está
  /// guardada: el error queda registrado y [reconciliar] crea el documento.
  Future<void> alCerrarAtencion({
    required Map<String, Object?> datos,
    required int revision,
    required Medico medico,
    required PrestadorIhce prestador,
    String actor = 'sistema',
  }) async {
    if (!habilitado) return;
    try {
      final entrada = EntradaAtencion.capturar(
        datos: datos,
        revision: revision,
        medico: medico,
        prestador: prestador,
      );
      final tipo = _tipoPara(entrada);
      if (tipo == null) {
        registro.info('cierre_sin_rda', {'revision': revision});
        return;
      }
      final clave = '${entrada.atencionId}:${tipo.name}:$revision';
      final cifrada = await cifrador.cifrarTexto(entrada.aJson());
      // Primero el cierre (para la reconciliación), luego la outbox.
      await repositorio.registrarCierre(clave, cifrada);
      await _insertar(entrada, tipo, cifrada, version: 1, actor: actor);
      await repositorio.borrarCierre(clave);
    } on Object catch (e) {
      registro.error('outbox_insercion_fallida', {
        'error': e.runtimeType.toString(),
      });
      return;
    }
    unawaited(procesarPendientes());
  }

  /// Revisión 1 = cierre de la historia inicial (consulta externa). Las
  /// evoluciones no llevan diagnóstico codificado: sin RDA (P1).
  TipoRda? _tipoPara(EntradaAtencion e) {
    if (e.revision != 1) return null;
    final atencion = (e.datos['atencion'] as Map?) ?? const {};
    return atencion['tipoConsulta'] == 'urgencia'
        ? TipoRda.urgencias
        : TipoRda.consulta;
  }

  String _tenant(PrestadorIhce p) => p.codigoHabilitacion.trim().isEmpty
      ? 'local'
      : p.codigoHabilitacion.trim();

  Future<DocumentoRda> _insertar(
    EntradaAtencion entrada,
    TipoRda tipo,
    String entradaCifrada, {
    required int version,
    required String actor,
  }) async {
    final ahora = reloj.ahora();
    final d = DocumentoRda(
      id: nuevoUuid(),
      tenantId: _tenant(PrestadorIhce.desdeMapa(entrada.prestador)),
      atencionId: entrada.atencionId,
      tipoRda: tipo,
      versionDoc: version,
      estado: EstadoDocumento.pendiente,
      creadoEn: ahora,
      actualizadoEn: ahora,
    );
    await repositorio.guardarEntrada(d.id, entradaCifrada);
    await repositorio.insertarDocumento(d);
    alCambiar?.call();
    registro.info('outbox_pendiente', {'documento': d.id, 'actor': actor});
    return d;
  }

  /// Crea los documentos de los cierres que quedaron sin outbox.
  Future<int> reconciliar() async {
    if (!habilitado) return 0;
    var n = 0;
    for (final e in (await repositorio.cierres()).entries) {
      try {
        final entrada = EntradaAtencion.desdeJson(
          await cifrador.descifrarTexto(e.value),
        );
        final tipo = _tipoPara(entrada);
        final existe =
            tipo == null ||
            repositorio
                .documentosDeAtencion(entrada.atencionId)
                .any((d) => d.tipoRda == tipo);
        if (!existe) {
          await _insertar(
            entrada,
            tipo,
            e.value,
            version: 1,
            actor: 'reconciliacion',
          );
          n++;
        }
        await repositorio.borrarCierre(e.key);
      } on Object catch (x) {
        registro.error('reconciliacion_fallida', {
          'error': x.runtimeType.toString(),
        });
      }
    }
    if (n > 0) registro.info('reconciliacion', {'creados': n});
    return n;
  }

  // ───────────────────────── Worker ─────────────────────────

  static const _procesables = {
    EstadoDocumento.pendiente,
    EstadoDocumento.construido,
    EstadoDocumento.validado,
    EstadoDocumento.firmado,
    EstadoDocumento.sinTransporte,
    EstadoDocumento.reintentoProgramado,
    // Un ENVIANDO huérfano (la app se cerró a mitad) se reenvía: los bytes
    // son los mismos y un 409 se concilia.
    EstadoDocumento.enviando,
  };

  /// Barrido del worker: al cerrar una atención, al iniciar la app y al
  /// recuperar la conectividad. Barridos concurrentes se unen en uno.
  Future<void> procesarPendientes() {
    if (!habilitado) return Future.value();
    return _barrido ??= _barrer().whenComplete(() => _barrido = null);
  }

  Future<void> _barrer() async {
    try {
      await repositorio.abrir();
      await reconciliar();
      final listos = repositorio.enEstados(
        _procesables,
        listosHasta: reloj.ahora(),
      );
      for (final d in listos) {
        await procesarDocumento(d.id);
      }
      await repositorio.depurarBitacora(
        reloj.ahora().subtract(config.retencionBitacora),
      );
    } on Object catch (e) {
      registro.error('worker_fallo', {'error': e.runtimeType.toString()});
    }
  }

  /// Lleva un documento por el pipeline hasta un estado de espera o final.
  /// Captura de último nivel: cualquier excepción no prevista deja el
  /// documento en `ERROR_INTERNO` y el worker sigue con el siguiente.
  Future<void> procesarDocumento(String id) async {
    if (!_enProceso.add(id)) return; // una sola transmisión viva
    try {
      var d = repositorio.documento(id);
      if (d == null) return;
      if (d.estado == EstadoDocumento.pendiente) d = await _construir(d);
      if (d.estado == EstadoDocumento.construido) d = await _validar(d);
      if (d.estado == EstadoDocumento.validado) d = await _firmar(d);
      if (const {
        EstadoDocumento.firmado,
        EstadoDocumento.sinTransporte,
        EstadoDocumento.reintentoProgramado,
        EstadoDocumento.enviando,
      }.contains(d.estado)) {
        await _enviar(d);
      }
    } on Object catch (e, traza) {
      registro.error('error_interno', {
        'documento': id,
        'error': e.runtimeType.toString(),
        'traza': registro.redactor.cuerpo('$traza', maximo: 600),
      });
      final d = repositorio.documento(id);
      if (d != null && !d.estado.terminal) {
        await _cambiar(
          d,
          EstadoDocumento.errorInterno,
          motivo: 'Error interno al procesar el documento',
        );
      }
    } finally {
      _enProceso.remove(id);
    }
  }

  Future<DocumentoRda> _cambiar(
    DocumentoRda d,
    EstadoDocumento a, {
    Object? motivo = _igual,
    Object? categoria = _igual,
    List<IhceIssue>? issues,
    String? bundleSha256,
    String? bundleCifrado,
    String? bundleIdentifier,
    String? vida,
    String? idCompositionIhce,
    List<IhceIssue>? advertencias,
    int? intentos,
    Object? proximoIntentoEn = _igual,
    int? ultimoHttpStatus,
    DateTime? aceptadoEn,
    String? shaUltimoEnvio,
  }) async {
    if (a != d.estado && !d.estado.puedePasarA(a)) {
      throw EstadoIhceInvalido('Transición ${d.estado.name} → ${a.name}');
    }
    final n = d.copyWith(
      estado: a,
      motivo: identical(motivo, _igual) ? d.motivo : motivo,
      categoria: identical(categoria, _igual) ? d.categoria : categoria,
      issues: issues,
      bundleSha256: bundleSha256,
      bundleCifrado: bundleCifrado,
      bundleIdentifier: bundleIdentifier,
      vida: vida,
      idCompositionIhce: idCompositionIhce,
      advertencias: advertencias,
      intentos: intentos,
      proximoIntentoEn: identical(proximoIntentoEn, _igual)
          ? d.proximoIntentoEn
          : proximoIntentoEn,
      ultimoHttpStatus: ultimoHttpStatus,
      actualizadoEn: reloj.ahora(),
      aceptadoEn: aceptadoEn,
      shaUltimoEnvio: shaUltimoEnvio,
    );
    await repositorio.actualizarDocumento(n);
    alCambiar?.call();
    return n;
  }

  Future<DocumentoRda> _construir(DocumentoRda d) async {
    final cifrada = await repositorio.entrada(d.id);
    if (cifrada == null) {
      return _cambiar(
        d,
        EstadoDocumento.invalidoLocal,
        motivo: 'Sin datos de la atención',
      );
    }
    final entrada = EntradaAtencion.desdeJson(
      await cifrador.descifrarTexto(cifrada),
    );
    final catalogo = await cargarCatalogo();
    final ResultadoEnsamblado r;
    try {
      final bytesPdf = await pdf.generar(entrada.datos, entrada.revision);
      final atencion = const ExtractorAtencion().extraer(
        entrada,
        pdf: bytesPdf,
      );
      r = estrategiaPara(d.tipoRda, config, catalogo).ensamblar(
        atencion,
        IdentidadDocumento(
          tenantId: d.tenantId,
          atencionId: d.atencionId,
          tipo: d.tipoRda,
          version: d.versionDoc,
        ),
      );
    } on RdaNoSoportado catch (e) {
      return _cambiar(
        d,
        EstadoDocumento.invalidoLocal,
        motivo: 'Este tipo de RDA aún no se puede generar: ${e.brecha}',
        categoria: 'NO_SOPORTADO',
      );
    }
    final advertencias = [
      for (final a in r.advertencias)
        IhceIssue(
          severity: 'warning',
          code: 'informational',
          diagnostics: a.mensaje,
          expression: [a.elemento],
        ),
    ];
    if (!r.valido) {
      final faltas = [
        ...r.faltantes,
        for (final h in r.identidad.hallazgos.where(
          (h) => h.nivel.name == 'bloqueo',
        ))
          FaltaDato('Patient.${h.campo}', h.mensaje, categoria: 'IDENTIDAD'),
      ];
      registro.alerta('invalido_local', {
        'documento': d.id,
        'faltantes': faltas.length,
      });
      return _cambiar(
        d,
        EstadoDocumento.invalidoLocal,
        motivo: _motivoFaltantes(faltas.map((f) => f.mensaje)),
        categoria: faltas.any((f) => f.categoria == 'SEMANTICO')
            ? 'SEMANTICO'
            : 'DATO',
        issues: [
          for (final f in faltas)
            IhceIssue(
              severity: 'error',
              code: f.categoria == 'SEMANTICO' ? 'code-invalid' : 'required',
              diagnostics: f.mensaje,
              expression: [f.elemento],
            ),
        ],
        advertencias: advertencias,
      );
    }
    final bytes = jcsBytes(r.bundle);
    final (nodos, aristas) = r.grafo.aRegistros(d.id);
    await repositorio.guardarGrafo(
      d.id,
      nodos,
      aristas,
      externos: r.grafo.externos,
    );
    final identificador = (r.bundle['identifier'] as Map?)?['value'] as String?;
    return _cambiar(
      d,
      EstadoDocumento.construido,
      bundleSha256: sha256Hex(bytes),
      bundleCifrado: await cifrador.cifrar(bytes),
      bundleIdentifier: identificador,
      advertencias: advertencias,
      motivo: null,
      categoria: null,
      issues: const [],
    );
  }

  String _motivoFaltantes(Iterable<String> mensajes) {
    final m = mensajes.toSet().toList();
    final primeros = m.take(3).join('; ');
    return m.length > 3 ? '$primeros (y ${m.length - 3} más)' : primeros;
  }

  Future<Uint8List> _bytes(DocumentoRda d) async =>
      cifrador.descifrar(d.bundleCifrado!);

  Future<DocumentoRda> _validar(DocumentoRda d) async {
    final bundle = (jsonDecode(utf8.decode(await _bytes(d))) as Map)
        .cast<String, Object?>();
    final issues = [
      ...validarReglasLocales(
        bundle,
        ContextoReglas(
          config: config,
          tipo: d.tipoRda,
          ahora: reloj.ahora(),
          externos: repositorio.externos(d.id),
        ),
      ),
      ...(await cargarEsquema()).validarBundle(bundle),
    ];
    if (issues.isNotEmpty) {
      registro.alerta('validacion_local_fallida', {
        'documento': d.id,
        'hallazgos': issues.length,
      });
      return _cambiar(
        d,
        EstadoDocumento.invalidoLocal,
        motivo: 'El documento no pasó la validación previa al envío',
        categoria: 'SINTACTICO',
        issues: issues,
      );
    }
    return _cambiar(d, EstadoDocumento.validado);
  }

  Future<DocumentoRda> _firmar(DocumentoRda d) async {
    final canonicos = await _bytes(d);
    final firmados = await firmador.firmar(canonicos);
    if (identical(firmados, canonicos)) {
      return _cambiar(d, EstadoDocumento.firmado);
    }
    return _cambiar(
      d,
      EstadoDocumento.firmado,
      bundleSha256: sha256Hex(firmados),
      bundleCifrado: await cifrador.cifrar(firmados),
    );
  }

  Future<void> _enviar(DocumentoRda d) async {
    if (!_transporte.disponible) {
      if (d.estado != EstadoDocumento.sinTransporte) {
        await _cambiar(d, EstadoDocumento.sinTransporte);
        registro.info('sin_transporte', {'documento': d.id});
      }
      return;
    }
    if (!config.transporteConfigurado || !await credenciales.configuradas()) {
      // Módulo inactivo sin errores: el documento espera en la cola.
      registro.info('sin_credenciales', {'documento': d.id});
      return;
    }
    final abierto = _circuitoAbiertoHasta;
    if (abierto != null && reloj.ahora().isBefore(abierto)) return;

    // Idempotencia: los mismos bytes ya aceptados en otro documento.
    final iguales = repositorio
        .porSha(d.tenantId, d.bundleSha256!)
        .where((x) => x.id != d.id && x.estado == EstadoDocumento.aceptado);
    if (iguales.isNotEmpty) {
      await _cambiar(d, EstadoDocumento.enviando);
      await _cambiar(
        repositorio.documento(d.id)!,
        EstadoDocumento.duplicado,
        motivo: 'Este mismo documento ya fue aceptado',
        categoria: 'DUPLICADO',
      );
      return;
    }
    if (repositorio
        .documentosDeAtencion(d.atencionId)
        .any(
          (x) =>
              x.id != d.id &&
              x.tipoRda == d.tipoRda &&
              x.estado == EstadoDocumento.aceptado,
        )) {
      // Corrección tras la aceptación: va por nota aclaratoria (P1).
      await _cambiar(d, EstadoDocumento.enviando);
      await _cambiar(
        repositorio.documento(d.id)!,
        EstadoDocumento.duplicado,
        motivo:
            'La atención ya tiene un RDA aceptado; las correcciones van por nota aclaratoria',
        categoria: 'DUPLICADO',
      );
      return;
    }

    final n = d.intentos + 1;
    var doc = await _cambiar(d, EstadoDocumento.enviando, intentos: n);
    final bytes = await _bytes(doc);
    final bundle = (jsonDecode(utf8.decode(bytes)) as Map)
        .cast<String, Object?>();
    final tipos = [
      for (final e in (bundle['entry'] as List?) ?? const [])
        ((e as Map)['resource'] as Map)['resourceType'] as String,
    ];
    final correlacion = nuevoUuid();
    final inicio = reloj.ahora();
    final cronometro = Stopwatch()..start();
    final resultado = await _clienteActual().enviarRda(
      doc.tipoRda,
      bytes,
      ContextoEnvio(
        idCorrelacion: correlacion,
        documentoId: doc.id,
        bundleIdentifierEnviado: doc.bundleIdentifier,
        tiposPorEntrada: tipos,
      ),
    );
    cronometro.stop();
    doc = await _aplicarResultado(doc, resultado, bundle);
    await repositorio.registrarIntento(
      IntentoTransmision(
        id: nuevoUuid(),
        documentoId: doc.id,
        nIntento: repositorio.siguienteIntento(doc.id),
        operacion: '\$${doc.tipoRda.operacion}',
        iniciadoEn: inicio,
        duracionMs: cronometro.elapsedMilliseconds,
        httpStatus: _http(resultado),
        categoria: doc.categoria,
        idCorrelacion: correlacion,
        idSolicitudServidor: switch (resultado) {
          Aceptado(:final idSolicitud) => idSolicitud,
          AceptadoSinVida(:final idSolicitud) => idSolicitud,
          _ => null,
        },
        issues: doc.estado == EstadoDocumento.aceptado
            ? doc.advertencias
            : doc.issues,
        actor: 'sistema',
        estado: doc.estado.name,
      ),
    );
    registro
      ..contar('estado_${doc.estado.name}')
      ..contar('tenant_${doc.tenantId}_${doc.estado.name}')
      ..info('intento', {
        'documento': doc.id,
        'correlacion': correlacion,
        'estado': doc.estado.name,
        'ms': cronometro.elapsedMilliseconds,
      });
    _vigilarPicos(doc.estado, _http(resultado));
  }

  int? _http(ResultadoEnvio r) => switch (r) {
    Aceptado(:final httpStatus) => httpStatus,
    AceptadoSinVida(:final httpStatus) => httpStatus,
    Rechazado(:final httpStatus) => httpStatus,
    Duplicado(:final httpStatus) => httpStatus,
    ErrorAuth(:final httpStatus) => httpStatus,
    FalloTransitorio(:final httpStatus) => httpStatus,
  };

  Future<DocumentoRda> _aplicarResultado(
    DocumentoRda d,
    ResultadoEnvio r,
    Map<String, Object?> bundle,
  ) async {
    if (r is! FalloTransitorio) _fallosSeguidos = 0;
    switch (r) {
      case Aceptado():
        try {
          return await _cambiar(
            d,
            EstadoDocumento.aceptado,
            vida: r.vida,
            idCompositionIhce: r.idComposition,
            advertencias: [...d.advertencias, ...r.advertencias],
            ultimoHttpStatus: r.httpStatus,
            aceptadoEn: reloj.ahora(),
            shaUltimoEnvio: d.bundleSha256,
            proximoIntentoEn: null,
            motivo: null,
            categoria: null,
          );
        } on RestriccionUnica catch (e) {
          registro.error('vida_repetido', {
            'documento': d.id,
            'restriccion': e.restriccion,
          });
          rethrow;
        }
      case AceptadoSinVida():
        registro.alerta('aceptado_sin_vida', {
          'documento': d.id,
          'motivo': r.motivo,
        });
        return _cambiar(
          d,
          EstadoDocumento.aceptadoSinVida,
          idCompositionIhce: r.idComposition,
          advertencias: [...d.advertencias, ...r.advertencias],
          ultimoHttpStatus: r.httpStatus,
          aceptadoEn: reloj.ahora(),
          shaUltimoEnvio: d.bundleSha256,
          proximoIntentoEn: null,
          motivo: r.motivo,
        );
      case Rechazado():
        final issues = [
          for (final i in r.issues) i.conNodo(_nodoDe(d.id, i, bundle)),
        ];
        if (r.categoria == CategoriaError.semantico) {
          final catalogo = await cargarCatalogo();
          catalogo.marcadosParaSincronizar.addAll(_sistemasDe(issues, bundle));
        }
        registro.alerta('rechazado', {
          'documento': d.id,
          'categoria': r.categoria.etiqueta,
          'http': r.httpStatus,
        });
        return _cambiar(
          d,
          EstadoDocumento.rechazado,
          issues: issues,
          categoria: r.categoria.etiqueta,
          motivo: _motivoRechazo(r.categoria),
          ultimoHttpStatus: r.httpStatus,
          shaUltimoEnvio: d.bundleSha256,
          proximoIntentoEn: null,
        );
      case Duplicado():
        registro.alerta('duplicado', {'documento': d.id});
        return _cambiar(
          d,
          EstadoDocumento.duplicado,
          issues: r.issues,
          categoria: CategoriaError.duplicado.etiqueta,
          motivo:
              'La plataforma ya tenía esta atención (pendiente de conciliación)',
          ultimoHttpStatus: r.httpStatus,
          shaUltimoEnvio: d.bundleSha256,
          proximoIntentoEn: null,
        );
      case ErrorAuth():
        registro.alerta('error_auth', {
          'documento': d.id,
          'http': r.httpStatus,
        });
        return _cambiar(
          d,
          EstadoDocumento.errorAuth,
          categoria: CategoriaError.auth.etiqueta,
          motivo: r.httpStatus == 403
              ? 'MinSalud negó el permiso: revisa la configuración de las credenciales'
              : 'MinSalud rechazó las credenciales: revisa el ClientID y el ClientSecret',
          ultimoHttpStatus: r.httpStatus,
          proximoIntentoEn: null,
        );
      case FalloTransitorio():
        _fallosSeguidos++;
        if (_fallosSeguidos >= config.cortacircuitosUmbral) {
          _circuitoAbiertoHasta = reloj.ahora().add(
            config.cortacircuitosEspera,
          );
          registro.alerta('cortacircuitos_abierto', {
            'tenant': d.tenantId,
            'ambiente': config.ambiente.name,
          });
        }
        if (d.intentos >= config.maxIntentos) {
          registro.alerta('agotado', {
            'documento': d.id,
            'intentos': d.intentos,
          });
          return _cambiar(
            d,
            EstadoDocumento.agotado,
            categoria: CategoriaError.transitorio.etiqueta,
            motivo: 'No se pudo enviar tras ${d.intentos} intentos',
            ultimoHttpStatus: r.httpStatus,
            issues: r.issues,
            proximoIntentoEn: null,
          );
        }
        return _cambiar(
          d,
          EstadoDocumento.reintentoProgramado,
          categoria: CategoriaError.transitorio.etiqueta,
          motivo: null,
          ultimoHttpStatus: r.httpStatus,
          issues: r.issues,
          proximoIntentoEn: reloj.ahora().add(
            esperaReintento(d.intentos, r.reintentarEn),
          ),
        );
    }
  }

  /// `min(TOPE, BASE · 2^(n-1))` con jitter de hasta el 10 %; `Retry-After`
  /// prevalece.
  Duration esperaReintento(int intento, Duration? retryAfter) {
    if (retryAfter != null) return retryAfter;
    final base =
        config.backoffBase.inMilliseconds * pow(2, max(0, intento - 1));
    final tope = min(
      config.backoffTope.inMilliseconds.toDouble(),
      base.toDouble(),
    );
    final jitter = tope * 0.1 * _azar.nextDouble();
    return Duration(milliseconds: (tope + jitter).round());
  }

  final _ventanaErrores = <(DateTime, String)>[];

  /// Alertas por picos de 4xx, 409 y 5xx (10 en 10 minutos).
  void _vigilarPicos(EstadoDocumento e, int? http) {
    if (http == null) return;
    final clase = http == 409
        ? '409'
        : http >= 500
        ? '5xx'
        : http >= 400
        ? '4xx'
        : null;
    if (clase == null) return;
    final ahora = reloj.ahora();
    _ventanaErrores
      ..add((ahora, clase))
      ..removeWhere(
        (x) => ahora.difference(x.$1) > const Duration(minutes: 10),
      );
    final n = _ventanaErrores.where((x) => x.$2 == clase).length;
    if (n >= 10) registro.alerta('pico_errores', {'clase': clase, 'n': n});
  }

  /// `location`/`expression` → nodo local (y, por él, tabla y PK de origen).
  String? _nodoDe(
    String documentoId,
    IhceIssue i,
    Map<String, Object?> bundle,
  ) {
    final entradas = (bundle['entry'] as List?) ?? const [];
    for (final ruta in [...i.location, ...i.expression]) {
      final m = RegExp(r'Bundle\.entry\[(\d+)\]').firstMatch(ruta);
      if (m != null) {
        final k = int.parse(m.group(1)!);
        if (k >= entradas.length) continue;
        final r = (entradas[k] as Map)['resource'] as Map;
        if (r['resourceType'] == 'Composition') {
          return repositorio
              .nodos(documentoId)
              .where((n) => n.tipoRecurso == 'Composition')
              .firstOrNull
              ?.idLocal;
        }
        return r['id'] as String?;
      }
      final tipo = RegExp(r'^([A-Z][A-Za-z]+)').firstMatch(ruta)?.group(1);
      final candidatos = repositorio
          .nodos(documentoId)
          .where((n) => n.tipoRecurso == tipo)
          .toList();
      if (candidatos.length == 1) return candidatos.first.idLocal;
    }
    return null;
  }

  /// Sistemas de los `Coding` señalados por un rechazo semántico.
  Set<String> _sistemasDe(List<IhceIssue> issues, Map<String, Object?> bundle) {
    final r = <String>{};
    for (final i in issues) {
      for (final ruta in i.location) {
        final m = RegExp(r'^Bundle\.(.+?)\.(code|display)$').firstMatch(ruta);
        if (m == null) continue;
        Object? actual = bundle;
        for (final paso in m.group(1)!.split('.')) {
          final p = RegExp(r'^(\w+)(?:\[(\d+)\])?$').firstMatch(paso);
          if (p == null || actual is! Map) {
            actual = null;
            break;
          }
          actual = actual[p.group(1)];
          if (p.group(2) != null && actual is List) {
            final k = int.parse(p.group(2)!);
            actual = k < actual.length ? actual[k] : null;
          }
        }
        if (actual is Map && actual['system'] is String) {
          r.add(actual['system'] as String);
        }
      }
    }
    return r;
  }

  String _motivoRechazo(CategoriaError c) => switch (c) {
    CategoriaError.sintactico => 'MinSalud rechazó el formato del documento',
    CategoriaError.semantico =>
      'MinSalud no reconoció un código o su nombre en el catálogo',
    CategoriaError.identidad =>
      'MinSalud no validó la identidad del paciente, del médico o del prestador',
    _ => 'MinSalud rechazó el documento',
  };

  // ───────────────────────── Lectura y reintento ─────────────────────────

  /// Estado del documento más reciente de la atención (o `null`).
  EstadoRdaAtencion? estadoDe(String atencionId) {
    final docs = repositorio.documentosDeAtencion(atencionId);
    if (docs.isEmpty) return null;
    final d = docs.reduce((a, b) => b.versionDoc >= a.versionDoc ? b : a);
    return EstadoRdaAtencion(
      documentoId: d.id,
      estado: d.estado,
      version: d.versionDoc,
      vida: d.vida,
      motivo: d.motivo,
    );
  }

  /// Tras guardar credenciales nuevas: los documentos en `ERROR_AUTH`
  /// vuelven a la cola con sus mismos bytes (sin reconstruirse) y se lanza
  /// un barrido. Devuelve cuántos se reactivaron.
  Future<int> reactivarErrorAuth() async {
    if (!habilitado) return 0;
    var n = 0;
    try {
      await repositorio.abrir();
      for (final d in repositorio.enEstados({EstadoDocumento.errorAuth})) {
        await _cambiar(
          d,
          EstadoDocumento.reintentoProgramado,
          motivo: null,
          categoria: null,
          proximoIntentoEn: reloj.ahora(),
        );
        n++;
      }
      if (n > 0) registro.info('reactivados_error_auth', {'documentos': n});
    } on Object catch (e) {
      registro.error('reactivacion_fallida', {
        'error': e.runtimeType.toString(),
      });
    }
    await procesarPendientes();
    return n;
  }

  /// `true` si algún documento quedó en `ERROR_AUTH`.
  bool get hayErrorAuth =>
      repositorio.enEstados({EstadoDocumento.errorAuth}).isNotEmpty;

  /// Reintento tras corregir (regla 10, c): nueva `version_doc` que recorre
  /// todo el pipeline con el médico y el prestador vigentes. Los datos
  /// clínicos sellados no cambian. Un documento aceptado no se reenvía.
  Future<String?> reintentar(
    String documentoId, {
    required Medico medico,
    required PrestadorIhce prestador,
  }) async {
    final d = repositorio.documento(documentoId);
    if (d == null || !d.estado.corregible) return null;
    final cifrada = await repositorio.entrada(d.id);
    if (cifrada == null) return null;
    final entrada = EntradaAtencion.desdeJson(
      await cifrador.descifrarTexto(cifrada),
    ).conConfiguracion(medico, prestador);
    final version =
        repositorio
            .documentosDeAtencion(d.atencionId)
            .where((x) => x.tipoRda == d.tipoRda)
            .map((x) => x.versionDoc)
            .fold(0, max) +
        1;
    final nuevo = await _insertar(
      entrada,
      d.tipoRda,
      await cifrador.cifrarTexto(entrada.aJson()),
      version: version,
      actor: 'usuario',
    );
    await procesarDocumento(nuevo.id);
    return nuevo.id;
  }

  /// Punto de extensión (P1): correcciones de un RDA aceptado.
  Future<ResultadoEnvio> enviarNotaAclaratoria(String documentoId) async =>
      throw const EstadoIhceInvalido(
        'La nota aclaratoria (ObservationClarificationNoteRDA) es P1',
      );
}

const _igual = Object();
