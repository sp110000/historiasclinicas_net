import 'mapa.dart';

/// Sistema de la revisión de síntomas, con ejemplos para orientar el
/// interrogatorio.
class SistemaRevision {
  const SistemaRevision(this.codigo, this.nombre, this.ejemplos);

  final String codigo;
  final String nombre;
  final String ejemplos;
}

/// Sistemas en el orden del formulario y del PDF.
const sistemasRevision = [
  SistemaRevision(
    'generales',
    'Generales',
    'fiebre, astenia, pérdida de peso, diaforesis',
  ),
  SistemaRevision(
    'piel',
    'Piel y faneras',
    'lesiones, prurito, cambios de color',
  ),
  SistemaRevision(
    'cabeza_cuello',
    'Cabeza, ojos, oídos, nariz y garganta',
    'cefalea, visión, audición, rinorrea, odinofagia',
  ),
  SistemaRevision(
    'respiratorio',
    'Respiratorio',
    'tos, expectoración, disnea, sibilancias',
  ),
  SistemaRevision(
    'cardiovascular',
    'Cardiovascular',
    'dolor torácico, palpitaciones, edemas',
  ),
  SistemaRevision(
    'gastrointestinal',
    'Gastrointestinal',
    'náuseas, vómito, dolor abdominal, cambios en las deposiciones',
  ),
  SistemaRevision(
    'genitourinario',
    'Genitourinario',
    'disuria, polaquiuria, hematuria, flujo, sangrado',
  ),
  SistemaRevision(
    'endocrino',
    'Endocrino y metabólico',
    'polidipsia, poliuria, intolerancia al calor o al frío',
  ),
  SistemaRevision(
    'musculoesqueletico',
    'Musculoesquelético',
    'artralgias, mialgias, limitación funcional',
  ),
  SistemaRevision(
    'neurologico',
    'Neurológico',
    'mareo, convulsiones, parestesias, debilidad',
  ),
  SistemaRevision(
    'mental',
    'Mental y del comportamiento',
    'ánimo, ansiedad, sueño',
  ),
  SistemaRevision(
    'hematologico',
    'Hematológico y linfático',
    'sangrados, equimosis, adenopatías',
  ),
];

enum EstadoSistema {
  niega('Niega'),
  refiere('Refiere');

  const EstadoSistema(this.etiqueta);

  final String etiqueta;

  static EstadoSistema? desdeNombre(String? nombre) =>
      values.where((e) => e.name == nombre).firstOrNull;
}

class HallazgoSistema {
  const HallazgoSistema({this.estado, this.detalle = ''});

  factory HallazgoSistema.desdeMapa(Map<String, Object?> m) => HallazgoSistema(
    estado: EstadoSistema.desdeNombre(m.textoONulo('estado')),
    detalle: m.texto('detalle'),
  );

  final EstadoSistema? estado;

  /// Síntomas que refiere (solo cuando [estado] es `refiere`).
  final String detalle;

  bool get vacio => estado == null && detalle.trim().isEmpty;

  Map<String, Object?> aMapa() =>
      compacto({'estado': estado?.name, 'detalle': detalle});
}

/// Revisión de síntomas por sistemas.
class RevisionSistemas {
  const RevisionSistemas({this.sistemas = const {}, this.observaciones = ''});

  factory RevisionSistemas.desdeMapa(Map<String, Object?> m) {
    final s = m.mapa('sistemas');
    return RevisionSistemas(
      sistemas: {
        for (final e in s.entries)
          e.key: HallazgoSistema.desdeMapa(
            (e.value! as Map).cast<String, Object?>(),
          ),
      },
      observaciones: m.texto('observaciones'),
    );
  }

  /// Hallazgo por código de sistema (ver [sistemasRevision]).
  final Map<String, HallazgoSistema> sistemas;
  final String observaciones;

  HallazgoSistema de(String codigo) =>
      sistemas[codigo] ?? const HallazgoSistema();

  RevisionSistemas con(String codigo, HallazgoSistema hallazgo) =>
      RevisionSistemas(
        sistemas: {...sistemas, codigo: hallazgo},
        observaciones: observaciones,
      );

  /// Marca como "Niega" los sistemas que aún no tienen respuesta.
  RevisionSistemas negarPendientes() => RevisionSistemas(
    sistemas: {
      ...sistemas,
      for (final s in sistemasRevision)
        if (de(s.codigo).estado == null)
          s.codigo: HallazgoSistema(
            estado: EstadoSistema.niega,
            detalle: de(s.codigo).detalle,
          ),
    },
    observaciones: observaciones,
  );

  RevisionSistemas copyWith({String? observaciones}) => RevisionSistemas(
    sistemas: sistemas,
    observaciones: observaciones ?? this.observaciones,
  );

  /// Sistemas con respuesta (niega o refiere).
  int get registrados =>
      sistemasRevision.where((s) => de(s.codigo).estado != null).length;

  bool get completa => registrados == sistemasRevision.length;

  bool get vacia => registrados == 0 && observaciones.trim().isEmpty;

  List<SistemaRevision> conEstado(EstadoSistema estado) =>
      sistemasRevision.where((s) => de(s.codigo).estado == estado).toList();

  Map<String, Object?> aMapa() {
    final conDatos = {
      for (final e in sistemas.entries)
        if (!e.value.vacio) e.key: e.value.aMapa(),
    };
    return compacto({
      'sistemas': conDatos.isEmpty ? null : conDatos,
      'observaciones': observaciones,
    });
  }
}
