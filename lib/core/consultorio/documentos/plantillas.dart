import '../../models/mapa.dart';
import 'plantillas_clinicas.dart';

export 'plantillas_clinicas.dart' show cuerpoBaseClinico, plantillasDeFabrica;

/// Tipos de plantilla de documento.
enum TipoPlantilla {
  autorizacionDatos(
    'Autorización de tratamiento de datos',
    'AD',
    'Autorizacion_datos',
  ),
  consentimientoImagen(
    'Consentimiento de uso de imagen',
    'CIM',
    'Consentimiento_imagen',
  ),

  /// Consentimiento informado de un procedimiento, por plan de tratamiento
  /// (5.3, pregunta 39).
  consentimientoInformado(
    'Consentimiento informado de procedimiento',
    'CI',
    'Consentimiento_informado',
  ),
  politicaPrivacidad(
    'Política de tratamiento de datos personales',
    null,
    'Politica_datos',
    firmaPaciente: false,
  ),

  /// Documentos clínicos (5.4): los expide el médico, sin la firma del
  /// paciente. Los tipos con [varias] tienen una plantilla por uso
  /// (general, laboral…; perfil metabólico, TSH…).
  certificado(
    'Certificado médico',
    'CE',
    'Certificado',
    firmaPaciente: false,
    varias: true,
  ),
  incapacidad('Incapacidad médica', 'IN', 'Incapacidad', firmaPaciente: false),
  orden(
    'Orden de laboratorio o imágenes',
    'OR',
    'Orden',
    firmaPaciente: false,
    varias: true,
  ),
  remision(
    'Remisión o interconsulta',
    'RM',
    'Remision',
    firmaPaciente: false,
    varias: true,
  );

  const TipoPlantilla(
    this.etiqueta,
    this.prefijo,
    this.baseArchivo, {
    this.firmaPaciente = true,
    this.varias = false,
  });

  final String etiqueta;

  /// Comienzo del nombre de sus PDF, solo ASCII.
  final String baseArchivo;

  /// Prefijo del consecutivo de los documentos firmados con ella, o `null`
  /// si no lleva número (la política es una sola, con versión).
  final String? prefijo;

  /// Se firma con el paciente (en pantalla).
  final bool firmaPaciente;

  /// Tiene varias plantillas (una por uso), y se pueden agregar más.
  final bool varias;

  bool get conFirmaDelPaciente => firmaPaciente;

  /// Certificado, incapacidad, orden o remisión: los expide el médico.
  bool get clinico => prefijo != null && !firmaPaciente;

  static const clinicos = [certificado, incapacidad, orden, remision];
}

/// Una versión del texto de una plantilla. Una versión aprobada no se
/// edita: editarla crea la siguiente, en borrador.
class VersionPlantilla {
  const VersionPlantilla({
    required this.version,
    required this.titulo,
    required this.cuerpo,
    this.aprobadaEn,
  });

  final int version;
  final String titulo;

  /// Texto con marcadores `{{clave}}` (ver [marcadoresPlantilla]).
  final String cuerpo;
  final DateTime? aprobadaEn;

  bool get aprobada => aprobadaEn != null;

  Map<String, Object?> aMapa() => compacto({
    'version': version,
    'titulo': titulo,
    'cuerpo': cuerpo,
    'aprobadaEn': aprobadaEn?.toUtc().toIso8601String(),
  });

  static VersionPlantilla desdeMapa(Map<String, Object?> m) => VersionPlantilla(
    version: m.entero('version')!,
    titulo: m.texto('titulo'),
    cuerpo: m.texto('cuerpo'),
    aprobadaEn: m['aprobadaEn'] == null
        ? null
        : DateTime.parse(m['aprobadaEn']! as String).toLocal(),
  );
}

/// Plantilla con su historial de versiones, de la 1 a la última.
///
/// Los tipos con una sola plantilla usan el nombre del tipo como [id]. Los
/// que tienen [TipoPlantilla.varias] usan un id propio por plantilla
/// («certificado_laboral», «orden_tsh» o una que agregó el médico).
class Plantilla {
  const Plantilla({
    required this.tipo,
    required this.versiones,
    String? id,
    String? nombre,
    this.propia = false,
  }) : _id = id,
       _nombre = nombre;

  static const coleccion = 'plantillas';

  final TipoPlantilla tipo;
  final List<VersionPlantilla> versiones;
  final String? _id;
  final String? _nombre;

