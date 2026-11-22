import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../ihce/reloj.dart';
import '../../models/medico.dart';
import '../../pais/perfil_pais.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../utils/ids.dart';
import '../documentos/documentos.dart';
import '../fotos/foto_procesada.dart';
import '../indice/indice_pacientes.dart';
import '../modelos/ficha_paciente.dart';
import '../modelos/foto.dart';
import '../modelos/medicion.dart';
import '../repositorio/bitacora.dart';
import '../repositorio/repositorio.dart';
import 'informe_pdf.dart';

/// Seguimiento antropométrico (y, desde la 5.2c, las fotos) del
/// consultorio, descifrado mientras está abierto.
class SeguimientoConsultorio {
  SeguimientoConsultorio(
    this._repo,
    this._indice,
    this._documentos, {
    this.reloj = const RelojSistema(),
  });

  final RepositorioConsultorio _repo;
  final IndicePacientes _indice;
  final DocumentosConsultorio _documentos;
  final Reloj reloj;

  final _mediciones = <String, Medicion>{};
  final _fotos = <String, Foto>{};

  Future<void> cargar() async {
    final m = await _repo.leerColeccionTolerante(Medicion.coleccion);
    final f = await _repo.leerColeccionTolerante(Foto.coleccion);
    olvidar();
    for (final e in m.registros.entries) {
      try {
        _mediciones[e.key] = Medicion.desdeMapa(e.key, e.value);
      } on Object {
        // Ilegible: se ignora (el respaldo conserva el original).
      }
    }
    for (final e in f.registros.entries) {
      try {
        _fotos[e.key] = Foto.desdeMapa(e.key, e.value);
      } on Object {
        // Ídem.
      }
    }
  }

  void olvidar() {
    _mediciones.clear();
    _fotos.clear();
  }

  // ─────────────────────────── Fotos ───────────────────────────

  Foto? foto(String id) => _fotos[id];

  /// Fotos de la ficha (y de las unidas a ella), de la más vieja a la más
  /// reciente.
  List<Foto> fotosDe(String pacienteId) {
    final ids = _indice.idsUnidos(pacienteId);
    return _fotos.values.where((f) => ids.contains(f.pacienteId)).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
  }

  /// La foto más reciente de [vista] antes de [antesDe] (para alinear la
  /// nueva en transparencia), o `null`.
  Foto? anterior(String pacienteId, VistaFoto vista, {DateTime? antesDe}) {
    Foto? r;
    for (final f in fotosDe(pacienteId)) {
      if (f.vista != vista) continue;
      if (antesDe != null && !f.fecha.isBefore(antesDe)) continue;
      r = f;
    }
    return r;
  }

  Future<Uint8List?> bytesFoto(String id) =>
      _repo.leerBinario(Foto.tipoBinario, id);

  Future<Uint8List?> miniatura(String id) =>
      _repo.leerBinario(Foto.tipoMiniatura, id);

  /// Guarda una foto ya procesada (sin metadatos). Exige el consentimiento
  /// de imagen vigente con el uso clínico (pregunta 22): sin él lanza
  /// [StateError].
  Future<Foto> guardarFoto({
    required String pacienteId,
    required VistaFoto vista,
    required FotoProcesada procesada,
    DateTime? fecha,
    String zona = '',
  }) async {
    final ficha = _indice.fichaActiva(pacienteId);
    final consentimiento = ficha == null
        ? null
        : _documentos.consentimientoImagenVigente(ficha);
    if (ficha == null || consentimiento == null) {
      throw StateError(
        'Falta el consentimiento de uso de imagen (uso clínico) para tomar '
        'fotos.',
      );
    }
    final ahora = reloj.ahora();
    final foto = Foto(
      id: nuevoUuid(),
      pacienteId: ficha.id,
      fecha: fecha ?? ahora,
      vista: vista,
      zona: zona,
      ancho: procesada.ancho,
      alto: procesada.alto,
      sha256: sha256.convert(procesada.jpeg).toString(),
      consentimientoId: consentimiento.id,
      creado: ahora,
    );
    await _repo.guardarBinario(Foto.tipoBinario, foto.id, procesada.jpeg);
    await _repo.guardarBinario(
      Foto.tipoMiniatura,
      foto.id,
      procesada.miniatura,
    );
    await _repo.guardar(Foto.coleccion, foto.id, foto.aMapa());
    _fotos[foto.id] = foto;
    return foto;
  }

  /// Borra la foto y sus binarios. Queda en la bitácora.
  Future<void> borrarFoto(String id) async {
    if (!_fotos.containsKey(id)) return;
    await _repo.guardarVarios([Escritura(Foto.coleccion, id, null)]);
    await _repo.borrarBinarios([
      (Foto.tipoBinario, id),
      (Foto.tipoMiniatura, id),
    ]);
    _fotos.remove(id);
    await registrarEnBitacora(
      _repo,
      AccionBitacora.borrarFoto,
      fecha: reloj.ahora(),
    );
  }

  Medicion? medicion(String id) => _mediciones[id];

