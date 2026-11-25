import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/caja/catalogo.dart';
import 'package:historiasclinicas_net/core/consultorio/caja/movimientos.dart';
import 'package:historiasclinicas_net/core/consultorio/inventario/insumo.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/reglas/inventario.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';

import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

// Sábado 21/11/2026 (el reloj de BancoConsultorio).
final _hoy = DateTime(2026, 11, 21);

final _insumo = Insumo(
  id: 'i1',
  nombre: 'Jeringa de prueba',
  categoria: CategoriaInsumo.dispositivo,
  unidad: 'unidad',
  registroInvima: 'INVIMA PRUEBA-0002',
  creado: _hoy,
);

final _sinRegistro = Insumo(
  id: 'i2',
  nombre: 'Vitamina de prueba',
  categoria: CategoriaInsumo.medicamento,
  unidad: 'ampolla',
  inyectable: true,
  creado: _hoy,
);

Lote _lote(String id, DateTime vence, {String insumoId = 'i1'}) => Lote(
  id: id,
  insumoId: insumoId,
  numero: id.toUpperCase(),
  vence: vence,
  ingreso: DateTime(2026, 11, 1),
);

InsumoCobro _linea(String loteId, double cantidad, {String nombre = 'J'}) =>
    InsumoCobro(
      insumoId: 'i1',
      loteId: loteId,
      nombre: nombre,
      lote: loteId.toUpperCase(),
      unidad: 'unidad',
      cantidad: cantidad,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Insumos del cobro (por tabla)', () {
    final lotes = {
      'l1': _lote('l1', DateTime(2027, 6, 30)),
      'lv': _lote('lv', DateTime(2026, 11, 20)),
      'l0': _lote('l0', DateTime(2027, 6, 30)),
      'l2': _lote('l2', DateTime(2027, 6, 30), insumoId: 'i2'),
    };
    final insumos = {'i1': _insumo, 'i2': _sinRegistro};
    const existencias = {'l1': 3.0, 'lv': 5.0, 'l0': 0.0, 'l2': 4.0};
    final casos = <(String, List<InsumoCobro>, List<String>, List<String>)>[
      ('alcanza', [_linea('l1', 2)], [], []),
      ('toda la existencia', [_linea('l1', 3)], [], []),
      (
        'dos líneas del mismo lote se suman',
        [_linea('l1', 2), _linea('l1', 2)],
        [
          'El lote L1 de «Jeringa de prueba» tiene 3 unidades; el cobro usa 4 '
              'unidades.',
        ],
        [],
      ),
      (
        'sin existencias',
        [_linea('l0', 1)],
        ['El lote L0 de «Jeringa de prueba» no tiene existencias.'],
        [],
      ),
      (
        'lote vencido',
        [_linea('lv', 1)],
        [
          'El lote LV de «Jeringa de prueba» venció el 20/11/2026: elige '
              'otro.',
        ],
        [],
      ),
      (
        'cantidad en 0',
        [_linea('l1', 0)],
        ['Escribe cuánto se usó de «Jeringa de prueba».'],
        [],
      ),
      (
        'lote que ya no está',
        [_linea('borrado', 1, nombre: 'Gasa')],
        ['El lote BORRADO de «Gasa» ya no está en el inventario: elige otro.'],
        [],
      ),
      (
        'sin registro Invima: avisa',
        [_linea('l2', 1)],
        [],
        [
          '«Vitamina de prueba» es inyectable y no tiene registro Invima: '
              'verifícalo antes de usarlo.',
        ],
      ),
    ];
    for (final (caso, lineas, bloqueos, avisos) in casos) {
      test(caso, () {
        final e = evaluarInsumosCobro(
          lineas: lineas,
          lotes: lotes,
          insumos: insumos,
          existencias: existencias,
          hoy: _hoy,
        );
        expect(e.bloqueos, bloqueos);
        expect(e.avisos, avisos);
      });
    }
  });

  test('el cobro guarda sus insumos; uno viejo, sin ellos, se lee igual', () {
    final c = Cobro(
      id: 'c1',
      pacienteId: 'p1',
      fecha: DateTime(2026, 11, 21, 10),
      items: const [
        ItemCobro(servicioId: 's', descripcion: 'Consulta', valorUnitario: 1),
      ],
      insumos: [_linea('l1', 1.5)],
    );
    final leido = Cobro.desdeMapa('c1', c.aMapa());
    expect(leido.insumos.single.cantidad, 1.5);
    expect(leido.insumos.single.lote, 'L1');
    expect(leido.anular('x', DateTime(2026, 11, 21)).insumos, hasLength(1));
    final viejo = c.aMapa()..remove('insumos');
    expect(Cobro.desdeMapa('c1', viejo).insumos, isEmpty);
    expect(
      Cobro(
        id: 'c2',
        pacienteId: 'p1',
        fecha: DateTime(2026, 11, 21),
        items: const [],
      ).aMapa().containsKey('insumos'),
      isFalse,
    );
  });

  group('En el consultorio', () {
    late BancoConsultorio b;
    late String paciente;
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
      paciente = r!.pacienteId;
    });

    ItemCobro consulta() {
      final s = b.servicio.caja.serviciosPorId['consulta_primera_vez']!;
      return ItemCobro(
        servicioId: s.id,
        descripcion: s.nombre,
        valorUnitario: s.tarifa,
      );
    }

    test('cobrar descuenta los insumos del lote que vence primero; sin '
        'existencias no se cobra; anular el cobro los devuelve', () async {
      final inv = b.servicio.inventario;
      final caja = b.servicio.caja;
      final jeringa = await inv.guardarInsumo(
        inv.nuevoInsumo().copyWith(
          nombre: 'Jeringa de prueba',
          categoria: CategoriaInsumo.dispositivo,
          unidad: 'unidad',
          registroInvima: 'INVIMA PRUEBA-0002',
        ),
      );
      final despues = await inv.registrarEntrada(
        insumoId: jeringa.id,
        numero: 'J-2',
        vence: DateTime(2027, 6, 30),
        cantidad: 10,
      );
      final primero = await inv.registrarEntrada(
        insumoId: jeringa.id,
        numero: 'J-1',
        vence: DateTime(2027, 1, 31),
        cantidad: 2,
      );
      expect(inv.usables.map((i) => i.id), [jeringa.id]);
      expect(inv.sugerido(jeringa.id)!.id, primero.id);

      // Más de lo que hay: no se registra nada.
      final demasiado = [inv.insumoCobro(primero, 3)];
      expect(
        caja
            .evaluar(
              pacienteId: paciente,
              items: [consulta()],
              pagos: const [],
              insumos: demasiado,
            )
            .bloqueos,
        [
          'El lote J-1 de «Jeringa de prueba» tiene 2 unidades; el cobro usa '
              '3 unidades.',
        ],
      );
      await expectLater(
        caja.cobrar(
          pacienteId: paciente,
          items: [consulta()],
          pagos: const [],
          insumos: demasiado,
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        ),
        throwsA(isA<StateError>()),
      );
      expect(caja.saldoPaciente(paciente), 0);
      expect(inv.existencia(primero.id), 2);

      final r = await caja.cobrar(
        pacienteId: paciente,
        items: [consulta()],
        pagos: [const PagoRecibo(medio: MedioPago.efectivo, valor: 10000)],
        insumos: [inv.insumoCobro(primero, 2), inv.insumoCobro(despues, 1)],
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      expect(r.cobro.insumos, hasLength(2));
      expect(inv.existencia(primero.id), 0);
      expect(inv.existencia(despues.id), 9);
      final salidas = inv.movimientosDeCobro(r.cobro.id);
      expect(salidas.map((m) => m.tipo), everyElement(TipoMovimiento.salida));
      expect(salidas.map((m) => m.motivo), everyElement(startsWith('Cobro: ')));

      // Cifrado y al reabrir.
      expect(contieneTexto(b.todosLosBytes, 'Jeringa de prueba'), isFalse);
      await b.servicio.bloquear();
      await b.servicio.desbloquear(fraseDePrueba);
      expect(caja.cobro(r.cobro.id)!.insumos.first.lote, 'J-1');
      expect(inv.existencia(despues.id), 9);

      // Anular: primero el recibo, luego el cobro; los insumos vuelven.
      await caja.anularRecibo(r.recibo!.id, motivo: 'Error de prueba');
      await caja.anularCobro(r.cobro.id, motivo: 'Error de prueba');
      expect(inv.existencia(primero.id), 2);
      expect(inv.existencia(despues.id), 10);
      final devueltos = inv
          .movimientosDeCobro(r.cobro.id)
          .where((m) => m.tipo == TipoMovimiento.ajuste)
          .toList();
      expect(devueltos, hasLength(2));
      expect(devueltos.first.motivo, startsWith('Cobro anulado: '));

      // Devolver otra vez no suma de más.
      await inv.devolverCobro(caja.cobro(r.cobro.id)!);
      expect(inv.existencia(despues.id), 10);

      final acciones = (await leerBitacora(
        b.servicio.repositorio,
      )).map((e) => e.accion).toList();
      expect(acciones, contains(AccionBitacora.salidaInventarioCobro));
      expect(
        acciones.where((a) => a == AccionBitacora.devolverInventario),
        hasLength(1),
      );
    });

    test('un cobro sin insumos no toca el inventario', () async {
      final inv = b.servicio.inventario;
      final r = await b.servicio.caja.cobrar(
        pacienteId: paciente,
        items: [consulta()],
        pagos: const [],
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      expect(r.cobro.insumos, isEmpty);
      expect(inv.movimientosDeCobro(r.cobro.id), isEmpty);
      await b.servicio.caja.anularCobro(r.cobro.id, motivo: 'Prueba');
      final acciones = (await leerBitacora(
        b.servicio.repositorio,
      )).map((e) => e.accion);
      expect(acciones, isNot(contains(AccionBitacora.devolverInventario)));
    });
  });
}
