import '../../utils/fechas.dart';
import '../documentos/documento_clinico.dart';
import '../documentos/plantillas.dart';
import '../modelos/configuracion.dart';

/// Lo que dicen las reglas de un documento clínico. Los bloqueos impiden
/// emitirlo; los avisos no.
class EvaluacionDocumento {
  const EvaluacionDocumento({required this.bloqueos, required this.avisos});

  final List<String> bloqueos;
  final List<String> avisos;

  bool get permiteEmitir => bloqueos.isEmpty;
}

/// Evalúa el borrador [b] (pura). [plantilla] es la elegida; [medicoListo],
/// si tus datos de médico están completos.
///
/// La incapacidad sigue el Decreto 1427 de 2022 según resúmenes (VERIFICAR
/// contra el texto): pide el diagnóstico, los días y las fechas; **avisa**
/// (no bloquea) si faltan el NIT o el código del prestador, y solo avisa de
/// los límites de días y de retroactividad cuando los escribiste en Ajustes.
EvaluacionDocumento evaluarDocumento(
  BorradorDocumento b, {
  required Plantilla plantilla,
  required ConfiguracionConsultorio configuracion,
  required bool medicoListo,
  required DateTime ahora,
}) {
  final bloqueos = <String>[];
  final avisos = <String>[];
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);

  if (!plantilla.usable) {
    bloqueos.add(
      'La plantilla «${plantilla.nombre}» está en borrador: revísala y '
      'apruébala en Ajustes → Plantillas.',
    );
  }
  if (!medicoListo) {
    bloqueos.add(
      'Completa tus datos de médico (nombre y registro): el documento los '
      'lleva.',
    );
  }
  if (b.texto.trim().isEmpty) bloqueos.add('Escribe el texto del documento.');

  switch (b.tipo) {
    case TipoPlantilla.certificado:
      if (b.finalidad.trim().isEmpty) {
        bloqueos.add(
          'Escribe con qué destino se expide el certificado (Ley 23 de 1981, '
          'art. 51, VERIFICAR).',
        );
      }
      if (b.incluirDiagnostico && b.diagnostico.vacio) {
        bloqueos.add('Escribe el diagnóstico o no lo incluyas.');
      }
    case TipoPlantilla.incapacidad:
      if (b.diagnostico.descripcion.trim().isEmpty) {
        bloqueos.add('Escribe el diagnóstico de la incapacidad.');
      } else if (b.diagnostico.codigo.trim().isEmpty) {
        avisos.add('El diagnóstico no tiene código CIE-10.');
      }
      final dias = b.dias;
      if (dias == null || dias < 1) {
        bloqueos.add('Escribe los días de incapacidad (1 o más).');
      } else if (configuracion.maxDiasIncapacidad > 0 &&
          dias > configuracion.maxDiasIncapacidad) {
        avisos.add(
          'Son $dias días: más que el límite de '
          '${configuracion.maxDiasIncapacidad} que escribiste en Ajustes.',
        );
      }
      final desde = DateTime(b.desde.year, b.desde.month, b.desde.day);
      if (desde.isBefore(hoy)) {
        final atras = hoy.difference(desde).inDays;
        final limite = configuracion.maxDiasRetroactivos;
        avisos.add(
          limite > 0 && atras > limite
              ? 'Empieza hace $atras días: más que el límite de retroactividad '
                    'de $limite que escribiste en Ajustes.'
              : 'Empieza antes de hoy (${formatoFecha(desde)}): es '
                    'retroactiva.',
        );
      }
      if (configuracion.nit.trim().isEmpty) {
        avisos.add('Falta tu NIT (Ajustes → Prestador).');
      }
      if (configuracion.codigoReps.trim().isEmpty) {
        avisos.add(
          'Falta tu código de prestador del REPS (Ajustes → Prestador).',
        );
      }
    case TipoPlantilla.orden:
      if (b.diagnostico.descripcion.trim().isEmpty) {
        avisos.add('Sin impresión diagnóstica.');
      }
    case TipoPlantilla.remision:
      if (b.destino.trim().isEmpty) {
        bloqueos.add('Escribe la especialidad o el servicio.');
      }
      if (b.diagnostico.descripcion.trim().isEmpty) {
        avisos.add('Sin diagnóstico.');
      }
    default:
      bloqueos.add('«${b.tipo.etiqueta}» no es un documento clínico.');
  }

  if (b.texto.contains('______')) {
    avisos.add('Quedan espacios «______» sin completar en el texto.');
  }
  return EvaluacionDocumento(bloqueos: bloqueos, avisos: avisos);
}
