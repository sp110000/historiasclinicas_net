import '../../models/mapa.dart';
import '../../utils/numeros.dart';

/// Un paso del esquema de titulación: desde la semana [semana] (contada
/// desde el inicio), [dosis] en [unidad].
class PasoEsquema {
  const PasoEsquema({
    required this.semana,
    required this.dosis,
    this.unidad = 'mg',
  });

  final int semana;
  final double dosis;
  final String unidad;

  String get texto => 'semana $semana: ${formatoNumero(dosis)} $unidad';

  Map<String, Object?> aMapa() => {
    'semana': semana,
    'dosis': dosis,
    'unidad': unidad,
  };

  static PasoEsquema desdeMapa(Map<String, Object?> m) => PasoEsquema(
    semana: m.entero('semana') ?? 0,
    dosis: m.decimal('dosis') ?? 0,
    unidad: m.texto('unidad').isEmpty ? 'mg' : m.texto('unidad'),
  );
}

/// Medicamento del catálogo GLP-1 (pregunta 24). Todo es editable y todo
/// va **VERIFICAR** contra la ficha técnica con registro Invima: la app no
/// trae dosis; el esquema de titulación lo escribe y lo aprueba el médico.
class MedicamentoGlp1 {
  const MedicamentoGlp1({
    required this.id,
    required this.generico,
    required this.comercial,
    required this.via,
    this.registroInvima = '',
    this.indicacion = '',
    this.esquema = const [],
    this.esquemaAprobadoEn,
    this.actualizado,
  });

  static const coleccion = 'catalogoGlp1';

  final String id;
  final String generico;
  final String comercial;

  /// Vía y frecuencia («Subcutánea semanal»).
  final String via;

  /// Vacío: «registro Invima sin confirmar» (avisa).
  final String registroInvima;

  /// Indicación aprobada en la ficha técnica; vacía si no se confirmó.
  final String indicacion;
  final List<PasoEsquema> esquema;

  /// `null`: esquema sin aprobar (se muestra como referencia, no se sugiere).
  final DateTime? esquemaAprobadoEn;
  final DateTime? actualizado;

  bool get registroConfirmado => registroInvima.trim().isNotEmpty;
  bool get esquemaAprobado => esquemaAprobadoEn != null && esquema.isNotEmpty;

  /// «Semaglutida (Ozempic®) · Subcutánea semanal».
  String get nombre =>
      '$generico${comercial.isEmpty ? '' : ' ($comercial)'} · $via';

  /// La dosis que sugiere el esquema aprobado en [semana] (desde el
  /// inicio), o `null`.
  PasoEsquema? pasoEnSemana(int semana) {
    if (!esquemaAprobado) return null;
    PasoEsquema? r;
    for (final p in [...esquema]..sort((a, b) => a.semana - b.semana)) {
      if (p.semana <= semana) r = p;
    }
    return r;
  }

  MedicamentoGlp1 copyWith({
    String? registroInvima,
    String? indicacion,
    List<PasoEsquema>? esquema,
    Object? esquemaAprobadoEn = sin,
    DateTime? actualizado,
  }) => MedicamentoGlp1(
    id: id,
    generico: generico,
    comercial: comercial,
    via: via,
    registroInvima: registroInvima ?? this.registroInvima,
    indicacion: indicacion ?? this.indicacion,
    esquema: esquema ?? this.esquema,
    esquemaAprobadoEn: cambio(esquemaAprobadoEn, this.esquemaAprobadoEn),
    actualizado: actualizado ?? this.actualizado,
  );

  Map<String, Object?> aMapa() => compacto({
    'generico': generico,
    'comercial': comercial,
    'via': via,
    'registroInvima': registroInvima,
    'indicacion': indicacion,
    if (esquema.isNotEmpty) 'esquema': [for (final p in esquema) p.aMapa()],
    'esquemaAprobadoEn': esquemaAprobadoEn?.toUtc().toIso8601String(),
    'actualizado': actualizado?.toUtc().toIso8601String(),
  });

  static MedicamentoGlp1 desdeMapa(String id, Map<String, Object?> m) =>
      MedicamentoGlp1(
        id: id,
        generico: m.texto('generico'),
        comercial: m.texto('comercial'),
        via: m.texto('via'),
        registroInvima: m.texto('registroInvima'),
        indicacion: m.texto('indicacion'),
        esquema: [
          for (final p in m.listaMapas('esquema')) PasoEsquema.desdeMapa(p),
        ],
        esquemaAprobadoEn: m['esquemaAprobadoEn'] == null
            ? null
            : DateTime.parse(m['esquemaAprobadoEn']! as String).toLocal(),
        actualizado: m['actualizado'] == null
            ? null
            : DateTime.parse(m['actualizado']! as String).toLocal(),
      );
}

