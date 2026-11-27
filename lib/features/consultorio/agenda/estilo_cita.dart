import 'package:flutter/material.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/agenda/cita.dart';

/// Cada tipo de cita se distingue por su ícono y su nombre (rediseño:
/// menos colores; el color queda para lo que significa algo). El naranja
/// marca la siguiente cita por atender.
({IconData icono, Color color}) estiloTipo(TipoCita t) => switch (t) {
  TipoCita.primeraVez => (
    icono: Icons.person_add_alt_1_outlined,
    color: ColoresMarca.tintaSuave,
  ),
  TipoCita.control => (
    icono: Icons.event_repeat_outlined,
    color: ColoresMarca.tintaSuave,
  ),
  TipoCita.programaPeso => (
    icono: Icons.monitor_weight_outlined,
    color: ColoresMarca.tintaSuave,
  ),
  TipoCita.valoracionEstetica => (
    icono: Icons.fact_check_outlined,
    color: ColoresMarca.tintaSuave,
  ),
  TipoCita.sesion => (
    icono: Icons.healing_outlined,
    color: ColoresMarca.tintaSuave,
  ),
  TipoCita.ecografia => (
    icono: Icons.monitor_heart_outlined,
    color: ColoresMarca.tintaSuave,
  ),
};

({IconData icono, Color color}) estiloEstado(EstadoCita e) => switch (e) {
  EstadoCita.agendada => (
    icono: Icons.schedule,
    color: ColoresMarca.textoSuave,
  ),
  EstadoCita.confirmada => (
    icono: Icons.check_circle_outline,
    color: ColoresMarca.estadoOk,
  ),
  EstadoCita.atendida => (icono: Icons.task_alt, color: ColoresMarca.estadoOk),
  EstadoCita.noAsistio => (
    icono: Icons.person_off_outlined,
    color: ColoresMarca.error,
  ),
  EstadoCita.cancelada => (
    icono: Icons.event_busy_outlined,
    color: ColoresMarca.textoSuave,
  ),
};

/// «08:00–08:20»
String rangoHoras(Cita c) {
  String h(DateTime f) =>
      '${f.hour.toString().padLeft(2, '0')}:'
      '${f.minute.toString().padLeft(2, '0')}';
  return '${h(c.inicio)}–${h(c.fin)}';
}
