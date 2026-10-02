import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/medico.dart';
import '../../../core/pdf/rasterizar.dart';
import '../../../core/pdf/receta_pdf.dart';
import '../../../core/receta/alertas.dart';
import '../../../core/receta/medicamentos.dart';
import '../../../core/receta/receta.dart';
import '../../../core/storage/preferencias.dart';
import '../../../core/storage/receta_store.dart';
import '../../../core/utils/ids.dart';
import '../../historia/estado/borrador_provider.dart';
import '../../historia/estado/historia_controller.dart';
import '../../medico/medico_provider.dart';

final recetaStoreProvider = Provider<RecetaStore>(
  (ref) => RecetaStore(ref.watch(preferenciasProvider)),
);

/// Receta en curso de la historia actual. Se guarda sola en el navegador;
/// si cambia la historia (otra historia abierta o una nueva), empieza una
/// receta nueva.
final recetaProvider = NotifierProvider<RecetaController, Receta>(
  RecetaController.new,
);

class RecetaController extends Notifier<Receta> {
  static const espera = Duration(milliseconds: 500);

  Timer? _temporizador;

  /// Cambios aún no guardados.
  Receta? _pendiente;

  @override
  Receta build() {
    final historiaId = ref.watch(historiaProvider.select((e) => e.historia.id));
    // En onDispose no se puede usar `ref`: se guarda lo necesario antes.
    final store = ref.read(recetaStoreProvider);
    ref.onDispose(() {
      final pendiente = _pendiente;
      _temporizador?.cancel();
      _pendiente = null;
      if (pendiente != null) unawaited(store.guardar(pendiente));
    });
    final guardada = store.leer();
    if (guardada != null && guardada.historiaId == historiaId) return guardada;
    return _nueva(historiaId);
  }

  Receta _nueva(String historiaId) {
    final firma = ref.read(historiaProvider).historia.firma;
    return Receta(
      id: nuevoUuid(),
      historiaId: historiaId,
      fecha: DateTime.now(),
      items: [ItemReceta(id: nuevoUuid())],
      incluirFirma: firma.incluirFirma,
      incluirSello: firma.incluirSello,
    );
  }

  void _cambiar(Receta nueva) {
    state = nueva;
    _temporizador?.cancel();
    // "No guardar borrador en este equipo" también vale para la receta.
    if (ref.read(borradorStoreProvider).desactivado) return;
    _pendiente = nueva;
    _temporizador = Timer(espera, () {
      _pendiente = null;
      ref.read(recetaStoreProvider).guardar(nueva);
    });
  }

  void actualizar(Receta Function(Receta r) cambio) => _cambiar(cambio(state));

  // ── Ítems ──

  void agregarItem() => _cambiar(
    state.copyWith(
      items: [
        ...state.items,
        ItemReceta(id: nuevoUuid()),
      ],
    ),
  );

  void actualizarItem(String id, ItemReceta Function(ItemReceta i) cambio) =>
      _cambiar(
        state.copyWith(
          items: [for (final i in state.items) i.id == id ? cambio(i) : i],
        ),
      );

  /// Para "Deshacer" tras eliminar.
  void insertarItem(int indice, ItemReceta item) => _cambiar(
    state.copyWith(
      items: [...state.items]
        ..insert(indice.clamp(0, state.items.length), item),
    ),
  );

  void eliminarItem(String id) => _cambiar(
    state.copyWith(items: state.items.where((i) => i.id != id).toList()),
  );

  /// Mueve un ítem como `ReorderableListView` ([hasta] cuenta el hueco que
  /// deja el ítem al salir).
  void reordenar(int desde, int hasta) {
    final lista = [...state.items];
    final destino = hasta > desde ? hasta - 1 : hasta;
    if (desde < 0 || desde >= lista.length || destino == desde) return;
    final item = lista.removeAt(desde);
    lista.insert(destino.clamp(0, lista.length), item);
    _cambiar(state.copyWith(items: lista));
  }

  void subir(String id) {
    final i = state.items.indexWhere((x) => x.id == id);
    if (i > 0) reordenar(i, i - 1);
  }

  void bajar(String id) {
    final i = state.items.indexWhere((x) => x.id == id);
    if (i >= 0 && i < state.items.length - 1) reordenar(i, i + 2);
  }

  // ── Paciente ──

  /// Corrige un dato del paciente solo en la receta. Con [valor] `null`
  /// vuelve al de la historia.
  void ajustarPaciente(String campo, String? valor) {
    final ajustes = {...state.ajustesPaciente};
    if (valor == null) {
      ajustes.remove(campo);
    } else {
      ajustes[campo] = valor;
    }
    _cambiar(state.copyWith(ajustesPaciente: ajustes));
  }

  void restablecerPaciente() => _cambiar(state.copyWith(ajustesPaciente: {}));

  void marcarAlertaVista(String clave) =>
      _cambiar(state.copyWith(alertasVistas: {...state.alertasVistas, clave}));

  // ── Ciclo ──

  /// Asigna el número correlativo antes de imprimir o guardar (si la
  /// numeración está activada y la receta aún no tiene número).
  Future<void> prepararParaImprimir() async {
    if (state.numero != null || !ref.read(opcionesRecetaProvider).numerar) {
      return;
    }
    final numero = await ref.read(recetaStoreProvider).asignarNumero();
    ref.invalidate(opcionesRecetaProvider);
    _cambiar(state.copyWith(numero: numero));
  }

  void marcarRegistrada() =>
      _cambiar(state.copyWith(registradaEnHistoria: true));

  /// Empieza otra receta para la misma historia.
  void nueva() => _cambiar(_nueva(state.historiaId));

  /// Guarda ya los cambios que esperaban (por ejemplo, antes de recargar).
  Future<void> guardarPendiente() async {
    if (_pendiente != null) await guardarAhora();
  }

