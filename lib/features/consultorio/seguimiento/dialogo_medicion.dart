import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/clinica/rangos.dart';
import '../../../core/consultorio/modelos/medicion.dart';
import '../../../core/models/mapa.dart';
import '../../../core/pais/perfil_pais.dart';
import '../../../core/utils/numeros.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../historia/widgets/dialogos.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../integracion/enganche_historia.dart';
import '../widgets/comunes.dart';

/// Registra una medición nueva o edita una manual. Con historias, ofrece
/// copiarla a la evolución en curso (pregunta 17), donde queda sellada.
Future<void> editarMedicion(
  BuildContext context, {
  required String pacienteId,
  Medicion? medicion,
}) => showDialog<void>(
  context: context,
  builder: (_) => _DialogoMedicion(pacienteId: pacienteId, inicial: medicion),
);

class _DialogoMedicion extends ConsumerStatefulWidget {
  const _DialogoMedicion({required this.pacienteId, this.inicial});

  final String pacienteId;
  final Medicion? inicial;

  @override
  ConsumerState<_DialogoMedicion> createState() => _DialogoMedicionState();
}

class _DialogoMedicionState extends ConsumerState<_DialogoMedicion> {
  late Map<String, Object?> _m;
  late var _copiar = widget.inicial == null && _tieneHistorias;
  var _guardando = false;
  String? _error;

  bool get _tieneHistorias => ref
      .read(servicioConsultorioProvider)
      .indice
      .historiasDe(widget.pacienteId)
      .isNotEmpty;

  @override
  void initState() {
    super.initState();
    final s = ref.read(servicioConsultorioProvider);
    final ahora = s.reloj.ahora();
    _m =
        widget.inicial?.aMapa() ??
        Medicion(
          id: '',
          pacienteId: widget.pacienteId,
          fecha: ahora,
          creado: ahora,
          talla: s.seguimiento.ultimaTalla(widget.pacienteId),
        ).aMapa();
  }

  Medicion get _medicion => Medicion.desdeMapa(widget.inicial?.id ?? '', _m);

  double? _num(String clave) => (_m[clave] as num?)?.toDouble();

  void _poner(String clave, Object? valor) => setState(() {
    if (valor == null) {
      _m.remove(clave);
    } else {
      _m[clave] = valor;
    }
  });

