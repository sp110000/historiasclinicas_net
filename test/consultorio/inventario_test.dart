import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/inventario/insumo.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/ficha_paciente.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/medicion.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/procedimientos.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/sesion.dart';
import 'package:historiasclinicas_net/core/consultorio/reglas/inventario.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';

import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';
import 'ayudas_procedimientos.dart';

// Sábado 21/11/2026 (el reloj de BancoConsultorio).
final _hoy = DateTime(2026, 11, 21);

Insumo _insumo({
  String id = 'i1',
  String nombre = 'Anestésico de prueba',
  String registro = 'INVIMA PRUEBA-0001',
  bool inyectable = true,
  double minimo = 0,
  bool activo = true,
  double? contenidoMl = 5,
}) => Insumo(
  id: id,
  nombre: nombre,
  categoria: CategoriaInsumo.medicamento,
  unidad: 'ampolla',
  contenidoMl: contenidoMl,
  registroInvima: registro,
  inyectable: inyectable,
  stockMinimo: minimo,
  activo: activo,
  creado: _hoy,
);

Lote _lote(String id, DateTime vence, {String insumoId = 'i1'}) => Lote(
  id: id,
  insumoId: insumoId,
  numero: id.toUpperCase(),
  vence: vence,
  ingreso: DateTime(2026, 11, 1),
);

