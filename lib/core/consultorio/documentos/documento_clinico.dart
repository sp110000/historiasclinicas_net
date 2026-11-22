import '../../models/mapa.dart';
import '../../utils/fechas.dart';
import 'plantillas.dart';

/// Diagnóstico de un documento clínico: código CIE-10 (opcional) y
/// descripción, como en la historia.
class DiagnosticoDocumento {
  const DiagnosticoDocumento({this.codigo = '', this.descripcion = ''});

  /// Desde el resumen de la historia («J029 Faringitis aguda»).
  factory DiagnosticoDocumento.desdeTexto(String texto) {
    final m = RegExp(
      r'^([A-Z]\d{2}[A-Z0-9]{0,2}(?:\.\d+)?)\s+(.+)$',
    ).firstMatch(texto.trim());
    return m == null
        ? DiagnosticoDocumento(descripcion: texto.trim())
        : DiagnosticoDocumento(codigo: m.group(1)!, descripcion: m.group(2)!);
  }

  final String codigo;
  final String descripcion;

  bool get vacio => codigo.trim().isEmpty && descripcion.trim().isEmpty;

  /// «A09X Diarrea y gastroenteritis…»
  String get texto =>
      [codigo.trim(), descripcion.trim()].where((s) => s.isNotEmpty).join(' ');

  Map<String, Object?> aMapa() =>
      compacto({'codigo': codigo.trim(), 'descripcion': descripcion.trim()});

  static DiagnosticoDocumento desdeMapa(Map<String, Object?> m) =>
      DiagnosticoDocumento(
        codigo: m.texto('codigo'),
        descripcion: m.texto('descripcion'),
      );
}

/// Origen de la incapacidad (VERIFICAR: la de origen laboral la reconoce la
/// ARL, no la EPS).
enum OrigenIncapacidad {
  enfermedadGeneral('Enfermedad general'),
  accidenteTrabajo('Accidente de trabajo'),
  enfermedadLaboral('Enfermedad laboral');

  const OrigenIncapacidad(this.etiqueta);

  final String etiqueta;
}

/// Lo que se escribe en el formulario de un certificado, una incapacidad,
/// una orden o una remisión antes de emitirlo.
class BorradorDocumento {
  const BorradorDocumento({
    required this.tipo,
    required this.plantillaId,
    required this.versionPlantilla,
    required this.titulo,
    required this.texto,
    required this.desde,
    this.diagnostico = const DiagnosticoDocumento(),
    this.incluirDiagnostico = false,
    this.finalidad = '',
    this.destino = '',
    this.dias,
    this.prorroga = false,
    this.prorrogaDe = '',
    this.origen = OrigenIncapacidad.enfermedadGeneral,
  });

  final TipoPlantilla tipo;
  final String plantillaId;
  final int versionPlantilla;
  final String titulo;

  /// El texto de la plantilla ya con los datos del paciente y del médico,
  /// editable.
  final String texto;
  final DiagnosticoDocumento diagnostico;

  /// Certificado: el diagnóstico es reservado y solo va si el paciente lo
  /// autoriza (VERIFICAR). En la incapacidad, la orden y la remisión va
  /// siempre que se escriba.
  final bool incluirDiagnostico;

  /// Certificado: para qué se expide (Ley 23 de 1981, art. 51, VERIFICAR).
  final String finalidad;

  /// Remisión: especialidad o servicio.
  final String destino;

  /// Incapacidad: días, fecha de inicio y prórroga.
  final int? dias;
  final DateTime desde;
  final bool prorroga;

  /// Número de la incapacidad que se prorroga («IN-000012»), opcional.
  final String prorrogaDe;
  final OrigenIncapacidad origen;

  /// Último día de la incapacidad (el inicio cuenta como el primero).
  DateTime? get hasta {
    final d = dias;
    if (d == null || d < 1) return null;
    return DateTime(desde.year, desde.month, desde.day + d - 1);
  }

  /// El diagnóstico va en el PDF.
  bool get diagnosticoVisible =>
      !diagnostico.vacio &&
      (tipo != TipoPlantilla.certificado || incluirDiagnostico);

  BorradorDocumento copyWith({
    String? plantillaId,
    int? versionPlantilla,
    String? titulo,
    String? texto,
    DiagnosticoDocumento? diagnostico,
    bool? incluirDiagnostico,
    String? finalidad,
    String? destino,
    Object? dias = sin,
    DateTime? desde,
    bool? prorroga,
    String? prorrogaDe,
    OrigenIncapacidad? origen,
  }) => BorradorDocumento(
    tipo: tipo,
    plantillaId: plantillaId ?? this.plantillaId,
    versionPlantilla: versionPlantilla ?? this.versionPlantilla,
    titulo: titulo ?? this.titulo,
    texto: texto ?? this.texto,
    diagnostico: diagnostico ?? this.diagnostico,
    incluirDiagnostico: incluirDiagnostico ?? this.incluirDiagnostico,
    finalidad: finalidad ?? this.finalidad,
    destino: destino ?? this.destino,
    dias: cambio<int>(dias, this.dias),
    desde: desde ?? this.desde,
    prorroga: prorroga ?? this.prorroga,
    prorrogaDe: prorrogaDe ?? this.prorrogaDe,
    origen: origen ?? this.origen,
  );

