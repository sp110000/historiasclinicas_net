import '../../ihce/reloj.dart';
import '../../models/medico.dart';
import '../../pais/perfil_pais.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../utils/fechas.dart';
import '../../utils/ids.dart';
import '../../utils/numeros.dart';
import '../indice/indice_pacientes.dart';
import '../indice/sellar_evolucion.dart';
import '../modelos/ficha_paciente.dart';
import '../modelos/medicion.dart';
import '../reglas/estetica.dart';
import '../repositorio/repositorio.dart';
import '../seguimiento/seguimiento.dart';
import 'plantilla_procedimiento.dart';
import 'valoracion.dart';

/// Plantillas de procedimiento, valoraciones (y, desde la 5.3c, el
/// consentimiento y las sesiones), descifradas mientras está abierto.
class ProcedimientosConsultorio {
  ProcedimientosConsultorio(
    this._repo,
    this._indice,
    this._seguimiento, {
    this.reloj = const RelojSistema(),
  });

  final RepositorioConsultorio _repo;
  final IndicePacientes _indice;
  final SeguimientoConsultorio _seguimiento;
  final Reloj reloj;

  final _plantillas = <String, PlantillaProcedimiento>{};
  final _valoraciones = <String, Valoracion>{};

  Future<void> cargar() async {
    final p = await _repo.leerColeccionTolerante(
      PlantillaProcedimiento.coleccion,
    );
    final v = await _repo.leerColeccionTolerante(Valoracion.coleccion);
    olvidar();
    for (final e in p.registros.entries) {
      try {
        _plantillas[e.key] = PlantillaProcedimiento.desdeMapa(e.key, e.value);
      } on Object {
        // Ilegible: se ignora (el respaldo conserva el original).
      }
    }
    for (final e in v.registros.entries) {
      try {
        _valoraciones[e.key] = Valoracion.desdeMapa(e.key, e.value);
      } on Object {
        // Ídem.
      }
    }
  }

  void olvidar() {
    _plantillas.clear();
    _valoraciones.clear();
  }

  // ─────────────────────────── Plantillas ───────────────────────────

  List<PlantillaProcedimiento> get plantillas => [
    for (final b in plantillasProcedimientoBase) _plantillas[b.id] ?? b,
    for (final p in _plantillas.values)
      if (!plantillasProcedimientoBase.any((b) => b.id == p.id)) p,
  ];

  PlantillaProcedimiento? plantilla(String id) =>
      plantillas.where((p) => p.id == id).firstOrNull;

  PlantillaProcedimiento _plantilla(String id) {
    final p = plantilla(id);
    if (p == null) throw StateError('No existe el procedimiento.');
    return p;
  }

  Future<PlantillaProcedimiento> guardarBorrador(
    String id,
    DefinicionProcedimiento d,
  ) async {
    if (d.nombre.trim().isEmpty) throw StateError('Escribe el nombre.');
    final nueva = _plantilla(id).conBorrador(d);
    await _repo.guardar(PlantillaProcedimiento.coleccion, id, nueva.aMapa());
    _plantillas[id] = nueva;
    return nueva;
  }

  /// Aprueba el borrador. Lanza [StateError] si le falta algo del
  /// protocolo (ver [DefinicionProcedimiento.faltantes]).
  Future<PlantillaProcedimiento> aprobar(String id) async {
    final nueva = _plantilla(id).aprobada(reloj.ahora());
    await _repo.guardar(PlantillaProcedimiento.coleccion, id, nueva.aMapa());
    _plantillas[id] = nueva;
    return nueva;
  }

  /// La definición vigente de [id]. Lanza [StateError] si no está
  /// aprobada (una plantilla sin aprobar no se usa).
  VersionProcedimiento vigente(String id) {
    final p = _plantilla(id);
    final v = p.vigente;
    if (v == null) {
      throw StateError(
        'La plantilla «${p.nombre}» no está aprobada: escribe tu protocolo '
        'y apruébala en Ajustes → Procedimientos.',
      );
    }
    return v;
  }

  // ─────────────────────────── Valoraciones ───────────────────────────

  Valoracion? valoracion(String id) => _valoraciones[id];

  /// Las de la ficha (y de las unidas a ella), de la más vieja a la más
  /// reciente.
  List<Valoracion> valoracionesDe(String pacienteId) {
    final ids = _indice.idsUnidos(pacienteId);
    return [
      for (final v in _valoraciones.values)
        if (ids.contains(v.pacienteId)) v,
    ]..sort((a, b) => a.fecha.compareTo(b.fecha));
  }

  /// Borrador de una valoración nueva con la plantilla vigente: los ítems
  /// sin responder y el peso y la talla de la última medición. Lanza
  /// [StateError] si la plantilla no está aprobada o por la edad.
  Valoracion nuevaValoracion(FichaPaciente ficha, String plantillaId) {
    final ahora = reloj.ahora();
    final bloqueo = bloqueoPorEdad(ficha, ahora);
    if (bloqueo != null) throw StateError(bloqueo);
    final v = vigente(plantillaId);
    final d = v.definicion;
    double? ultimo(double? Function(Medicion m) campo) {
      for (final m in _seguimiento.medicionesDe(ficha.id).reversed) {
        final x = campo(m);
        if (x != null) return x;
      }
      return null;
    }

    return Valoracion(
      id: '',
      pacienteId: ficha.id,
      plantillaId: plantillaId,
      version: v.version,
      fecha: ahora,
      creado: ahora,
      edad: edadConFechaNacimiento(ficha, ahora),
      peso: ultimo((m) => m.peso),
      talla: ultimo((m) => m.talla),
      respuestas: [for (final i in d.items) RespuestaValoracion(item: i)],
      tamizajes: [
        for (final t in d.tamizajes)
          TamizajeAplicado(
            instrumento: t,
            respuestas: List<int?>.filled(t.numeroItems, null),
          ),
      ],
    );
  }

