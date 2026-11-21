import '../../clinica/edad.dart';
import '../../models/mapa.dart';
import '../../models/paciente.dart';

/// Líneas de atención del consultorio.
enum LineaAtencion {
  general('General'),
  peso('Programa de peso'),
  estetica('Estética');

  const LineaAtencion(this.etiqueta);

  final String etiqueta;
}

/// Ficha del paciente en el índice del consultorio.
///
/// Solo guarda datos administrativos (contacto, líneas, etiquetas). Los
/// datos clínicos (alergias, antecedentes, diagnósticos) se leen de las
/// historias selladas, con su fuente.
class FichaPaciente {
  const FichaPaciente({
    required this.id,
    required this.clave,
    required this.creado,
    required this.actualizado,
    this.tipoDocumento = '',
    this.numeroDocumento = '',
    this.primerApellido = '',
    this.segundoApellido = '',
    this.nombres = '',
    this.fechaNacimiento,
    this.edadAproximada,
    this.sexo,
    this.telefono = '',
    this.correo = '',
    this.direccion = '',
    this.ciudad = '',
    this.ocupacion = '',
    this.aseguradora = '',
    this.contactoEmergencia = '',
    this.lineas = const {},
    this.etiquetas = const [],
    this.notas = '',
    this.unidaEn,
    this.autorizacionDatosId,
  });

  static const coleccion = 'pacientes';

  final String id;

  /// `CC:1032456789`, o `SIN:<id>` si no tiene documento que lo identifique.
  final String clave;
  final String tipoDocumento;
  final String numeroDocumento;
  final String primerApellido;
  final String segundoApellido;
  final String nombres;
  final DateTime? fechaNacimiento;
  final int? edadAproximada;
  final String? sexo;
  final String telefono;
  final String correo;
  final String direccion;
  final String ciudad;
  final String ocupacion;
  final String aseguradora;
  final String contactoEmergencia;
  final Set<LineaAtencion> lineas;
  final List<String> etiquetas;

  /// Notas internas del médico (no van a ningún documento).
  final String notas;

  /// Si esta ficha se unió a otra: el id de la ficha que la reemplaza.
  final String? unidaEn;

  /// Autorización de tratamiento de datos vigente (documento firmado).
  final String? autorizacionDatosId;
  final DateTime creado;
  final DateTime actualizado;

  bool get activa => unidaEn == null;

  String get apellidos =>
      [primerApellido, segundoApellido].where((s) => s.isNotEmpty).join(' ');

  /// «PEÑA MUÑOZ, José Ángel»
  String get nombreCompleto {
    final a = apellidos.toUpperCase();
    if (a.isEmpty) return nombres.isEmpty ? 'Sin nombre' : nombres;
    return nombres.isEmpty ? a : '$a, $nombres';
  }

  /// «CC 1032456789»
  String get documentoTexto =>
      [tipoDocumento, numeroDocumento].where((s) => s.isNotEmpty).join(' ');

  int? edadAnios(DateTime ahora) {
    final f = fechaNacimiento;
    if (f == null) return edadAproximada;
    return calcularEdad(f, ahora)?.anios;
  }

  /// Menor de 18 años, o `null` si no se sabe la edad.
  bool? esMenorDeEdad(DateTime ahora) {
    final e = edadAnios(ahora);
    return e == null ? null : e < 18;
  }

  /// Ficha nueva a partir del paciente de una historia.
  factory FichaPaciente.desdePaciente(
    Paciente p, {
    required String id,
    required String clave,
    required DateTime ahora,
  }) => FichaPaciente(
    id: id,
    clave: clave,
    creado: ahora,
    actualizado: ahora,
    tipoDocumento: p.tipoDocumento,
    numeroDocumento: p.numeroDocumento,
    primerApellido: p.primerApellido,
    segundoApellido: p.segundoApellido,
    nombres: p.nombres,
    fechaNacimiento: p.fechaNacimiento,
    edadAproximada: p.edadAproximada,
    sexo: p.sexo,
    telefono: p.telefono,
    direccion: p.direccion,
    ciudad: p.ciudad,
    ocupacion: p.ocupacion,
    aseguradora: p.aseguradora,
  );

  /// Completa los datos vacíos con los de una historia más reciente, sin
  /// pisar lo que el médico ya editó en la ficha.
  FichaPaciente completadaCon(Paciente p, DateTime ahora) {
    String o(String actual, String nuevo) => actual.isEmpty ? nuevo : actual;
    return copyWith(
      primerApellido: o(primerApellido, p.primerApellido),
      segundoApellido: o(segundoApellido, p.segundoApellido),
      nombres: o(nombres, p.nombres),
      fechaNacimiento: fechaNacimiento ?? p.fechaNacimiento,
      edadAproximada: fechaNacimiento == null && p.fechaNacimiento == null
          ? edadAproximada ?? p.edadAproximada
          : edadAproximada,
      sexo: sexo ?? p.sexo,
      telefono: o(telefono, p.telefono),
      direccion: o(direccion, p.direccion),
      ciudad: o(ciudad, p.ciudad),
      ocupacion: o(ocupacion, p.ocupacion),
      aseguradora: o(aseguradora, p.aseguradora),
      actualizado: ahora,
    );
  }

