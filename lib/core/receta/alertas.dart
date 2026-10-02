/// Alertas de la receta: alergias del paciente y medicamentos de control
/// especial. Solo avisan: nunca bloquean la receta.
///
/// Las tablas son una ayuda y no sustituyen el juicio clínico ni la norma
/// de cada país (VERIFICAR).
library;

import '../utils/texto.dart';
import 'receta.dart';

/// Minúsculas, sin tildes, solo letras y números separados por un espacio,
/// y sin la "s" final de los plurales: "Penicilinas" → "penicilina".
String normalizarFarmaco(String texto) {
  final palabras = sinTildes(texto.toLowerCase())
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .trim()
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => p.length > 4 && p.endsWith('s') ? _singular(p) : p);
  return palabras.join(' ');
}

String _singular(String p) {
  // "antiinflamatorios" → "antiinflamatorio"; "aines" → "aine".
  return p.substring(0, p.length - 1);
}

/// `true` si [termino] aparece en [texto] como palabras completas. Un
/// término que termina en `*` es un prefijo de palabra ("cef*").
bool _contiene(String texto, String termino) {
  if (termino.isEmpty || texto.isEmpty) return false;
  if (termino.endsWith('*')) {
    final prefijo = termino.substring(0, termino.length - 1);
    return ' $texto'.contains(' $prefijo');
  }
  return ' $texto '.contains(' $termino ');
}

/// Grupo de medicamentos que comparten alergia (o el mismo principio
/// activo con otro nombre, si [sinonimos]).
class GrupoFarmacos {
  const GrupoFarmacos({
    required this.nombre,
    required this.miembros,
    this.alias = const [],
    this.cruzada = const [],
    this.sinonimos = false,
  });

  /// "las penicilinas".
  final String nombre;

  /// Principios activos (normalizados). `*` al final indica prefijo.
  final List<String> miembros;

  /// Cómo puede anotarse la alergia al grupo: "betalactamico", "aine"…
  final List<String> alias;

  /// Nombres de otros grupos con posible reactividad cruzada.
  final List<String> cruzada;

  /// El mismo principio activo con distintos nombres.
  final bool sinonimos;

  bool incluye(String texto) => miembros.any((m) => _contiene(texto, m));

  bool nombradoEn(String alergia) =>
      incluye(alergia) || alias.any((a) => _contiene(alergia, a));
}

