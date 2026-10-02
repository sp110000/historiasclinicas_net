import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/historia.dart';
import '../estado/historia_controller.dart';

/// Atajos para editar la historia nueva desde los formularios.
extension EdicionHistoria on WidgetRef {
  void editar(HistoriaClinica Function(HistoriaClinica h) cambio) =>
      read(historiaProvider.notifier).actualizar(cambio);

  void editarPaciente(Paciente Function(Paciente p) cambio) =>
      editar((h) => h.copyWith(paciente: cambio(h.paciente)));

  void editarAntecedentes(Antecedentes Function(Antecedentes a) cambio) =>
      editar((h) => h.copyWith(antecedentes: cambio(h.antecedentes)));

  void editarSignos(SignosVitales Function(SignosVitales s) cambio) =>
      editar((h) => h.copyWith(signos: cambio(h.signos)));

  void editarExamen(ExamenFisico Function(ExamenFisico e) cambio) =>
      editar((h) => h.copyWith(examen: cambio(h.examen)));

  void editarPlan(PlanTratamiento Function(PlanTratamiento p) cambio) =>
      editar((h) => h.copyWith(plan: cambio(h.plan)));
}
