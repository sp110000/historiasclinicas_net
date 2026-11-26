import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Ilustraciones de la marca (docs/REDISENO.md): mancha cálida de fondo,
/// formas blancas con trazo de tinta y acentos naranjas. Vectoriales y
/// dibujadas aquí mismo, sin archivos ni conexión. Son decorativas: no
/// llevan texto para el lector de pantalla (lo dice el texto de al lado).
enum Ilustracion {
  /// Portapapeles con el pulso: el siguiente paciente.
  consulta,

  /// Calendario y taza: un día sin más citas.
  agendaLibre,

  /// Ficha y lupa: sin pacientes o sin resultados.
  sinResultados,

  /// Escudo con candado: el consultorio cifrado.
  candado,

  /// Círculo con el chulo: todo al día.
  listo,

  /// Billetera con monedas: la caja.
  caja,

  /// Caja de insumos: el inventario.
  inventario,
}

/// Una [Ilustracion] de [alto] píxeles (el ancho es 4/3 del alto).
class IlustracionMarca extends StatelessWidget {
  const IlustracionMarca(this.tipo, {super.key, this.alto = 120});

  final Ilustracion tipo;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: alto * 4 / 3,
        height: alto,
        child: CustomPaint(painter: _Pintor(tipo)),
      ),
    );
  }
}

/// Estado vacío con ilustración, título, texto y acciones, centrado.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.ilustracion,
    required this.titulo,
    this.texto,
    this.acciones = const [],
    this.alto = 110,
  });

  final Ilustracion ilustracion;
  final String titulo;
  final String? texto;
  final List<Widget> acciones;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IlustracionMarca(ilustracion, alto: alto),
        const SizedBox(height: 12),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ColoresMarca.tinta,
          ),
        ),
        if (texto != null) ...[
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              texto!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColoresMarca.textoSuave),
            ),
          ),
        ],
        if (acciones.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: acciones,
          ),
        ],
      ],
    );
  }
}

// Colores de las ilustraciones.
const _mancha = Color(0xFFFCE6DE);
const _manchaVerde = Color(0xFFE3F1E7);
const _medio = Color(0xFFFBB9AB);
const _linea = Color(0xFFF3ECE7);
const _oro = Color(0xFFF4C76B);
const _oroOscuro = Color(0xFFC9962F);

class _Pintor extends CustomPainter {
  const _Pintor(this.tipo);

  final Ilustracion tipo;

  @override
  void paint(Canvas canvas, Size size) {
    // Se dibuja en un lienzo de 200 × 150 y se escala.
    final e = size.width / 200;
    canvas.save();
    canvas.scale(e, size.height / 150);
    final p = _Lapiz(canvas, e);
    switch (tipo) {
      case Ilustracion.consulta:
        _consulta(p);
      case Ilustracion.agendaLibre:
        _agendaLibre(p);
      case Ilustracion.sinResultados:
        _sinResultados(p);
      case Ilustracion.candado:
        _candado(p);
      case Ilustracion.listo:
        _listo(p);
      case Ilustracion.caja:
        _caja(p);
      case Ilustracion.inventario:
        _inventario(p);
    }
    canvas.restore();
  }

  void _consulta(_Lapiz p) {
    p.mancha(_mancha);
    p.hoja(const Offset(150, 128), derecha: true);
    p.rect(const Rect.fromLTRB(66, 34, 134, 132), 12, Colors.white);
    p.rect(const Rect.fromLTRB(84, 26, 116, 42), 7, ColoresMarca.marca);
    p.trazo(
      const [
        Offset(76, 76),
        Offset(88, 76),
        Offset(93, 64),
        Offset(100, 90),
        Offset(106, 70),
        Offset(110, 78),
        Offset(124, 78),
      ],
      ColoresMarca.marca,
      3.5,
    );
    for (final (y, w) in [(96.0, 44.0), (108.0, 32.0), (120.0, 38.0)]) {
      p.relleno(Rect.fromLTWH(78, y, w, 6), 3, _linea);
    }
    p.circulo(const Offset(40, 46), 15, Colors.white);
    p.trazo(
      const [Offset(40, 37), Offset(40, 46), Offset(47, 51)],
      ColoresMarca.tinta,
      2.5,
    );
    p.punto(const Offset(172, 36), 6, ColoresMarca.marca);
    p.punto(const Offset(24, 118), 4, _medio);
  }

