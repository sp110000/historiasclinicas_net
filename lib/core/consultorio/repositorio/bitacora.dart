import '../../utils/ids.dart';
import 'repositorio.dart';

/// Acciones que quedan en la bitácora. El resumen nunca lleva datos del
/// paciente: solo qué se hizo y cuándo.
enum AccionBitacora {
  crearFrase('Creó la frase de acceso'),
  desbloquear('Desbloqueó el consultorio'),
  recuperar('Recuperó el acceso con el código'),
  cambiarFrase('Cambió la frase de acceso'),
  regenerarCodigo('Generó un código de recuperación nuevo'),
  bloquear('Bloqueó el consultorio'),
  bloqueoAutomatico('Bloqueo por inactividad'),
  respaldar('Descargó un respaldo'),
  restaurar('Restauró un respaldo'),
  cambiarAjustes('Cambió los ajustes'),
  importarPdf('Importó historias en PDF'),
  unirFichas('Unió dos fichas de paciente'),
  aprobarPlantilla('Aprobó una plantilla'),
  firmarDocumento('Firmó un documento'),
  revocarDocumento('Registró la revocación de un documento'),
  anularDocumento('Anuló un documento'),
  borrarMedicion('Borró una medición'),
  borrarFoto('Borró una foto');

  const AccionBitacora(this.etiqueta);

  final String etiqueta;
}

class EntradaBitacora {
  const EntradaBitacora({
    required this.id,
    required this.fecha,
    required this.accion,
    this.resumen = '',
  });

  static const coleccion = 'bitacora';

  final String id;
  final DateTime fecha;
  final AccionBitacora accion;
  final String resumen;

  Map<String, Object?> aMapa() => {
    'fecha': fecha.toUtc().toIso8601String(),
    'accion': accion.name,
    if (resumen.isNotEmpty) 'resumen': resumen,
  };

  static EntradaBitacora desdeMapa(String id, Map<String, Object?> m) =>
      EntradaBitacora(
        id: id,
        fecha: DateTime.parse(m['fecha']! as String).toLocal(),
        accion: AccionBitacora.values.byName(m['accion']! as String),
        resumen: m['resumen'] as String? ?? '',
      );
}

/// Agrega una entrada. Solo se agregan: nunca se editan ni se borran.
Future<void> registrarEnBitacora(
  RepositorioConsultorio repositorio,
  AccionBitacora accion, {
  required DateTime fecha,
  String resumen = '',
}) {
  final entrada = EntradaBitacora(
    id: nuevoUuid(),
    fecha: fecha,
    accion: accion,
    resumen: resumen,
  );
  return repositorio.guardar(
    EntradaBitacora.coleccion,
    entrada.id,
    entrada.aMapa(),
  );
}

/// La bitácora, de la más reciente a la más antigua.
Future<List<EntradaBitacora>> leerBitacora(
  RepositorioConsultorio repositorio,
) async {
  final datos = await repositorio.leerColeccion(EntradaBitacora.coleccion);
  return [
    for (final e in datos.entries) EntradaBitacora.desdeMapa(e.key, e.value),
  ]..sort((a, b) => b.fecha.compareTo(a.fecha));
}