  Widget _campo(String clave, String etiqueta, String unidad, RangoSigno r) =>
      CampoNumero(
        etiqueta: etiqueta,
        valor: _num(clave),
        unidad: unidad,
        rango: r,
        alCambiar: (v) => _poner(clave, v),
      );

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final s = ref.read(servicioConsultorioProvider);
    try {
      final m = await s.seguimiento.guardarMedicion(_medicion);
      ref.read(versionIndiceProvider.notifier).cambio();
      if (!mounted) return;
      if (_copiar &&
          await confirmarReemplazoHistoria(
            context,
            ref,
            pacienteId: widget.pacienteId,
            continuar: true,
          )) {
        await agregarALaEvolucion(ref, widget.pacienteId, m.texto);
        if (mounted) {
          mostrarMensaje(
            context,
            'Medición guardada y agregada a la evolución en curso. Se sella '
            'al descargar la historia.',
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  Future<void> _borrar() async {
    final si = await confirmar(
      context,
      titulo: '¿Borrar la medición?',
      texto:
          'Se borra del seguimiento. Si la copiaste a una evolución ya '
          'sellada, allí sigue.',
      aceptar: 'Borrar',
      icono: Icons.delete_outline,
      peligro: true,
    );
    if (!si || !mounted) return;
    await ref
        .read(servicioConsultorioProvider)
        .seguimiento
        .borrarMedicion(widget.inicial!.id);
    ref.read(versionIndiceProvider.notifier).cambio();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = _medicion;
    final movil = MediaQuery.sizeOf(context).width < 600;
    String calc(double? v, [int? d]) =>
        v == null ? '—' : formatoNumero(v, decimales: d);
    return AlertDialog(
      title: TituloDialogo(
        widget.inicial == null ? 'Medición nueva' : 'Editar medición',
        icono: Icons.straighten,
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: movil ? 8 : 40,
        vertical: 16,
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilaCampos(
                anchoMinimo: 420,
                children: [
                  CampoFecha(
                    etiqueta: 'Fecha',
                    valor: m.fecha,
                    requerido: true,
                    primera: DateTime(2000),
                    ultima: DateTime.now().add(const Duration(days: 1)),
                    alCambiar: (f) {
                      if (f == null) return;
                      final h = m.fecha;
                      _poner(
                        'fecha',
                        fechaHoraIso(
                          DateTime(f.year, f.month, f.day, h.hour, h.minute),
                        ),
                      );
                    },
                  ),
                  const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 14),
              RejillaCampos(
                anchoMinimo: 140,
                children: [
                  _campo('peso', 'Peso', 'kg', Rangos.peso),
                  _campo('talla', 'Talla', 'cm', Rangos.talla),
                  _campo('cintura', 'Cintura', 'cm', rangoPerimetro),
                  _campo('cadera', 'Cadera', 'cm', rangoPerimetro),
                  _campo('abdomen', 'Abdomen', 'cm', rangoPerimetro),
                  _campo(
                    'paSistolica',
                    'PA sistólica',
                    'mmHg',
                    Rangos.paSistolica,
                  ),
                  _campo(
                    'paDiastolica',
                    'PA diastólica',
                    'mmHg',
                    Rangos.paDiastolica,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'IMC ${calc(m.imc, 1)} · ICC ${calc(m.icc, 2)} (se calculan)',
                style: const TextStyle(color: ColoresMarca.textoSuave),
              ),
              const SizedBox(height: 14),
              const Text('PERÍMETROS', style: EstilosMarca.rotulo),
              const SizedBox(height: 8),
              RejillaCampos(
                anchoMinimo: 140,
                children: [
                  _campo('flancoDerecho', 'Flanco D', 'cm', rangoPerimetro),
                  _campo('flancoIzquierdo', 'Flanco I', 'cm', rangoPerimetro),
                  _campo('musloDerecho', 'Muslo D', 'cm', rangoPerimetro),
                  _campo('musloIzquierdo', 'Muslo I', 'cm', rangoPerimetro),
                  _campo('brazoDerecho', 'Brazo D', 'cm', rangoPerimetro),
                  _campo('brazoIzquierdo', 'Brazo I', 'cm', rangoPerimetro),
                ],
              ),
              const SizedBox(height: 14),
              FilaCampos(
                anchoMinimo: 420,
                children: [
                  _campo('grasa', '% de grasa', '%', rangoGrasa),
                  CampoDesplegable(
                    etiqueta: 'Método del % de grasa',
                    opciones: [
                      for (final g in MetodoGrasa.values)
                        Opcion(g.name, g.etiqueta),
                    ],
                    valor: m.metodoGrasa?.name,
                    requerido: m.grasa != null,
                    alCambiar: (v) => _poner('metodoGrasa', v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Notas',
                valorInicial: m.notas,
                lineas: 2,
                alCambiar: (v) => _poner('notas', v),
              ),
              if (widget.inicial == null && _tieneHistorias)
                CheckboxListTile(
                  value: _copiar,
                  onChanged: (v) => setState(() => _copiar = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Agregar a la evolución en curso'),
                  subtitle: const Text(
                    '«Mediciones del día: …» queda en la historia y se sella '
                    'al descargarla.',
                  ),
                ),
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
        if (widget.inicial != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ColoresMarca.error),
            onPressed: _guardando ? null : _borrar,
            child: const Text('Borrar'),
          ),
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: const Text('Guardar medición'),
        ),
      ],
    );
  }
}
