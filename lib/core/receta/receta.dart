import '../models/historia.dart';
import '../models/mapa.dart';
import '../pais/perfil_pais.dart';
import '../presentacion/datos_historia.dart';
import '../utils/fechas.dart';
import 'numero_letras.dart';

/// Un medicamento de la receta.
class ItemReceta {
  const ItemReceta({
    required this.id,
    this.medicamento = '',
    this.concentracion = '',
    this.forma = '',
    this.dosis = '',
    this.via = '',
    this.frecuencia = '',
    this.duracion = '',
    this.cantidad,
    this.unidad = '',
    this.nota = '',
  });

  factory ItemReceta.desdeMapa(Map<String, Object?> m) => ItemReceta(
    id: m.texto('id'),
    medicamento: m.texto('medicamento'),
    concentracion: m.texto('concentracion'),
    forma: m.texto('forma'),
    dosis: m.texto('dosis'),
    via: m.texto('via'),
    frecuencia: m.texto('frecuencia'),
    duracion: m.texto('duracion'),
    cantidad: m.entero('cantidad'),
    unidad: m.texto('unidad'),
    nota: m.texto('nota'),
  );

  final String id;

  /// Denominación común (DCI) o genérico.
  final String medicamento;

  /// "500 mg", "250 mg/5 mL".
  final String concentracion;

  /// Forma farmacéutica: "cápsula", "jarabe"…
  final String forma;

  /// "1 cápsula", "5 mL".
  final String dosis;

  /// "oral", "tópica"…
  final String via;

  /// "cada 8 horas".
  final String frecuencia;

  /// "7 días".
  final String duracion;

  /// Unidades a dispensar (se imprime también en letras).
  final int? cantidad;

  /// Unidad de la cantidad: "cápsulas", "frascos", "envases"…
  final String unidad;

  /// Indicación particular: "con alimentos", "si hay dolor o fiebre"…
  final String nota;

  ItemReceta copyWith({
    String? medicamento,
    String? concentracion,
    String? forma,
    String? dosis,
    String? via,
    String? frecuencia,
    String? duracion,
    Object? cantidad = sin,
    String? unidad,
    String? nota,
  }) => ItemReceta(
    id: id,
    medicamento: medicamento ?? this.medicamento,
    concentracion: concentracion ?? this.concentracion,
    forma: forma ?? this.forma,
    dosis: dosis ?? this.dosis,
    via: via ?? this.via,
    frecuencia: frecuencia ?? this.frecuencia,
    duracion: duracion ?? this.duracion,
    cantidad: cambio<int>(cantidad, this.cantidad),
    unidad: unidad ?? this.unidad,
    nota: nota ?? this.nota,
  );

  Map<String, Object?> aMapa() => compacto({
    'id': id,
    'medicamento': medicamento,
    'concentracion': concentracion,
    'forma': forma,
    'dosis': dosis,
    'via': via,
    'frecuencia': frecuencia,
    'duracion': duracion,
    'cantidad': cantidad,
    'unidad': unidad,
    'nota': nota,
  });

  bool get vacio =>
      medicamento.trim().isEmpty &&
      concentracion.trim().isEmpty &&
      forma.trim().isEmpty &&
      dosis.trim().isEmpty &&
      via.trim().isEmpty &&
      frecuencia.trim().isEmpty &&
      duracion.trim().isEmpty &&
      cantidad == null &&
      nota.trim().isEmpty;

  /// Datos obligatorios que faltan.
  List<String> get faltantes => [
    if (medicamento.trim().isEmpty) 'medicamento',
    if (concentracion.trim().isEmpty) 'concentración',
    if (forma.trim().isEmpty) 'forma farmacéutica',
    if (dosis.trim().isEmpty) 'dosis',
    if (via.trim().isEmpty) 'vía',
    if (frecuencia.trim().isEmpty) 'frecuencia',
    if (duracion.trim().isEmpty) 'duración',
    if (cantidad == null || cantidad == 0) 'cantidad',
  ];

  /// "AMOXICILINA 500 mg · cápsula"
  String get titulo {
    final nombre = [
      medicamento.trim().toUpperCase(),
      concentracion.trim(),
    ].where((t) => t.isNotEmpty).join(' ');
    return [nombre, forma.trim()].where((t) => t.isNotEmpty).join(' · ');
  }

  /// "1 cápsula vía oral cada 8 horas durante 7 días. Con alimentos."
  String get posologia {
    final d = duracion.trim();
    final partes = [
      dosis.trim(),
      if (via.trim().isNotEmpty) 'vía ${via.trim()}',
      frecuencia.trim(),
      if (d.isNotEmpty) RegExp(r'^\d').hasMatch(d) ? 'durante $d' : d,
    ].where((t) => t.isNotEmpty).join(' ');
    final n = nota.trim();
    return [
      if (partes.isNotEmpty) '$partes.',
      if (n.isNotEmpty) n.endsWith('.') ? n : '$n.',
    ].join(' ');
  }

