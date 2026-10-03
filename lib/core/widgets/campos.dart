import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/tema.dart';
import '../clinica/rangos.dart';
import '../pais/perfil_pais.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';

String? _obligatorio(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Obligatorio' : null;

String _etiqueta(String etiqueta, bool requerido) =>
    requerido ? '$etiqueta *' : etiqueta;

/// Texto de una o varias líneas.
class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.etiqueta,
    required this.alCambiar,
    this.valorInicial,
    this.controller,
    this.requerido = false,
    this.lineas = 1,
    this.pista,
    this.ayuda,
    this.teclado,
    this.mayusculas = TextCapitalization.sentences,
  });

  final String etiqueta;
  final ValueChanged<String> alCambiar;
  final String? valorInicial;
  final TextEditingController? controller;
  final bool requerido;

  /// Líneas visibles; con más de una, el campo crece con el texto.
  final int lineas;
  final String? pista;
  final String? ayuda;
  final TextInputType? teclado;
  final TextCapitalization mayusculas;

  @override
  Widget build(BuildContext context) {
    final multilinea = lineas > 1;
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? valorInicial : null,
      decoration: InputDecoration(
        labelText: _etiqueta(etiqueta, requerido),
        hintText: pista,
        helperText: ayuda,
        alignLabelWithHint: multilinea,
      ),
      minLines: lineas,
      maxLines: multilinea ? null : 1,
      keyboardType: multilinea ? TextInputType.multiline : teclado,
      textInputAction: multilinea
          ? TextInputAction.newline
          : TextInputAction.next,
      textCapitalization: mayusculas,
      validator: requerido ? _obligatorio : null,
      onChanged: alCambiar,
    );
  }
}

// ─────────────────────────── Fecha y hora ───────────────────────────

/// Escribe "15031990" como "15/03/1990"; "9/" se completa como "09/".
class FormateadorFecha extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    final partes = nuevo.text.split('/');
    final b = StringBuffer();
    for (var i = 0; i < partes.length; i++) {
      var p = partes[i].replaceAll(RegExp(r'\D'), '');
      final cerrada = i < partes.length - 1;
      if (cerrada && i < 2 && p.length == 1) p = '0$p';
      b.write(p);
    }
    var digitos = b.toString();
    if (digitos.length > 8) digitos = digitos.substring(0, 8);
    final s = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      if (i == 2 || i == 4) s.write('/');
      s.write(digitos[i]);
    }
    if (nuevo.text.endsWith('/') &&
        (digitos.length == 2 || digitos.length == 4) &&
        nuevo.text.length > anterior.text.length) {
      s.write('/');
    }
    final texto = s.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// "15/03/1990" → fecha; `null` si está incompleta o no existe.
DateTime? leerFecha(String texto) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texto.trim());
  if (m == null) return null;
  final dia = int.parse(m.group(1)!);
  final mes = int.parse(m.group(2)!);
  final anio = int.parse(m.group(3)!);
  if (anio < 1900 || anio > 2100 || mes < 1 || mes > 12 || dia < 1) {
    return null;
  }
  if (dia > DateTime(anio, mes + 1, 0).day) return null;
  return DateTime(anio, mes, dia);
}

class CampoFecha extends StatefulWidget {
  const CampoFecha({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.alCambiar,
    this.requerido = false,
    this.primera,
    this.ultima,
    this.ayuda,
    this.habilitado = true,
  });

  final String etiqueta;
  final DateTime? valor;
  final ValueChanged<DateTime?> alCambiar;
  final bool requerido;
  final DateTime? primera;
  final DateTime? ultima;
  final String? ayuda;
  final bool habilitado;

  @override
  State<CampoFecha> createState() => _CampoFechaState();
}