  /// La agregó el médico (no es de fábrica).
  final bool propia;

  String get id => _id ?? tipo.name;

  /// Nombre en las listas («Perfil metabólico»).
  String get nombre => _nombre ?? tipo.etiqueta;

  /// La última aprobada: la que usan los documentos nuevos. `null` mientras
  /// ninguna versión esté aprobada (no se puede usar).
  VersionPlantilla? get vigente =>
      versiones.where((v) => v.aprobada).lastOrNull;

  /// La última, si todavía no está aprobada.
  VersionPlantilla? get borrador =>
      versiones.isNotEmpty && !versiones.last.aprobada ? versiones.last : null;

  VersionPlantilla get ultima => versiones.last;

  bool get usable => vigente != null;

  Plantilla _con(List<VersionPlantilla> v, {String? nombre}) => Plantilla(
    tipo: tipo,
    versiones: v,
    id: _id,
    nombre: nombre ?? _nombre,
    propia: propia,
  );

  /// Guarda el texto: reemplaza el borrador, o crea la versión siguiente si
  /// la última ya está aprobada.
  Plantilla conBorrador(String titulo, String cuerpo, {String? nombre}) {
    final b = borrador;
    final nueva = VersionPlantilla(
      version: b?.version ?? ultima.version + 1,
      titulo: titulo,
      cuerpo: cuerpo,
    );
    return _con([
      ...b == null ? versiones : versiones.sublist(0, versiones.length - 1),
      nueva,
    ], nombre: nombre);
  }

  /// Aprueba el borrador. Lanza [StateError] si no hay borrador.
  Plantilla aprobada(DateTime ahora) {
    final b = borrador;
    if (b == null) throw StateError('No hay un borrador para aprobar.');
    return _con([
      ...versiones.sublist(0, versiones.length - 1),
      VersionPlantilla(
        version: b.version,
        titulo: b.titulo,
        cuerpo: b.cuerpo,
        aprobadaEn: ahora,
      ),
    ]);
  }

  Map<String, Object?> aMapa() => compacto({
    if (id != tipo.name) 'tipo': tipo.name,
    'nombre': _nombre,
    'propia': propia ? true : null,
    'versiones': [for (final v in versiones) v.aMapa()],
  });

  static Plantilla desdeMapa(String id, Map<String, Object?> m) {
    final tipo = TipoPlantilla.values.byName(m.textoONulo('tipo') ?? id);
    return Plantilla(
      tipo: tipo,
      id: id == tipo.name ? null : id,
      nombre: m.textoONulo('nombre') ?? plantillasDeFabrica[id]?._nombre,
      propia: m.booleano('propia'),
      versiones: [
        for (final v in m.listaMapas('versiones'))
          VersionPlantilla.desdeMapa(v),
      ],
    );
  }

  /// La plantilla de fábrica: versión 1 en borrador.
  static Plantilla base(TipoPlantilla tipo) =>
      plantillasDeFabrica[tipo.name] ??
      Plantilla(
        tipo: tipo,
        versiones: [
          VersionPlantilla(
            version: 1,
            titulo: tipo.etiqueta,
            cuerpo: switch (tipo) {
              TipoPlantilla.autorizacionDatos => _autorizacionBase.trim(),
              TipoPlantilla.consentimientoImagen => _imagenBase.trim(),
              TipoPlantilla.consentimientoInformado => _informadoBase.trim(),
              TipoPlantilla.politicaPrivacidad => _politicaBase.trim(),
              _ => cuerpoBaseClinico(tipo),
            },
          ),
        ],
      );

  /// Una plantilla nueva del médico para [tipo] (con [TipoPlantilla.varias]),
  /// con el texto base del tipo en borrador.
  static Plantilla nueva(
    TipoPlantilla tipo, {
    required String id,
    required String nombre,
  }) => Plantilla(
    tipo: tipo,
    id: id,
    nombre: nombre,
    propia: true,
    versiones: [
      VersionPlantilla(
        version: 1,
        titulo: tipo.etiqueta,
        cuerpo: cuerpoBaseClinico(tipo),
      ),
    ],
  );
}

