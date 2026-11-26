import '../agenda/cita.dart';
import '../modelos/ficha_paciente.dart';
import '../repositorio/bitacora.dart';
import '../servicio.dart';

/// Lo que el consultorio guarda de un paciente (con lo de las fichas
/// unidas a la suya). Sin nada, su ficha se puede borrar del todo.
class RegistrosPaciente {
  const RegistrosPaciente({
    required this.partes,
    required this.citasPorVenir,
    required this.saldo,
  });

  /// «2 historias», «1 receta», «3 cobros»…: solo lo que tiene.
  final List<String> partes;

  /// Citas abiertas desde ahora: hay que cancelarlas antes de eliminar.
  final List<Cita> citasPorVenir;

  /// Lo que el paciente debe en la caja.
  final int saldo;

  bool get vacio => partes.isEmpty;
}

/// Cómo terminó la eliminación de una ficha.
enum ResultadoEliminacion {
  /// No tenía registros: la ficha se borró.
  borrada,

  /// Tenía registros: la ficha se ocultó y todo se conserva.
  oculta,
}

String _cuenta(int n, String uno, String varios) =>
    '$n ${n == 1 ? uno : varios}';

extension EliminarPaciente on ServicioConsultorio {
  RegistrosPaciente registrosDe(String pacienteId) {
    final historias = indice.historiasDe(pacienteId);
    final medicionesDeHistorias = historias.fold<int>(
      0,
      (s, h) => s + h.mediciones.length,
    );
    final mediciones =
        seguimiento.medicionesDe(pacienteId).length - medicionesDeHistorias;
    final unidas = indice.idsUnidos(pacienteId).length - 1;
    final citas = agenda.citasDe(pacienteId);
    final ahora = reloj.ahora();
    final partes = [
      for (final (n, uno, varios) in [
        (historias.length, 'historia', 'historias'),
        (indice.recetasDe(pacienteId).length, 'receta', 'recetas'),
        (documentos.documentosDe(pacienteId).length, 'documento', 'documentos'),
        (citas.length, 'cita', 'citas'),
        (caja.cobrosDe(pacienteId).length, 'cobro', 'cobros'),
        (caja.recibosDePaciente(pacienteId).length, 'recibo', 'recibos'),
        (caja.paquetesDe(pacienteId).length, 'paquete', 'paquetes'),
        (seguimiento.fotosDe(pacienteId).length, 'foto', 'fotos'),
        (mediciones, 'medición', 'mediciones'),
        (
          procedimientos.valoracionesDe(pacienteId).length,
          'valoración',
          'valoraciones',
        ),
        (procedimientos.sesionesDe(pacienteId).length, 'sesión', 'sesiones'),
        (peso.programaDe(pacienteId) == null ? 0 : 1, 'programa de peso', ''),
        (unidas, 'ficha unida', 'fichas unidas'),
      ])
        if (n > 0) _cuenta(n, uno, varios),
    ];
    return RegistrosPaciente(
      partes: partes,
      citasPorVenir: [
        for (final c in citas.reversed)
          if (!c.estado.cerrada && !c.inicio.isBefore(ahora)) c,
      ],
      saldo: caja.saldoPaciente(pacienteId),
    );
  }

  /// Elimina la ficha de la lista. Sin registros se borra; con historias u
  /// otros registros se oculta y todo se conserva (la historia clínica no
  /// se puede destruir antes de tiempo). Lanza [StateError] si tiene citas
  /// por venir.
  Future<ResultadoEliminacion> eliminarPaciente(String pacienteId) async {
    final f = indice.ficha(pacienteId);
    if (f == null || !f.visible) throw StateError('No se encontró la ficha.');
    final r = registrosDe(pacienteId);
    if (r.citasPorVenir.isNotEmpty) {
      throw StateError(
        'Tiene citas por venir: cancélalas o reprográmalas en la agenda '
        'antes de eliminar la ficha.',
      );
    }
    final ahora = reloj.ahora();
    final ResultadoEliminacion resultado;
    if (r.vacio) {
      await indice.borrarFicha(pacienteId);
      resultado = ResultadoEliminacion.borrada;
    } else {
      await indice.marcarEliminada(pacienteId, ahora);
      resultado = ResultadoEliminacion.oculta;
    }
    await registrarEnBitacora(
      repositorio,
      AccionBitacora.eliminarPaciente,
      fecha: ahora,
      resumen: resultado == ResultadoEliminacion.borrada
          ? 'Sin registros: se borró'
          : 'Se ocultó; sus registros se conservan',
    );
    return resultado;
  }

  /// Devuelve a la lista una ficha eliminada; si se había borrado,
  /// [original] la vuelve a guardar (deshacer).
  Future<void> restaurarPaciente(
    String pacienteId, {
    FichaPaciente? original,
  }) async {
    final f = indice.ficha(pacienteId);
    if (f == null) {
      if (original == null) throw StateError('No se encontró la ficha.');
      await indice.reponerFicha(original);
    } else {
      await indice.marcarEliminada(pacienteId, null);
    }
    await registrarEnBitacora(
      repositorio,
      AccionBitacora.restaurarPaciente,
      fecha: reloj.ahora(),
    );
  }
}
