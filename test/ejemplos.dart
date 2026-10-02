import 'dart:convert';

import 'package:historiasclinicas_net/core/models/historia.dart';
import 'package:historiasclinicas_net/core/models/medico.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';

/// Historia con todas las secciones llenas, para tests.
HistoriaClinica historiaCompleta() => HistoriaClinica(
  id: '6f1c2b9e-0000-4000-8000-000000000001',
  pais: Pais.colombia,
  fechaAtencion: DateTime(2026, 10, 2, 9, 14),
  tipoConsulta: 'primera_vez',
  paciente: Paciente(
    primerApellido: 'Peña',
    segundoApellido: 'Muñoz',
    nombres: 'José Ángel',
    tipoDocumento: 'CC',
    numeroDocumento: '1032456789',
    fechaNacimiento: DateTime(1990, 3, 15),
    sexo: 'F',
    telefono: '300 123 4567',
    direccion: 'Calle 10 # 20-30',
    ciudad: 'Bogotá',
    ocupacion: 'Docente',
    aseguradora: 'EPS Sanitas',
    acompananteNombre: 'Ana Muñoz',
    acompananteParentesco: 'Madre',
  ),
  motivoConsulta: 'Dolor de garganta',
  enfermedadActual: 'Odinofagia y fiebre de 2 días. «ñ» 38,5 °C.',
  antecedentes: const Antecedentes(
    alergias: ['Penicilina', 'AINEs'],
    personales: 'Hipotiroidismo',
    medicacionActual: 'Levotiroxina 50 µg/día',
    quirurgicos: 'Apendicectomía (2010)',
    familiares: 'Madre con HTA',
    habitos: 'No fuma',
    gineco: GinecoObstetricos(
      gestaciones: 2,
      partos: 1,
      cesareas: 1,
      anticoncepcion: 'DIU',
    ),
  ),
  revisionSistemas: const RevisionSistemas(
    sistemas: {
      'generales': HallazgoSistema(
        estado: EstadoSistema.refiere,
        detalle: 'Fiebre no cuantificada y astenia',
      ),
      'respiratorio': HallazgoSistema(estado: EstadoSistema.niega),
      'cardiovascular': HallazgoSistema(estado: EstadoSistema.niega),
    },
    observaciones: 'Sin otros síntomas.',
  ),
  signos: const SignosVitales(
    paSistolica: 118,
    paDiastolica: 76,
    fc: 92,
    fr: 18,
    temperatura: 38.5,
    spo2: 97,
    peso: 64.5,
    talla: 162,
  ),
  examen: const ExamenFisico(
    estadoGeneral: 'Alerta, hidratada',
    hallazgos: 'Faringe eritematosa con exudado.',
  ),
  analisis:
      'Cuadro compatible con faringitis aguda; descartar origen bacteriano.',
  diagnosticos: const [
    Diagnostico(id: 'd1', descripcion: 'Faringitis aguda', codigo: 'J02.9'),
    Diagnostico(
      id: 'd2',
      descripcion: 'Fiebre',
      codigo: 'R50.9',
      tipo: 'relacionado',
      caracter: 'confirmado_nuevo',
    ),
  ],
  plan: PlanTratamiento(
    planTerapeutico: 'Manejo sintomático.',
    indicaciones:
        'Líquidos abundantes. Consultar si hay dificultad respiratoria.',
    proximoControl: DateTime(2026, 10, 9),
  ),
);

/// PNG mínimos (12x6) y distintos entre sí, para firma, sello y logo.
final pngFirma = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAwAAAAGCAYAAAD37n+BAAAAEklEQVR42mMQ0Yj6TwpmGIkaAAMBcel5m29DAAAAAElFTkSuQmCC',
);
final pngSello = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAwAAAAGCAYAAAD37n+BAAAAE0lEQVR42mOQi1pwghTMMBI1AAA5GYcBEaOYAAAAAABJRU5ErkJggg==',
);
final pngLogo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAwAAAAGCAYAAAD37n+BAAAAEklEQVR42mOQy+r9TwpmGIkaAI0plaHgY9aPAAAAAElFTkSuQmCC',
);

/// Médico configurado con firma, sello y logo, para tests.
Medico medicoEjemplo() => Medico(
  nombre: 'Dra. Ana Pérez Gómez',
  especialidad: 'Medicina interna',
  registro: 'RM 54321',
  consultorio: 'Consultorio Salud Plena',
  ciudad: 'Bogotá',
  telefono: '601 555 0101',
  firma: pngFirma,
  sello: pngSello,
  logo: pngLogo,
);
