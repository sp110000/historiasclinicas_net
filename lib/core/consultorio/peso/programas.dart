import 'dart:typed_data';

import '../../ihce/reloj.dart';
import '../../models/medico.dart';
import '../../pais/perfil_pais.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../utils/ids.dart';
import '../../utils/numeros.dart';
import '../documentos/plantillas.dart';
import '../indice/indice_pacientes.dart';
import '../modelos/ficha_paciente.dart';
import '../modelos/medicion.dart';
import '../reglas/glp1.dart';
import '../repositorio/repositorio.dart';
import 'catalogo_glp1.dart';
import 'indicaciones_pdf.dart';
import 'plantillas_plan.dart';
import 'programa_peso.dart';

/// Avance del peso desde el inicio del programa.
class ProgresoPeso {
  const ProgresoPeso({
    required this.inicial,
    required this.actual,
    required this.fechaActual,
    this.meta,
  });

  final double inicial;
  final double actual;
  final DateTime fechaActual;
  final double? meta;

  /// Cambio en % desde el inicio (negativo si bajó).
  double get porcentaje => (actual - inicial) / inicial * 100;

  /// Kilos que faltan para la meta (0 si ya llegó).
  double? get faltan =>
      meta == null ? null : (actual - meta!).clamp(0, double.infinity);
}

/// Programas de peso, catálogo GLP-1 y plantillas de plan (5.3),
/// descifrados mientras el consultorio está abierto.
class ProgramasPeso {
  ProgramasPeso(this._repo, this._indice, {this.reloj = const RelojSistema()});

  final RepositorioConsultorio _repo;
  final IndicePacientes _indice;
  final Reloj reloj;

  final _programas = <String, ProgramaPeso>{};
  final _catalogo = <String, MedicamentoGlp1>{};
  final _plantillas = <String, PlantillaPlan>{};

  Future<void> cargar() async {
    final p = await _repo.leerColeccionTolerante(ProgramaPeso.coleccion);
    final c = await _repo.leerColeccionTolerante(MedicamentoGlp1.coleccion);
    final t = await _repo.leerColeccionTolerante(PlantillaPlan.coleccion);
    olvidar();
    for (final e in p.registros.entries) {
      try {
        _programas[e.key] = ProgramaPeso.desdeMapa(e.key, e.value);
      } on Object {
        // Ilegible: se ignora (el respaldo conserva el original).
      }
    }
    for (final e in c.registros.entries) {
      try {
        _catalogo[e.key] = MedicamentoGlp1.desdeMapa(e.key, e.value);
      } on Object {
        // Ídem.
      }
    }
    for (final e in t.registros.entries) {
      try {
        _plantillas[e.key] = PlantillaPlan.desdeMapa(e.key, e.value);
      } on Object {
        // Ídem.
      }
    }
  }

  void olvidar() {
    _programas.clear();
    _catalogo.clear();
    _plantillas.clear();
  }

  // ─────────────────────────── Catálogo ───────────────────────────

  /// El catálogo: el de fábrica con lo que el médico editó encima.
  List<MedicamentoGlp1> get catalogo => [
    for (final m in catalogoGlp1Base) _catalogo[m.id] ?? m,
    for (final m in _catalogo.values)
      if (!catalogoGlp1Base.any((b) => b.id == m.id)) m,
  ];

  MedicamentoGlp1? medicamento(String id) =>
      catalogo.where((m) => m.id == id).firstOrNull;

  /// Guarda el registro, la indicación o el esquema. Cambiar el esquema lo
  /// deja otra vez sin aprobar.
  Future<MedicamentoGlp1> guardarMedicamento(MedicamentoGlp1 m) async {
    final antes = medicamento(m.id);
    final cambioEsquema =
        antes == null ||
        antes.esquema.map((p) => p.texto).join('|') !=
            m.esquema.map((p) => p.texto).join('|');
    final guardado = m.copyWith(
      esquemaAprobadoEn: cambioEsquema ? null : m.esquemaAprobadoEn,
      actualizado: reloj.ahora(),
    );
    await _repo.guardar(MedicamentoGlp1.coleccion, m.id, guardado.aMapa());
    _catalogo[m.id] = guardado;
    return guardado;
  }

