import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../almacen/almacen.dart';
import '../repositorio/migraciones.dart';
import '../repositorio/repositorio.dart';
import '../seguridad/boveda.dart';
import '../seguridad/cifrado_registros.dart';
import '../seguridad/llavero.dart';
import '../seguridad/motor_aes.dart';

/// Respaldo del consultorio (`.hcrespaldo`): un ZIP sin compresión (el
/// contenido ya va cifrado) con
///
/// * `LEEME.txt`: qué es y cómo restaurarlo, sin datos;
/// * `manifiesto.json`, en claro: formato, fecha, esquema, el llavero
///   (sales, parámetros y la llave de datos envuelta) y el SHA-256 de cada
///   archivo;
/// * `manifiesto.sello`: el SHA-256 del manifiesto cifrado con la llave de
///   datos, que autentica el manifiesto;
/// * `registros/<colección>/<id>.bin` y `binarios/<tipo>/<id>.bin`: los
///   mismos bytes cifrados del almacén.
///
/// Se abre con la frase (o el código de recuperación) **del momento del
/// respaldo**.
abstract final class FormatoRespaldo {
  static const extension = '.hcrespaldo';
  static const tipoMime = 'application/octet-stream';
  static const identificador = 'historiasclinicas.net/respaldo';
  static const version = 1;
  static const leeme = 'LEEME.txt';
  static const manifiesto = 'manifiesto.json';
  static const sello = 'manifiesto.sello';
  static const carpetaRegistros = 'registros/';
  static const carpetaBinarios = 'binarios/';
  static const aadSello = 'hcc1|respaldo|manifiesto';
}

const _textoLeeme = '''
Respaldo cifrado del consultorio de historiasclinicas.net.

Contiene, cifrados con AES-256-GCM, los datos del consultorio guardados en
el navegador: índice de pacientes, documentos, fotos y datos de gestión.

Para restaurarlo: abre la versión del consultorio, ve a Ajustes, Respaldo,
«Restaurar…», elige este archivo y escribe la frase de acceso (o el código
de recuperación) que tenías cuando lo descargaste.

Sin esa frase ni el código, nadie puede abrirlo. Guarda copias en dos
lugares distintos (por ejemplo, una memoria USB y tu nube).
''';

/// Último respaldo descargado (en `meta`, en claro: solo fecha, huella y
/// tamaño).
class InfoRespaldo {
  const InfoRespaldo({
    required this.fecha,
    required this.huella,
    required this.tamano,
  });

  final DateTime fecha;

  /// SHA-256 del archivo descargado.
  final String huella;
  final int tamano;

  Map<String, Object?> aMapa() => {
    'fecha': fecha.toUtc().toIso8601String(),
    'huella': huella,
    'tamano': tamano,
  };

  Uint8List aBytes() => Uint8List.fromList(utf8.encode(jsonEncode(aMapa())));

  static InfoRespaldo? desdeBytes(Uint8List? b) {
    if (b == null) return null;
    final m = (jsonDecode(utf8.decode(b)) as Map).cast<String, Object?>();
    return InfoRespaldo(
      fecha: DateTime.parse(m['fecha']! as String).toLocal(),
      huella: m['huella']! as String,
      tamano: m['tamano']! as int,
    );
  }

  /// `true` si pasaron más de [dias] desde el respaldo.
  bool vencido(DateTime ahora, int dias) =>
      ahora.difference(fecha) > Duration(days: dias);
}

Future<InfoRespaldo?> leerInfoRespaldo(AlmacenConsultorio almacen) async =>
    InfoRespaldo.desdeBytes(
      await almacen.leer(Deposito.meta, ClavesMeta.respaldo),
    );

class ArchivoRespaldo {
  const ArchivoRespaldo({
    required this.nombre,
    required this.bytes,
    required this.info,
  });

  final String nombre;
  final Uint8List bytes;
  final InfoRespaldo info;
}

String _dos(int n) => n.toString().padLeft(2, '0');

String nombreArchivoRespaldo(DateTime f) =>
    'Respaldo_consultorio_${f.year}-${_dos(f.month)}-${_dos(f.day)}'
    '${FormatoRespaldo.extension}';

String _sha256(List<int> b) => sha256.convert(b).toString();

