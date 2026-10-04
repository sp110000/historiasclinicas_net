import 'dart:async';
import 'dart:convert';

import '../modelo/documento_rda.dart';
import 'almacen_kv.dart';

/// Violación de una restricción `UNIQUE` del esquema lógico.
class RestriccionUnica implements Exception {
  const RestriccionUnica(this.restriccion);

  final String restriccion;

  @override
  String toString() => 'RestriccionUnica($restriccion)';
}

/// Una migración del almacén IHCE. Todas son aditivas y reversibles: el
/// módulo usa su propia base (`historiasclinicas_ihce`) y prefijo de
/// claves, y no toca el almacenamiento existente de la app.
class Migracion {
  const Migracion(this.version, this.descripcion, this.subir, this.bajar);

  final int version;
  final String descripcion;
  final Future<void> Function(AlmacenKv kv) subir;
  final Future<void> Function(AlmacenKv kv) bajar;
}

abstract final class _Prefijos {
  static const esquema = 'ihce:esquema';
  static const documento = 'ihce:doc:';
  static const grafo = 'ihce:grafo:';
  static const intento = 'ihce:intento:';
  static const entrada = 'ihce:entrada:';
  static const cierre = 'ihce:cierre:';
  static const catalogo = 'ihce:catalogo:';
  static const todos = 'ihce:';
}

/// Migraciones en orden. La 1 crea las colecciones (con IndexedDB basta con
/// registrar la versión: las «tablas» son prefijos de clave) y su bajada
/// las elimina.
final migracionesIhce = <Migracion>[
  Migracion(
    1,
    'colecciones ihce_rda_documento, ihce_rda_nodo, ihce_rda_arista, '
    'ihce_transmision_intento, entradas y cierres',
    (kv) async {},
    (kv) async {
      for (final k in await kv.claves(_Prefijos.todos)) {
        if (k != _Prefijos.esquema) await kv.borrar(k);
      }
    },
  ),
];

/// Repositorio del grafo clínico, la outbox y la bitácora sobre un
/// [AlmacenKv]. Mantiene en memoria los índices del esquema lógico:
///
/// * `UNIQUE (tenant_id, atencion_id, tipo_rda, version_doc)`
/// * `UNIQUE (vida) WHERE vida IS NOT NULL`
/// * a lo sumo un `ACEPTADO` por `(atencion_id, tipo_rda)`
/// * `INDEX (estado, proximo_intento_en)` — barrido del worker
/// * `INDEX (tenant_id, bundle_sha256)` — idempotencia
/// * nodos `UNIQUE (documento_id, id_local)` e
///   `INDEX (tipo_recurso, tabla_origen, pk_origen)`
/// * aristas `INDEX (documento_id, id_local_origen)` y `(…, id_local_destino)`
/// * intentos `INDEX (documento_id, n_intento)`, solo inserción.
class RepositorioIhce {
  RepositorioIhce(this._kv, {List<Migracion>? migraciones})
    : _migraciones = migraciones ?? migracionesIhce;

  final AlmacenKv _kv;
  final List<Migracion> _migraciones;
  Future<void>? _apertura;

  final _documentos = <String, DocumentoRda>{};
  final _porClaveNatural = <String, String>{};
  final _porVida = <String, String>{};
  final _porSha = <String, Set<String>>{};
  final _porEstado = <EstadoDocumento, Set<String>>{};
  final _nodos = <String, List<NodoRda>>{};
  final _nodosPorOrigen = <String, Set<(String, String)>>{};
  final _aristas = <String, List<AristaRda>>{};
  final _externos = <String, Set<String>>{};
  final _intentos = <String, List<IntentoTransmision>>{};

  /// Versión del esquema aplicada.
  int version = 0;

  Future<void> abrir() => _apertura ??= _abrir();