  void _agendaLibre(_Lapiz p) {
    p.mancha(_mancha);
    p.hoja(const Offset(46, 130), derecha: false);
    const cal = Rect.fromLTRB(54, 36, 138, 124);
    p.rect(cal, 14, Colors.white, borde: false);
    p.canvas.save();
    p.canvas.clipRRect(RRect.fromRectAndRadius(cal, const Radius.circular(14)));
    p.canvas.drawRect(
      const Rect.fromLTRB(54, 36, 138, 58),
      Paint()..color = ColoresMarca.marca,
    );
    p.canvas.restore();
    p.rect(cal, 14, null);
    p.linea(const Offset(54, 58), const Offset(138, 58), 2.5);
    for (final x in [74.0, 116.0]) {
      p.rect(Rect.fromLTWH(x, 28, 8, 18), 4, Colors.white);
    }
    for (var f = 0; f < 3; f++) {
      for (var c = 0; c < 4; c++) {
        p.relleno(
          Rect.fromLTWH(66.0 + c * 17, 70.0 + f * 16, 11, 8),
          3,
          f == 1 && c == 2 ? _medio : _linea,
        );
      }
    }
    // Taza: día libre.
    p.rect(const Rect.fromLTRB(140, 96, 168, 128), 6, Colors.white);
    p.arco(const Rect.fromLTRB(160, 102, 178, 120), -1.4, 2.8);
    for (final x in [148.0, 158.0]) {
      p.curva(Offset(x, 90), Offset(x - 5, 82), Offset(x + 4, 76), _medio);
    }
    p.punto(const Offset(168, 40), 6, ColoresMarca.marca);
  }

  void _sinResultados(_Lapiz p) {
    p.mancha(_mancha);
    p.rect(const Rect.fromLTRB(46, 36, 128, 120), 12, Colors.white);
    p.punto(const Offset(87, 64), 12, _linea);
    p.relleno(const Rect.fromLTWH(66, 80, 42, 14), 7, _linea);
    p.relleno(const Rect.fromLTWH(60, 102, 54, 6), 3, _linea);
    p.circulo(const Offset(132, 96), 22, Colors.white, ancho: 3);
    p.arco(
      const Rect.fromLTRB(118, 82, 146, 110),
      3.4,
      1.4,
      ColoresMarca.marca,
    );
    p.linea(const Offset(148, 112), const Offset(168, 132), 7);
    p.punto(const Offset(164, 40), 6, ColoresMarca.marca);
    p.punto(const Offset(30, 110), 4, _medio);
  }

  void _candado(_Lapiz p) {
    p.mancha(_mancha);
    p.hoja(const Offset(148, 130), derecha: true);
    final escudo = Path()
      ..moveTo(100, 22)
      ..lineTo(144, 38)
      ..lineTo(144, 76)
      ..cubicTo(144, 106, 124, 126, 100, 136)
      ..cubicTo(76, 126, 56, 106, 56, 76)
      ..lineTo(56, 38)
      ..close();
    p.camino(escudo, Colors.white);
    final aro = Path()
      ..moveTo(88, 76)
      ..lineTo(88, 66)
      ..arcToPoint(const Offset(112, 66), radius: const Radius.circular(12))
      ..lineTo(112, 76);
    p.camino(aro, null, ancho: 3.5);
    p.rect(const Rect.fromLTRB(80, 74, 120, 106), 7, ColoresMarca.marca);
    p.punto(const Offset(100, 88), 4, Colors.white);
    p.relleno(const Rect.fromLTWH(98, 88, 4, 9), 2, Colors.white);
    p.punto(const Offset(40, 40), 6, ColoresMarca.marca);
    p.punto(const Offset(168, 44), 4, _medio);
  }

  void _listo(_Lapiz p) {
    p.mancha(_manchaVerde);
    p.circulo(const Offset(100, 78), 36, Colors.white);
    p.trazo(
      const [Offset(84, 79), Offset(96, 91), Offset(118, 67)],
      ColoresMarca.estadoOk,
      6,
    );
    for (final (c, r) in [
      (const Offset(152, 40), 7.0),
      (const Offset(48, 50), 5.0),
      (const Offset(156, 118), 4.0),
    ]) {
      p.estrella(c, r);
    }
  }

  void _caja(_Lapiz p) {
    p.mancha(_mancha);
    p.rect(const Rect.fromLTRB(52, 56, 148, 126), 14, ColoresMarca.marca);
    p.rect(const Rect.fromLTRB(52, 56, 148, 76), 10, _medio);
    p.circulo(const Offset(128, 100), 7, Colors.white);
    p.circulo(const Offset(68, 40), 14, _oro);
    p.circulo(const Offset(68, 40), 8, null, color: _oroOscuro, ancho: 2);
    p.circulo(const Offset(150, 34), 9, _oro);
    p.punto(const Offset(30, 110), 4, _medio);
  }

