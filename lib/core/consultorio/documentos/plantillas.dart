import '../../models/mapa.dart';

/// Tipos de plantilla de documento. Las subfases siguientes agregan
/// consentimientos, certificados, incapacidades, órdenes y remisiones.
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
  politicaPrivacidad(
    'Política de tratamiento de datos personales',
    null,
    'Politica_datos',
  );

  const TipoPlantilla(this.etiqueta, this.prefijo, this.baseArchivo);

  final String etiqueta;

  /// Comienzo del nombre de sus PDF, solo ASCII.
  final String baseArchivo;

  /// Se firma con el paciente (en pantalla).
  bool get conFirmaDelPaciente => prefijo != null;

  /// Prefijo del consecutivo de los documentos firmados con ella, o `null`
  /// si no lleva número (la política es una sola, con versión).
  final String? prefijo;
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
class Plantilla {
  const Plantilla({required this.tipo, required this.versiones});

  static const coleccion = 'plantillas';

  final TipoPlantilla tipo;
  final List<VersionPlantilla> versiones;

  String get id => tipo.name;

  /// La última aprobada: la que usan los documentos nuevos. `null` mientras
  /// ninguna versión esté aprobada (no se puede usar).
  VersionPlantilla? get vigente =>
      versiones.where((v) => v.aprobada).lastOrNull;

  /// La última, si todavía no está aprobada.
  VersionPlantilla? get borrador =>
      versiones.isNotEmpty && !versiones.last.aprobada ? versiones.last : null;

  VersionPlantilla get ultima => versiones.last;

  bool get usable => vigente != null;

  /// Guarda el texto: reemplaza el borrador, o crea la versión siguiente si
  /// la última ya está aprobada.
  Plantilla conBorrador(String titulo, String cuerpo) {
    final b = borrador;
    final nueva = VersionPlantilla(
      version: b?.version ?? ultima.version + 1,
      titulo: titulo,
      cuerpo: cuerpo,
    );
    return Plantilla(
      tipo: tipo,
      versiones: [
        ...b == null ? versiones : versiones.sublist(0, versiones.length - 1),
        nueva,
      ],
    );
  }

  /// Aprueba el borrador. Lanza [StateError] si no hay borrador.
  Plantilla aprobada(DateTime ahora) {
    final b = borrador;
    if (b == null) throw StateError('No hay un borrador para aprobar.');
    return Plantilla(
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
    'versiones': [for (final v in versiones) v.aMapa()],
  };

  static Plantilla desdeMapa(String id, Map<String, Object?> m) => Plantilla(
    tipo: TipoPlantilla.values.byName(id),
    versiones: [
      for (final v in m.listaMapas('versiones')) VersionPlantilla.desdeMapa(v),
    ],
  );

  /// La plantilla de fábrica: versión 1 en borrador.
  static Plantilla base(TipoPlantilla tipo) => Plantilla(
    tipo: tipo,
    versiones: [
      VersionPlantilla(
        version: 1,
        titulo: tipo.etiqueta,
        cuerpo: switch (tipo) {
          TipoPlantilla.autorizacionDatos => _autorizacionBase.trim(),
          TipoPlantilla.consentimientoImagen => _imagenBase.trim(),
          TipoPlantilla.politicaPrivacidad => _politicaBase.trim(),
        },
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