  Future<void> _abrir() async {
    version = int.tryParse(await _kv.leer(_Prefijos.esquema) ?? '') ?? 0;
    for (final m in _migraciones.where((m) => m.version > version)) {
      await m.subir(_kv);
      version = m.version;
      await _kv.escribir(_Prefijos.esquema, '$version');
    }
    for (final k in await _kv.claves(_Prefijos.documento)) {
      final d = DocumentoRda.desdeMapa(
        (jsonDecode((await _kv.leer(k))!) as Map).cast(),
      );
      _indexar(d);
    }
    for (final k in await _kv.claves(_Prefijos.grafo)) {
      final m = (jsonDecode((await _kv.leer(k))!) as Map)
          .cast<String, Object?>();
      final id = k.substring(_Prefijos.grafo.length);
      _nodos[id] = [
        for (final n in m['nodos']! as List)
          NodoRda.desdeMapa((n as Map).cast()),
      ];
      _aristas[id] = [
        for (final a in m['aristas']! as List)
          AristaRda.desdeMapa((a as Map).cast()),
      ];
      _externos[id] = {
        for (final x in (m['externos'] as List?) ?? const []) x as String,
      };
      _indexarNodos(id);
    }
    for (final k in await _kv.claves(_Prefijos.intento)) {
      final i = IntentoTransmision.desdeMapa(
        (jsonDecode((await _kv.leer(k))!) as Map).cast(),
      );
      (_intentos[i.documentoId] ??= []).add(i);
    }
    for (final l in _intentos.values) {
      l.sort((a, b) => a.nIntento.compareTo(b.nIntento));
    }
  }

  /// Revierte las migraciones posteriores a [destino] (por defecto, todas).
  Future<void> revertir({int destino = 0}) async {
    for (final m in _migraciones.reversed.where((m) => m.version > destino)) {
      await m.bajar(_kv);
      version = m.version - 1;
      await _kv.escribir(_Prefijos.esquema, '$version');
    }
    _documentos.clear();
    _porClaveNatural.clear();
    _porVida.clear();
    _porSha.clear();
    _porEstado.clear();
    _nodos.clear();
    _nodosPorOrigen.clear();
    _aristas.clear();
    _externos.clear();
    _intentos.clear();
    _apertura = null;
  }

  // ───────────────────────── Documentos ─────────────────────────

  static String _claveNatural(DocumentoRda d) =>
      '${d.tenantId}|${d.atencionId}|${d.tipoRda.name}|${d.versionDoc}';

  void _indexar(DocumentoRda d) {
    _documentos[d.id] = d;
    _porClaveNatural[_claveNatural(d)] = d.id;
    if (d.vida != null) _porVida[d.vida!] = d.id;
    if (d.bundleSha256 != null) {
      (_porSha['${d.tenantId}|${d.bundleSha256}'] ??= {}).add(d.id);
    }
    (_porEstado[d.estado] ??= {}).add(d.id);
  }

  void _desindexar(DocumentoRda d) {
    _porClaveNatural.remove(_claveNatural(d));
    if (d.vida != null) _porVida.remove(d.vida);
    if (d.bundleSha256 != null) {
      _porSha['${d.tenantId}|${d.bundleSha256}']?.remove(d.id);
    }
    _porEstado[d.estado]?.remove(d.id);
  }

  void _comprobarUnicos(DocumentoRda d) {
    final natural = _porClaveNatural[_claveNatural(d)];
    if (natural != null && natural != d.id) {
      throw const RestriccionUnica(
        '(tenant_id, atencion_id, tipo_rda, version_doc)',
      );
    }
    if (d.vida != null) {
      final otro = _porVida[d.vida!];
      if (otro != null && otro != d.id) throw const RestriccionUnica('(vida)');
    }
    if (d.estado == EstadoDocumento.aceptado) {
      final yaAceptado = _documentos.values.any(
        (x) =>
            x.id != d.id &&
            x.atencionId == d.atencionId &&
            x.tipoRda == d.tipoRda &&
            x.estado == EstadoDocumento.aceptado,
      );
      if (yaAceptado) {
        throw const RestriccionUnica('ACEPTADO por (atencion_id, tipo_rda)');
      }
    }
  }

  Future<void> insertarDocumento(DocumentoRda d) async {
    await abrir();
    if (_documentos.containsKey(d.id)) {
      throw const RestriccionUnica('(id)');
    }
    _comprobarUnicos(d);
    await _kv.escribir('${_Prefijos.documento}${d.id}', jsonEncode(d.aMapa()));
    _indexar(d);
  }