class _CampoFechaState extends State<CampoFecha> {
  late final _controller = TextEditingController(
    text: widget.valor == null ? '' : formatoFecha(widget.valor!),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime get _primera => widget.primera ?? DateTime(1900);
  DateTime get _ultima => widget.ultima ?? DateTime(2100, 12, 31);

  String? _validar(String? texto) {
    final t = texto?.trim() ?? '';
    if (t.isEmpty) return widget.requerido ? 'Obligatorio' : null;
    final f = leerFecha(t);
    if (f == null) return 'Fecha no válida (dd/mm/aaaa)';
    if (f.isBefore(_primera)) return 'Anterior a ${formatoFecha(_primera)}';
    if (f.isAfter(_ultima)) return 'Posterior a ${formatoFecha(_ultima)}';
    return null;
  }

  Future<void> _elegir() async {
    final hoy = DateTime.now();
    var inicial = widget.valor ?? (hoy.isAfter(_ultima) ? _ultima : hoy);
    if (inicial.isBefore(_primera)) inicial = _primera;
    final f = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: _primera,
      lastDate: _ultima,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (f == null) return;
    _controller.text = formatoFecha(f);
    widget.alCambiar(f);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      enabled: widget.habilitado,
      decoration: InputDecoration(
        labelText: _etiqueta(widget.etiqueta, widget.requerido),
        hintText: 'dd/mm/aaaa',
        helperText: widget.ayuda,
        suffixIcon: IconButton(
          onPressed: widget.habilitado ? _elegir : null,
          icon: const Icon(Icons.calendar_month_outlined),
          tooltip: 'Elegir en el calendario',
        ),
      ),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [FormateadorFecha()],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: _validar,
      onChanged: (t) =>
          widget.alCambiar(t.trim().isEmpty ? null : leerFecha(t)),
    );
  }
}

/// "0930" → "09:30".
class FormateadorHora extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    var d = nuevo.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 4) d = d.substring(0, 4);
    final t = d.length > 2 ? '${d.substring(0, 2)}:${d.substring(2)}' : d;
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}

/// "09:30" → (9, 30); `null` si no es una hora válida.
(int, int)? leerHora(String texto) {
  final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(texto.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return (h, min);
}

class CampoHora extends StatefulWidget {
  const CampoHora({
    super.key,
    required this.etiqueta,
    required this.hora,
    required this.minuto,
    required this.alCambiar,
  });

  final String etiqueta;
  final int hora;
  final int minuto;
  final void Function(int hora, int minuto) alCambiar;

  @override
  State<CampoHora> createState() => _CampoHoraState();
}

class _CampoHoraState extends State<CampoHora> {
  late final _controller = TextEditingController(
    text:
        '${widget.hora.toString().padLeft(2, '0')}:'
        '${widget.minuto.toString().padLeft(2, '0')}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _elegir() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: widget.hora, minute: widget.minuto),
    );
    if (t == null) return;
    _controller.text =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    widget.alCambiar(t.hour, t.minute);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        hintText: 'hh:mm',
        suffixIcon: IconButton(
          onPressed: _elegir,
          icon: const Icon(Icons.schedule),
          tooltip: 'Elegir la hora',
        ),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FormateadorHora()],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (t) => leerHora(t ?? '') == null ? 'Hora no válida' : null,
      onChanged: (t) {
        final h = leerHora(t);
        if (h != null) widget.alCambiar(h.$1, h.$2);
      },
    );
  }
}

// ─────────────────────────── Números ───────────────────────────

/// Número con unidad. Marca en rojo lo imposible (error de digitación) y
/// en ámbar lo que está fuera del rango habitual en adultos.
class CampoNumero extends StatefulWidget {
  const CampoNumero({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.alCambiar,
    this.unidad,
    this.rango,
    this.avisarFueraDeRango = true,
    this.decimales = true,
  });

  final String etiqueta;
  final double? valor;
  final ValueChanged<double?> alCambiar;
  final String? unidad;
  final RangoSigno? rango;

  /// `false` en menores de 18 años: sus rangos dependen de la edad.
  final bool avisarFueraDeRango;
  final bool decimales;

  @override
  State<CampoNumero> createState() => _CampoNumeroState();
}

