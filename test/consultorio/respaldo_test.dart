// Fase 5.0: respaldo cifrado (.hcrespaldo): ida y vuelta, frase y código,
// y detección de cada alteración.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/almacen/almacen.dart';
import 'package:historiasclinicas_net/core/consultorio/respaldo/respaldo.dart';
import 'package:historiasclinicas_net/core/consultorio/seguridad/boveda.dart';

import 'ayudas_consultorio.dart';

/// Consultorio con dos pacientes y una foto.
Future<({BancoConsultorio banco, String codigo})> _conDatos() async {
  final b = BancoConsultorio();
  final codigo = await b.servicio.crear(fraseDePrueba);
  final repo = b.servicio.repositorio;
  await repo.guardar('pacientes', 'p1', {'nombre': 'PACIENTE UNO'});
  await repo.guardar('pacientes', 'p2', {'nombre': 'PACIENTE DOS'});
  await repo.guardarBinario(
    'fotos',
    'f1',
    Uint8List.fromList(List.generate(500, (i) => i % 256)),
  );
  return (banco: b, codigo: codigo);
}

Map<String, Uint8List> _abrirZip(Uint8List bytes) => {
  for (final f in ZipDecoder().decodeBytes(bytes).files)
    if (f.isFile) f.name: f.content,
};

Uint8List _armarZip(Map<String, Uint8List> archivos) {
  final zip = Archive();
  for (final e in archivos.entries) {
    zip.addFile(ArchiveFile.noCompress(e.key, e.value.length, e.value));
  }
  return ZipEncoder().encodeBytes(zip);
}

Set<TipoProblema> _tipos(VerificacionRespaldo v) =>
    v.problemas.map((p) => p.tipo).toSet();

