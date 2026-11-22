import 'dart:convert';

import '../../integridad/json_canonico.dart';
import '../../models/mapa.dart';
import '../../utils/texto.dart';
import 'plantillas.dart';
import '../procedimientos/plan_tratamiento.dart';

/// Marca de los adjuntos del consultorio. Es otra clave que la de
/// `historia.json` (`"app"`), así que abrir un documento o una receta en la
/// historia se comporta como con cualquier PDF ajeno. La clave se ordena
/// primero en el JSON canónico: la marca se busca al comienzo.
const marcaAdjuntoConsultorio = '"aplicacion":"historiasclinicas.net"';

const nombreAdjuntoDocumento = 'documento.json';

/// `Autorizacion_datos_PENA-MUNOZ_AD-000001.pdf`: solo ASCII (Chromium
/// descarta el nombre de una descarga con tildes o «ñ»).
String nombreArchivoDocumento(
  String base, {
  required String apellido,
  required String numero,
}) {
  String ascii(String s, String siVacio) {
    final r = sinTildes(s.trim())
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return r.isEmpty ? siVacio : r;
  }

  return '${base}_${ascii(apellido, 'SIN-APELLIDO')}_'
      '${ascii(numero, 'SIN-NUMERO')}.pdf';
}

/// Los tres usos de la imagen, cada uno por separado (pregunta 22).
class PermisosImagen {
  const PermisosImagen({
    this.clinico = false,
    this.docencia = false,
    this.publicidad = false,
  });

  /// Registro clínico: obligatorio para tomar fotos.
  final bool clinico;

  /// Docencia o publicación académica, sin rostro ni rasgos identificables.
  final bool docencia;

  /// Publicidad o redes sociales.
  final bool publicidad;

  List<String> get etiquetas => [
    if (clinico) 'uso clínico',
    if (docencia) 'docencia',
    if (publicidad) 'publicidad',
  ];

  /// El texto del marcador `{{permisos}}`.
  String get texto => [
    '${clinico ? '[X]' : '[ ]'} Registro clínico: documentar mi evolución y '
        'los resultados en mi historia clínica.',
    '${docencia ? '[X]' : '[ ]'} Docencia o publicación académica, sin mi '
        'rostro ni rasgos que me identifiquen.',
    '${publicidad ? '[X]' : '[ ]'} Publicidad o redes sociales.',
  ].join('\n');

  Map<String, Object?> aMapa() => {
    'clinico': clinico,
    'docencia': docencia,
    'publicidad': publicidad,
  };

  static PermisosImagen desdeMapa(Map<String, Object?> m) => PermisosImagen(
    clinico: m.booleano('clinico'),
    docencia: m.booleano('docencia'),
    publicidad: m.booleano('publicidad'),
  );
}

enum EstadoDocumento {
  vigente('Vigente'),
  revocado('Revocado'),
  anulado('Anulado');

  const EstadoDocumento(this.etiqueta);

  final String etiqueta;
}

/// Documento firmado o emitido: autorización de datos, consentimientos y
/// documentos clínicos (certificado, incapacidad, orden y remisión).
///
/// [datos] es lo sellado: va como `documento.json` dentro del PDF, con su
/// SHA-256, y no cambia después. El estado (revocado o anulado) se guarda
/// aparte.
class DocumentoConsultorio {
  const DocumentoConsultorio({
    required this.id,
    required this.datos,
    required this.creado,
    this.estado = EstadoDocumento.vigente,
    this.cambioEstado,
    this.motivoEstado = '',
    this.tienePdf = false,
  });

  static const coleccion = 'documentos';
  static const tipoBinarioPdf = 'pdfdoc';
  static const tipoBinarioFirma = 'firma';

  final String id;
  final Map<String, Object?> datos;
  final DateTime creado;
  final EstadoDocumento estado;
  final DateTime? cambioEstado;
  final String motivoEstado;
  final bool tienePdf;

  TipoPlantilla get tipo => TipoPlantilla.values.byName(datos.texto('tipo'));
  String get numero => datos.texto('numero');
  String get titulo => datos.texto('titulo');
  String get pacienteId => datos.texto('pacienteId');
  String get contenido => datos.texto('contenido');
  int get versionPlantilla => datos.entero('versionPlantilla') ?? 0;
  DateTime get fechaHora => datos.fecha('fechaHora')!;
  String get sha256Firma => datos.texto('sha256Firma');

  /// La plantilla con la que se emitió (documentos clínicos; en los demás,
  /// el nombre del tipo).
  String get plantillaId => datos.textoONulo('plantillaId') ?? tipo.name;

  /// Campos propios de un documento clínico (diagnóstico, días, fechas,
  /// finalidad, destino), o vacío.
  Map<String, Object?> get campos => datos.mapa('campos');
  bool get vigente => estado == EstadoDocumento.vigente;

  /// El plan que cubre un consentimiento informado, o `null`.
  PlanTratamiento? get plan => datos['plan'] == null
      ? null
      : PlanTratamiento.desdeMapa(datos.mapa('plan'));

  /// Usos autorizados de la imagen (solo el consentimiento de imagen).
  PermisosImagen get permisos =>
      PermisosImagen.desdeMapa(datos.mapa('permisos'));

  /// SHA-256 de [datos] en JSON canónico: la huella del documento.
  String get hash => sha256Canonico(datos);

  /// `documento.json`: lo sellado más su huella, solo ASCII.
  String get json => jsonCanonico({
    'aplicacion': 'historiasclinicas.net',
    'documento': datos,
    'sha256': hash,
  });

  DocumentoConsultorio copyWith({
    EstadoDocumento? estado,
    DateTime? cambioEstado,
    String? motivoEstado,
    bool? tienePdf,
  }) => DocumentoConsultorio(
    id: id,
    datos: datos,
    creado: creado,
    estado: estado ?? this.estado,
    cambioEstado: cambioEstado ?? this.cambioEstado,
    motivoEstado: motivoEstado ?? this.motivoEstado,
    tienePdf: tienePdf ?? this.tienePdf,
  );

  Map<String, Object?> aMapa() => compacto({
    'datos': datos,
    'creado': creado.toUtc().toIso8601String(),
    'estado': estado.name,
    'cambioEstado': cambioEstado?.toUtc().toIso8601String(),
    'motivoEstado': motivoEstado,
    'tienePdf': tienePdf ? true : null,
  });

  static DocumentoConsultorio desdeMapa(String id, Map<String, Object?> m) =>
      DocumentoConsultorio(
        id: id,
        datos: m.mapa('datos'),
        creado: DateTime.parse(m['creado']! as String).toLocal(),
        estado: EstadoDocumento.values.byName(m.texto('estado')),
        cambioEstado: m['cambioEstado'] == null
            ? null
            : DateTime.parse(m['cambioEstado']! as String).toLocal(),
        motivoEstado: m.texto('motivoEstado'),
        tienePdf: m.booleano('tienePdf'),
      );
}

/// Lee un `documento.json` y comprueba su huella. Devuelve los datos
/// sellados, o `null` si no es un documento o la huella no coincide.
Map<String, Object?>? leerDocumentoJson(List<int> bytes) {
  try {
    final m = (jsonDecode(utf8.decode(bytes)) as Map).cast<String, Object?>();
    final datos = (m['documento'] as Map?)?.cast<String, Object?>();
    if (datos == null || m['sha256'] != sha256Canonico(datos)) return null;
    return datos;
  } on Object {
    return null;
  }
}
