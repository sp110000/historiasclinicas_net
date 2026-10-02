import 'mapa.dart';

/// Como [cambio], pero acepta cualquier número (72 o 72.0).
double? _numero(Object? nuevo, double? actual) =>
    identical(nuevo, sin) ? actual : (nuevo as num?)?.toDouble();

class SignosVitales {
  const SignosVitales({
    this.paSistolica,
    this.paDiastolica,
    this.fc,
    this.fr,
    this.temperatura,
    this.spo2,
    this.peso,
    this.talla,
    this.glucemia,
    this.perimetroAbdominal,
  });

  factory SignosVitales.desdeMapa(Map<String, Object?> m) => SignosVitales(
    paSistolica: m.decimal('paSistolica'),
    paDiastolica: m.decimal('paDiastolica'),
    fc: m.decimal('fc'),
    fr: m.decimal('fr'),
    temperatura: m.decimal('temperatura'),
    spo2: m.decimal('spo2'),
    peso: m.decimal('peso'),
    talla: m.decimal('talla'),
    glucemia: m.decimal('glucemia'),
    perimetroAbdominal: m.decimal('perimetroAbdominal'),
  );

  /// mmHg
  final double? paSistolica;
  final double? paDiastolica;

  /// latidos por minuto
  final double? fc;

  /// respiraciones por minuto
  final double? fr;

  /// °C
  final double? temperatura;

  /// %
  final double? spo2;

  /// kg
  final double? peso;

  /// cm
  final double? talla;

  /// mg/dL
  final double? glucemia;

  /// cm
  final double? perimetroAbdominal;

  bool get vacio => aMapa().isEmpty;

  SignosVitales copyWith({
    Object? paSistolica = sin,
    Object? paDiastolica = sin,
    Object? fc = sin,
    Object? fr = sin,
    Object? temperatura = sin,
    Object? spo2 = sin,
    Object? peso = sin,
    Object? talla = sin,
    Object? glucemia = sin,
    Object? perimetroAbdominal = sin,
  }) => SignosVitales(
    paSistolica: _numero(paSistolica, this.paSistolica),
    paDiastolica: _numero(paDiastolica, this.paDiastolica),
    fc: _numero(fc, this.fc),
    fr: _numero(fr, this.fr),
    temperatura: _numero(temperatura, this.temperatura),
    spo2: _numero(spo2, this.spo2),
    peso: _numero(peso, this.peso),
    talla: _numero(talla, this.talla),
    glucemia: _numero(glucemia, this.glucemia),
    perimetroAbdominal: _numero(perimetroAbdominal, this.perimetroAbdominal),
  );

  Map<String, Object?> aMapa() => compacto({
    'paSistolica': paSistolica,
    'paDiastolica': paDiastolica,
    'fc': fc,
    'fr': fr,
    'temperatura': temperatura,
    'spo2': spo2,
    'peso': peso,
    'talla': talla,
    'glucemia': glucemia,
    'perimetroAbdominal': perimetroAbdominal,
  });
}
