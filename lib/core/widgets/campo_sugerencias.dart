import 'package:flutter/material.dart';

import '../../app/tema.dart';
import '../utils/texto.dart';

String _normalizar(String t) =>
    sinTildes(t.toLowerCase()).replaceAll(RegExp('[^a-z0-9]+'), ' ').trim();

/// Filtra [opciones] por el comienzo de cualquier palabra, sin tildes.
List<String> filtrarOpciones(List<String> opciones, String consulta) {
  final q = _normalizar(consulta);
  if (q.isEmpty) return opciones;
  final resultado = opciones
      .where((o) => ' ${_normalizar(o)}'.contains(' $q'))
      .toList();
  // Si ya está escrita exactamente, no estorba con la lista.
  return resultado.length == 1 && _normalizar(resultado.single) == q
      ? const []
      : resultado;
}

/// Campo de texto libre con sugerencias desplegables.
class CampoSugerencias<T extends Object> extends StatefulWidget {
  const CampoSugerencias({
    super.key,
    required this.etiqueta,
    required this.controller,
    required this.sugerencias,
    required this.texto,
    required this.alCambiar,
    this.detalle,
    this.alElegir,
    this.requerido = false,
    this.mostrarError = false,
    this.pista,
    this.mayusculas = TextCapitalization.none,
    this.validador,
    this.foco,
  });

  final String etiqueta;
  final TextEditingController controller;
  final List<T> Function(String consulta) sugerencias;

  /// Texto que queda en el campo al elegir una opción.
  final String Function(T opcion) texto;

  /// Segunda línea de la opción (opcional).
  final String? Function(T opcion)? detalle;
  final ValueChanged<String> alCambiar;

  /// Por defecto, escribe [texto] y avisa con [alCambiar].
  final ValueChanged<T>? alElegir;
  final bool requerido;

  /// Marca el campo si es obligatorio y está vacío.
  final bool mostrarError;
  final String? pista;
  final TextCapitalization mayusculas;
  final FormFieldValidator<String>? validador;

  /// Foco propio (por ejemplo, para cargar algo al entrar al campo).
  final FocusNode? foco;

  @override
  State<CampoSugerencias<T>> createState() => _CampoSugerenciasState<T>();
}

class _CampoSugerenciasState<T extends Object>
    extends State<CampoSugerencias<T>> {
  FocusNode? _focoPropio;

  FocusNode get _foco => widget.foco ?? (_focoPropio ??= FocusNode());

  @override
  void dispose() {
    _focoPropio?.dispose();
    super.dispose();
  }

  void _elegir(T opcion) {
    final elegir = widget.alElegir;
    if (elegir != null) {
      elegir(opcion);
    } else {
      final t = widget.texto(opcion);
      widget.controller.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
      widget.alCambiar(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vacio = widget.controller.text.trim().isEmpty;
    return LayoutBuilder(
      builder: (context, restricciones) => RawAutocomplete<T>(
        textEditingController: widget.controller,
        focusNode: _foco,
        optionsBuilder: (valor) => widget.sugerencias(valor.text),
        displayStringForOption: widget.texto,
        onSelected: _elegir,
        fieldViewBuilder: (context, controller, foco, alEnviar) =>
            TextFormField(
              controller: controller,
              focusNode: foco,
              validator: widget.validador,
              textCapitalization: widget.mayusculas,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: widget.requerido
                    ? '${widget.etiqueta} *'
                    : widget.etiqueta,
                hintText: widget.pista,
                errorText: widget.requerido && widget.mostrarError && vacio
                    ? 'Obligatorio'
                    : null,
              ),
              onChanged: widget.alCambiar,
              onFieldSubmitted: (_) => alEnviar(),
            ),
        optionsViewBuilder: (context, elegir, opciones) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 280,
                maxWidth: restricciones.maxWidth.clamp(220, 520),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                children: [
                  for (final o in opciones)
                    InkWell(
                      onTap: () => elegir(o),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.texto(o)),
                            if (widget.detalle?.call(o) case final d?
                                when d.isNotEmpty)
                              Text(
                                d,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: ColoresMarca.textoSuave,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
