import '../modelo/dto.dart';
import '../perfiles/perfiles_rda.g.dart';
import '../terminologia/catalogo_terminologia.dart';
import '../terminologia/equivalencias.dart';

enum NivelIdentidad { ok, advertencia, bloqueo }

class HallazgoIdentidad {
  const HallazgoIdentidad(this.nivel, this.campo, this.mensaje);

  final NivelIdentidad nivel;

  /// Elemento de dato (sin el valor: nunca se registran nombres ni
  /// documentos).
  final String campo;
  final String mensaje;

  @override
  String toString() => '${nivel.name}: $campo — $mensaje';
}

class ResultadoIdentidad {
  const ResultadoIdentidad(
    this.hallazgos, {
    this.caso = CasoIdentidad.nacional,
  });

  final List<HallazgoIdentidad> hallazgos;
  final CasoIdentidad caso;

  NivelIdentidad get nivel =>
      hallazgos.any((h) => h.nivel == NivelIdentidad.bloqueo)
      ? NivelIdentidad.bloqueo
      : hallazgos.any((h) => h.nivel == NivelIdentidad.advertencia)
      ? NivelIdentidad.advertencia
      : NivelIdentidad.ok;
}

/// Manual de Operaciones §5.4.4: el paciente nacional se valida contra el
/// registro nacional (EVOL / Maestro Persona); el extranjero y el que no
/// tiene identificación, no.
enum CasoIdentidad { nacional, extranjero, sinIdentificacion }

/// Validador puro, dirigido por tablas, de la identidad del paciente
/// (Fase 4.3). La plataforma exige que coincidan tipo y número de documento,
/// primer apellido, primer nombre y sexo biológico; las diferencias en
/// segundo apellido o fecha de nacimiento solo generan advertencia.
///
/// ADRES/BDUA no valida identidad: es la fuente de los códigos de EAPB.
class ValidadorIdentidad {
  const ValidadorIdentidad(this._catalogo);

  final CatalogoTerminologia _catalogo;

  /// Juego de caracteres del número. Sin fuente oficial de longitudes por
  /// tipo de documento, solo se valida que no esté vacío y su juego de
  /// caracteres (TODO(IHCE-VERIFICAR): longitudes del Maestro Persona).
  static final _caracteresNumero = RegExp(r'^[A-Za-z0-9]+$');

  ResultadoIdentidad validar(PacienteDto p) {
    final h = <HallazgoIdentidad>[];
    void bloqueo(String c, String m) =>
        h.add(HallazgoIdentidad(NivelIdentidad.bloqueo, c, m));
    void advertencia(String c, String m) =>
        h.add(HallazgoIdentidad(NivelIdentidad.advertencia, c, m));

    // 1. Tipo de documento: tabla de equivalencias local → ValueSet vigente.
    final tipo = tipoDocumentoAColombianPersonIdentifier[p.tipoDocumento];
    if (p.tipoDocumento.isEmpty) {
      bloqueo('tipoDocumento', 'Falta el tipo de documento');
    } else if (tipo == null ||
        !_catalogo.enValueSet(
          ConjuntoRda.colombianPersonIdentifierCodes,
          sistemaTipoDocumento,
          tipo,
        )) {
      bloqueo(
        'tipoDocumento',
        'El tipo de documento no pertenece a ColombianPersonIdentifierCodes',
      );
    }

    // 2. Número: sin espacios ni separadores, juego de caracteres.
    if (p.numeroDocumento.isEmpty) {
      bloqueo('numeroDocumento', 'Falta el número de documento');
    } else if (!_caracteresNumero.hasMatch(p.numeroDocumento)) {
      bloqueo(
        'numeroDocumento',
        'El número de documento solo admite letras y dígitos, sin separadores',
      );
    }

    final caso = documentosSinIdentificacion.contains(tipo)
        ? CasoIdentidad.sinIdentificacion
        : documentosExtranjero.contains(tipo)
        ? CasoIdentidad.extranjero
        : CasoIdentidad.nacional;

    // 4. Campos que el servidor exige coincidir.
    if (p.primerApellido.isEmpty) {
      bloqueo('primerApellido', 'Falta el primer apellido');
    }
    if (p.primerNombre.isEmpty) {
      bloqueo('primerNombre', 'Falta el primer nombre');
    }
    if (p.sexo == null || !sexoAGenero.containsKey(p.sexo)) {
      bloqueo('sexo', 'Falta el sexo biológico');
    }
    if (p.segundoApellido.isEmpty && caso == CasoIdentidad.nacional) {
      advertencia('segundoApellido', 'Sin segundo apellido');
    }
    if (p.fechaNacimiento == null) {
      // Para la identidad es advertencia; el perfil exige `birthDate` y el
      // mapper bloquea el RDA por su lado.
      advertencia('fechaNacimiento', 'Sin fecha de nacimiento');
    }
    return ResultadoIdentidad(h, caso: caso);
  }
}