  Future<MedicamentoGlp1> aprobarEsquema(String id) async {
    final m = medicamento(id);
    if (m == null) throw StateError('No está en el catálogo.');
    if (m.esquema.isEmpty) {
      throw StateError('Escribe el esquema de titulación antes de aprobarlo.');
    }
    final aprobado = m.copyWith(
      esquemaAprobadoEn: reloj.ahora(),
      actualizado: reloj.ahora(),
    );
    await _repo.guardar(MedicamentoGlp1.coleccion, id, aprobado.aMapa());
    _catalogo[id] = aprobado;
    return aprobado;
  }

  // ─────────────────────── Plantillas de plan ───────────────────────

  List<PlantillaPlan> get plantillas => [
    for (final b in plantillasPlanBase) _plantillas[b.id] ?? b,
    for (final p in _plantillas.values)
      if (!plantillasPlanBase.any((b) => b.id == p.id)) p,
  ];

  PlantillaPlan? plantilla(String id) =>
      plantillas.where((p) => p.id == id).firstOrNull;

  Future<PlantillaPlan> guardarBorradorPlan(
    String id,
    String titulo,
    String cuerpo,
  ) async {
    final p = plantilla(id);
    if (p == null) throw StateError('No existe la plantilla.');
    final nueva = p.conBorrador(titulo.trim(), cuerpo.trim());
    await _repo.guardar(PlantillaPlan.coleccion, id, nueva.aMapa());
    _plantillas[id] = nueva;
    return nueva;
  }

  Future<PlantillaPlan> aprobarPlan(String id) async {
    final p = plantilla(id);
    if (p == null) throw StateError('No existe la plantilla.');
    final nueva = p.aprobada(reloj.ahora());
    await _repo.guardar(PlantillaPlan.coleccion, id, nueva.aMapa());
    _plantillas[id] = nueva;
    return nueva;
  }

  /// El plan para el paciente desde la versión aprobada de [plantillaId],
  /// con los marcadores rellenados.
  PlanAsignado asignarPlan(
    String plantillaId, {
    required String paciente,
    String proteina = '',
    double? metaPeso,
  }) {
    final p = plantilla(plantillaId);
    final v = p?.vigente;
    if (p == null || v == null) {
      throw StateError(
        'La plantilla «${p?.nombre ?? plantillaId}» está en borrador: '
        'revísala y apruébala en Ajustes.',
      );
    }
    final ahora = reloj.ahora();
    return PlanAsignado(
      plantillaId: p.id,
      version: v.version,
      nombre: v.titulo,
      texto: rellenarPlantilla(v.cuerpo, {
        'paciente': paciente,
        'proteina': proteina,
        'metaPeso': metaPeso == null ? '' : '${formatoNumero(metaPeso)} kg',
        'fecha':
            '${ahora.day.toString().padLeft(2, '0')}/'
            '${ahora.month.toString().padLeft(2, '0')}/${ahora.year}',
      }),
    );
  }

  // ─────────────────────────── Programas ───────────────────────────

  ProgramaPeso? programa(String id) => _programas[id];

  /// El programa de la ficha (o de una unida a ella), o `null`.
  ProgramaPeso? programaDe(String pacienteId) {
    final ids = _indice.idsUnidos(pacienteId);
    final propios = _programas.values
        .where((p) => ids.contains(p.pacienteId))
        .toList();
    if (propios.isEmpty) return null;
    propios.sort((a, b) {
      if (a.estado != b.estado) {
        return a.estado.index.compareTo(b.estado.index);
      }
      return b.actualizado.compareTo(a.actualizado);
    });
    return propios.first;
  }

  /// Guarda un programa nuevo (sin [ProgramaPeso.id]) o editado.
  Future<ProgramaPeso> guardar(ProgramaPeso p) async {
    if (p.metaPeso != null && (p.metaPeso! < 20 || p.metaPeso! > 400)) {
      throw StateError('El peso meta no es plausible.');
    }
    final id = p.id.isEmpty ? nuevoUuid() : p.id;
    final guardado = p.copyWith(id: id, actualizado: reloj.ahora());
    await _repo.guardar(ProgramaPeso.coleccion, id, guardado.aMapa());
    _programas[id] = guardado;
    return guardado;
  }

