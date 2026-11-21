import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/almacen/almacen.dart';
import 'package:historiasclinicas_net/core/consultorio/indice/indice_pacientes.dart';
import 'package:historiasclinicas_net/core/consultorio/indice/normalizar.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/ficha_paciente.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/repositorio.dart';
import 'package:historiasclinicas_net/core/integridad/cadena_hash.dart';
import 'package:historiasclinicas_net/core/models/evolucion.dart';
import 'package:pdf/widgets.dart' as pw;

import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

void main() {
  late BancoConsultorio b;
  late IndicePacientes indice;

  setUp(() async {
    b = BancoConsultorio();
    await b.servicio.crear(fraseDePrueba);
    indice = IndicePacientes(b.servicio.repositorio, reloj: b.reloj);
    await indice.cargar();
  });

  group('Normalización', () {
    test('buscar sin tildes ni mayúsculas', () {
      expect(
        paraBuscar('  Peña   MUÑOZ, José Ángel '),
        'pena munoz, jose angel',
      );
      expect(paraBuscar('Ü ç'), 'u c');
    });

    test('documentos sin puntos, espacios ni guiones', () {
      expect(documentoNormalizado('1.032.456 789'), '1032456789');
      expect(documentoNormalizado('ab-123'), 'AB123');
      expect(claveDocumento('cc', '1.032.456.789'), 'CC:1032456789');
      expect(claveDocumento('AS', '123'), isNull);
      expect(claveDocumento('MS', '123'), isNull);
      expect(claveDocumento('CC', ' '), isNull);
    });
  });

  group('Registrar historias', () {
    test(
      'una historia nueva crea la ficha y guarda datos y PDF cifrados',
      () async {
        final datos = historiaSintetica();
        final pdf = await pdfCon(datos);
        final r = await indice.registrarHistoria(
          datos,
          revision: 1,
          origen: OrigenArchivo.generado,
          nombreArchivo: 'historia.pdf',
          bytesPdf: pdf,
        );
        expect(r.tipo, TipoRegistro.nueva);
        expect(r.pacienteNuevo, isTrue);
        expect(r.integridadCorrecta, isTrue);

        final ficha = indice.ficha(r.pacienteId)!;
        expect(ficha.clave, 'CC:1032456789');
        expect(ficha.nombreCompleto, 'PEÑA MUÑOZ, José Ángel');
        expect(ficha.telefono, '300 123 4567');

        final h = indice.historia(r.historiaId)!;
        expect(h.pacienteId, ficha.id);
        expect(h.diagnosticos.first, startsWith('J02.9'));
        expect(h.alergias, ['Penicilina', 'AINEs']);
        expect(h.tienePdf, isTrue);
        expect(h.archivos.single.nombre, 'historia.pdf');
        expect(h.archivos.single.origen, OrigenArchivo.generado);

        expect(await indice.pdfDe(r.historiaId), pdf);
        expect(await indice.datosDe(r.historiaId), datos);

        // Nada en claro en el almacén.
        await b.servicio.repositorio.esperarEscrituras();
        final bytes = b.todosLosBytes;
        expect(contieneTexto(bytes, '1032456789'), isFalse);
        expect(contieneTexto(bytes, 'Faringitis'), isFalse);
        expect(contieneTexto(bytes, 'Penicilina'), isFalse);
      },
    );

    test(
      'la misma versión no se duplica; una más nueva la reemplaza',
      () async {
        final v1 = historiaSintetica();
        await indice.registrarHistoria(
          v1,
          revision: 1,
          origen: OrigenArchivo.generado,
          nombreArchivo: 'a.pdf',
        );
        final otra = await indice.registrarHistoria(
          v1,
          revision: 1,
          origen: OrigenArchivo.abierto,
          nombreArchivo: 'a.pdf',
        );
        expect(otra.tipo, TipoRegistro.yaEstaba);

        final v2 = sellarEvoluciones(v1, [
          Evolucion(
            id: 'e1',
            fechaHora: DateTime(2026, 10, 9, 10),
            texto: 'Mejoría. Sin fiebre.',
          ).aMapa(),
        ]);
        final nueva = await indice.registrarHistoria(
          v2,
          revision: 2,
          origen: OrigenArchivo.generado,
          nombreArchivo: 'a.pdf',
        );
        expect(nueva.tipo, TipoRegistro.actualizada);
        expect(nueva.pacienteNuevo, isFalse);
        final h = indice.historia(nueva.historiaId)!;
        expect(h.revision, 2);
        expect(h.evoluciones.single.resumen, 'Mejoría. Sin fiebre.');
        expect(h.ultimaAtencion, DateTime(2026, 10, 9, 10));
        expect(h.archivos.map((a) => a.revision), [1, 2]);

        final vieja = await indice.registrarHistoria(
          v1,
          revision: 1,
          origen: OrigenArchivo.abierto,
          nombreArchivo: 'copia vieja.pdf',
        );
        expect(vieja.tipo, TipoRegistro.masVieja);
        expect(indice.historia(h.id)!.revision, 2);
        expect(await indice.datosDe(h.id), v2);
        expect(indice.fichasActivas, hasLength(1));
      },
    );

    test(
      'la misma revisión con otro contenido queda como divergente',
      () async {
        final base = historiaSintetica();
        Map<String, Object?> con(String texto) => sellarEvoluciones(base, [
          Evolucion(
            id: 'e1',
            fechaHora: DateTime(2026, 10, 9, 10),
            texto: texto,
          ).aMapa(),
        ]);
        await indice.registrarHistoria(
          con('Versión del consultorio.'),
          revision: 2,
          origen: OrigenArchivo.generado,
        );
        final r = await indice.registrarHistoria(
          con('Versión de otro equipo.'),
          revision: 2,
          origen: OrigenArchivo.importado,
          nombreArchivo: 'otro equipo.pdf',
        );
        expect(r.tipo, TipoRegistro.divergente);
        final h = indice.historia(r.historiaId)!;
        expect(h.divergente, isTrue);
        expect(h.divergencias.single.nombre, 'otro equipo.pdf');
        expect(h.evoluciones.single.resumen, 'Versión del consultorio.');
      },
    );

    test('el mismo documento escrito distinto va a la misma ficha', () async {
      await indice.registrarHistoria(
        historiaSintetica(),
        revision: 1,
        origen: OrigenArchivo.importado,
      );
      final r = await indice.registrarHistoria(
        historiaSintetica(
          id: 'otra-historia',
          numeroDocumento: '1.032.456.789',
          telefono: '311 000 0000',
          fecha: DateTime(2026, 11, 2, 8),
        ),
        revision: 1,
        origen: OrigenArchivo.importado,
      );
      expect(r.pacienteNuevo, isFalse);
      expect(indice.fichasActivas, hasLength(1));
      expect(indice.historiasDe(r.pacienteId).map((h) => h.id), [
        'otra-historia',
        '6f1c2b9e-0000-4000-8000-000000000001',
      ]);
      // Completa lo vacío, sin pisar lo que ya tenía.
      expect(indice.ficha(r.pacienteId)!.telefono, '300 123 4567');
    });

    test(
      'un paciente sin identificar (AS/MS) tiene una ficha por historia',
      () async {
        for (final id in ['h1', 'h2']) {
          await indice.registrarHistoria(
            historiaSintetica(
              id: id,
              tipoDocumento: 'AS',
              numeroDocumento: '1',
            ),
            revision: 1,
            origen: OrigenArchivo.importado,
          );
        }
        final claves = indice.fichasActivas.map((f) => f.clave).toSet();
        expect(claves, {'SIN:h1', 'SIN:h2'});
      },
    );

    test('el índice persiste cifrado y se recarga igual', () async {
      final r = await indice.registrarHistoria(
        historiaSintetica(),
        revision: 1,
        origen: OrigenArchivo.generado,
      );
      final otro = IndicePacientes(b.servicio.repositorio, reloj: b.reloj);
      await otro.cargar();
      expect(
        otro.ficha(r.pacienteId)!.aMapa(),
        indice.ficha(r.pacienteId)!.aMapa(),
      );
      expect(
        otro.historia(r.historiaId)!.aMapa(),
        indice.historia(r.historiaId)!.aMapa(),
      );
      otro.olvidar();
      expect(otro.cargado, isFalse);
      expect(otro.fichasActivas, isEmpty);
    });
  });

  group('Importar PDF', () {
    test(
      'informe por archivo: buena, alterada, ajena, no PDF y dañada',
      () async {
        final buena = await pdfCon(historiaSintetica());
        final alteradaDatos = historiaSintetica(
          id: 'h-alterada',
          numeroDocumento: '55',
        );
        (alteradaDatos['motivo']! as Map)['motivoConsulta'] =
            'Cambiado después de sellar';
        final alterada = await pdfCon(alteradaDatos);
        final ajeno =
            await (pw.Document()
                  ..addPage(pw.Page(build: (_) => pw.Text('Factura'))))
                .save();
        final noPdf = Uint8List.fromList(utf8.encode('hola'));
        final texto = latin1.decode(buena);
        final corte = texto.indexOf('"app":"historiasclinicas.net"');
        final truncado = Uint8List.sublistView(buena, 0, corte + 40);

        final avances = <int>[];
        final r = await indice.importarVarios([
          (nombre: 'buena.pdf', bytes: buena),
          (nombre: 'alterada.pdf', bytes: alterada),
          (nombre: 'factura.pdf', bytes: ajeno),
          (nombre: 'nota.txt', bytes: noPdf),
          (nombre: 'truncado.pdf', bytes: truncado),
          (nombre: 'buena (copia).pdf', bytes: buena),
        ], alAvanzar: (hechos, total) => avances.add(hechos));

        expect(avances, [1, 2, 3, 4, 5, 6]);
        expect(r.map((x) => x.tipo), [
          TipoImportacion.registrada,
          TipoImportacion.alterada,
          TipoImportacion.noEsDeLaApp,
          TipoImportacion.noEsDeLaApp,
          TipoImportacion.danada,
          TipoImportacion.registrada,
        ]);
        expect(r[1].mensaje, contains('Importada'));
        expect(r[1].registro!.integridadCorrecta, isFalse);
        expect(r[5].registro!.tipo, TipoRegistro.yaEstaba);
        expect(r.where((x) => x.importada), hasLength(3));

        // La alterada queda en el índice, marcada.
        final h = indice.historia('h-alterada')!;
        expect(h.integridadCorrecta, isFalse);
        expect(h.motivo, 'Cambiado después de sellar');

        final bitacora = await leerBitacora(b.servicio.repositorio);
        final importacion = bitacora.singleWhere(
          (e) => e.accion == AccionBitacora.importarPdf,
        );
        expect(importacion.resumen, '3 de 6 archivos');
      },
    );
  });

  group('Búsqueda y filtros', () {
    Future<void> poblar() async {
      final pacientes = [
        ('h1', '111', 'Peña', 'José Ángel', DateTime(2026, 11, 10)),
        ('h2', '222', 'Muñoz', 'María José', DateTime(2026, 6, 1)),
        ('h3', '333', 'Gómez', 'Andrés', DateTime(2025, 1, 15)),
      ];
      for (final (id, doc, ap, nom, fecha) in pacientes) {
        await indice.registrarHistoria(
          historiaSintetica(
            id: id,
            numeroDocumento: doc,
            primerApellido: ap,
            nombres: nom,
            fecha: fecha,
          ),
          revision: 1,
          origen: OrigenArchivo.importado,
        );
      }
    }

    List<String> nombres(List<ResumenPaciente> r) => [
      for (final x in r) x.ficha.nombres,
    ];

    test('sin tildes, en cualquier orden y por documento', () async {
      await poblar();
      expect(nombres(indice.buscar()), ['José Ángel', 'María José', 'Andrés']);
      expect(nombres(indice.buscar(texto: 'jose')), [
        'José Ángel',
        'María José',
      ]);
      expect(nombres(indice.buscar(texto: 'ANGEL pena')), ['José Ángel']);
      // Todos tienen «Muñoz» de segundo apellido.
      expect(nombres(indice.buscar(texto: 'munoz')), hasLength(3));
      expect(nombres(indice.buscar(texto: 'maria munoz')), ['María José']);
      expect(nombres(indice.buscar(texto: '22')), ['María José']);
      expect(nombres(indice.buscar(texto: 'gomez 333')), ['Andrés']);
      expect(indice.buscar(texto: 'zz'), isEmpty);
    });

    test('por línea, etiquetas y última atención', () async {
      await poblar();
      final jose = indice.buscar(texto: 'pena').single.ficha;
      await indice.guardarFicha(
        jose.copyWith(
          lineas: {LineaAtencion.peso},
          etiquetas: ['GLP-1', 'VIP'],
        ),
      );
      expect(nombres(indice.buscar(linea: LineaAtencion.peso)), ['José Ángel']);
      expect(indice.buscar(linea: LineaAtencion.estetica), isEmpty);
      expect(nombres(indice.buscar(etiquetas: {'GLP-1'})), ['José Ángel']);
      expect(indice.buscar(etiquetas: {'GLP-1', 'otra'}), isEmpty);
      expect(indice.etiquetasUsadas, ['GLP-1', 'VIP']);

      // Hoy es 21/11/2026 en el reloj de pruebas.
      expect(
        nombres(indice.buscar(ultimaAtencion: FiltroUltimaAtencion.ultimoMes)),
        ['José Ángel'],
      );
      expect(
        nombres(indice.buscar(ultimaAtencion: FiltroUltimaAtencion.ultimoAnio)),
        ['José Ángel', 'María José'],
      );
      expect(
        nombres(
          indice.buscar(ultimaAtencion: FiltroUltimaAtencion.masDeUnAnio),
        ),
        ['Andrés'],
      );
    });

    test('controles vencidos: la fecha pasó y no volvió', () async {
      await indice.registrarHistoria(
        historiaSintetica(
          id: 'vencido',
          numeroDocumento: '1',
          fecha: DateTime(2026, 10, 1),
          proximoControl: DateTime(2026, 11, 1),
        ),
        revision: 1,
        origen: OrigenArchivo.importado,
      );
      await indice.registrarHistoria(
        historiaSintetica(
          id: 'pendiente',
          numeroDocumento: '2',
          nombres: 'Lucía',
          fecha: DateTime(2026, 11, 1),
          proximoControl: DateTime(2026, 12, 1),
        ),
        revision: 1,
        origen: OrigenArchivo.importado,
      );
      // Volvió después de la fecha del control: ya no está vencido.
      await indice.registrarHistoria(
        historiaSintetica(
          id: 'volvio',
          numeroDocumento: '3',
          nombres: 'Rosa',
          fecha: DateTime(2026, 9, 1),
          proximoControl: DateTime(2026, 10, 1),
          evoluciones: [
            Evolucion(
              id: 'e1',
              fechaHora: DateTime(2026, 10, 3, 9),
              texto: 'Control.',
            ),
          ],
        ),
        revision: 2,
        origen: OrigenArchivo.importado,
      );
      final vencidos = indice.buscar(soloControlesVencidos: true);
      expect(vencidos.single.ficha.numeroDocumento, '1');
      expect(indice.controlesVencidos, 1);
      final pendiente = indice.buscar(texto: 'lucia').single;
      expect(pendiente.proximoControl, DateTime(2026, 12, 1));
      expect(pendiente.controlVencido(b.reloj.ahora()), isFalse);
    });
  });

  test(
    'un registro dañado o alterado no impide abrir el consultorio',
    () async {
      final r = await indice.registrarHistoria(
        historiaSintetica(),
        revision: 1,
        origen: OrigenArchivo.importado,
      );
      // Una ficha con un formato que el índice no entiende…
      await b.servicio.repositorio.guardar(FichaPaciente.coleccion, 'rara', {
        'nombre': 'sin clave ni fechas',
      });
      await b.servicio.repositorio.esperarEscrituras();
      // …y una historia con un byte cambiado (falla el descifrado autenticado).
      final registros = b.almacen.datos[Deposito.registros]!;
      final clave = RepositorioConsultorio.claveRegistro(
        RegistroHistoria.coleccion,
        r.historiaId,
      );
      final alterado = Uint8List.fromList(registros[clave]!);
      alterado[alterado.length - 1] ^= 1;
      registros[clave] = alterado;

      await b.servicio.bloquear();
      await b.servicio.desbloquear(fraseDePrueba);
      final i = b.servicio.indice;
      expect(i.cargado, isTrue);
      expect(
        i.registrosIlegibles,
        unorderedEquals(['pacientes/rara', 'historias/${r.historiaId}']),
      );
      expect(i.fichasActivas.single.id, r.pacienteId);
      expect(i.historia(r.historiaId), isNull);
    },
  );

  group('Fichas', () {
    test(
      'no se puede crear ni editar una ficha con un documento repetido',
      () async {
        final r = await indice.registrarHistoria(
          historiaSintetica(),
          revision: 1,
          origen: OrigenArchivo.importado,
        );
        final borrador = FichaPaciente(
          id: '',
          clave: '',
          creado: b.reloj.ahora(),
          actualizado: b.reloj.ahora(),
          tipoDocumento: 'CC',
          numeroDocumento: '1032456789',
        );
        expect(() => indice.crearFicha(borrador), throwsStateError);
        final otra = await indice.crearFicha(
          borrador.copyWith(numeroDocumento: '999', nombres: 'Otra'),
        );
        expect(otra.clave, 'CC:999');
        expect(
          () =>
              indice.guardarFicha(otra.copyWith(numeroDocumento: '1032456789')),
          throwsStateError,
        );
        expect(indice.ficha(r.pacienteId)!.clave, 'CC:1032456789');

        final sinDoc = await indice.crearFicha(
          borrador.copyWith(tipoDocumento: '', numeroDocumento: ''),
        );
        expect(sinDoc.clave, 'SIN:${sinDoc.id}');
      },
    );

    test('unir fichas mueve las historias y deja la origen marcada', () async {
      final a = await indice.registrarHistoria(
        historiaSintetica(
          id: 'h-as',
          tipoDocumento: 'AS',
          numeroDocumento: '7',
        ),
        revision: 1,
        origen: OrigenArchivo.importado,
      );
      final c = await indice.registrarHistoria(
        historiaSintetica(id: 'h-cc', fecha: DateTime(2026, 11, 5)),
        revision: 1,
        origen: OrigenArchivo.importado,
      );
      final origen = indice.ficha(a.pacienteId)!;
      await indice.guardarFicha(
        origen.copyWith(
          lineas: {LineaAtencion.estetica},
          etiquetas: ['Hidrolipoclasia'],
          notas: 'Llegó sin documento.',
        ),
      );

      await indice.unirFichas(a.pacienteId, c.pacienteId);

      expect(indice.fichasActivas.map((f) => f.id), [c.pacienteId]);
      expect(indice.ficha(a.pacienteId)!.unidaEn, c.pacienteId);
      final destino = indice.ficha(c.pacienteId)!;
      expect(destino.lineas, {LineaAtencion.estetica});
      expect(destino.etiquetas, ['Hidrolipoclasia']);
      expect(destino.notas, 'Llegó sin documento.');
      expect(indice.historiasDe(c.pacienteId).map((h) => h.id), [
        'h-cc',
        'h-as',
      ]);
      expect(indice.historiasDe(a.pacienteId), isEmpty);

      // Una nueva revisión de la historia movida sigue en la ficha destino.
      final datos = await indice.datosDe('h-as');
      final r = await indice.registrarHistoria(
        sellarEvoluciones(datos!, [
          Evolucion(
            id: 'e1',
            fechaHora: DateTime(2026, 11, 20, 9),
            texto: 'Control.',
          ).aMapa(),
        ]),
        revision: 2,
        origen: OrigenArchivo.generado,
      );
      expect(r.pacienteId, c.pacienteId);

      final bitacora = await leerBitacora(b.servicio.repositorio);
      expect(
        bitacora
            .singleWhere((e) => e.accion == AccionBitacora.unirFichas)
            .resumen,
        '1 historia movida',
      );
    });

    test('alergias vigentes: la última evolución que las actualizó', () async {
      final r = await indice.registrarHistoria(
        historiaSintetica(
          evoluciones: [
            Evolucion(
              id: 'e1',
              fechaHora: DateTime(2026, 10, 9, 10),
              texto:
                  'Control.\n$prefijoAlergiasActualizadas Penicilina, '
                  'látex.',
            ),
          ],
        ),
        revision: 2,
        origen: OrigenArchivo.importado,
      );
      final a = indice.alergiasDe(r.pacienteId)!;
      expect(a.alergias, ['Penicilina', 'látex']);
      expect(a.niega, isFalse);
      expect(a.desde, DateTime(2026, 10, 9, 10));

      // Una historia posterior sin actualización manda con sus alergias.
      await indice.registrarHistoria(
        historiaSintetica(id: 'posterior', fecha: DateTime(2026, 11, 2)),
        revision: 1,
        origen: OrigenArchivo.importado,
      );
      expect(indice.alergiasDe(r.pacienteId)!.alergias, [
        'Penicilina',
        'AINEs',
      ]);
    });
  });

  test('rendimiento con 5.000 pacientes sintéticos', () async {
    const n = 5000;
    final repo = b.servicio.repositorio;
    final modelo = historiaSintetica();
    final ahora = b.reloj.ahora();
    final escrituras = <Escritura>[];
    final apellidos = ['Peña', 'Muñoz', 'Gómez', 'Díaz', 'Ríos', 'Castaño'];
    final nombresPila = ['José', 'María', 'Andrés', 'Lucía', 'Ángel', 'Sofía'];
    for (var i = 0; i < n; i++) {
      final ficha = FichaPaciente(
        id: 'p$i',
        clave: 'CC:${1000000 + i}',
        creado: ahora,
        actualizado: ahora,
        tipoDocumento: 'CC',
        numeroDocumento: '${1000000 + i}',
        primerApellido: apellidos[i % apellidos.length],
        segundoApellido: apellidos[(i ~/ 6) % apellidos.length],
        nombres: '${nombresPila[i % 5]} ${nombresPila[(i ~/ 5) % 6]}',
        lineas: {LineaAtencion.values[i % 3]},
      );
      final registro = RegistroHistoria.desdeDatos(
        modelo,
        pacienteId: ficha.id,
        revision: 1,
        ahora: ahora,
      );
      escrituras
        ..add(Escritura(FichaPaciente.coleccion, ficha.id, ficha.aMapa()))
        ..add(Escritura(RegistroHistoria.coleccion, 'h$i', registro.aMapa()));
    }
    for (var i = 0; i < escrituras.length; i += 1000) {
      await repo.guardarVarios(escrituras.sublist(i, i + 1000));
    }

    final reloj = Stopwatch()..start();
    final nuevo = IndicePacientes(repo, reloj: b.reloj);
    await nuevo.cargar();
    final tCarga = reloj.elapsedMilliseconds;
    expect(nuevo.fichasActivas, hasLength(n));

    reloj.reset();
    final consultas = ['jose', 'pena munoz', '1004', 'sofia diaz', 'zz'];
    for (final q in consultas) {
      nuevo.buscar(texto: q);
    }
    final todos = nuevo.buscar(linea: LineaAtencion.peso);
    final tBusqueda = reloj.elapsedMilliseconds / (consultas.length + 1);
    expect(todos, hasLength(n ~/ 3 + (n % 3 > 1 ? 1 : 0)));

    // ignore: avoid_print
    print(
      'Índice con $n pacientes (AES en Dart, VM): carga ${tCarga}ms, '
      'búsqueda ${tBusqueda.toStringAsFixed(1)}ms por consulta',
    );
    expect(tBusqueda, lessThan(250));
  });
}
