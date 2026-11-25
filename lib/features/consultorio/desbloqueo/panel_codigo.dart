import 'package:flutter/material.dart';

import '../../../app/tema.dart';
import '../../../core/archivos/archivos.dart' as archivos;
import '../../../core/consultorio/documentos/hoja_recuperacion.dart';
import '../../../core/consultorio/seguridad/llavero.dart';
import '../../../core/widgets/campos.dart';
import '../widgets/comunes.dart';

/// Muestra el código de recuperación **una sola vez** y pide sus últimos 4
/// caracteres antes de seguir, para confirmar que quedó guardado.
class PanelCodigoRecuperacion extends StatefulWidget {
  const PanelCodigoRecuperacion({
    super.key,
    required this.codigo,
    required this.alConfirmar,
    this.titulo = 'Guarda tu código de recuperación',
  });

  final String codigo;
  final VoidCallback alConfirmar;
  final String titulo;

  @override
  State<PanelCodigoRecuperacion> createState() =>
      _PanelCodigoRecuperacionState();
}

class _PanelCodigoRecuperacionState extends State<PanelCodigoRecuperacion> {
  var _ultimos = '';
  var _descargando = false;

  String get _esperado {
    final n = normalizarCodigo(widget.codigo);
    return n.substring(n.length - 4);
  }

  bool get _coincide => normalizarCodigo(_ultimos) == _esperado;

  Future<void> _descargarHoja() async {
    setState(() => _descargando = true);
    try {
      final ahora = DateTime.now();
      final pdf = await generarHojaRecuperacion(
        codigo: widget.codigo,
        fecha: ahora,
      );
      archivos.descargar(
        nombreHojaRecuperacion(ahora),
        pdf,
        tipo: 'application/pdf',
      );
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grupos = formatearCodigo(widget.codigo);
    return TarjetaConsultorio(
      icono: Icons.key_outlined,
      titulo: widget.titulo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Si olvidas la frase, este código es la única forma de abrir el '
            'consultorio o sus respaldos. Se muestra solo esta vez: '
            'descárgalo e imprímelo, y guarda la hoja lejos del equipo.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(
              color: ColoresMarca.tinte,
              borderRadius: RadiosMarca.recuadro,
            ),
            child: Semantics(
              label: 'Código de recuperación: $grupos',
              child: ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SelectableText(
                    grupos,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: ColoresMarca.tinta,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _descargando ? null : _descargarHoja,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Descargar hoja para imprimir'),
            ),
          ),
          const SizedBox(height: 20),
          CampoTexto(
            etiqueta: 'Últimos 4 caracteres del código',
            ayuda: 'Para confirmar que lo guardaste',
            mayusculas: TextCapitalization.characters,
            alCambiar: (v) => setState(() => _ultimos = v),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _coincide ? widget.alConfirmar : null,
              child: const Text('Ya lo guardé, continuar'),
            ),
          ),
        ],
      ),
    );
  }
}
