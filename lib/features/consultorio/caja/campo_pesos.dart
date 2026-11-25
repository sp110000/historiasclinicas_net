import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// `80000` → `80.000` (sin el signo).
String milesPesos(int v) {
  final t = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < t.length; i++) {
    if (i > 0 && (t.length - i) % 3 == 0) b.write('.');
    b.write(t[i]);
  }
  return '${v < 0 ? '-' : ''}$b';
}

/// Lee `80.000` (o `80000`) como 80000; vacío es `null`.
int? leerPesos(String t) {
  final d = t.replaceAll(RegExp(r'[^0-9]'), '');
  return d.isEmpty ? null : int.tryParse(d);
}

/// Deja solo dígitos y pone el separador de miles mientras se escribe.
class _FormatoMiles extends TextInputFormatter {
  const _FormatoMiles();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    final v = leerPesos(nuevo.text);
    final texto = v == null ? '' : milesPesos(v);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Un valor en pesos (entero, sin decimales), con «$» y miles.
class CampoPesos extends StatelessWidget {
  const CampoPesos({
    super.key,
    required this.etiqueta,
    required this.alCambiar,
    this.controller,
    this.valorInicial,
    this.requerido = false,
    this.ayuda,
    this.habilitado = true,
  });

  final String etiqueta;
  final ValueChanged<int?> alCambiar;
  final TextEditingController? controller;
  final int? valorInicial;
  final bool requerido;
  final String? ayuda;
  final bool habilitado;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    initialValue: controller == null && valorInicial != null
        ? milesPesos(valorInicial!)
        : null,
    enabled: habilitado,
    decoration: InputDecoration(
      labelText: requerido ? '$etiqueta *' : etiqueta,
      prefixText: r'$ ',
      helperText: ayuda,
      helperMaxLines: 3,
    ),
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.next,
    inputFormatters: [
      LengthLimitingTextInputFormatter(13),
      const _FormatoMiles(),
    ],
    onChanged: (t) => alCambiar(leerPesos(t)),
  );
}
