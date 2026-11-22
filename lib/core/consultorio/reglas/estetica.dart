import '../../utils/numeros.dart';
import '../modelos/ficha_paciente.dart';
import '../procedimientos/plantilla_procedimiento.dart';
import '../procedimientos/valoracion.dart';

/// Edad en años cumplidos con la fecha de nacimiento, o `null`.
int? edadConFechaNacimiento(FichaPaciente f, DateTime ahora) {
  final n = f.fechaNacimiento;
  if (n == null) return null;
  var e = ahora.year - n.year;
  if (ahora.month < n.month || (ahora.month == n.month && ahora.day < n.day)) {
    e--;
  }
  return e;
}

/// Ley 1799 de 2016 (pregunta 28; VERIFICAR el alcance de la Sentencia
/// C-246 de 2017): un menor de 18 años no puede tener valoración estética,
/// sesiones ni citas de esos tipos. Sin fecha de nacimiento, se pide.
/// Devuelve el motivo del bloqueo, o `null`.
String? bloqueoPorEdad(FichaPaciente f, DateTime ahora) {
  final e = edadConFechaNacimiento(f, ahora);
  if (e == null) {
    return 'Falta la fecha de nacimiento: la valoración estética exige '
        'comprobar la mayoría de edad.';
  }
  if (e < 18) {
    return 'Paciente menor de 18 años: los procedimientos estéticos están '
        'prohibidos (Ley 1799 de 2016, VERIFICAR las excepciones).';
  }
  return null;
}

/// El resultado menos restrictivo que permiten las respuestas: un
/// «no apto» en «sí» da no apto; un «diferir» en «sí», diferir.
ResultadoValoracion resultadoMinimo(List<RespuestaValoracion> respuestas) {
  var r = ResultadoValoracion.apto;
  for (final x in respuestas) {
    if (x.si != true) continue;
    final e = switch (x.item.efecto) {
      EfectoItem.noApto => ResultadoValoracion.noApto,
      EfectoItem.diferir => ResultadoValoracion.diferir,
      EfectoItem.precaucion => ResultadoValoracion.apto,
    };
    if (e.rigor > r.rigor) r = e;
  }
  return r;
}

/// Avisos que no bloquean: IMC sobre el umbral, tamizaje positivo,
/// expectativas no realistas.
List<String> avisosValoracion(Valoracion v, DefinicionProcedimiento d) {
  final imc = v.imc;
  return [
    if (imc != null && d.imcMaximoAviso != null && imc > d.imcMaximoAviso!)
      'IMC ${formatoNumero(imc, decimales: 1)}: por encima de '
          '${formatoNumero(d.imcMaximoAviso!)} (tu criterio).',
    for (final t in v.tamizajes)
      if (t.positivo)
        'Tamizaje ${t.instrumento.nombre.split(' ').first} positivo: '
            'considera diferir y remitir a psicología o psiquiatría.',
    if (v.expectativasRealistas == false)
      'Expectativas no realistas: explícale el alcance.',
  ];
}

/// Lo que falta o no cuadra para sellar la valoración. Vacía: se puede.
List<String> problemasValoracion(Valoracion v) {
  final r = v.resultado;
  final minimo = resultadoMinimo(v.respuestas);
  return [
    if (v.zonas.isEmpty) 'Elige al menos una zona.',
    for (final z in v.zonas)
      if (z.pinzable && (z.pinzableCm ?? 0) <= 0)
        'Escribe cuántos cm de grasa pinzable hay en «${z.zona}».',
    if (v.expectativasRealistas == null)
      'Indica si las expectativas son '
          'realistas.',
    for (final x in v.respuestas)
      if (x.si == null) 'Responde «${x.item.texto}».',
    for (final x in v.respuestas)
      if (x.si == true &&
          x.item.efecto == EfectoItem.precaucion &&
          x.nota.trim().isEmpty)
        'Escribe una nota para «${x.item.texto}».',
    for (final t in v.tamizajes)
      if (!t.completo) 'Completa el tamizaje ${t.instrumento.nombre}.',
    if (r == null) 'Elige el resultado.',
    if (r != null && r.rigor < minimo.rigor)
      'Con las respuestas, el resultado no puede ser «${r.etiqueta}»: como '
          'mínimo es «${minimo.etiqueta}».',
    if (r != null && r != ResultadoValoracion.apto && v.motivo.trim().isEmpty)
      'Escribe el motivo de «${r.etiqueta}».',
  ];
}

/// Estado de la valoración de un procedimiento para la sesión.
enum EstadoValoracion { falta, vigente, vencida, noApto, diferir }

/// La valoración que manda para [plantillaId]: la última sellada.
Valoracion? ultimaValoracion(
  Iterable<Valoracion> valoraciones,
  String plantillaId,
) {
  final selladas = [
    for (final v in valoraciones)
      if (v.plantillaId == plantillaId && v.sellada) v,
  ]..sort((a, b) => a.fecha.compareTo(b.fecha));
  return selladas.lastOrNull;
}

EstadoValoracion estadoValoracion(Valoracion? v, DateTime ahora) {
  if (v == null) return EstadoValoracion.falta;
  return switch (v.resultado) {
    ResultadoValoracion.noApto => EstadoValoracion.noApto,
    ResultadoValoracion.diferir => EstadoValoracion.diferir,
    ResultadoValoracion.apto =>
      v.vigenteHasta != null &&
              !DateTime(
                ahora.year,
                ahora.month,
                ahora.day,
              ).isAfter(v.vigenteHasta!)
          ? EstadoValoracion.vigente
          : EstadoValoracion.vencida,
    null => EstadoValoracion.falta,
  };
}
