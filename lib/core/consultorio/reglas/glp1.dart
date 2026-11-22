import '../peso/catalogo_glp1.dart';
import '../peso/programa_peso.dart';

/// Ítems de la lista que aplican según el sexo de la ficha. Sin sexo
/// registrado se incluyen todos (lo más prudente).
List<ItemContraindicacion> contraindicacionesAplicables(String? sexo) => [
  for (final i in contraindicacionesGlp1)
    if (!i.soloMujeres || sexo != 'M') i,
];

/// Lo que dice la revisión de contraindicaciones (pregunta 25).
class EvaluacionContraindicaciones {
  const EvaluacionContraindicaciones({
    required this.bloqueos,
    required this.faltanNotas,
    required this.precauciones,
    required this.absolutas,
  });

  /// Impiden iniciar el GLP-1: una absoluta en «sí», una absoluta sin
  /// aclarar («no sabe» o sin responder), un ítem sin responder o una
  /// lista de otra versión.
  final List<String> bloqueos;

  /// Precauciones en «sí» o «no sabe» que todavía no tienen nota.
  final List<String> faltanNotas;

  /// Precauciones en «sí» o «no sabe» (con su nota).
  final List<ItemContraindicacion> precauciones;

  /// Absolutas en «sí».
  final List<ItemContraindicacion> absolutas;

  bool get permiteIniciar => bloqueos.isEmpty && faltanNotas.isEmpty;

  List<String> get motivos => [...bloqueos, ...faltanNotas];
}

EvaluacionContraindicaciones evaluarContraindicaciones(
  RevisionContraindicaciones? revision, {
  String? sexo,
}) {
  if (revision == null) {
    return const EvaluacionContraindicaciones(
      bloqueos: ['Falta revisar la lista de contraindicaciones.'],
      faltanNotas: [],
      precauciones: [],
      absolutas: [],
    );
  }
  final bloqueos = <String>[];
  final faltanNotas = <String>[];
  final precauciones = <ItemContraindicacion>[];
  final absolutas = <ItemContraindicacion>[];
  if (revision.version != versionContraindicacionesGlp1) {
    bloqueos.add('La lista de contraindicaciones cambió: revísala de nuevo.');
  }
  for (final item in contraindicacionesAplicables(sexo)) {
    final r = revision.respuestas[item.id];
    if (r == null) {
      bloqueos.add('Falta responder «${item.texto}».');
      continue;
    }
    if (item.absoluta) {
      switch (r.respuesta) {
        case RespuestaContra.si:
          absolutas.add(item);
          bloqueos.add('Contraindicación absoluta: ${item.texto}.');
        case RespuestaContra.desconoce:
          bloqueos.add('Aclara «${item.texto}» antes de iniciar.');
        case RespuestaContra.no:
          break;
      }
    } else if (r.respuesta != RespuestaContra.no) {
      precauciones.add(item);
      if (r.nota.trim().isEmpty) {
        faltanNotas.add('Escribe una nota para «${item.texto}».');
      }
    }
  }
  return EvaluacionContraindicaciones(
    bloqueos: bloqueos,
    faltanNotas: faltanNotas,
    precauciones: precauciones,
    absolutas: absolutas,
  );
}
