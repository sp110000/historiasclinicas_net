import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/caja/catalogo.dart';
import 'package:historiasclinicas_net/core/consultorio/caja/movimientos.dart';
import 'package:historiasclinicas_net/core/consultorio/caja/recibo_pdf.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/ficha_paciente.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/reglas/caja.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';

import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';
import 'ayudas_procedimientos.dart';
import 'documentos_test.dart' show textoPdf;

// Lunes 23/11/2026, 9:30.
final _ahora = DateTime(2026, 11, 23, 9, 30);

final _catalogo = {for (final s in serviciosIniciales) s.id: s};

ItemCobro _item(
  String servicioId, {
  int cantidad = 1,
  int? valor,
  int descuento = 0,
  String motivo = '',
}) {
  final s = _catalogo[servicioId]!;
  return ItemCobro(
    servicioId: s.id,
    descripcion: s.nombre,
    valorUnitario: valor ?? s.tarifa,
    cantidad: cantidad,
    descuento: descuento,
    motivoDescuento: motivo,
  );
}

PagoRecibo _pago(int valor, [MedioPago medio = MedioPago.efectivo]) =>
    PagoRecibo(medio: medio, valor: valor);

Recibo _recibo(
  String id,
  DateTime fecha,
  List<PagoRecibo> pagos, {
  DateTime? anuladoEn,
  bool trasCierre = false,
}) => Recibo(
  id: id,
  numero: 'RC-$id',
  cobroId: 'c',
  pacienteId: 'f',
  fecha: fecha,
  pagos: pagos,
  anulado: anuladoEn != null,
  anuladoEn: anuladoEn,
  anuladoTrasCierre: trasCierre,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Catálogo', () {
    test('tarifas iniciales de la pregunta 44', () {
      final t = {for (final s in serviciosIniciales) s.id: s.tarifa};
      expect(t, {
        'consulta_primera_vez': 80000,
        'control': 45000,
        'certificado': 40000,
        'valoracion_estetica': 70000,
        'sesion_hidrolipoclasia': 240000,
        'paquete_hidrolipoclasia_4': 880000,
        'ecografia': 100000,
        'ecografia_obstetrica': 120000,
        'ecografia_transvaginal': 120000,
      });
      expect(_catalogo['valoracion_estetica']!.abonable, isTrue);
      expect(_catalogo['paquete_hidrolipoclasia_4']!.sesionesPaquete, 4);
      expect(
        serviciosIniciales.where((s) => s.linea == LineaAtencion.estetica),
        hasLength(3),
      );
      for (final s in serviciosIniciales) {
        expect(Servicio.desdeMapa(s.aMapa()).aMapa(), s.aMapa());
      }
    });

    test('formato en pesos', () {
      expect(formatoPesos(0), r'$ 0');
      expect(formatoPesos(80000), r'$ 80.000');
      expect(formatoPesos(1234567), r'$ 1.234.567');
      expect(formatoPesos(-45000), r'-$ 45.000');
    });
  });

  group('Totales y saldos (por tabla)', () {
    final casos =
        <
          ({
            String caso,
            List<ItemCobro> items,
            int credito,
            List<PagoRecibo> pagos,
            int total,
            int saldo,
          })
        >[
          (
            caso: 'consulta pagada completa',
            items: [_item('consulta_primera_vez')],
            credito: 0,
            pagos: [_pago(80000)],
            total: 80000,
            saldo: 0,
          ),
          (
            caso: 'dos controles con descuento',
            items: [
              _item(
                'control',
                cantidad: 2,
                descuento: 10000,
                motivo: 'Familia',
              ),
            ],
            credito: 0,
            pagos: [_pago(80000, MedioPago.nequi)],
            total: 80000,
            saldo: 0,
          ),
          (
            caso: 'paquete con crédito de valoración y abono',
            items: [_item('paquete_hidrolipoclasia_4')],
            credito: 70000,
            pagos: [_pago(300000), _pago(200000, MedioPago.tarjeta)],
            total: 810000,
            saldo: 310000,
          ),
          (
            caso: 'sesión sin pago',
            items: [_item('sesion_hidrolipoclasia')],
            credito: 0,
            pagos: const [],
            total: 240000,
            saldo: 240000,
          ),
          (
            caso: 'certificado y control',
            items: [_item('certificado'), _item('control')],
            credito: 0,
            pagos: [_pago(50000), _pago(35000, MedioPago.daviplata)],
            total: 85000,
            saldo: 0,
          ),
        ];
    for (final c in casos) {
      test(c.caso, () {
        final e = evaluarCobro(
          pacienteId: 'f',
          items: c.items,
          credito: c.credito,
          pagos: c.pagos,
          diaCerrado: false,
          servicios: _catalogo,
        );
        expect(e.bloqueos, isEmpty);
        final cobro = Cobro(
          id: 'c',
          pacienteId: 'f',
          fecha: _ahora,
          items: c.items,
          credito: c.credito,
        );
        expect(cobro.total, c.total);
        expect(cobro.total - sumaPagos(c.pagos), c.saldo);
        expect(
          e.avisos.any((a) => a.contains('saldo')),
          c.saldo > 0,
          reason: '${e.avisos}',
        );
      });
    }
  });

  group('Reglas del cobro (por tabla)', () {
    final casos =
        <
          ({
            String caso,
            String paciente,
            List<ItemCobro> items,
            int credito,
            List<PagoRecibo> pagos,
            bool cerrado,
            String bloqueo,
          })
        >[
          (
            caso: 'sin paciente',
            paciente: '',
            items: [_item('control')],
            credito: 0,
            pagos: const [],
            cerrado: false,
            bloqueo: 'Elige el paciente',
          ),
          (
            caso: 'sin servicios',
            paciente: 'f',
            items: const [],
            credito: 0,
            pagos: const [],
            cerrado: false,
            bloqueo: 'Agrega al menos un servicio',
          ),
          (
            caso: 'cantidad cero',
            paciente: 'f',
            items: [_item('control', cantidad: 0)],
            credito: 0,
            pagos: const [],
            cerrado: false,
            bloqueo: 'La cantidad va desde 1',
          ),
          (
            caso: 'descuento sin motivo',
            paciente: 'f',
            items: [_item('control', descuento: 5000)],
            credito: 0,
            pagos: const [],
            cerrado: false,
            bloqueo: 'motivo del descuento',
          ),
          (
            caso: 'descuento mayor que el valor',
            paciente: 'f',
            items: [_item('control', descuento: 50000, motivo: 'x')],
            credito: 0,
            pagos: const [],
            cerrado: false,
            bloqueo: r'va de 0 a $ 45.000',
          ),
          (
            caso: 'crédito mayor que el total',
            paciente: 'f',
            items: [_item('control')],
            credito: 70000,
            pagos: const [],
            cerrado: false,
            bloqueo: 'El crédito no puede ser mayor',
          ),
          (
            caso: 'pago en cero',
            paciente: 'f',
            items: [_item('control')],
            credito: 0,
            pagos: [_pago(0)],
            cerrado: false,
            bloqueo: 'Cada pago tiene que tener un valor',
          ),
          (
            caso: 'sobrepago',
            paciente: 'f',
            items: [_item('control')],
            credito: 0,
            pagos: [_pago(50000)],
            cerrado: false,
            bloqueo: 'supera lo que se debe',
          ),
          (
            caso: 'pago con la caja cerrada',
            paciente: 'f',
            items: [_item('control')],
            credito: 0,
            pagos: [_pago(45000)],
            cerrado: true,
            bloqueo: 'La caja de hoy ya se cerró',
          ),
        ];
    for (final c in casos) {
      test('bloquea: ${c.caso}', () {
        final e = evaluarCobro(
          pacienteId: c.paciente,
          items: c.items,
          credito: c.credito,
          pagos: c.pagos,
          diaCerrado: c.cerrado,
        );
        expect(e.permiteRegistrar, isFalse);
        expect(e.bloqueos.join('\n'), contains(c.bloqueo));
      });
    }

    test('sin pago con la caja cerrada sí se registra (queda el saldo)', () {
      final e = evaluarCobro(
        pacienteId: 'f',
        items: [_item('control')],
        credito: 0,
        pagos: const [],
        diaCerrado: true,
      );
      expect(e.permiteRegistrar, isTrue);
    });

    test('avisa del crédito de valoración sin aplicar en un tratamiento', () {
      EvaluacionCobro con(String servicio) => evaluarCobro(
        pacienteId: 'f',
        items: [_item(servicio)],
        credito: 0,
        pagos: const [],
        diaCerrado: false,
        creditoSinAplicar: 70000,
        servicios: _catalogo,
      );
      expect(
        con('paquete_hidrolipoclasia_4').avisos.join(),
        contains(r'crédito de $ 70.000'),
      );
      expect(con('control').avisos.join(), isNot(contains('crédito')));
      expect(
        con('valoracion_estetica').avisos.join(),
        isNot(contains('crédito')),
      );
    });
  });

  group('Totales del día', () {
    final lunes = DateTime(2026, 11, 23, 10);
    final martes = DateTime(2026, 11, 24, 11);
    final recibos = [
      _recibo('1', lunes, [_pago(80000), _pago(20000, MedioPago.nequi)]),
      _recibo('2', lunes, [_pago(45000)], anuladoEn: lunes),
      // Anulado el martes con el lunes ya cerrado: cuenta el martes.
      _recibo('3', lunes, [_pago(30000)], anuladoEn: martes, trasCierre: true),
      _recibo('4', martes, [_pago(240000, MedioPago.tarjeta)]),
    ];

    test('el lunes: lo vigente y lo anulado después del cierre', () {
      final t = totalesDelDia(recibos, lunes);
      expect(t[MedioPago.efectivo], 110000);
      expect(t[MedioPago.nequi], 20000);
      expect(t[MedioPago.tarjeta], 0);
    });

    test('el martes: resta la anulación del recibo del lunes', () {
      final t = totalesDelDia(recibos, martes);
      expect(t[MedioPago.efectivo], -30000);
      expect(t[MedioPago.tarjeta], 240000);
    });
  });

  group('CSV', () {
    test('BOM, punto y coma, CRLF y comillas', () {
      final b = csvDeFilas([
        ['Concepto', 'Valor'],
        ['Control; sábado', 45000],
        ['Dijo "hola"', 0],
      ]);
      expect(b.take(3), [0xEF, 0xBB, 0xBF]);
      final t = utf8.decode(b.skip(3).toList());
      expect(
        t,
        'Concepto;Valor\r\n"Control; sábado";45000\r\n"Dijo ""hola""";0\r\n',
      );
    });

    test('informe del mes con volumen por técnica', () {
      final cobros = [
        Cobro(
          id: 'a',
          pacienteId: 'f',
          fecha: DateTime(2026, 11, 3),
          items: [_item('control', cantidad: 2)],
        ),
        Cobro(
          id: 'b',
          pacienteId: 'f',
          fecha: DateTime(2026, 11, 4),
          items: [_item('paquete_hidrolipoclasia_4')],
          credito: 70000,
        ),
        Cobro(
          id: 'c',
          pacienteId: 'f',
          fecha: DateTime(2026, 11, 5),
          items: [_item('control')],
          anulado: true,
        ),
        Cobro(
          id: 'd',
          pacienteId: 'f',
          fecha: DateTime(2026, 10, 30),
          items: [_item('control')],
        ),
      ];
      final i = informeDelMes(
        anio: 2026,
        mes: 11,
        cobros: cobros,
        recibos: [
          _recibo('1', DateTime(2026, 11, 3), [_pago(90000)]),
          _recibo('2', DateTime(2026, 11, 4), [
            _pago(500000, MedioPago.transferencia),
          ]),
        ],
        servicios: _catalogo,
      );
      expect(i.porServicio.map((f) => (f.concepto, f.cantidad, f.neto)), [
        ('Control', 2, 90000),
        ('Paquete de 4 sesiones', 1, 880000),
      ]);
      expect(i.porLinea.map((f) => (f.concepto, f.neto)), [
        ('Estética', 880000),
        ('General', 90000),
      ]);
      expect(i.creditosAplicados, 70000);
      expect(i.totalRecaudo, 590000);
      final csv = utf8.decode(
        csvInforme(
          i,
          volumen: [(tecnica: 'Hidrolipoclasia', valoraciones: 3, sesiones: 5)],
        ).skip(3).toList(),
      );
      final lineas = csv.split('\r\n');
      expect(
        lineas.first,
        'Mes;Sección;Concepto;Línea;Cantidad;Bruto;Descuentos;Neto',
      );
      expect(
        lineas,
        contains('2026-11;Servicio;Control;General;2;90000;0;90000'),
      );
      expect(
        lineas,
        contains(
          '2026-11;Créditos aplicados;Valoraciones abonadas;;;;70000;-70000',
        ),
      );
      expect(lineas, contains('2026-11;Recaudo;Transferencia;;;;;500000'));
      expect(
        lineas,
        contains('2026-11;Sesiones;Hidrolipoclasia;Estética;5;;;'),
      );
    });
  });

  group('En el consultorio', () {
    late BancoConsultorio b;
    late String paciente;
    late FuentesPdf fuentes;

    setUpAll(() async => fuentes = await FuentesPdf.cargar());

    setUp(() async {
      b = BancoConsultorio(ahora: _ahora);
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

    Future<({Cobro cobro, Recibo? recibo})> cobrar(
      List<ItemCobro> items,
      List<PagoRecibo> pagos, {
      Credito? credito,
    }) async {
      final r = await b.servicio.caja.cobrar(
        pacienteId: paciente,
        items: items,
        pagos: pagos,
        credito: credito,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      return (cobro: r.cobro, recibo: r.recibo);
    }

    test('cobro con abono, saldo y recibos; cifrado y al reabrir', () async {
      final caja = b.servicio.caja;
      final r = await cobrar(
        [_item('consulta_primera_vez')],
        [_pago(50000, MedioPago.nequi)],
      );
      expect(r.recibo!.numero, 'RC-000001');
      expect(caja.saldo(r.cobro), 30000);
      expect(caja.saldoPaciente(paciente), 30000);
      b.reloj.avanzar(const Duration(hours: 2));
      final (abono, pdf) = await caja.abonar(
        r.cobro.id,
        [_pago(30000)],
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      expect(abono.numero, 'RC-000002');
      expect(caja.saldo(r.cobro), 0);
      expect(caja.totales(_ahora), {
        MedioPago.efectivo: 30000,
        MedioPago.transferencia: 0,
        MedioPago.nequi: 50000,
        MedioPago.daviplata: 0,
        MedioPago.tarjeta: 0,
      });
      expect(await caja.pdfRecibo(abono.id), pdf);
      await expectLater(
        caja.abonar(
          r.cobro.id,
          [_pago(1000)],
          medico: medicoCompleto(),
          pais: Pais.colombia,
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'm', contains('pagado')),
        ),
      );
      expect(contieneTexto(b.todosLosBytes, 'RC-000001'), isFalse);
      expect(contieneTexto(b.todosLosBytes, 'Consulta'), isFalse);

      await b.servicio.bloquear();
      expect(caja.cobrosDe(paciente), isEmpty);
      await b.servicio.desbloquear(fraseDePrueba);
      expect(caja.cobrosDe(paciente), hasLength(1));
      expect(caja.recibosDe(r.cobro.id).map((x) => x.numero), [
        'RC-000001',
        'RC-000002',
      ]);
      expect(caja.saldoPaciente(paciente), 0);
    });

    test(
      'recibo PDF: número, pagos, saldo y aviso de que no es factura',
      () async {
        final r = await b.servicio.caja.cobrar(
          pacienteId: paciente,
          items: [_item('control', cantidad: 2, descuento: 10000, motivo: 'x')],
          pagos: [
            PagoRecibo(
              medio: MedioPago.transferencia,
              valor: 50000,
              referencia: 'ABC123',
            ),
          ],
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        );
        final texto = textoPdf(r.pdf!);
        if (texto == null) return; // Sin pdftotext.
        final plano = texto.replaceAll(RegExp(r'\s+'), ' ');
        for (final esperado in [
          'RECIBO DE CAJA',
          'RC-000001',
          'PEÑA MUÑOZ, José Ángel',
          'Control',
          r'$ 90.000',
          r'-$ 10.000',
          'Transferencia',
          'ABC123',
          r'$ 50.000',
          r'$ 30.000',
          avisoNoFactura,
        ]) {
          expect(plano, contains(esperado), reason: esperado);
        }
      },
    );

    test('consecutivo sin saltos ni repetidos (también al reabrir)', () async {
      final caja = b.servicio.caja;
      final numeros = <String>[];
      for (var i = 0; i < 3; i++) {
        numeros.add(
          (await cobrar([_item('control')], [_pago(45000)])).recibo!.numero,
        );
      }
      // Un cobro sin pago no gasta número.
      final sinPago = await cobrar([_item('control')], const []);
      expect(sinPago.recibo, isNull);
      // Un recibo anulado conserva su número.
      final anular = caja.recibosDelDia(_ahora).first;
      await caja.anularRecibo(anular.id, motivo: 'Error de digitación');
      await b.servicio.bloquear();
      await b.servicio.desbloquear(fraseDePrueba);
      numeros.add(
        (await cobrar([_item('control')], [_pago(45000)])).recibo!.numero,
      );
      expect(numeros, ['RC-000001', 'RC-000002', 'RC-000003', 'RC-000004']);
      final todos = caja.recibosDelDia(_ahora).map((r) => r.numero).toList();
      expect(todos.toSet(), hasLength(todos.length));
    });

    test('equipo secundario: su propia serie RC-S', () async {
      b.servicio.documentos.serie = 'S';
      final r = await cobrar([_item('control')], [_pago(45000)]);
      expect(r.recibo!.numero, 'RC-S000001');
    });

    test(
      'paquete: se crea al cobrarlo, se usa sin recibo y se agota',
      () async {
        final caja = b.servicio.caja;
        final r = await cobrar(
          [_item('paquete_hidrolipoclasia_4')],
          [_pago(880000, MedioPago.transferencia)],
        );
        final paquete = caja.paquetesDe(paciente).single;
        expect(paquete.sesiones, 4);
        expect(paquete.cobroId, r.cobro.id);
        expect(paquete.plantillaId, 'hidrolipoclasia');
        final recibos = caja.recibosDelDia(_ahora).length;
        for (var i = 1; i <= 4; i++) {
          final p = await caja.usarPaquete(paquete.id);
          expect(p.usadas, i);
        }
        expect(caja.recibosDelDia(_ahora), hasLength(recibos));
        expect(caja.usosDelDia(_ahora).map((u) => u.numero), [1, 2, 3, 4]);
        expect(caja.paquete(paquete.id)!.agotado, isTrue);
        await expectLater(
          caja.usarPaquete(paquete.id),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'm',
              contains('ya usó sus 4 sesiones'),
            ),
          ),
        );
        // Ya usado, el cobro del paquete no se anula.
        await caja.anularRecibo(
          caja.recibosDe(r.cobro.id).single.id,
          motivo: 'Devolución',
        );
        await expectLater(
          caja.anularCobro(r.cobro.id, motivo: 'x'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'crédito de la valoración: 30 días y se descuenta del tratamiento',
      () async {
        final caja = b.servicio.caja;
        // Sin pagar del todo, no hay crédito.
        final v = await cobrar([_item('valoracion_estetica')], [_pago(30000)]);
        expect(caja.creditosDisponibles(paciente), isEmpty);
        await caja.abonar(
          v.cobro.id,
          [_pago(40000)],
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        );
        final credito = caja.creditosDisponibles(paciente).single;
        expect(credito.valor, 70000);
        expect(credito.vence, DateTime(2026, 12, 23));
        expect(
          caja
              .evaluar(
                pacienteId: paciente,
                items: [_item('paquete_hidrolipoclasia_4')],
                pagos: const [],
              )
              .avisos
              .join(),
          contains('sin aplicar'),
        );
        final t = await cobrar(
          [_item('paquete_hidrolipoclasia_4')],
          [_pago(810000, MedioPago.tarjeta)],
          credito: credito,
        );
        expect(t.cobro.credito, 70000);
        expect(t.cobro.total, 810000);
        expect(caja.saldo(t.cobro), 0);
        expect(caja.creditosDisponibles(paciente), isEmpty);
        // Aplicado, el recibo de la valoración no se anula sin anular antes
        // el tratamiento.
        await expectLater(
          caja.anularRecibo(caja.recibosDe(v.cobro.id).first.id, motivo: 'x'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'm',
              contains('ya se aplicó'),
            ),
          ),
        );
        // Anular el tratamiento (recibo y cobro) libera el crédito.
        await caja.anularRecibo(
          caja.recibosDe(t.cobro.id).single.id,
          motivo: 'Desistió',
        );
        await caja.anularCobro(t.cobro.id, motivo: 'Desistió');
        expect(caja.creditosDisponibles(paciente).single.id, credito.id);
        expect(caja.paquetesDe(paciente).single.anulado, isTrue);
      },
    );

    test('el crédito vence a los 30 días', () async {
      final caja = b.servicio.caja;
      await cobrar([_item('valoracion_estetica')], [_pago(70000)]);
      b.reloj.fijar(DateTime(2026, 12, 23, 18));
      expect(caja.creditosDisponibles(paciente), hasLength(1));
      b.reloj.fijar(DateTime(2026, 12, 24, 8));
      expect(caja.creditosDisponibles(paciente), isEmpty);
    });

    test(
      'anular un recibo de hoy: sale de los totales y anula su crédito',
      () async {
        final caja = b.servicio.caja;
        final v = await cobrar([_item('valoracion_estetica')], [_pago(70000)]);
        expect(caja.creditosDisponibles(paciente), hasLength(1));
        await expectLater(
          caja.anularRecibo(v.recibo!.id, motivo: '  '),
          throwsA(isA<StateError>()),
        );
        await caja.anularRecibo(v.recibo!.id, motivo: 'Pago duplicado');
        final anulado = caja.recibo(v.recibo!.id)!;
        expect(anulado.anulado, isTrue);
        expect(anulado.anuladoTrasCierre, isFalse);
        expect(anulado.motivoAnulacion, 'Pago duplicado');
        expect(caja.totales(_ahora)[MedioPago.efectivo], 0);
        expect(caja.saldo(v.cobro), 70000);
        expect(caja.creditosDisponibles(paciente), isEmpty);
        await expectLater(
          caja.anularRecibo(v.recibo!.id, motivo: 'otra vez'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('día cerrado: inmutable, y la anulación cuenta en el día en que se '
        'hace', () async {
      final caja = b.servicio.caja;
      final r = await cobrar([_item('control')], [_pago(45000)]);
      await cobrar([_item('certificado')], [_pago(40000, MedioPago.nequi)]);
      final cierre = await caja.cerrarDia(
        efectivoContado: 40000,
        notas: 'Faltó cambio',
      );
      expect(cierre.efectivoEsperado, 45000);
      expect(cierre.diferencia, -5000);
      expect(cierre.total, 85000);
      expect(caja.hoyCerrado, isTrue);

      // No se reabre ni recibe pagos ni anulaciones.
      await expectLater(
        caja.cerrarDia(efectivoContado: 45000),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        cobrar([_item('control')], [_pago(45000)]),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'm',
            contains('ya se cerró'),
          ),
        ),
      );
      await expectLater(
        caja.anularRecibo(r.recibo!.id, motivo: 'x'),
        throwsA(isA<StateError>()),
      );
      // Sin pago sí (queda el saldo, sin recibo), y el paquete se puede usar.
      final sinPago = await cobrar([_item('control')], const []);
      expect(caja.saldo(sinPago.cobro), 45000);

      // Al día siguiente: la anulación del lunes resta el martes.
      final martes = DateTime(2026, 11, 24, 8, 15);
      b.reloj.fijar(martes);
      await caja.anularRecibo(r.recibo!.id, motivo: 'Error de digitación');
      expect(caja.recibo(r.recibo!.id)!.anuladoTrasCierre, isTrue);
      expect(caja.totales(_ahora)[MedioPago.efectivo], 45000);
      expect(caja.totales(martes)[MedioPago.efectivo], -45000);
      expect(caja.anulacionesDelDia(martes).single.numero, 'RC-000001');
      // El cierre guardado del lunes no cambia (también al reabrir).
      await b.servicio.bloquear();
      await b.servicio.desbloquear(fraseDePrueba);
      final guardado = caja.cierre(_ahora)!;
      expect(guardado.totales[MedioPago.efectivo], 45000);
      expect(guardado.efectivoContado, 40000);
      expect(guardado.notas, 'Faltó cambio');
      expect(caja.diaCerrado(martes), isFalse);

      final csv = utf8.decode(
        (await caja.exportarDia(_ahora)).skip(3).toList(),
      );
      expect(csv, contains('RC-000001'));
      expect(csv, contains('Anulado el 2026-11-24'));
      expect(csv, contains(';Efectivo contado;Efectivo;40000;Cierre'));
      expect(csv, contains(';Diferencia;Efectivo;-5000;Faltó cambio'));
      final csvMartes = utf8.decode(
        (await caja.exportarDia(martes)).skip(3).toList(),
      );
      expect(csvMartes, contains('Anulación del recibo del 2026-11-23'));
      expect(csvMartes, contains(';-45000;Anulación'));
    });

    test('anular un cobro: solo sin recibos vigentes', () async {
      final caja = b.servicio.caja;
      final r = await cobrar([_item('control')], [_pago(20000)]);
      await expectLater(
        caja.anularCobro(r.cobro.id, motivo: 'x'),
        throwsA(
          isA<StateError>().having((e) => e.message, 'm', contains('recibos')),
        ),
      );
      await caja.anularRecibo(r.recibo!.id, motivo: 'x');
      await caja.anularCobro(r.cobro.id, motivo: 'No era');
      expect(caja.cobro(r.cobro.id)!.anulado, isTrue);
      expect(caja.saldoPaciente(paciente), 0);
    });

    test('catálogo editable y en la bitácora', () async {
      final caja = b.servicio.caja;
      final nuevo = caja.nuevoServicio().copyWith(
        nombre: 'Lavado de oídos',
        tarifa: 35000,
      );
      await caja.guardarCatalogo([
        for (final s in caja.servicios)
          s.id == 'control' ? s.copyWith(tarifa: 50000) : s,
        nuevo,
      ]);
      await expectLater(
        caja.guardarCatalogo([nuevo.copyWith(nombre: ' ')]),
        throwsA(isA<StateError>()),
      );
      await b.servicio.bloquear();
      await b.servicio.desbloquear(fraseDePrueba);
      expect(caja.serviciosPorId['control']!.tarifa, 50000);
      expect(caja.serviciosPorId[nuevo.id]!.nombre, 'Lavado de oídos');
      final r = await cobrar([_item('control')], [_pago(45000)]);
      await cobrar([_item('paquete_hidrolipoclasia_4')], const []);
      await caja.usarPaquete(caja.paquetesDe(paciente).single.id);
      await caja.cerrarDia(efectivoContado: 45000);
      await caja.exportarInforme(2026, 11);
      final acciones = (await leerBitacora(
        b.servicio.repositorio,
      )).map((e) => e.accion).toList();
      for (final a in [
        AccionBitacora.cambiarAjustes,
        AccionBitacora.registrarCobro,
        AccionBitacora.registrarPago,
        AccionBitacora.usarPaquete,
        AccionBitacora.cerrarCaja,
        AccionBitacora.exportarInforme,
      ]) {
        expect(acciones, contains(a), reason: a.name);
      }
      expect(r.recibo, isNotNull);
    });

    test('volumen por técnica: valoraciones selladas del mes', () async {
      final caja = b.servicio.caja;
      expect(caja.volumenPorTecnica(2026, 11), isEmpty);
      await aprobarHidrolipoclasia(b);
      await valorarAptoDePrueba(b, paciente);
      final nombre = b.servicio.procedimientos.plantilla('hidrolipoclasia')!;
      expect(caja.volumenPorTecnica(2026, 11), [
        (tecnica: nombre.nombre, valoraciones: 1, sesiones: 0),
      ]);
      expect(caja.volumenPorTecnica(2026, 10), isEmpty);
      final csv = utf8.decode(
        (await caja.exportarInforme(2026, 11)).skip(3).toList(),
      );
      expect(csv, contains(';Valoraciones;${nombre.nombre};Estética;1;;;'));
    });
  });

  group('Procedimientos y servicios editables en el cobro', () {
    const proc = ItemCobro(
      servicioId: 'procedimiento:hidrolipoclasia',
      plantillaId: 'hidrolipoclasia',
      descripcion: 'Hidrolipoclasia abdomen',
      valorUnitario: 240000,
      cantidad: 2,
    );

    test('el procedimiento se guarda con su plantilla; uno viejo se lee '
        'como servicio', () {
      final m = ItemCobro.desdeMapa(proc.aMapa());
      expect(m.plantillaId, 'hidrolipoclasia');
      expect(m.esProcedimiento, isTrue);
      expect(m.bruto, 480000);
      final viejo = ItemCobro.desdeMapa(
        _item('control').aMapa()..remove('plantillaId'),
      );
      expect(viejo.esProcedimiento, isFalse);
      // Nombre y precio editados se conservan.
      final editado = _item(
        'control',
      ).copyWith(descripcion: 'Control con ecografía', valorUnitario: 60000);
      expect(editado.servicioId, 'control');
      expect(
        ItemCobro.desdeMapa(editado.aMapa()).descripcion,
        'Control con ecografía',
      );
      expect(editado.neto, 60000);
    });

    test('reglas: sin nombre bloquea, sin precio avisa, y el procedimiento '
        'cuenta como tratamiento para el crédito', () {
      EvaluacionCobro evaluar(List<ItemCobro> items) => evaluarCobro(
        pacienteId: 'f',
        items: items,
        credito: 0,
        pagos: const [],
        diaCerrado: false,
        creditoSinAplicar: 70000,
        servicios: _catalogo,
      );
      expect(
        evaluar([_item('control').copyWith(descripcion: ' ')]).bloqueos,
        contains('Escribe el nombre de cada servicio y procedimiento.'),
      );
      expect(
        evaluar([_item('control', valor: 0)]).avisos,
        contains('«Control» va sin precio.'),
      );
      expect(
        evaluar([proc]).avisos,
        contains(r'Hay un crédito de $ 70.000 de la valoración sin aplicar.'),
      );
    });

    test('la caja sugiere la tarifa de la sesión del procedimiento', () async {
      final b = BancoConsultorio(ahora: _ahora);
      await b.servicio.crear(fraseDePrueba);
      expect(b.servicio.caja.tarifaProcedimiento('hidrolipoclasia'), 240000);
      expect(b.servicio.caja.tarifaProcedimiento('otro'), 0);
    });

    test(
      'el informe del mes lleva el procedimiento en la línea de estética',
      () {
        final i = informeDelMes(
          anio: 2026,
          mes: 11,
          cobros: [
            Cobro(
              id: 'c1',
              pacienteId: 'f',
              fecha: _ahora,
              items: const [proc],
            ),
          ],
          recibos: const [],
          servicios: _catalogo,
        );
        final fila = i.porServicio.single;
        expect(fila.concepto, 'Hidrolipoclasia abdomen');
        expect(fila.linea, 'Estética');
        expect(fila.cantidad, 2);
        expect(fila.bruto, 480000);
      },
    );
  });
}