/// Arma el respaldo de todo el almacén y registra su fecha y huella en
/// `meta`. Necesita la bóveda desbloqueada (para sellar el manifiesto).
Future<ArchivoRespaldo> exportarRespaldo(
  Boveda boveda, {
  required DateTime ahora,
  String versionApp = '',
}) async {
  final almacen = boveda.almacen;
  final llavero = await boveda.leerLlavero();
  if (llavero == null) throw StateError('El consultorio no tiene llavero.');
  final registros = await almacen.leerTodo(Deposito.registros);
  final binarios = await almacen.leerTodo(Deposito.binarios);

  final archivos = <String, Uint8List>{
    for (final e in registros.entries)
      '${FormatoRespaldo.carpetaRegistros}${e.key}.bin': e.value,
    for (final e in binarios.entries)
      '${FormatoRespaldo.carpetaBinarios}${e.key}.bin': e.value,
  };
  final porColeccion = <String, int>{};
  for (final k in registros.keys) {
    final c = k.split('/').first;
    porColeccion[c] = (porColeccion[c] ?? 0) + 1;
  }
  final manifiesto = <String, Object?>{
    'formato': FormatoRespaldo.identificador,
    'version': FormatoRespaldo.version,
    if (versionApp.isNotEmpty) 'versionApp': versionApp,
    'creado': ahora.toUtc().toIso8601String(),
    'esquema': await leerVersionEsquema(almacen),
    'llavero': llavero.aMapa(),
    'conteos': {
      'registros': registros.length,
      'binarios': binarios.length,
      'porColeccion': porColeccion,
    },
    'archivos': {for (final e in archivos.entries) e.key: _sha256(e.value)},
  };
  final bytesManifiesto = Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(manifiesto)),
  );
  final sello = await boveda.cifrado.cifrar(
    Uint8List.fromList(sha256.convert(bytesManifiesto).bytes),
    FormatoRespaldo.aadSello,
  );

  final zip = Archive();
  void agregar(String nombre, List<int> datos) =>
      zip.addFile(ArchiveFile.noCompress(nombre, datos.length, datos));
  agregar(FormatoRespaldo.leeme, utf8.encode(_textoLeeme));
  agregar(FormatoRespaldo.manifiesto, bytesManifiesto);
  agregar(FormatoRespaldo.sello, sello);
  for (final e in archivos.entries) {
    agregar(e.key, e.value);
  }
  final bytes = ZipEncoder().encodeBytes(zip);

  final info = InfoRespaldo(
    fecha: ahora,
    huella: _sha256(bytes),
    tamano: bytes.length,
  );
  await almacen.aplicar([
    Cambio(Deposito.meta, ClavesMeta.respaldo, info.aBytes()),
  ]);
  return ArchivoRespaldo(
    nombre: nombreArchivoRespaldo(ahora),
    bytes: bytes,
    info: info,
  );
}

/// Por qué un respaldo no se puede restaurar entero.
enum TipoProblema {
  /// No es un respaldo de esta app, o está truncado.
  noEsRespaldo(fatal: true),

  /// Es de una versión más nueva de la app.
  versionNueva(fatal: true),

  /// La frase o el código no abren el llavero del respaldo.
  secretoIncorrecto(fatal: true),

  /// El manifiesto fue modificado (su sello no coincide).
  manifiestoAlterado(fatal: true),

  /// Un archivo listado no está en el ZIP.
  falta(fatal: false),

  /// El SHA-256 de un archivo no coincide con el manifiesto.
  huellaDistinta(fatal: false),

  /// Un archivo no se descifra con su clave (alterado o cambiado de lugar).
  noDescifra(fatal: false),

  /// Hay un archivo que el manifiesto no lista.
  sobrante(fatal: false),

  /// Los conteos del manifiesto no coinciden con los archivos.
  conteos(fatal: false);

  const TipoProblema({required this.fatal});

  final bool fatal;
}

class ProblemaRespaldo {
  const ProblemaRespaldo(this.tipo, [this.archivo = '']);

  final TipoProblema tipo;
  final String archivo;