class _CampoNumeroState extends State<CampoNumero> {
  late final _controller = TextEditingController(
    text: widget.valor == null ? '' : formatoNumero(widget.valor!),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validar(String? texto) {
    final t = texto?.trim() ?? '';
    if (t.isEmpty) return null;
    final v = leerNumero(t);
    if (v == null) return 'Número no válido';
    final r = widget.rango;
    if (r != null && !r.esPlausible(v)) return 'Valor no plausible';
    return null;
  }

  String? get _aviso {
    final r = widget.rango;
    final v = leerNumero(_controller.text);
    if (!widget.avisarFueraDeRango || r == null || v == null) return null;
    if (!r.esPlausible(v) || r.esHabitual(v)) return null;
    String n(double? x) => x == null ? '' : formatoNumero(x);
    final rango = r.minHabitual != null && r.maxHabitual != null
        ? '${n(r.minHabitual)}–${n(r.maxHabitual)}'
        : r.minHabitual != null
        ? '≥ ${n(r.minHabitual)}'
        : '≤ ${n(r.maxHabitual)}';
    return 'Fuera de lo habitual ($rango)';
  }

  @override
  Widget build(BuildContext context) {
    final aviso = _aviso;
    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        suffixText: widget.unidad,
        helperText: aviso,
        helperMaxLines: 2,
        helperStyle: const TextStyle(
          color: ColoresMarca.aviso,
          fontWeight: FontWeight.w500,
        ),
        enabledBorder: aviso == null
            ? null
            : const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: ColoresMarca.aviso, width: 1.4),
              ),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: widget.decimales),
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(widget.decimales ? r'[0-9.,]' : r'[0-9]'),
        ),
      ],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: _validar,
      onChanged: (t) {
        setState(() {});
        final v = leerNumero(t);
        if (t.trim().isEmpty || v != null) widget.alCambiar(v);
      },
    );
  }
}

/// Entero pequeño (G, P, A, edad aproximada…).
class CampoEntero extends StatelessWidget {
  const CampoEntero({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.alCambiar,
    this.requerido = false,
    this.sufijo,
  });

  final String etiqueta;
  final int? valor;
  final ValueChanged<int?> alCambiar;
  final bool requerido;
  final String? sufijo;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: valor?.toString() ?? '',
      decoration: InputDecoration(
        labelText: _etiqueta(etiqueta, requerido),
        suffixText: sufijo,
      ),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      validator: requerido ? _obligatorio : null,
      onChanged: (t) => alCambiar(int.tryParse(t)),
    );
  }
}

// ─────────────────────────── Opciones ───────────────────────────

/// Una opción entre varias, con botones tipo chip. Participa en la
/// validación del formulario.
class SelectorOpciones extends StatelessWidget {
  const SelectorOpciones({
    super.key,
    required this.etiqueta,
    required this.opciones,
    required this.valor,
    required this.alCambiar,
    this.requerido = false,
    this.permitirNinguna = false,
  });