  Future<void> actualizarDocumento(DocumentoRda d) async {
    await abrir();
    final anterior = _documentos[d.id];
    if (anterior == null) throw StateError('Documento inexistente');
    _comprobarUnicos(d);
    await _kv.escribir('${_Prefijos.documento}${d.id}', jsonEncode(d.aMapa()));
    _desindexar(anterior);
    _indexar(d);
  }

  DocumentoRda? documento(String id) => _documentos[id];

  Iterable<DocumentoRda> get documentos => _documentos.values;

  List<DocumentoRda> documentosDeAtencion(String atencionId) =>
      [
        for (final d in _documentos.values)
          if (d.atencionId == atencionId) d,
      ]..sort((a, b) {
        final t = a.tipoRda.index.compareTo(b.tipoRda.index);
        return t != 0 ? t : a.versionDoc.compareTo(b.versionDoc);
      });

  /// Índice `(estado, proximo_intento_en)`.
  List<DocumentoRda> enEstados(
    Set<EstadoDocumento> estados, {
    DateTime? listosHasta,
  }) => [
    for (final e in estados)
      for (final id in _porEstado[e] ?? const <String>{})
        if (listosHasta == null ||
            _documentos[id]!.proximoIntentoEn == null ||
            !_documentos[id]!.proximoIntentoEn!.isAfter(listosHasta))
          _documentos[id]!,
  ]..sort((a, b) => a.creadoEn.compareTo(b.creadoEn));

  /// Índice `(tenant_id, bundle_sha256)`.
  List<DocumentoRda> porSha(String tenantId, String sha) => [
    for (final id in _porSha['$tenantId|$sha'] ?? const <String>{})
      _documentos[id]!,
  ];

  DocumentoRda? porVida(String vida) =>
      _porVida[vida] == null ? null : _documentos[_porVida[vida]];

  /// VIDA de la atención (raíz local), del documento ACEPTADO del tipo.
  String? vidaDeAtencion(String atencionId, {TipoRda tipo = TipoRda.consulta}) {
    for (final d in _documentos.values) {
      if (d.atencionId == atencionId &&
          d.tipoRda == tipo &&
          d.estado == EstadoDocumento.aceptado) {
        return d.vida;
      }
    }
    return null;
  }

  // ───────────────────────── Grafo ─────────────────────────

  void _indexarNodos(String documentoId) {
    for (final n in _nodos[documentoId] ?? const <NodoRda>[]) {
      (_nodosPorOrigen['${n.tipoRecurso}|${n.tablaOrigen}|${n.pkOrigen}'] ??=
              {})
          .add((documentoId, n.idLocal));
    }
  }

  Future<void> guardarGrafo(
    String documentoId,
    List<NodoRda> nodos,
    List<AristaRda> aristas, {
    Set<String> externos = const {},
  }) async {
    await abrir();
    final ids = <String>{};
    for (final n in nodos) {
      if (!ids.add(n.idLocal)) {
        throw const RestriccionUnica('(documento_id, id_local)');
      }
    }
    await _kv.escribir(
      '${_Prefijos.grafo}$documentoId',
      jsonEncode({
        'nodos': [for (final n in nodos) n.aMapa()],
        'aristas': [for (final a in aristas) a.aMapa()],
        'externos': externos.toList()..sort(),
      }),
    );
    _externos[documentoId] = Set.unmodifiable(externos);
    for (final s in _nodosPorOrigen.values) {
      s.removeWhere((x) => x.$1 == documentoId);
    }
    _nodos[documentoId] = List.unmodifiable(nodos);
    _aristas[documentoId] = List.unmodifiable(aristas);
    _indexarNodos(documentoId);
  }

  List<NodoRda> nodos(String documentoId) => _nodos[documentoId] ?? const [];

  /// Referencias externas permitidas del documento (IPS, MinSalud, …).
  Set<String> externos(String documentoId) =>
      _externos[documentoId] ?? const {};

  List<AristaRda> aristas(String documentoId) =>
      _aristas[documentoId] ?? const [];

