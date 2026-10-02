/// Secciones de la historia, en el orden del formulario y del PDF.
enum SeccionHistoria {
  paciente('Datos del paciente', 'Paciente'),
  motivo('Motivo de consulta y enfermedad actual', 'Motivo'),
  antecedentes('Antecedentes', 'Antecedentes'),
  signos('Signos vitales', 'Signos vitales'),
  examen('Examen físico', 'Examen físico'),
  diagnosticos('Diagnósticos', 'Diagnósticos'),
  plan('Plan de tratamiento e indicaciones', 'Plan'),
  firma('Firma y sello', 'Firma y sello'),
  evoluciones('Evoluciones', 'Evoluciones');

  const SeccionHistoria(this.titulo, this.tituloCorto);

  final String titulo;
  final String tituloCorto;

  int get numero => index + 1;
}