  /// Sella la valoración como evolución en la historia más reciente de la
  /// ficha (pregunta 29) y la guarda. Lanza [StateError] si algo no
  /// cuadra (edad, plantilla, respuestas, resultado o motivo).
  Future<(Valoracion, EvolucionSellada)> sellarValoracion(
    Valoracion v,
    FichaPaciente ficha, {
    required Medico medico,
    required Pais pais,
    FuentesPdf? fuentes,
  }) async {
    if (v.sellada) throw StateError('La valoración ya está sellada.');
    final ahora = reloj.ahora();
    final bloqueo = bloqueoPorEdad(ficha, ahora);
    if (bloqueo != null) throw StateError(bloqueo);
    final version = vigente(v.plantillaId);
    if (version.version != v.version) {
      throw StateError(
        'La plantilla cambió de versión: empieza la valoración de nuevo.',
      );
    }
    final problemas = problemasValoracion(v);
    if (problemas.isNotEmpty) throw StateError(problemas.first);
    final d = version.definicion;
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final lista = v.copyWith(
      fecha: ahora,
      edad: edadConFechaNacimiento(ficha, ahora),
      vigenteHasta: v.resultado == ResultadoValoracion.apto
          ? hoy.add(Duration(days: d.vigenciaDias))
          : null,
    );
    final sellada = await sellarEvolucionEnHistoria(
      _indice,
      pacienteId: ficha.id,
      texto: textoValoracion(lista, d, version: version.version),
      medico: medico,
      pais: pais,
      ahora: ahora,
      fuentes: fuentes,
    );
    final id = nuevoUuid();
    final guardada = lista.copyWith(
      id: id,
      historiaId: sellada.historiaId,
      revision: sellada.revision,
      huellaEvolucion: sellada.huella,
    );
    await _repo.guardar(Valoracion.coleccion, id, guardada.aMapa());
    _valoraciones[id] = guardada;
    return (guardada, sellada);
  }
}

String _zona(ZonaValorada z) => [
  z.zona,
  z.pinzable
      ? 'grasa pinzable ${formatoNumero(z.pinzableCm ?? 0)} cm'
      : 'sin grasa pinzable',
  'elasticidad ${z.elasticidad.etiqueta.toLowerCase()}',
  'flacidez ${z.flacidez}',
].join(', ');

/// Texto que se sella como evolución (todo lo clínico de la valoración).
String textoValoracion(
  Valoracion v,
  DefinicionProcedimiento d, {
  required int version,
}) {
  final contra = [
    for (final r in v.respuestas)
      if (r.si == true && r.item.efecto != EfectoItem.precaucion)
        '${r.item.texto} (${r.item.efecto.etiqueta.toLowerCase()})'
            '${r.nota.trim().isEmpty ? '' : ': ${r.nota.trim()}'}',
  ];
  final precauciones = [
    for (final r in v.respuestas)
      if (r.si == true && r.item.efecto == EfectoItem.precaucion)
        '${r.item.texto}: ${r.nota.trim()}',
  ];
  final imc = v.imc;
  final r = v.resultado!;
  return [
    'Valoración para ${d.nombre} (plantilla v$version).',
    if (v.edad != null) 'Edad ${v.edad} años.',
    [
      if (v.peso != null) 'Peso ${formatoNumero(v.peso!)} kg',
      if (v.talla != null) 'talla ${formatoNumero(v.talla!)} cm',
      if (imc != null) 'IMC ${formatoNumero(imc, decimales: 1)}',
    ].join(', ').let((s) => s.isEmpty ? '' : '$s.'),
    'Zonas: ${v.zonas.map(_zona).join('; ')}.',
    'Expectativas ${v.expectativasRealistas! ? 'realistas' : 'no realistas'}'
        '${v.notaExpectativas.trim().isEmpty ? '' : ' (${v.notaExpectativas.trim()})'}.',
    'Contraindicaciones: ${contra.isEmpty ? 'ninguna' : contra.join('; ')}.',
    if (precauciones.isNotEmpty) 'Precauciones: ${precauciones.join('; ')}.',
    if (v.tamizajes.isNotEmpty)
      'Tamizaje: ${v.tamizajes.map((t) => t.texto).join('; ')}.',
    'Resultado: ${r.etiqueta.toUpperCase()}'
        '${v.vigenteHasta == null ? '' : ' (vigente hasta el ${formatoFecha(v.vigenteHasta!)})'}.',
    if (v.motivo.trim().isNotEmpty) 'Motivo: ${v.motivo.trim()}.',
    if (v.recomendacion.trim().isNotEmpty)
      'Recomendación: ${v.recomendacion.trim()}.',
  ].where((s) => s.isNotEmpty).join(' ');
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
