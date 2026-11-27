import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../ihce/reloj.dart';
import '../../integridad/json_canonico.dart';
import '../../models/mapa.dart';
import '../../models/medico.dart';
import '../../pais/perfil_pais.dart';
import '../../pdf/adjuntos_pdf.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../utils/ids.dart';
import '../fotos/foto_procesada.dart';
import '../indice/indice_pacientes.dart';
import '../indice/sellar_evolucion.dart';
import '../modelos/ficha_paciente.dart';
import '../repositorio/bitacora.dart';
import '../repositorio/repositorio.dart';
import 'estudio_imagen.dart';
import 'informe_eco_pdf.dart';
import 'plantillas_eco.dart';

/// Los estudios de imágenes del consultorio (por ahora, ecografías): el
/// informe en borrador, sus imágenes cifradas y, al cerrarlo, su número y
/// su PDF firmado.
class ImagenesConsultorio {
  ImagenesConsultorio(
    this._repo,
    this._indice, {
    required String Function() serie,
    this.reloj = const RelojSistema(),
  }) : _serie = serie;

  final RepositorioConsultorio _repo;
  final IndicePacientes _indice;
  final String Function() _serie;
  final Reloj reloj;

  static const coleccionConsecutivos = 'consecutivos';

  final _estudios = <String, EstudioImagen>{};

  static const coleccionPlantillas = 'configuracion';
  static const idPlantillas = 'plantillasEco';

  /// Las plantillas editadas o creadas en Ajustes, por id.
  final _plantillas = <String, PlantillaEco>{};

  Future<void> cargar() async {
    final r = await _repo.leerColeccionTolerante(EstudioImagen.coleccion);
    final p = await _repo.leer(coleccionPlantillas, idPlantillas);
    _plantillas.clear();
    for (final m
        in p?.listaMapas('plantillas') ?? const <Map<String, Object?>>[]) {
      try {
        final x = PlantillaEco.desdeMapa(m);
        _plantillas[x.id] = x;
      } on Object {
        // Ilegible: queda la de base.
      }
    }
    _estudios.clear();
    for (final e in r.registros.entries) {
      try {
        _estudios[e.key] = EstudioImagen.desdeMapa(e.key, e.value);
      } on Object {
        // Un registro ilegible no impide abrir el consultorio.
      }
    }
  }

  void olvidar() {
    _estudios.clear();
    _plantillas.clear();
  }

  // ─────────────────────────── Plantillas ───────────────────────────

  /// Las de base (con los cambios del médico) y después las propias.
  List<PlantillaEco> get plantillas => [
    for (final b in plantillasEcoBase) _plantillas[b.id] ?? b,
    for (final p in _plantillas.values)
      if (p.propia) p,
  ];

  PlantillaEco? plantilla(String id) => _plantillas[id] ?? plantillaEco(id);

  /// Es de base y tiene cambios del médico.
  bool editada(String id) =>
      !id.startsWith(PlantillaEco.prefijoPropia) && _plantillas.containsKey(id);

  /// Una plantilla propia nueva, copia de [base].
  PlantillaEco nuevaPlantilla(PlantillaEco base) => base.conId(
    '${PlantillaEco.prefijoPropia}${nuevoUuid()}',
    nombre: '${base.nombre} (propia)',
  );

  Future<void> guardarPlantilla(PlantillaEco p) async {
    if (p.nombre.trim().isEmpty) {
      throw StateError('La plantilla necesita nombre.');
    }
    if (p.secciones.isEmpty) {
      throw StateError('La plantilla necesita al menos una sección.');
    }
    await _guardarPlantillas({..._plantillas, p.id: p});
  }

  /// Vuelve a la de base, o quita la propia.
  Future<void> restaurarPlantilla(String id) async =>
      _guardarPlantillas({..._plantillas}..remove(id));

  Future<void> _guardarPlantillas(Map<String, PlantillaEco> todas) async {
    await _repo.guardar(coleccionPlantillas, idPlantillas, {
      'plantillas': [for (final p in todas.values) p.aMapa()],
    });
    _plantillas
      ..clear()
      ..addAll(todas);
    await registrarEnBitacora(
      _repo,
      AccionBitacora.cambiarAjustes,
      fecha: reloj.ahora(),
      resumen: 'Plantillas de ecografía',
    );
  }

  EstudioImagen? estudio(String id) => _estudios[id];

  /// Todos, del más reciente al más viejo.
  List<EstudioImagen> get estudios =>
      _estudios.values.toList()..sort((a, b) => b.fecha.compareTo(a.fecha));

  /// Los de la ficha (y de las unidas a ella), del más reciente al más viejo.
  List<EstudioImagen> estudiosDe(String pacienteId) {
    final ids = _indice.idsUnidos(pacienteId);
    return [
      for (final e in estudios)
        if (ids.contains(e.pacienteId)) e,
    ];
  }

  /// El equipo del último estudio, para sugerirlo en el siguiente.
  String get ultimoEquipo {
    for (final e in estudios) {
      if (e.equipo.trim().isNotEmpty) return e.equipo.trim();
    }
    return '';
  }

