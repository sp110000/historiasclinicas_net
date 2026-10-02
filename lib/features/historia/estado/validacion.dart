import '../../../core/clinica/rangos.dart';
import '../../../core/models/historia.dart';
import '../../../core/models/secciones.dart';

export '../../../core/models/secciones.dart';

/// Dato que falta (o es inválido) para poder finalizar la historia.
class Pendiente {
  const Pendiente(this.seccion, this.campo);

  final SeccionHistoria seccion;
  final String campo;

  @override
  String toString() => '${seccion.titulo}: $campo';
}

bool _vacio(String s) => s.trim().isEmpty;

/// Lo que impide finalizar la historia. Lista vacía = se puede finalizar.
List<Pendiente> pendientesParaFinalizar(HistoriaClinica h, {DateTime? ahora}) {
  final hoy = ahora ?? DateTime.now();
  final p = h.paciente;
  final pendientes = <Pendiente>[];
  void falta(SeccionHistoria s, String campo) =>
      pendientes.add(Pendiente(s, campo));

  const pac = SeccionHistoria.paciente;
  if (h.fechaAtencion.isAfter(hoy.add(const Duration(days: 1)))) {
    falta(pac, 'Fecha de la atención en el futuro');
  }
  if (_vacio(p.primerApellido)) falta(pac, 'Primer apellido');
  if (_vacio(p.nombres)) falta(pac, 'Nombres');
  if (_vacio(p.tipoDocumento)) falta(pac, 'Tipo de documento');
  if (_vacio(p.numeroDocumento)) falta(pac, 'Número de documento');
  if (p.fechaNacimiento == null && p.edadAproximada == null) {
    falta(pac, 'Fecha de nacimiento (o edad aproximada)');
  } else if (p.fechaNacimiento != null && h.edad == null) {
    falta(pac, 'Fecha de nacimiento posterior a la atención');
  }
  if (p.sexo == null) falta(pac, 'Sexo');

  if (_vacio(h.motivoConsulta)) {
    falta(SeccionHistoria.motivo, 'Motivo de consulta');
  }
  if (_vacio(h.enfermedadActual)) {
    falta(SeccionHistoria.motivo, 'Enfermedad actual');
  }

  if (!h.antecedentes.alergiasRegistradas) {
    falta(SeccionHistoria.antecedentes, 'Alergias (o marcar "Niega alergias")');
  }

  for (final (nombre, valor, rango) in signosConRango(h.signos)) {
    if (valor != null && !rango.esPlausible(valor)) {
      falta(SeccionHistoria.signos, '$nombre: valor no plausible');
    }
  }

  final conDescripcion = h.diagnosticos.where((d) => !_vacio(d.descripcion));
  if (conDescripcion.isEmpty) {
    falta(SeccionHistoria.diagnosticos, 'Al menos un diagnóstico');
  }
  if (h.diagnosticos.any((d) => _vacio(d.descripcion))) {
    falta(SeccionHistoria.diagnosticos, 'Diagnóstico sin descripción');
  }
  return pendientes;
}

/// (nombre, valor, rango) de cada signo vital.
List<(String, double?, RangoSigno)> signosConRango(SignosVitales s) => [
  ('PA sistólica', s.paSistolica, Rangos.paSistolica),
  ('PA diastólica', s.paDiastolica, Rangos.paDiastolica),
  ('FC', s.fc, Rangos.fc),
  ('FR', s.fr, Rangos.fr),
  ('Temperatura', s.temperatura, Rangos.temperatura),
  ('SpO₂', s.spo2, Rangos.spo2),
  ('Peso', s.peso, Rangos.peso),
  ('Talla', s.talla, Rangos.talla),
  ('Glucemia', s.glucemia, Rangos.glucemia),
  ('Perímetro abdominal', s.perimetroAbdominal, Rangos.perimetroAbdominal),
];

enum Avance { vacia, parcial, completa }

/// Avance de cada sección, para el índice lateral.
Avance avanceSeccion(SeccionHistoria s, HistoriaClinica h) {
  final pendientes = pendientesParaFinalizar(h).where((p) => p.seccion == s);
  final datos = switch (s) {
    SeccionHistoria.paciente => h.paciente.aMapa().keys.any(
      (k) => k != 'tipoDocumento',
    ),
    SeccionHistoria.motivo =>
      !_vacio(h.motivoConsulta) || !_vacio(h.enfermedadActual),
    SeccionHistoria.antecedentes => h.antecedentes.aMapa().isNotEmpty,
    SeccionHistoria.revision => !h.revisionSistemas.vacia,
    SeccionHistoria.signos => !h.signos.vacio,
    SeccionHistoria.examen => h.examen.aMapa().isNotEmpty,
    SeccionHistoria.analisis => h.analisis.trim().isNotEmpty,
    SeccionHistoria.diagnosticos => h.diagnosticos.isNotEmpty,
    SeccionHistoria.plan => h.plan.aMapa().isNotEmpty,
    // Se completa con los datos del médico (Fase 2).
    SeccionHistoria.firma => false,
    SeccionHistoria.evoluciones => false,
  };
  if (!datos) return Avance.vacia;
  // La revisión por sistemas está completa cuando todos tienen respuesta.
  if (s == SeccionHistoria.revision && !h.revisionSistemas.completa) {
    return Avance.parcial;
  }
  return pendientes.isEmpty ? Avance.completa : Avance.parcial;
}
