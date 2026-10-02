import 'mapa.dart';
import 'medico.dart';
import 'signos_vitales.dart';

/// Entrada de seguimiento. Se agrega al final y, una vez sellada (con
/// [hash]), no se modifica.
class Evolucion {
  const Evolucion({
    required this.id,
    required this.fechaHora,
    this.texto = '',
    this.signos = const SignosVitales(),
    this.incluirFirma = true,
    this.incluirSello = true,
    this.avisoIntegridad,
    this.autor,
    this.hash,
  });

  factory Evolucion.desdeMapa(Map<String, Object?> m) => Evolucion(
    id: m.texto('id'),
    fechaHora: m.fecha('fechaHora')!,
    texto: m.texto('texto'),
    signos: SignosVitales.desdeMapa(m.mapa('signosVitales')),
    incluirFirma: m.booleano('incluirFirma', porDefecto: true),
    incluirSello: m.booleano('incluirSello', porDefecto: true),
    avisoIntegridad: m.textoONulo('avisoIntegridad'),
    autor: m['autor'] == null ? null : Autor.desdeMapa(m.mapa('autor')),
    hash: m.textoONulo('hash'),
  );

  /// Identificador estable (UUID).
  final String id;

  /// Hora local en que se escribió (editable solo antes de sellarla).
  final DateTime fechaHora;
  final String texto;
  final SignosVitales signos;
  final bool incluirFirma;
  final bool incluirSello;

  /// Nota automática cuando se agregó sobre una historia con alteraciones.
  final String? avisoIntegridad;

  /// Médico que la escribió (copia tomada al sellarla).
  final Autor? autor;

  /// SHA-256 encadenado; `null` mientras no está sellada.
  final String? hash;

  bool get sellada => hash != null;

  Evolucion copyWith({
    DateTime? fechaHora,
    String? texto,
    SignosVitales? signos,
    bool? incluirFirma,
    bool? incluirSello,
    Object? avisoIntegridad = sin,
  }) => Evolucion(
    id: id,
    fechaHora: fechaHora ?? this.fechaHora,
    texto: texto ?? this.texto,
    signos: signos ?? this.signos,
    incluirFirma: incluirFirma ?? this.incluirFirma,
    incluirSello: incluirSello ?? this.incluirSello,
    avisoIntegridad: cambio(avisoIntegridad, this.avisoIntegridad),
    autor: autor,
    hash: hash,
  );

  /// Mapa sin el hash: es lo que se sella.
  Map<String, Object?> aMapa() => compacto({
    'id': id,
    'fechaHora': fechaHoraIso(fechaHora),
    'texto': texto,
    'signosVitales': signos.vacio ? null : signos.aMapa(),
    'incluirFirma': incluirFirma,
    'incluirSello': incluirSello,
    'avisoIntegridad': avisoIntegridad,
    'autor': autor?.aMapa(),
  });
}