  void _inventario(_Lapiz p) {
    p.mancha(_mancha);
    p.hoja(const Offset(152, 130), derecha: true);
    final tapa = Path()
      ..moveTo(58, 56)
      ..lineTo(100, 38)
      ..lineTo(142, 56)
      ..lineTo(100, 74)
      ..close();
    final izquierda = Path()
      ..moveTo(58, 56)
      ..lineTo(100, 74)
      ..lineTo(100, 126)
      ..lineTo(58, 108)
      ..close();
    final derecha = Path()
      ..moveTo(100, 74)
      ..lineTo(142, 56)
      ..lineTo(142, 108)
      ..lineTo(100, 126)
      ..close();
    p.camino(izquierda, Colors.white);
    p.camino(derecha, ColoresMarca.marca);
    p.camino(tapa, _medio);
    p.linea(const Offset(79, 47), const Offset(121, 65), 2.5);
    p.punto(const Offset(40, 44), 6, ColoresMarca.marca);
  }

  @override
  bool shouldRepaint(_Pintor viejo) => viejo.tipo != tipo;
}

/// Atajos de dibujo con el trazo de tinta de la marca.
class _Lapiz {
  _Lapiz(this.canvas, this.escala);

  final Canvas canvas;
  final double escala;

  Paint _trazo(double ancho, [Color color = ColoresMarca.tinta]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = ancho
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void mancha(Color color) {
    final m = Path()
      ..moveTo(30, 90)
      ..cubicTo(20, 45, 60, 14, 110, 14)
      ..cubicTo(160, 14, 192, 44, 186, 86)
      ..cubicTo(180, 130, 140, 146, 100, 143)
      ..cubicTo(60, 140, 38, 125, 30, 90)
      ..close();
    canvas.drawPath(m, Paint()..color = color);
  }

  void hoja(Offset base, {required bool derecha}) {
    final s = derecha ? 1.0 : -1.0;
    final h = Path()
      ..moveTo(base.dx, base.dy)
      ..cubicTo(
        base.dx - 4 * s,
        base.dy - 32,
        base.dx + 12 * s,
        base.dy - 56,
        base.dx + 40 * s,
        base.dy - 64,
      )
      ..cubicTo(
        base.dx + 42 * s,
        base.dy - 32,
        base.dx + 26 * s,
        base.dy - 8,
        base.dx,
        base.dy,
      )
      ..close();
    canvas.drawPath(h, Paint()..color = _medio);
    final tallo = Path()
      ..moveTo(base.dx, base.dy)
      ..cubicTo(
        base.dx + 8 * s,
        base.dy - 20,
        base.dx + 20 * s,
        base.dy - 36,
        base.dx + 36 * s,
        base.dy - 50,
      );
    canvas.drawPath(tallo, _trazo(2.5));
  }

  /// Rectángulo redondeado con relleno [color] (o sin relleno) y trazo.
  void rect(Rect r, double radio, Color? color, {bool borde = true}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radio));
    if (color != null) canvas.drawRRect(rr, Paint()..color = color);
    if (borde) canvas.drawRRect(rr, _trazo(2.5));
  }

  void relleno(Rect r, double radio, Color color) => canvas.drawRRect(
    RRect.fromRectAndRadius(r, Radius.circular(radio)),
    Paint()..color = color,
  );

  void circulo(
    Offset c,
    double r,
    Color? fondo, {
    Color color = ColoresMarca.tinta,
    double ancho = 2.5,
  }) {
    if (fondo != null) canvas.drawCircle(c, r, Paint()..color = fondo);
    canvas.drawCircle(c, r, _trazo(ancho, color));
  }

  void punto(Offset c, double r, Color color) =>
      canvas.drawCircle(c, r, Paint()..color = color);

  void trazo(List<Offset> puntos, Color color, double ancho) {
    final t = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (final q in puntos.skip(1)) {
      t.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(t, _trazo(ancho, color));
  }

  void linea(Offset a, Offset b, double ancho) =>
      canvas.drawLine(a, b, _trazo(ancho));

  void arco(
    Rect r,
    double inicio,
    double barrido, [
    Color color = ColoresMarca.tinta,
  ]) => canvas.drawArc(r, inicio, barrido, false, _trazo(2.5, color));

  void curva(Offset a, Offset c, Offset b, Color color) => canvas.drawPath(
    Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(c.dx, c.dy, b.dx, b.dy),
    _trazo(2.5, color),
  );

  void camino(Path c, Color? color, {double ancho = 2.5}) {
    if (color != null) canvas.drawPath(c, Paint()..color = color);
    canvas.drawPath(c, _trazo(ancho));
  }

  /// Destello de cuatro puntas.
  void estrella(Offset c, double r) {
    final e = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(e, Paint()..color = ColoresMarca.marca);
  }
}
