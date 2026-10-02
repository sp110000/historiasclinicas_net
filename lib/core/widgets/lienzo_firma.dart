import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/tema.dart';
import '../imagenes/procesar_imagen.dart';

/// Color de tinta de la firma dibujada (azul oscuro, se imprime bien en B/N).
const tintaFirma = Color(0xFF14285A);

/// Trazos de una firma dibujada en pantalla.
class ControladorFirma extends ChangeNotifier {
  final List<List<Offset>> _trazos = [];

  List<List<Offset>> get trazos => List.unmodifiable(_trazos);

  bool get vacio => _trazos.isEmpty;

  void empezar(Offset punto) {
    _trazos.add([punto]);
    notifyListeners();
  }

  void continuar(Offset punto) {
    if (_trazos.isEmpty) return;
    final ultimo = _trazos.last;
    // Ignora movimientos mínimos (ruido del puntero).
    if ((ultimo.last - punto).distance < 0.8) return;
    ultimo.add(punto);
    notifyListeners();
  }

  void deshacer() {
    if (_trazos.isEmpty) return;
    _trazos.removeLast();
    notifyListeners();
  }

  void limpiar() {
    _trazos.clear();
    notifyListeners();
  }

  /// PNG con fondo transparente, recortado a los trazos y a [escala]x para
  /// que se imprima nítido. `null` si no hay trazos.
  Future<Uint8List?> exportarPng({
    double escala = 3,
    double grosor = 2.6,
  }) async {
    if (_trazos.isEmpty) return null;
    var izq = double.infinity, arr = double.infinity;
    var der = -double.infinity, aba = -double.infinity;
    for (final t in _trazos) {
      for (final p in t) {
        izq = math.min(izq, p.dx);
        arr = math.min(arr, p.dy);
        der = math.max(der, p.dx);
        aba = math.max(aba, p.dy);
      }
    }
    final margen = grosor + 2;
    final caja = Rect.fromLTRB(
      izq - margen,
      arr - margen,
      der + margen,
      aba + margen,
    );
    final ancho = (caja.width * escala).ceil();
    final alto = (caja.height * escala).ceil();

    final grabadora = ui.PictureRecorder();
    final lienzo = Canvas(grabadora)
      ..scale(escala)
      ..translate(-caja.left, -caja.top);
    pintarTrazos(lienzo, _trazos, grosor: grosor, color: tintaFirma);
    final imagen = await grabadora.endRecording().toImage(ancho, alto);
    return aPng(imagen);
  }
}

/// Dibuja los trazos suavizados (curvas por los puntos medios).
void pintarTrazos(
  Canvas lienzo,
  List<List<Offset>> trazos, {
  required double grosor,
  required Color color,
}) {
  final pincel = Paint()
    ..color = color
    ..strokeWidth = grosor
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  for (final t in trazos) {
    if (t.length == 1) {
      lienzo.drawCircle(t.first, grosor / 2, Paint()..color = color);
      continue;
    }
    final camino = Path()..moveTo(t.first.dx, t.first.dy);
    for (var i = 1; i < t.length - 1; i++) {
      final medio = Offset.lerp(t[i], t[i + 1], 0.5)!;
      camino.quadraticBezierTo(t[i].dx, t[i].dy, medio.dx, medio.dy);
    }
    camino.lineTo(t.last.dx, t.last.dy);
    lienzo.drawPath(camino, pincel);
  }
}

/// Área para firmar con el ratón, el dedo o un lápiz.
class LienzoFirma extends StatelessWidget {
  const LienzoFirma({super.key, required this.controlador, this.alto = 220});

  final ControladorFirma controlador;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Área para dibujar la firma',
      child: Container(
        height: alto,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColoresMarca.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => controlador.empezar(e.localPosition),
          onPointerMove: (e) => controlador.continuar(e.localPosition),
          child: ListenableBuilder(
            listenable: controlador,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _PintorFirma(
                controlador.trazos,
                // Con la fuente de la app: sin ella el motor web buscaría
                // una fuente de respaldo en internet.
                estiloPista: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: ColoresMarca.textoSuave,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorFirma extends CustomPainter {
  _PintorFirma(this.trazos, {required this.estiloPista});

  final List<List<Offset>> trazos;
  final TextStyle estiloPista;

  @override
  void paint(Canvas canvas, Size size) {
    // Línea guía (no se exporta).
    final y = size.height * 0.72;
    final guia = Paint()
      ..color = ColoresMarca.borde
      ..strokeWidth = 1.2;
    for (var x = 24.0; x < size.width - 24; x += 10) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), guia);
    }
    if (trazos.isEmpty) {
      final texto = TextPainter(
        text: TextSpan(text: 'Firma aquí', style: estiloPista),
        textDirection: TextDirection.ltr,
      )..layout();
      texto.paint(canvas, Offset(24, y - texto.height - 8));
    }
    pintarTrazos(canvas, trazos, grosor: 2.6, color: tintaFirma);
  }

  @override
  bool shouldRepaint(_PintorFirma old) => true;
}
