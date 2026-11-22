import 'package:flutter/material.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/seguridad/boveda.dart';
import '../../../core/consultorio/seguridad/llavero.dart';
import '../../../core/consultorio/servicio.dart';
import '../../../core/widgets/recuadro_icono.dart';
import '../../../core/widgets/titulo_dialogo.dart';

/// Tarjeta de las pantallas del consultorio (como las de «Datos del
/// médico»): ícono en recuadro con tinte, título y contenido.
class TarjetaConsultorio extends StatelessWidget {
  const TarjetaConsultorio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.child,
    this.subtitulo,
  });

  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final relleno = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return Container(
      padding: EdgeInsets.all(relleno),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RecuadroIcono(icono, color: ColoresMarca.primario, lado: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitulo != null)
                      Text(
                        subtitulo!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ColoresMarca.textoSuave,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// Contenido centrado con el ancho máximo de las demás pantallas.
class CuerpoConsultorio extends StatelessWidget {
  const CuerpoConsultorio({
    super.key,
    required this.children,
    this.anchoMaximo = 900,
  });

  final List<Widget> children;
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.sizeOf(context).width < 700;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(movil ? 12 : 24, 20, movil ? 12 : 24, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: anchoMaximo),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Mensaje para el médico a partir de una excepción del consultorio.
String mensajeDeError(Object e) => switch (e) {
  SecretoIncorrecto() => 'La frase o el código no son correctos.',
  OtraPestanaAbierta() =>
    'El consultorio está abierto en otra pestaña de este navegador. '
        'Bloquéalo allí o cierra esa pestaña y vuelve a intentarlo.',
  BovedaBloqueada() => 'El consultorio está bloqueado.',
  StateError(:final message) => message,
  _ => 'No se pudo completar la operación. ($e)',
};

void mostrarMensaje(BuildContext context, String texto) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// `1,2 MB`, `850 KB`.
String formatoTamano(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
  return '${(bytes / 1024).ceil()} KB';
}

/// «hoy», «ayer», «hace 9 días».
String haceDias(DateTime fecha, DateTime ahora) {
  final dias = DateTime(
    ahora.year,
    ahora.month,
    ahora.day,
  ).difference(DateTime(fecha.year, fecha.month, fecha.day)).inDays;
  return switch (dias) {
    <= 0 => 'hoy',
    1 => 'ayer',
    _ => 'hace $dias días',
  };
}

/// Píldora de estado: control vencido, alterada, divergente…
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado({
    super.key,
    required this.icono,
    required this.texto,
    required this.color,
  });

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // 6 %: con más tinte, el verde de «Íntegra» baja de 4,5:1.
        color: color.withValues(alpha: 0.06),
        borderRadius: RadiosMarca.pildora,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12.5,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pide un texto corto en un diálogo; devuelve `null` si se cancela.
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  String aceptar = 'Aceptar',
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _DialogoTexto(titulo: titulo, etiqueta: etiqueta, aceptar: aceptar),
);

class _DialogoTexto extends StatefulWidget {
  const _DialogoTexto({
    required this.titulo,
    required this.etiqueta,
    required this.aceptar,
  });

  final String titulo;
  final String etiqueta;
  final String aceptar;

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _listo() {
    if (_texto.text.trim().isEmpty) return;
    Navigator.pop(context, _texto.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: TituloDialogo(widget.titulo, icono: Icons.edit_outlined),
    content: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 480),
      child: TextField(
        controller: _texto,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _listo(),
        decoration: InputDecoration(labelText: widget.etiqueta),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _texto.text.trim().isEmpty ? null : _listo,
        child: Text(widget.aceptar),
      ),
    ],
  );
}
