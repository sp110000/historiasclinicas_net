/// Ajustes del consultorio que se guardan cifrados en el almacén.
class ConfiguracionConsultorio {
  const ConfiguracionConsultorio({
    this.minutosBloqueo = minutosBloqueoPorDefecto,
    this.diasRespaldo = diasRespaldoPorDefecto,
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

  ConfiguracionConsultorio copyWith({int? minutosBloqueo, int? diasRespaldo}) =>
      ConfiguracionConsultorio(
        minutosBloqueo: (minutosBloqueo ?? this.minutosBloqueo).clamp(
          minutosBloqueoMinimo,
          minutosBloqueoMaximo,
        ),
        diasRespaldo: (diasRespaldo ?? this.diasRespaldo).clamp(
          diasRespaldoMinimo,
          diasRespaldoMaximo,
        ),
      );

  Map<String, Object?> aMapa() => {
    'minutosBloqueo': minutosBloqueo,
    'diasRespaldo': diasRespaldo,
  };

  static ConfiguracionConsultorio desdeMapa(Map<String, Object?> m) =>
      const ConfiguracionConsultorio().copyWith(
        minutosBloqueo: m['minutosBloqueo'] as int?,
        diasRespaldo: m['diasRespaldo'] as int?,
      );
}
