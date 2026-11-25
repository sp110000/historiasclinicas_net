import '../../models/mapa.dart';

/// Certificación del médico en una técnica o familia de técnicas
/// (pregunta 36; art. 11 del Proyecto de Ley 187 de 2026, que no es ley:
/// VERIFICAR). Usar una técnica sin certificación vigente avisa y queda en
/// la bitácora, pero no bloquea.
class Certificacion {
  const Certificacion({
    required this.id,
    required this.familia,
    required this.entidad,
    required this.fecha,
    required this.creado,
    this.vigenteHasta,
    this.soporte,
    this.notas = '',
    this.retiradaEn,
  });

  static const coleccion = 'certificaciones';

  /// Tipo de binario del soporte (PDF o foto), cifrado.
  static const tipoBinario = 'certificacion';

  final String id;

  /// Técnica o familia (la misma que la plantilla del procedimiento).
  final String familia;
  final String entidad;
  final DateTime fecha;
  final DateTime creado;
  final DateTime? vigenteHasta;

  /// `pdf` o `jpg` si hay soporte guardado.
  final String? soporte;
  final String notas;

  /// No se borra: se retira con fecha.
  final DateTime? retiradaEn;

  bool vigenteEn(DateTime dia) =>
      retiradaEn == null &&
      !DateTime(
        dia.year,
        dia.month,
        dia.day,
      ).isBefore(DateTime(fecha.year, fecha.month, fecha.day)) &&
      (vigenteHasta == null ||
          !DateTime(dia.year, dia.month, dia.day).isAfter(vigenteHasta!));

  Certificacion copyWith({
    String? id,
    Object? soporte = sin,
    Object? retiradaEn = sin,
  }) => Certificacion(
    id: id ?? this.id,
    familia: familia,
    entidad: entidad,
    fecha: fecha,
    creado: creado,
    vigenteHasta: vigenteHasta,
    soporte: cambio(soporte, this.soporte),
    notas: notas,
    retiradaEn: cambio(retiradaEn, this.retiradaEn),
  );

  Map<String, Object?> aMapa() => compacto({
    'familia': familia,
    'entidad': entidad,
    'fecha': fechaIso(fecha),
    'creado': creado.toUtc().toIso8601String(),
    'vigenteHasta': vigenteHasta == null ? null : fechaIso(vigenteHasta!),
    'soporte': soporte,
    'notas': notas,
    'retiradaEn': retiradaEn?.toUtc().toIso8601String(),
  });

  static Certificacion desdeMapa(String id, Map<String, Object?> m) =>
      Certificacion(
        id: id,
        familia: m.texto('familia'),
        entidad: m.texto('entidad'),
        fecha: m.fecha('fecha')!,
        creado: DateTime.parse(m.texto('creado')).toLocal(),
        vigenteHasta: m.fecha('vigenteHasta'),
        soporte: m.textoONulo('soporte'),
        notas: m.texto('notas'),
        retiradaEn: m['retiradaEn'] == null
            ? null
            : DateTime.parse(m.texto('retiradaEn')).toLocal(),
      );
}

/// La familia de técnicas sin el «(VERIFICAR)» de la plantilla de fábrica,
/// en minúsculas, para comparar.
String claveFamilia(String familia) =>
    familia.replaceAll(RegExp(r'\(.*?\)'), '').trim().toLowerCase();