/// Catálogo de fábrica (VERIFICAR). Solo OZEMPIC® tiene registro
/// confirmado en lo que se encontró (2019M-0019473, para el control
/// glucémico en diabetes tipo 2); los demás quedan «sin confirmar» hasta
/// que el médico escriba el número. Ningún esquema trae dosis.
const catalogoGlp1Base = [
  MedicamentoGlp1(
    id: 'semaglutida_sc',
    generico: 'Semaglutida',
    comercial: 'Ozempic®',
    via: 'Subcutánea semanal',
    registroInvima: '2019M-0019473',
    indicacion: 'Control glucémico en diabetes mellitus tipo 2',
  ),
  MedicamentoGlp1(
    id: 'semaglutida_oral',
    generico: 'Semaglutida oral',
    comercial: 'Rybelsus®',
    via: 'Oral diaria',
  ),
  MedicamentoGlp1(
    id: 'liraglutida',
    generico: 'Liraglutida',
    comercial: 'Saxenda® / Victoza®',
    via: 'Subcutánea diaria',
  ),
  MedicamentoGlp1(
    id: 'tirzepatida',
    generico: 'Tirzepatida (GIP/GLP-1)',
    comercial: 'Mounjaro®',
    via: 'Subcutánea semanal',
  ),
];

/// Contraindicación o precaución de la lista del programa (pregunta 25).
class ItemContraindicacion {
  const ItemContraindicacion({
    required this.id,
    required this.texto,
    required this.absoluta,
    this.soloMujeres = false,
  });

  final String id;
  final String texto;

  /// Absoluta: en «sí» (o sin aclarar) impide iniciar el GLP-1. Si no,
  /// es una precaución que pide una nota.
  final bool absoluta;

  /// Solo aplica a mujeres (embarazo, lactancia, anticoncepción).
  final bool soloMujeres;
}

/// Versión de la lista de contraindicaciones (se guarda con cada revisión).
const versionContraindicacionesGlp1 = 1;

/// Lista por defecto (VERIFICAR contra la ficha técnica con registro
/// Invima de cada medicamento).
const contraindicacionesGlp1 = [
  ItemContraindicacion(
    id: 'cmt_men2',
    texto:
        'Antecedente personal o familiar de carcinoma medular de tiroides o '
        'de neoplasia endocrina múltiple tipo 2 (MEN2)',
    absoluta: true,
  ),
  ItemContraindicacion(
    id: 'pancreatitis',
    texto: 'Antecedente de pancreatitis',
    absoluta: true,
  ),
  ItemContraindicacion(
    id: 'embarazo',
    texto: 'Embarazo',
    absoluta: true,
    soloMujeres: true,
  ),
  ItemContraindicacion(
    id: 'lactancia',
    texto: 'Lactancia',
    absoluta: true,
    soloMujeres: true,
  ),
  ItemContraindicacion(
    id: 'hipersensibilidad',
    texto: 'Hipersensibilidad al medicamento o a sus componentes',
    absoluta: true,
  ),
  ItemContraindicacion(
    id: 'biliar',
    texto: 'Enfermedad biliar',
    absoluta: false,
  ),
  ItemContraindicacion(
    id: 'retinopatia',
    texto: 'Retinopatía diabética',
    absoluta: false,
  ),
  ItemContraindicacion(
    id: 'naion',
    texto: 'Neuropatía óptica isquémica (NAION) o neuritis óptica',
    absoluta: false,
  ),
  ItemContraindicacion(
    id: 'gastrointestinal',
    texto: 'Gastroparesia o enfermedad gastrointestinal grave',
    absoluta: false,
  ),
  ItemContraindicacion(id: 'dm1', texto: 'Diabetes tipo 1', absoluta: false),
  ItemContraindicacion(
    id: 'renal',
    texto: 'Insuficiencia renal o riesgo de deshidratación',
    absoluta: false,
  ),
  ItemContraindicacion(
    id: 'depresion',
    texto: 'Depresión o ideación suicida',
    absoluta: false,
  ),
  ItemContraindicacion(
    id: 'cirugia',
    texto: 'Cirugía o sedación programada',
    absoluta: false,
  ),
  ItemContraindicacion(
    id: 'hipoglucemiantes',
    texto: 'Uso de insulina o sulfonilureas',
    absoluta: false,
  ),
  ItemContraindicacion(
    id: 'fertil',
    texto:
        'Mujer en edad fértil: anticoncepción y plan de embarazo (suspender '
        'antes; VERIFICAR el plazo en la ficha técnica)',
    absoluta: false,
    soloMujeres: true,
  ),
];
