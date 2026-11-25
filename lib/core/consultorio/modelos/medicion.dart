import '../../clinica/imc.dart';
import '../../clinica/rangos.dart';
import '../../models/mapa.dart';
import '../../utils/numeros.dart';

/// Método con que se midió el porcentaje de grasa.
enum MetodoGrasa {
  bioimpedancia('Bioimpedancia'),
  pliegues('Pliegues cutáneos'),
  otro('Otro');

  const MetodoGrasa(this.etiqueta);

  final String etiqueta;
}

/// De dónde sale una medición del seguimiento.
enum OrigenMedicion {
  /// Registrada en la ficha («+ Medición»).
  manual,

  /// Signos sellados en una historia o en una evolución (solo lectura).
  historia,
}

/// Rangos plausibles de los perímetros (cm): avisan, no bloquean.
const rangoPerimetro = RangoSigno(minPlausible: 10, maxPlausible: 250);
const rangoGrasa = RangoSigno(minPlausible: 2, maxPlausible: 75);

/// Una medición antropométrica. El IMC y el índice cintura-cadera se
/// calculan, no se guardan.
class Medicion {
  const Medicion({
    required this.id,
    required this.pacienteId,
    required this.fecha,
    required this.creado,
    this.origen = OrigenMedicion.manual,
    this.fuente = '',
    this.peso,
    this.talla,
    this.cintura,
    this.cadera,
    this.abdomen,
    this.flancoDerecho,
    this.flancoIzquierdo,
    this.musloDerecho,
    this.musloIzquierdo,
    this.brazoDerecho,
    this.brazoIzquierdo,
    this.paSistolica,
    this.paDiastolica,
    this.grasa,
    this.metodoGrasa,
    this.notas = '',
  });

  static const coleccion = 'mediciones';

  final String id;
  final String pacienteId;
  final DateTime fecha;
  final DateTime creado;
  final OrigenMedicion origen;

  /// Para las que vienen de una historia: «Historia del 02/10/2026»,
  /// «Evolución 2».
  final String fuente;
  final double? peso;
  final double? talla;
  final double? cintura;
  final double? cadera;
  final double? abdomen;
  final double? flancoDerecho;
  final double? flancoIzquierdo;
  final double? musloDerecho;
  final double? musloIzquierdo;
  final double? brazoDerecho;
  final double? brazoIzquierdo;
  final double? paSistolica;
  final double? paDiastolica;

  /// Porcentaje de grasa; exige [metodoGrasa].
  final double? grasa;
  final MetodoGrasa? metodoGrasa;
  final String notas;

  bool get editable => origen == OrigenMedicion.manual;

  double? get imc => calcularImc(pesoKg: peso, tallaCm: talla);

  /// Índice cintura-cadera, o `null` si falta alguno.
  double? get icc {
    final c = cintura;
    final h = cadera;
    if (c == null || h == null || h <= 0) return null;
    return c / h;
  }

  bool get vacia => aMapa().keys.every(
    (k) => const {
      'pacienteId',
      'fecha',
      'creado',
      'origen',
      'fuente',
      'notas',
    }.contains(k),
  );

