import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/modelos/foto.dart';
import '../../../core/utils/fechas.dart';
import '../estado/consultorio_provider.dart';

/// Guía de encuadre (pregunta 19): eje vertical y líneas de hombros,
/// ombligo y caderas, para que las fotos de distintas fechas se puedan
/// comparar.
class GuiaEncuadre extends StatelessWidget {
  const GuiaEncuadre({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _PintorGuia(DefaultTextStyle.of(context).style),
      size: Size.infinite,
    ),
  );
}

class _PintorGuia extends CustomPainter {
  _PintorGuia(this.estilo);

  final TextStyle estilo;

  static const lineas = [
    (0.22, 'hombros'),
    (0.47, 'ombligo'),
    (0.58, 'caderas'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5;
    final sombra = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 3;
    void discontinua(Offset a, Offset b) {
      final largo = (b - a).distance;
      final dir = (b - a) / largo;
      for (var t = 0.0; t < largo; t += 12) {
        final p = a + dir * t;
        final q = a + dir * (t + 7 < largo ? t + 7 : largo);
        canvas
          ..drawLine(p, q, sombra)
          ..drawLine(p, q, pincel);
      }
    }

    discontinua(Offset(size.width / 2, 0), Offset(size.width / 2, size.height));
    for (final (y, nombre) in lineas) {
      final yy = size.height * y;
      discontinua(Offset(0, yy), Offset(size.width, yy));
      final t = TextPainter(
        text: TextSpan(
          text: ' $nombre ',
          style: estilo.copyWith(
            fontSize: 11,
            color: Colors.white,
            backgroundColor: Colors.black.withValues(alpha: 0.55),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(canvas, Offset(6, yy - t.height - 2));
    }
  }

  @override
  bool shouldRepaint(_PintorGuia anterior) => false;
}

/// Una foto del almacén, descifrada solo mientras se muestra.
class FotoCifrada extends ConsumerStatefulWidget {
  const FotoCifrada({
    super.key,
    required this.foto,
    this.miniatura = false,
    this.fit = BoxFit.contain,
    this.opacidad = 1,
  });

  final Foto foto;
  final bool miniatura;
  final BoxFit fit;
  final double opacidad;

  @override
  ConsumerState<FotoCifrada> createState() => _FotoCifradaState();
}

class _FotoCifradaState extends ConsumerState<FotoCifrada> {
  late Future<Uint8List?> _bytes = _leer();

  Future<Uint8List?> _leer() {
    final s = ref.read(servicioConsultorioProvider).seguimiento;
    return widget.miniatura
        ? s.miniatura(widget.foto.id)
        : s.bytesFoto(widget.foto.id);
  }

  @override
  void didUpdateWidget(FotoCifrada anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.foto.id != widget.foto.id ||
        anterior.miniatura != widget.miniatura) {
      _bytes = _leer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '${widget.foto.titulo}, ${formatoFecha(widget.foto.fecha)}',
      child: FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (context, s) {
          final b = s.data;
          if (b == null) {
            return const ColoredBox(
              color: ColoresMarca.bloqueado,
              child: Center(
                child: Icon(
                  Icons.photo_outlined,
                  color: ColoresMarca.textoSuave,
                ),
              ),
            );
          }
          return Opacity(
            opacity: widget.opacidad,
            child: Image.memory(
              b,
              fit: widget.fit,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          );
        },
      ),
    );
  }
}