/// VERIFICAR: tabla orientativa, no exhaustiva.
const gruposFarmacos = <GrupoFarmacos>[
  // Mismo principio activo con otro nombre.
  GrupoFarmacos(
    nombre: 'paracetamol (acetaminofén)',
    sinonimos: true,
    miembros: ['paracetamol', 'acetaminofen', 'acetaminofeno'],
  ),
  GrupoFarmacos(
    nombre: 'metamizol (dipirona)',
    sinonimos: true,
    miembros: ['metamizol', 'dipirona'],
  ),
  GrupoFarmacos(
    nombre: 'ácido acetilsalicílico (aspirina)',
    sinonimos: true,
    miembros: ['acido acetilsalicilico', 'acetilsalicilico', 'aspirina', 'aas'],
  ),
  GrupoFarmacos(
    nombre: 'meperidina (petidina)',
    sinonimos: true,
    miembros: ['meperidina', 'petidina'],
  ),
  GrupoFarmacos(
    nombre: 'salbutamol (albuterol)',
    sinonimos: true,
    miembros: ['salbutamol', 'albuterol'],
  ),
  GrupoFarmacos(
    nombre: 'adrenalina (epinefrina)',
    sinonimos: true,
    miembros: ['adrenalina', 'epinefrina'],
  ),
  GrupoFarmacos(
    nombre: 'trimetoprim-sulfametoxazol (cotrimoxazol)',
    sinonimos: true,
    miembros: ['cotrimoxazol', 'trimetoprim sulfametoxazol'],
  ),
  // Grupos con alergia compartida.
  GrupoFarmacos(
    nombre: 'las penicilinas',
    alias: ['betalactamico', 'beta lactamico'],
    cruzada: ['las cefalosporinas', 'los carbapenémicos'],
    miembros: [
      'penicilina',
      'amoxicilina',
      'ampicilina',
      'bencilpenicilina',
      'fenoximetilpenicilina',
      'dicloxacilina',
      'cloxacilina',
      'flucloxacilina',
      'oxacilina',
      'nafcilina',
      'piperacilina',
      'ticarcilina',
      'sultamicilina',
      'temocilina',
    ],
  ),
  GrupoFarmacos(
    nombre: 'las cefalosporinas',
    alias: ['cefalosporina', 'betalactamico', 'beta lactamico'],
    cruzada: ['las penicilinas', 'los carbapenémicos'],
    miembros: ['cef*'],
  ),
  GrupoFarmacos(
    nombre: 'los carbapenémicos',
    alias: ['carbapenem', 'carbapenemico', 'betalactamico', 'beta lactamico'],
    cruzada: ['las penicilinas', 'las cefalosporinas'],
    miembros: ['imipenem', 'meropenem', 'ertapenem', 'doripenem'],
  ),
  GrupoFarmacos(
    nombre: 'las sulfonamidas',
    alias: ['sulfa', 'sulfonamida', 'sulfamida'],
    miembros: [
      'sulfametoxazol',
      'cotrimoxazol',
      'sulfadiazina',
      'sulfasalazina',
      'sulfacetamida',
    ],
  ),
  GrupoFarmacos(
    nombre: 'los macrólidos',
    alias: ['macrolido'],
    miembros: [
      'eritromicina',
      'azitromicina',
      'claritromicina',
      'roxitromicina',
      'espiramicina',
    ],
  ),
  GrupoFarmacos(
    nombre: 'las quinolonas',
    alias: ['quinolona', 'fluoroquinolona'],
    miembros: [
      'ciprofloxacino',
      'ciprofloxacina',
      'levofloxacino',
      'levofloxacina',
      'moxifloxacino',
      'moxifloxacina',
      'norfloxacino',
      'norfloxacina',
      'ofloxacino',
      'ofloxacina',
    ],
  ),
  GrupoFarmacos(
    nombre: 'las tetraciclinas',
    alias: ['tetraciclina'],
    miembros: ['tetraciclina', 'doxiciclina', 'minociclina', 'tigeciclina'],
  ),
  GrupoFarmacos(
    nombre: 'los aminoglucósidos',
    alias: ['aminoglucosido'],
    miembros: [
      'gentamicina',
      'amikacina',
      'tobramicina',
      'estreptomicina',
      'neomicina',
    ],
  ),
  GrupoFarmacos(
    nombre: 'los AINE',
    alias: ['aine', 'antiinflamatorio', 'antiinflamatorio no esteroideo'],
    cruzada: ['las pirazolonas'],
    miembros: [
      'ibuprofeno',
      'dexibuprofeno',
      'naproxeno',
      'diclofenaco',
      'aceclofenaco',
      'ketorolaco',
      'ketoprofeno',
      'dexketoprofeno',
      'flurbiprofeno',
      'meloxicam',
      'piroxicam',
      'tenoxicam',
      'lornoxicam',
      'indometacina',
      'nimesulida',
      'nabumetona',
      'sulindaco',
      'acido mefenamico',
      'celecoxib',
      'etoricoxib',
      'acido acetilsalicilico',
      'acetilsalicilico',
      'aspirina',
    ],
  ),
  GrupoFarmacos(
    nombre: 'las pirazolonas',
    alias: ['pirazolona'],
    cruzada: ['los AINE'],
    miembros: ['metamizol', 'dipirona', 'propifenazona'],
  ),
  GrupoFarmacos(
    nombre: 'los opioides',
    alias: ['opioide', 'opiaceo'],
    miembros: [
      'morfina',
      'codeina',
      'tramadol',
      'oxicodona',
      'hidromorfona',
      'hidrocodona',
      'fentanilo',
      'meperidina',
      'petidina',
      'metadona',
      'tapentadol',
      'buprenorfina',
      'nalbufina',
    ],
  ),
  GrupoFarmacos(
    nombre: 'los anestésicos locales tipo amida',
    alias: ['anestesico local'],
    miembros: [
      'lidocaina',
      'bupivacaina',
      'levobupivacaina',
      'mepivacaina',
      'ropivacaina',
      'prilocaina',
      'articaina',
    ],
  ),
];

enum GravedadAlerta {
  /// Coincidencia directa, mismo principio activo o mismo grupo.
  alta,

  /// Posible reactividad cruzada entre grupos.
  media,
}

class AlertaAlergia {
  const AlertaAlergia({
    required this.clave,
    required this.alergia,
    required this.numeroItem,
    required this.medicamento,
    required this.motivo,
    required this.gravedad,
  });

  /// Identifica la alerta para marcarla como leída.
  final String clave;
  final String alergia;
  final int numeroItem;
  final String medicamento;

