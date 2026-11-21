/// Borrador de la historia y receta en curso cifrados (pregunta 6).
///
/// Con la bandera encendida, los providers de la historia y la receta usan
/// estas subclases en lugar de guardar en claro en `localStorage`:
///
/// * con el consultorio abierto, cada guardado va cifrado al almacén;
/// * con el consultorio bloqueado, queda solo en memoria hasta desbloquear;
/// * lo que hubiera en claro de antes se usa al iniciar y se borra con el
///   primer guardado (o al abrir el consultorio, que lo cifra).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/consultorio/repositorio/repositorio.dart';
import '../../../core/consultorio/servicio.dart';
import '../../../core/receta/receta.dart';
import '../../../core/storage/borrador_store.dart';
import '../../../core/storage/preferencias.dart';
import '../../../core/storage/receta_store.dart';
import '../../historia/estado/borrador_provider.dart';
import '../../historia/estado/historia_controller.dart';
import '../estado/consultorio_provider.dart';

const coleccionEnCurso = 'enCurso';
const _idBorrador = 'borrador';
const _idReceta = 'receta';

/// Lo que está en curso (borrador y receta), en memoria, con lo que falta
/// escribir o borrar en el almacén cifrado.
class EnCursoCifrado {
  EnCursoCifrado(this._servicio, this._prefs) {
    // Lo que quedó en claro de antes de encender la bandera.
    _borrador = BorradorStore(_prefs).leer();
    _receta = RecetaStore(_prefs).leer();
    _hayEnClaro =
        _prefs.containsKey(Claves.borrador) ||
        _prefs.containsKey(Claves.receta);
    // Si había algo en claro, se cifrará al abrir.
    if (_borrador != null) _sinEscribir.add(_idBorrador);
    if (_receta != null) _sinEscribir.add(_idReceta);
  }

  final ServicioConsultorio _servicio;
  final SharedPreferences _prefs;

  BorradorGuardado? _borrador;
  Receta? _receta;
  var _hayEnClaro = false;
  final _sinEscribir = <String>{};

  bool get _abierto => _servicio.boveda.desbloqueada;

  BorradorGuardado? get borrador => _borrador;
  Receta? get receta => _receta;

  Future<void> _quitarEnClaro() async {
    if (!_hayEnClaro) return;
    _hayEnClaro = false;
    await _prefs.remove(Claves.borrador);
    await _prefs.remove(Claves.receta);
  }

  Map<String, Object?>? _mapa(String id) => switch (id) {
    _idBorrador when _borrador != null => {
      'guardadoEn': _borrador!.guardadoEn.toIso8601String(),
      'contenido': _borrador!.contenido,
    },
    _idReceta when _receta != null => _receta!.aMapa(),
    _ => null,
  };

  /// Escribe (o borra, si ya no hay nada) [ids] en el almacén, si está
  /// abierto; si no, quedan pendientes.
  Future<void> _escribir(Set<String> ids) async {
    await _quitarEnClaro();
    _sinEscribir.addAll(ids);
    if (!_abierto) return;
    final pendientes = {..._sinEscribir};
    _sinEscribir.clear();
    try {
      await _servicio.repositorio.guardarVarios([
        for (final id in pendientes) Escritura(coleccionEnCurso, id, _mapa(id)),
      ]);
    } on Object catch (e) {
      // Bloqueado mientras se escribía: se intenta de nuevo al abrir.
      _sinEscribir.addAll(pendientes);
      debugPrint('Consultorio: el borrador quedó en memoria: $e');
    }
  }

  Future<DateTime> guardarBorrador(Map<String, Object?> contenido) async {
    final ahora = DateTime.now();
    _borrador = BorradorGuardado(ahora, contenido);
    await _escribir({_idBorrador});
    return ahora;
  }

  Future<void> guardarReceta(Receta r) async {
    _receta = r;
    await _escribir({_idReceta});
  }

  Future<void> borrarReceta() async {
    _receta = null;
    await _escribir({_idReceta});
  }

  /// Borra todo lo que está en curso: la historia y la receta.
  Future<void> borrarTodo() async {
    _borrador = null;
    _receta = null;
    await _escribir({_idBorrador, _idReceta});
  }

  /// Al abrir el consultorio: escribe lo pendiente y, si no había nada en
  /// memoria, trae lo guardado. Devuelve `true` si trajo un borrador.
  Future<bool> alAbrir() async {
    var trajo = false;
    try {
      if (_borrador == null && !_sinEscribir.contains(_idBorrador)) {
        final m = await _servicio.repositorio.leer(
          coleccionEnCurso,
          _idBorrador,
        );
        if (m != null) {
          _borrador = BorradorGuardado(
            DateTime.parse(m['guardadoEn']! as String),
            (m['contenido']! as Map).cast<String, Object?>(),
          );
          trajo = true;
        }
      }
      if (_receta == null && !_sinEscribir.contains(_idReceta)) {
        final m = await _servicio.repositorio.leer(coleccionEnCurso, _idReceta);
        if (m != null) _receta = Receta.desdeMapa(m);
      }
    } on Object catch (e) {
      debugPrint('Consultorio: no se leyó el borrador cifrado: $e');
    }
    await _escribir({});
    return trajo;
  }
}

final enCursoCifradoProvider = Provider<EnCursoCifrado>(
  (ref) => EnCursoCifrado(
    ref.read(servicioConsultorioProvider),
    ref.watch(preferenciasProvider),
  ),
);

/// [BorradorStore] que guarda en [EnCursoCifrado].
class BorradorStoreConsultorio extends BorradorStore {
  BorradorStoreConsultorio(super.prefs, this._enCurso);

  final EnCursoCifrado _enCurso;

  @override
  BorradorGuardado? leer() => _enCurso.borrador;

  @override
  Future<DateTime> guardar(Map<String, Object?> contenido) =>
      _enCurso.guardarBorrador(contenido);

  @override
  Future<void> borrar() => _enCurso.borrarTodo();
}

/// [RecetaStore] cuya receta en curso va a [EnCursoCifrado]. La numeración,
/// el título y «Mis medicamentos» siguen en este navegador: no tienen datos
/// de pacientes.
class RecetaStoreConsultorio extends RecetaStore {
  RecetaStoreConsultorio(super.prefs, this._enCurso);

  final EnCursoCifrado _enCurso;

  @override
  Receta? leer() => _enCurso.receta;

  @override
  Future<void> guardar(Receta receta) => _enCurso.guardarReceta(receta);

  @override
  Future<void> borrar() => _enCurso.borrarReceta();
}

/// Los almacenes de la historia y de la receta con la bandera encendida.
BorradorStore crearBorradorStoreConsultorio(Ref ref) =>
    BorradorStoreConsultorio(
      ref.watch(preferenciasProvider),
      ref.watch(enCursoCifradoProvider),
    );

RecetaStore crearRecetaStoreConsultorio(Ref ref) => RecetaStoreConsultorio(
  ref.watch(preferenciasProvider),
  ref.watch(enCursoCifradoProvider),
);

/// Al abrir el consultorio: cifra lo pendiente y, si la historia en curso
/// está vacía y había un borrador guardado, lo restaura.
Future<void> sincronizarEnCurso(Ref ref) async {
  final trajo = await ref.read(enCursoCifradoProvider).alAbrir();
  if (trajo && !ref.read(historiaProvider).hayCambiosSinGuardar) {
    // La historia vuelve a leer su borrador (y la receta, la suya).
    ref
      ..invalidate(historiaProvider)
      ..invalidate(borradorProvider);
  }
}
