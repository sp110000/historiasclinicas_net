/// Enganches entre la historia de siempre y el consultorio.
///
/// La historia solo los llama dentro de `if (consultorioHabilitado)`, así que
/// en el sitio público no existen. Ninguno lanza: si el consultorio falla,
/// la historia ya está guardada en su PDF y eso no cambia.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/archivos/archivos.dart' as archivos;
import '../../../core/consultorio/indice/indice_pacientes.dart'
    show TipoRegistro;
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/consultorio/modelos/registro_historia.dart';
import '../../../core/consultorio/servicio.dart';
import '../../../core/models/historia.dart';
import '../../../core/utils/fechas.dart';
import '../../historia/estado/archivo_provider.dart';
import '../../historia/estado/borrador_provider.dart';
import '../../historia/estado/historia_controller.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';

ServicioConsultorio _servicio(WidgetRef ref) =>
    ref.read(servicioConsultorioProvider);

void _avisar(BuildContext context, String texto) {
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(texto),
      behavior: SnackBarBehavior.floating,
      width: MediaQuery.sizeOf(context).width > 640 ? 560 : null,
      duration: const Duration(seconds: 8),
    ),
  );
}

/// Después de escribir el PDF de la historia: la registra en el índice (o
/// la deja pendiente si el consultorio está bloqueado).
Future<void> registrarHistoriaGuardada(
  BuildContext context,
  WidgetRef ref, {
  required Map<String, Object?> datos,
  required int revision,
  required String nombreArchivo,
  required Uint8List bytesPdf,
}) async {
  try {
    await _servicio(ref).registrarHistoria(
      HistoriaPendiente(
        datos: datos,
        revision: revision,
        origen: OrigenArchivo.generado,
        nombreArchivo: nombreArchivo,
        bytesPdf: bytesPdf,
      ),
    );
    ref.read(versionIndiceProvider.notifier).cambio();
  } on Object catch (e) {
    debugPrint('Consultorio: no se registró la historia: $e');
    if (context.mounted) {
      _avisar(
        context,
        'La historia quedó guardada en el PDF, pero no se pudo registrar en '
        'el consultorio. Impórtala después desde Pacientes.',
      );
    }
  }
}

/// Después de abrir el PDF de una historia. Si el consultorio tiene una
/// revisión más nueva, lo dice y ofrece abrirla. Luego registra el archivo.
Future<void> alAbrirHistoria(
  BuildContext context,
  WidgetRef ref, {
  required Map<String, Object?> datos,
  required int revision,
  required archivos.ArchivoAbierto archivo,
}) async {
  try {
    final s = _servicio(ref);
    final id = datos['id'];
    final enIndice = s.boveda.desbloqueada && id is String
        ? s.indice.historia(id)
        : null;
    if (enIndice != null &&
        enIndice.revision > revision &&
        context.mounted &&
        await _preguntarVersionNueva(context, enIndice, revision)) {
      await abrirHistoriaDelIndice(ref, enIndice.id);
      if (context.mounted) {
        _avisar(
          context,
          'Se abrió la versión del consultorio (revisión '
          '${enIndice.revision}).',
        );
      }
      return;
    }
    final r = await s.registrarHistoria(
      HistoriaPendiente(
        datos: datos,
        revision: revision,
        origen: OrigenArchivo.abierto,
        nombreArchivo: archivo.nombre,
        bytesPdf: archivo.bytes,
      ),
    );
    ref.read(versionIndiceProvider.notifier).cambio();
    if (r != null) {
      ref.read(fichaEnCursoProvider.notifier).cambiar(r.pacienteId);
    }
    if (r?.tipo == TipoRegistro.divergente && context.mounted) {
      _avisar(
        context,
        'Este PDF no coincide con la versión del consultorio con la misma '
        'revisión. Quedó marcado como versión divergente en la ficha.',
      );
    }
  } on Object catch (e) {
    debugPrint('Consultorio: no se registró la historia abierta: $e');
  }
}

Future<bool> _preguntarVersionNueva(
  BuildContext context,
  RegistroHistoria enIndice,
  int revisionArchivo,
) async {
  final si = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hay una versión más nueva'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Text(
          'El archivo que abriste es la revisión $revisionArchivo. El '
          'consultorio tiene la revisión ${enIndice.revision}, del '
          '${formatoFechaHora(enIndice.ultimaAtencion)}. Si continúas el '
          'archivo viejo, las evoluciones nuevas no tendrán las de la '
          'versión más reciente.',
        ),
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Seguir con este archivo'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Abrir la más nueva'),
        ),
      ],
    ),
  );
  return si ?? false;
}

