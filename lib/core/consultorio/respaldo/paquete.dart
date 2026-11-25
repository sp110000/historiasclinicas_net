/// Paquete del equipo secundario (`.hcpaquete`, pregunta 3).
///
/// El secundario (p. ej. el celular) se configura restaurando un respaldo
/// del principal, así que comparte su llave. El paquete lleva lo creado en
/// el secundario desde esa restauración (fichas nuevas, mediciones, fotos y
/// documentos firmados), con el mismo formato y el mismo sello que el
/// respaldo, y en el principal **se combina**: lo que ya existe con el mismo
/// identificador no se duplica.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../almacen/almacen.dart';
import '../documentos/documento.dart';
import '../documentos/plantillas.dart';
import '../indice/indice_pacientes.dart';
import '../modelos/ficha_paciente.dart';
import '../modelos/foto.dart';
import '../modelos/medicion.dart';
import '../repositorio/repositorio.dart';
import '../seguridad/boveda.dart';
import 'respaldo.dart' show ArchivoRespaldo, InfoRespaldo;

abstract final class FormatoPaquete {
  static const extension = '.hcpaquete';
  static const identificador = 'historiasclinicas.net/paquete';
  static const version = 1;
  static const leeme = 'LEEME.txt';
  static const manifiesto = 'manifiesto.json';
  static const sello = 'manifiesto.sello';
  static const carpetaRegistros = 'registros/';
  static const carpetaBinarios = 'binarios/';
  static const aadSello = 'hcc1|paquete|manifiesto';

  /// Colecciones que viajan, con los binarios de cada registro.
  static const colecciones = {
    FichaPaciente.coleccion: <String>[],
    Medicion.coleccion: <String>[],
    Foto.coleccion: [Foto.tipoBinario, Foto.tipoMiniatura],
    DocumentoConsultorio.coleccion: [
      DocumentoConsultorio.tipoBinarioFirma,
      DocumentoConsultorio.tipoBinarioPdf,
    ],
  };
}

const _textoLeeme = '''
historiasclinicas.net · Paquete del equipo secundario

Lo creado en el equipo secundario (fichas nuevas, mediciones, fotos y
documentos firmados), cifrado con la llave del consultorio. En el equipo
principal: Ajustes → Equipo secundario → «Combinar un paquete». No reemplaza
nada: agrega lo que falta y no duplica lo que ya está.
''';

String _sha256(List<int> b) => sha256.convert(b).toString();

String _dos(int n) => n.toString().padLeft(2, '0');

String nombreArchivoPaquete(DateTime f) =>
    'Paquete_equipo_secundario_${f.year}-${_dos(f.month)}-${_dos(f.day)}'
    '${FormatoPaquete.extension}';

/// Cuándo se restauró un respaldo en este equipo, o `null`.
Future<DateTime?> leerRestauradoEn(AlmacenConsultorio almacen) async {
  final b = await almacen.leer(Deposito.meta, ClavesMeta.restauradoEn);
  return b == null ? null : DateTime.parse(utf8.decode(b)).toLocal();
}

/// Arma el paquete con lo creado desde [desde]. Necesita la bóveda abierta.
Future<ArchivoRespaldo> exportarPaquete(
  Boveda boveda,
  RepositorioConsultorio repo, {
  required DateTime desde,
  required DateTime ahora,
}) async {
  final almacen = boveda.almacen;
  final archivos = <String, Uint8List>{};
  final conteos = <String, int>{};
  for (final e in FormatoPaquete.colecciones.entries) {
    final datos = await repo.leerColeccionTolerante(e.key);
    final sobres = await almacen.leerTodo(
      Deposito.registros,
      prefijo: '${e.key}/',
    );
    for (final r in datos.registros.entries) {
      final creado = DateTime.tryParse('${r.value['creado']}');
      if (creado == null || creado.isBefore(desde)) continue;
      final clave = RepositorioConsultorio.claveRegistro(e.key, r.key);
      archivos['${FormatoPaquete.carpetaRegistros}$clave.bin'] = sobres[clave]!;
      conteos[e.key] = (conteos[e.key] ?? 0) + 1;
      for (final tipo in e.value) {
        final cb = RepositorioConsultorio.claveRegistro(tipo, r.key);
        final b = await almacen.leer(Deposito.binarios, cb);
        if (b != null) {
          archivos['${FormatoPaquete.carpetaBinarios}$cb.bin'] = b;
        }
      }
    }
  }
  final manifiesto = <String, Object?>{
    'formato': FormatoPaquete.identificador,
    'version': FormatoPaquete.version,
    'creado': ahora.toUtc().toIso8601String(),
    'desde': desde.toUtc().toIso8601String(),
    'conteos': conteos,
    'archivos': {for (final e in archivos.entries) e.key: _sha256(e.value)},
  };
  final bytesManifiesto = Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(manifiesto)),
  );
  final sello = await boveda.cifrado.cifrar(
    Uint8List.fromList(sha256.convert(bytesManifiesto).bytes),
    FormatoPaquete.aadSello,
  );
  final zip = Archive();
  void agregar(String nombre, List<int> d) =>
      zip.addFile(ArchiveFile.noCompress(nombre, d.length, d));
  agregar(FormatoPaquete.leeme, utf8.encode(_textoLeeme));
  agregar(FormatoPaquete.manifiesto, bytesManifiesto);
  agregar(FormatoPaquete.sello, sello);
  for (final e in archivos.entries) {
    agregar(e.key, e.value);
  }
  final bytes = ZipEncoder().encodeBytes(zip);
  return ArchivoRespaldo(
    nombre: nombreArchivoPaquete(ahora),
    bytes: bytes,
    info: InfoRespaldo(
      fecha: ahora,
      huella: _sha256(bytes),
      tamano: bytes.length,
    ),
  );
}

