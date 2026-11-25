import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/fotos/procesar_foto.dart';
import '../../../core/consultorio/modelos/foto.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import 'piezas_fotos.dart';

/// Procesa una foto (reducir, JPEG, sin metadatos). Las pruebas lo
/// sustituyen si hace falta.
final procesarFotoProvider =
    Provider<Future<FotoProcesada> Function(Uint8List)>((ref) => procesarFoto);

/// «Tomar fotos»: guía la secuencia de vistas (frontal, laterales,
/// posterior y detalle). Después de cada foto muestra la guía y la anterior
/// de esa vista en transparencia, con «Repetir» o «Aceptar». Devuelve
/// cuántas se guardaron.
Future<int?> tomarFotos(BuildContext context, {required String pacienteId}) =>
    showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SecuenciaFotos(pacienteId: pacienteId),
    );

class _SecuenciaFotos extends ConsumerStatefulWidget {
  const _SecuenciaFotos({required this.pacienteId});

  final String pacienteId;

  @override
  ConsumerState<_SecuenciaFotos> createState() => _SecuenciaFotosState();
}

class _SecuenciaFotosState extends ConsumerState<_SecuenciaFotos> {
  var _indice = 0;
  FotoProcesada? _candidata;
  var _ocupado = false;
  var _guardadas = 0;
  var _verAnterior = true;
  final _zona = TextEditingController();
  String? _error;

  VistaFoto get _vista => VistaFoto.values[_indice];

  @override
  void dispose() {
    _zona.dispose();
    super.dispose();
  }

  Future<void> _elegir() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final archivo = await ref.read(elegirFotoProvider)();
      if (archivo == null) return;
      final p = await ref.read(procesarFotoProvider)(archivo.bytes);
      if (mounted) setState(() => _candidata = p);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? 'No se pudo leer la foto: usa una imagen JPG o PNG.'
              : mensajeDeError(e),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _aceptar() async {
    final p = _candidata;
    if (p == null) return;
    if (_vista == VistaFoto.detalle && _zona.text.trim().isEmpty) {
      setState(() => _error = 'Escribe la zona del detalle.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      await ref
          .read(servicioConsultorioProvider)
          .seguimiento
          .guardarFoto(
            pacienteId: widget.pacienteId,
            vista: _vista,
            procesada: p,
            zona: _vista == VistaFoto.detalle ? _zona.text.trim() : '',
          );
      ref.read(versionIndiceProvider.notifier).cambio();
      _guardadas++;
      _siguiente();
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _siguiente() {
    if (_indice == VistaFoto.values.length - 1) {
      Navigator.pop(context, _guardadas);
      return;
    }
    setState(() {
      _indice++;
      _candidata = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.read(servicioConsultorioProvider).seguimiento;
    final anterior = s.anterior(widget.pacienteId, _vista);
    final p = _candidata;
    final movil = MediaQuery.sizeOf(context).width < 600;
    final total = VistaFoto.values.length;
    return AlertDialog(
      title: TituloDialogo(
        '${_vista.etiqueta} (${_indice + 1} de $total)',
        icono: Icons.photo_camera_outlined,
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: movil ? 8 : 40,
        vertical: 16,
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                p == null
                    ? 'Encuadra a la persona de frente a la guía: hombros, '
                          'ombligo y caderas sobre las líneas.'
                    : 'Compara con la guía${anterior == null ? '' : ' y con la '
                                'foto anterior'}. Si no quedó alineada, repítela.',
                style: const TextStyle(color: ColoresMarca.textoSuave),
              ),
              const SizedBox(height: 10),
              AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: RadiosMarca.control,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: ColoresMarca.tinta),
                      if (p != null)
                        Image.memory(
                          p.jpeg,
                          fit: BoxFit.contain,
                          semanticLabel: 'Foto nueva: ${_vista.etiqueta}',
                        )
                      else
                        const Center(
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 48,
                            color: Colors.white70,
                          ),
                        ),
                      if (anterior != null && _verAnterior)
                        FotoCifrada(foto: anterior, opacidad: 0.35),
                      const GuiaEncuadre(),
                    ],
                  ),
                ),
              ),
              if (anterior != null)
                SwitchListTile(
                  value: _verAnterior,
                  onChanged: (v) => setState(() => _verAnterior = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ver la anterior en transparencia'),
                ),
              if (_vista == VistaFoto.detalle) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _zona,
                  decoration: const InputDecoration(
                    labelText: 'Zona del detalle',
                    hintText: 'Abdomen, flanco derecho…',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: ColoresMarca.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.pop(context, _guardadas),
          child: Text(_guardadas == 0 ? 'Cancelar' : 'Terminar'),
        ),
        if (p == null) ...[
          TextButton(
            onPressed: _ocupado ? null : _siguiente,
            child: const Text('Saltar esta vista'),
          ),
          FilledButton.icon(
            onPressed: _ocupado ? null : _elegir,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Tomar o elegir foto'),
          ),
        ] else ...[
          TextButton(
            onPressed: _ocupado
                ? null
                : () => setState(() => _candidata = null),
            child: const Text('Repetir'),
          ),
          FilledButton(
            onPressed: _ocupado ? null : _aceptar,
            child: const Text('Aceptar'),
          ),
        ],
      ],
    );
  }
}
