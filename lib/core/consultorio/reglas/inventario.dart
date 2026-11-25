import '../../utils/fechas.dart';
import '../../utils/numeros.dart';
import '../../utils/texto.dart';
import '../inventario/insumo.dart';
import '../procedimientos/sesion.dart';

/// Días antes del vencimiento en que avisa (pregunta 49).
const diasAvisoVencimiento = 30;

enum EstadoLote {
  vigente('Vigente'),
  porVencer('Vence pronto'),
  vencido('Vencido'),
  agotado('Agotado');

  const EstadoLote(this.etiqueta);

  final String etiqueta;
}

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Existencia de cada lote: la suma de sus movimientos.
Map<String, double> existencias(Iterable<Movimiento> movimientos) {
  final e = <String, double>{};
  for (final m in movimientos) {
    e[m.loteId] = (e[m.loteId] ?? 0) + m.cantidad;
  }
  return e;
}

/// Días que le quedan al lote (negativo si ya venció).
int diasParaVencer(Lote l, DateTime hoy) =>
    _dia(l.vence).difference(_dia(hoy)).inDays;

EstadoLote estadoLote(Lote l, double existencia, DateTime hoy) {
  if (l.vencidoEn(hoy)) return EstadoLote.vencido;
  if (existencia <= 0) return EstadoLote.agotado;
  if (diasParaVencer(l, hoy) <= diasAvisoVencimiento) {
    return EstadoLote.porVencer;
  }
  return EstadoLote.vigente;
}

/// El que vence primero, primero (pregunta 49).
List<Lote> ordenFefo(Iterable<Lote> lotes) => lotes.toList()
  ..sort((a, b) {
    final v = a.vence.compareTo(b.vence);
    return v != 0 ? v : a.ingreso.compareTo(b.ingreso);
  });

/// Los lotes que se pueden usar hoy, el que vence primero primero.
List<Lote> lotesDisponibles(
  Iterable<Lote> lotes,
  Map<String, double> existencias,
  DateTime hoy,
) => [
  for (final l in ordenFefo(lotes))
    if (!l.vencidoEn(hoy) && (existencias[l.id] ?? 0) > 0) l,
];

/// Aviso si falta el registro Invima (más fuerte en los inyectables).
String? avisoInvima(Insumo i) {
  if (!i.sinRegistro) return null;
  return i.inyectable
      ? '«${i.nombre}» es inyectable y no tiene registro Invima: verifícalo '
            'antes de usarlo.'
      : '«${i.nombre}» no tiene registro Invima.';
}

/// «3 ampollas», «1 unidad», «2,5 frascos».
String cantidadTexto(double c, String unidad) {
  final n = formatoNumero(c, decimales: c % 1 == 0 ? 0 : 1);
  final u = unidad.trim().isEmpty ? 'unidad' : unidad.trim();
  if (c == 1 || u.endsWith('s')) return '$n $u';
  final vocal = RegExp(r'[aeiou]$').hasMatch(sinTildes(u));
  return '$n ${vocal ? '${u}s' : '${u}es'}';
}

/// Lo que dicen las reglas de una entrada, un ajuste o una baja.
class EvaluacionInventario {
  const EvaluacionInventario({required this.bloqueos, required this.avisos});

  final List<String> bloqueos;
  final List<String> avisos;

  bool get permite => bloqueos.isEmpty;
}

/// Evalúa una entrada (puras). [mismoNumero] es el lote del mismo insumo
/// con ese número, si ya existe.
EvaluacionInventario evaluarEntrada({
  required Insumo? insumo,
  required String numero,
  required DateTime? vence,
  required double? cantidad,
  required DateTime hoy,
  Lote? mismoNumero,
}) {
  final bloqueos = <String>[];
  final avisos = <String>[];
  if (insumo == null) bloqueos.add('Elige el insumo.');
  if (numero.trim().isEmpty) bloqueos.add('Escribe el número de lote.');
  if (vence == null) bloqueos.add('Escribe el vencimiento.');
  if (cantidad == null || cantidad <= 0) {
    bloqueos.add('La cantidad tiene que ser mayor que 0.');
  }
  if (vence != null && _dia(hoy).isAfter(vence)) {
    bloqueos.add(
      'El lote ${numero.trim()} venció el ${formatoFecha(vence)}: no se '
      'ingresa.',
    );
  } else if (vence != null) {
    final dias = _dia(vence).difference(_dia(hoy)).inDays;
    if (dias <= diasAvisoVencimiento) {
      avisos.add('Vence en $dias ${dias == 1 ? 'día' : 'días'}.');
    }
  }
  if (mismoNumero != null &&
      vence != null &&
      _dia(mismoNumero.vence) != _dia(vence)) {
    bloqueos.add(
      'El lote ${numero.trim()} ya está con otro vencimiento '
      '(${formatoFecha(mismoNumero.vence)}).',
    );
  }
  if (insumo != null) {
    final a = avisoInvima(insumo);
    if (a != null) avisos.add(a);
  }
  return EvaluacionInventario(bloqueos: bloqueos, avisos: avisos);
}

/// Evalúa un ajuste de [cantidad] (con signo) sobre un lote con
/// [existencia].
EvaluacionInventario evaluarAjuste({
  required double existencia,
  required double? cantidad,
  required String motivo,
}) => EvaluacionInventario(
  bloqueos: [
    if (cantidad == null || cantidad == 0)
      'Escribe cuánto sumar (o restar, con «-»).',
    if (cantidad != null && existencia + cantidad < 0)
      'No puede quedar menos de 0 (hay ${formatoNumero(existencia)}).',
    if (motivo.trim().isEmpty) 'Escribe el motivo.',
  ],
  avisos: const [],
);

