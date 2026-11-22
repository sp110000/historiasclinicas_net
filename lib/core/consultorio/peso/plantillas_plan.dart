import '../../models/mapa.dart';
import '../documentos/plantillas.dart';

enum TipoPlan {
  nutricional('Plan nutricional'),
  ejercicio('Plan de ejercicio');

  const TipoPlan(this.etiqueta);

  final String etiqueta;
}

/// Plantilla de plan nutricional o de ejercicio (pregunta 26), con
/// versiones como las de los documentos: las de fábrica son un BORRADOR
/// con los apartados en blanco, y no se usan hasta aprobarlas.
class PlantillaPlan {
  const PlantillaPlan({
    required this.id,
    required this.tipo,
    required this.versiones,
  });

  static const coleccion = 'plantillasPlan';

  final String id;
  final TipoPlan tipo;
  final List<VersionPlantilla> versiones;

  VersionPlantilla? get vigente =>
      versiones.where((v) => v.aprobada).lastOrNull;

  VersionPlantilla? get borrador =>
      versiones.isNotEmpty && !versiones.last.aprobada ? versiones.last : null;

  VersionPlantilla get ultima => versiones.last;

  bool get usable => vigente != null;

  String get nombre => (vigente ?? ultima).titulo;

  PlantillaPlan conBorrador(String titulo, String cuerpo) {
    final b = borrador;
    return PlantillaPlan(
      id: id,
      tipo: tipo,
      versiones: [
        ...b == null ? versiones : versiones.sublist(0, versiones.length - 1),
        VersionPlantilla(
          version: b?.version ?? ultima.version + 1,
          titulo: titulo,
          cuerpo: cuerpo,
        ),
      ],
    );
  }

  PlantillaPlan aprobada(DateTime ahora) {
    final b = borrador;
    if (b == null) throw StateError('No hay un borrador para aprobar.');
    return PlantillaPlan(
      id: id,
      tipo: tipo,
      versiones: [
        ...versiones.sublist(0, versiones.length - 1),
        VersionPlantilla(
          version: b.version,
          titulo: b.titulo,
          cuerpo: b.cuerpo,
          aprobadaEn: ahora,
        ),
      ],
    );
  }

  Map<String, Object?> aMapa() => {
    'tipo': tipo.name,
    'versiones': [for (final v in versiones) v.aMapa()],
  };

  static PlantillaPlan desdeMapa(String id, Map<String, Object?> m) =>
      PlantillaPlan(
        id: id,
        tipo: TipoPlan.values.byName(m.texto('tipo')),
        versiones: [
          for (final v in m.listaMapas('versiones'))
            VersionPlantilla.desdeMapa(v),
        ],
      );
}

/// Marcadores de los planes.
const marcadoresPlan = {
  'paciente': 'Nombre del paciente',
  'proteina': 'Proteína indicada en el programa',
  'metaPeso': 'Peso meta',
  'fecha': 'Fecha de hoy',
};

/// Las tres de fábrica: solo la estructura, con los apartados en blanco
/// («______»). No traen cifras: las escribe el médico.
final plantillasPlanBase = [
  PlantillaPlan(
    id: 'deficit_moderado',
    tipo: TipoPlan.nutricional,
    versiones: [
      VersionPlantilla(
        version: 1,
        titulo: 'Déficit moderado',
        cuerpo: _deficit.trim(),
      ),
    ],
  ),
  PlantillaPlan(
    id: 'con_glp1',
    tipo: TipoPlan.nutricional,
    versiones: [
      VersionPlantilla(
        version: 1,
        titulo: 'Alimentación con GLP-1',
        cuerpo: _conGlp1.trim(),
      ),
    ],
  ),
  PlantillaPlan(
    id: 'fuerza_caminata',
    tipo: TipoPlan.ejercicio,
    versiones: [
      VersionPlantilla(
        version: 1,
        titulo: 'Fuerza y caminata',
        cuerpo: _fuerza.trim(),
      ),
    ],
  ),
];

const _deficit = '''
Plan de alimentación para {{paciente}} ({{fecha}}). Meta de peso: {{metaPeso}}.

Objetivo diario: ______
Proteína: {{proteina}}, repartida en las comidas principales.
Comidas al día y horarios: ______
Porciones o intercambios por comida: ______
Alimentos para preferir: ______
Alimentos para limitar: ______
Agua y bebidas: ______
Cuándo consultar antes del control: ______
''';

const _conGlp1 = '''
Alimentación durante el tratamiento con GLP-1 para {{paciente}} ({{fecha}}).

Proteína: {{proteina}}, aun con poco apetito.
Tamaño de las porciones y número de comidas: ______
Cómo comer (despacio, parar al sentirse lleno): ______
Agua y bebidas: ______
Qué hacer si hay náuseas o llenura: ______
Alimentos que conviene evitar mientras se ajusta la dosis: ______
Cuándo consultar antes del control: ______
''';

const _fuerza = '''
Plan de ejercicio para {{paciente}} ({{fecha}}).

Fuerza (para conservar la masa muscular): ______ días por semana, ______
Caminata u otro ejercicio aeróbico: ______ minutos, ______ días por semana
Cómo empezar y cómo progresar: ______
Calentamiento y estiramientos: ______
Cuándo parar y consultar: ______
''';
