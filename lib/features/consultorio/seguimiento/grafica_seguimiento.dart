import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/tema.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/utils/numeros.dart';

/// Un punto de la gráfica: fecha y valor.
typedef PuntoSeguimiento = ({DateTime fecha, double valor});

/// Gráfica de líneas del seguimiento (peso, IMC, cintura…), dibujada con
/// `CustomPainter`: línea en el color principal (≥ 3:1), textos en el gris
/// del tema (≥ 4,5:1) y una línea de meta opcional, punteada.
class GraficaSeguimiento extends StatelessWidget {
  const GraficaSeguimiento({
    super.key,
    required this.puntos,
    required this.nombre,
    required this.unidad,
    this.meta,
    this.decimales,
    this.alto = 220,
  });

  final List<PuntoSeguimiento> puntos;
  final String nombre;
  final String unidad;
  final double? meta;
  final int? decimales;
  final double alto;

  String _valor(double v) => formatoNumero(v, decimales: decimales);

  @override
  Widget build(BuildContext context) {
    final descripcion = puntos.isEmpty
        ? '$nombre: sin datos'
        : puntos.length == 1
        ? '$nombre: ${_valor(puntos.single.valor)} $unidad el '
              '${formatoFecha(puntos.single.fecha)}'
        : '$nombre: de ${_valor(puntos.first.valor)} a '
              '${_valor(puntos.last.valor)} $unidad, entre el '
              '${formatoFecha(puntos.first.fecha)} y el '
              '${formatoFecha(puntos.last.fecha)} (${puntos.length} '
              'mediciones)';
    return Semantics(
      container: true,
      label: descripcion,
      excludeSemantics: true,
      child: SizedBox(
        height: alto,
        width: double.infinity,
        child: puntos.isEmpty
            ? const Center(
                child: Text(
                  'Sin mediciones para graficar.',
                  style: TextStyle(color: ColoresMarca.textoSuave),
                ),
              )
            : CustomPaint(
                painter: _Pintor(
                  puntos: puntos,
                  meta: meta,
                  formato: _valor,
                  estiloTexto: DefaultTextStyle.of(context).style.copyWith(
                    fontSize: 11,
                    color: ColoresMarca.textoSuave,
                  ),
                ),
              ),
      ),
    );
  }
}

class _Pintor extends CustomPainter {
  _Pintor({
    required this.puntos,
    required this.meta,
    required this.formato,
    required this.estiloTexto,
  });

  final List<PuntoSeguimiento> puntos;
  final double? meta;
  final String Function(double) formato;
  final TextStyle estiloTexto;

  TextPainter _texto(String t) => TextPainter(
    text: TextSpan(text: t, style: estiloTexto),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final valores = [for (final p in puntos) p.valor, ?meta];
    var minimo = valores.reduce(math.min);
    var maximo = valores.reduce(math.max);
    if (maximo - minimo < 1e-9) {
      minimo -= 1;
      maximo += 1;
    }
    final margenValor = (maximo - minimo) * 0.12;
    minimo -= margenValor;
    maximo += margenValor;

    final etiquetaMax = _texto(formato(maximo));
    final etiquetaMin = _texto(formato(minimo));
    final izquierda = math.max(etiquetaMax.width, etiquetaMin.width) + 8;
    const abajo = 20.0;
    const arriba = 6.0;
    const derecha = 12.0;
    final area = Rect.fromLTRB(
      izquierda,
      arriba,
      size.width - derecha,
      size.height - abajo,
    );

    final guia = Paint()
      ..color = ColoresMarca.borde
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = area.top + area.height * i / 3;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), guia);
    }
    etiquetaMax.paint(canvas, Offset(0, area.top - etiquetaMax.height / 2));
    etiquetaMin.paint(canvas, Offset(0, area.bottom - etiquetaMin.height / 2));

    final t0 = puntos.first.fecha.millisecondsSinceEpoch.toDouble();
    final t1 = puntos.last.fecha.millisecondsSinceEpoch.toDouble();
    double x(DateTime f) => puntos.length == 1 || t1 == t0
        ? area.center.dx
        : area.left + (f.millisecondsSinceEpoch - t0) / (t1 - t0) * area.width;
    double y(double v) =>
        area.bottom - (v - minimo) / (maximo - minimo) * area.height;

    // Meta, punteada.
    if (meta != null) {
      final m = meta!;
      final pincel = Paint()
        ..color = ColoresMarca.estadoOk
        ..strokeWidth = 1.5;
      for (var xi = area.left; xi < area.right; xi += 10) {
        canvas.drawLine(
          Offset(xi, y(m)),
          Offset(math.min(xi + 5, area.right), y(m)),
          pincel,
        );
      }
      final t = _texto('meta ${formato(m)}');
      t.paint(canvas, Offset(area.right - t.width, y(m) - t.height - 2));
    }

    final linea = Paint()
      ..color = ColoresMarca.primario
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final camino = Path();
    for (final (i, p) in puntos.indexed) {
      final o = Offset(x(p.fecha), y(p.valor));
      i == 0 ? camino.moveTo(o.dx, o.dy) : camino.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(camino, linea);
    final punto = Paint()..color = ColoresMarca.primario;
    final fondo = Paint()..color = Colors.white;
    for (final p in puntos) {
      final o = Offset(x(p.fecha), y(p.valor));
      canvas
        ..drawCircle(o, 4.5, punto)
        ..drawCircle(o, 2, fondo);
    }

    // Fechas de la primera y la última.
    final f0 = _texto(formatoFecha(puntos.first.fecha));
    f0.paint(canvas, Offset(area.left, area.bottom + 4));
    if (puntos.length > 1) {
      final f1 = _texto(formatoFecha(puntos.last.fecha));
      f1.paint(canvas, Offset(area.right - f1.width, area.bottom + 4));
    }
  }

  @override
  bool shouldRepaint(_Pintor anterior) =>
      anterior.puntos != puntos || anterior.meta != meta;
}