  String get descripcion => switch (tipo) {
    TipoProblema.noEsRespaldo =>
      'El archivo no es un respaldo de esta app o está incompleto.',
    TipoProblema.versionNueva =>
      'El respaldo es de una versión más nueva de la app: actualízala antes '
          'de restaurarlo.',
    TipoProblema.secretoIncorrecto =>
      'La frase o el código no corresponden a este respaldo. Usa la frase '
          'que tenías cuando lo descargaste.',
    TipoProblema.manifiestoAlterado =>
      'El índice del respaldo fue modificado: no se puede confiar en él.',
    TipoProblema.falta => 'Falta $archivo.',
    TipoProblema.huellaDistinta => '$archivo fue modificado.',
    TipoProblema.noDescifra =>
      '$archivo no se puede descifrar (alterado o cambiado de lugar).',
    TipoProblema.sobrante => '$archivo no figura en el índice del respaldo.',
    TipoProblema.conteos =>
      'La cantidad de registros no coincide con el índice del respaldo.',
  };

  @override
  String toString() => descripcion;
}

/// Resultado de abrir y verificar un respaldo.
class VerificacionRespaldo {
  VerificacionRespaldo._({
    required this.problemas,
    this.creado,
    this.esquema = 0,
    this.llavero,
    this.llaveDatos,
    this.cambiosIntegros = const [],
    this.registros = 0,
    this.binarios = 0,
  });

  final List<ProblemaRespaldo> problemas;
  final DateTime? creado;
  final int esquema;
  final Llavero? llavero;

  /// La llave de datos del respaldo (solo si el llavero se abrió).
  final Uint8List? llaveDatos;

  /// Los archivos que pasaron todas las comprobaciones, listos para
  /// escribirse en el almacén.
  final List<Cambio> cambiosIntegros;
  final int registros;
  final int binarios;

  bool get integro => problemas.isEmpty;

  bool get restaurable =>
      llaveDatos != null && !problemas.any((p) => p.tipo.fatal);
}

