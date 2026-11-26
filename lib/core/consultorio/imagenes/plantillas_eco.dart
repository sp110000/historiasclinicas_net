/// Plantillas base del informe ecográfico (parte 1 de Imágenes). Cada una
/// trae las secciones de hallazgos con un texto normal que el médico edita,
/// las medidas habituales y una impresión normal. Son una base: el informe
/// se escribe y se revisa en cada estudio.
library;

/// Una medida de la plantilla. Con [volumen], se piden tres diámetros en cm
/// y se calcula el volumen del elipsoide (× 0,523) en mL.
class MedidaPlantilla {
  const MedidaPlantilla(this.nombre, this.unidad, {this.volumen = false});

  final String nombre;
  final String unidad;
  final bool volumen;
}

/// Una sección de hallazgos: el órgano o la región y su texto normal.
class SeccionPlantilla {
  const SeccionPlantilla(this.titulo, this.textoNormal);

  final String titulo;
  final String textoNormal;
}

class PlantillaEco {
  const PlantillaEco({
    required this.id,
    required this.nombre,
    required this.tecnica,
    required this.secciones,
    this.medidas = const [],
    this.impresion = '',
  });

  final String id;

  /// «Ecografía de tiroides»: el título del informe.
  final String nombre;

  /// Técnica sugerida (transductor y abordaje).
  final String tecnica;
  final List<SeccionPlantilla> secciones;
  final List<MedidaPlantilla> medidas;

  /// Impresión diagnóstica cuando todo es normal.
  final String impresion;
}

const _convexo = 'Transabdominal, transductor convexo';
const _lineal = 'Transductor lineal de alta frecuencia';

