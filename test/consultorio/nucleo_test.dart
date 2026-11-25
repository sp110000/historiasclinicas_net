// Fase 5.0: núcleo cifrado del consultorio (almacén, AES-GCM con AAD,
// llavero en sobre, bóveda, repositorio, migraciones, candado y ajustes).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/almacen/almacen.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/configuracion.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/migraciones.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/repositorio.dart';
import 'package:historiasclinicas_net/core/consultorio/seguridad/boveda.dart';
import 'package:historiasclinicas_net/core/consultorio/seguridad/cifrado_registros.dart';
import 'package:historiasclinicas_net/core/consultorio/seguridad/derivacion.dart';
import 'package:historiasclinicas_net/core/consultorio/seguridad/llavero.dart';
import 'package:historiasclinicas_net/core/consultorio/seguridad/motor_aes.dart';
import 'package:historiasclinicas_net/core/consultorio/seguridad/motor_aes_dart.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';

import 'ayudas_consultorio.dart';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('derivación', () {
    test('PBKDF2-HMAC-SHA256 da el vector conocido (portabilidad)', () async {
      // PBKDF2-HMAC-SHA256("password", "salt", 1, 32): vector publicado.
      final llave = await derivarLlave(
        'password',
        utf8.encode('salt'),
        const ParametrosDerivacion.pbkdf2(1),
      );
      expect(
        llave.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('la misma frase con tildes compuestas o separadas da la misma '
        'llave', () async {
      final sal = utf8.encode('sal-de-prueba-16');
      final compuesta = await derivarLlave('Perú año', sal, parametrosDePrueba);
      final separada = await derivarLlave(
        'Perú año ',
        sal,
        parametrosDePrueba,
      );
      expect(separada, compuesta);
    });

    test('Argon2id deriva 32 bytes y los parámetros van y vuelven', () async {
      const p = ParametrosDerivacion.argon2id(memoriaKib: 64, iteraciones: 1);
      final llave = await derivarLlave('frase', utf8.encode('saldeprueba'), p);
      expect(llave, hasLength(32));
      final vuelta = ParametrosDerivacion.desdeMapa(p.aMapa());
      expect(vuelta.algoritmo, ParametrosDerivacion.idArgon2id);
      expect(vuelta.memoriaKib, 64);
      expect(
        () => ParametrosDerivacion.desdeMapa({
          'algoritmo': 'x',
          'iteraciones': 1,
        }),
        throwsFormatException,
      );
    });
  });

  group('AES-256-GCM con AAD', () {
    final motor = MotorAesDart();

    test('cifra, descifra y detecta un byte cambiado o otra AAD', () async {
      final llave = await motor.importar(Uint8List(32)..fillRange(0, 32, 7));
      final nonce = Uint8List(12);
      final cifrado = await motor.cifrar(
        llave,
        nonce,
        _b('hola'),
        aad: _b('a'),
      );
      expect(cifrado, hasLength(4 + 16));
      expect(
        await motor.descifrar(llave, nonce, cifrado, aad: _b('a')),
        _b('hola'),
      );
      final alterado = Uint8List.fromList(cifrado)..[0] ^= 1;
      await expectLater(
        motor.descifrar(llave, nonce, alterado, aad: _b('a')),
        throwsA(isA<ErrorDescifrado>()),
      );
      await expectLater(
        motor.descifrar(llave, nonce, cifrado, aad: _b('b')),
        throwsA(isA<ErrorDescifrado>()),
      );
    });

    test('el formato de registro lleva versión y nonce al azar', () async {
      final c = CifradoRegistros(motor, await motor.importar(Uint8List(32)));
      final a = await c.cifrar(_b('x'), 'hcc1|p/1');
      final b = await c.cifrar(_b('x'), 'hcc1|p/1');
      expect(a[0], CifradoRegistros.formato);
      expect(a, isNot(b), reason: 'cada cifrado usa un nonce nuevo');
      expect(await c.descifrar(a, 'hcc1|p/1'), _b('x'));
      await expectLater(
        c.descifrar(a, 'hcc1|p/2'),
        throwsA(isA<ErrorDescifrado>()),
      );
      expect(
        () => c.descifrar(Uint8List.fromList([9, ...a.skip(1)]), 'hcc1|p/1'),
        throwsFormatException,
      );
    });

    test('la llave importada debe tener 32 bytes', () {
      expect(() => motor.importar(Uint8List(16)), throwsArgumentError);
    });
  });

  group('llavero en sobre', () {
    final motor = MotorAesDart();
    final fabrica = fabricaDePrueba(motor);

    test('se abre con la frase y con el código, no con otros', () async {
      final r = await fabrica.crear(fraseDePrueba, ahora: DateTime(2026));
      expect(codigoBienFormado(r.codigo), isTrue);
      expect(
        await fabrica.abrirConFrase(r.llavero, fraseDePrueba),
        r.llaveDatos,
      );
      expect(await fabrica.abrirConCodigo(r.llavero, r.codigo), r.llaveDatos);
      // El código se acepta en minúsculas, con guiones y con O por 0.
      final escrito = formatearCodigo(r.codigo).toLowerCase();
      expect(await fabrica.abrirConCodigo(r.llavero, escrito), r.llaveDatos);
      await expectLater(
        fabrica.abrirConFrase(r.llavero, 'otra frase cualquiera'),
        throwsA(isA<SecretoIncorrecto>()),
      );
      await expectLater(
        fabrica.abrirConCodigo(r.llavero, '0' * 24),
        throwsA(isA<SecretoIncorrecto>()),
      );
    });

    test('cambiar la frase conserva la llave de datos', () async {
      final r = await fabrica.crear(fraseDePrueba, ahora: DateTime(2026));
      final nuevo = await fabrica.cambiarFrase(
        r.llavero,
        r.llaveDatos,
        'frase nueva y larga',
      );
      expect(
        await fabrica.abrirConFrase(nuevo, 'frase nueva y larga'),
        r.llaveDatos,
      );
      await expectLater(
        fabrica.abrirConFrase(nuevo, fraseDePrueba),
        throwsA(isA<SecretoIncorrecto>()),
      );
      expect(await fabrica.abrirConCodigo(nuevo, r.codigo), r.llaveDatos);
    });

    test('el llavero va y vuelve y no contiene la frase ni la llave', () async {
      final r = await fabrica.crear(fraseDePrueba, ahora: DateTime(2026));
      final bytes = r.llavero.aBytes();
      expect(Llavero.desdeBytes(bytes).aMapa(), r.llavero.aMapa());
      final texto = utf8.decode(bytes);
      expect(texto, isNot(contains(fraseDePrueba)));
      expect(texto, isNot(contains(r.codigo)));
      expect(texto, isNot(contains(base64Encode(r.llaveDatos))));
    });

    test('formato del código de recuperación', () {
      expect(formatearCodigo('abcd' * 6), 'ABCD-ABCD-ABCD-ABCD-ABCD-ABCD');
      expect(normalizarCodigo('o1l-I'), '0111');
      expect(codigoBienFormado('ABCD-EFGH'), isFalse);
      expect(codigoBienFormado('U' * 24), isFalse, reason: 'U no es Crockford');
    });
  });

  group('servicio y bóveda', () {
    test(
      'crear deja el consultorio abierto y no guarda nada en claro',
      () async {
        final b = BancoConsultorio();
        expect(await b.servicio.estado(), EstadoBoveda.sinConfigurar);
        final codigo = await b.servicio.crear(fraseDePrueba);
        expect(codigoBienFormado(codigo), isTrue);
        expect(await b.servicio.estado(), EstadoBoveda.desbloqueada);
        await b.servicio.repositorio.guardar('pacientes', 'p1', {
          'nombre': 'PACIENTE SINTETICO',
          'documento': 'CC 9900000001',
        });
        expect(contieneTexto(b.todosLosBytes, 'PACIENTE SINTETICO'), isFalse);
        expect(contieneTexto(b.todosLosBytes, '9900000001'), isFalse);
        expect(contieneTexto(b.todosLosBytes, fraseDePrueba), isFalse);
        expect(contieneTexto(b.todosLosBytes, codigo), isFalse);
        expect(
          b.almacen.datos[Deposito.registros]!.keys,
          everyElement(isNot(contains('SINTETICO'))),
        );
        expect(
          await b.servicio.repositorio.leer('pacientes', 'p1'),
          containsPair('nombre', 'PACIENTE SINTETICO'),
        );
      },
    );

    test('bloquear descarta la llave: nada se lee ni se escribe', () async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      await b.servicio.repositorio.guardar('pacientes', 'p1', {'n': 1});
      await b.servicio.bloquear();
      expect(await b.servicio.estado(), EstadoBoveda.bloqueada);
      expect(b.candado.tomado, isFalse);
      await expectLater(
        b.servicio.repositorio.leer('pacientes', 'p1'),
        throwsA(isA<BovedaBloqueada>()),
      );
      await expectLater(
        b.servicio.repositorio.guardar('pacientes', 'p2', {'n': 2}),
        throwsA(isA<BovedaBloqueada>()),
      );
    });

    test('frase incorrecta: sigue bloqueado; la correcta abre', () async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      await b.servicio.repositorio.guardar('pacientes', 'p1', {'n': 1});
      await b.servicio.bloquear();
      await expectLater(
        b.servicio.desbloquear('no es la frase'),
        throwsA(isA<SecretoIncorrecto>()),
      );
      expect(await b.servicio.estado(), EstadoBoveda.bloqueada);
      await b.servicio.desbloquear(fraseDePrueba);
      expect(await b.servicio.repositorio.leer('pacientes', 'p1'), {'n': 1});
    });

    test('recuperar con el código pone una frase nueva', () async {
      final b = BancoConsultorio();
      final codigo = await b.servicio.crear(fraseDePrueba);
      await b.servicio.repositorio.guardar('pacientes', 'p1', {'n': 1});
      await b.servicio.bloquear();
      await b.servicio.recuperar(formatearCodigo(codigo), 'frase recuperada 1');
      expect(await b.servicio.repositorio.leer('pacientes', 'p1'), {'n': 1});
      await b.servicio.bloquear();
      await expectLater(
        b.servicio.desbloquear(fraseDePrueba),
        throwsA(isA<SecretoIncorrecto>()),
      );
      await b.servicio.desbloquear('frase recuperada 1');
    });

    test('cambiar la frase exige la actual', () async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      await expectLater(
        b.servicio.cambiarFrase('equivocada', 'otra frase nueva'),
        throwsA(isA<SecretoIncorrecto>()),
      );
      await b.servicio.cambiarFrase(fraseDePrueba, 'otra frase nueva');
      await b.servicio.bloquear();
      await b.servicio.desbloquear('otra frase nueva');
    });

    test(
      'no se crea una segunda frase sobre un consultorio existente',
      () async {
        final b = BancoConsultorio();
        await b.servicio.crear(fraseDePrueba);
        await b.servicio.bloquear();
        await expectLater(b.servicio.crear('otra'), throwsStateError);
      },
    );

    test(
      'otra pestaña con el consultorio abierto impide desbloquear',
      () async {
        final b = BancoConsultorio();
        await b.servicio.crear(fraseDePrueba);
        await b.servicio.bloquear();
        b.candado.ocupadoPorOtra = true;
        await expectLater(
          b.servicio.desbloquear(fraseDePrueba),
          throwsA(isA<OtraPestanaAbierta>()),
        );
        expect(await b.servicio.estado(), EstadoBoveda.bloqueada);
      },
    );
  });

  group('repositorio', () {
    test('un registro copiado sobre otra clave no se descifra', () async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      final repo = b.servicio.repositorio;
      await repo.guardar('pacientes', 'a', {'n': 'A'});
      await repo.guardar('pacientes', 'b', {'n': 'B'});
      final registros = b.almacen.datos[Deposito.registros]!;
      registros['pacientes/b'] = registros['pacientes/a']!;
      await expectLater(
        repo.leer('pacientes', 'b'),
        throwsA(isA<ErrorDescifrado>()),
      );
    });

    test('guardarVarios es atómico', () async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      final repo = b.servicio.repositorio;
      b.almacen.fallarProximaEscritura = true;
      await expectLater(
        repo.guardarVarios(const [
          Escritura('pacientes', '1', {'n': 1}),
          Escritura('pacientes', '2', {'n': 2}),
        ]),
        throwsStateError,
      );
      expect(await repo.leerColeccion('pacientes'), isEmpty);
      await repo.guardarVarios(const [
        Escritura('pacientes', '1', {'n': 1}),
        Escritura('pacientes', '2', {'n': 2}),
      ]);
      expect((await repo.leerColeccion('pacientes')).keys, ['1', '2']);
    });

    test('binarios cifrados con su propia AAD', () async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      final repo = b.servicio.repositorio;
      final foto = Uint8List.fromList(List.generate(1000, (i) => i % 251));
      await repo.guardarBinario('fotos', 'f1', foto);
      expect(await repo.leerBinario('fotos', 'f1'), foto);
      final guardado = b.almacen.datos[Deposito.binarios]!['fotos/f1']!;
      expect(guardado.length, foto.length + 1 + 12 + 16);
      // Un binario no se puede leer como registro de la misma clave.
      b.almacen.datos[Deposito.registros]!['fotos/f1'] = guardado;
      await expectLater(
        repo.leer('fotos', 'f1'),
        throwsA(isA<ErrorDescifrado>()),
      );
    });

    test('colección con caché', () async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      final c = Coleccion<Map<String, Object?>>(
        b.servicio.repositorio,
        'notas',
        idDe: (m) => m['id']! as String,
        aMapa: (m) => m,
        desdeMapa: (m) => m,
      );
      await c.guardar({'id': 'x', 'texto': 'uno'});
      expect(c.porId('x'), {'id': 'x', 'texto': 'uno'});
      c.olvidar();
      expect(c.porId('x'), isNull);
      await c.cargar();
      expect(c.todos.single['texto'], 'uno');
    });
  });

  group('migraciones', () {
    test('el esquema queda en la versión actual al crear', () async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      expect(await leerVersionEsquema(b.almacen), versionEsquemaActual);
    });

    test(
      'una migración nueva se aplica una vez y junto con su versión',
      () async {
        final b = BancoConsultorio();
        await b.servicio.crear(fraseDePrueba);
        final repo = b.servicio.repositorio;
        await repo.guardar('pacientes', '1', {'nombre': 'x'});
        var veces = 0;
        final lista = [
          ...migracionesConsultorio,
          MigracionConsultorio(versionEsquemaActual + 1, 'Agrega un campo', (
            r,
          ) async {
            veces++;
            final p = (await r.leer('pacientes', '1'))!;
            const clave = 'pacientes/1';
            return [
              Cambio(
                Deposito.registros,
                clave,
                await r.boveda.cifrado.cifrar(
                  Uint8List.fromList(
                    utf8.encode(jsonEncode({...p, 'nuevo': true})),
                  ),
                  RepositorioConsultorio.aadRegistro(clave),
                ),
              ),
            ];
          }),
        ];
        expect(
          await migrar(repo, migraciones: lista),
          versionEsquemaActual + 1,
        );
        expect(
          await migrar(repo, migraciones: lista),
          versionEsquemaActual + 1,
        );
        expect(veces, 1);
        expect(await repo.leer('pacientes', '1'), {
          'nombre': 'x',
          'nuevo': true,
        });
      },
    );

    test('un almacén de una versión más nueva no se abre', () async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      await b.servicio.bloquear();
      await b.almacen.aplicar([
        Cambio(
          Deposito.meta,
          ClavesMeta.esquema,
          Uint8List.fromList(utf8.encode('99')),
        ),
      ]);
      await expectLater(
        b.servicio.desbloquear(fraseDePrueba),
        throwsStateError,
      );
      expect(await b.servicio.estado(), EstadoBoveda.bloqueada);
    });
  });

  group('ajustes y bitácora', () {
    test('los ajustes se guardan cifrados y se acotan', () async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      expect(b.servicio.configuracion.minutosBloqueo, 10);
      expect(b.servicio.configuracion.diasRespaldo, 7);
      await b.servicio.guardarConfiguracion(
        const ConfiguracionConsultorio().copyWith(
          minutosBloqueo: 500,
          diasRespaldo: 0,
        ),
      );
      expect(b.servicio.configuracion.minutosBloqueo, 60);
      expect(b.servicio.configuracion.diasRespaldo, 1);
      await b.servicio.bloquear();
      expect(b.servicio.configuracion.minutosBloqueo, 10);
      await b.servicio.desbloquear(fraseDePrueba);
      expect(b.servicio.configuracion.minutosBloqueo, 60);
    });

    test('la bitácora registra las acciones sin datos del paciente', () async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      await b.servicio.bloquear(automatico: true);
      await b.servicio.desbloquear(fraseDePrueba);
      final acciones = (await b.servicio.bitacora())
          .map((e) => e.accion)
          .toSet();
      expect(acciones, {
        AccionBitacora.crearFrase,
        AccionBitacora.bloqueoAutomatico,
        AccionBitacora.desbloquear,
      });
    });
  });
}
