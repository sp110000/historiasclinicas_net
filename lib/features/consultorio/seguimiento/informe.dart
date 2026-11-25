import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/consultorio/documentos/documento.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/pais/pais_provider.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../historia/widgets/dialogos.dart';
import '../../medico/medico_provider.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';

String _hoy(DateTime f) =>
    '${f.year}-${f.month.toString().padLeft(2, '0')}-'
    '${f.day.toString().padLeft(2, '0')}';

/// «Informe de seguimiento»: si la ficha tiene fotos, pregunta si van
/// (apagado por defecto, pregunta 23); luego descarga el PDF.
Future<void> descargarInformeSeguimiento(
  BuildContext context,
  WidgetRef ref, {
  required FichaPaciente ficha,
}) async {
  final s = ref.read(servicioConsultorioProvider);
  if (s.seguimiento.medicionesDe(ficha.id).isEmpty) {
    mostrarMensaje(context, 'Registra al menos una medición.');
    return;
  }
  var incluirFotos = false;
  if (s.seguimiento.fotosDe(ficha.id).isNotEmpty) {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const TituloDialogo(
            'Informe de seguimiento',
            icono: Icons.summarize_outlined,
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Cambios, gráficas de peso, IMC y cintura, y la tabla de '
                  'mediciones, con tu firma.',
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: incluirFotos,
                  onChanged: (v) => setState(() => incluirFotos = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Incluir fotos'),
                  subtitle: const Text(
                    'La primera y la última de cada vista. Las fotos salen '
                    'del consultorio cifrado: compártelo solo con el '
                    'paciente o dentro de su atención.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Descargar'),
            ),
          ],
        ),
      ),
    );
    if (si != true || !context.mounted) return;
  }
  try {
    final pdf = await s.seguimiento.informePdf(
      ficha,
      medico: ref.read(medicoProvider),
      pais: ref.read(paisProvider),
      incluirFotos: incluirFotos,
    );
    final nombre = nombreArchivoDocumento(
      'Informe_seguimiento',
      apellido: ficha.primerApellido,
      numero: _hoy(s.seguimiento.reloj.ahora()),
    );
    ref.read(descargarPdfProvider)(pdf, nombre);
    if (context.mounted) {
      mostrarMensaje(
        context,
        'Informe descargado${incluirFotos ? ' (con fotos)' : ''}: $nombre.',
      );
    }
  } catch (e) {
    if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
  }
}

/// «Exportar fotos en PDF» (pregunta 23): todas las fotos de la ficha.
Future<void> exportarFotosPdf(
  BuildContext context,
  WidgetRef ref, {
  required FichaPaciente ficha,
}) async {
  final s = ref.read(servicioConsultorioProvider);
  final n = s.seguimiento.fotosDe(ficha.id).length;
  final si = await confirmar(
    context,
    titulo: '¿Exportar las fotos?',
    texto:
        'Se descarga un PDF con ${n == 1 ? 'la foto' : 'las $n fotos'} de '
        '${ficha.nombreCompleto}, fuera del consultorio cifrado. Queda en la '
        'bitácora. Compártelo solo con el paciente o dentro de su atención.',
    aceptar: 'Exportar',
    icono: Icons.picture_as_pdf_outlined,
  );
  if (!si || !context.mounted) return;
  try {
    final pdf = await s.seguimiento.fotosPdf(
      ficha,
      medico: ref.read(medicoProvider),
      pais: ref.read(paisProvider),
    );
    final nombre = nombreArchivoDocumento(
      'Fotos_clinicas',
      apellido: ficha.primerApellido,
      numero: _hoy(s.seguimiento.reloj.ahora()),
    );
    ref.read(descargarPdfProvider)(pdf, nombre);
    if (context.mounted) {
      mostrarMensaje(
        context,
        'Fotos exportadas el ${formatoFecha(s.seguimiento.reloj.ahora())}: '
        '$nombre.',
      );
    }
  } catch (e) {
    if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
  }
}
