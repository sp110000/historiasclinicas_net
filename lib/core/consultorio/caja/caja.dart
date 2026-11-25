import 'dart:typed_data';

import '../../ihce/reloj.dart';
import '../../models/mapa.dart';
import '../../models/medico.dart';
import '../../pais/perfil_pais.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../utils/ids.dart';
import '../indice/indice_pacientes.dart';
import '../modelos/ficha_paciente.dart';
import '../procedimientos/procedimientos.dart';
import '../reglas/caja.dart';
import '../repositorio/bitacora.dart';
import '../repositorio/repositorio.dart';
import 'catalogo.dart';
import 'movimientos.dart';
import 'recibo_pdf.dart';

/// Resultado de cobrar: el cobro y, si hubo pago, su recibo y el PDF.
typedef ResultadoCobro = ({Cobro cobro, Recibo? recibo, Uint8List? pdf});

/// La caja del consultorio (5.6), descifrada mientras está abierto.
class CajaConsultorio {
  CajaConsultorio(
    this._repo,
    this._indice,
    this._procedimientos, {
    required String Function() serie,
    this.reloj = const RelojSistema(),
  }) : _serie = serie;

  final RepositorioConsultorio _repo;
  final IndicePacientes _indice;
  final ProcedimientosConsultorio _procedimientos;
  final String Function() _serie;
  final Reloj reloj;

  static const coleccionCatalogo = 'configuracion';
  static const idCatalogo = 'caja';
  static const coleccionConsecutivos = 'consecutivos';

  List<Servicio> _servicios = serviciosIniciales;
  final _cobros = <String, Cobro>{};
  final _recibos = <String, Recibo>{};
  final _paquetes = <String, Paquete>{};
  final _creditos = <String, Credito>{};
  final _cierres = <String, CierreDiario>{};

  Future<void> cargar() async {
    final cat = await _repo.leer(coleccionCatalogo, idCatalogo);
    final cobros = await _repo.leerColeccionTolerante(Cobro.coleccion);
    final recibos = await _repo.leerColeccionTolerante(Recibo.coleccion);
    final paquetes = await _repo.leerColeccionTolerante(Paquete.coleccion);
    final creditos = await _repo.leerColeccionTolerante(Credito.coleccion);
    final cierres = await _repo.leerColeccionTolerante(CierreDiario.coleccion);
    olvidar();
    try {
      if (cat != null) {
        _servicios = [
          for (final s in cat.listaMapas('servicios')) Servicio.desdeMapa(s),
        ];
      }
    } on Object {
      _servicios = serviciosIniciales;
    }
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

    leer(cobros.registros, _cobros, Cobro.desdeMapa);
    leer(recibos.registros, _recibos, Recibo.desdeMapa);
    leer(paquetes.registros, _paquetes, Paquete.desdeMapa);
    leer(creditos.registros, _creditos, Credito.desdeMapa);
    leer(cierres.registros, _cierres, (_, m) => CierreDiario.desdeMapa(m));
  }

  void olvidar() {
    _servicios = serviciosIniciales;
    _cobros.clear();
    _recibos.clear();
    _paquetes.clear();
    _creditos.clear();
    _cierres.clear();
  }

  // ─────────────────────────── Catálogo ───────────────────────────

  List<Servicio> get servicios => _servicios;
  Map<String, Servicio> get serviciosPorId => {
    for (final s in _servicios) s.id: s,
  };

  /// Guarda el catálogo (tarifas, servicios nuevos o desactivados).
  Future<void> guardarCatalogo(List<Servicio> servicios) async {
    for (final s in servicios) {
      if (s.nombre.trim().isEmpty) {
        throw StateError('Cada servicio necesita nombre.');
      }
      if (s.tarifa < 0) throw StateError('Una tarifa no puede ser negativa.');
    }
    await _repo.guardar(coleccionCatalogo, idCatalogo, {
      'servicios': [for (final s in servicios) s.aMapa()],
    });
    _servicios = List.unmodifiable(servicios);
    await registrarEnBitacora(
      _repo,
      AccionBitacora.cambiarAjustes,
      fecha: reloj.ahora(),
      resumen: 'Catálogo de la caja',
    );
  }

  /// Un servicio nuevo (sin guardar), con id propio.
  Servicio nuevoServicio() => Servicio(
    id: 'servicio_${nuevoUuid().substring(0, 8)}',
    nombre: '',
    linea: LineaAtencion.general,
    tarifa: 0,
  );

