import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/mapa.dart';
import '../../storage/preferencias.dart';

/// Configuración del prestador para el RDA: datos iguales para todas sus
/// atenciones (vía 2 de la matriz). No son secretos. Se capturan una vez
/// en «Datos del médico → Consultorio» (regla 10) o se aprovisionan con
/// [PrestadorIhceStore.guardar].
class PrestadorIhce {
  const PrestadorIhce({
    this.codigoHabilitacion = '',
    this.modalidad = '',
    this.entorno = '',
    this.cupsPrimeraVez = '',
    this.cupsControl = '',
    this.cupsInterconsulta = '',
  });

  factory PrestadorIhce.desdeMapa(Map<String, Object?> m) => PrestadorIhce(
    codigoHabilitacion: m.texto('codigoHabilitacion'),
    modalidad: m.texto('modalidad'),
    entorno: m.texto('entorno'),
    cupsPrimeraVez: m.texto('cupsPrimeraVez'),
    cupsControl: m.texto('cupsControl'),
    cupsInterconsulta: m.texto('cupsInterconsulta'),
  );

  /// Código de habilitación REPS: `id` y referencia de la IPS.
  final String codigoHabilitacion;

  /// Código `ColombianTechModality`.
  final String modalidad;

  /// Código `EntornoAtencion`.
  final String entorno;

  /// Códigos `CUPSConsultationCodes` según el tipo de consulta.
  final String cupsPrimeraVez;
  final String cupsControl;
  final String cupsInterconsulta;

  /// CUPS para el tipo de consulta local, o `''` si no está configurado.
  String cupsPara(String? tipoConsulta) => switch (tipoConsulta) {
    'primera_vez' => cupsPrimeraVez,
    'control' => cupsControl,
    'interconsulta' => cupsInterconsulta,
    _ => '',
  };

  PrestadorIhce copyWith({
    String? codigoHabilitacion,
    String? modalidad,
    String? entorno,
    String? cupsPrimeraVez,
    String? cupsControl,
    String? cupsInterconsulta,
  }) => PrestadorIhce(
    codigoHabilitacion: codigoHabilitacion ?? this.codigoHabilitacion,
    modalidad: modalidad ?? this.modalidad,
    entorno: entorno ?? this.entorno,
    cupsPrimeraVez: cupsPrimeraVez ?? this.cupsPrimeraVez,
    cupsControl: cupsControl ?? this.cupsControl,
    cupsInterconsulta: cupsInterconsulta ?? this.cupsInterconsulta,
  );

  Map<String, Object?> aMapa() => compacto({
    'codigoHabilitacion': codigoHabilitacion,
    'modalidad': modalidad,
    'entorno': entorno,
    'cupsPrimeraVez': cupsPrimeraVez,
    'cupsControl': cupsControl,
    'cupsInterconsulta': cupsInterconsulta,
  });
}

class PrestadorIhceStore {
  PrestadorIhceStore(this._prefs);

  final SharedPreferences _prefs;

  PrestadorIhce leer() {
    final texto = _prefs.getString(Claves.ihcePrestador);
    if (texto == null) return const PrestadorIhce();
    try {
      return PrestadorIhce.desdeMapa((jsonDecode(texto) as Map).cast());
    } on Object {
      return const PrestadorIhce();
    }
  }

  Future<void> guardar(PrestadorIhce p) => p.aMapa().isEmpty
      ? _prefs.remove(Claves.ihcePrestador)
      : _prefs.setString(Claves.ihcePrestador, jsonEncode(p.aMapa()));
}
