import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../receta/estado/receta_controller.dart' show rasterizadorProvider;

/// Vista previa de un PDF del consultorio: el PDF real dibujado como
/// imagen, como la de la receta. Se vuelve a generar 300 ms después de que
/// cambie [clave] y mantiene la imagen anterior mientras tanto.
class VistaPreviaPdf extends ConsumerStatefulWidget {
  const VistaPreviaPdf({
    super.key,
    required this.generar,
    required this.clave,
    this.formato = 'A4',
    this.descripcion = 'documento',
  });

  final Future<Uint8List> Function() generar;

  /// Cambia cuando cambia lo que se imprime.
  final Object clave;
  final String formato;

  /// Para el lector de pantalla: «Vista previa del documento, hoja 1 de 1».
  final String descripcion;

  static const espera = Duration(milliseconds: 300);

  @override
  ConsumerState<VistaPreviaPdf> createState() => _VistaPreviaPdfState();
}

class _VistaPreviaPdfState extends ConsumerState<VistaPreviaPdf> {
  Timer? _temporizador;
  List<Uint8List> _paginas = const [];
  var _generando = false;
  Object? _error;
  var _solicitud = 0;

  @override
  void initState() {
    super.initState();
    _programar(Duration.zero);
  }

  @override
  void didUpdateWidget(VistaPreviaPdf anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.clave != widget.clave) _programar();
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  void _programar([Duration espera = VistaPreviaPdf.espera]) {
    _temporizador?.cancel();
    _temporizador = Timer(espera, _dibujar);
  }

  Future<void> _dibujar() async {
    final n = ++_solicitud;
    setState(() => _generando = true);
    try {
      final pdf = await widget.generar();
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
    final total = _paginas.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                      ? 'Vista previa · ${widget.formato}'
                      : 'Vista previa · ${widget.formato} · '
                            '${total == 1 ? '1 hoja' : '$total hojas'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ColoresMarca.textoSuave,
                  ),
                ),
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
              if (_paginas.isEmpty) {
                return Center(
                  child: _error != null
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'La vista previa no está disponible en este '
                            'navegador. El PDF se genera igual al emitir.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const CircularProgressIndicator(),
                );
              }
              final ancho = (c.maxWidth - 32).clamp(200.0, 620.0);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Center(
                  child: Column(
                    children: [
                      for (final (i, png) in _paginas.indexed)
                        Semantics(
                          label:
                              'Vista previa del ${widget.descripcion}, hoja '
                              '${i + 1} de $total',
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
              );
            },
          ),
        ),
      ],
    );
  }
}
