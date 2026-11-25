import 'dart:convert';

import '../../models/mapa.dart';
import '../caja/catalogo.dart';
import '../caja/movimientos.dart';
import '../modelos/ficha_paciente.dart';

/// Lo que dicen las reglas de un cobro o un abono.
class EvaluacionCobro {
  const EvaluacionCobro({required this.bloqueos, required this.avisos});

  final List<String> bloqueos;
  final List<String> avisos;

  bool get permiteRegistrar => bloqueos.isEmpty;
}

int sumaPagos(Iterable<PagoRecibo> pagos) =>
    pagos.fold(0, (s, p) => s + p.valor);

List<String> _problemasPagos(
  List<PagoRecibo> pagos, {
  required int saldo,
  required bool diaCerrado,
}) => [
  if (pagos.any((p) => p.valor <= 0)) 'Cada pago tiene que tener un valor.',
  if (sumaPagos(pagos) > saldo)
    'Lo pagado (${formatoPesos(sumaPagos(pagos))}) supera lo que se debe '
        '(${formatoPesos(saldo)}).',
  if (pagos.isNotEmpty && diaCerrado)
    'La caja de hoy ya se cerró: no se registran más pagos hoy.',
];

/// Evalúa un cobro nuevo (puro). [credito] es el crédito que se le aplica.
EvaluacionCobro evaluarCobro({
  required String pacienteId,
  required List<ItemCobro> items,
  required int credito,
  required List<PagoRecibo> pagos,
  required bool diaCerrado,
  int creditoSinAplicar = 0,
  Map<String, Servicio> servicios = const {},
}) {
  final bloqueos = <String>[];
  final avisos = <String>[];
  if (pacienteId.isEmpty) bloqueos.add('Elige el paciente.');
  if (items.isEmpty) bloqueos.add('Agrega al menos un servicio.');
  for (final i in items) {
    if (i.cantidad < 1) {
      bloqueos.add('La cantidad va desde 1 (${i.descripcion}).');
    }
    if (i.valorUnitario < 0) bloqueos.add('El valor no puede ser negativo.');
    if (i.descuento < 0 || i.descuento > i.bruto) {
      bloqueos.add(
        'El descuento de «${i.descripcion}» va de 0 a ${formatoPesos(i.bruto)}.',
      );
    } else if (i.descuento > 0 && i.motivoDescuento.trim().isEmpty) {
      bloqueos.add('Escribe el motivo del descuento de «${i.descripcion}».');
    }
  }
  final antesDeCredito = items.fold(0, (s, i) => s + i.neto);
  if (credito > antesDeCredito) {
    bloqueos.add('El crédito no puede ser mayor que el total.');
  }
  final total = antesDeCredito - credito;
  bloqueos.addAll(
    _problemasPagos(
      pagos,
      saldo: total < 0 ? 0 : total,
      diaCerrado: diaCerrado,
    ),
  );
  final saldo = total - sumaPagos(pagos);
  if (bloqueos.isEmpty && saldo > 0) {
    avisos.add(
      pagos.isEmpty
          ? 'Sin pago: queda el saldo de ${formatoPesos(saldo)} y no hay recibo.'
          : 'Es un abono: queda un saldo de ${formatoPesos(saldo)}.',
    );
  }
  final tratamientoEstetico = items.any((i) {
    final s = servicios[i.servicioId];
    return s != null && s.linea == LineaAtencion.estetica && !s.abonable;
  });
  if (credito == 0 && creditoSinAplicar > 0 && tratamientoEstetico) {
    avisos.add(
      'Hay un crédito de ${formatoPesos(creditoSinAplicar)} de la valoración '
      'sin aplicar.',
    );
  }
  return EvaluacionCobro(bloqueos: bloqueos, avisos: avisos);
}

/// Evalúa un abono a un cobro con [saldo] pendiente.
EvaluacionCobro evaluarAbono({
  required Cobro cobro,
  required int saldo,
  required List<PagoRecibo> pagos,
  required bool diaCerrado,
}) {
  final bloqueos = <String>[
    if (cobro.anulado) 'El cobro está anulado.',
    if (saldo <= 0) 'El cobro ya está pagado.',
    if (pagos.isEmpty) 'Agrega el pago.',
    ..._problemasPagos(pagos, saldo: saldo, diaCerrado: diaCerrado),
  ];
  final queda = saldo - sumaPagos(pagos);
  return EvaluacionCobro(
    bloqueos: bloqueos,
    avisos: [
      if (bloqueos.isEmpty && queda > 0)
        'Queda un saldo de ${formatoPesos(queda)}.',
    ],
  );
}

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Totales por medio de pago del día [dia] (pregunta 46): suman los recibos
/// de ese día que siguen vigentes (o que se anularon después de cerrarlo) y
/// restan los recibos de días ya cerrados que se anularon ese día.
Map<MedioPago, int> totalesDelDia(Iterable<Recibo> recibos, DateTime dia) {
  final t = {for (final m in MedioPago.values) m: 0};
  for (final r in recibos) {
    if (_mismoDia(r.fecha, dia) && (!r.anulado || r.anuladoTrasCierre)) {
      for (final p in r.pagos) {
        t[p.medio] = t[p.medio]! + p.valor;
      }
    }
    if (r.anuladoTrasCierre && _mismoDia(r.anuladoEn!, dia)) {
      for (final p in r.pagos) {
        t[p.medio] = t[p.medio]! - p.valor;
      }
    }
  }
  return t;
}