/// Abre en la historia la última revisión que guarda el índice (con su PDF,
/// si lo tiene, para imprimirla tal cual). Devuelve `false` si no la tiene.
Future<bool> abrirHistoriaDelIndice(WidgetRef ref, String historiaId) async {
  final s = _servicio(ref);
  final registro = s.indice.historia(historiaId);
  final datos = await s.indice.datosDe(historiaId);
  if (registro == null || datos == null) return false;
  final pdf = registro.tienePdf ? await s.indice.pdfDe(historiaId) : null;
  final nombre = registro.archivos.isEmpty
      ? 'historia.pdf'
      : registro.archivos.last.nombre;
  ref
      .read(historiaProvider.notifier)
      .abrir(datos, revision: registro.revision, nombreArchivo: nombre);
  ref
      .read(archivoActualProvider.notifier)
      .cambiar(
        pdf == null
            ? null
            : archivos.ArchivoAbierto(nombre: nombre, bytes: pdf),
      );
  await ref.read(borradorProvider.notifier).borrar();
  ref.read(fichaEnCursoProvider.notifier).cambiar(registro.pacienteId);
  return true;
}

/// Continúa la historia más reciente de la ficha con una evolución nueva.
/// Devuelve `false` si la ficha no tiene historias.
Future<bool> nuevaEvolucionPara(WidgetRef ref, String pacienteId) async {
  if (!await _abrirUltimaHistoria(ref, pacienteId)) return false;
  if (ref.read(historiaProvider).evolucionesNuevas.isEmpty) {
    ref.read(historiaProvider.notifier).agregarEvolucion();
  }
  return true;
}

/// Deja en la historia en curso la más reciente de la ficha, sin reabrirla
/// si ya es esa (para no perder evoluciones sin guardar).
Future<bool> _abrirUltimaHistoria(WidgetRef ref, String pacienteId) async {
  final ultima = _servicio(ref).indice.ultimaHistoria(pacienteId);
  if (ultima == null) return false;
  final enCurso = ref.read(historiaProvider);
  if (enCurso.abierta && enCurso.historia.id == ultima.id) {
    ref.read(fichaEnCursoProvider.notifier).cambiar(pacienteId);
    return true;
  }
  return abrirHistoriaDelIndice(ref, ultima.id);
}

/// Antes de ir a la receta: la receta toma el paciente y las alergias de
/// la historia en curso. Con historias, continúa la más reciente (la
/// receta se registra en la evolución en curso); sin ninguna, empieza una
/// historia nueva prellenada (se registra en el plan).
Future<void> prepararRecetaPara(WidgetRef ref, FichaPaciente ficha) async {
  if (!await _abrirUltimaHistoria(ref, ficha.id)) {
    await nuevaHistoriaPara(ref, ficha);
  }
}

/// `true` si reemplazar la historia en curso perdería algo: la página de
/// la ficha pide confirmación antes.
bool historiaEnCursoConCambios(WidgetRef ref) =>
    ref.read(historiaProvider).hayCambiosSinGuardar;

/// Empieza una historia nueva con los datos de la ficha y los antecedentes
/// de su historia más reciente (con las alergias vigentes). El médico los
/// revisa antes de finalizar.
Future<void> nuevaHistoriaPara(WidgetRef ref, FichaPaciente ficha) async {
  final indice = _servicio(ref).indice;
  Antecedentes? antecedentes;
  final ultima = indice.ultimaHistoria(ficha.id);
  if (ultima != null) {
    final datos = await indice.datosDe(ultima.id);
    if (datos != null) {
      antecedentes = HistoriaClinica.desdeMapa(datos).antecedentes;
      final vigentes = indice.alergiasDe(ficha.id);
      if (vigentes != null) {
        antecedentes = antecedentes.copyWith(
          alergias: vigentes.alergias,
          niegaAlergias: vigentes.niega,
        );
      }
    }
  }
  final ctrl = ref.read(historiaProvider.notifier);
  // En el mismo bloque síncrono: limpiar sube versionFormulario y el
  // formulario se reconstruye ya con la ficha.
  ctrl
    ..limpiar()
    ..actualizar(
      (h) => h.copyWith(
        paciente: ficha.aPaciente(),
        antecedentes: antecedentes ?? h.antecedentes,
      ),
    );
  ref.read(archivoActualProvider.notifier).cambiar(null);
  await ref.read(borradorProvider.notifier).borrar();
  ref.read(fichaEnCursoProvider.notifier).cambiar(ficha.id);
}

/// Historias pendientes de registrar (consultorio bloqueado).
int historiasPendientes(WidgetRef ref) => _servicio(ref).historiasPendientes;