  NodoRda? nodo(String documentoId, String idLocal) {
    for (final n in nodos(documentoId)) {
      if (n.idLocal == idLocal) return n;
    }
    return null;
  }

  /// Índice `(tipo_recurso, tabla_origen, pk_origen)`.
  List<(String documentoId, String idLocal)> nodosPorOrigen(
    String tipoRecurso,
    String tablaOrigen,
    String pkOrigen,
  ) => [...?_nodosPorOrigen['$tipoRecurso|$tablaOrigen|$pkOrigen']];

  List<AristaRda> aristasDesde(String documentoId, String idLocal) => [
    for (final a in aristas(documentoId))
      if (a.idLocalOrigen == idLocal) a,
  ];

  List<AristaRda> aristasHacia(String documentoId, String idLocal) => [
    for (final a in aristas(documentoId))
      if (a.idLocalDestino == idLocal) a,
  ];

  // ───────────────────────── Bitácora ─────────────────────────

  /// Solo inserción: un intento no se modifica ni se borra (salvo por la
  /// retención configurada, ver [depurarBitacora]).
  Future<void> registrarIntento(IntentoTransmision i) async {
    await abrir();
    final lista = _intentos[i.documentoId] ??= [];
    if (lista.any((x) => x.nIntento == i.nIntento)) {
      throw const RestriccionUnica('(documento_id, n_intento)');
    }
    await _kv.escribir(
      '${_Prefijos.intento}${i.documentoId}:${i.nIntento.toString().padLeft(4, '0')}',
      jsonEncode(i.aMapa()),
    );
    lista.add(i);
  }

  List<IntentoTransmision> intentos(String documentoId) =>
      List.unmodifiable(_intentos[documentoId] ?? const []);

  int siguienteIntento(String documentoId) =>
      (_intentos[documentoId]?.length ?? 0) + 1;

  /// Elimina los intentos anteriores a [limite] (retención, §3.7).
  Future<int> depurarBitacora(DateTime limite) async {
    var n = 0;
    for (final e in _intentos.entries) {
      final viejos = e.value
          .where((i) => i.iniciadoEn.isBefore(limite))
          .toList();
      for (final i in viejos) {
        await _kv.borrar(
          '${_Prefijos.intento}${i.documentoId}:${i.nIntento.toString().padLeft(4, '0')}',
        );
        e.value.remove(i);
        n++;
      }
    }
    return n;
  }

  // ───────────────────────── Entradas y cierres ─────────────────────────

  /// Instantánea cifrada de la atención (datos sellados, médico y prestador)
  /// de la que el worker construye el documento.
  Future<void> guardarEntrada(String documentoId, String cifrada) async {
    await abrir();
    await _kv.escribir('${_Prefijos.entrada}$documentoId', cifrada);
  }

  Future<String?> entrada(String documentoId) =>
      _kv.leer('${_Prefijos.entrada}$documentoId');

  /// Registro del cierre de una atención, escrito antes de la outbox: el
  /// barrido de reconciliación crea los documentos que falten.
  Future<void> registrarCierre(String clave, String cifrado) async {
    await abrir();
    await _kv.escribir('${_Prefijos.cierre}$clave', cifrado);
  }

  Future<Map<String, String>> cierres() async {
    final r = <String, String>{};
    for (final k in await _kv.claves(_Prefijos.cierre)) {
      r[k.substring(_Prefijos.cierre.length)] = (await _kv.leer(k))!;
    }
    return r;
  }

  Future<void> borrarCierre(String clave) =>
      _kv.borrar('${_Prefijos.cierre}$clave');

  // ───────────────────────── Catálogos importados ─────────────────────────

  Future<void> guardarCatalogo(String system, String json) async {
    await abrir();
    await _kv.escribir('${_Prefijos.catalogo}$system', json);
  }

  Future<Map<String, String>> catalogos() async {
    final r = <String, String>{};
    for (final k in await _kv.claves(_Prefijos.catalogo)) {
      r[k.substring(_Prefijos.catalogo.length)] = (await _kv.leer(k))!;
    }
    return r;
  }
}