/// Un paquete verificado: sus registros y binarios cifrados, por clave.
class PaqueteVerificado {
  const PaqueteVerificado({
    required this.creado,
    required this.registros,
    required this.binarios,
  });

  final DateTime creado;
  final Map<String, Uint8List> registros;
  final Map<String, Uint8List> binarios;

  Map<String, int> get porColeccion {
    final r = <String, int>{};
    for (final k in registros.keys) {
      final c = k.split('/').first;
      r[c] = (r[c] ?? 0) + 1;
    }
    return r;
  }
}

/// Verifica el paquete con la llave del consultorio abierto: sello del
/// manifiesto, huella de cada archivo y que todo se descifre con su AAD.
/// Lanza [FormatException] con el motivo, para mostrarlo.
Future<PaqueteVerificado> verificarPaquete(
  Uint8List bytes,
  Boveda boveda,
) async {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes, verify: true);
  } catch (_) {
    throw const FormatException('El archivo no es un paquete del consultorio.');
  }
  final contenido = <String, Uint8List>{
    for (final f in zip.files)
      if (f.isFile) f.name: f.content,
  };
  final bm = contenido[FormatoPaquete.manifiesto];
  final sello = contenido[FormatoPaquete.sello];
  if (bm == null || sello == null) {
    throw const FormatException('El archivo no es un paquete del consultorio.');
  }
  final Map<String, Object?> m;
  try {
    m = (jsonDecode(utf8.decode(bm)) as Map).cast();
  } catch (_) {
    throw const FormatException('El paquete está dañado.');
  }
  if (m['formato'] != FormatoPaquete.identificador) {
    throw const FormatException('El archivo no es un paquete del consultorio.');
  }
  if ((m['version'] as int? ?? 0) > FormatoPaquete.version) {
    throw const FormatException(
      'El paquete es de una versión más nueva de la app: actualízala.',
    );
  }
  try {
    final esperado = await boveda.cifrado.descifrar(
      sello,
      FormatoPaquete.aadSello,
    );
    if (!_iguales(esperado, sha256.convert(bm).bytes)) throw Exception();
  } catch (_) {
    throw const FormatException(
      'El paquete no es de este consultorio (otra llave) o fue alterado.',
    );
  }
  final archivos = (m['archivos']! as Map).cast<String, String>();
  final registros = <String, Uint8List>{};
  final binarios = <String, Uint8List>{};
  for (final e in archivos.entries) {
    final datos = contenido[e.key];
    if (datos == null || _sha256(datos) != e.value || !e.key.endsWith('.bin')) {
      throw FormatException('El paquete está incompleto o alterado: ${e.key}');
    }
    final esRegistro = e.key.startsWith(FormatoPaquete.carpetaRegistros);
    final clave = e.key.substring(
      (esRegistro
              ? FormatoPaquete.carpetaRegistros
              : FormatoPaquete.carpetaBinarios)
          .length,
      e.key.length - 4,
    );
    try {
      await boveda.cifrado.descifrar(
        datos,
        esRegistro
            ? RepositorioConsultorio.aadRegistro(clave)
            : RepositorioConsultorio.aadBinario(clave),
      );
    } catch (_) {
      throw FormatException('No se pudo descifrar ${e.key}.');
    }
    (esRegistro ? registros : binarios)[clave] = datos;
  }
  return PaqueteVerificado(
    creado: DateTime.parse(m['creado']! as String).toLocal(),
    registros: registros,
    binarios: binarios,
  );
}