  /// Un estudio nuevo en borrador para [ficha] con la plantilla [p].
  Future<EstudioImagen> crear(FichaPaciente ficha, PlantillaEco p) async {
    final e = EstudioImagen.nuevo(
      id: nuevoUuid(),
      pacienteId: ficha.id,
      p: p,
      ahora: reloj.ahora(),
      equipo: ultimoEquipo,
    );
    await _guardar(e);
    return e;
  }

  Future<void> _guardar(EstudioImagen e) async {
    await _repo.guardar(EstudioImagen.coleccion, e.id, e.aMapa());
    _estudios[e.id] = e;
  }

  EstudioImagen _borrador(String id) {
    final e = _estudios[id];
    if (e == null) throw StateError('No se encontró el estudio.');
    if (!e.borrador) {
      throw StateError('El informe ya se cerró: no se puede cambiar.');
    }
    return e;
  }

  /// Guarda los cambios del borrador. Lanza [StateError] si ya se cerró.
  Future<EstudioImagen> guardar(EstudioImagen e) async {
    _borrador(e.id);
    final g = e.copyWith(actualizado: reloj.ahora());
    await _guardar(g);
    return g;
  }

  /// Agrega una imagen ya procesada (JPEG sin metadatos). Va al informe si
  /// todavía cabe.
  Future<EstudioImagen> agregarImagen(
    String estudioId,
    FotoProcesada p, {
    String rotulo = '',
  }) async {
    final e = _borrador(estudioId);
    final imagen = ImagenEstudio(
      id: nuevoUuid(),
      ancho: p.ancho,
      alto: p.alto,
      sha256: sha256.convert(p.jpeg).toString(),
      rotulo: rotulo,
      enInforme: e.imagenesInforme.length < maxImagenesInforme,
    );
    await _repo.guardarBinario(
      EstudioImagen.tipoBinarioImagen,
      imagen.id,
      p.jpeg,
    );
    await _repo.guardarBinario(
      EstudioImagen.tipoMiniatura,
      imagen.id,
      p.miniatura,
    );
    return guardar(e.copyWith(imagenes: [...e.imagenes, imagen]));
  }

  /// Quita una imagen del borrador y borra sus archivos.
  Future<EstudioImagen> quitarImagen(String estudioId, String imagenId) async {
    final e = _borrador(estudioId);
    await _repo.borrarBinarios([
      (EstudioImagen.tipoBinarioImagen, imagenId),
      (EstudioImagen.tipoMiniatura, imagenId),
    ]);
    return guardar(
      e.copyWith(
        imagenes: [
          for (final i in e.imagenes)
            if (i.id != imagenId) i,
        ],
      ),
    );
  }

  Future<Uint8List?> bytesImagen(String imagenId) =>
      _repo.leerBinario(EstudioImagen.tipoBinarioImagen, imagenId);

  Future<Uint8List?> miniatura(String imagenId) =>
      _repo.leerBinario(EstudioImagen.tipoMiniatura, imagenId);

  /// Borra un borrador con sus imágenes (un estudio cerrado se anula).
  Future<void> borrarBorrador(String id) async {
    final e = _borrador(id);
    await _repo.borrarBinarios([
      for (final i in e.imagenes) ...[
        (EstudioImagen.tipoBinarioImagen, i.id),
        (EstudioImagen.tipoMiniatura, i.id),
      ],
    ]);
    await _repo.guardarVarios([Escritura(EstudioImagen.coleccion, id, null)]);
    _estudios.remove(id);
  }

  Future<ContenidoEstudioPdf> _contenido(
    EstudioImagen e, {
    required Medico medico,
    required Pais pais,
    String? numero,
    String? huella,
    List<AdjuntoPdf> adjuntos = const [],
  }) async {
    final ficha = _indice.fichaActiva(e.pacienteId);
    final copia = instantaneaMedico(medico, pais: pais);
    return ContenidoEstudioPdf(
      estudio: e,
      paciente: ficha?.nombreCompleto ?? 'Paciente',
      documentoPaciente: ficha?.documentoTexto ?? '',
      edad: ficha?.edadAnios(e.fecha),
      medico: medico.configurado ? Autor.desdeMapa(copia.autor) : null,
      recursos: copia.recursos,
      imagenes: {
        for (final i in e.imagenesInforme.take(maxImagenesInforme))
          i.id: ?await bytesImagen(i.id),
      },
      numero: numero,
      huella: huella,
      adjuntos: adjuntos,
    );
  }

  /// El PDF como saldría ahora, sin número (vista previa). No guarda nada.
  Future<Uint8List> vistaPrevia(
    EstudioImagen e, {
    required Medico medico,
    required Pais pais,
    FuentesPdf? fuentes,
  }) async => generarPdfEstudio(
    await _contenido(e, medico: medico, pais: pais),
    fuentes: fuentes,
  );

  Future<String> _siguienteNumero() async {
    final serie = _serie();
    final clave = '${EstudioImagen.prefijo}$serie';
    final r = await _repo.leer(coleccionConsecutivos, clave);
    final n = ((r?['ultimo'] as num?)?.toInt() ?? 0) + 1;
    await _repo.guardar(coleccionConsecutivos, clave, {'ultimo': n});
    return '${EstudioImagen.prefijo}-$serie${n.toString().padLeft(6, '0')}';
  }

