import 'dart:convert';

import '../almacen/repositorio_ihce.dart';
import '../cliente/validador_vida_client.dart';
import '../reloj.dart';
import '../../utils/ids.dart';
import 'catalogo_terminologia.dart';

/// Importador desde archivo (P0) para los CodeSystems que la guía trae como
/// `fragment` (CUPS, CUMS, IUM…): las tablas de referencia de SISPRO que
/// cita el Anexo Técnico, exportadas como texto `código;nombre` (también
/// tabulador, coma o `|`). El CIE-10 ya tiene su importador en la app
/// (Excel de SISPRO, `lib/core/cie10/catalogo_cie10.dart`).
class ImportadorCatalogo {
  const ImportadorCatalogo(this._repositorio);

  final RepositorioIhce _repositorio;

  static final _separador = RegExp(r'[;\t|,]');

  /// Lee el texto, lo guarda en el almacén y lo registra en [catalogo].
  /// Devuelve la cantidad de conceptos. Lanza [FormatException] si no hay
  /// ninguno.
  Future<int> importar(
    String system,
    String texto,
    CatalogoTerminologia catalogo,
  ) async {
    final conceptos = leerTabla(texto);
    if (conceptos.isEmpty) {
      throw const FormatException('El archivo no trae códigos');
    }
    await _repositorio.guardarCatalogo(system, jsonEncode(conceptos));
    catalogo.registrar(system, conceptos);
    return conceptos.length;
  }

  /// `código<sep>nombre` por línea; omite encabezados y líneas vacías.
  static Map<String, String> leerTabla(String texto) {
    final r = <String, String>{};
    for (final linea in const LineSplitter().convert(texto)) {
      final t = linea.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final i = t.indexOf(_separador);
      if (i <= 0) continue;
      final codigo = t.substring(0, i).trim().replaceAll('"', '');
      final nombre = t.substring(i + 1).trim().replaceAll('"', '');
      if (codigo.isEmpty || nombre.isEmpty) continue;
      // Encabezados («Código;Nombre») y filas sin forma de código.
      if (!RegExp(r'^[A-Za-z0-9.\-]+$').hasMatch(codigo)) {
        continue;
      }
      r[codigo] = nombre;
    }
    return r;
  }

  /// Registra en [catalogo] los catálogos importados antes.
  Future<void> cargarGuardados(CatalogoTerminologia catalogo) async {
    for (final e in (await _repositorio.catalogos()).entries) {
      catalogo.registrar(
        e.key,
        (jsonDecode(e.value) as Map).cast<String, String>(),
      );
    }
  }
}

/// Sincronización en línea (P1) con `GET /CodeSystem/{id}` y
/// `GET /CodeSystem?since=`, cuando haya credenciales y transporte. No se
/// ejecuta contra IHCE en este proyecto ni en las pruebas (solo con mocks).
/// El envío de un RDA nunca depende de estos endpoints.
class SincronizadorTerminologia {
  SincronizadorTerminologia({
    required this.cliente,
    required this.repositorio,
    required this.catalogo,
    Reloj? reloj,
  }) : reloj = reloj ?? const RelojSistema();

  final ValidadorVidaClient cliente;
  final RepositorioIhce repositorio;
  final CatalogoTerminologia catalogo;
  final Reloj reloj;

  /// Descarga el CodeSystem [id] y lo registra con su `url` como `system`.
  Future<int> sincronizar(String id) async {
    final r = await cliente.obtenerCodeSystem(
      id,
      ContextoEnvio(idCorrelacion: nuevoUuid(), documentoId: 'terminologia'),
    );
    if (r is! Encontrado || r.recurso['resourceType'] != 'CodeSystem') return 0;
    final conceptos = <String, String>{};
    void visitar(List<Object?> lista) {
      for (final c in lista.whereType<Map>()) {
        final code = c['code'];
        if (code is String) conceptos[code] = (c['display'] as String?) ?? '';
        visitar((c['concept'] as List?) ?? const []);
      }
    }

    visitar((r.recurso['concept'] as List?) ?? const []);
    final system = r.recurso['url'] as String?;
    if (system == null || conceptos.isEmpty) return 0;
    await repositorio.guardarCatalogo(system, jsonEncode(conceptos));
    catalogo.registrar(system, conceptos);
    catalogo.marcadosParaSincronizar.remove(system);
    return conceptos.length;
  }

  /// Ids de los CodeSystems modificados desde [desde].
  Future<List<String>> modificadosDesde(DateTime desde) async {
    final r = await cliente.codeSystemsDesde(
      desde,
      ContextoEnvio(idCorrelacion: nuevoUuid(), documentoId: 'terminologia'),
    );
    if (r is! Encontrado) return const [];
    return [
      for (final e in (r.recurso['entry'] as List?) ?? const [])
        if (e is Map && e['resource'] is Map && e['resource']['id'] is String)
          e['resource']['id'] as String,
    ];
  }
}
