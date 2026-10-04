/// DTO tipados y normalizados que reciben los mappers (Fase 4: «normalizar»).
/// No llevan lógica de FHIR: solo los datos del repositorio, con su origen
/// (`tabla`, `pk`) para el grafo.
library;

class Origen {
  const Origen(this.tabla, this.pk);

  /// Clave del mapa de la historia o del almacén local.
  final String tabla;
  final String pk;
}

class PacienteDto {
  const PacienteDto({
    required this.origen,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.primerApellido,
    required this.segundoApellido,
    required this.primerNombre,
    required this.segundoNombre,
    required this.fechaNacimiento,
    required this.sexo,
    required this.ciudad,
    required this.nacionalidad,
    required this.paisResidencia,
    required this.etnia,
    required this.discapacidad,
    required this.zonaResidencia,
  });

  final Origen origen;

  /// Código local (`CC`, `TI`, …).
  final String tipoDocumento;
  final String numeroDocumento;
  final String primerApellido;
  final String segundoApellido;
  final String primerNombre;
  final String segundoNombre;

  /// `null` si solo se conoce la edad aproximada.
  final DateTime? fechaNacimiento;

  /// Código local `F`/`M`/`I`.
  final String? sexo;
  final String ciudad;
  final String nacionalidad;
  final String paisResidencia;
  final String etnia;
  final String discapacidad;
  final String zonaResidencia;
}

class ProfesionalDto {
  const ProfesionalDto({
    required this.origen,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.primerApellido,
    required this.segundoApellido,
    required this.nombres,
    required this.codigoRethus,
    required this.registro,
  });

  final Origen origen;
  final String tipoDocumento;
  final String numeroDocumento;
  final String primerApellido;
  final String segundoApellido;

  /// Uno o más nombres de pila.
  final List<String> nombres;
  final String codigoRethus;

  /// Registro profesional (RETHUS).
  final String registro;
}

class PrestadorDto {
  const PrestadorDto({
    required this.codigoHabilitacion,
    required this.modalidad,
    required this.entorno,
    required this.cupsConsulta,
  });

  final String codigoHabilitacion;
  final String modalidad;
  final String entorno;

  /// CUPS de la consulta según su tipo (ya resuelto).
  final String cupsConsulta;
}

class DiagnosticoDto {
  const DiagnosticoDto({
    required this.origen,
    required this.codigoCie10,
    required this.principal,
    required this.caracter,
  });

  final Origen origen;
  final String codigoCie10;
  final bool principal;

  /// Código local de carácter (`presuntivo`, `confirmado_nuevo`, …).
  final String caracter;
}

/// Encuentro (raíz local).
class EncuentroDto {
  const EncuentroDto({
    required this.origen,
    required this.id,
    required this.inicio,
    required this.fin,
    required this.tipoConsulta,
    required this.causaExterna,
  });

  final Origen origen;

  /// `historia.id`: identificador estable de la atención.
  final String id;

  /// Hora local del consultorio (sin zona: la zona la pone el mapper).
  final DateTime inicio;
  final DateTime fin;
  final String? tipoConsulta;
  final String? causaExterna;
}

/// Alergia codificada (`TipoAlergia`). Hoy el repositorio solo guarda
/// etiquetas de texto: la lista llega vacía y la sección va con
/// `emptyReason` (MATRIZ_RDA §3).
class AlergiaDto {
  const AlergiaDto({
    required this.origen,
    required this.tipo,
    required this.texto,
  });

  final Origen origen;
  final String tipo;
  final String texto;
}

/// Observación con perfil de la guía. Cada variante instancia un perfil.
sealed class ObservacionDto {
  const ObservacionDto(this.origen);

  final Origen origen;
}

/// `PatientOccupationAtEncounterRDA`: ocupación codificada en CIUO-88 A.C.
class OcupacionDto extends ObservacionDto {
  const OcupacionDto({required Origen origen, required this.codigoCiuo})
    : super(origen);

  final String codigoCiuo;
}

