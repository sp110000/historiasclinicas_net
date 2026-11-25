import '../../ihce/reloj.dart';
import '../../utils/ids.dart';
import '../procedimientos/sesion.dart';
import '../reglas/inventario.dart';
import '../reglas/inventario.dart' as reglas show evaluarEntrada;
import '../repositorio/bitacora.dart';
import '../repositorio/repositorio.dart';
import 'insumo.dart';

/// El inventario del consultorio (5.7), descifrado mientras está abierto:
/// insumos, lotes y movimientos (solo se agregan).
class InventarioConsultorio {
  InventarioConsultorio(this._repo, {this.reloj = const RelojSistema()});

  final RepositorioConsultorio _repo;
  final Reloj reloj;

  final _insumos = <String, Insumo>{};
  final _lotes = <String, Lote>{};
  final _movimientos = <String, Movimiento>{};
  Map<String, double> _existencias = const {};

  Future<void> cargar() async {
    final i = await _repo.leerColeccionTolerante(Insumo.coleccion);
    final l = await _repo.leerColeccionTolerante(Lote.coleccion);
    final m = await _repo.leerColeccionTolerante(Movimiento.coleccion);
    olvidar();
    void leer<T>(
      Map<String, Map<String, Object?>> origen,
      Map<String, T> destino,
      T Function(String, Map<String, Object?>) desdeMapa,
    ) {
      for (final e in origen.entries) {
        try {
          destino[e.key] = desdeMapa(e.key, e.value);
        } on Object {
          // Ilegible: se ignora (el respaldo conserva el original).
        }
      }
    }

    leer(i.registros, _insumos, Insumo.desdeMapa);
    leer(l.registros, _lotes, Lote.desdeMapa);
    leer(m.registros, _movimientos, Movimiento.desdeMapa);
    _existencias = existencias(_movimientos.values);
  }

  void olvidar() {
    _insumos.clear();
    _lotes.clear();
    _movimientos.clear();
    _existencias = const {};
  }

  DateTime get _hoy {
    final a = reloj.ahora();
    return DateTime(a.year, a.month, a.day);
  }

  // ─────────────────────────── Consultas ───────────────────────────

  bool get vacio => _insumos.isEmpty;

  /// Todos los insumos, por nombre (los inactivos al final).
  List<Insumo> get insumos => _insumos.values.toList()
    ..sort((a, b) {
      if (a.activo != b.activo) return a.activo ? -1 : 1;
      return claveNombre(a.nombre).compareTo(claveNombre(b.nombre));
    });

  Insumo? insumo(String id) => _insumos[id];
  Lote? lote(String id) => _lotes[id];
  Insumo? insumoDeLote(String? loteId) {
    final l = loteId == null ? null : _lotes[loteId];
    return l == null ? null : _insumos[l.insumoId];
  }

  double existencia(String loteId) => _existencias[loteId] ?? 0;

  /// Existencia sin los lotes vencidos.
  double existenciaVigente(String insumoId) => _lotes.values
      .where((l) => l.insumoId == insumoId && !l.vencidoEn(_hoy))
      .fold(0, (s, l) => s + existencia(l.id));

  /// Los lotes del insumo, el que vence primero primero.
  List<Lote> lotesDe(String insumoId) =>
      ordenFefo(_lotes.values.where((l) => l.insumoId == insumoId));

  List<Lote> disponibles(String insumoId) => lotesDisponibles(
    _lotes.values.where((l) => l.insumoId == insumoId),
    _existencias,
    _hoy,
  );

  /// El lote sugerido: el que vence primero, con existencia y sin vencer.
  Lote? sugerido(String insumoId) => disponibles(insumoId).firstOrNull;

  EstadoLote estado(Lote l) => estadoLote(l, existencia(l.id), _hoy);

