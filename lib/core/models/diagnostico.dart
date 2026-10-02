import 'mapa.dart';

class Diagnostico {
  const Diagnostico({
    required this.id,
    this.descripcion = '',
    this.codigo = '',
    this.tipo = 'principal',
    this.caracter = 'presuntivo',
  });

  factory Diagnostico.desdeMapa(Map<String, Object?> m) => Diagnostico(
    id: m.texto('id'),
    descripcion: m.texto('descripcion'),
    codigo: m.texto('codigo'),
    tipo: m.textoONulo('tipo') ?? 'principal',
    caracter: m.textoONulo('caracter') ?? 'presuntivo',
  );

  /// Identificador estable dentro de la lista (para reordenar).
  final String id;
  final String descripcion;

  /// Código CIE-10, opcional.
  final String codigo;

  /// `principal` o `relacionado`.
  final String tipo;

  /// Código de `PerfilPais.caracteresDiagnostico`.
  final String caracter;

  /// "J02.9 Faringitis aguda"
  String get textoCorto =>
      [codigo.trim(), descripcion.trim()].where((s) => s.isNotEmpty).join(' ');

  Diagnostico copyWith({
    String? descripcion,
    String? codigo,
    String? tipo,
    String? caracter,
  }) => Diagnostico(
    id: id,
    descripcion: descripcion ?? this.descripcion,
    codigo: codigo ?? this.codigo,
    tipo: tipo ?? this.tipo,
    caracter: caracter ?? this.caracter,
  );

  Map<String, Object?> aMapa() => compacto({
    'id': id,
    'descripcion': descripcion,
    'codigo': codigo,
    'tipo': tipo,
    'caracter': caracter,
  });
}