/// `AttendanceAllowanceRDA`: incapacidad.
class IncapacidadDto extends ObservacionDto {
  const IncapacidadDto({
    required Origen origen,
    required this.alcance,
    this.dias,
    this.inicio,
    this.fin,
    this.prospectiva,
    this.retroactiva,
    this.diasLicenciaMaternidad,
  }) : super(origen);

  /// Código `ColombianLicenseScope`.
  final String alcance;
  final int? dias;
  final DateTime? inicio;
  final DateTime? fin;
  final bool? prospectiva;
  final bool? retroactiva;
  final int? diasLicenciaMaternidad;
}

/// Procedimiento CUPS: realizado → `ProcedureRDA`; ordenado →
/// `ServiceRequestRDA`.
class ProcedimientoDto {
  const ProcedimientoDto({
    required this.origen,
    required this.cups,
    required this.finalidad,
    required this.fecha,
    required this.realizado,
    this.diagnosticoPrincipal,
    this.diagnosticoRelacionado,
  });

  final Origen origen;
  final String cups;

  /// Código `RIPSFinalidadConsultaVersion2`.
  final String finalidad;
  final DateTime fecha;
  final bool realizado;

  /// `pk` de los diagnósticos (`ProcedureRDA` exige principal y relacionado).
  final String? diagnosticoPrincipal;
  final String? diagnosticoRelacionado;
}

/// Prescripción (`MedicationRequestRDA`), según los slices vigentes.
class MedicamentoDto {
  const MedicamentoDto({
    required this.origen,
    required this.fecha,
    required this.finalidad,
    required this.duracionDias,
    required this.frecuencia,
    required this.via,
    required this.dosis,
    required this.unidadDosis,
    this.dci = const [],
    this.iumPrimerNivel,
    this.categoria,
    this.textoMagistral,
    this.indicacionEspecial,
    this.diagnosticoPk,
    this.instrucciones,
  });

  final Origen origen;
  final DateTime fecha;

  /// `RIPSFinalidadConsultaVersion2`.
  final String finalidad;
  final num duracionDias;

  /// Código `MedicationTime` de la frecuencia.
  final String frecuencia;

  /// Código `VAD` de la vía.
  final String via;
  final num dosis;

  /// Código `UMM` de la unidad de dosis.
  final String unidadDosis;

  /// Códigos `MipresINN` (DCI).
  final List<String> dci;

  /// Código `IUMPrimerNivel`.
  final String? iumPrimerNivel;

  /// `ColombianHealthTechnologyCategory` (medicamentos).
  final String? categoria;

  /// Preparaciones magistrales: texto del medicamento.
  final String? textoMagistral;

  /// `MipresSpecialInstruction`.
  final String? indicacionEspecial;
  final String? diagnosticoPk;
  final String? instrucciones;
}

/// Texto libre que no se codifica: viaja como narrativa de la sección con
/// `emptyReason` (MATRIZ_RDA §3).
class TextosLibresDto {
  const TextosLibresDto({
    this.alergias = const [],
    this.niegaAlergias = false,
    this.ocupacion = '',
    this.aseguradora = '',
    this.habitos = '',
    this.examenes = '',
    this.interconsultas = '',
  });

  final List<String> alergias;
  final bool niegaAlergias;
  final String ocupacion;
  final String aseguradora;
  final String habitos;
  final String examenes;
  final String interconsultas;
}

/// Todo lo que necesita el ensamblador para una atención.
class AtencionRda {
  const AtencionRda({
    required this.paciente,
    required this.profesional,
    required this.prestador,
    required this.encuentro,
    required this.diagnosticos,
    required this.textos,
    required this.pdf,
    this.alergias = const [],
    this.observaciones = const [],
    this.procedimientos = const [],
    this.medicamentos = const [],
  });

  final PacienteDto paciente;
  final ProfesionalDto profesional;
  final PrestadorDto prestador;
  final EncuentroDto encuentro;
  final List<DiagnosticoDto> diagnosticos;
  final TextosLibresDto textos;

  /// PDF de soporte (resumen de la atención), ya generado.
  final List<int> pdf;
  final List<AlergiaDto> alergias;
  final List<ObservacionDto> observaciones;
  final List<ProcedimientoDto> procedimientos;
  final List<MedicamentoDto> medicamentos;
}
