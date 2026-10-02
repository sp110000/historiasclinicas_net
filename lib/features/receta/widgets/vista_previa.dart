import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/pdf/receta_pdf.dart';
import '../estado/receta_controller.dart';

/// Vista previa de la receta: es el PDF real dibujado como imagen, así lo
/// que se ve es exactamente lo que se imprime. Se actualiza 300 ms después
/// del último cambio y mantiene la imagen anterior mientras tanto.
class VistaPreviaReceta extends ConsumerStatefulWidget {
  const VistaPreviaReceta({super.key});

  static const espera = Duration(milliseconds: 300);

  @override
  ConsumerState<VistaPreviaReceta> createState() => _VistaPreviaRecetaState();
}

class _VistaPreviaRecetaState extends ConsumerState<VistaPreviaReceta> {
  Timer? _temporizador;
  List<Uint8List> _paginas = const [];
  var _generando = false;
  Object? _error;
  var _zoom = 1.0;
  var _solicitud = 0;

  @override
  void initState() {
    super.initState();
    _programar(Duration.zero);
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  void _programar([Duration espera = VistaPreviaReceta.espera]) {
    _temporizador?.cancel();
    _temporizador = Timer(espera, _dibujar);
  }

  Future<void> _dibujar() async {
    final n = ++_solicitud;
    setState(() => _generando = true);
    try {
      final pdf = await generarPdfReceta(ref.read(documentoRecetaProvider));
      if (!mounted) return;
      final dpi = 96 * MediaQuery.devicePixelRatioOf(context).clamp(1.5, 2.5);
      final paginas = await ref.read(rasterizadorProvider)(pdf, dpi).toList();
      if (!mounted || n != _solicitud) return;
      setState(() {
        _paginas = paginas;
        _error = null;
        _generando = false;
      });
    } catch (e) {
      if (!mounted || n != _solicitud) return;
      setState(() {
        _error = e;
        _generando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(documentoRecetaProvider, (_, _) => _programar());
    final total = _paginas.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
          child: Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 18,
                color: ColoresMarca.textoSuave,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  total == 0
                      ? 'Vista previa · A5'
                      : 'Vista previa · A5 · '
                            '${total == 1 ? '1 hoja' : '$total hojas'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ColoresMarca.textoSuave,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Reducir',
                onPressed: _zoom <= 0.6
                    ? null
                    : () => setState(() => _zoom -= 0.2),
                icon: const Icon(Icons.zoom_out),
              ),
              Text(
                '${(_zoom * 100).round()} %',
                style: const TextStyle(
                  fontSize: 13,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              IconButton(
                tooltip: 'Ampliar',
                onPressed: _zoom >= 2
                    ? null
                    : () => setState(() => _zoom += 0.2),
                icon: const Icon(Icons.zoom_in),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 3,
          child: _generando ? const LinearProgressIndicator() : null,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final ancho = ((c.maxWidth - 40).clamp(200.0, 520.0)) * _zoom;
              if (_paginas.isEmpty) {
                return Center(
                  child: _error != null
                      ? _SinVistaPrevia(error: _error!)
                      : const CircularProgressIndicator(),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: c.maxWidth - 40),
                    child: Column(
                      children: [
                        if (_error != null)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'No se pudo actualizar la vista previa.',
                              style: TextStyle(color: ColoresMarca.error),
                            ),
                          ),
                        for (final (i, png) in _paginas.indexed)
                          Semantics(
                            label:
                                'Vista previa de la receta, hoja ${i + 1} '
                                'de $total',
                            image: true,
                            child: Container(
                              width: ancho,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x26000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Image.memory(
                                png,
                                fit: BoxFit.fitWidth,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SinVistaPrevia extends StatelessWidget {
  const _SinVistaPrevia({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: ColoresMarca.textoSuave,
            size: 36,
          ),
          const SizedBox(height: 8),
          const Text(
            'La vista previa no está disponible en este navegador.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Puedes imprimir o guardar el PDF igualmente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 6),
          Text(
            '$error',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: ColoresMarca.textoSuave,
            ),
          ),
        ],
      ),
    );
  }
}