/// Marcadores que se reemplazan al generar el documento.
const marcadoresPlantilla = {
  'responsable': 'Tu nombre (o el del consultorio, si lo escribiste)',
  'documentoResponsable': 'Tu tipo y número de documento',
  'direccion': 'Dirección del consultorio',
  'ciudad': 'Ciudad',
  'telefono': 'Teléfono',
  'correo': 'Correo para consultas y reclamos',
  'paciente': 'Nombre completo del paciente',
  'documentoPaciente': 'Tipo y número de documento del paciente',
  'fecha': 'Fecha del documento',
  'permisos':
      'Usos de la imagen que el paciente autoriza (consentimiento '
      'de imagen)',
  'registroMedico': 'Tu registro profesional',
  'procedimiento': 'Procedimiento (consentimiento informado)',
  'zonas': 'Zonas del plan de tratamiento',
  'sesiones': 'Número de sesiones del plan',
  'producto': 'Producto o solución, con su registro Invima',
  'riesgos': 'Riesgos (de la plantilla del procedimiento)',
  'alternativas': 'Alternativas (de la plantilla del procedimiento)',
  'certificacion': 'Tu certificación en la técnica',
  'codigoReps': 'Código de prestador en el REPS',
  'habilitacion': 'Habilitación del servicio',
  'poliza': 'Póliza de complicaciones',
  'edad': 'Edad del paciente («36 años»)',
  'medico': 'Tu nombre',
};

/// Reemplaza los `{{clave}}` de [cuerpo]. Un marcador sin valor queda como
/// «______» para completarlo a mano.
String rellenarPlantilla(String cuerpo, Map<String, String> valores) =>
    cuerpo.replaceAllMapped(RegExp(r'\{\{\s*(\w+)\s*\}\}'), (m) {
      final v = valores[m.group(1)]?.trim() ?? '';
      return v.isEmpty ? '______' : v;
    });

// Textos base. Siguen la Ley 1581 de 2012 y el Decreto 1377 de 2013
// (compilado en el Decreto 1074 de 2015). Son borradores para revisar con tu
// abogado antes de aprobarlos (VERIFICAR): la app no los deja usar sin
// aprobar.

const _autorizacionBase = '''
Yo, {{paciente}}, identificado(a) con {{documentoPaciente}}, autorizo de manera previa, expresa e informada a {{responsable}}, identificado(a) con {{documentoResponsable}}, con domicilio en {{direccion}}, {{ciudad}}, para recolectar, almacenar, usar y conservar mis datos personales, incluidos los datos sensibles relativos a mi salud, con las siguientes finalidades:

1. Prestarme la atención médica, elaborar y custodiar mi historia clínica y sus anexos, conforme a las normas que la regulan.
2. Programar citas, recordarlas y contactarme por teléfono, mensaje o correo para el seguimiento de mi atención.
3. Emitir recetas, órdenes, certificados, incapacidades, recibos y demás documentos derivados de la atención.
4. Cumplir las obligaciones legales del prestador y atender los requerimientos de las autoridades competentes.

Declaro que se me informó que:

a) Los datos de salud son datos sensibles y no estoy obligado(a) a autorizar su tratamiento; sin embargo, son necesarios para prestarme la atención médica y para llevar mi historia clínica.
b) Como titular tengo derecho a conocer, actualizar y rectificar mis datos; a solicitar prueba de esta autorización; a ser informado(a) del uso que se les da; a revocar la autorización o pedir la supresión de los datos cuando no exista un deber legal o contractual de conservarlos; a acceder gratuitamente a ellos, y a presentar quejas ante la Superintendencia de Industria y Comercio.
c) La historia clínica se conserva durante el tiempo que exige la ley, aun si revoco esta autorización.
d) Mis datos no se venden ni se ceden a terceros, salvo por obligación legal o con mi autorización.
e) Puedo ejercer mis derechos escribiendo a {{correo}} o llamando al {{telefono}}, y consultar la política de tratamiento de datos en el consultorio.

Fecha: {{fecha}}
''';

const _imagenBase = '''
Yo, {{paciente}}, identificado(a) con {{documentoPaciente}}, autorizo a {{responsable}}, identificado(a) con {{documentoResponsable}}, para tomar fotografías de mi cuerpo durante mi atención y para usarlas solo en los usos que marco a continuación:

{{permisos}}

Declaro que se me informó que:

a) El registro clínico es necesario para documentar mi evolución y los resultados de los procedimientos; las fotografías hacen parte de mi historia clínica y se guardan cifradas, con la misma reserva.
b) Para docencia o publicaciones académicas se usan sin mi rostro ni rasgos que me identifiquen.
c) Para publicidad o redes sociales solo se usan si lo marqué expresamente.
d) Puedo revocar en cualquier momento los usos de docencia y publicidad, escribiendo a {{correo}} o llamando al {{telefono}}. La revocación no afecta lo ya publicado de buena fe antes de ella, ni las fotografías que deben conservarse como parte de la historia clínica.
e) No recibo pago por estas autorizaciones y negarme a las de docencia o publicidad no cambia mi atención.

Fecha: {{fecha}}
''';