  final String etiqueta;
  final List<Opcion> opciones;
  final String? valor;
  final ValueChanged<String?> alCambiar;
  final bool requerido;
  final bool permitirNinguna;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return FormField<String>(
      initialValue: valor,
      validator: requerido
          ? (_) => valor == null ? 'Elige una opción' : null
          : null,
      builder: (campo) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _etiqueta(etiqueta, requerido),
            style: TextStyle(
              fontSize: 12.5,
              color: campo.hasError ? esquema.error : ColoresMarca.textoSuave,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in opciones)
                ChoiceChip(
                  label: Text(o.etiqueta),
                  selected: valor == o.codigo,
                  showCheckmark: false,
                  onSelected: (si) {
                    final nuevo = si
                        ? o.codigo
                        : (permitirNinguna ? null : o.codigo);
                    campo.didChange(nuevo);
                    alCambiar(nuevo);
                  },
                ),
            ],
          ),
          if (campo.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(
                campo.errorText!,
                style: TextStyle(color: esquema.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class CampoDesplegable extends StatelessWidget {
  const CampoDesplegable({
    super.key,
    required this.etiqueta,
    required this.opciones,
    required this.valor,
    required this.alCambiar,
    this.requerido = false,
    this.mostrarCodigo = false,
  });

  final String etiqueta;
  final List<Opcion> opciones;
  final String? valor;
  final ValueChanged<String> alCambiar;
  final bool requerido;

  /// Muestra "CC · Cédula de ciudadanía".
  final bool mostrarCodigo;

  @override
  Widget build(BuildContext context) {
    final valido = opciones.any((o) => o.codigo == valor) ? valor : null;
    return DropdownButtonFormField<String>(
      initialValue: valido,
      isExpanded: true,
      // Por defecto usaría titleMedium (17 w600): mismo texto que los campos.
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(labelText: _etiqueta(etiqueta, requerido)),
      items: [
        for (final o in opciones)
          DropdownMenuItem(
            value: o.codigo,
            child: Text(
              mostrarCodigo && o.codigo != o.etiqueta
                  ? '${o.codigo} · ${o.etiqueta}'
                  : o.etiqueta,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      validator: requerido ? (v) => v == null ? 'Obligatorio' : null : null,
      onChanged: (v) {
        if (v != null) alCambiar(v);
      },
    );
  }
}

/// Lista de etiquetas (alergias): se escribe y se pulsa Enter o coma.
class CampoEtiquetas extends StatefulWidget {
  const CampoEtiquetas({
    super.key,
    required this.etiqueta,
    required this.valores,
    required this.alCambiar,
    this.pista,
    this.habilitado = true,
  });

  final String etiqueta;
  final List<String> valores;
  final ValueChanged<List<String>> alCambiar;
  final String? pista;
  final bool habilitado;

  @override
  State<CampoEtiquetas> createState() => _CampoEtiquetasState();
}

class _CampoEtiquetasState extends State<CampoEtiquetas> {
  final _controller = TextEditingController();
  final _foco = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _agregar(String texto) {
    final nuevas = texto
        .split(RegExp(r'[,;\n]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .where(
          (t) => !widget.valores.any((v) => v.toLowerCase() == t.toLowerCase()),
        )
        .toList();
    _controller.clear();
    if (nuevas.isNotEmpty) widget.alCambiar([...widget.valores, ...nuevas]);
    _foco.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _foco,
          enabled: widget.habilitado,
          decoration: InputDecoration(
            labelText: widget.etiqueta,
            hintText: widget.pista,
            suffixIcon: IconButton(
              onPressed: widget.habilitado
                  ? () => _agregar(_controller.text)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Agregar',
            ),
          ),
          textCapitalization: TextCapitalization.sentences,
          onChanged: (t) {
            if (t.contains(',') || t.contains(';')) _agregar(t);
          },
          onSubmitted: _agregar,
        ),
        if (widget.valores.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in widget.valores)
                InputChip(
                  label: Text(v),
                  avatar: const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: ColoresMarca.aviso,
                  ),
                  onDeleted: widget.habilitado
                      ? () => widget.alCambiar([
                          for (final x in widget.valores)
                            if (x != v) x,
                        ])
                      : null,
                  deleteButtonTooltipMessage: 'Quitar $v',
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────── Distribución ───────────────────────────

/// Campos en fila en pantallas anchas y apilados en móvil.
class FilaCampos extends StatelessWidget {
  const FilaCampos({
    super.key,
    required this.children,
    this.flex,
    this.anchoMinimo = 560,
  });

  final List<Widget> children;

  /// Proporción de cada campo (por defecto, iguales).
  final List<int>? flex;
  final double anchoMinimo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < anchoMinimo) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, w) in children.indexed) ...[
                if (i > 0) const SizedBox(height: 14),
                w,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, w) in children.indexed) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(flex: flex?[i] ?? 1, child: w),
            ],
          ],
        );
      },
    );
  }
}

/// Rejilla de campos del mismo ancho: tantas columnas como quepan.
class RejillaCampos extends StatelessWidget {
  const RejillaCampos({
    super.key,
    required this.children,
    this.anchoMinimo = 150,
    this.maxColumnas = 4,
  });

  final List<Widget> children;
  final double anchoMinimo;
  final int maxColumnas;

  @override
  Widget build(BuildContext context) {
    const separacion = 14.0;
    return LayoutBuilder(
      builder: (context, c) {
        final posibles =
            ((c.maxWidth + separacion) / (anchoMinimo + separacion))
                .floor()
                .clamp(1, maxColumnas);
        final ancho = (c.maxWidth - separacion * (posibles - 1)) / posibles;
        return Wrap(
          spacing: separacion,
          runSpacing: 14,
          children: [
            for (final w in children) SizedBox(width: ancho, child: w),
          ],
        );
      },
    );
  }
}

/// Valor calculado, con el mismo aspecto que un campo.
class ValorCalculado extends StatelessWidget {
  const ValorCalculado({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.vacio = '—',
    this.destacado = false,
  });

  final String etiqueta;
  final String valor;
  final String vacio;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: etiqueta,
        filled: true,
        fillColor: destacado ? ColoresMarca.tinte : ColoresMarca.fondo,
        prefixIcon: const Icon(Icons.calculate_outlined, size: 20),
      ),
      child: Text(
        valor.isEmpty ? vacio : valor,
        style: TextStyle(
          fontWeight: valor.isEmpty ? FontWeight.w400 : FontWeight.w600,
          color: valor.isEmpty ? ColoresMarca.textoSuave : null,
        ),
      ),
    );
  }
}