/// Una línea de la sesión que puede salir del inventario.
typedef LineaInventario = ({String nombre, LoteSesion lote, double unidades});

/// Unidades del anestésico: las escritas o, si no, las que alcanzan para el
/// volumen (una ampolla abierta no se guarda).
double unidadesAnestesico(AnestesicoSesion a, Insumo? insumo) {
  if (a.lote.unidades != null) return a.lote.unidades!;
  final c = insumo?.contenidoMl;
  final v = a.volumenMl;
  if (c == null || c <= 0 || v == null || v <= 0) return 1;
  return (v / c).ceilToDouble();
}

/// Las líneas de [s] con su lote y las unidades a descontar.
List<LineaInventario> lineasInventario(
  Sesion s,
  Insumo? Function(String? loteId) insumoDeLote,
) => [
  if (s.anestesico case final a?)
    (
      nombre: a.nombre,
      lote: a.lote,
      unidades: unidadesAnestesico(a, insumoDeLote(a.lote.loteId)),
    ),
  for (final c in s.componentes)
    (nombre: c.nombre, lote: c.lote, unidades: c.lote.unidades ?? 1),
  for (final i in s.insumos)
    (nombre: i.nombre, lote: i.lote, unidades: i.cantidad),
];

/// Bloqueos y avisos del inventario en una sesión (puras): un lote del
/// inventario sin existencia suficiente bloquea; un insumo sin registro
/// Invima avisa; una línea escrita a mano que sí está en el inventario
/// avisa que no se descontará. (El lote vencido ya lo bloquea la sesión.)
EvaluacionInventario evaluarInventarioSesion({
  required List<LineaInventario> lineas,
  required Map<String, Lote> lotes,
  required Map<String, Insumo> insumos,
  required Map<String, double> existencias,
  required Insumo? Function(String nombre) insumoPorNombre,
}) {
  final bloqueos = <String>[];
  final avisos = <String>[];
  final usado = <String, double>{};
  for (final l in lineas) {
    final id = l.lote.loteId;
    if (id == null) {
      final i = insumoPorNombre(l.nombre);
      if (i != null && l.nombre.trim().isNotEmpty) {
        avisos.add(
          '«${l.nombre}» está en el inventario, pero su lote se escribió a '
          'mano: no se descontará.',
        );
      }
      continue;
    }
    final lote = lotes[id];
    final insumo = lote == null ? null : insumos[lote.insumoId];
    if (lote == null || insumo == null) {
      bloqueos.add(
        'El lote ${l.lote.lote.trim()} de «${l.nombre}» ya no está en el '
        'inventario: elige otro.',
      );
      continue;
    }
    if (l.unidades <= 0) {
      bloqueos.add('Escribe las unidades que se usan de «${l.nombre}».');
      continue;
    }
    usado[id] = (usado[id] ?? 0) + l.unidades;
    final a = avisoInvima(insumo);
    if (a != null && !avisos.contains(a)) avisos.add(a);
  }
  for (final e in usado.entries) {
    final lote = lotes[e.key]!;
    final insumo = insumos[lote.insumoId]!;
    final hay = existencias[e.key] ?? 0;
    if (e.value > hay) {
      bloqueos.add(
        hay <= 0
            ? 'El lote ${lote.numero} de «${insumo.nombre}» no tiene '
                  'existencias.'
            : 'El lote ${lote.numero} de «${insumo.nombre}» tiene '
                  '${cantidadTexto(hay, insumo.unidad)}; la sesión usa '
                  '${cantidadTexto(e.value, insumo.unidad)}.',
      );
    }
  }
  return EvaluacionInventario(bloqueos: bloqueos, avisos: avisos);
}

/// Alertas del inventario (pregunta 49).
class AlertasInventario {
  const AlertasInventario({
    required this.bajoMinimo,
    required this.porVencer,
    required this.vencidos,
    required this.sinRegistro,
  });

  /// Insumos activos con menos existencia vigente que su mínimo.
  final List<Insumo> bajoMinimo;

  /// Lotes con existencia que vencen en 30 días o menos.
  final List<Lote> porVencer;

  /// Lotes vencidos que todavía tienen existencia (para dar de baja).
  final List<Lote> vencidos;

  /// Insumos activos sin registro Invima.
  final List<Insumo> sinRegistro;

  int get total =>
      bajoMinimo.length +
      porVencer.length +
      vencidos.length +
      sinRegistro.length;
}

AlertasInventario alertasInventario({
  required Iterable<Insumo> insumos,
  required Iterable<Lote> lotes,
  required Map<String, double> existencias,
  required DateTime hoy,
}) {
  final activos = [
    for (final i in insumos)
      if (i.activo) i,
  ];
  double vigente(Insumo i) => lotes
      .where((l) => l.insumoId == i.id && !l.vencidoEn(hoy))
      .fold(0.0, (s, l) => s + (existencias[l.id] ?? 0));
  final conExistencia = ordenFefo([
    for (final l in lotes)
      if ((existencias[l.id] ?? 0) > 0 &&
          activos.any((i) => i.id == l.insumoId))
        l,
  ]);
  return AlertasInventario(
    bajoMinimo: [
      for (final i in activos)
        if (i.stockMinimo > 0 && vigente(i) < i.stockMinimo) i,
    ],
    porVencer: [
      for (final l in conExistencia)
        if (estadoLote(l, existencias[l.id]!, hoy) == EstadoLote.porVencer) l,
    ],
    vencidos: [
      for (final l in conExistencia)
        if (l.vencidoEn(hoy)) l,
    ],
    sinRegistro: [
      for (final i in activos)
        if (i.sinRegistro) i,
    ],
  );
}

/// Para comparar nombres sin mayúsculas, tildes ni espacios de más.
String claveNombre(String n) =>
    sinTildes(n).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
