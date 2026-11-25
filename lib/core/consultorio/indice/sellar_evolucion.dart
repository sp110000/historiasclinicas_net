import 'dart:typed_data';

import '../../integridad/cadena_hash.dart';
import '../../models/historia.dart';
import '../../models/mapa.dart';
import '../../models/medico.dart';
import '../../pais/perfil_pais.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../pdf/historia_pdf.dart';
import '../../utils/ids.dart';
import '../../utils/nombres_archivo.dart';
import '../modelos/registro_historia.dart';
import 'indice_pacientes.dart';

/// Versión nueva de una historia con una evolución sellada desde el
/// consultorio (valoración o sesión, preguntas 29 y 35).
class EvolucionSellada {
  const EvolucionSellada({
    required this.historiaId,
    required this.datos,
    required this.revision,
    required this.pdf,
    required this.nombreArchivo,
    required this.huella,
  });

  final String historiaId;
  final Map<String, Object?> datos;
  final int revision;

  /// El PDF de la versión nueva: es el registro legal y se descarga.
  final Uint8List pdf;
  final String nombreArchivo;

  /// SHA-256 encadenado de la evolución.
  final String huella;
}

/// Sella [texto] como evolución nueva en la historia más reciente de la
/// ficha, genera el PDF de la versión siguiente y la registra en el
/// índice. Lanza [StateError] si la ficha no tiene historia.
Future<EvolucionSellada> sellarEvolucionEnHistoria(
  IndicePacientes indice, {
  required String pacienteId,
  required String texto,
  required Medico medico,
  required Pais pais,
  required DateTime ahora,
  DateTime? proximoControl,
  FuentesPdf? fuentes,
}) async {
  final ultima = indice.ultimaHistoria(pacienteId);
  if (ultima == null) {
    throw StateError(
      'La ficha no tiene historia clínica: empieza una antes de sellar.',
    );
  }
  final datos = await indice.datosDe(ultima.id);
  if (datos == null) {
    throw StateError('No se encontró la historia en el consultorio.');
  }
  final copia = instantaneaMedico(medico, pais: pais, logo: false);
  final evolucion = Evolucion(
    id: nuevoUuid(),
    fechaHora: alMinuto(ahora),
    texto: texto.trim(),
    proximoControl: proximoControl,
    avisoIntegridad: ultima.integridadCorrecta
        ? null
        : 'Agregada sobre una historia con alteraciones detectadas: '
              '${ultima.integridadDescripcion.toLowerCase()}.',
  );
  final nuevos = sellarEvoluciones(datos, [
    {...evolucion.aMapa(), if (medico.configurado) 'autor': copia.autor},
  ], recursos: medico.configurado ? copia.recursos : const {});
  final revision = ultima.revision + 1;
  final pdf = await generarPdfHistoria(
    datos: nuevos,
    revision: revision,
    fuentes: fuentes,
    generadoEn: ahora,
  );
  final paciente = HistoriaClinica.desdeMapa(nuevos).paciente;
  final nombre = nombreArchivoHistoria(
    primerApellido: paciente.primerApellido,
    documento: paciente.numeroDocumento,
    revision: revision,
  );
  await indice.registrarHistoria(
    nuevos,
    revision: revision,
    origen: OrigenArchivo.generado,
    nombreArchivo: nombre,
    bytesPdf: pdf,
  );
  final huella =
      ((nuevos['evoluciones']! as List).last as Map)['hash']! as String;
  return EvolucionSellada(
    historiaId: ultima.id,
    datos: nuevos,
    revision: revision,
    pdf: pdf,
    nombreArchivo: nombre,
    huella: huella,
  );
}