  /// Cierra el informe: le da su número, sella `ecografia.json` dentro del
  /// PDF y guarda el PDF (cifrado). Desde entonces no se edita. Lanza
  /// [StateError] con lo que falte.
  Future<(EstudioImagen, Uint8List)> cerrar(
    String id, {
    required Medico medico,
    required Pais pais,
    FuentesPdf? fuentes,
  }) async {
    final e = _borrador(id);
    final faltan = e.faltantes;
    if (faltan.isNotEmpty) {
      throw StateError('Para cerrar el informe falta ${faltan.join(', ')}.');
    }
    final ahora = reloj.ahora();
    final numero = await _siguienteNumero();
    final ficha = _indice.fichaActiva(e.pacienteId);
    final copia = instantaneaMedico(medico, pais: pais);
    final sellado = e.sellado(
      numero: numero,
      cerrado: ahora,
      autor: medico.configurado ? copia.autor : null,
      paciente: ficha == null
          ? null
          : {
              'nombre': ficha.nombreCompleto,
              if (ficha.documentoTexto.isNotEmpty)
                'documento': ficha.documentoTexto,
            },
    );
    final huella = sha256Canonico(sellado);
    final pdf = await generarPdfEstudio(
      await _contenido(
        e,
        medico: medico,
        pais: pais,
        numero: numero,
        huella: huella,
        adjuntos: [
          AdjuntoPdf(
            EstudioImagen.nombreAdjunto,
            EstudioImagen.jsonSellado(sellado),
          ),
        ],
      ),
      fuentes: fuentes,
    );
    final cerrado = e.copyWith(
      estado: EstadoEstudio.cerrado,
      numero: numero,
      cerrado: ahora,
      sha256: huella,
      actualizado: ahora,
    );
    await _repo.guardarBinario(EstudioImagen.tipoBinarioPdf, id, pdf);
    await _guardar(cerrado);
    await registrarEnBitacora(
      _repo,
      AccionBitacora.cerrarEstudio,
      fecha: ahora,
      resumen: numero,
    );
    return (cerrado, pdf);
  }

  /// Anota el informe cerrado [id] como evolución sellada en la historia
  /// más reciente del paciente. Lanza [StateError] si no está cerrado, si
  /// ya se anotó o si el paciente no tiene historia.
  Future<EvolucionSellada> anotarEnEvolucion(
    String id, {
    required Medico medico,
    required Pais pais,
    FuentesPdf? fuentes,
  }) async {
    final e = _estudios[id];
    if (e == null || e.estado != EstadoEstudio.cerrado) {
      throw StateError('Solo se anota un informe cerrado.');
    }
    if (e.huellaEvolucion != null) {
      throw StateError('Este informe ya está anotado en la evolución.');
    }
    final sellada = await sellarEvolucionEnHistoria(
      _indice,
      pacienteId: e.pacienteId,
      texto: e.textoEvolucion,
      medico: medico,
      pais: pais,
      ahora: reloj.ahora(),
      fuentes: fuentes,
    );
    await _guardar(e.copyWith(huellaEvolucion: sellada.huella));
    return sellada;
  }

  Future<Uint8List?> pdfDe(String id) =>
      _repo.leerBinario(EstudioImagen.tipoBinarioPdf, id);

  /// Anula un informe cerrado, con motivo. El número no se reutiliza.
  Future<EstudioImagen> anular(String id, {required String motivo}) async {
    final e = _estudios[id];
    if (e == null || e.estado != EstadoEstudio.cerrado) {
      throw StateError('Solo se anula un informe cerrado.');
    }
    if (motivo.trim().isEmpty) throw StateError('Escribe el motivo.');
    final ahora = reloj.ahora();
    final anulado = e.copyWith(
      estado: EstadoEstudio.anulado,
      motivoAnulacion: motivo.trim(),
      actualizado: ahora,
    );
    await _guardar(anulado);
    await registrarEnBitacora(
      _repo,
      AccionBitacora.anularEstudio,
      fecha: ahora,
      resumen: e.numero ?? '',
    );
    return anulado;
  }

  /// `Ecografia_PENA_EC-000001.pdf` (solo ASCII).
  String nombreArchivo(EstudioImagen e) {
    final ficha = _indice.fichaActiva(e.pacienteId);
    String ascii(String s) => s
        .toUpperCase()
        .replaceAll(RegExp('[ÁÀÄÂ]'), 'A')
        .replaceAll(RegExp('[ÉÈËÊ]'), 'E')
        .replaceAll(RegExp('[ÍÌÏÎ]'), 'I')
        .replaceAll(RegExp('[ÓÒÖÔ]'), 'O')
        .replaceAll(RegExp('[ÚÙÜÛ]'), 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final apellido = ascii(ficha?.primerApellido ?? '');
    return 'Ecografia_${apellido.isEmpty ? 'PACIENTE' : apellido}_'
        '${e.numero ?? 'borrador'}.pdf';
  }
}
