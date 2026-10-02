import 'package:flutter/material.dart';

import '../estado/validacion.dart';

IconData iconoSeccion(SeccionHistoria s) => switch (s) {
  SeccionHistoria.paciente => Icons.person_outline,
  SeccionHistoria.motivo => Icons.chat_bubble_outline,
  SeccionHistoria.antecedentes => Icons.history_edu_outlined,
  SeccionHistoria.signos => Icons.monitor_heart_outlined,
  SeccionHistoria.examen => Icons.accessibility_new,
  SeccionHistoria.diagnosticos => Icons.medical_information_outlined,
  SeccionHistoria.plan => Icons.assignment_outlined,
  SeccionHistoria.firma => Icons.draw_outlined,
  SeccionHistoria.evoluciones => Icons.timeline,
};