Movimiento _mov(String lote, TipoMovimiento tipo, double cantidad) =>
    Movimiento(
      id: '$lote$tipo$cantidad',
      loteId: lote,
      insumoId: 'i1',
      tipo: tipo,
      cantidad: cantidad,
      fecha: _hoy,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Existencias por movimientos (por tabla)', () {
    final casos = <(String, List<Movimiento>, double)>[
      ('solo una entrada', [_mov('l1', TipoMovimiento.entrada, 10)], 10),
      (
        'entrada y salida de una sesión',
        [
          _mov('l1', TipoMovimiento.entrada, 10),
          _mov('l1', TipoMovimiento.salida, -2),
        ],
        8,
      ),
      (
        'dos entradas, una salida y un ajuste negativo',
        [
          _mov('l1', TipoMovimiento.entrada, 10),
          _mov('l1', TipoMovimiento.entrada, 5),
          _mov('l1', TipoMovimiento.salida, -3),
          _mov('l1', TipoMovimiento.ajuste, -1),
        ],
        11,
      ),
      (
        'ajuste positivo por conteo',
        [
          _mov('l1', TipoMovimiento.entrada, 4),
          _mov('l1', TipoMovimiento.ajuste, 2),
        ],
        6,
      ),
      (
        'baja de todo',
        [
          _mov('l1', TipoMovimiento.entrada, 4),
          _mov('l1', TipoMovimiento.baja, -4),
        ],
        0,
      ),
      (
        'los de otro lote no cuentan',
        [
          _mov('l1', TipoMovimiento.entrada, 4),
          _mov('l2', TipoMovimiento.entrada, 7),
        ],
        4,
      ),
    ];
    for (final (caso, movs, esperado) in casos) {
      test(caso, () => expect(existencias(movs)['l1'], esperado));
    }
  });

  group('Estado del lote (por tabla)', () {
    final casos = <(String, DateTime, double, EstadoLote)>[
      ('vigente', DateTime(2027, 6, 30), 5, EstadoLote.vigente),
      ('vence en 31 días', DateTime(2026, 12, 22), 5, EstadoLote.vigente),
      ('vence en 30 días', DateTime(2026, 12, 21), 5, EstadoLote.porVencer),
      ('vence hoy (todavía sirve)', _hoy, 5, EstadoLote.porVencer),
      ('venció ayer', DateTime(2026, 11, 20), 5, EstadoLote.vencido),
      (
        'vencido y sin existencias',
        DateTime(2026, 11, 1),
        0,
        EstadoLote.vencido,
      ),
      ('agotado', DateTime(2027, 6, 30), 0, EstadoLote.agotado),
    ];
    for (final (caso, vence, existencia, esperado) in casos) {
      test(
        caso,
        () => expect(estadoLote(_lote('l', vence), existencia, _hoy), esperado),
      );
    }
  });

  test('el que vence primero, primero; sin vencidos ni agotados', () {
    final lotes = [
      _lote('c', DateTime(2027, 6, 30)),
      _lote('a', DateTime(2026, 11, 20)), // vencido
      _lote('b', DateTime(2026, 12, 15)),
      _lote('d', DateTime(2026, 12, 1)), // agotado
    ];
    final e = {'a': 3.0, 'b': 2.0, 'c': 10.0, 'd': 0.0};
    expect(ordenFefo(lotes).map((l) => l.id), ['a', 'd', 'b', 'c']);
    expect(lotesDisponibles(lotes, e, _hoy).map((l) => l.id), ['b', 'c']);
  });

  group('Entrada (por tabla)', () {
    final casos =
        <
          (String, Insumo?, String, DateTime?, double?, Lote?, String?, String?)
        >[
          (
            'sin insumo',
            null,
            'L1',
            DateTime(2027),
            5,
            null,
            'Elige el insumo.',
            null,
          ),
          (
            'sin número de lote',
            _insumo(),
            ' ',
            DateTime(2027),
            5,
            null,
            'Escribe el número de lote.',
            null,
          ),
          (
            'sin vencimiento',
            _insumo(),
            'L1',
            null,
            5,
            null,
            'Escribe el vencimiento.',
            null,
          ),
          (
            'cantidad en cero',
            _insumo(),
            'L1',
            DateTime(2027),
            0,
            null,
            'La cantidad tiene que ser mayor que 0.',
            null,
          ),
          (
            'lote vencido',
            _insumo(),
            'L1',
            DateTime(2026, 11, 1),
            5,
            null,
            'El lote L1 venció el 01/11/2026: no se ingresa.',
            null,
          ),
          (
            'mismo número con otro vencimiento',
            _insumo(),
            'L1',
            DateTime(2027, 2, 1),
            5,
            _lote('l1', DateTime(2027, 1, 1)),
            'El lote L1 ya está con otro vencimiento (01/01/2027).',
            null,
          ),
          (
            'vence en 10 días: avisa',
            _insumo(),
            'L1',
            DateTime(2026, 12, 1),
            5,
            null,
            null,
            'Vence en 10 días.',
          ),
          (
            'inyectable sin registro Invima: avisa',
            _insumo(registro: ''),
            'L1',
            DateTime(2027),
            5,
            null,
            null,
            '«Anestésico de prueba» es inyectable y no tiene registro Invima',
          ),
          (
            'mismo número y vencimiento: suma al lote',
            _insumo(),
            'L1',
            DateTime(2027, 1, 1),
            5,
            _lote('l1', DateTime(2027, 1, 1)),
            null,
            null,
          ),
        ];
    for (final (caso, insumo, numero, vence, cantidad, mismo, bloqueo, aviso)
        in casos) {
      test(caso, () {
        final e = evaluarEntrada(
          insumo: insumo,
          numero: numero,
          vence: vence,
          cantidad: cantidad,
          hoy: _hoy,
          mismoNumero: mismo,
        );
        if (bloqueo == null) {
          expect(e.bloqueos, isEmpty);
        } else {
          expect(e.bloqueos, contains(bloqueo));
        }
        if (aviso == null) {
          expect(e.avisos, isEmpty);
        } else {
          expect(e.avisos.join('\n'), contains(aviso));
        }
      });
    }
  });

  test('aviso sin registro Invima: más fuerte en los inyectables', () {
    expect(avisoInvima(_insumo()), isNull);
    expect(
      avisoInvima(_insumo(registro: '')),
      '«Anestésico de prueba» es inyectable y no tiene registro Invima: '
      'verifícalo antes de usarlo.',
    );
    expect(
      avisoInvima(_insumo(nombre: 'Gasa', registro: '', inyectable: false)),
      '«Gasa» no tiene registro Invima.',
    );
  });

  test('cantidades con su unidad', () {
    expect(cantidadTexto(1, 'ampolla'), '1 ampolla');
    expect(cantidadTexto(3, 'ampolla'), '3 ampollas');
    expect(cantidadTexto(2, 'unidad'), '2 unidades');
    expect(cantidadTexto(2, 'frasco'), '2 frascos');
    expect(cantidadTexto(2.5, 'frasco'), '2,5 frascos');
  });

  group('Unidades del anestésico', () {
    const a = AnestesicoSesion(
      nombre: 'Anestésico de prueba',
      concentracionMgMl: 20,
      maximoMgKg: 7,
    );
    final casos = <(String, AnestesicoSesion, Insumo?, double)>[
      ('10 mL en ampollas de 5 mL', a.copyWith(volumenMl: 10.0), _insumo(), 2),
      ('11 mL: una ampolla más', a.copyWith(volumenMl: 11.0), _insumo(), 3),
      (
        'sin contenido por unidad',
        a.copyWith(volumenMl: 10.0),
        _insumo(contenidoMl: null),
        1,
      ),
      ('sin volumen', a, _insumo(), 1),
      (
        'escritas a mano',
        a.copyWith(
          volumenMl: 10.0,
          lote: const LoteSesion(lote: 'L', unidades: 4),
        ),
        _insumo(),
        4,
      ),
    ];
    for (final (caso, x, insumo, esperado) in casos) {
      test(caso, () => expect(unidadesAnestesico(x, insumo), esperado));
    }
  });

  group('Inventario en la sesión (por tabla)', () {
    final insumos = {
      'i1': _insumo(),
      'i2': _insumo(
        id: 'i2',
        nombre: 'Componente A de prueba',
        registro: '',
        inyectable: false,
      ),
    };
    final lotes = {
      'la': _lote('la', DateTime(2027, 1, 1)),
      'lc': _lote('lc', DateTime(2027, 1, 1), insumoId: 'i2'),
    };
    final hay = {'la': 2.0, 'lc': 1.0};
    LoteSesion del(String id, {double? unidades}) => LoteSesion(
      lote: lotes[id]!.numero,
      vence: lotes[id]!.vence,
      loteId: id,
      unidades: unidades,
    );
    EvaluacionInventario evaluar(List<LineaInventario> lineas) =>
        evaluarInventarioSesion(
          lineas: lineas,
          lotes: lotes,
          insumos: insumos,
          existencias: hay,
          insumoPorNombre: (n) => insumos.values
              .where((i) => claveNombre(i.nombre) == claveNombre(n))
              .firstOrNull,
        );
    final casos = <(String, List<LineaInventario>, String?, String?)>[
      (
        'alcanza',
        [(nombre: 'Anestésico de prueba', lote: del('la'), unidades: 2)],
        null,
        null,
      ),
      (
        'no alcanza',
        [(nombre: 'Anestésico de prueba', lote: del('la'), unidades: 3)],
        'El lote LA de «Anestésico de prueba» tiene 2 ampollas; la sesión '
            'usa 3 ampollas.',
        null,
      ),
      (
        'dos líneas del mismo lote suman',
        [
          (nombre: 'Anestésico de prueba', lote: del('la'), unidades: 1),
          (nombre: 'Anestésico de prueba', lote: del('la'), unidades: 2),
        ],
        'tiene 2 ampollas; la sesión usa 3 ampollas.',
        null,
      ),
      (
        'lote que ya no está',
        [
          (
            nombre: 'Anestésico de prueba',
            lote: const LoteSesion(lote: 'LX', loteId: 'otro'),
            unidades: 1,
          ),
        ],
        'El lote LX de «Anestésico de prueba» ya no está en el inventario',
        null,
      ),
      (
        'unidades en cero',
        [(nombre: 'Anestésico de prueba', lote: del('la'), unidades: 0)],
        'Escribe las unidades que se usan de «Anestésico de prueba».',
        null,
      ),
      (
        'del inventario sin registro Invima: avisa',
        [(nombre: 'Componente A de prueba', lote: del('lc'), unidades: 1)],
        null,
        '«Componente A de prueba» no tiene registro Invima.',
      ),
      (
        'escrito a mano estando en el inventario: avisa',
        [
          (
            nombre: 'anestesico de prueba',
            lote: LoteSesion(lote: 'L9', vence: DateTime(2027)),
            unidades: 1,
          ),
        ],
        null,
        'está en el inventario, pero su lote se escribió a mano',
      ),
      (
        'escrito a mano y fuera del inventario: nada',
        [
          (
            nombre: 'Componente B de prueba',
            lote: LoteSesion(lote: 'C9', vence: DateTime(2027)),
            unidades: 1,
          ),
        ],
        null,
        null,
      ),
    ];
    for (final (caso, lineas, bloqueo, aviso) in casos) {
      test(caso, () {
        final e = evaluar(lineas);
        if (bloqueo == null) {
          expect(e.bloqueos, isEmpty);
        } else {
          expect(e.bloqueos.join('\n'), contains(bloqueo));
        }
        if (aviso == null) {
          expect(e.avisos, isEmpty);
        } else {
          expect(e.avisos.join('\n'), contains(aviso));
        }
      });
    }
  });

  test('alertas: bajo mínimo, por vencer, vencidos con existencia y sin '
      'registro', () {
    final insumos = [
      _insumo(minimo: 10),
      _insumo(id: 'i2', nombre: 'Jeringa', registro: '', inyectable: false),
      _insumo(id: 'i3', nombre: 'Viejo', registro: '', activo: false),
    ];
    final lotes = [
      _lote('a', DateTime(2026, 11, 20)), // vencido con 5
      _lote('b', DateTime(2026, 12, 10)), // vence en 19 días, 4
      _lote('c', DateTime(2027, 6, 30)), // 3
      _lote('d', DateTime(2026, 12, 1), insumoId: 'i2'), // agotado
    ];
    final a = alertasInventario(
      insumos: insumos,
      lotes: lotes,
      existencias: {'a': 5, 'b': 4, 'c': 3, 'd': 0},
      hoy: _hoy,
    );
    // Lo vencido no cuenta para el mínimo: 4 + 3 < 10.
    expect(a.bajoMinimo.map((i) => i.id), ['i1']);
    expect(a.porVencer.map((l) => l.id), ['b']);
    expect(a.vencidos.map((l) => l.id), ['a']);
    expect(a.sinRegistro.map((i) => i.id), ['i2']);
    expect(a.total, 4);
  });

  group('En el consultorio', () {
    late BancoConsultorio b;
    late String id;
    late FuentesPdf fuentes;

    setUpAll(() async => fuentes = await FuentesPdf.cargar());

    setUp(() async {
      b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      final r = await b.servicio.registrarHistoria(
        HistoriaPendiente(
          datos: historiaSintetica(),
          revision: 1,
          origen: OrigenArchivo.importado,
        ),
      );
      id = r!.pacienteId;
    });

    Future<Insumo> anestesico() => b.servicio.inventario.guardarInsumo(
      b.servicio.inventario.nuevoInsumo().copyWith(
        nombre: 'Anestésico de prueba',
        unidad: 'ampolla',
        presentacion: 'Ampolla de 5 mL',
        contenidoMl: 5.0,
        concentracionMgMl: 20.0,
        registroInvima: 'INVIMA PRUEBA-0001',
        inyectable: true,
        stockMinimo: 3,
      ),
    );

    test('insumos, entradas, ajuste y baja; cifrado y al reabrir', () async {
      final inv = b.servicio.inventario;
      expect(inv.vacio, isTrue);
      final i = await anestesico();
      await expectLater(
        inv.guardarInsumo(
          inv.nuevoInsumo().copyWith(nombre: 'ANESTESICO de prueba'),
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'm', contains('Ya hay')),
        ),
      );
      final viejo = await inv.registrarEntrada(
        insumoId: i.id,
        numero: 'l-a',
        vence: DateTime(2026, 12, 15),
        cantidad: 2,
      );
      expect(viejo.numero, 'L-A');
      final nuevo = await inv.registrarEntrada(
        insumoId: i.id,
        numero: 'L-B',
        vence: DateTime(2027, 6, 30),
        cantidad: 10,
        proveedor: 'Proveedor de prueba',
        factura: 'F-1',
      );
      // El mismo número y vencimiento suma al lote.
      final otraVez = await inv.registrarEntrada(
        insumoId: i.id,
        numero: 'L-A',
        vence: DateTime(2026, 12, 15),
        cantidad: 1,
      );
      expect(otraVez.id, viejo.id);
      expect(inv.existencia(viejo.id), 3);
      await expectLater(
        inv.registrarEntrada(
          insumoId: i.id,
          numero: 'L-C',
          vence: DateTime(2026, 11, 1),
          cantidad: 1,
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'm', contains('venció')),
        ),
      );
      expect(inv.sugerido(i.id)!.id, viejo.id);
      expect(inv.existenciaVigente(i.id), 13);
      expect(inv.estado(viejo), EstadoLote.porVencer);
      expect(inv.alertas().porVencer.single.id, viejo.id);

      await inv.ajustar(nuevo.id, -1, motivo: 'Ampolla rota');
      await expectLater(
        inv.ajustar(nuevo.id, -20, motivo: 'x'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        inv.ajustar(nuevo.id, 1, motivo: ' '),
        throwsA(isA<StateError>()),
      );
      expect(inv.existencia(nuevo.id), 9);

      // Al vencer, el lote viejo deja de sugerirse y se da de baja.
      b.reloj.fijar(DateTime(2026, 12, 16, 8));
      expect(inv.sugerido(i.id)!.id, nuevo.id);
      expect(inv.alertas().vencidos.single.id, viejo.id);
      await inv.darDeBaja(viejo.id, motivo: 'Vencido');
      expect(inv.existencia(viejo.id), 0);
      expect(inv.alertas().vencidos, isEmpty);
      expect(
        inv.movimientosDe(i.id).map((m) => (m.tipo, m.cantidad)).toList(),
        containsAll([
          (TipoMovimiento.entrada, 2.0),
          (TipoMovimiento.entrada, 10.0),
          (TipoMovimiento.ajuste, -1.0),
          (TipoMovimiento.baja, -3.0),
        ]),
      );

      expect(contieneTexto(b.todosLosBytes, 'PRUEBA-0001'), isFalse);
      expect(contieneTexto(b.todosLosBytes, 'Anest'), isFalse);
      await b.servicio.bloquear();
      expect(inv.vacio, isTrue);
      await b.servicio.desbloquear(fraseDePrueba);
      expect(inv.insumos.single.nombre, 'Anestésico de prueba');
      expect(inv.existencia(nuevo.id), 9);
      expect(inv.lote(nuevo.id)!.proveedor, 'Proveedor de prueba');
      final acciones = (await leerBitacora(
        b.servicio.repositorio,
      )).map((e) => e.accion).toSet();
      expect(
        acciones,
        containsAll([
          AccionBitacora.guardarInsumo,
          AccionBitacora.entradaInventario,
          AccionBitacora.ajusteInventario,
          AccionBitacora.bajaInventario,
        ]),
      );
    });

    group('Sesión', () {
      late ProcedimientosConsultorio p;
      late FichaPaciente ficha;
      late Insumo i;
      late Lote viejo;
      late Lote nuevo;

      setUp(() async {
        await b.servicio.seguimiento.guardarMedicion(
          Medicion(
            id: '',
            pacienteId: id,
            fecha: DateTime(2026, 11, 20, 9),
            creado: DateTime(2026, 11, 20, 9),
            peso: 64,
          ),
        );
        await aprobarHidrolipoclasia(b);
        await valorarAptoDePrueba(b, id);
        await consentimientoDePrueba(b, id);
        p = b.servicio.procedimientos;
        ficha = b.servicio.indice.ficha(id)!;
        i = await anestesico();
        viejo = await b.servicio.inventario.registrarEntrada(
          insumoId: i.id,
          numero: 'L-A',
          vence: DateTime(2026, 12, 15),
          cantidad: 2,
        );
        nuevo = await b.servicio.inventario.registrarEntrada(
          insumoId: i.id,
          numero: 'L-B',
          vence: DateTime(2027, 6, 30),
          cantidad: 10,
        );
      });

      /// Completa lo demás sin tocar el lote del anestésico.
      Sesion completar(Sesion s, {double volumen = 10}) => s.copyWith(
        verificacion: {for (final k in s.verificacion.keys) k: true},
        zonas: const [ZonaSesion(zona: 'Abdomen inferior', volumenMl: 300)],
        componentes: [
          for (final c in s.componentes)
            ComponenteSesion(
              nombre: c.nombre,
              lote: LoteSesion(lote: 'C-1', vence: DateTime(2027, 3, 31)),
            ),
        ],
        anestesico: s.anestesico!.copyWith(volumenMl: volumen),
        duracionMin: 45,
      );

      test(
        'sugiere el lote que vence primero y lo descuenta al sellar',
        () async {
          final borrador = p.nuevaSesion(ficha, 'hidrolipoclasia');
          expect(borrador.anestesico!.lote.loteId, viejo.id);
          expect(borrador.anestesico!.lote.lote, 'L-A');
          expect(borrador.anestesico!.lote.vence, DateTime(2026, 12, 15));
          // Los componentes no están en el inventario: se escriben a mano.
          expect(
            borrador.componentes.every((c) => !c.lote.delInventario),
            isTrue,
          );

          // 15 mL son 3 ampollas: el lote L-A solo tiene 2.
          final mucho = completar(borrador, volumen: 15);
          expect(
            p.evaluar(mucho, ficha).bloqueos,
            contains(
              'El lote L-A de «Anestésico de prueba» tiene 2 ampollas; la '
              'sesión usa 3 ampollas.',
            ),
          );
          await expectLater(
            p.sellarSesion(
              mucho,
              ficha,
              medico: medicoCompleto(),
              pais: Pais.colombia,
              fuentes: fuentes,
            ),
            throwsA(isA<StateError>()),
          );
          expect(b.servicio.inventario.existencia(viejo.id), 2);

          final lista = completar(borrador);
          final e = p.evaluar(lista, ficha);
          expect(e.bloqueos, isEmpty, reason: '${e.bloqueos}');
          final (sesion, sellada) = await p.sellarSesion(
            lista,
            ficha,
            medico: medicoCompleto(),
            pais: Pais.colombia,
            fuentes: fuentes,
          );
          expect(sellada.revision, 3);
          final inv = b.servicio.inventario;
          expect(inv.existencia(viejo.id), 0);
          expect(inv.existencia(nuevo.id), 10);
          final salida = inv
              .movimientosDe(i.id)
              .singleWhere((m) => m.tipo == TipoMovimiento.salida);
          expect(salida.cantidad, -2);
          expect(salida.loteId, viejo.id);
          expect(salida.sesionId, sesion.id);
          expect(salida.motivo, 'Sesión 1 de 4: Anestésico de prueba');
          expect(
            textoSesion(
              sesion,
              p.vigente('hidrolipoclasia').definicion,
              version: 1,
            ),
            contains(
              'Anestésico de prueba 20 mg/mL, 10 mL (lote L-A, vence 15/12/2026)',
            ),
          );
          // La sesión guardada conserva el enlace (al reabrir también).
          await b.servicio.bloquear();
          await b.servicio.desbloquear(fraseDePrueba);
          expect(
            b.servicio.procedimientos
                .sesionesDe(id)
                .single
                .anestesico!
                .lote
                .loteId,
            viejo.id,
          );
          expect(b.servicio.inventario.existencia(viejo.id), 0);
          // Agotado el L-A, la sesión siguiente sugiere el L-B.
          final segunda = b.servicio.procedimientos.nuevaSesion(
            b.servicio.indice.ficha(id)!,
            'hidrolipoclasia',
          );
          expect(segunda.anestesico!.lote.loteId, nuevo.id);
          expect(
            (await leerBitacora(b.servicio.repositorio)).map((e) => e.accion),
            contains(AccionBitacora.salidaInventario),
          );
        },
      );

      test('un lote vencido del inventario bloquea', () async {
        b.reloj.fijar(DateTime(2026, 12, 16, 9));
        final borrador = p.nuevaSesion(ficha, 'hidrolipoclasia');
        // El vencido ya no se sugiere.
        expect(borrador.anestesico!.lote.loteId, nuevo.id);
        final conVencido = completar(borrador).copyWith(
          anestesico: completar(
            borrador,
          ).anestesico!.copyWith(lote: b.servicio.inventario.loteSesion(viejo)),
        );
        expect(
          p.evaluar(conVencido, ficha).bloqueos,
          contains(
            'El lote L-A de «Anestésico de prueba» venció el 15/12/2026.',
          ),
        );
      });

      test(
        'escrito a mano estando en el inventario: avisa y no descuenta',
        () async {
          final borrador = p.nuevaSesion(ficha, 'hidrolipoclasia');
          final aMano = completar(borrador).copyWith(
            anestesico: completar(borrador).anestesico!.copyWith(
              lote: LoteSesion(lote: 'L9', vence: DateTime(2027, 3, 31)),
            ),
          );
          final e = p.evaluar(aMano, ficha);
          expect(e.bloqueos, isEmpty);
          expect(
            e.avisos.join('\n'),
            contains(
              '«Anestésico de prueba» está en el inventario, pero su lote se '
              'escribió a mano: no se descontará.',
            ),
          );
          await p.sellarSesion(
            aMano,
            ficha,
            medico: medicoCompleto(),
            pais: Pais.colombia,
            fuentes: fuentes,
          );
          expect(b.servicio.inventario.existencia(viejo.id), 2);
          expect(
            b.servicio.inventario
                .movimientosDe(i.id)
                .where((m) => m.tipo == TipoMovimiento.salida),
            isEmpty,
          );
        },
      );
    });
  });
}