// Consentimiento informado por plan de tratamiento: sigue los apartados
// del art. 16 del Proyecto de Ley 187 de 2026 Senado (NO es ley) y el
// art. 15 de la Ley 23 de 1981. Borrador para revisar con tu abogado
// (VERIFICAR); la app no lo deja usar sin aprobarlo.
const _informadoBase = '''
Yo, {{paciente}}, identificado(a) con {{documentoPaciente}}, declaro que el médico {{responsable}}, {{registroMedico}}, me explicó de forma clara y suficiente lo siguiente, que pude hacer todas mis preguntas y que me las resolvió:

1. Procedimiento y plan de tratamiento: {{procedimiento}}, en {{zonas}}, en {{sesiones}} sesiones. Producto o solución: {{producto}}.

2. Quién lo hace y dónde: {{responsable}}, {{registroMedico}}. Certificación en la técnica: {{certificacion}}. Prestador inscrito en el REPS con el código {{codigoReps}}; habilitación del servicio: {{habilitacion}}.

3. Alcance realista: el resultado depende de cada persona y no se puede garantizar. El médico se obliga a poner todos los medios a su alcance (obligación de medio), no a lograr un resultado determinado.

4. Riesgos: {{riesgos}}

5. Alternativas: {{alternativas}}. También puedo no hacerme el procedimiento.

6. Si hay una complicación: debo comunicarme de inmediato al {{telefono}} o acudir al servicio de urgencias más cercano. Póliza de complicaciones: {{poliza}}.

7. Puedo revocar este consentimiento en cualquier momento antes de cada sesión, sin dar explicaciones. La revocación queda registrada y no afecta lo ya hecho.

8. Este consentimiento cubre el plan descrito. Si cambian la técnica, el producto o las zonas, firmaré uno nuevo.

Fecha: {{fecha}}
''';

const _politicaBase = '''
1. Responsable del tratamiento
{{responsable}}, identificado(a) con {{documentoResponsable}}. Dirección: {{direccion}}, {{ciudad}}. Teléfono: {{telefono}}. Correo: {{correo}}.

2. Datos que se tratan
Datos de identificación y contacto de los pacientes y de sus acompañantes, y datos sensibles relativos a la salud contenidos en la historia clínica y sus anexos (consentimientos, fotografías clínicas, resultados y documentos).

3. Finalidades
Prestar la atención médica; elaborar, custodiar y conservar la historia clínica; programar y recordar citas; emitir recetas, órdenes, certificados, incapacidades y recibos; hacer seguimiento a los tratamientos, y cumplir las obligaciones legales del prestador.

4. Tratamiento de datos sensibles
Los datos de salud se tratan solo con la autorización expresa del titular, salvo las excepciones de ley. El titular no está obligado a autorizar el tratamiento de datos sensibles. Los datos de menores de edad se tratan respetando su interés superior y con la autorización de su representante legal.

5. Derechos de los titulares
Conocer, actualizar y rectificar sus datos; solicitar prueba de la autorización; ser informados del uso que se da a sus datos; presentar quejas ante la Superintendencia de Industria y Comercio; revocar la autorización o solicitar la supresión de los datos cuando no exista un deber legal o contractual de conservarlos, y acceder gratuitamente a ellos.

6. Consultas y reclamos
El titular puede consultar sus datos o presentar reclamos escribiendo a {{correo}}, llamando al {{telefono}} o en el consultorio. Las consultas se responden en un plazo máximo de diez (10) días hábiles y los reclamos en un plazo máximo de quince (15) días hábiles, prorrogables en los términos de la ley.

7. Seguridad
La información se guarda cifrada en los equipos del consultorio, con acceso protegido por contraseña, y se respalda de forma periódica. No se envía a servidores de terceros.

8. Transferencia y transmisión
Los datos no se venden ni se ceden. Solo se entregan a terceros por obligación legal, por orden de autoridad competente o con la autorización del titular.

9. Conservación
La historia clínica se conserva durante el tiempo que exige la ley. Los demás datos se conservan mientras sean necesarios para las finalidades descritas.

10. Vigencia
Esta política rige desde el {{fecha}}.
''';