  // ─────────────────────────── Consultas ───────────────────────────

  Cobro? cobro(String id) => _cobros[id];
  Recibo? recibo(String id) => _recibos[id];
  Paquete? paquete(String id) => _paquetes[id];

  List<Recibo> recibosDe(String cobroId) =>
      _recibos.values.where((r) => r.cobroId == cobroId).toList()
        ..sort((a, b) => a.fecha.compareTo(b.fecha));

  int pagado(String cobroId) => recibosDe(
    cobroId,
  ).where((r) => !r.anulado).fold(0, (s, r) => s + r.valor);

  int saldo(Cobro c) => c.anulado ? 0 : c.total - pagado(c.id);

  List<Cobro> cobrosDe(String pacienteId) {
    final ids = _indice.idsUnidos(pacienteId);
    return _cobros.values.where((c) => ids.contains(c.pacienteId)).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  /// Lo que la ficha debe (cobros vigentes con saldo).
  int saldoPaciente(String pacienteId) =>
      cobrosDe(pacienteId).fold(0, (s, c) => s + saldo(c));

  List<Paquete> paquetesDe(String pacienteId) {
    final ids = _indice.idsUnidos(pacienteId);
    return _paquetes.values.where((p) => ids.contains(p.pacienteId)).toList()
      ..sort((a, b) => b.creado.compareTo(a.creado));
  }

  /// Créditos de valoración que se pueden aplicar hoy.
  List<Credito> creditosDisponibles(String pacienteId) {
    final ids = _indice.idsUnidos(pacienteId);
    final ahora = reloj.ahora();
    return [
      for (final c in _creditos.values)
        if (ids.contains(c.pacienteId) && c.disponible(ahora)) c,
    ]..sort((a, b) => a.vence.compareTo(b.vence));
  }

  CierreDiario? cierre(DateTime dia) => _cierres[CierreDiario.clave(dia)];
  bool diaCerrado(DateTime dia) => cierre(dia) != null;
  bool get hoyCerrado => diaCerrado(reloj.ahora());

  static bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Recibos emitidos el día [dia] (vigentes y anulados).
  List<Recibo> recibosDelDia(DateTime dia) =>
      _recibos.values.where((r) => _mismoDia(r.fecha, dia)).toList()
        ..sort((a, b) => a.fecha.compareTo(b.fecha));

  /// Recibos de días cerrados que se anularon el día [dia].
  List<Recibo> anulacionesDelDia(DateTime dia) =>
      _recibos.values
          .where((r) => r.anuladoTrasCierre && _mismoDia(r.anuladoEn!, dia))
          .toList()
        ..sort((a, b) => a.anuladoEn!.compareTo(b.anuladoEn!));

  /// Sesiones de paquete usadas el día [dia] (sin recibo).
  List<({Paquete paquete, UsoPaquete uso, int numero})> usosDelDia(
    DateTime dia,
  ) {
    final r = <({Paquete paquete, UsoPaquete uso, int numero})>[];
    for (final p in _paquetes.values) {
      var n = 0;
      for (final u in p.usos) {
        if (u.anulado) continue;
        n++;
        if (_mismoDia(u.fecha, dia)) r.add((paquete: p, uso: u, numero: n));
      }
    }
    return r..sort((a, b) => a.uso.fecha.compareTo(b.uso.fecha));
  }

  /// Cobros sin pago del día [dia] (quedan con saldo, sin recibo).
  List<Cobro> cobrosSinPagoDelDia(DateTime dia) => [
    for (final c in _cobros.values)
      if (!c.anulado && _mismoDia(c.fecha, dia) && recibosDe(c.id).isEmpty) c,
  ]..sort((a, b) => a.fecha.compareTo(b.fecha));

  Map<MedioPago, int> totales(DateTime dia) =>
      totalesDelDia(_recibos.values, dia);

  Future<Uint8List?> pdfRecibo(String id) =>
      _repo.leerBinario(Recibo.tipoBinarioPdf, id);

  // ─────────────────────────── Acciones ───────────────────────────

  Future<String> _siguienteNumero() async {
    final serie = _serie();
    final clave = 'RC$serie';
    final r = await _repo.leer(coleccionConsecutivos, clave);
    final n = (r?.entero('ultimo') ?? 0) + 1;
    await _repo.guardar(coleccionConsecutivos, clave, {'ultimo': n});
    return 'RC-$serie${n.toString().padLeft(6, '0')}';
  }

  /// El valor del crédito que se aplicaría a [items].
  int valorCredito(Credito? credito, List<ItemCobro> items) {
    if (credito == null) return 0;
    final neto = items.fold(0, (s, i) => s + i.neto);
    return credito.valor < neto ? credito.valor : neto;
  }

  EvaluacionCobro evaluar({
    required String pacienteId,
    required List<ItemCobro> items,
    required List<PagoRecibo> pagos,
    Credito? credito,
  }) => evaluarCobro(
    pacienteId: pacienteId,
    items: items,
    credito: valorCredito(credito, items),
    pagos: pagos,
    diaCerrado: hoyCerrado,
    creditoSinAplicar: credito == null && pacienteId.isNotEmpty
        ? creditosDisponibles(pacienteId).fold(0, (s, c) => s + c.valor)
        : 0,
    servicios: serviciosPorId,
  );

  /// Registra un cobro con sus pagos (si los hay, emite el recibo y su
  /// PDF). Un servicio de paquete crea el paquete; una valoración abonable
  /// pagada del todo deja el crédito. Lanza [StateError] con el primer
  /// bloqueo de las reglas.
  Future<ResultadoCobro> cobrar({
    required String pacienteId,
    required List<ItemCobro> items,
    required List<PagoRecibo> pagos,
    required Medico medico,
    required Pais pais,
    Credito? credito,
    String? citaId,
    FuentesPdf? fuentes,
  }) async {
    final e = evaluar(
      pacienteId: pacienteId,
      items: items,
      pagos: pagos,
      credito: credito,
    );
    if (!e.permiteRegistrar) throw StateError(e.bloqueos.first);
    if (credito != null && !credito.disponible(reloj.ahora())) {
      throw StateError('El crédito ya no está disponible.');
    }
    final ficha = _indice.fichaActiva(pacienteId)!;
    final ahora = reloj.ahora();
    final cobro = Cobro(
      id: nuevoUuid(),
      pacienteId: ficha.id,
      fecha: ahora,
      items: items,
      creditoId: credito?.id,
      credito: valorCredito(credito, items),
      citaId: citaId,
    );
    await _repo.guardar(Cobro.coleccion, cobro.id, cobro.aMapa());
    _cobros[cobro.id] = cobro;
    if (credito != null) {
      final aplicado = credito.copyWith(aplicadoEn: cobro.id);
      await _repo.guardar(Credito.coleccion, credito.id, aplicado.aMapa());
      _creditos[credito.id] = aplicado;
    }
    final catalogo = serviciosPorId;
    for (final i in items) {
      final s = catalogo[i.servicioId];
      if (s == null || !s.esPaquete) continue;
      final p = Paquete(
        id: nuevoUuid(),
        pacienteId: ficha.id,
        servicioId: s.id,
        nombre: s.nombre,
        sesiones: s.sesionesPaquete * i.cantidad,
        cobroId: cobro.id,
        creado: ahora,
        plantillaId: s.plantillaId,
      );
      await _repo.guardar(Paquete.coleccion, p.id, p.aMapa());
      _paquetes[p.id] = p;
    }
    await registrarEnBitacora(
      _repo,
      AccionBitacora.registrarCobro,
      fecha: ahora,
      resumen: formatoPesos(cobro.total),
    );
    if (pagos.isEmpty) {
      await _creditoSiCorresponde(cobro);
      return (cobro: cobro, recibo: null, pdf: null);
    }
    final (recibo, pdf) = await _emitirRecibo(
      cobro,
      pagos,
      medico: medico,
      pais: pais,
      fuentes: fuentes,
    );
    return (cobro: cobro, recibo: recibo, pdf: pdf);
  }

  /// Un abono a un cobro con saldo: emite su recibo.
  Future<(Recibo, Uint8List)> abonar(
    String cobroId,
    List<PagoRecibo> pagos, {
    required Medico medico,
    required Pais pais,
    FuentesPdf? fuentes,
  }) async {
    final c = _cobros[cobroId];
    if (c == null) throw StateError('No existe el cobro.');
    final e = evaluarAbono(
      cobro: c,
      saldo: saldo(c),
      pagos: pagos,
      diaCerrado: hoyCerrado,
    );
    if (!e.permiteRegistrar) throw StateError(e.bloqueos.first);
    return _emitirRecibo(
      c,
      pagos,
      medico: medico,
      pais: pais,
      fuentes: fuentes,
    );
  }

  Future<(Recibo, Uint8List)> _emitirRecibo(
    Cobro cobro,
    List<PagoRecibo> pagos, {
    required Medico medico,
    required Pais pais,
    FuentesPdf? fuentes,
  }) async {
    final ahora = reloj.ahora();
    final recibo = Recibo(
      id: nuevoUuid(),
      numero: await _siguienteNumero(),
      cobroId: cobro.id,
      pacienteId: cobro.pacienteId,
      fecha: ahora,
      pagos: pagos,
      tienePdf: true,
    );
    final ficha = _indice.fichaActiva(cobro.pacienteId);
    final copia = instantaneaMedico(medico, pais: pais);
    final pdf = await generarPdfRecibo(
      ContenidoRecibo(
        recibo: recibo,
        cobro: cobro,
        paciente: ficha?.nombreCompleto ?? '',
        documentoPaciente: ficha?.documentoTexto ?? '',
        pagadoALaFecha: pagado(cobro.id) + recibo.valor,
        medico: medico.configurado ? Autor.desdeMapa(copia.autor) : null,
        recursos: copia.recursos,
      ),
      fuentes: fuentes,
    );
    await _repo.guardarBinario(Recibo.tipoBinarioPdf, recibo.id, pdf);
    await _repo.guardar(Recibo.coleccion, recibo.id, recibo.aMapa());
    _recibos[recibo.id] = recibo;
    await registrarEnBitacora(
      _repo,
      AccionBitacora.registrarPago,
      fecha: ahora,
      resumen: '${recibo.numero} · ${formatoPesos(recibo.valor)}',
    );
    await _creditoSiCorresponde(cobro);
    return (recibo, pdf);
  }

  /// Una valoración abonable pagada del todo deja su crédito por 30 días.
  Future<void> _creditoSiCorresponde(Cobro cobro) async {
    if (saldo(cobro) > 0) return;
    if (_creditos.values.any((c) => c.cobroOrigenId == cobro.id)) return;
    final catalogo = serviciosPorId;
    final valor = cobro.items
        .where((i) => catalogo[i.servicioId]?.abonable ?? false)
        .fold(0, (s, i) => s + i.neto);
    if (valor <= 0) return;
    final ahora = reloj.ahora();
    final c = Credito(
      id: nuevoUuid(),
      pacienteId: cobro.pacienteId,
      valor: valor,
      cobroOrigenId: cobro.id,
      vence: DateTime(
        ahora.year,
        ahora.month,
        ahora.day + Credito.diasVigencia,
      ),
    );
    await _repo.guardar(Credito.coleccion, c.id, c.aMapa());
    _creditos[c.id] = c;
  }

  /// Anula un recibo con motivo. Si su día ya se cerró, resta en el de hoy.
  /// Si el cobro deja de estar pagado, su crédito (sin aplicar) se anula; si
  /// ya se aplicó, primero hay que anular el cobro donde se aplicó.
  Future<void> anularRecibo(String id, {required String motivo}) async {
    final r = _recibos[id];
    if (r == null || r.anulado) throw StateError('El recibo no está vigente.');
    if (motivo.trim().isEmpty) throw StateError('Escribe el motivo.');
    if (hoyCerrado) {
      throw StateError(
        'La caja de hoy ya se cerró: anula el recibo mañana (cuenta en ese '
        'día).',
      );
    }
    final credito = _creditos.values
        .where((c) => c.cobroOrigenId == r.cobroId && !c.anulado)
        .firstOrNull;
    if (credito?.aplicadoEn != null) {
      throw StateError(
        'El crédito de esta valoración ya se aplicó en otro cobro: anula '
        'primero ese cobro.',
      );
    }
    final ahora = reloj.ahora();
    final anulado = r.anular(
      motivo.trim(),
      ahora,
      trasCierre: diaCerrado(r.fecha),
    );
    await _repo.guardar(Recibo.coleccion, id, anulado.aMapa());
    _recibos[id] = anulado;
    if (credito != null) {
      final sin = credito.copyWith(anulado: true);
      await _repo.guardar(Credito.coleccion, sin.id, sin.aMapa());
      _creditos[sin.id] = sin;
    }
    await registrarEnBitacora(
      _repo,
      AccionBitacora.anularRecibo,
      fecha: ahora,
      resumen: r.numero,
    );
  }

  /// Anula un cobro sin recibos vigentes: libera el crédito aplicado y
  /// anula los paquetes sin usar.
  Future<void> anularCobro(String id, {required String motivo}) async {
    final c = _cobros[id];
    if (c == null || c.anulado) throw StateError('El cobro no está vigente.');
    if (motivo.trim().isEmpty) throw StateError('Escribe el motivo.');
    if (recibosDe(id).any((r) => !r.anulado)) {
      throw StateError('Anula primero sus recibos.');
    }
    final paquetes = _paquetes.values.where((p) => p.cobroId == id).toList();
    if (paquetes.any((p) => p.usadas > 0)) {
      throw StateError('Su paquete ya tiene sesiones usadas.');
    }
    final ahora = reloj.ahora();
    final anulado = c.anular(motivo.trim(), ahora);
    await _repo.guardar(Cobro.coleccion, id, anulado.aMapa());
    _cobros[id] = anulado;
    for (final p in paquetes) {
      final a = p.copyWith(anulado: true);
      await _repo.guardar(Paquete.coleccion, a.id, a.aMapa());
      _paquetes[a.id] = a;
    }
    final aplicado = c.creditoId == null ? null : _creditos[c.creditoId];
    if (aplicado != null) {
      final libre = aplicado.copyWith(aplicadoEn: null);
      await _repo.guardar(Credito.coleccion, libre.id, libre.aMapa());
      _creditos[libre.id] = libre;
    }
    await registrarEnBitacora(
      _repo,
      AccionBitacora.anularCobro,
      fecha: ahora,
      resumen: formatoPesos(c.total),
    );
  }

  /// Usa una sesión del paquete (sin recibo, pregunta 46).
  Future<Paquete> usarPaquete(String id, {String? sesionId}) async {
    final p = _paquetes[id];
    if (p == null || p.anulado) throw StateError('El paquete no está vigente.');
    if (p.agotado) {
      throw StateError(
        'El paquete ya usó sus ${p.sesiones} sesiones: cobra la sesión.',
      );
    }
    final ahora = reloj.ahora();
    final usado = p.copyWith(
      usos: [
        ...p.usos,
        UsoPaquete(fecha: ahora, sesionId: sesionId),
      ],
    );
    await _repo.guardar(Paquete.coleccion, id, usado.aMapa());
    _paquetes[id] = usado;
    await registrarEnBitacora(
      _repo,
      AccionBitacora.usarPaquete,
      fecha: ahora,
      resumen: '${usado.usadas}/${usado.sesiones}',
    );
    return usado;
  }

  /// Cierra la caja de hoy con el efectivo contado. No se reabre.
  Future<CierreDiario> cerrarDia({
    required int efectivoContado,
    String notas = '',
  }) async {
    final ahora = reloj.ahora();
    if (diaCerrado(ahora)) throw StateError('La caja de hoy ya se cerró.');
    if (efectivoContado < 0) {
      throw StateError('El efectivo no puede ser negativo.');
    }
    final c = CierreDiario(
      dia: DateTime(ahora.year, ahora.month, ahora.day),
      totales: totales(ahora),
      efectivoContado: efectivoContado,
      cerradoEn: ahora,
      notas: notas,
    );
    await _repo.guardar(
      CierreDiario.coleccion,
      CierreDiario.clave(ahora),
      c.aMapa(),
    );
    _cierres[CierreDiario.clave(ahora)] = c;
    await registrarEnBitacora(
      _repo,
      AccionBitacora.cerrarCaja,
      fecha: ahora,
      resumen: formatoPesos(c.total),
    );
    return c;
  }

  // ─────────────────────────── Informes ───────────────────────────

  /// La caja del día [dia] en CSV: recibos (también los anulados), las
  /// anulaciones de días cerrados, los usos de paquete y los totales.
  Future<List<int>> exportarDia(DateTime dia) async {
    String hora(DateTime f) =>
        '${f.hour.toString().padLeft(2, '0')}:'
        '${f.minute.toString().padLeft(2, '0')}';
    String paciente(String id) => _indice.ficha(id)?.nombreCompleto ?? '';
    String concepto(String cobroId) => _cobros[cobroId]?.descripcion ?? '';
    final c = cierre(dia);
    final t = c?.totales ?? totales(dia);
    final filas = <List<Object>>[
      [
        'Día',
        'Hora',
        'Número',
        'Paciente',
        'Concepto',
        'Medio',
        'Valor',
        'Estado',
      ],
      for (final r in recibosDelDia(dia))
        for (final p in r.pagos)
          [
            diaIso(dia),
            hora(r.fecha),
            r.numero,
            paciente(r.pacienteId),
            concepto(r.cobroId),
            p.medio.etiqueta,
            p.valor,
            r.anulado
                ? (r.anuladoTrasCierre
                      ? 'Anulado el ${diaIso(r.anuladoEn!)}'
                      : 'Anulado')
                : 'Vigente',
          ],
      for (final r in anulacionesDelDia(dia))
        for (final p in r.pagos)
          [
            diaIso(dia),
            hora(r.anuladoEn!),
            r.numero,
            paciente(r.pacienteId),
            'Anulación del recibo del ${diaIso(r.fecha)}',
            p.medio.etiqueta,
            -p.valor,
            'Anulación',
          ],
      for (final u in usosDelDia(dia))
        [
          diaIso(dia),
          hora(u.uso.fecha),
          '',
          paciente(u.paquete.pacienteId),
          '${u.paquete.nombre}: sesión ${u.numero} de ${u.paquete.sesiones}',
          '',
          0,
          'Uso de paquete',
        ],
      for (final e in t.entries)
        [diaIso(dia), '', '', '', 'Total', e.key.etiqueta, e.value, ''],
      if (c != null) ...[
        [
          diaIso(dia),
          hora(c.cerradoEn),
          '',
          '',
          'Efectivo contado',
          MedioPago.efectivo.etiqueta,
          c.efectivoContado,
          'Cierre',
        ],
        [
          diaIso(dia),
          '',
          '',
          '',
          'Diferencia',
          MedioPago.efectivo.etiqueta,
          c.diferencia,
          c.notas,
        ],
      ],
    ];
    await registrarEnBitacora(
      _repo,
      AccionBitacora.exportarInforme,
      fecha: reloj.ahora(),
      resumen: 'Caja del ${diaIso(dia)}',
    );
    return csvDeFilas(filas);
  }

  InformeMes informe(int anio, int mes) => informeDelMes(
    anio: anio,
    mes: mes,
    cobros: _cobros.values,
    recibos: _recibos.values,
    servicios: serviciosPorId,
  );

  /// Valoraciones y sesiones selladas del mes por técnica, y sesiones de
  /// paquete usadas.
  List<VolumenTecnica> volumenPorTecnica(int anio, int mes) {
    bool delMes(DateTime f) => f.year == anio && f.month == mes;
    final v = <String, ({int valoraciones, int sesiones})>{};
    String nombre(String plantillaId) {
      final p = _procedimientos.plantilla(plantillaId);
      return p?.nombre ?? plantillaId;
    }

    for (final x in _procedimientos.todasLasValoraciones) {
      if (!x.sellada || !delMes(x.fecha)) continue;
      final k = nombre(x.plantillaId);
      final a = v[k] ?? (valoraciones: 0, sesiones: 0);
      v[k] = (valoraciones: a.valoraciones + 1, sesiones: a.sesiones);
    }
    for (final s in _procedimientos.todasLasSesiones) {
      if (!s.sellada || !delMes(s.fecha)) continue;
      final k = nombre(s.plantillaId);
      final a = v[k] ?? (valoraciones: 0, sesiones: 0);
      v[k] = (valoraciones: a.valoraciones, sesiones: a.sesiones + 1);
    }
    return [
      for (final e in v.entries)
        (
          tecnica: e.key,
          valoraciones: e.value.valoraciones,
          sesiones: e.value.sesiones,
        ),
    ]..sort((a, b) => a.tecnica.compareTo(b.tecnica));
  }

  /// El informe del mes en CSV (y queda en la bitácora).
  Future<List<int>> exportarInforme(int anio, int mes) async {
    final csv = csvInforme(
      informe(anio, mes),
      volumen: volumenPorTecnica(anio, mes),
    );
    await registrarEnBitacora(
      _repo,
      AccionBitacora.exportarInforme,
      fecha: reloj.ahora(),
      resumen: '$anio-${mes.toString().padLeft(2, '0')}',
    );
    return csv;
  }
}
