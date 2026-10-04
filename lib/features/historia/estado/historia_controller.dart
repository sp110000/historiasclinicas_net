import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/integridad/cadena_hash.dart';
import '../../../core/models/historia.dart';
import '../../../core/models/mapa.dart';
import '../../../core/models/medico.dart';
import '../../../core/pais/pais_provider.dart';
import '../../../core/pais/perfil_pais.dart';
import '../../../core/utils/ids.dart';
import '../../ihce/ihce_provider.dart';
import '../../medico/medico_provider.dart';
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
    // RDA (módulo IHCE): al iniciar la app se procesa la cola pendiente.
    // Con el módulo deshabilitado no hay servicio y no pasa nada.
    unawaited(ref.read(servicioIhceProvider)?.procesarPendientes());
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

  /// Historia inicial con la copia del médico y sus imágenes, sin sellar.
  /// Sirve para finalizar y para la vista previa del borrador.
  Map<String, Object?> datosConMedico(Medico medico, {DateTime? finalizadaEn}) {
    final h = state.historia;
    final copia = instantaneaMedico(
      medico,
      pais: h.pais,
      firma: h.firma.incluirFirma,
      sello: h.firma.incluirSello,
    );
    return {
      ...h.aMapa(),
      if (finalizadaEn != null) 'finalizadaEn': fechaHoraIso(finalizadaEn),
      if (medico.configurado) 'medico': copia.autor,
      if (medico.configurado && copia.recursos.isNotEmpty)
        'recursos': copia.recursos,
    };
  }

  /// Datos sellados para el próximo guardado: la historia inicial (si es
  /// nueva) o las evoluciones nuevas encadenadas al final. Cada parte lleva
  /// una copia de [medico] (su autor) con sus imágenes en `recursos`.
  DatosParaGuardar prepararGuardado({
    Medico medico = const Medico(),
    DateTime? ahora,
  }) {
    if (!state.abierta) {
      return DatosParaGuardar(
        sellarBase(
          datosConMedico(medico, finalizadaEn: ahora ?? DateTime.now()),
        ),
        1,
      );
    }
    final recursos = <String, String>{};
    final nuevas = <Map<String, Object?>>[];
    for (final e in state.evolucionesNuevas) {
      final copia = instantaneaMedico(
        medico,
        pais: state.historia.pais,
        logo: false,
        firma: e.incluirFirma,
        sello: e.incluirSello,
      );
      if (medico.configurado) recursos.addAll(copia.recursos);
      nuevas.add({...e.aMapa(), if (medico.configurado) 'autor': copia.autor});
    }
    return DatosParaGuardar(
      sellarEvoluciones(state.datosSellados!, nuevas, recursos: recursos),
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
    // Cierre de la atención → outbox del RDA (módulo IHCE). No construye ni
    // envía nada aquí, no espera y nunca lanza: la atención ya está guardada.
    final ihce = ref.read(servicioIhceProvider);
    if (ihce != null) {
      unawaited(
        ihce.alCerrarAtencion(
          datos: guardado.datos,
          revision: guardado.revision,
          medico: ref.read(medicoProvider),
          prestador: ref.read(prestadorIhceProvider),
        ),
      );
    }
  }

  /// Registra lo formulado en una receta ([texto]): al final del plan
  /// terapéutico de una historia nueva, o de la evolución en curso de una
  /// historia abierta (si no hay ninguna, la crea). Devuelve dónde quedó.
  String registrarReceta(String texto) {
    String unir(String actual) =>
        actual.trim().isEmpty ? texto : '${actual.trimRight()}\n\n$texto';
    final version = state.versionFormulario + 1;
    if (!state.abierta) {
      final h = state.historia;
      state = state.copyWith(
        historia: h.copyWith(
          plan: h.plan.copyWith(planTerapeutico: unir(h.plan.planTerapeutico)),
        ),
        versionFormulario: version,
      );
      return 'el plan de tratamiento';
    }
    if (state.evolucionesNuevas.isEmpty) agregarEvolucion();
    final lista = [...state.evolucionesNuevas];
    final ultima = lista.last;
    lista[lista.length - 1] = ultima.copyWith(texto: unir(ultima.texto));
    state = state.copyWith(
      evolucionesNuevas: lista,
      versionFormulario: version,
    );
    return 'la evolución en curso';
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
