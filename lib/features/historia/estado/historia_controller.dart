import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/integridad/cadena_hash.dart';
import '../../../core/models/historia.dart';
import '../../../core/models/mapa.dart';
import '../../../core/pais/pais_provider.dart';
import '../../../core/pais/perfil_pais.dart';
import '../../../core/utils/ids.dart';
import 'borrador_provider.dart';
import 'estado_historia.dart';

final historiaProvider = NotifierProvider<HistoriaController, EstadoHistoria>(
  HistoriaController.new,
);

/// Datos listos para escribir en el PDF.
class DatosParaGuardar {
  const DatosParaGuardar(this.datos, this.revision);

  final Map<String, Object?> datos;
  final int revision;
}

class HistoriaController extends Notifier<EstadoHistoria> {
  @override
  EstadoHistoria build() {
    var inicial = EstadoHistoria.nueva(ref.read(paisProvider));
    final store = ref.read(borradorStoreProvider);
    final borrador = store.desactivado ? null : store.leer();
    if (borrador != null) {
      try {
        inicial = EstadoHistoria.desdeBorrador(
          borrador.contenido,
          guardadoEn: borrador.guardadoEn,
        );
      } on Object {
        // Borrador ilegible (versión anterior o dañado): se empieza de cero.
      }
    }
    listenSelf((anterior, siguiente) {
      if (anterior != null) {
        ref.read(borradorProvider.notifier).programar(siguiente);
      }
    });
    return inicial;
  }

  /// Edita la historia nueva. No hace nada si la historia está abierta
  /// (bloqueada).
  void actualizar(HistoriaClinica Function(HistoriaClinica h) cambio) {
    if (state.abierta) return;
    state = state.copyWith(historia: cambio(state.historia));
  }

  /// Empieza una historia en blanco.
  void limpiar() {
    state = EstadoHistoria.nueva(
      ref.read(paisProvider),
      versionFormulario: state.versionFormulario + 1,
    );
  }

  /// Oculta el aviso de "borrador recuperado".
  void aceptarBorradorRestaurado() =>
      state = state.copyWith(borradorRestauradoEn: null);

  /// Aplica el país a una historia nueva (documento por defecto incluido).
  void cambiarPais(Pais pais) {
    if (state.abierta || state.historia.pais == pais) return;
    final h = state.historia;
    final validos = pais.perfil.tiposDocumento.map((o) => o.codigo);
    final documento = validos.contains(h.paciente.tipoDocumento)
        ? h.paciente.tipoDocumento
        : validos.first;
    state = EstadoHistoria(
      modo: ModoHistoria.nueva,
      historia: h.copyWith(
        pais: pais,
        paciente: h.paciente.copyWith(tipoDocumento: documento),
      ),
      versionFormulario: state.versionFormulario + 1,
    );
  }

  /// Carga una historia leída de un PDF. Lanza [FormatException] si los
  /// datos no son una historia clínica.
  void abrir(
    Map<String, Object?> datos, {
    required int revision,
    String? nombreArchivo,
  }) {
    state = EstadoHistoria.abierta(
      datos: datos,
      revision: revision,
      nombreArchivo: nombreArchivo,
      versionFormulario: state.versionFormulario + 1,
    );
  }

  /// Datos sellados para el próximo guardado: la historia inicial (si es
  /// nueva) o las evoluciones nuevas encadenadas al final.
  DatosParaGuardar prepararGuardado({DateTime? ahora}) {
    if (!state.abierta) {
      final base = {
        ...state.historia.aMapa(),
        'finalizadaEn': fechaHoraIso(ahora ?? DateTime.now()),
      };
      return DatosParaGuardar(sellarBase(base), 1);
    }
    return DatosParaGuardar(
      sellarEvoluciones(state.datosSellados!, [
        for (final e in state.evolucionesNuevas) e.aMapa(),
      ]),
      state.revision + 1,
    );
  }

  /// Registra que [datos] se guardaron en [nombreArchivo]: la historia queda
  /// abierta, con todo lo anterior sellado.
  void guardado(DatosParaGuardar guardado, {required String nombreArchivo}) {
    state = EstadoHistoria.abierta(
      datos: guardado.datos,
      revision: guardado.revision,
      nombreArchivo: nombreArchivo,
      versionFormulario: state.versionFormulario + 1,
    );
  }

  // ── Evoluciones (solo en historias abiertas) ──

  void agregarEvolucion({DateTime? ahora}) {
    if (!state.abierta) return;
    final integridad = state.integridad;
    final nueva = Evolucion(
      id: nuevoUuid(),
      fechaHora: alMinuto(ahora ?? DateTime.now()),
      avisoIntegridad: integridad != null && !integridad.correcta
          ? 'Agregada sobre una historia con alteraciones detectadas: '
                '${integridad.descripcion.toLowerCase()}.'
          : null,
    );
    state = state.copyWith(
      evolucionesNuevas: [...state.evolucionesNuevas, nueva],
    );
  }

  void actualizarEvolucion(int indice, Evolucion evolucion) {
    final lista = [...state.evolucionesNuevas];
    lista[indice] = evolucion;
    state = state.copyWith(evolucionesNuevas: lista);
  }

  void descartarEvolucion(int indice) {
    final lista = [...state.evolucionesNuevas]..removeAt(indice);
    state = state.copyWith(evolucionesNuevas: lista);
  }
}
