import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../ihce/reloj.dart';
import '../../models/mapa.dart';
import '../../utils/texto.dart';
import '../repositorio/bitacora.dart';
import '../repositorio/repositorio.dart';

/// Un texto sin sus notas «VERIFICAR» y las notas que se le quitaron.
typedef TextoVerificar = ({String limpio, List<String> notas});

String _ordenar(String s) => s
    .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
    .replaceAll(RegExp(r' ([.,;:)])'), r'$1')
    .replaceAll('( ', '(')
    .replaceAll(RegExp(r'\.{2,}'), '.')
    .trim();

/// Separa las notas «VERIFICAR» de [texto] (pregunta 50): un paréntesis
/// que la lleva pierde esa parte («(Ley 51 de 1983, VERIFICAR)» →
/// «(Ley 51 de 1983)»; «(VERIFICAR)» desaparece) y una oración que la lleva
/// fuera de un paréntesis se quita entera. Puras.
TextoVerificar separarVerificar(String texto) {
  if (!texto.contains('VERIFICAR')) return (limpio: texto, notas: const []);
  final notas = <String>[];
  var s = texto.replaceAllMapped(
    RegExp(r'([ \t]*)\(([^()]*VERIFICAR[^()]*)\)'),
    (m) {
      final dentro = m.group(2)!;
      notas.add(_ordenar(dentro));
      final quedan = [
        for (final p in dentro.split(RegExp(r'\s*[,;]\s*')))
          if (!p.contains('VERIFICAR') && p.trim().isNotEmpty) p.trim(),
      ];
      return quedan.isEmpty ? '' : '${m.group(1)}(${quedan.join(', ')})';
    },
  );
  if (s.contains('VERIFICAR')) {
    final oraciones = s.split(RegExp(r'(?<=[.!?])\s+'));
    s = [
      for (final o in oraciones)
        if (o.contains('VERIFICAR')) ...[] else o,
    ].join(' ');
    notas.addAll([
      for (final o in oraciones)
        if (o.contains('VERIFICAR')) _ordenar(o),
    ]);
  }
  return (limpio: _ordenar(s), notas: notas);
}

/// Clave estable de una nota: la huella del texto completo, sin mayúsculas,
/// tildes ni espacios de más. Si el texto cambia, hay que verificarlo de
/// nuevo.
String claveVerificacion(String texto) {
  final n = sinTildes(texto).toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return sha256.convert(utf8.encode(n.trim())).toString().substring(0, 32);
}

/// Una nota marcada como verificada, con la fecha y la fuente.
class Verificacion {
  const Verificacion({
    required this.id,
    required this.texto,
    required this.fecha,
    required this.fuente,
  });

  static const coleccion = 'verificaciones';

  final String id;

  /// El texto completo, con la marca «VERIFICAR».
  final String texto;
  final DateTime fecha;
  final String fuente;

  Map<String, Object?> aMapa() => {
    'texto': texto,
    'fecha': fechaIso(fecha),
    'fuente': fuente.trim(),
  };

  static Verificacion desdeMapa(String id, Map<String, Object?> m) =>
      Verificacion(
        id: id,
        texto: m.texto('texto'),
        fecha: m.fecha('fecha')!,
        fuente: m.texto('fuente'),
      );
}

/// El registro de verificaciones (pregunta 50b), cifrado como lo demás.
class VerificacionesConsultorio {
  VerificacionesConsultorio(this._repo, {this.reloj = const RelojSistema()});

  final RepositorioConsultorio _repo;
  final Reloj reloj;
  final _todas = <String, Verificacion>{};

  Future<void> cargar() async {
    final r = await _repo.leerColeccionTolerante(Verificacion.coleccion);
    olvidar();
    for (final e in r.registros.entries) {
      try {
        _todas[e.key] = Verificacion.desdeMapa(e.key, e.value);
      } on Object {
        // Ilegible: se ignora (el respaldo conserva el original).
      }
    }
  }

  void olvidar() => _todas.clear();

  /// La verificación de [texto], si la hay.
  Verificacion? de(String texto) => _todas[claveVerificacion(texto)];

  /// Todas, de la más reciente a la más vieja.
  List<Verificacion> get todas =>
      _todas.values.toList()..sort((a, b) => b.fecha.compareTo(a.fecha));

  Future<Verificacion> marcar(
    String texto, {
    required DateTime fecha,
    required String fuente,
  }) async {
    if (!texto.contains('VERIFICAR')) {
      throw StateError('El texto no tiene una nota por verificar.');
    }
    if (fuente.trim().isEmpty) {
      throw StateError('Escribe la fuente (norma, concepto, ficha técnica).');
    }
    final hoy = reloj.ahora();
    if (DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
    ).isAfter(DateTime(hoy.year, hoy.month, hoy.day))) {
      throw StateError('La fecha no puede ser futura.');
    }
    final v = Verificacion(
      id: claveVerificacion(texto),
      texto: texto,
      fecha: DateTime(fecha.year, fecha.month, fecha.day),
      fuente: fuente.trim(),
    );
    await _repo.guardar(Verificacion.coleccion, v.id, v.aMapa());
    _todas[v.id] = v;
    await registrarEnBitacora(
      _repo,
      AccionBitacora.verificarNota,
      fecha: hoy,
      resumen: v.fuente,
    );
    return v;
  }

  Future<void> quitar(String texto) async {
    final id = claveVerificacion(texto);
    if (_todas.remove(id) == null) return;
    await _repo.guardarVarios([Escritura(Verificacion.coleccion, id, null)]);
    await registrarEnBitacora(
      _repo,
      AccionBitacora.quitarVerificacion,
      fecha: reloj.ahora(),
    );
  }
}
