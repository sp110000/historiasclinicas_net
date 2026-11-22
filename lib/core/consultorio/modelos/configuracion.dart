import '../../models/mapa.dart';

/// Ajustes del consultorio que se guardan cifrados en el almacén.
class ConfiguracionConsultorio {
  const ConfiguracionConsultorio({
    this.minutosBloqueo = minutosBloqueoPorDefecto,
    this.diasRespaldo = diasRespaldoPorDefecto,
    this.codigoReps = '',
    this.nit = '',
    this.habilitacion = '',
    this.polizaAseguradora = '',
    this.polizaNumero = '',
    this.sinPoliza = false,
    this.maxDiasIncapacidad = 0,
    this.maxDiasRetroactivos = 0,
  });

  static const coleccion = 'configuracion';
  static const id = 'consultorio';

  static const minutosBloqueoPorDefecto = 10;
  static const minutosBloqueoMinimo = 2;
  static const minutosBloqueoMaximo = 60;

  static const diasRespaldoPorDefecto = 7;
  static const diasRespaldoMinimo = 1;
  static const diasRespaldoMaximo = 60;

  /// Minutos sin actividad antes de bloquear.
  final int minutosBloqueo;

  /// Días sin respaldo antes de avisar.
  final int diasRespaldo;

  /// Datos del prestador (Resolución 3100 de 2019, VERIFICAR): los usan el
  /// consentimiento informado y, en la 5.4, la incapacidad.
  final String codigoReps;
  final String nit;

  /// Habilitación del servicio (p. ej. número y servicio habilitado).
  final String habilitacion;

  /// Póliza de complicaciones (pregunta 34, VERIFICAR): se copia al
  /// consentimiento y a la sesión.
  final String polizaAseguradora;
  final String polizaNumero;
  final bool sinPoliza;

  /// Límites de la incapacidad (Decreto 1427 de 2022, VERIFICAR): 0 es «sin
  /// escribir» y no avisa. Los escribes tú cuando los verifiques.
  final int maxDiasIncapacidad;
  final int maxDiasRetroactivos;

  /// «Póliza N.º 123 de Aseguradora», «Sin póliza de complicaciones» o
  /// vacío si no se ha escrito.
  String get textoPoliza {
    if (sinPoliza) return 'sin póliza de complicaciones';
    final n = polizaNumero.trim();
    final a = polizaAseguradora.trim();
    if (n.isEmpty && a.isEmpty) return '';
    return [
      'póliza',
      if (n.isNotEmpty) 'N.º $n',
      if (a.isNotEmpty) 'de $a',
    ].join(' ');
  }

  ConfiguracionConsultorio copyWith({
    int? minutosBloqueo,
    int? diasRespaldo,
    String? codigoReps,
    String? nit,
    String? habilitacion,
    String? polizaAseguradora,
    String? polizaNumero,
    bool? sinPoliza,
    int? maxDiasIncapacidad,
    int? maxDiasRetroactivos,
  }) => ConfiguracionConsultorio(
    minutosBloqueo: (minutosBloqueo ?? this.minutosBloqueo).clamp(
      minutosBloqueoMinimo,
      minutosBloqueoMaximo,
    ),
    diasRespaldo: (diasRespaldo ?? this.diasRespaldo).clamp(
      diasRespaldoMinimo,
      diasRespaldoMaximo,
    ),
    codigoReps: codigoReps ?? this.codigoReps,
    nit: nit ?? this.nit,
    habilitacion: habilitacion ?? this.habilitacion,
    polizaAseguradora: polizaAseguradora ?? this.polizaAseguradora,
    polizaNumero: polizaNumero ?? this.polizaNumero,
    sinPoliza: sinPoliza ?? this.sinPoliza,
    maxDiasIncapacidad: (maxDiasIncapacidad ?? this.maxDiasIncapacidad).clamp(
      0,
      999,
    ),
    maxDiasRetroactivos: (maxDiasRetroactivos ?? this.maxDiasRetroactivos)
        .clamp(0, 999),
  );

  Map<String, Object?> aMapa() => compacto({
    'minutosBloqueo': minutosBloqueo,
    'diasRespaldo': diasRespaldo,
    'codigoReps': codigoReps.trim(),
    'nit': nit.trim(),
    'habilitacion': habilitacion.trim(),
    'polizaAseguradora': polizaAseguradora.trim(),
    'polizaNumero': polizaNumero.trim(),
    'sinPoliza': sinPoliza ? true : null,
    'maxDiasIncapacidad': maxDiasIncapacidad > 0 ? maxDiasIncapacidad : null,
    'maxDiasRetroactivos': maxDiasRetroactivos > 0 ? maxDiasRetroactivos : null,
  });

  static ConfiguracionConsultorio desdeMapa(Map<String, Object?> m) =>
      const ConfiguracionConsultorio().copyWith(
        minutosBloqueo: m['minutosBloqueo'] as int?,
        diasRespaldo: m['diasRespaldo'] as int?,
        codigoReps: m.texto('codigoReps'),
        nit: m.texto('nit'),
        habilitacion: m.texto('habilitacion'),
        polizaAseguradora: m.texto('polizaAseguradora'),
        polizaNumero: m.texto('polizaNumero'),
        sinPoliza: m.booleano('sinPoliza'),
        maxDiasIncapacidad: m.entero('maxDiasIncapacidad'),
        maxDiasRetroactivos: m.entero('maxDiasRetroactivos'),
      );
}
