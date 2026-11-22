import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../ihce/reloj.dart';
import '../../models/mapa.dart';
import '../../models/medico.dart';
import '../../pais/perfil_pais.dart';
import '../../pdf/adjuntos_pdf.dart';
import '../../pdf/fuentes_pdf.dart';
import '../../utils/fechas.dart';
import '../../utils/ids.dart';
import '../indice/indice_pacientes.dart';
import '../modelos/ficha_paciente.dart';
import '../repositorio/bitacora.dart';
import '../repositorio/repositorio.dart';
import 'documento.dart';
import 'documento_pdf.dart';
import 'plantillas.dart';

/// Un documento recién firmado y su PDF (para descargarlo).
typedef DocumentoFirmado = ({DocumentoConsultorio documento, Uint8List pdf});

/// Plantillas y documentos del consultorio, descifrados mientras está
/// abierto.
class DocumentosConsultorio {
  DocumentosConsultorio(
    this._repo,
    this._indice, {
    this.reloj = const RelojSistema(),
  });

  final RepositorioConsultorio _repo;
  final IndicePacientes _indice;
  final Reloj reloj;

  static const coleccionConsecutivos = 'consecutivos';

  final _plantillas = <TipoPlantilla, Plantilla>{};
  final _documentos = <String, DocumentoConsultorio>{};

  Future<void> cargar() async {
    final plantillas = await _repo.leerColeccionTolerante(Plantilla.coleccion);
    final documentos = await _repo.leerColeccionTolerante(
      DocumentoConsultorio.coleccion,
    );
    olvidar();
    for (final e in plantillas.registros.entries) {
      try {
        final p = Plantilla.desdeMapa(e.key, e.value);
        _plantillas[p.tipo] = p;
      } on Object {
        // Una plantilla ilegible vuelve a la de fábrica (en borrador).
      }
    }
    for (final e in documentos.registros.entries) {
      try {
        _documentos[e.key] = DocumentoConsultorio.desdeMapa(e.key, e.value);
      } on Object {
        // Se ignora: su PDF, si se descargó, sigue siendo el original.
      }
    }
  }

  void olvidar() {
    _plantillas.clear();
    _documentos.clear();
  }

  // ─────────────────────────── Plantillas ───────────────────────────

  /// La plantilla guardada, o la de fábrica (versión 1 en borrador).
  Plantilla plantilla(TipoPlantilla tipo) =>
      _plantillas[tipo] ?? Plantilla.base(tipo);

  Future<Plantilla> guardarBorrador(
    TipoPlantilla tipo, {
    required String titulo,
    required String cuerpo,
  }) async {
    final p = plantilla(tipo).conBorrador(titulo.trim(), cuerpo.trim());
    await _repo.guardar(Plantilla.coleccion, p.id, p.aMapa());
    _plantillas[tipo] = p;
    return p;
  }

  /// Aprueba el borrador: desde ahora los documentos nuevos usan esa
  /// versión. Los firmados conservan la suya.
  Future<Plantilla> aprobar(TipoPlantilla tipo) async {
    final ahora = reloj.ahora();
    final p = plantilla(tipo).aprobada(ahora);
    await _repo.guardar(Plantilla.coleccion, p.id, p.aMapa());
    _plantillas[tipo] = p;
    await registrarEnBitacora(
      _repo,
      AccionBitacora.aprobarPlantilla,
      fecha: ahora,
      resumen: '${tipo.etiqueta} v${p.vigente!.version}',
    );
    return p;
  }

  // ─────────────────────────── Documentos ───────────────────────────

  DocumentoConsultorio? documento(String id) => _documentos[id];

  /// Documentos de la ficha (y de las fichas unidas a ella), del más
  /// reciente al más viejo.
  List<DocumentoConsultorio> documentosDe(String pacienteId) {
    final ids = _indice.idsUnidos(pacienteId);
    return _documentos.values.where((d) => ids.contains(d.pacienteId)).toList()
      ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
  }

  /// El consentimiento de imagen vigente de la ficha (con el uso clínico),
  /// o `null`: sin él no se toman fotos (pregunta 22).
  DocumentoConsultorio? consentimientoImagenVigente(FichaPaciente ficha) {
    final id = (_indice.fichaActiva(ficha.id) ?? ficha).consentimientoImagenId;
    final d = id == null ? null : _documentos[id];
    return d != null && d.vigente && d.permisos.clinico ? d : null;
  }