  ProgramaPeso _de(String programaId) {
    final p = _programas[programaId];
    if (p == null) throw StateError('No existe el programa.');
    return p;
  }

  /// Guarda la revisión de la lista. Lanza [StateError] si una precaución
  /// en «sí» o «no sabe» no tiene nota.
  Future<ProgramaPeso> revisarContraindicaciones(
    String programaId,
    Map<String, RespuestaItem> respuestas, {
    String? sexo,
  }) async {
    final revision = RevisionContraindicaciones(
      fecha: reloj.ahora(),
      respuestas: respuestas,
    );
    final e = evaluarContraindicaciones(revision, sexo: sexo);
    if (e.faltanNotas.isNotEmpty) throw StateError(e.faltanNotas.first);
    return guardar(_de(programaId).copyWith(contraindicaciones: revision));
  }

  /// Inicia el GLP-1. Lanza [StateError] con el primer motivo si la lista
  /// de contraindicaciones lo impide.
  Future<ProgramaPeso> iniciarGlp1(
    String programaId, {
    required String medicamentoId,
    required DosisGlp1 dosis,
    String? sexo,
  }) async {
    final p = _de(programaId);
    final e = evaluarContraindicaciones(p.contraindicaciones, sexo: sexo);
    if (!e.permiteIniciar) throw StateError(e.motivos.first);
    if (p.glp1 != null && p.glp1!.activo) {
      throw StateError('Ya hay un GLP-1 activo: suspéndelo antes.');
    }
    final m = medicamento(medicamentoId);
    if (m == null) throw StateError('No está en el catálogo.');
    if (dosis.dosis <= 0) throw StateError('Escribe la dosis.');
    return guardar(
      p.copyWith(
        glp1: TratamientoGlp1(
          medicamentoId: m.id,
          nombre: m.nombre,
          inicio: dosis.fecha,
          registroInvima: m.registroInvima,
          indicacion: m.indicacion,
          dosis: [dosis],
        ),
      ),
    );
  }

  TratamientoGlp1 _glp1(ProgramaPeso p) {
    final g = p.glp1;
    if (g == null || !g.activo) throw StateError('No hay un GLP-1 activo.');
    return g;
  }

  Future<ProgramaPeso> cambiarDosis(String programaId, DosisGlp1 dosis) {
    final p = _de(programaId);
    final g = _glp1(p);
    if (dosis.dosis <= 0) throw StateError('Escribe la dosis.');
    return guardar(p.copyWith(glp1: g.copyWith(dosis: [...g.dosis, dosis])));
  }

  Future<ProgramaPeso> registrarTolerancia(
    String programaId,
    RegistroTolerancia t,
  ) {
    final p = _de(programaId);
    final g = p.glp1;
    if (g == null) throw StateError('No hay un GLP-1 registrado.');
    if (t.sintomas.trim().isEmpty) throw StateError('Escribe los síntomas.');
    return guardar(
      p.copyWith(glp1: g.copyWith(tolerancia: [...g.tolerancia, t])),
    );
  }

  Future<ProgramaPeso> registrarEvento(String programaId, EventoAdverso e) {
    final p = _de(programaId);
    final g = p.glp1;
    if (g == null) throw StateError('No hay un GLP-1 registrado.');
    if (e.descripcion.trim().isEmpty) {
      throw StateError('Describe el evento adverso.');
    }
    return guardar(p.copyWith(glp1: g.copyWith(eventos: [...g.eventos, e])));
  }

  Future<ProgramaPeso> suspenderGlp1(String programaId, String motivo) {
    final p = _de(programaId);
    final g = _glp1(p);
    if (motivo.trim().isEmpty) throw StateError('Escribe el motivo.');
    return guardar(
      p.copyWith(
        glp1: g.copyWith(
          suspendidoEn: reloj.ahora(),
          motivoSuspension: motivo.trim(),
        ),
      ),
    );
  }