const plantillasEcoBase = <PlantillaEco>[
  PlantillaEco(
    id: 'abdominal_total',
    nombre: 'Ecografía abdominal total',
    tecnica: _convexo,
    secciones: [
      SeccionPlantilla(
        'Hígado',
        'De tamaño normal, contornos regulares y ecogenicidad homogénea. Sin '
            'lesiones focales.',
      ),
      SeccionPlantilla(
        'Vesícula biliar',
        'Distendida, de paredes delgadas, sin cálculos ni barro biliar.',
      ),
      SeccionPlantilla(
        'Vías biliares',
        'Intra y extrahepáticas de calibre normal.',
      ),
      SeccionPlantilla(
        'Páncreas',
        'Visible en lo que permite el gas intestinal, de tamaño y '
            'ecogenicidad normales.',
      ),
      SeccionPlantilla('Bazo', 'De tamaño normal y ecogenicidad homogénea.'),
      SeccionPlantilla(
        'Riñones',
        'De tamaño y forma normales, con buena diferenciación '
            'corticomedular. Sin dilatación de los sistemas colectores ni '
            'cálculos.',
      ),
      SeccionPlantilla(
        'Aorta abdominal',
        'De calibre normal en los segmentos visualizados.',
      ),
      SeccionPlantilla('Líquido libre', 'No se observa líquido libre.'),
    ],
    medidas: [
      MedidaPlantilla('Hígado, lóbulo derecho (longitud)', 'cm'),
      MedidaPlantilla('Colédoco (diámetro)', 'mm'),
      MedidaPlantilla('Bazo (longitud)', 'cm'),
      MedidaPlantilla('Riñón derecho (longitud)', 'cm'),
      MedidaPlantilla('Riñón izquierdo (longitud)', 'cm'),
    ],
    impresion: 'Ecografía abdominal dentro de límites normales.',
  ),
  PlantillaEco(
    id: 'higado_vias_biliares',
    nombre: 'Ecografía de hígado y vías biliares',
    tecnica: _convexo,
    secciones: [
      SeccionPlantilla(
        'Hígado',
        'De tamaño normal, contornos regulares y ecogenicidad homogénea. Sin '
            'lesiones focales.',
      ),
      SeccionPlantilla(
        'Vesícula biliar',
        'Distendida, de paredes delgadas, sin cálculos ni barro biliar. '
            'Murphy ecográfico negativo.',
      ),
      SeccionPlantilla(
        'Vías biliares',
        'Intra y extrahepáticas de calibre normal.',
      ),
    ],
    medidas: [
      MedidaPlantilla('Hígado, lóbulo derecho (longitud)', 'cm'),
      MedidaPlantilla('Pared vesicular (espesor)', 'mm'),
      MedidaPlantilla('Colédoco (diámetro)', 'mm'),
    ],
    impresion: 'Hígado y vías biliares sin alteraciones ecográficas.',
  ),
  PlantillaEco(
    id: 'renal_vias_urinarias',
    nombre: 'Ecografía renal y de vías urinarias',
    tecnica: _convexo,
    secciones: [
      SeccionPlantilla(
        'Riñón derecho',
        'De tamaño y forma normales, buena diferenciación corticomedular. '
            'Sin dilatación del sistema colector ni cálculos.',
      ),
      SeccionPlantilla(
        'Riñón izquierdo',
        'De tamaño y forma normales, buena diferenciación corticomedular. '
            'Sin dilatación del sistema colector ni cálculos.',
      ),
      SeccionPlantilla(
        'Vejiga',
        'Con adecuada repleción, paredes delgadas y contenido anecoico.',
      ),
    ],
    medidas: [
      MedidaPlantilla('Riñón derecho (longitud)', 'cm'),
      MedidaPlantilla('Riñón derecho, parénquima (espesor)', 'mm'),
      MedidaPlantilla('Riñón izquierdo (longitud)', 'cm'),
      MedidaPlantilla('Riñón izquierdo, parénquima (espesor)', 'mm'),
      MedidaPlantilla('Vejiga, volumen prevaciado', 'mL', volumen: true),
      MedidaPlantilla('Residuo posmiccional', 'mL', volumen: true),
    ],
    impresion: 'Riñones y vejiga sin alteraciones ecográficas.',
  ),
  PlantillaEco(
    id: 'tiroides_cuello',
    nombre: 'Ecografía de tiroides y cuello',
    tecnica: _lineal,
    secciones: [
      SeccionPlantilla(
        'Lóbulo derecho',
        'De tamaño normal, ecogenicidad homogénea. Sin nódulos.',
      ),
      SeccionPlantilla(
        'Lóbulo izquierdo',
        'De tamaño normal, ecogenicidad homogénea. Sin nódulos.',
      ),
      SeccionPlantilla('Istmo', 'De espesor normal.'),
      SeccionPlantilla(
        'Ganglios cervicales',
        'Sin adenopatías de aspecto patológico.',
      ),
    ],
    medidas: [
      MedidaPlantilla('Lóbulo derecho', 'mL', volumen: true),
      MedidaPlantilla('Lóbulo izquierdo', 'mL', volumen: true),
      MedidaPlantilla('Istmo (espesor)', 'mm'),
    ],
    impresion: 'Glándula tiroides de tamaño y ecogenicidad normales.',
  ),
  PlantillaEco(
    id: 'pelvica_transabdominal',
    nombre: 'Ecografía pélvica ginecológica transabdominal',
    tecnica: '$_convexo, con vejiga llena',
    secciones: [
      SeccionPlantilla(
        'Útero',
        'En anteversoflexión, de tamaño y contornos normales, miometrio '
            'homogéneo.',
      ),
      SeccionPlantilla('Endometrio', 'Lineal, de espesor acorde al ciclo.'),
      SeccionPlantilla('Ovario derecho', 'De tamaño y morfología normales.'),
      SeccionPlantilla('Ovario izquierdo', 'De tamaño y morfología normales.'),
      SeccionPlantilla('Fondo de saco de Douglas', 'Sin líquido libre.'),
    ],
    medidas: [
      MedidaPlantilla('Útero', 'mL', volumen: true),
      MedidaPlantilla('Endometrio (espesor)', 'mm'),
      MedidaPlantilla('Ovario derecho', 'mL', volumen: true),
      MedidaPlantilla('Ovario izquierdo', 'mL', volumen: true),
    ],
    impresion: 'Útero y ovarios sin alteraciones ecográficas.',
  ),
  PlantillaEco(
    id: 'vejiga_residuo',
    nombre: 'Ecografía de vejiga y residuo posmiccional',
    tecnica: _convexo,
    secciones: [
      SeccionPlantilla(
        'Vejiga',
        'Con adecuada repleción, paredes delgadas y contenido anecoico.',
      ),
      SeccionPlantilla('Próstata', 'De tamaño y ecogenicidad normales.'),
    ],
    medidas: [
      MedidaPlantilla('Volumen prevaciado', 'mL', volumen: true),
      MedidaPlantilla('Residuo posmiccional', 'mL', volumen: true),
      MedidaPlantilla('Próstata', 'mL', volumen: true),
    ],
    impresion: 'Vaciamiento vesical adecuado.',
  ),
  PlantillaEco(
    id: 'partes_blandas',
    nombre: 'Ecografía de partes blandas',
    tecnica: _lineal,
    secciones: [
      SeccionPlantilla('Región explorada', ''),
      SeccionPlantilla(
        'Hallazgos',
        'Piel, tejido celular subcutáneo y planos musculares de aspecto '
            'normal. Sin colecciones ni masas.',
      ),
    ],
    medidas: [MedidaPlantilla('Lesión', 'mL', volumen: true)],
    impresion: 'Partes blandas sin alteraciones ecográficas.',
  ),
  PlantillaEco(
    id: 'inguinal_pared',
    nombre: 'Ecografía inguinal y de pared abdominal',
    tecnica: '$_lineal, en reposo y con maniobra de Valsalva',
    secciones: [
      SeccionPlantilla(
        'Región inguinal derecha',
        'Sin protrusión de contenido herniario en reposo ni con Valsalva.',
      ),
      SeccionPlantilla(
        'Región inguinal izquierda',
        'Sin protrusión de contenido herniario en reposo ni con Valsalva.',
      ),
      SeccionPlantilla(
        'Pared abdominal',
        'Sin defectos de la pared ni colecciones.',
      ),
    ],
    medidas: [MedidaPlantilla('Defecto herniario (cuello)', 'mm')],
    impresion: 'Sin hernias en las regiones exploradas.',
  ),
  PlantillaEco(
    id: 'testicular',
    nombre: 'Ecografía testicular',
    tecnica: '$_lineal, con Doppler color',
    secciones: [
      SeccionPlantilla(
        'Testículo derecho',
        'De tamaño normal, ecogenicidad homogénea, con flujo al Doppler.',
      ),
      SeccionPlantilla(
        'Testículo izquierdo',
        'De tamaño normal, ecogenicidad homogénea, con flujo al Doppler.',
      ),
      SeccionPlantilla('Epidídimos', 'De tamaño y ecogenicidad normales.'),
      SeccionPlantilla('Bolsa escrotal', 'Sin hidrocele ni varicocele.'),
    ],
    medidas: [
      MedidaPlantilla('Testículo derecho', 'mL', volumen: true),
      MedidaPlantilla('Testículo izquierdo', 'mL', volumen: true),
    ],
    impresion: 'Testículos y epidídimos sin alteraciones ecográficas.',
  ),
  PlantillaEco(
    id: 'mamaria',
    nombre: 'Ecografía mamaria',
    tecnica: _lineal,
    secciones: [
      SeccionPlantilla(
        'Mama derecha',
        'Patrón fibroglandular, sin nódulos ni quistes.',
      ),
      SeccionPlantilla(
        'Mama izquierda',
        'Patrón fibroglandular, sin nódulos ni quistes.',
      ),
      SeccionPlantilla('Axilas', 'Sin adenopatías de aspecto patológico.'),
    ],
    medidas: [MedidaPlantilla('Lesión', 'mL', volumen: true)],
    impresion: 'Mamas sin alteraciones ecográficas.',
  ),
  PlantillaEco(
    id: 'musculoesqueletica',
    nombre: 'Ecografía musculoesquelética',
    tecnica: _lineal,
    secciones: [
      SeccionPlantilla('Estructura explorada', ''),
      SeccionPlantilla(
        'Tendones',
        'De espesor y ecoestructura fibrilar normales.',
      ),
      SeccionPlantilla('Músculo', 'Sin roturas ni colecciones.'),
      SeccionPlantilla('Articulación', 'Sin derrame articular.'),
    ],
    medidas: [MedidaPlantilla('Tendón (espesor)', 'mm')],
    impresion: 'Estructuras exploradas sin alteraciones ecográficas.',
  ),
  PlantillaEco(
    id: 'fast',
    nombre: 'Ecografía FAST / eFAST',
    tecnica: 'Transductor convexo y lineal',
    secciones: [
      SeccionPlantilla('Espacio hepatorrenal (Morison)', 'Sin líquido libre.'),
      SeccionPlantilla('Espacio esplenorrenal', 'Sin líquido libre.'),
      SeccionPlantilla('Pelvis', 'Sin líquido libre.'),
      SeccionPlantilla('Pericardio (subxifoideo)', 'Sin derrame pericárdico.'),
      SeccionPlantilla(
        'Tórax (eFAST)',
        'Deslizamiento pleural presente en ambos campos anteriores.',
      ),
    ],
    impresion: 'FAST negativo.',
  ),
  PlantillaEco(
    id: 'pulmonar',
    nombre: 'Ecografía pulmonar',
    tecnica: 'Transductor convexo o lineal',
    secciones: [
      SeccionPlantilla(
        'Campos anteriores',
        'Deslizamiento pleural presente, patrón de líneas A.',
      ),
      SeccionPlantilla(
        'Campos laterales',
        'Patrón de líneas A, sin consolidaciones.',
      ),
      SeccionPlantilla('Bases posteriores', 'Sin derrame pleural.'),
    ],
    medidas: [MedidaPlantilla('Derrame pleural (espesor)', 'mm')],
    impresion: 'Ecografía pulmonar sin alteraciones.',
  ),
  PlantillaEco(
    id: 'tvp_compresion',
    nombre: 'Ecografía venosa por compresión (TVP)',
    tecnica: _lineal,
    secciones: [
      SeccionPlantilla(
        'Miembro inferior derecho',
        'Venas femoral común, femoral y poplítea compresibles en su '
            'totalidad.',
      ),
      SeccionPlantilla(
        'Miembro inferior izquierdo',
        'Venas femoral común, femoral y poplítea compresibles en su '
            'totalidad.',
      ),
    ],
    impresion:
        'Sin signos de trombosis venosa profunda en los segmentos '
        'explorados.',
  ),
  PlantillaEco(
    id: 'libre',
    nombre: 'Otra ecografía',
    tecnica: '',
    secciones: [SeccionPlantilla('Hallazgos', '')],
  ),
];

PlantillaEco? plantillaEco(String id) =>
    plantillasEcoBase.where((p) => p.id == id).firstOrNull;