  Future<Uint8List?> pdfDe(String id) =>
      _repo.leerBinario(DocumentoConsultorio.tipoBinarioPdf, id);

  /// Siguiente número del consecutivo [prefijo] («AD-000001»). Se asigna al
  /// firmar y no se reutiliza, aunque el documento se anule.
  Future<String> _siguienteNumero(String prefijo) async {
    final r = await _repo.leer(coleccionConsecutivos, prefijo);
    final n = (r?.entero('ultimo') ?? 0) + 1;
    await _repo.guardar(coleccionConsecutivos, prefijo, {'ultimo': n});
    return '$prefijo-${n.toString().padLeft(6, '0')}';
  }

  /// Valores de los marcadores de las plantillas.
  Map<String, String> valores(
    Medico medico, {
    FichaPaciente? ficha,
    required DateTime fecha,
  }) => {
    'responsable': [
      medico.nombre.trim(),
      if (medico.consultorio.trim().isNotEmpty) medico.consultorio.trim(),
    ].where((s) => s.isNotEmpty).join(' · '),
    'documentoResponsable': [
      medico.tipoDocumento,
      medico.documento,
    ].where((s) => s.trim().isNotEmpty).join(' '),
    'direccion': medico.direccion,
    'ciudad': medico.ciudad,
    'telefono': medico.telefono,
    'correo': medico.correo,
    if (ficha != null) 'paciente': ficha.nombreCompleto,
    if (ficha != null) 'documentoPaciente': ficha.documentoTexto,
    'fecha': formatoFecha(fecha),
  };

  /// Firma la autorización de tratamiento de datos de [ficha].
  Future<DocumentoFirmado> firmarAutorizacion({
    required FichaPaciente ficha,
    required Uint8List firmaPng,
    required Medico medico,
    required Pais pais,
    bool incluirFirma = true,
    bool incluirSello = true,
    FuentesPdf? fuentes,
  }) => firmarDocumento(
    TipoPlantilla.autorizacionDatos,
    ficha: ficha,
    firmaPng: firmaPng,
    medico: medico,
    pais: pais,
    incluirFirma: incluirFirma,
    incluirSello: incluirSello,
    fuentes: fuentes,
  );

  /// Firma un documento de [tipo] para [ficha] con la plantilla vigente.
  /// Guarda el documento, la firma y el PDF (cifrados) y lo deja ligado a
  /// la ficha. El consentimiento de imagen exige [permisos] con el uso
  /// clínico. Lanza [StateError] si la plantilla no está aprobada.
  Future<DocumentoFirmado> firmarDocumento(
    TipoPlantilla tipo, {
    required FichaPaciente ficha,
    required Uint8List firmaPng,
    required Medico medico,
    required Pais pais,
    PermisosImagen? permisos,
    bool incluirFirma = true,
    bool incluirSello = true,
    FuentesPdf? fuentes,
  }) async {
    if (!tipo.conFirmaDelPaciente) {
      throw StateError('«${tipo.etiqueta}» no se firma con el paciente.');
    }
    final imagen = tipo == TipoPlantilla.consentimientoImagen;
    if (imagen && !(permisos?.clinico ?? false)) {
      throw StateError(
        'El consentimiento de imagen necesita, al menos, el uso clínico.',
      );
    }
    final version = plantilla(tipo).vigente;
    if (version == null) {
      throw StateError(
        'La plantilla «${tipo.etiqueta}» está en borrador: revísala y '
        'apruébala en Ajustes.',
      );
    }
    final ahora = reloj.ahora();
    final numero = await _siguienteNumero(tipo.prefijo!);
    final id = nuevoUuid();
    final copia = instantaneaMedico(
      medico,
      pais: pais,
      firma: incluirFirma,
      sello: incluirSello,
    );
    final contenido = rellenarPlantilla(version.cuerpo, {
      ...valores(medico, ficha: ficha, fecha: ahora),
      if (imagen) 'permisos': permisos!.texto,
    });
    final documento = DocumentoConsultorio(
      id: id,
      creado: ahora,
      tienePdf: true,
      datos: {
        'tipo': tipo.name,
        'numero': numero,
        'titulo': version.titulo,
        'versionPlantilla': version.version,
        'pacienteId': ficha.id,
        'paciente': {
          'nombre': ficha.nombreCompleto,
          'documento': ficha.documentoTexto,
        },
        'fechaHora': fechaHoraIso(ahora),
        'contenido': contenido,
        'sha256Firma': sha256.convert(firmaPng).toString(),
        if (imagen) 'permisos': permisos!.aMapa(),
        if (medico.configurado) 'autor': copia.autor,
      },
    );
    final pdf = await generarPdfDocumento(
      ContenidoDocumentoPdf(
        titulo: version.titulo,
        cuerpo: contenido,
        fechaHora: ahora,
        numero: numero,
        version: version.version,
        paciente: ficha.nombreCompleto,
        documentoPaciente: ficha.documentoTexto,
        firmaPaciente: firmaPng,
        medico: medico.configurado ? Autor.desdeMapa(copia.autor) : null,
        recursos: copia.recursos,
        adjuntos: [AdjuntoPdf(nombreAdjuntoDocumento, documento.json)],
        huella: documento.hash,
      ),
      fuentes: fuentes,
    );
    await _repo.guardarBinario(
      DocumentoConsultorio.tipoBinarioFirma,
      id,
      firmaPng,
    );
    await _repo.guardarBinario(DocumentoConsultorio.tipoBinarioPdf, id, pdf);
    await _repo.guardar(DocumentoConsultorio.coleccion, id, documento.aMapa());
    _documentos[id] = documento;
    final actual = _indice.fichaActiva(ficha.id) ?? ficha;
    await _indice.guardarFicha(
      imagen
          ? actual.copyWith(consentimientoImagenId: id)
          : actual.copyWith(autorizacionDatosId: id),
    );
    await registrarEnBitacora(
      _repo,
      AccionBitacora.firmarDocumento,
      fecha: ahora,
      resumen: numero,
    );
    return (documento: documento, pdf: pdf);
  }

