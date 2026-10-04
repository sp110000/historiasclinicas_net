import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../pais/perfil_pais.dart';
import 'mapa.dart';

/// Datos del médico que usa este navegador. Se configuran una vez y se
/// guardan solo en este navegador.
class Medico {
  const Medico({
    this.nombre = '',
    this.especialidad = '',
    this.registro = '',
    this.documento = '',
    this.consultorio = '',
    this.direccion = '',
    this.ciudad = '',
    this.telefono = '',
    this.correo = '',
    this.logo,
    this.firma,
    this.sello,
    this.tipoDocumento = '',
    this.primerApellido = '',
    this.segundoApellido = '',
    this.nombres = '',
    this.codigoRethus = '',
  });

  /// Lee el formato de almacenamiento local (imágenes en base64).
  factory Medico.desdeAlmacen(Map<String, Object?> m) {
    Uint8List? imagen(String clave) {
      final b64 = m.textoONulo(clave);
      return b64 == null ? null : base64Decode(b64);
    }

    return Medico(
      nombre: m.texto('nombre'),
      especialidad: m.texto('especialidad'),
      registro: m.texto('registro'),
      documento: m.texto('documento'),
      consultorio: m.texto('consultorio'),
      direccion: m.texto('direccion'),
      ciudad: m.texto('ciudad'),
      telefono: m.texto('telefono'),
      correo: m.texto('correo'),
      logo: imagen('logo'),
      firma: imagen('firma'),
      sello: imagen('sello'),
      tipoDocumento: m.texto('tipoDocumento'),
      primerApellido: m.texto('primerApellido'),
      segundoApellido: m.texto('segundoApellido'),
      nombres: m.texto('nombres'),
      codigoRethus: m.texto('codigoRethus'),
    );
  }

  final String nombre;
  final String especialidad;

  /// Registro profesional (CO) o número de colegiado (ES).
  final String registro;

  /// Documento de identidad del médico (opcional).
  final String documento;
  final String consultorio;
  final String direccion;
  final String ciudad;
  final String telefono;
  final String correo;

  /// Imágenes PNG (fondo transparente).
  final Uint8List? logo;
  final Uint8List? firma;
  final Uint8List? sello;

  // Identificación para el RDA (módulo IHCE): el perfil exige el tipo de
  // documento, los apellidos y nombres por separado y la profesión RETHUS.

  /// Código local de tipo de documento (como el del paciente).
  final String tipoDocumento;
  final String primerApellido;
  final String segundoApellido;
  final String nombres;

  /// Código `RETHUSqualification` de la profesión.
  final String codigoRethus;

  /// Con nombre y registro ya puede figurar en los documentos.
  bool get configurado =>
      nombre.trim().isNotEmpty && registro.trim().isNotEmpty;

  bool get vacio => aAlmacen().isEmpty;

  Medico copyWith({
    String? nombre,
    String? especialidad,
    String? registro,
    String? documento,
    String? consultorio,
    String? direccion,
    String? ciudad,
    String? telefono,
    String? correo,
    Object? logo = sin,
    Object? firma = sin,
    Object? sello = sin,
    String? tipoDocumento,
    String? primerApellido,
    String? segundoApellido,
    String? nombres,
    String? codigoRethus,
  }) => Medico(
    nombre: nombre ?? this.nombre,
    especialidad: especialidad ?? this.especialidad,
    registro: registro ?? this.registro,
    documento: documento ?? this.documento,
    consultorio: consultorio ?? this.consultorio,
    direccion: direccion ?? this.direccion,
    ciudad: ciudad ?? this.ciudad,
    telefono: telefono ?? this.telefono,
    correo: correo ?? this.correo,
    logo: cambio(logo, this.logo),
    firma: cambio(firma, this.firma),
    sello: cambio(sello, this.sello),
    tipoDocumento: tipoDocumento ?? this.tipoDocumento,
    primerApellido: primerApellido ?? this.primerApellido,
    segundoApellido: segundoApellido ?? this.segundoApellido,
    nombres: nombres ?? this.nombres,
    codigoRethus: codigoRethus ?? this.codigoRethus,
  );