/// Abre el respaldo con [secreto] (frase o, con [esCodigo], el código de
/// recuperación) y lo verifica entero, sin tocar el almacén.
Future<VerificacionRespaldo> verificarRespaldo(
  Uint8List bytes,
  String secreto, {
  required MotorAes motor,
  bool esCodigo = false,
  FabricaLlavero? fabrica,
}) async {
  VerificacionRespaldo fatal(TipoProblema t) =>
      VerificacionRespaldo._(problemas: [ProblemaRespaldo(t)]);

  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes, verify: true);
  } catch (_) {
    return fatal(TipoProblema.noEsRespaldo);
  }
  final contenido = <String, Uint8List>{
    for (final f in zip.files)
      if (f.isFile) f.name: f.content,
  };
  final bytesManifiesto = contenido[FormatoRespaldo.manifiesto];
  final sello = contenido[FormatoRespaldo.sello];
  if (bytesManifiesto == null || sello == null) {
    return fatal(TipoProblema.noEsRespaldo);
  }

  final Map<String, Object?> m;
  final Llavero llavero;
  final Map<String, String> archivos;
  final int esquema;
  final DateTime creado;
  try {
    m = (jsonDecode(utf8.decode(bytesManifiesto)) as Map).cast();
    if (m['formato'] != FormatoRespaldo.identificador) {
      return fatal(TipoProblema.noEsRespaldo);
    }
    if ((m['version'] as int? ?? 0) > FormatoRespaldo.version) {
      return fatal(TipoProblema.versionNueva);
    }
    esquema = m['esquema']! as int;
    if (esquema > versionEsquemaActual) {
      return fatal(TipoProblema.versionNueva);
    }
    creado = DateTime.parse(m['creado']! as String).toLocal();
    llavero = Llavero.desdeMapa((m['llavero']! as Map).cast());
    archivos = (m['archivos']! as Map).cast<String, String>();
  } catch (_) {
    return fatal(TipoProblema.noEsRespaldo);
  }

  final f = fabrica ?? FabricaLlavero(motor);
  final Uint8List llaveDatos;
  try {
    llaveDatos = esCodigo
        ? await f.abrirConCodigo(llavero, secreto)
        : await f.abrirConFrase(llavero, secreto);
  } on SecretoIncorrecto {
    return fatal(TipoProblema.secretoIncorrecto);
  }

  final cifrado = CifradoRegistros(
    motor,
    await motor.importar(Uint8List.fromList(llaveDatos)),
  );
  try {
    final esperado = await cifrado.descifrar(sello, FormatoRespaldo.aadSello);
    final real = sha256.convert(bytesManifiesto).bytes;
    if (!_iguales(esperado, real)) {
      return fatal(TipoProblema.manifiestoAlterado);
    }
  } catch (_) {
    return fatal(TipoProblema.manifiestoAlterado);
  }

  final problemas = <ProblemaRespaldo>[];
  final cambios = <Cambio>[];
  var nRegistros = 0;
  var nBinarios = 0;
  for (final e in archivos.entries) {
    final nombre = e.key;
    final datos = contenido[nombre];
    if (datos == null) {
      problemas.add(ProblemaRespaldo(TipoProblema.falta, nombre));
      continue;
    }
    if (_sha256(datos) != e.value) {
      problemas.add(ProblemaRespaldo(TipoProblema.huellaDistinta, nombre));
      continue;
    }
    final esRegistro = nombre.startsWith(FormatoRespaldo.carpetaRegistros);
    final esBinario = nombre.startsWith(FormatoRespaldo.carpetaBinarios);
    if ((!esRegistro && !esBinario) || !nombre.endsWith('.bin')) {
      problemas.add(ProblemaRespaldo(TipoProblema.noDescifra, nombre));
      continue;
    }
    final clave = nombre.substring(
      (esRegistro
              ? FormatoRespaldo.carpetaRegistros
              : FormatoRespaldo.carpetaBinarios)
          .length,
      nombre.length - '.bin'.length,
    );
    try {
      await cifrado.descifrar(
        datos,
        esRegistro
            ? RepositorioConsultorio.aadRegistro(clave)
            : RepositorioConsultorio.aadBinario(clave),
      );
    } catch (_) {
      problemas.add(ProblemaRespaldo(TipoProblema.noDescifra, nombre));
      continue;
    }
    cambios.add(
      Cambio(esRegistro ? Deposito.registros : Deposito.binarios, clave, datos),
    );
    if (esRegistro) {
      nRegistros++;
    } else {
      nBinarios++;
    }
  }
  const propios = {
    FormatoRespaldo.leeme,
    FormatoRespaldo.manifiesto,
    FormatoRespaldo.sello,
  };
  for (final nombre in contenido.keys) {
    if (!propios.contains(nombre) && !archivos.containsKey(nombre)) {
      problemas.add(ProblemaRespaldo(TipoProblema.sobrante, nombre));
    }
  }
  final conteos = (m['conteos'] as Map?)?.cast<String, Object?>() ?? const {};
  final totalRegistros = archivos.keys
      .where((k) => k.startsWith(FormatoRespaldo.carpetaRegistros))
      .length;
  final totalBinarios = archivos.keys
      .where((k) => k.startsWith(FormatoRespaldo.carpetaBinarios))
      .length;
  if (conteos['registros'] != totalRegistros ||
      conteos['binarios'] != totalBinarios) {
    problemas.add(const ProblemaRespaldo(TipoProblema.conteos));
  }

  return VerificacionRespaldo._(
    problemas: problemas,
    creado: creado,
    esquema: esquema,
    llavero: llavero,
    llaveDatos: llaveDatos,
    cambiosIntegros: cambios,
    registros: nRegistros,
    binarios: nBinarios,
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

/// Reemplaza **todo** el almacén por el respaldo verificado (en una sola
/// transacción) y deja la bóveda desbloqueada con su llave. Desde ahí, la
/// frase del consultorio es la del respaldo.
///
/// Con problemas no fatales, solo restaura si [aceptarParcial] (lo íntegro).
Future<void> restaurarRespaldo(
  Boveda boveda,
  VerificacionRespaldo v, {
  bool aceptarParcial = false,
}) async {
  if (!v.restaurable) throw StateError('El respaldo no se puede restaurar.');
  if (!v.integro && !aceptarParcial) {
    throw StateError('El respaldo tiene problemas: confirma restaurar parte.');
  }
  final info = InfoRespaldo(fecha: v.creado!, huella: '', tamano: 0);
  await boveda.almacen.aplicar([
    Cambio(Deposito.meta, ClavesMeta.llavero, v.llavero!.aBytes()),
    Cambio(
      Deposito.meta,
      ClavesMeta.esquema,
      Uint8List.fromList(utf8.encode('${v.esquema}')),
    ),
    Cambio(Deposito.meta, ClavesMeta.respaldo, info.aBytes()),
    ...v.cambiosIntegros,
  ], vaciarAntes: true);
  boveda.bloquear();
  await boveda.adoptarLlave(Uint8List.fromList(v.llaveDatos!));
}