void main() {
  test(
    'ida y vuelta: otro equipo restaura con la frase del respaldo',
    () async {
      final (:banco, codigo: _) = await _conDatos();
      final archivo = await banco.servicio.respaldar();
      expect(archivo.nombre, 'Respaldo_consultorio_2026-11-21.hcrespaldo');
      expect(contieneTexto(archivo.bytes, 'PACIENTE UNO'), isFalse);
      expect(contieneTexto(archivo.bytes, fraseDePrueba), isFalse);

      final otro = BancoConsultorio();
      final v = await otro.servicio.verificar(archivo.bytes, fraseDePrueba);
      expect(v.integro, isTrue, reason: '${v.problemas}');
      expect(v.registros, greaterThanOrEqualTo(2));
      expect(v.binarios, 1);
      await otro.servicio.restaurar(v);
      expect(await otro.servicio.estado(), EstadoBoveda.desbloqueada);
      expect(await otro.servicio.repositorio.leer('pacientes', 'p2'), {
        'nombre': 'PACIENTE DOS',
      });
      expect(
        await otro.servicio.repositorio.leerBinario('fotos', 'f1'),
        hasLength(500),
      );
      // Desde ahí, la frase del consultorio es la del respaldo.
      await otro.servicio.bloquear();
      await otro.servicio.desbloquear(fraseDePrueba);
    },
  );

  test('el respaldo se abre también con el código de recuperación', () async {
    final (:banco, :codigo) = await _conDatos();
    final archivo = await banco.servicio.respaldar();
    final v = await BancoConsultorio().servicio.verificar(
      archivo.bytes,
      codigo,
      esCodigo: true,
    );
    expect(v.integro, isTrue);
  });

  test('restaurar reemplaza todo lo que había', () async {
    final (:banco, codigo: _) = await _conDatos();
    final archivo = await banco.servicio.respaldar();
    final otro = BancoConsultorio();
    await otro.servicio.crear('frase del otro equipo');
    await otro.servicio.repositorio.guardar('pacientes', 'zz', {'n': 'viejo'});
    final v = await otro.servicio.verificar(archivo.bytes, fraseDePrueba);
    await otro.servicio.restaurar(v);
    expect(await otro.servicio.repositorio.leer('pacientes', 'zz'), isNull);
    await otro.servicio.bloquear();
    await expectLater(
      otro.servicio.desbloquear('frase del otro equipo'),
      throwsA(anything),
    );
  });

  test('frase incorrecta: no se abre', () async {
    final (:banco, codigo: _) = await _conDatos();
    final archivo = await banco.servicio.respaldar();
    final v = await BancoConsultorio().servicio.verificar(
      archivo.bytes,
      'otra',
    );
    expect(_tipos(v), {TipoProblema.secretoIncorrecto});
    expect(v.restaurable, isFalse);
  });

  test('un manifiesto modificado se detecta por su sello', () async {
    final (:banco, codigo: _) = await _conDatos();
    final archivos = _abrirZip((await banco.servicio.respaldar()).bytes);
    final m =
        (jsonDecode(utf8.decode(archivos[FormatoRespaldo.manifiesto]!)) as Map)
            .cast<String, Object?>();
    m['creado'] = '2020-01-01T00:00:00.000Z';
    archivos[FormatoRespaldo.manifiesto] = Uint8List.fromList(
      utf8.encode(jsonEncode(m)),
    );
    final v = await BancoConsultorio().servicio.verificar(
      _armarZip(archivos),
      fraseDePrueba,
    );
    expect(_tipos(v), {TipoProblema.manifiestoAlterado});
  });

  test('un archivo modificado, faltante, sobrante o cambiado de lugar se '
      'detecta y se informa por nombre', () async {
    final (:banco, codigo: _) = await _conDatos();
    final archivos = _abrirZip((await banco.servicio.respaldar()).bytes);
    const p1 = 'registros/pacientes/p1.bin';
    const p2 = 'registros/pacientes/p2.bin';
    const f1 = 'binarios/fotos/f1.bin';
    // p1 y p2 intercambiados, la foto con un byte cambiado, un sobrante.
    final copia = Map<String, Uint8List>.of(archivos)
      ..[p1] = archivos[p2]!
      ..[p2] = archivos[p1]!
      ..[f1] = (Uint8List.fromList(archivos[f1]!)..[40] ^= 0xff)
      ..['registros/pacientes/intruso.bin'] = archivos[p1]!;
    final v = await BancoConsultorio().servicio.verificar(
      _armarZip(copia),
      fraseDePrueba,
    );
    final porArchivo = {for (final p in v.problemas) p.archivo: p.tipo};
    expect(porArchivo[p1], TipoProblema.huellaDistinta);
    expect(porArchivo[p2], TipoProblema.huellaDistinta);
    expect(porArchivo[f1], TipoProblema.huellaDistinta);
    expect(
      porArchivo['registros/pacientes/intruso.bin'],
      TipoProblema.sobrante,
    );
    expect(v.integro, isFalse);
    expect(v.restaurable, isTrue, reason: 'lo demás está íntegro');

    // Sin un archivo:
    final sinFoto = Map<String, Uint8List>.of(archivos)..remove(f1);
    final v2 = await BancoConsultorio().servicio.verificar(
      _armarZip(sinFoto),
      fraseDePrueba,
    );
    expect(v2.problemas.single.tipo, TipoProblema.falta);
    expect(v2.problemas.single.descripcion, contains(f1));
  });

  test('con problemas, solo se restaura lo íntegro y si se confirma', () async {
    final (:banco, codigo: _) = await _conDatos();
    final archivos = _abrirZip((await banco.servicio.respaldar()).bytes);
    const p1 = 'registros/pacientes/p1.bin';
    archivos[p1] = Uint8List.fromList(archivos[p1]!)..[20] ^= 1;
    final otro = BancoConsultorio();
    final v = await otro.servicio.verificar(_armarZip(archivos), fraseDePrueba);
    await expectLater(otro.servicio.restaurar(v), throwsStateError);
    expect(await otro.servicio.estado(), EstadoBoveda.sinConfigurar);
    await otro.servicio.restaurar(v, aceptarParcial: true);
    expect(await otro.servicio.repositorio.leer('pacientes', 'p1'), isNull);
    expect(await otro.servicio.repositorio.leer('pacientes', 'p2'), {
      'nombre': 'PACIENTE DOS',
    });
  });

  test('archivo ajeno, truncado o de una versión nueva', () async {
    final s = BancoConsultorio().servicio;
    final ajeno = await s.verificar(
      Uint8List.fromList(utf8.encode('hola')),
      'x',
    );
    expect(_tipos(ajeno), {TipoProblema.noEsRespaldo});

    final (:banco, codigo: _) = await _conDatos();
    final bytes = (await banco.servicio.respaldar()).bytes;
    final truncado = await s.verificar(
      Uint8List.sublistView(bytes, 0, bytes.length ~/ 2),
      fraseDePrueba,
    );
    expect(_tipos(truncado), {TipoProblema.noEsRespaldo});

    final archivos = _abrirZip(bytes);
    final m =
        (jsonDecode(utf8.decode(archivos[FormatoRespaldo.manifiesto]!)) as Map)
            .cast<String, Object?>();
    m['esquema'] = 99;
    archivos[FormatoRespaldo.manifiesto] = Uint8List.fromList(
      utf8.encode(jsonEncode(m)),
    );
    final nuevo = await s.verificar(_armarZip(archivos), fraseDePrueba);
    expect(_tipos(nuevo), {TipoProblema.versionNueva});
  });

  test(
    'el respaldo registra fecha, huella y tamaño, y avisa al vencer',
    () async {
      final (:banco, codigo: _) = await _conDatos();
      expect(await banco.servicio.infoRespaldo(), isNull);
      final archivo = await banco.servicio.respaldar();
      final info = (await banco.servicio.infoRespaldo())!;
      expect(info.tamano, archivo.bytes.length);
      expect(info.huella, hasLength(64));
      expect(info.vencido(banco.reloj.ahora(), 7), isFalse);
      expect(
        info.vencido(banco.reloj.ahora().add(const Duration(days: 8)), 7),
        isTrue,
      );
      // La fecha está en claro (meta) para avisar aun con el consultorio
      // bloqueado.
      await banco.servicio.bloquear();
      expect(await leerInfoRespaldo(banco.almacen), isNotNull);
      expect(
        banco.almacen.datos[Deposito.meta]!.keys,
        contains(ClavesMeta.respaldo),
      );
    },
  );

  test('el manifiesto no lleva datos del paciente', () async {
    final (:banco, codigo: _) = await _conDatos();
    final archivos = _abrirZip((await banco.servicio.respaldar()).bytes);
    final texto = utf8.decode(archivos[FormatoRespaldo.manifiesto]!);
    expect(texto, isNot(contains('PACIENTE')));
    expect(utf8.decode(archivos[FormatoRespaldo.leeme]!), contains('frase'));
  });
}