  /// PDF de la política de tratamiento de datos (versión vigente), para
  /// imprimir y exhibir. Lanza [StateError] si no está aprobada.
  Future<Uint8List> politicaPdf({
    required Medico medico,
    required Pais pais,
    FuentesPdf? fuentes,
  }) async {
    const tipo = TipoPlantilla.politicaPrivacidad;
    final version = plantilla(tipo).vigente;
    if (version == null) {
      throw StateError(
        'La política está en borrador: revísala y apruébala en Ajustes.',
      );
    }
    final copia = instantaneaMedico(medico, pais: pais);
    return generarPdfDocumento(
      ContenidoDocumentoPdf(
        titulo: version.titulo,
        cuerpo: rellenarPlantilla(
          version.cuerpo,
          valores(medico, fecha: version.aprobadaEn!),
        ),
        fechaHora: version.aprobadaEn!,
        version: version.version,
        medico: medico.configurado ? Autor.desdeMapa(copia.autor) : null,
        recursos: copia.recursos,
      ),
      fuentes: fuentes,
    );
  }

  /// Revoca (el paciente retira la autorización) o anula (un error) un
  /// documento. No se borra: queda con fecha y motivo. Si era la
  /// autorización vigente de la ficha, la ficha queda sin autorización.
  Future<void> cambiarEstado(
    String id,
    EstadoDocumento estado, {
    required String motivo,
  }) async {
    final d = _documentos[id];
    if (d == null || !d.vigente || estado == EstadoDocumento.vigente) {
      throw StateError('El documento no está vigente.');
    }
    if (motivo.trim().isEmpty) throw StateError('Escribe el motivo.');
    final ahora = reloj.ahora();
    final nuevo = d.copyWith(
      estado: estado,
      cambioEstado: ahora,
      motivoEstado: motivo.trim(),
    );
    await _repo.guardar(DocumentoConsultorio.coleccion, id, nuevo.aMapa());
    _documentos[id] = nuevo;
    final activa = _indice.fichaActiva(d.pacienteId);
    if (activa != null && activa.autorizacionDatosId == id) {
      await _indice.guardarFicha(activa.copyWith(autorizacionDatosId: null));
    }
    if (activa != null && activa.consentimientoImagenId == id) {
      await _indice.guardarFicha(activa.copyWith(consentimientoImagenId: null));
    }
    await registrarEnBitacora(
      _repo,
      estado == EstadoDocumento.revocado
          ? AccionBitacora.revocarDocumento
          : AccionBitacora.anularDocumento,
      fecha: ahora,
      resumen: d.numero,
    );
  }
}