  /// "pertenece al grupo de las penicilinas".
  final String motivo;
  final GravedadAlerta gravedad;

  String get texto =>
      'El paciente refiere alergia a «$alergia». «$medicamento» '
      '(ítem $numeroItem) $motivo.';
}

/// Separa el texto de alergias de la receta ("Penicilina, AINEs") en
/// alergias individuales. "Niega alergias…" no cuenta.
List<String> alergiasDeTexto(String texto) {
  if (normalizarFarmaco(texto).startsWith('niega')) return const [];
  return texto
      .split(RegExp(r'[,;\n]| y '))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

/// Cruza las [alergias] del paciente con los medicamentos de [items].
List<AlertaAlergia> alertasDeAlergia({
  required List<String> alergias,
  required List<ItemReceta> items,
}) {
  final alertas = <AlertaAlergia>[];
  for (final (i, item) in items.indexed) {
    final med = normalizarFarmaco(item.medicamento);
    if (med.length < 3) continue;
    for (final alergia in alergias) {
      final al = normalizarFarmaco(alergia);
      if (al.length < 3) continue;
      final alerta = _comparar(al, med);
      if (alerta == null) continue;
      alertas.add(
        AlertaAlergia(
          clave: '${item.id}|$al|$med',
          alergia: alergia.trim(),
          numeroItem: i + 1,
          medicamento: item.medicamento.trim(),
          motivo: alerta.$1,
          gravedad: alerta.$2,
        ),
      );
    }
  }
  return alertas;
}

(String, GravedadAlerta)? _comparar(String alergia, String med) {
  if (_contiene(med, alergia) || _contiene(alergia, med)) {
    return ('coincide con esa alergia', GravedadAlerta.alta);
  }
  for (final g in gruposFarmacos.where((g) => g.sinonimos)) {
    if (g.incluye(alergia) && g.incluye(med)) {
      return ('es el mismo principio activo: ${g.nombre}', GravedadAlerta.alta);
    }
  }
  final deLaAlergia = gruposFarmacos.where(
    (g) => !g.sinonimos && g.nombradoEn(alergia),
  );
  final delMedicamento = gruposFarmacos.where(
    (g) => !g.sinonimos && g.incluye(med),
  );
  for (final g in delMedicamento) {
    if (deLaAlergia.contains(g)) {
      return ('pertenece al grupo de ${g.nombre}', GravedadAlerta.alta);
    }
  }
  for (final g in delMedicamento) {
    for (final a in deLaAlergia) {
      if (a.cruzada.contains(g.nombre)) {
        return (
          'pertenece al grupo de ${g.nombre}: posible reactividad cruzada '
              'con ${a.nombre}',
          GravedadAlerta.media,
        );
      }
    }
  }
  return null;
}

// ─────────────────────────── Control especial ───────────────────────────

/// Principios activos que suelen exigir recetario o receta oficial
/// (estupefacientes y algunos psicotrópicos). VERIFICAR la lista oficial de
/// cada país: en Colombia, el Fondo Nacional de Estupefacientes; en España,
/// la receta oficial de estupefacientes.
const controlEspecial = [
  'morfina',
  'hidromorfona',
  'oxicodona',
  'fentanilo',
  'remifentanilo',
  'metadona',
  'meperidina',
  'petidina',
  'tapentadol',
  'buprenorfina',
  'ketamina',
  'metilfenidato',
  'lisdexanfetamina',
  'dexanfetamina',
  'fenobarbital',
  'alprazolam',
  'clonazepam',
  'diazepam',
  'lorazepam',
  'lormetazepam',
  'midazolam',
  'bromazepam',
  'clobazam',
  'triazolam',
  'flunitrazepam',
  'zolpidem',
];

class AvisoControlEspecial {
  const AvisoControlEspecial({
    required this.numeroItem,
    required this.medicamento,
  });

  final int numeroItem;
  final String medicamento;

  String get texto =>
      '«$medicamento» (ítem $numeroItem) podría requerir recetario o receta '
      'oficial de control especial (VERIFICAR la norma de tu país). Esta hoja '
      'podría no servir para dispensarlo.';
}

List<AvisoControlEspecial> avisosControlEspecial(List<ItemReceta> items) => [
  for (final (i, item) in items.indexed)
    if (controlEspecial.any(
      (c) => _contiene(normalizarFarmaco(item.medicamento), c),
    ))
      AvisoControlEspecial(
        numeroItem: i + 1,
        medicamento: item.medicamento.trim(),
      ),
];