bool _iguales(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    d |= a[i] ^ b[i];
  }
  return d == 0;
}

/// Lo que pasó al combinar.
class ResultadoPaquete {
  const ResultadoPaquete({
    required this.agregados,
    required this.yaEstaban,
    required this.fichasUnidas,
  });

  /// Registros nuevos por colección.
  final Map<String, int> agregados;
  final int yaEstaban;

  /// Fichas del secundario que coincidían (por documento) con una del
  /// principal: quedan unidas a ella.
  final int fichasUnidas;

  int get totalAgregados => agregados.values.fold(0, (a, b) => a + b);
}

/// Combina el paquete en este equipo (el principal). Una ficha nueva del
/// secundario con el mismo documento que una de aquí queda unida a esa; los
/// documentos vigentes se ligan a su ficha si no tenía uno. Luego hay que
/// recargar el índice, los documentos y el seguimiento.
Future<ResultadoPaquete> combinarPaquete(
  PaqueteVerificado p,
  RepositorioConsultorio repo,
  IndicePacientes indice, {
  required DateTime ahora,
}) async {
  final almacen = repo.boveda.almacen;
  final existentes = await almacen.leerTodo(Deposito.registros);
  final existentesBin = await almacen.leerTodo(Deposito.binarios);
  final cambios = <Cambio>[];
  final agregados = <String, int>{};
  var yaEstaban = 0;
  var unidas = 0;
  final fichasReescritas = <Escritura>[];
  final documentosNuevos = <DocumentoConsultorio>[];

  for (final e in p.registros.entries) {
    if (existentes.containsKey(e.key)) {
      yaEstaban++;
      continue;
    }
    final (coleccion, id) = (
      e.key.substring(0, e.key.indexOf('/')),
      e.key.substring(e.key.indexOf('/') + 1),
    );
    if (coleccion == FichaPaciente.coleccion) {
      final ficha = FichaPaciente.desdeMapa(
        id,
        await repo.descifrarSobre(e.key, e.value),
      );
      final igual = indice.porClave(ficha.clave);
      if (igual != null && igual.id != ficha.id) {
        // La misma persona: la ficha del secundario queda unida a la de aquí.
        fichasReescritas.add(
          Escritura(
            coleccion,
            id,
            ficha.copyWith(unidaEn: igual.id, actualizado: ahora).aMapa(),
          ),
        );
        unidas++;
        agregados[coleccion] = (agregados[coleccion] ?? 0) + 1;
        continue;
      }
    }
    if (coleccion == DocumentoConsultorio.coleccion) {
      documentosNuevos.add(
        DocumentoConsultorio.desdeMapa(
          id,
          await repo.descifrarSobre(e.key, e.value),
        ),
      );
    }
    cambios.add(Cambio(Deposito.registros, e.key, e.value));
    agregados[coleccion] = (agregados[coleccion] ?? 0) + 1;
  }
  for (final e in p.binarios.entries) {
    if (!existentesBin.containsKey(e.key)) {
      cambios.add(Cambio(Deposito.binarios, e.key, e.value));
    }
  }
  await repo.esperarEscrituras();
  await almacen.aplicar(cambios);
  if (fichasReescritas.isNotEmpty) await repo.guardarVarios(fichasReescritas);

  // Recargar el índice para ligar los documentos a su ficha.
  await indice.cargar();
  for (final d in documentosNuevos.where((d) => d.vigente)) {
    final f = indice.fichaActiva(d.pacienteId);
    if (f == null) continue;
    if (d.tipo == TipoPlantilla.autorizacionDatos &&
        f.autorizacionDatosId == null) {
      await indice.guardarFicha(f.copyWith(autorizacionDatosId: d.id));
    } else if (d.tipo == TipoPlantilla.consentimientoImagen &&
        f.consentimientoImagenId == null) {
      await indice.guardarFicha(f.copyWith(consentimientoImagenId: d.id));
    }
  }
  return ResultadoPaquete(
    agregados: agregados,
    yaEstaban: yaEstaban,
    fichasUnidas: unidas,
  );
}