  List<Movimiento> movimientosDe(String insumoId) =>
      _movimientos.values.where((m) => m.insumoId == insumoId).toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha));

  /// El insumo activo con ese nombre (sin mayúsculas ni tildes).
  Insumo? insumoPorNombre(String nombre) {
    final k = claveNombre(nombre);
    if (k.isEmpty) return null;
    return _insumos.values
        .where((i) => i.activo && claveNombre(i.nombre) == k)
        .firstOrNull;
  }

  AlertasInventario alertas() => alertasInventario(
    insumos: _insumos.values,
    lotes: _lotes.values,
    existencias: _existencias,
    hoy: _hoy,
  );

  // ─────────────────────────── Acciones ───────────────────────────

  Insumo nuevoInsumo() => Insumo(
    id: '',
    nombre: '',
    categoria: CategoriaInsumo.medicamento,
    unidad: 'unidad',
    creado: reloj.ahora(),
  );

  /// Guarda un insumo nuevo (id vacío) o uno que cambió.
  Future<Insumo> guardarInsumo(Insumo i) async {
    if (i.nombre.trim().isEmpty) throw StateError('Escribe el nombre.');
    if (i.unidad.trim().isEmpty) {
      throw StateError('Escribe la unidad (ampolla, frasco, unidad).');
    }
    if (i.stockMinimo < 0) {
      throw StateError('El mínimo no puede ser negativo.');
    }
    final otro = insumoPorNombre(i.nombre);
    if (otro != null && otro.id != i.id) {
      throw StateError('Ya hay un insumo «${otro.nombre}».');
    }
    final id = i.id.isEmpty ? nuevoUuid() : i.id;
    final g = Insumo.desdeMapa(id, i.aMapa());
    await _repo.guardar(Insumo.coleccion, id, g.aMapa());
    _insumos[id] = g;
    await registrarEnBitacora(
      _repo,
      AccionBitacora.guardarInsumo,
      fecha: reloj.ahora(),
    );
    return g;
  }

  Lote? _mismoNumero(String insumoId, String numero) => _lotes.values
      .where(
        (l) =>
            l.insumoId == insumoId &&
            l.numero.trim().toUpperCase() == numero.trim().toUpperCase(),
      )
      .firstOrNull;

  EvaluacionInventario evaluarEntrada({
    required String? insumoId,
    required String numero,
    required DateTime? vence,
    required double? cantidad,
  }) => reglas.evaluarEntrada(
    insumo: insumoId == null ? null : _insumos[insumoId],
    numero: numero,
    vence: vence,
    cantidad: cantidad,
    hoy: _hoy,
    mismoNumero: insumoId == null ? null : _mismoNumero(insumoId, numero),
  );

  /// Entrada de [cantidad] unidades de un lote (nuevo, o el mismo número si
  /// ya estaba con ese vencimiento).
  Future<Lote> registrarEntrada({
    required String insumoId,
    required String numero,
    required DateTime vence,
    required double cantidad,
    String proveedor = '',
    String factura = '',
  }) async {
    final e = evaluarEntrada(
      insumoId: insumoId,
      numero: numero,
      vence: vence,
      cantidad: cantidad,
    );
    if (!e.permite) throw StateError(e.bloqueos.first);
    final ahora = reloj.ahora();
    var lote = _mismoNumero(insumoId, numero);
    if (lote == null) {
      lote = Lote(
        id: nuevoUuid(),
        insumoId: insumoId,
        numero: numero.trim().toUpperCase(),
        vence: DateTime(vence.year, vence.month, vence.day),
        ingreso: ahora,
        proveedor: proveedor.trim(),
        factura: factura.trim(),
      );
      await _repo.guardar(Lote.coleccion, lote.id, lote.aMapa());
      _lotes[lote.id] = lote;
    }
    await _mover(
      lote,
      TipoMovimiento.entrada,
      cantidad,
      motivo: factura.trim().isEmpty ? '' : 'Factura ${factura.trim()}',
    );
    await registrarEnBitacora(
      _repo,
      AccionBitacora.entradaInventario,
      fecha: ahora,
    );
    return lote;
  }

  Future<void> _mover(
    Lote l,
    TipoMovimiento tipo,
    double cantidad, {
    String motivo = '',
    String? sesionId,
  }) async {
    final m = Movimiento(
      id: nuevoUuid(),
      loteId: l.id,
      insumoId: l.insumoId,
      tipo: tipo,
      cantidad: cantidad,
      fecha: reloj.ahora(),
      sesionId: sesionId,
      motivo: motivo.trim(),
    );
    await _repo.guardar(Movimiento.coleccion, m.id, m.aMapa());
    _movimientos[m.id] = m;
    _existencias = {
      ..._existencias,
      l.id: (_existencias[l.id] ?? 0) + cantidad,
    };
  }

  /// Ajuste con signo (conteo físico, daño…), con motivo.
  Future<void> ajustar(
    String loteId,
    double cantidad, {
    required String motivo,
  }) async {
    final l = _lotes[loteId];
    if (l == null) throw StateError('No existe el lote.');
    final e = evaluarAjuste(
      existencia: existencia(loteId),
      cantidad: cantidad,
      motivo: motivo,
    );
    if (!e.permite) throw StateError(e.bloqueos.first);
    await _mover(l, TipoMovimiento.ajuste, cantidad, motivo: motivo);
    await registrarEnBitacora(
      _repo,
      AccionBitacora.ajusteInventario,
      fecha: reloj.ahora(),
    );
  }

  /// Saca del inventario toda la existencia del lote (vencido, dañado).
  Future<void> darDeBaja(String loteId, {required String motivo}) async {
    final l = _lotes[loteId];
    if (l == null) throw StateError('No existe el lote.');
    if (motivo.trim().isEmpty) throw StateError('Escribe el motivo.');
    final hay = existencia(loteId);
    if (hay <= 0) throw StateError('El lote no tiene existencias.');
    await _mover(l, TipoMovimiento.baja, -hay, motivo: motivo);
    await registrarEnBitacora(
      _repo,
      AccionBitacora.bajaInventario,
      fecha: reloj.ahora(),
    );
  }

  // ─────────────────────────── Sesión ───────────────────────────

  /// El lote de la sesión para el lote [l] del inventario.
  LoteSesion loteSesion(Lote l, {double? unidades}) => LoteSesion(
    lote: l.numero,
    vence: l.vence,
    loteId: l.id,
    unidades: unidades,
  );

  List<LineaInventario> lineas(Sesion s) => lineasInventario(s, insumoDeLote);

  /// Sugiere el lote que vence primero en cada línea sin lote cuyo nombre
  /// está en el inventario (pregunta 49).
  Sesion sugerirLotes(Sesion s) {
    LoteSesion sugerir(String nombre, LoteSesion actual) {
      if (actual.delInventario || actual.lote.trim().isNotEmpty) return actual;
      final i = insumoPorNombre(nombre);
      final l = i == null ? null : sugerido(i.id);
      return l == null ? actual : loteSesion(l);
    }

    final a = s.anestesico;
    return s.copyWith(
      anestesico: a?.copyWith(lote: sugerir(a.nombre, a.lote)),
      componentes: [
        for (final c in s.componentes)
          ComponenteSesion(nombre: c.nombre, lote: sugerir(c.nombre, c.lote)),
      ],
      insumos: [
        for (final i in s.insumos)
          InsumoSesion(
            nombre: i.nombre,
            cantidad: i.cantidad,
            lote: sugerir(i.nombre, i.lote),
          ),
      ],
    );
  }

  EvaluacionInventario evaluarSesion(Sesion s) => evaluarInventarioSesion(
    lineas: lineas(s),
    lotes: _lotes,
    insumos: _insumos,
    existencias: _existencias,
    insumoPorNombre: insumoPorNombre,
  );

  /// Descuenta las líneas de la sesión sellada [s] que salen del
  /// inventario.
  Future<void> descontarSesion(Sesion s) async {
    final e = evaluarSesion(s);
    if (!e.permite) throw StateError(e.bloqueos.first);
    var hubo = false;
    for (final l in lineas(s)) {
      final lote = l.lote.loteId == null ? null : _lotes[l.lote.loteId];
      if (lote == null) continue;
      await _mover(
        lote,
        TipoMovimiento.salida,
        -l.unidades,
        motivo: '${s.titulo}: ${l.nombre}',
        sesionId: s.id,
      );
      hubo = true;
    }
    if (hubo) {
      await registrarEnBitacora(
        _repo,
        AccionBitacora.salidaInventario,
        fecha: reloj.ahora(),
        resumen: s.titulo,
      );
    }
  }
}