  /// Los campos propios del tipo, para `documento.json`.
  Map<String, Object?> campos() => compacto({
    if (diagnosticoVisible) 'diagnostico': diagnostico.aMapa(),
    if (tipo == TipoPlantilla.certificado) 'finalidad': finalidad.trim(),
    if (tipo == TipoPlantilla.remision) 'destino': destino.trim(),
    if (tipo == TipoPlantilla.incapacidad) ...{
      'origen': origen.name,
      'dias': dias,
      'desde': fechaIso(desde),
      if (hasta != null) 'hasta': fechaIso(hasta!),
      'prorroga': prorroga,
      'prorrogaDe': prorroga ? prorrogaDe.trim() : null,
    },
  });
}

/// Datos del prestador que la incapacidad muestra (Decreto 1427 de 2022,
/// VERIFICAR).
class PrestadorDocumento {
  const PrestadorDocumento({
    this.nombre = '',
    this.nit = '',
    this.codigoReps = '',
  });

  final String nombre;
  final String nit;
  final String codigoReps;

  String get texto => [
    if (nombre.trim().isNotEmpty) nombre.trim(),
    if (nit.trim().isNotEmpty) 'NIT ${nit.trim()}',
    if (codigoReps.trim().isNotEmpty) 'código REPS ${codigoReps.trim()}',
  ].join(' · ');
}

/// Filas «Etiqueta: valor» del bloque de datos del PDF.
List<(String, String)> filasDocumento(
  BorradorDocumento b, {
  PrestadorDocumento prestador = const PrestadorDocumento(),
}) => [
  if (b.tipo == TipoPlantilla.remision && b.destino.trim().isNotEmpty)
    ('Remitido a', b.destino.trim()),
  if (b.diagnosticoVisible)
    (
      b.tipo == TipoPlantilla.orden ? 'Impresión diagnóstica' : 'Diagnóstico',
      b.diagnostico.texto,
    ),
  if (b.tipo == TipoPlantilla.incapacidad) ...[
    ('Origen', b.origen.etiqueta),
    if (b.dias != null && b.dias! > 0)
      ('Días', '${b.dias} (${numeroEnLetras(b.dias!)})'),
    ('Desde', formatoFecha(b.desde)),
    if (b.hasta != null) ('Hasta', formatoFecha(b.hasta!)),
    (
      'Prórroga',
      !b.prorroga
          ? 'No'
          : b.prorrogaDe.trim().isEmpty
          ? 'Sí'
          : 'Sí, de ${b.prorrogaDe.trim()}',
    ),
    if (prestador.texto.isNotEmpty) ('Prestador', prestador.texto),
  ],
  if (b.tipo == TipoPlantilla.certificado && b.finalidad.trim().isNotEmpty)
    ('Se expide con destino a', b.finalidad.trim()),
];

/// Las mismas filas, desde los campos sellados de un documento.
List<(String, String)> filasDeCampos(
  TipoPlantilla tipo,
  Map<String, Object?> campos, {
  PrestadorDocumento prestador = const PrestadorDocumento(),
}) {
  final desde = campos.fecha('desde');
  return filasDocumento(
    BorradorDocumento(
      tipo: tipo,
      plantillaId: '',
      versionPlantilla: 0,
      titulo: '',
      texto: '',
      desde: desde ?? DateTime(2000),
      diagnostico: campos['diagnostico'] == null
          ? const DiagnosticoDocumento()
          : DiagnosticoDocumento.desdeMapa(campos.mapa('diagnostico')),
      incluirDiagnostico: true,
      finalidad: campos.texto('finalidad'),
      destino: campos.texto('destino'),
      dias: campos.entero('dias'),
      prorroga: campos.booleano('prorroga'),
      prorrogaDe: campos.texto('prorrogaDe'),
      origen:
          OrigenIncapacidad.values.asNameMap()[campos.texto('origen')] ??
          OrigenIncapacidad.enfermedadGeneral,
    ),
    prestador: prestador,
  );
}

/// «tres», «veintiuno», «ciento ochenta»: los días de la incapacidad se
/// escriben también en letras, como en los documentos de papel. De 1 a 999.
String numeroEnLetras(int n) {
  if (n < 1 || n > 999) return '$n';
  const unidades = [
    '',
    'uno',
    'dos',
    'tres',
    'cuatro',
    'cinco',
    'seis',
    'siete',
    'ocho',
    'nueve',
    'diez',
    'once',
    'doce',
    'trece',
    'catorce',
    'quince',
    'dieciséis',
    'diecisiete',
    'dieciocho',
    'diecinueve',
    'veinte',
    'veintiuno',
    'veintidós',
    'veintitrés',
    'veinticuatro',
    'veinticinco',
    'veintiséis',
    'veintisiete',
    'veintiocho',
    'veintinueve',
  ];
  const decenas = [
    '',
    '',
    '',
    'treinta',
    'cuarenta',
    'cincuenta',
    'sesenta',
    'setenta',
    'ochenta',
    'noventa',
  ];
  const centenas = [
    '',
    'ciento',
    'doscientos',
    'trescientos',
    'cuatrocientos',
    'quinientos',
    'seiscientos',
    'setecientos',
    'ochocientos',
    'novecientos',
  ];
  String hasta99(int m) {
    if (m < 30) return unidades[m];
    final d = decenas[m ~/ 10];
    return m % 10 == 0 ? d : '$d y ${unidades[m % 10]}';
  }

  if (n == 100) return 'cien';
  final c = n ~/ 100;
  final resto = n % 100;
  return [if (c > 0) centenas[c], if (resto > 0) hasta99(resto)].join(' ');
}
