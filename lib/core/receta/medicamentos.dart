/// "Mis medicamentos": plantillas que el médico guarda desde la receta para
/// reutilizarlas. Empieza vacía; se puede exportar e importar en JSON (y en
/// el futuro, cargar un catálogo).
library;

import 'dart:convert';

import '../models/mapa.dart';
import 'alertas.dart';
import 'receta.dart';

class PlantillaMedicamento {
  const PlantillaMedicamento({
    required this.medicamento,
    this.concentracion = '',
    this.forma = '',
    this.dosis = '',
    this.via = '',
    this.frecuencia = '',
    this.duracion = '',
    this.unidad = '',
    this.nota = '',
  });

  factory PlantillaMedicamento.desdeItem(ItemReceta i) => PlantillaMedicamento(
    medicamento: i.medicamento.trim(),
    concentracion: i.concentracion.trim(),
    forma: i.forma.trim(),
    dosis: i.dosis.trim(),
    via: i.via.trim(),
    frecuencia: i.frecuencia.trim(),
    duracion: i.duracion.trim(),
    unidad: i.unidad.trim(),
    nota: i.nota.trim(),
  );

  factory PlantillaMedicamento.desdeMapa(Map<String, Object?> m) {
    String t(String clave) {
      final v = m[clave];
      if (v == null) return '';
      if (v is String) return v.trim();
      throw FormatException('"$clave" debe ser un texto');
    }

    final medicamento = t('medicamento');
    if (medicamento.isEmpty) {
      throw const FormatException('Hay un medicamento sin nombre');
    }
    return PlantillaMedicamento(
      medicamento: medicamento,
      concentracion: t('concentracion'),
      forma: t('forma'),
      dosis: t('dosis'),
      via: t('via'),
      frecuencia: t('frecuencia'),
      duracion: t('duracion'),
      unidad: t('unidad'),
      nota: t('nota'),
    );
  }

  final String medicamento;
  final String concentracion;
  final String forma;
  final String dosis;
  final String via;
  final String frecuencia;
  final String duracion;
  final String unidad;
  final String nota;

  /// Dos plantillas con el mismo medicamento, concentración y forma son la
  /// misma (la nueva reemplaza a la anterior).
  String get clave => normalizarFarmaco('$medicamento|$concentracion|$forma');

  /// "Amoxicilina 500 mg · cápsula"
  String get etiqueta {
    final nombre = [
      medicamento,
      concentracion,
    ].where((t) => t.isNotEmpty).join(' ');
    return [nombre, forma].where((t) => t.isNotEmpty).join(' · ');
  }

  /// "1 cápsula · oral · cada 8 horas · 7 días"
  String get detalle =>
      [dosis, via, frecuencia, duracion].where((t) => t.isNotEmpty).join(' · ');

  /// Rellena [item] con esta plantilla (conserva su id y su cantidad).
  ItemReceta aplicarA(ItemReceta item) => item.copyWith(
    medicamento: medicamento,
    concentracion: concentracion,
    forma: forma,
    dosis: dosis,
    via: via,
    frecuencia: frecuencia,
    duracion: duracion,
    unidad: unidad,
    nota: nota,
  );

  Map<String, Object?> aMapa() => compacto({
    'medicamento': medicamento,
    'concentracion': concentracion,
    'forma': forma,
    'dosis': dosis,
    'via': via,
    'frecuencia': frecuencia,
    'duracion': duracion,
    'unidad': unidad,
    'nota': nota,
  });
}

/// Agrega o reemplaza [nueva] (por su [PlantillaMedicamento.clave]) y deja
/// la lista ordenada alfabéticamente.
List<PlantillaMedicamento> conPlantilla(
  List<PlantillaMedicamento> lista,
  PlantillaMedicamento nueva,
) {
  final resultado = [
    for (final p in lista)
      if (p.clave != nueva.clave) p,
    nueva,
  ];
  resultado.sort(
    (a, b) =>
        normalizarFarmaco(a.etiqueta).compareTo(normalizarFarmaco(b.etiqueta)),
  );
  return resultado;
}

/// Plantillas que coinciden con lo escrito (por el comienzo de cualquier
/// palabra, sin tildes).
List<PlantillaMedicamento> buscarPlantillas(
  List<PlantillaMedicamento> lista,
  String consulta, {
  int maximo = 8,
}) {
  final q = normalizarFarmaco(consulta);
  if (q.isEmpty) return lista.take(maximo).toList();
  return lista
      .where((p) => ' ${normalizarFarmaco(p.etiqueta)}'.contains(' $q'))
      .take(maximo)
      .toList();
}

const _identificador = 'historiasclinicas.net';

/// JSON legible para respaldar o compartir la lista.
String exportarMedicamentos(
  List<PlantillaMedicamento> lista, {
  DateTime? ahora,
}) => const JsonEncoder.withIndent('  ').convert({
  'app': _identificador,
  'tipo': 'medicamentos',
  'version': 1,
  'exportado': fechaHoraIso(ahora ?? DateTime.now()),
  'medicamentos': [for (final p in lista) p.aMapa()],
});

class ResultadoImportacion {
  const ResultadoImportacion({
    required this.lista,
    required this.nuevos,
    required this.actualizados,
  });

  final List<PlantillaMedicamento> lista;
  final int nuevos;
  final int actualizados;

  String get resumen {
    String n(int c, String s, String p) => '$c ${c == 1 ? s : p}';
    return '${n(nuevos, 'medicamento nuevo', 'medicamentos nuevos')} y '
        '${n(actualizados, 'actualizado', 'actualizados')}';
  }
}

/// Une a [actuales] los medicamentos de [texto]: un JSON exportado por la
/// app o una lista simple de objetos. Lanza [FormatException] con un
/// mensaje claro si el archivo no sirve.
ResultadoImportacion importarMedicamentos(
  String texto,
  List<PlantillaMedicamento> actuales,
) {
  final Object? json;
  try {
    json = jsonDecode(texto);
  } on FormatException {
    throw const FormatException('El archivo no es un JSON válido');
  }
  final List<Object?> lista = switch (json) {
    {'tipo': final tipo} when tipo != 'medicamentos' => throw FormatException(
      'El archivo contiene "$tipo", no medicamentos',
    ),
    {'medicamentos': final List<Object?> l} => l,
    final List<Object?> l => l,
    _ => throw const FormatException(
      'No se encontró una lista de medicamentos',
    ),
  };
  var resultado = actuales;
  var nuevos = 0, actualizados = 0;
  for (final e in lista) {
    if (e is! Map) {
      throw const FormatException('Formato de medicamento no válido');
    }
    final p = PlantillaMedicamento.desdeMapa(e.cast<String, Object?>());
    if (resultado.any((x) => x.clave == p.clave)) {
      actualizados++;
    } else {
      nuevos++;
    }
    resultado = conPlantilla(resultado, p);
  }
  return ResultadoImportacion(
    lista: resultado,
    nuevos: nuevos,
    actualizados: actualizados,
  );
}