  /// «Mediciones del día: Peso 88 kg · Talla 176 cm · IMC 28,4 · …», para
  /// copiarla a la evolución en curso (pregunta 17).
  String get texto {
    String n(double v, [int? decimales]) =>
        formatoNumero(v, decimales: decimales);
    String par(String nombre, double? d, double? i) {
      if (d == null && i == null) return '';
      return '$nombre D/I ${d == null ? '—' : n(d)}/'
          '${i == null ? '—' : n(i)} cm';
    }

    final partes = [
      if (peso != null) 'Peso ${n(peso!)} kg',
      if (talla != null) 'Talla ${n(talla!)} cm',
      if (imc != null) 'IMC ${n(imc!, 1)}',
      if (cintura != null) 'Cintura ${n(cintura!)} cm',
      if (cadera != null) 'Cadera ${n(cadera!)} cm',
      if (icc != null) 'ICC ${n(icc!, 2)}',
      if (abdomen != null) 'Abdomen ${n(abdomen!)} cm',
      par('Flanco', flancoDerecho, flancoIzquierdo),
      par('Muslo', musloDerecho, musloIzquierdo),
      par('Brazo', brazoDerecho, brazoIzquierdo),
      if (paSistolica != null && paDiastolica != null)
        'PA ${n(paSistolica!)}/${n(paDiastolica!)} mmHg',
      if (grasa != null)
        'Grasa ${n(grasa!)} %'
            '${metodoGrasa == null ? '' : ' (${metodoGrasa!.etiqueta.toLowerCase()})'}',
    ].where((p) => p.isNotEmpty);
    return 'Mediciones del día: ${partes.join(' · ')}.';
  }

  Medicion copyWith({String? pacienteId}) =>
      Medicion.desdeMapa(id, {...aMapa(), 'pacienteId': ?pacienteId});

  Map<String, Object?> aMapa() => compacto({
    'pacienteId': pacienteId,
    'fecha': fechaHoraIso(fecha),
    'creado': creado.toUtc().toIso8601String(),
    'origen': origen == OrigenMedicion.manual ? null : origen.name,
    'fuente': fuente,
    'peso': peso,
    'talla': talla,
    'cintura': cintura,
    'cadera': cadera,
    'abdomen': abdomen,
    'flancoDerecho': flancoDerecho,
    'flancoIzquierdo': flancoIzquierdo,
    'musloDerecho': musloDerecho,
    'musloIzquierdo': musloIzquierdo,
    'brazoDerecho': brazoDerecho,
    'brazoIzquierdo': brazoIzquierdo,
    'paSistolica': paSistolica,
    'paDiastolica': paDiastolica,
    'grasa': grasa,
    'metodoGrasa': metodoGrasa?.name,
    'notas': notas,
  });

  static Medicion desdeMapa(String id, Map<String, Object?> m) {
    double? d(String k) => (m[k] as num?)?.toDouble();
    final metodo = m.textoONulo('metodoGrasa');
    final origen = m.textoONulo('origen');
    return Medicion(
      id: id,
      pacienteId: m.texto('pacienteId'),
      fecha: m.fecha('fecha')!,
      creado: DateTime.parse(m['creado']! as String).toLocal(),
      origen: origen == null
          ? OrigenMedicion.manual
          : OrigenMedicion.values.byName(origen),
      fuente: m.texto('fuente'),
      peso: d('peso'),
      talla: d('talla'),
      cintura: d('cintura'),
      cadera: d('cadera'),
      abdomen: d('abdomen'),
      flancoDerecho: d('flancoDerecho'),
      flancoIzquierdo: d('flancoIzquierdo'),
      musloDerecho: d('musloDerecho'),
      musloIzquierdo: d('musloIzquierdo'),
      brazoDerecho: d('brazoDerecho'),
      brazoIzquierdo: d('brazoIzquierdo'),
      paSistolica: d('paSistolica'),
      paDiastolica: d('paDiastolica'),
      grasa: d('grasa'),
      metodoGrasa: metodo == null ? null : MetodoGrasa.values.byName(metodo),
      notas: m.texto('notas'),
    );
  }
}

/// Cambio entre la primera y la última medición con [valor]: (primera,
/// última, % de cambio). `null` si hay menos de dos.
({double primera, double ultima, double porcentaje})? cambioEn(
  List<Medicion> mediciones,
  double? Function(Medicion m) valor,
) {
  final con = [
    for (final m in mediciones)
      if (valor(m) case final v?) (m.fecha, v),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  if (con.length < 2) return null;
  final p = con.first.$2;
  final u = con.last.$2;
  return (primera: p, ultima: u, porcentaje: p == 0 ? 0 : (u - p) / p * 100);
}