  /// "21 (veintiuno) cápsulas"
  String get textoCantidad {
    final c = cantidad;
    if (c == null) return '';
    return [
      '$c (${numeroALetras(c)})',
      unidad.trim(),
    ].where((t) => t.isNotEmpty).join(' ');
  }

  /// Una línea para registrar en la historia.
  String get resumen => [
    titulo,
    posologia,
    if (cantidad != null) 'Cantidad: $textoCantidad.',
  ].where((t) => t.isNotEmpty).join(' ');
}

/// Datos del paciente en la receta: salen de la historia y se pueden
/// corregir en la propia receta.
class PacienteReceta {
  const PacienteReceta({
    this.nombre = '',
    this.documento = '',
    this.edad = '',
    this.fechaNacimiento = '',
    this.diagnostico = '',
    this.alergias = '',
  });

  factory PacienteReceta.deHistoria(HistoriaClinica h) {
    final p = h.paciente;
    return PacienteReceta(
      nombre: p.nombreCompleto,
      documento: p.numeroDocumento.isEmpty
          ? ''
          : '${p.tipoDocumento} ${p.numeroDocumento}',
      edad: h.edadTexto,
      fechaNacimiento: p.fechaNacimiento == null
          ? ''
          : formatoFecha(p.fechaNacimiento!),
      diagnostico: h.diagnosticos
          .map((d) => d.textoCorto)
          .where((t) => t.isNotEmpty)
          .join('; '),
      alergias: h.antecedentes.alergiasRegistradas
          ? textoAlergias(h.antecedentes)
          : '',
    );
  }

  final String nombre;
  final String documento;
  final String edad;

  /// La pide la norma española (VERIFICAR).
  final String fechaNacimiento;
  final String diagnostico;
  final String alergias;

  static const campos = [
    'nombre',
    'documento',
    'edad',
    'fechaNacimiento',
    'diagnostico',
    'alergias',
  ];

  String valor(String campo) => switch (campo) {
    'nombre' => nombre,
    'documento' => documento,
    'edad' => edad,
    'fechaNacimiento' => fechaNacimiento,
    'diagnostico' => diagnostico,
    'alergias' => alergias,
    _ => throw ArgumentError.value(campo, 'campo'),
  };

  /// Aplica las correcciones hechas en la receta ([ajustes]: campo → valor).
  PacienteReceta conAjustes(Map<String, String> ajustes) => PacienteReceta(
    nombre: ajustes['nombre'] ?? nombre,
    documento: ajustes['documento'] ?? documento,
    edad: ajustes['edad'] ?? edad,
    fechaNacimiento: ajustes['fechaNacimiento'] ?? fechaNacimiento,
    diagnostico: ajustes['diagnostico'] ?? diagnostico,
    alergias: ajustes['alergias'] ?? alergias,
  );
}

/// Receta en edición. Pertenece a la historia [historiaId].
class Receta {
  const Receta({
    required this.id,
    required this.historiaId,
    required this.fecha,
    this.numero,
    this.items = const [],
    this.indicaciones = '',
    this.incluirFirma = true,
    this.incluirSello = true,
    this.ajustesPaciente = const {},
    this.alertasVistas = const {},
    this.registradaEnHistoria = false,
  });

  factory Receta.desdeMapa(Map<String, Object?> m) => Receta(
    id: m.texto('id'),
    historiaId: m.texto('historiaId'),
    fecha: m.fecha('fecha')!,
    numero: m.textoONulo('numero'),
    items: [for (final i in m.listaMapas('items')) ItemReceta.desdeMapa(i)],
    indicaciones: m.texto('indicaciones'),
    incluirFirma: m.booleano('incluirFirma', porDefecto: true),
    incluirSello: m.booleano('incluirSello', porDefecto: true),
    ajustesPaciente: m.mapa('ajustesPaciente').cast<String, String>(),
    alertasVistas: m.listaTextos('alertasVistas').toSet(),
    registradaEnHistoria: m.booleano('registradaEnHistoria'),
  );

  final String id;
  final String historiaId;
  final DateTime fecha;

  /// "R-000123": se asigna al imprimir o guardar, si la numeración está
  /// activada.
  final String? numero;
  final List<ItemReceta> items;
  final String indicaciones;
  final bool incluirFirma;
  final bool incluirSello;

  /// Correcciones de los datos del paciente (campo → valor).
  final Map<String, String> ajustesPaciente;

  /// Alertas de alergia que el médico ya leyó.
  final Set<String> alertasVistas;

  /// Ya se registró en la historia ("Se formuló: …").
  final bool registradaEnHistoria;

  Receta copyWith({
    DateTime? fecha,
    Object? numero = sin,
    List<ItemReceta>? items,
    String? indicaciones,
    bool? incluirFirma,
    bool? incluirSello,
    Map<String, String>? ajustesPaciente,
    Set<String>? alertasVistas,
    bool? registradaEnHistoria,
  }) => Receta(
    id: id,
    historiaId: historiaId,
    fecha: fecha ?? this.fecha,
    numero: cambio<String>(numero, this.numero),
    items: items ?? this.items,
    indicaciones: indicaciones ?? this.indicaciones,
    incluirFirma: incluirFirma ?? this.incluirFirma,
    incluirSello: incluirSello ?? this.incluirSello,
    ajustesPaciente: ajustesPaciente ?? this.ajustesPaciente,
    alertasVistas: alertasVistas ?? this.alertasVistas,
    registradaEnHistoria: registradaEnHistoria ?? this.registradaEnHistoria,
  );