  /// Paciente para prellenar una historia nueva.
  Paciente aPaciente() => Paciente(
    primerApellido: primerApellido,
    segundoApellido: segundoApellido,
    nombres: nombres,
    tipoDocumento: tipoDocumento,
    numeroDocumento: numeroDocumento,
    fechaNacimiento: fechaNacimiento,
    edadAproximada: fechaNacimiento == null ? edadAproximada : null,
    sexo: sexo,
    telefono: telefono,
    direccion: direccion,
    ciudad: ciudad,
    ocupacion: ocupacion,
    aseguradora: aseguradora,
  );

  FichaPaciente copyWith({
    String? clave,
    String? tipoDocumento,
    String? numeroDocumento,
    String? primerApellido,
    String? segundoApellido,
    String? nombres,
    Object? fechaNacimiento = sin,
    Object? edadAproximada = sin,
    Object? sexo = sin,
    String? telefono,
    String? correo,
    String? direccion,
    String? ciudad,
    String? ocupacion,
    String? aseguradora,
    String? contactoEmergencia,
    Set<LineaAtencion>? lineas,
    List<String>? etiquetas,
    String? notas,
    Object? unidaEn = sin,
    Object? autorizacionDatosId = sin,
    DateTime? actualizado,
  }) => FichaPaciente(
    id: id,
    clave: clave ?? this.clave,
    creado: creado,
    actualizado: actualizado ?? this.actualizado,
    tipoDocumento: tipoDocumento ?? this.tipoDocumento,
    numeroDocumento: numeroDocumento ?? this.numeroDocumento,
    primerApellido: primerApellido ?? this.primerApellido,
    segundoApellido: segundoApellido ?? this.segundoApellido,
    nombres: nombres ?? this.nombres,
    fechaNacimiento: cambio(fechaNacimiento, this.fechaNacimiento),
    edadAproximada: cambio(edadAproximada, this.edadAproximada),
    sexo: cambio(sexo, this.sexo),
    telefono: telefono ?? this.telefono,
    correo: correo ?? this.correo,
    direccion: direccion ?? this.direccion,
    ciudad: ciudad ?? this.ciudad,
    ocupacion: ocupacion ?? this.ocupacion,
    aseguradora: aseguradora ?? this.aseguradora,
    contactoEmergencia: contactoEmergencia ?? this.contactoEmergencia,
    lineas: lineas ?? this.lineas,
    etiquetas: etiquetas ?? this.etiquetas,
    notas: notas ?? this.notas,
    unidaEn: cambio(unidaEn, this.unidaEn),
    autorizacionDatosId: cambio(autorizacionDatosId, this.autorizacionDatosId),
  );

  Map<String, Object?> aMapa() => compacto({
    'clave': clave,
    'tipoDocumento': tipoDocumento,
    'numeroDocumento': numeroDocumento,
    'primerApellido': primerApellido,
    'segundoApellido': segundoApellido,
    'nombres': nombres,
    'fechaNacimiento': fechaNacimiento == null
        ? null
        : fechaIso(fechaNacimiento!),
    'edadAproximada': edadAproximada,
    'sexo': sexo,
    'telefono': telefono,
    'correo': correo,
    'direccion': direccion,
    'ciudad': ciudad,
    'ocupacion': ocupacion,
    'aseguradora': aseguradora,
    'contactoEmergencia': contactoEmergencia,
    'lineas': lineas.isEmpty ? null : [for (final l in lineas) l.name],
    'etiquetas': etiquetas.isEmpty ? null : etiquetas,
    'notas': notas,
    'unidaEn': unidaEn,
    'autorizacionDatosId': autorizacionDatosId,
    'creado': creado.toUtc().toIso8601String(),
    'actualizado': actualizado.toUtc().toIso8601String(),
  });

  static FichaPaciente desdeMapa(String id, Map<String, Object?> m) =>
      FichaPaciente(
        id: id,
        clave: m.texto('clave'),
        tipoDocumento: m.texto('tipoDocumento'),
        numeroDocumento: m.texto('numeroDocumento'),
        primerApellido: m.texto('primerApellido'),
        segundoApellido: m.texto('segundoApellido'),
        nombres: m.texto('nombres'),
        fechaNacimiento: m.fecha('fechaNacimiento'),
        edadAproximada: m.entero('edadAproximada'),
        sexo: m.textoONulo('sexo'),
        telefono: m.texto('telefono'),
        correo: m.texto('correo'),
        direccion: m.texto('direccion'),
        ciudad: m.texto('ciudad'),
        ocupacion: m.texto('ocupacion'),
        aseguradora: m.texto('aseguradora'),
        contactoEmergencia: m.texto('contactoEmergencia'),
        lineas: {
          for (final l in (m['lineas'] as List?) ?? const [])
            if (LineaAtencion.values.any((x) => x.name == l))
              LineaAtencion.values.byName(l as String),
        },
        etiquetas: [
          for (final e in (m['etiquetas'] as List?) ?? const []) e as String,
        ],
        notas: m.texto('notas'),
        unidaEn: m.textoONulo('unidaEn'),
        autorizacionDatosId: m.textoONulo('autorizacionDatosId'),
        creado: DateTime.parse(m['creado']! as String).toLocal(),
        actualizado: DateTime.parse(m['actualizado']! as String).toLocal(),
      );
}
