import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cie10/catalogo_cie10.dart';
import '../../../core/consultorio/documentos/documento_clinico.dart';
import '../../../core/widgets/campo_sugerencias.dart';
import '../../cie10/cie10_provider.dart';

/// Diagnóstico con el buscador CIE-10 de la historia: la descripción busca
/// desde 3 letras y el código desde «letra + número». El catálogo se carga
/// la primera vez que se entra a uno de los dos campos.
class CampoDiagnostico extends ConsumerStatefulWidget {
  const CampoDiagnostico({
    super.key,
    required this.valor,
    required this.alCambiar,
    this.etiqueta = 'Diagnóstico',
    this.requerido = false,
  });

  final DiagnosticoDocumento valor;
  final ValueChanged<DiagnosticoDocumento> alCambiar;
  final String etiqueta;
  final bool requerido;

  @override
  ConsumerState<CampoDiagnostico> createState() => _CampoDiagnosticoState();
}

class _CampoDiagnosticoState extends ConsumerState<CampoDiagnostico> {
  late final _descripcion = TextEditingController(
    text: widget.valor.descripcion,
  );
  late final _codigo = TextEditingController(text: widget.valor.codigo);
  final _focoDescripcion = FocusNode();
  final _focoCodigo = FocusNode();
  var _usarCatalogo = false;

  @override
  void initState() {
    super.initState();
    _focoDescripcion.addListener(_activar);
    _focoCodigo.addListener(_activar);
  }

  void _activar() {
    if (_usarCatalogo) return;
    if (_focoDescripcion.hasFocus || _focoCodigo.hasFocus) {
      setState(() => _usarCatalogo = true);
    }
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _codigo.dispose();
    _focoDescripcion.dispose();
    _focoCodigo.dispose();
    super.dispose();
  }

  void _elegir(EntradaCie10 e) {
    for (final (c, t) in [(_descripcion, e.descripcion), (_codigo, e.codigo)]) {
      c.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    }
    widget.alCambiar(
      DiagnosticoDocumento(codigo: e.codigo, descripcion: e.descripcion),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = _usarCatalogo
        ? ref.watch(catalogoCie10Provider).value
        : null;
    final descripcion = CampoSugerencias<EntradaCie10>(
      etiqueta: widget.etiqueta,
      requerido: widget.requerido,
      controller: _descripcion,
      foco: _focoDescripcion,
      mayusculas: TextCapitalization.sentences,
      sugerencias: (q) => catalogo == null || q.trim().length < 3
          ? const []
          : catalogo.buscar(q, maximo: 8),
      texto: (e) => e.descripcion,
      detalle: (e) => 'CIE-10 ${e.codigo}',
      alElegir: _elegir,
      alCambiar: (v) => widget.alCambiar(
        DiagnosticoDocumento(codigo: _codigo.text.trim(), descripcion: v),
      ),
    );
    final codigo = CampoSugerencias<EntradaCie10>(
      etiqueta: 'CIE-10',
      pista: 'J029',
      controller: _codigo,
      foco: _focoCodigo,
      mayusculas: TextCapitalization.characters,
      sugerencias: (q) =>
          catalogo == null || !RegExp(r'^[A-Za-z]\d').hasMatch(q.trim())
          ? const []
          : catalogo.buscar(q, maximo: 8),
      texto: (e) => e.codigo,
      detalle: (e) => e.descripcion,
      alElegir: _elegir,
      alCambiar: (v) => widget.alCambiar(
        DiagnosticoDocumento(codigo: v.trim(), descripcion: _descripcion.text),
      ),
    );
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < 480
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [descripcion, const SizedBox(height: 12), codigo],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: descripcion),
                const SizedBox(width: 10),
                SizedBox(width: 130, child: codigo),
              ],
            ),
    );
  }
}
