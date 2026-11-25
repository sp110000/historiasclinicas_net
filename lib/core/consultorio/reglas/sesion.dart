import '../../utils/fechas.dart';
import '../../utils/numeros.dart';
import '../documentos/documento.dart';
import '../modelos/ficha_paciente.dart';
import '../procedimientos/plantilla_procedimiento.dart';
import '../procedimientos/sesion.dart';
import '../procedimientos/valoracion.dart';
import 'estetica.dart';

/// Días que vale el peso para calcular la dosis (pregunta 32).
const diasVigenciaPeso = 30;

/// Desde qué fracción del máximo avisa la dosis (pregunta 32).
const avisoDosis = 0.8;

/// Lo que dicen las reglas de una sesión: si algo bloquea, el botón de
/// sellar dice por qué (el primero).
class EvaluacionSesion {
  const EvaluacionSesion({required this.bloqueos, required this.avisos});

  final List<String> bloqueos;
  final List<String> avisos;

  bool get permiteSellar => bloqueos.isEmpty;
}

/// Evalúa la sesión [s] (puras: sin almacén). [plantilla] es la de la
/// sesión; [valoracion], la última sellada del procedimiento;
/// [consentimientos], los del procedimiento (vigente o no), del más viejo
/// al más reciente; [anterior], la última sesión sellada del procedimiento;
/// [certificada], si hay certificación vigente en la familia.
EvaluacionSesion evaluarSesion({
  required Sesion s,
  required FichaPaciente ficha,
  required PlantillaProcedimiento plantilla,
  required Valoracion? valoracion,
  required List<DocumentoConsultorio> consentimientos,
  required Sesion? anterior,
  required bool certificada,
  required DateTime ahora,
}) {
  final bloqueos = <String>[];
  final avisos = <String>[];
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);

  // Plantilla.
  final version = plantilla.vigente;
  if (version == null) {
    return EvaluacionSesion(
      bloqueos: [
        'La plantilla «${plantilla.nombre}» no está aprobada: apruébala en '
            'Procedimientos.',
      ],
      avisos: const [],
    );
  }
  final d = version.definicion;

  // Edad (Ley 1799 de 2016, VERIFICAR).
  final edad = bloqueoPorEdad(ficha, ahora);
  if (edad != null) bloqueos.add(edad);

  // Valoración (pregunta 29).
  switch (estadoValoracion(valoracion, ahora)) {
    case EstadoValoracion.falta:
      bloqueos.add('Falta la valoración del procedimiento.');
    case EstadoValoracion.noApto:
      bloqueos.add(
        'La valoración fue «no apto»: hace falta una valoración nueva.',
      );
    case EstadoValoracion.diferir:
      bloqueos.add(
        'La valoración fue «diferir»: hace falta una valoración nueva.',
      );
    case EstadoValoracion.vencida:
      bloqueos.add(
        'La valoración venció el ${formatoFecha(valoracion!.vigenteHasta!)}: '
        'hace falta una nueva.',
      );
    case EstadoValoracion.vigente:
      break;
  }

  // Consentimiento por plan (pregunta 39).
  final vigente = consentimientos.where((c) => c.vigente).lastOrNull;
  if (vigente == null) {
    final ultimo = consentimientos.lastOrNull;
    bloqueos.add(
      ultimo != null && ultimo.estado == EstadoDocumento.revocado
          ? 'El consentimiento ${ultimo.numero} fue revocado el '
                '${formatoFecha(ultimo.cambioEstado!)}: hace falta uno nuevo.'
          : 'Falta el consentimiento firmado.',
    );
  } else {
    final plan = vigente.plan!;
    for (final z in s.zonas) {
      if (!plan.zonas.contains(z.zona)) {
        bloqueos.add(
          'La zona «${z.zona}» no está en el consentimiento '
          '${vigente.numero}: firma uno nuevo.',
        );
      }
    }
    if (s.numero > plan.sesiones) {
      bloqueos.add(
        'El consentimiento ${vigente.numero} cubre ${plan.sesiones} '
        '${plan.sesiones == 1 ? 'sesión' : 'sesiones'}: firma uno nuevo.',
      );
    }
    if (plan.version != version.version) {
      avisos.add(
        'El protocolo cambió desde el consentimiento (v${plan.version} → '
        'v${version.version}): si cambió la técnica o el producto, firma uno '
        'nuevo.',
      );
    }
  }

  // Lista de verificación previa (pregunta 33).
  final faltan = [
    for (final i in d.listaVerificacion)
      if (s.verificacion[i] != true) i,
  ];
  if (faltan.isNotEmpty) {
    bloqueos.add(
      'Falta marcar en la lista de verificación: «${faltan.first}»'
      '${faltan.length > 1 ? ' y ${faltan.length - 1} más' : ''}.',
    );
  }

  // Zonas y, si se infiltra una solución, sus volúmenes.
  if (s.zonas.isEmpty) bloqueos.add('Elige al menos una zona.');
  for (final z in d.usaSolucion ? s.zonas : const <ZonaSesion>[]) {
    if ((z.volumenMl ?? 0) <= 0) {
      bloqueos.add('Escribe el volumen de «${z.zona}».');
    } else if (d.volumenMaximoZonaMl != null &&
        z.volumenMl! > d.volumenMaximoZonaMl!) {
      bloqueos.add(
        '«${z.zona}» supera el volumen máximo por zona del protocolo '
        '(${formatoNumero(d.volumenMaximoZonaMl!)} mL).',
      );
    }
  }
  if (d.usaSolucion &&
      d.volumenMaximoSesionMl != null &&
      s.volumenTotalMl > d.volumenMaximoSesionMl!) {
    bloqueos.add(
      'El volumen total (${formatoNumero(s.volumenTotalMl)} mL) supera el '
      'máximo por sesión del protocolo '
      '(${formatoNumero(d.volumenMaximoSesionMl!)} mL).',
    );
  }

  // Anestésico y dosis (pregunta 32), si el procedimiento lo usa.
  final a = d.usaAnestesico ? s.anestesico : null;
  if (!d.usaAnestesico) {
    // Sin anestésico: no hay dosis que calcular.
  } else if (a == null || (a.volumenMl ?? 0) <= 0) {
    bloqueos.add('Escribe el anestésico y su volumen.');
  } else {
    final peso = s.pesoKg;
    final fechaPeso = s.fechaPeso;
    if (peso == null ||
        fechaPeso == null ||
        hoy.difference(fechaPeso).inDays > diasVigenciaPeso) {
      bloqueos.add(
        fechaPeso == null
            ? 'Pesa al paciente: la dosis se calcula en mg/kg.'
            : 'Pesa al paciente: la última medición es del '
                  '${formatoFecha(fechaPeso)} (más de $diasVigenciaPeso días).',
      );
    } else {
      final f = a.fraccion(peso)!;
      final mgKg = formatoNumero(a.mgKg(peso)!, decimales: 1);
      final maximo = formatoNumero(a.maximoMgKg);
      if (f > 1) {
        bloqueos.add(
          'Dosis por encima del máximo del protocolo: $mgKg mg/kg de '
          '${a.nombre} (máximo $maximo mg/kg).',
        );
      } else if (f >= avisoDosis) {
        avisos.add(
          'Dosis al ${(f * 100).round()} % del máximo: $mgKg mg/kg de '
          '${a.nombre} (máximo $maximo mg/kg).',
        );
      }
    }
  }

  // Lotes: escritos y sin vencer (el enlace con el inventario, en la 5.7).
  final lotes = [
    if (a != null) (a.nombre, a.lote),
    for (final c in s.componentes) (c.nombre, c.lote),
    for (final i in s.insumos) (i.nombre, i.lote),
  ];
  for (final (nombre, lote) in lotes) {
    if (!lote.completo) {
      bloqueos.add('Escribe el lote y el vencimiento de «$nombre».');
    } else if (lote.vencidoEn(hoy)) {
      bloqueos.add(
        'El lote ${lote.lote.trim()} de «$nombre» venció el '
        '${formatoFecha(lote.vence!)}.',
      );
    }
  }

  // Intervalo entre sesiones (aviso).
  if (anterior != null && d.intervaloDias != null) {
    final dias = hoy
        .difference(
          DateTime(
            anterior.fecha.year,
            anterior.fecha.month,
            anterior.fecha.day,
          ),
        )
        .inDays;
    if (dias < d.intervaloDias!) {
      avisos.add(
        'Han pasado $dias días desde la sesión anterior; el protocolo pide '
        '${d.intervaloDias}.',
      );
    }
  }

  // Certificación (pregunta 36: aviso registrado, no bloqueo).
  if (!certificada) {
    avisos.add('Sin certificación vigente para «${d.familia}».');
  }

  if (s.duracionMin == null || s.duracionMin! <= 0) {
    bloqueos.add('Escribe la duración.');
  }
  if (s.eventosAdversos.trim().isEmpty) {
    bloqueos.add('Escribe los eventos adversos («Ninguno» si no hubo).');
  }
  return EvaluacionSesion(bloqueos: bloqueos, avisos: avisos);
}