  Map<String, Object?> aAlmacen() => compacto({
    'nombre': nombre,
    'especialidad': especialidad,
    'registro': registro,
    'documento': documento,
    'consultorio': consultorio,
    'direccion': direccion,
    'ciudad': ciudad,
    'telefono': telefono,
    'correo': correo,
    'logo': logo == null ? null : base64Encode(logo!),
    'firma': firma == null ? null : base64Encode(firma!),
    'sello': sello == null ? null : base64Encode(sello!),
    'tipoDocumento': tipoDocumento,
    'primerApellido': primerApellido,
    'segundoApellido': segundoApellido,
    'nombres': nombres,
    'codigoRethus': codigoRethus,
  });
}

/// SHA-256 (hex) de los bytes de una imagen: su identificador en `recursos`.
String hashImagen(Uint8List bytes) => sha256.convert(bytes).toString();

/// Copia del médico guardada en la historia (y en cada evolución). Las
/// imágenes se referencian por su SHA-256 en `datos.recursos`.
class Autor {
  const Autor({
    required this.nombre,
    this.especialidad = '',
    this.registro = '',
    this.etiquetaRegistro = 'Registro',
    this.documento = '',
    this.consultorio = '',
    this.direccion = '',
    this.ciudad = '',
    this.telefono = '',
    this.correo = '',
    this.logo,
    this.firma,
    this.sello,
  });

  factory Autor.desdeMapa(Map<String, Object?> m) => Autor(
    nombre: m.texto('nombre'),
    especialidad: m.texto('especialidad'),
    registro: m.texto('registro'),
    etiquetaRegistro: m.textoONulo('etiquetaRegistro') ?? 'Registro',
    documento: m.texto('documento'),
    consultorio: m.texto('consultorio'),
    direccion: m.texto('direccion'),
    ciudad: m.texto('ciudad'),
    telefono: m.texto('telefono'),
    correo: m.texto('correo'),
    logo: m.textoONulo('logo'),
    firma: m.textoONulo('firma'),
    sello: m.textoONulo('sello'),
  );

  final String nombre;
  final String especialidad;
  final String registro;

  /// "Registro profesional" o "N.º de colegiado", según el país.
  final String etiquetaRegistro;
  final String documento;
  final String consultorio;
  final String direccion;
  final String ciudad;
  final String telefono;
  final String correo;

  /// SHA-256 de las imágenes (claves de `recursos`).
  final String? logo;
  final String? firma;
  final String? sello;

  /// "Registro profesional 012345"
  String get lineaRegistro =>
      registro.trim().isEmpty ? '' : '$etiquetaRegistro ${registro.trim()}';

  /// Hashes de imágenes que usa este autor.
  Iterable<String> get imagenes => [?logo, ?firma, ?sello];

  Map<String, Object?> aMapa() => compacto({
    'nombre': nombre,
    'especialidad': especialidad,
    'registro': registro,
    'etiquetaRegistro': etiquetaRegistro,
    'documento': documento,
    'consultorio': consultorio,
    'direccion': direccion,
    'ciudad': ciudad,
    'telefono': telefono,
    'correo': correo,
    'logo': logo,
    'firma': firma,
    'sello': sello,
  });
}

/// Etiqueta del número profesional en cada país (VERIFICAR).
String etiquetaRegistro(Pais pais) => switch (pais) {
  Pais.colombia => 'Registro profesional',
  Pais.espana => 'N.º de colegiado',
};

/// Copia de [medico] para guardar en un documento, con sus imágenes en
/// `recursos` (SHA-256 → base64). Solo se incluyen las imágenes pedidas.
({Map<String, Object?> autor, Map<String, String> recursos}) instantaneaMedico(
  Medico medico, {
  required Pais pais,
  bool logo = true,
  bool firma = true,
  bool sello = true,
}) {
  final recursos = <String, String>{};
  String? registrar(Uint8List? bytes, bool incluir) {
    if (bytes == null || !incluir) return null;
    final h = hashImagen(bytes);
    recursos[h] = base64Encode(bytes);
    return h;
  }

  final autor = Autor(
    nombre: medico.nombre.trim(),
    especialidad: medico.especialidad.trim(),
    registro: medico.registro.trim(),
    etiquetaRegistro: etiquetaRegistro(pais),
    documento: medico.documento.trim(),
    consultorio: medico.consultorio.trim(),
    direccion: medico.direccion.trim(),
    ciudad: medico.ciudad.trim(),
    telefono: medico.telefono.trim(),
    correo: medico.correo.trim(),
    logo: registrar(medico.logo, logo),
    firma: registrar(medico.firma, firma),
    sello: registrar(medico.sello, sello),
  );
  return (autor: autor.aMapa(), recursos: recursos);
}