  /// Indicaciones impresas del programa (meta, planes, recordatorio y
  /// GLP-1 vigente), con la firma del médico.
  Future<Uint8List> indicacionesPdf(
    ProgramaPeso p,
    FichaPaciente ficha, {
    required Medico medico,
    required Pais pais,
    FuentesPdf? fuentes,
  }) {
    final copia = instantaneaMedico(medico, pais: pais);
    return generarIndicacionesPeso(
      programa: p,
      paciente: ficha.nombreCompleto,
      documento: ficha.documentoTexto,
      medico: medico.configurado ? Autor.desdeMapa(copia.autor) : null,
      recursos: copia.recursos,
      fuentes: fuentes,
      generadoEn: reloj.ahora(),
    );
  }

  /// Avance desde el inicio: el peso inicial es la última medición hasta
  /// el día del inicio (o la primera después); el actual, la última.
  ProgresoPeso? progreso(ProgramaPeso p, List<Medicion> mediciones) {
    final conPeso = [
      for (final m in mediciones)
        if (m.peso != null) m,
    ];
    if (conPeso.isEmpty) return null;
    final finDelInicio = DateTime(
      p.inicio.year,
      p.inicio.month,
      p.inicio.day + 1,
    );
    final antes = conPeso.where((m) => m.fecha.isBefore(finDelInicio));
    final inicial = antes.isNotEmpty ? antes.last : conPeso.first;
    final actual = conPeso.last;
    return ProgresoPeso(
      inicial: inicial.peso!,
      actual: actual.peso!,
      fechaActual: actual.fecha,
      meta: p.metaPeso,
    );
  }
}

// ─────────────── Textos para la evolución (pregunta 17) ───────────────

String _dosisConVia(TratamientoGlp1 g, DosisGlp1 d) {
  final via = g.nombre.split(' · ').skip(1).join(' · ').toLowerCase();
  return '${d.texto}${via.isEmpty ? '' : ' $via'}';
}

/// «Programa de peso: inicia Semaglutida (Ozempic®) 0,25 mg subcutánea
/// semanal. Registro Invima …. Contraindicaciones revisadas el …».
String textoInicioGlp1(TratamientoGlp1 g, RevisionContraindicaciones? r) {
  final nombre = g.nombre.split(' · ').first;
  final d = g.dosis.first;
  final precauciones = r == null
      ? const <String>[]
      : [
          for (final i in contraindicacionesGlp1)
            if (!i.absoluta &&
                r.respuestas[i.id] != null &&
                r.respuestas[i.id]!.respuesta != RespuestaContra.no)
              '${i.texto} (${r.respuestas[i.id]!.nota.trim()})',
        ];
  return [
    'Programa de peso: inicia $nombre ${_dosisConVia(g, d)}.',
    g.registroInvima.isEmpty
        ? 'Registro Invima sin confirmar.'
        : 'Registro Invima ${g.registroInvima}.',
    if (r != null)
      'Contraindicaciones revisadas el '
          '${r.fecha.day.toString().padLeft(2, '0')}/'
          '${r.fecha.month.toString().padLeft(2, '0')}/${r.fecha.year}: '
          'ninguna absoluta'
          '${precauciones.isEmpty ? '' : '; precauciones: ${precauciones.join('; ')}'}.',
  ].join(' ');
}

String textoCambioDosis(TratamientoGlp1 g, DosisGlp1 d) =>
    'Programa de peso: ${g.nombre.split(' · ').first}, cambio de dosis a '
    '${_dosisConVia(g, d)}.';

String textoEventoAdverso(TratamientoGlp1 g, EventoAdverso e) => [
  'Evento adverso con ${g.nombre.split(' · ').first}: ${e.descripcion.trim()} '
      '(${e.gravedad.etiqueta.toLowerCase()}).',
  if (e.conducta.trim().isNotEmpty) 'Conducta: ${e.conducta.trim()}.',
  e.reportadoInvima ? 'Reportado a Invima.' : 'No reportado a Invima.',
].join(' ');

String textoSuspension(TratamientoGlp1 g) =>
    'Programa de peso: se suspende ${g.nombre.split(' · ').first}. Motivo: '
    '${g.motivoSuspension}.';
