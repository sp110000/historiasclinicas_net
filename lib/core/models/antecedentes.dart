import 'mapa.dart';

class GinecoObstetricos {
  const GinecoObstetricos({
    this.fum,
    this.gestaciones,
    this.partos,
    this.cesareas,
    this.abortos,
    this.vivos,
    this.anticoncepcion = '',
    this.gestante = false,
  });

  factory GinecoObstetricos.desdeMapa(Map<String, Object?> m) =>
      GinecoObstetricos(
        fum: m.fecha('fum'),
        gestaciones: m.entero('gestaciones'),
        partos: m.entero('partos'),
        cesareas: m.entero('cesareas'),
        abortos: m.entero('abortos'),
        vivos: m.entero('vivos'),
        anticoncepcion: m.texto('anticoncepcion'),
        gestante: m.booleano('gestante'),
      );

  /// Fecha de la última menstruación.
  final DateTime? fum;
  final int? gestaciones;
  final int? partos;
  final int? cesareas;
  final int? abortos;
  final int? vivos;
  final String anticoncepcion;

  /// Gestación en curso: cambia la interpretación del IMC y muestra la
  /// edad gestacional calculada desde la FUM.
  final bool gestante;

  bool get vacio =>
      fum == null &&
      [gestaciones, partos, cesareas, abortos, vivos].every((v) => v == null) &&
      anticoncepcion.trim().isEmpty &&
      !gestante;

  /// "G3 P1 C1 A1 V2"
  String get formula {
    String p(String letra, int? v) => v == null ? '' : '$letra$v';
    return [
      p('G', gestaciones),
      p('P', partos),
      p('C', cesareas),
      p('A', abortos),
      p('V', vivos),
    ].where((s) => s.isNotEmpty).join(' ');
  }

  GinecoObstetricos copyWith({
    Object? fum = sin,
    Object? gestaciones = sin,
    Object? partos = sin,
    Object? cesareas = sin,
    Object? abortos = sin,
    Object? vivos = sin,
    String? anticoncepcion,
    bool? gestante,
  }) => GinecoObstetricos(
    fum: cambio(fum, this.fum),
    gestaciones: cambio(gestaciones, this.gestaciones),
    partos: cambio(partos, this.partos),
    cesareas: cambio(cesareas, this.cesareas),
    abortos: cambio(abortos, this.abortos),
    vivos: cambio(vivos, this.vivos),
    anticoncepcion: anticoncepcion ?? this.anticoncepcion,
    gestante: gestante ?? this.gestante,
  );

  Map<String, Object?> aMapa() => compacto({
    'fum': fum == null ? null : fechaIso(fum!),
    'gestaciones': gestaciones,
    'partos': partos,
    'cesareas': cesareas,
    'abortos': abortos,
    'vivos': vivos,
    'anticoncepcion': anticoncepcion,
    'gestante': gestante ? true : null,
  });
}

class Antecedentes {
  const Antecedentes({
    this.alergias = const [],
    this.tiposAlergia = const {},
    this.niegaAlergias = false,
    this.personales = '',
    this.medicacionActual = '',
    this.quirurgicos = '',
    this.familiares = '',
    this.habitos = '',
    this.otros = '',
    this.gineco = const GinecoObstetricos(),
  });

  factory Antecedentes.desdeMapa(Map<String, Object?> m) => Antecedentes(
    alergias: m.listaTextos('alergias'),
    tiposAlergia: m.mapa('tiposAlergia').cast<String, String>(),
    niegaAlergias: m.booleano('niegaAlergias'),
    personales: m.texto('personales'),
    medicacionActual: m.texto('medicacionActual'),
    quirurgicos: m.texto('quirurgicos'),
    familiares: m.texto('familiares'),
    habitos: m.texto('habitos'),
    otros: m.texto('otros'),
    gineco: GinecoObstetricos.desdeMapa(m.mapa('ginecoObstetricos')),
  );

  /// Cada alergia es una etiqueta ("penicilina", "AINEs"): alimenta la
  /// alerta de la receta.
  final List<String> alergias;

  /// Tipo de cada alergia (código `TipoAlergia` del RDA, módulo IHCE):
  /// etiqueta → código. Solo se captura con el módulo habilitado.
  final Map<String, String> tiposAlergia;

  /// Distingue "niega alergias" de "no se preguntó".
  final bool niegaAlergias;
  final String personales;
  final String medicacionActual;
  final String quirurgicos;
  final String familiares;
  final String habitos;
  final String otros;
  final GinecoObstetricos gineco;

  bool get alergiasRegistradas => niegaAlergias || alergias.isNotEmpty;

  Antecedentes copyWith({
    List<String>? alergias,
    Map<String, String>? tiposAlergia,
    bool? niegaAlergias,
    String? personales,
    String? medicacionActual,
    String? quirurgicos,
    String? familiares,
    String? habitos,
    String? otros,
    GinecoObstetricos? gineco,
  }) => Antecedentes(
    alergias: alergias ?? this.alergias,
    tiposAlergia: tiposAlergia ?? this.tiposAlergia,
    niegaAlergias: niegaAlergias ?? this.niegaAlergias,
    personales: personales ?? this.personales,
    medicacionActual: medicacionActual ?? this.medicacionActual,
    quirurgicos: quirurgicos ?? this.quirurgicos,
    familiares: familiares ?? this.familiares,
    habitos: habitos ?? this.habitos,
    otros: otros ?? this.otros,
    gineco: gineco ?? this.gineco,
  );

  Map<String, Object?> aMapa() => compacto({
    'alergias': alergias.isEmpty ? null : alergias,
    'tiposAlergia': tiposAlergia.isEmpty ? null : tiposAlergia,
    'niegaAlergias': niegaAlergias ? true : null,
    'personales': personales,
    'medicacionActual': medicacionActual,
    'quirurgicos': quirurgicos,
    'familiares': familiares,
    'habitos': habitos,
    'otros': otros,
    'ginecoObstetricos': gineco.vacio ? null : gineco.aMapa(),
  });
}
