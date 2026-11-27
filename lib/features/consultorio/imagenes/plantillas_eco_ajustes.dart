import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/imagenes/plantillas_eco.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../historia/widgets/dialogos.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';

/// Ajustes → Plantillas de ecografía: editar los textos normales, las
/// medidas y la impresión de cada tipo de estudio, o crear plantillas
/// propias. Un informe ya creado no cambia.
class TarjetaPlantillasEco extends ConsumerWidget {
  const TarjetaPlantillasEco({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final imagenes = ref.read(servicioConsultorioProvider).imagenes;
    Future<void> editar(PlantillaEco p) async {
      final nueva = await showDialog<PlantillaEco>(
        context: context,
        builder: (_) => _EditorPlantillaEco(plantilla: p),
      );
      if (nueva == null || !context.mounted) return;
      try {
        await imagenes.guardarPlantilla(nueva);
        ref.read(versionIndiceProvider.notifier).cambio();
        if (context.mounted) {
          mostrarMensaje(context, 'Plantilla «${nueva.nombre}» guardada.');
        }
      } catch (e) {
        if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
      }
    }

    Future<void> restaurar(PlantillaEco p) async {
      final ok = await confirmar(
        context,
        titulo: p.propia ? '¿Quitar la plantilla?' : '¿Volver a la original?',
        texto: p.propia
            ? 'Los informes ya hechos con ella no cambian.'
            : 'Se pierden tus cambios a esta plantilla. Los informes ya '
                  'hechos no cambian.',
        aceptar: p.propia ? 'Quitar' : 'Restaurar',
        icono: Icons.restore,
      );
      if (!ok) return;
      await imagenes.restaurarPlantilla(p.id);
      ref.read(versionIndiceProvider.notifier).cambio();
    }

    return TarjetaConsultorio(
      icono: Icons.monitor_heart_outlined,
      titulo: 'Plantillas de ecografía',
      subtitulo: 'Hallazgos normales, medidas e impresión de cada estudio',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in imagenes.plantillas)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.nombre),
              subtitle: p.propia
                  ? const Text('Propia')
                  : imagenes.editada(p.id)
                  ? const Text('Con tus cambios')
                  : null,
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Editar ${p.nombre}',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => editar(p),
                  ),
                  IconButton(
                    tooltip: 'Copiar como plantilla propia',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () => editar(imagenes.nuevaPlantilla(p)),
                  ),
                  if (p.propia || imagenes.editada(p.id))
                    IconButton(
                      tooltip: p.propia ? 'Quitar' : 'Volver a la original',
                      icon: Icon(
                        p.propia ? Icons.delete_outline : Icons.restore,
                      ),
                      onPressed: () => restaurar(p),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EditorPlantillaEco extends StatefulWidget {
  const _EditorPlantillaEco({required this.plantilla});

  final PlantillaEco plantilla;

  @override
  State<_EditorPlantillaEco> createState() => _EditorPlantillaEcoState();
}

class _EditorPlantillaEcoState extends State<_EditorPlantillaEco> {
  late final p = widget.plantilla;
  late final _nombre = TextEditingController(text: p.nombre);
  late final _tecnica = TextEditingController(text: p.tecnica);
  late final _secciones = TextEditingController(
    text: seccionesATexto(p.secciones),
  );
  late final _medidas = TextEditingController(text: medidasATexto(p.medidas));
  late final _impresion = TextEditingController(text: p.impresion);
  late var _consentimiento = p.requiereConsentimiento;

  @override
  void dispose() {
    for (final c in [_nombre, _tecnica, _secciones, _medidas, _impresion]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _campo(
    TextEditingController c,
    String etiqueta, {
    String? ayuda,
    int lineas = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      minLines: lineas,
      maxLines: lineas == 1 ? 1 : lineas + 6,
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        helperMaxLines: 3,
        alignLabelWithHint: lineas > 1,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const TituloDialogo('Plantilla de ecografía'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _campo(_nombre, 'Nombre (título del informe)'),
              _campo(_tecnica, 'Técnica'),
              _campo(
                _secciones,
                'Hallazgos normales',
                ayuda: 'Una sección por línea: «Órgano: texto normal».',
                lineas: 6,
              ),
              _campo(
                _medidas,
                'Medidas',
                ayuda:
                    'Una por línea: «Nombre | unidad». Agrega «| volumen» para '
                    'pedir tres diámetros en cm y calcular el volumen en mL.',
                lineas: 4,
              ),
              _campo(_impresion, 'Impresión normal', lineas: 2),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _consentimiento,
                onChanged: (v) => setState(() => _consentimiento = v ?? false),
                title: const Text(
                  'Pide consentimiento informado y acompañante',
                ),
                subtitle: const Text(
                  'Para estudios invasivos, como el transvaginal.',
                  style: TextStyle(color: ColoresMarca.textoSuave),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            p.copyWith(
              nombre: _nombre.text.trim(),
              tecnica: _tecnica.text.trim(),
              secciones: seccionesDesdeTexto(_secciones.text),
              medidas: medidasDesdeTexto(_medidas.text),
              impresion: _impresion.text.trim(),
              requiereConsentimiento: _consentimiento,
            ),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