  Map<String, Object?> aMapa() => compacto({
    'id': id,
    'historiaId': historiaId,
    'fecha': fechaHoraIso(fecha),
    'numero': numero,
    'items': [for (final i in items) i.aMapa()],
    'indicaciones': indicaciones,
    'incluirFirma': incluirFirma,
    'incluirSello': incluirSello,
    'ajustesPaciente': ajustesPaciente.isEmpty ? null : ajustesPaciente,
    'alertasVistas': alertasVistas.isEmpty ? null : alertasVistas.toList(),
    'registradaEnHistoria': registradaEnHistoria ? true : null,
  });

  /// Ítems con algo escrito (los vacíos no se imprimen).
  List<ItemReceta> get itemsConDatos =>
      items.where((i) => !i.vacio).toList(growable: false);

  /// Ni medicamentos ni indicaciones. Una receta puede llevar solo
  /// indicaciones (recomendaciones sin medicamentos).
  bool get sinContenido => itemsConDatos.isEmpty && indicaciones.trim().isEmpty;

  /// "Se formuló (R-000123): 1. … 2. …" para el plan o la evolución, o
  /// "Se dieron indicaciones (R-000123)…" si no lleva medicamentos.
  String textoParaHistoria() {
    final lista = itemsConDatos;
    final b = StringBuffer(
      '${lista.isEmpty ? 'Se dieron indicaciones' : 'Se formuló'}'
      '${numero == null ? '' : ' ($numero)'} el ${formatoFecha(fecha)}:',
    );
    for (final (i, item) in lista.indexed) {
      b.write('\n${i + 1}. ${item.resumen}');
    }
    if (indicaciones.trim().isNotEmpty) {
      b.write('\nIndicaciones: ${indicaciones.trim()}');
    }
    return b.toString();
  }
}

/// Formato del número de receta: `R-000123`.
String formatoNumeroReceta(int n) => 'R-${n.toString().padLeft(6, '0')}';

// ─────────────── Opciones sugeridas (se puede escribir otra) ───────────────

/// Formas farmacéuticas frecuentes. En España se dice "comprimido" y en
/// Colombia "tableta".
List<String> formasFarmaceuticas(Pais pais) => [
  if (pais == Pais.espana) 'comprimido' else 'tableta',
  'cápsula',
  if (pais == Pais.espana) 'tableta' else 'comprimido',
  'tableta recubierta',
  'cápsula blanda',
  'sobre',
  'jarabe',
  'suspensión',
  'solución oral',
  'gotas orales',
  'ampolla',
  'vial',
  'crema',
  'ungüento',
  'gel',
  'loción',
  'gotas oftálmicas',
  'gotas óticas',
  'spray nasal',
  'inhalador',
  'óvulo',
  'supositorio',
  'parche',
];

const viasAdministracion = [
  'oral',
  'sublingual',
  'tópica',
  'oftálmica',
  'ótica',
  'nasal',
  'inhalada',
  'intramuscular',
  'intravenosa',
  'subcutánea',
  'rectal',
  'vaginal',
  'transdérmica',
];

const frecuenciasFrecuentes = [
  'cada 4 horas',
  'cada 6 horas',
  'cada 8 horas',
  'cada 12 horas',
  'cada 24 horas',
  'una vez al día',
  'dos veces al día',
  'tres veces al día',
  'en la noche',
  'dosis única',
];

const duracionesFrecuentes = [
  '3 días',
  '5 días',
  '7 días',
  '10 días',
  '14 días',
  '30 días',
  'uso continuo',
];

/// Unidad de la cantidad según la forma: "cápsula" → "cápsulas".
String unidadSugerida(String forma) {
  final f = forma.trim().toLowerCase();
  if (f.isEmpty) return '';
  const contables = {
    'tableta': 'tabletas',
    'tableta recubierta': 'tabletas',
    'comprimido': 'comprimidos',
    'cápsula': 'cápsulas',
    'cápsula blanda': 'cápsulas',
    'sobre': 'sobres',
    'ampolla': 'ampollas',
    'vial': 'viales',
    'óvulo': 'óvulos',
    'supositorio': 'supositorios',
    'parche': 'parches',
  };
  const envases = {
    'jarabe': 'frascos',
    'suspensión': 'frascos',
    'solución oral': 'frascos',
    'gotas orales': 'frascos',
    'gotas oftálmicas': 'frascos',
    'gotas óticas': 'frascos',
    'spray nasal': 'frascos',
    'inhalador': 'inhaladores',
    'crema': 'tubos',
    'ungüento': 'tubos',
    'gel': 'tubos',
    'loción': 'frascos',
  };
  return contables[f] ?? envases[f] ?? '';
}