  /// Las mediciones de la ficha (también las de fichas unidas a ella) y las
  /// de los signos sellados en sus historias, de la más vieja a la más
  /// reciente.
  List<Medicion> medicionesDe(String pacienteId) {
    final ids = _indice.idsUnidos(pacienteId);
    return [
      ..._mediciones.values.where((m) => ids.contains(m.pacienteId)),
      for (final h in _indice.historiasDe(pacienteId))
        for (final m in h.mediciones) m.copyWith(pacienteId: pacienteId),
    ]..sort((a, b) => a.fecha.compareTo(b.fecha));
  }

  /// La talla más reciente registrada (se arrastra a la medición nueva).
  double? ultimaTalla(String pacienteId) {
    for (final m in medicionesDe(pacienteId).reversed) {
      if (m.talla != null) return m.talla;
    }
    return null;
  }

  /// Guarda una medición nueva (sin [Medicion.id]) o editada. Lanza
  /// [StateError] si está vacía o el % de grasa no dice el método.
  Future<Medicion> guardarMedicion(Medicion m) async {
    if (!m.editable) {
      throw StateError('Las mediciones de una historia no se editan.');
    }
    if (m.vacia) throw StateError('Escribe al menos una medida.');
    if (m.grasa != null && m.metodoGrasa == null) {
      throw StateError('Indica con qué método se midió la grasa.');
    }
    final id = m.id.isEmpty ? nuevoUuid() : m.id;
    final guardada = Medicion.desdeMapa(id, m.aMapa());
    await _repo.guardar(Medicion.coleccion, id, guardada.aMapa());
    _mediciones[id] = guardada;
    return guardada;
  }

  Future<void> borrarMedicion(String id) async {
    final m = _mediciones[id];
    if (m == null) return;
    await _repo.guardarVarios([Escritura(Medicion.coleccion, id, null)]);
    _mediciones.remove(id);
    await registrarEnBitacora(
      _repo,
      AccionBitacora.borrarMedicion,
      fecha: reloj.ahora(),
    );
  }

  // ─────────────────────────── PDF ───────────────────────────

  PacienteInforme _paciente(FichaPaciente ficha) => PacienteInforme(
    nombre: ficha.nombreCompleto,
    documento: ficha.documentoTexto,
    edad: ficha.edadAnios(reloj.ahora()),
    sexo: opcionesSexo
        .where((o) => o.codigo == ficha.sexo)
        .map((o) => o.etiqueta)
        .firstOrNull,
  );

  Future<List<FotoConBytes>> _conBytes(Iterable<Foto> fotos) async => [
    for (final f in fotos)
      if (await bytesFoto(f.id) case final b?) (foto: f, bytes: b),
  ];

  /// Informe de seguimiento en PDF. Las fotos entran solo con
  /// [incluirFotos] (pregunta 23); si se piden, va la primera y la última
  /// de cada vista, y queda en la bitácora.
  Future<Uint8List> informePdf(
    FichaPaciente ficha, {
    required Medico medico,
    required Pais pais,
    bool incluirFotos = false,
    FuentesPdf? fuentes,
  }) async {
    final copia = instantaneaMedico(medico, pais: pais);
    final fotos = <Foto>[];
    if (incluirFotos) {
      for (final v in VistaFoto.values) {
        final deLaVista = [
          for (final f in fotosDe(ficha.id))
            if (f.vista == v) f,
        ];
        if (deLaVista.isEmpty) continue;
        fotos.add(deLaVista.first);
        if (deLaVista.length > 1) fotos.add(deLaVista.last);
      }
    }
    final pdf = await generarInformeSeguimiento(
      paciente: _paciente(ficha),
      mediciones: medicionesDe(ficha.id),
      fotos: await _conBytes(fotos),
      medico: medico.configurado ? Autor.desdeMapa(copia.autor) : null,
      recursos: copia.recursos,
      fuentes: fuentes,
      generadoEn: reloj.ahora(),
    );
    if (fotos.isNotEmpty) {
      await registrarEnBitacora(
        _repo,
        AccionBitacora.exportarFotos,
        fecha: reloj.ahora(),
      );
    }
    return pdf;
  }

  /// Todas las fotos de la ficha en un PDF («Exportar fotos del paciente»,
  /// pregunta 23). Queda en la bitácora.
  Future<Uint8List> fotosPdf(
    FichaPaciente ficha, {
    required Medico medico,
    required Pais pais,
    FuentesPdf? fuentes,
  }) async {
    final fotos = fotosDe(ficha.id);
    if (fotos.isEmpty) throw StateError('La ficha no tiene fotos.');
    final copia = instantaneaMedico(medico, pais: pais);
    final pdf = await generarPdfFotos(
      paciente: _paciente(ficha),
      fotos: await _conBytes(fotos),
      medico: medico.configurado ? Autor.desdeMapa(copia.autor) : null,
      fuentes: fuentes,
      generadoEn: reloj.ahora(),
    );
    await registrarEnBitacora(
      _repo,
      AccionBitacora.exportarFotos,
      fecha: reloj.ahora(),
    );
    return pdf;
  }
}