  /// Guarda de inmediato lo pendiente.
  Future<void> guardarAhora() async {
    _temporizador?.cancel();
    _pendiente = null;
    await ref.read(recetaStoreProvider).guardar(state);
  }
}

// ─────────────────────────── Opciones ───────────────────────────

class OpcionesReceta {
  const OpcionesReceta({
    required this.numerar,
    required this.proximoNumero,
    required this.titulo,
  });

  final bool numerar;
  final String proximoNumero;

  /// "Receta médica", "Fórmula médica"… (en España, VERIFICAR si debe ser
  /// "Hoja de tratamiento").
  final String titulo;
}

const titulosReceta = [
  'Receta médica',
  'Fórmula médica',
  'Prescripción médica',
  'Hoja de tratamiento',
];

final opcionesRecetaProvider =
    NotifierProvider<OpcionesRecetaController, OpcionesReceta>(
      OpcionesRecetaController.new,
    );

class OpcionesRecetaController extends Notifier<OpcionesReceta> {
  RecetaStore get _store => ref.read(recetaStoreProvider);

  @override
  OpcionesReceta build() => OpcionesReceta(
    numerar: _store.numerar,
    proximoNumero: _store.proximoNumero,
    titulo: _store.titulo,
  );

  Future<void> cambiarNumerar(bool valor) async {
    await _store.cambiarNumerar(valor);
    ref.invalidateSelf();
  }

  Future<void> cambiarTitulo(String titulo) async {
    await _store.cambiarTitulo(titulo);
    ref.invalidateSelf();
  }

  /// Para seguir la numeración de otro equipo o talonario.
  Future<void> continuarDesde(int ultimo) async {
    await _store.cambiarUltimoNumero(ultimo);
    ref.invalidateSelf();
  }
}

// ─────────────────────────── Mis medicamentos ───────────────────────────

final misMedicamentosProvider =
    NotifierProvider<MisMedicamentosController, List<PlantillaMedicamento>>(
      MisMedicamentosController.new,
    );

class MisMedicamentosController extends Notifier<List<PlantillaMedicamento>> {
  RecetaStore get _store => ref.read(recetaStoreProvider);

  @override
  List<PlantillaMedicamento> build() => _store.leerMedicamentos();

  Future<void> _poner(List<PlantillaMedicamento> lista) async {
    state = lista;
    await _store.guardarMedicamentos(lista);
  }

  Future<void> guardar(PlantillaMedicamento p) =>
      _poner(conPlantilla(state, p));

  Future<void> eliminar(PlantillaMedicamento p) =>
      _poner(state.where((x) => x.clave != p.clave).toList());

  Future<ResultadoImportacion> importar(String json) async {
    final r = importarMedicamentos(json, state);
    await _poner(r.lista);
    return r;
  }

  String exportar() => exportarMedicamentos(state);
}

// ─────────────────────────── Derivados ───────────────────────────

/// Datos del paciente que se imprimen (historia + correcciones).
final pacienteRecetaProvider = Provider<PacienteReceta>((ref) {
  final h = ref.watch(historiaProvider.select((e) => e.historia));
  final ajustes = ref.watch(recetaProvider.select((r) => r.ajustesPaciente));
  return PacienteReceta.deHistoria(h).conAjustes(ajustes);
});

/// Alergias con las que se cruzan los medicamentos: las de la historia, o
/// las corregidas en la receta.
final alergiasRecetaProvider = Provider<List<String>>((ref) {
  final ajustes = ref.watch(recetaProvider.select((r) => r.ajustesPaciente));
  final corregidas = ajustes['alergias'];
  if (corregidas != null) return alergiasDeTexto(corregidas);
  final a = ref.watch(historiaProvider.select((e) => e.historia.antecedentes));
  return a.niegaAlergias ? const [] : a.alergias;
});

final alertasAlergiaProvider = Provider<List<AlertaAlergia>>((ref) {
  final items = ref.watch(recetaProvider.select((r) => r.items));
  return alertasDeAlergia(
    alergias: ref.watch(alergiasRecetaProvider),
    items: items,
  );
});

final avisosControlProvider = Provider<List<AvisoControlEspecial>>(
  (ref) =>
      avisosControlEspecial(ref.watch(recetaProvider.select((r) => r.items))),
);

/// Lo que se imprime, con la copia del médico de este navegador.
final documentoRecetaProvider = Provider<DocumentoReceta>((ref) {
  final r = ref.watch(recetaProvider);
  final pais = ref.watch(historiaProvider.select((e) => e.historia.pais));
  final medico = ref.watch(medicoProvider);
  final opciones = ref.watch(opcionesRecetaProvider);
  final copia = medico.configurado
      ? instantaneaMedico(
          medico,
          pais: pais,
          firma: r.incluirFirma,
          sello: r.incluirSello,
        )
      : null;
  return DocumentoReceta(
    // Con la numeración activada, la vista previa ya muestra el número que
    // recibirá al imprimir o guardar.
    receta: r.numero == null && opciones.numerar
        ? r.copyWith(numero: opciones.proximoNumero)
        : r,
    paciente: ref.watch(pacienteRecetaProvider),
    pais: pais,
    titulo: opciones.titulo,
    medico: copia == null ? null : Autor.desdeMapa(copia.autor),
    recursos: copia?.recursos ?? const {},
  );
});

/// Convierte un PDF en imágenes PNG (una por página) para la vista previa.
typedef Rasterizador = Stream<Uint8List> Function(Uint8List pdf, double dpi);

/// En la web usa pdf.js, servido desde el propio sitio (sin CDN). Los tests
/// lo sustituyen.
final rasterizadorProvider = Provider<Rasterizador>((ref) => rasterizarPdf);