/// Una fila del informe del mes.
class FilaInforme {
  const FilaInforme({
    required this.concepto,
    required this.linea,
    required this.cantidad,
    required this.bruto,
    required this.descuentos,
  });

  final String concepto;
  final String linea;
  final int cantidad;
  final int bruto;
  final int descuentos;

  int get neto => bruto - descuentos;
}

/// Informe mensual (pregunta 47): lo cobrado por servicio y por línea en el
/// mes (cobros vigentes), y lo recaudado por medio de pago (con la regla de
/// las anulaciones del cierre).
class InformeMes {
  const InformeMes({
    required this.anio,
    required this.mes,
    required this.porServicio,
    required this.porLinea,
    required this.recaudo,
    required this.creditosAplicados,
  });

  final int anio;
  final int mes;
  final List<FilaInforme> porServicio;
  final List<FilaInforme> porLinea;
  final Map<MedioPago, int> recaudo;
  final int creditosAplicados;

  int get totalNeto => porServicio.fold(0, (s, f) => s + f.neto);
  int get totalRecaudo => recaudo.values.fold(0, (s, v) => s + v);
}

InformeMes informeDelMes({
  required int anio,
  required int mes,
  required Iterable<Cobro> cobros,
  required Iterable<Recibo> recibos,
  required Map<String, Servicio> servicios,
}) {
  bool delMes(DateTime f) => f.year == anio && f.month == mes;
  final porServicio = <String, FilaInforme>{};
  final porLinea = <String, FilaInforme>{};
  var creditos = 0;
  void sumar(
    Map<String, FilaInforme> m,
    String clave,
    String concepto,
    String linea,
    ItemCobro i,
  ) {
    final a = m[clave];
    m[clave] = FilaInforme(
      concepto: concepto,
      linea: linea,
      cantidad: (a?.cantidad ?? 0) + i.cantidad,
      bruto: (a?.bruto ?? 0) + i.bruto,
      descuentos: (a?.descuentos ?? 0) + i.descuento,
    );
  }

  for (final c in cobros) {
    if (c.anulado || !delMes(c.fecha)) continue;
    creditos += c.credito;
    for (final i in c.items) {
      final s = servicios[i.servicioId];
      final linea = s?.linea.etiqueta ?? 'Sin línea';
      sumar(porServicio, i.servicioId, s?.nombre ?? i.descripcion, linea, i);
      sumar(porLinea, linea, linea, linea, i);
    }
  }
  final recaudo = {for (final m in MedioPago.values) m: 0};
  for (var d = 1; d <= DateTime(anio, mes + 1, 0).day; d++) {
    totalesDelDia(recibos, DateTime(anio, mes, d)).forEach((m, v) {
      recaudo[m] = recaudo[m]! + v;
    });
  }
  int porNombre(FilaInforme a, FilaInforme b) =>
      a.concepto.compareTo(b.concepto);
  return InformeMes(
    anio: anio,
    mes: mes,
    porServicio: porServicio.values.toList()..sort(porNombre),
    porLinea: porLinea.values.toList()..sort(porNombre),
    recaudo: recaudo,
    creditosAplicados: creditos,
  );
}

String _campo(Object v) {
  final t = '$v';
  return RegExp(r'[;"\r\n]').hasMatch(t) ? '"${t.replaceAll('"', '""')}"' : t;
}

/// CSV para Excel en español (pregunta 47): separador «;», UTF-8 con BOM
/// y fin de línea CRLF. Los valores en pesos van sin separador de miles.
List<int> csvDeFilas(List<List<Object>> filas) {
  final texto = filas.map((f) => f.map(_campo).join(';')).join('\r\n');
  return [0xEF, 0xBB, 0xBF, ...utf8.encode('$texto\r\n')];
}

/// Una fila del volumen por técnica (valoraciones y sesiones selladas).
typedef VolumenTecnica = ({String tecnica, int valoraciones, int sesiones});

/// El informe del mes en CSV, con el volumen por técnica al final.
List<int> csvInforme(InformeMes i, {List<VolumenTecnica> volumen = const []}) {
  final mes = '${i.anio}-${i.mes.toString().padLeft(2, '0')}';
  return csvDeFilas([
    [
      'Mes',
      'Sección',
      'Concepto',
      'Línea',
      'Cantidad',
      'Bruto',
      'Descuentos',
      'Neto',
    ],
    for (final f in i.porServicio)
      [
        mes,
        'Servicio',
        f.concepto,
        f.linea,
        f.cantidad,
        f.bruto,
        f.descuentos,
        f.neto,
      ],
    for (final f in i.porLinea)
      [
        mes,
        'Línea',
        f.concepto,
        f.linea,
        f.cantidad,
        f.bruto,
        f.descuentos,
        f.neto,
      ],
    [
      mes,
      'Créditos aplicados',
      'Valoraciones abonadas',
      '',
      '',
      '',
      i.creditosAplicados,
      -i.creditosAplicados,
    ],
    for (final e in i.recaudo.entries)
      [mes, 'Recaudo', e.key.etiqueta, '', '', '', '', e.value],
    for (final v in volumen) ...[
      [mes, 'Valoraciones', v.tecnica, 'Estética', v.valoraciones, '', '', ''],
      [mes, 'Sesiones', v.tecnica, 'Estética', v.sesiones, '', '', ''],
    ],
  ]);
}

/// «2026-11-21» para nombres de archivo.
String diaIso(DateTime d) => fechaIso(d);
