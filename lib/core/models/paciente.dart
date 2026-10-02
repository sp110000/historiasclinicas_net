import 'mapa.dart';

class Paciente {
  const Paciente({
    this.primerApellido = '',
    this.segundoApellido = '',
    this.nombres = '',
    this.tipoDocumento = '',
    this.numeroDocumento = '',
    this.fechaNacimiento,
    this.edadAproximada,
    this.sexo,
    this.telefono = '',
    this.direccion = '',
    this.ciudad = '',
    this.estadoCivil = '',
    this.ocupacion = '',
    this.aseguradora = '',
    this.acompananteNombre = '',
    this.acompananteParentesco = '',
    this.acompananteTelefono = '',
  });

  factory Paciente.desdeMapa(Map<String, Object?> m) => Paciente(
    primerApellido: m.texto('primerApellido'),
    segundoApellido: m.texto('segundoApellido'),
    nombres: m.texto('nombres'),
    tipoDocumento: m.texto('tipoDocumento'),
    numeroDocumento: m.texto('numeroDocumento'),
    fechaNacimiento: m.fecha('fechaNacimiento'),
    edadAproximada: m.entero('edadAproximada'),
    sexo: m.textoONulo('sexo'),
    telefono: m.texto('telefono'),
    direccion: m.texto('direccion'),
    ciudad: m.texto('ciudad'),
    estadoCivil: m.texto('estadoCivil'),
    ocupacion: m.texto('ocupacion'),
    aseguradora: m.texto('aseguradora'),
    acompananteNombre: m.texto('acompananteNombre'),
    acompananteParentesco: m.texto('acompananteParentesco'),
    acompananteTelefono: m.texto('acompananteTelefono'),
  );

  final String primerApellido;
  final String segundoApellido;
  final String nombres;
  final String tipoDocumento;
  final String numeroDocumento;

  /// Fecha sin hora. Si se desconoce, se usa [edadAproximada] (años).
  final DateTime? fechaNacimiento;
  final int? edadAproximada;

  /// Código de `opcionesSexo` (F, M, I).
  final String? sexo;
  final String telefono;
  final String direccion;
  final String ciudad;
  final String estadoCivil;
  final String ocupacion;
  final String aseguradora;
  final String acompananteNombre;
  final String acompananteParentesco;
  final String acompananteTelefono;

  String get apellidos => [
    primerApellido.trim(),
    segundoApellido.trim(),
  ].where((s) => s.isNotEmpty).join(' ');

  /// "PEÑA MUÑOZ, José Ángel"
  String get nombreCompleto {
    final a = apellidos.toUpperCase();
    final n = nombres.trim();
    if (a.isEmpty) return n;
    return n.isEmpty ? a : '$a, $n';
  }

  bool get tieneComplementarios => [
    estadoCivil,
    ocupacion,
    aseguradora,
    acompananteNombre,
    acompananteParentesco,
    acompananteTelefono,
  ].any((s) => s.trim().isNotEmpty);

  Paciente copyWith({
    String? primerApellido,
    String? segundoApellido,
    String? nombres,
    String? tipoDocumento,
    String? numeroDocumento,
    Object? fechaNacimiento = sin,
    Object? edadAproximada = sin,
    Object? sexo = sin,
    String? telefono,
    String? direccion,
    String? ciudad,
    String? estadoCivil,
    String? ocupacion,
    String? aseguradora,
    String? acompananteNombre,
    String? acompananteParentesco,
    String? acompananteTelefono,
  }) => Paciente(
    primerApellido: primerApellido ?? this.primerApellido,
    segundoApellido: segundoApellido ?? this.segundoApellido,
    nombres: nombres ?? this.nombres,
    tipoDocumento: tipoDocumento ?? this.tipoDocumento,
    numeroDocumento: numeroDocumento ?? this.numeroDocumento,
    fechaNacimiento: cambio(fechaNacimiento, this.fechaNacimiento),
    edadAproximada: cambio(edadAproximada, this.edadAproximada),
    sexo: cambio(sexo, this.sexo),
    telefono: telefono ?? this.telefono,
    direccion: direccion ?? this.direccion,
    ciudad: ciudad ?? this.ciudad,
    estadoCivil: estadoCivil ?? this.estadoCivil,
    ocupacion: ocupacion ?? this.ocupacion,
    aseguradora: aseguradora ?? this.aseguradora,
    acompananteNombre: acompananteNombre ?? this.acompananteNombre,
    acompananteParentesco: acompananteParentesco ?? this.acompananteParentesco,
    acompananteTelefono: acompananteTelefono ?? this.acompananteTelefono,
  );

  Map<String, Object?> aMapa() => compacto({
    'primerApellido': primerApellido,
    'segundoApellido': segundoApellido,
    'nombres': nombres,
    'tipoDocumento': tipoDocumento,
    'numeroDocumento': numeroDocumento,
    'fechaNacimiento': fechaNacimiento == null
        ? null
        : fechaIso(fechaNacimiento!),
    'edadAproximada': edadAproximada,
    'sexo': sexo,
    'telefono': telefono,
    'direccion': direccion,
    'ciudad': ciudad,
    'estadoCivil': estadoCivil,
    'ocupacion': ocupacion,
    'aseguradora': aseguradora,
    'acompananteNombre': acompananteNombre,
    'acompananteParentesco': acompananteParentesco,
    'acompananteTelefono': acompananteTelefono,
  });
}
