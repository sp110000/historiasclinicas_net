import 'dart:convert';

import '../../models/historia.dart';
import '../../models/mapa.dart';
import '../../models/medico.dart';
import '../modelo/dto.dart';
import '../modelo/prestador_ihce.dart';
import 'normalizacion.dart';

/// Instantánea de una atención cerrada: lo que guarda la outbox (cifrado)
/// para construir el RDA después, sin depender del estado de la app.
///
/// * `datos`: el `historia.json` sellado (solo lectura).
/// * `medico`: identificación del profesional al cerrar (sin imágenes).
/// * `prestador`: configuración IHCE del prestador al cerrar.
class EntradaAtencion {
  const EntradaAtencion({
    required this.datos,
    required this.revision,
    required this.medico,
    required this.prestador,
  });

  factory EntradaAtencion.capturar({
    required Map<String, Object?> datos,
    required int revision,
    required Medico medico,
    required PrestadorIhce prestador,
  }) => EntradaAtencion(
    datos: datos,
    revision: revision,
    medico: {
      for (final e in medico.aAlmacen().entries)
        if (!const {'logo', 'firma', 'sello'}.contains(e.key)) e.key: e.value,
    },
    prestador: prestador.aMapa(),
  );

  factory EntradaAtencion.desdeJson(String json) {
    final m = (jsonDecode(json) as Map).cast<String, Object?>();
    return EntradaAtencion(
      datos: m.mapa('datos'),
      revision: m.entero('revision') ?? 1,
      medico: m.mapa('medico'),
      prestador: m.mapa('prestador'),
    );
  }

  final Map<String, Object?> datos;
  final int revision;
  final Map<String, Object?> medico;
  final Map<String, Object?> prestador;

  String get atencionId => datos.texto('id');

  /// Nueva instantánea con el médico y el prestador vigentes (reintento
  /// tras corregir su configuración). Los datos clínicos sellados no cambian.
  EntradaAtencion conConfiguracion(Medico m, PrestadorIhce p) =>
      EntradaAtencion.capturar(
        datos: datos,
        revision: revision,
        medico: m,
        prestador: p,
      );

  String aJson() => jsonEncode({
    'datos': datos,
    'revision': revision,
    'medico': medico,
    'prestador': prestador,
  });
}

/// Extracción (solo lectura) y normalización a DTO tipados.
class ExtractorAtencion {
  const ExtractorAtencion();

  AtencionRda extraer(EntradaAtencion e, {required List<int> pdf}) {
    final h = HistoriaClinica.desdeMapa(e.datos);
    final p = h.paciente;
    final medico = Medico.desdeAlmacen(e.medico);
    final prestador = PrestadorIhce.desdeMapa(e.prestador);
    final nombres = normalizarTexto(p.nombres).split(' ')
      ..removeWhere((x) => x.isEmpty);
    final finalizada = e.datos.fecha('finalizadaEn') ?? h.fechaAtencion;
    return AtencionRda(
      paciente: PacienteDto(
        origen: Origen('datos.paciente', h.id),
        tipoDocumento: p.tipoDocumento.trim(),
        numeroDocumento: normalizarNumeroDocumento(p.numeroDocumento),
        primerApellido: normalizarTexto(p.primerApellido),
        segundoApellido: normalizarTexto(p.segundoApellido),
        // Primer token = primer nombre; el resto, segundo nombre
        // (MATRIZ_RDA: `name.given` 1..2).
        primerNombre: nombres.isEmpty ? '' : nombres.first,
        segundoNombre: nombres.length < 2 ? '' : nombres.skip(1).join(' '),
        fechaNacimiento: p.fechaNacimiento,
        sexo: p.sexo,
        ciudad: normalizarTexto(p.ciudad),
        nacionalidad: p.nacionalidad.trim(),
        paisResidencia: p.paisResidencia.trim(),
        etnia: p.etnia.trim(),
        discapacidad: p.discapacidad.trim(),
        zonaResidencia: p.zonaResidencia.trim(),
      ),
      profesional: ProfesionalDto(
        origen: const Origen('localStorage.hc.medico.v1', 'medico'),
        tipoDocumento: medico.tipoDocumento.trim(),
        numeroDocumento: normalizarNumeroDocumento(medico.documento),
        primerApellido: normalizarTexto(medico.primerApellido),
        segundoApellido: normalizarTexto(medico.segundoApellido),
        nombres: normalizarTexto(medico.nombres).split(' ')
          ..removeWhere((x) => x.isEmpty),
        codigoRethus: medico.codigoRethus.trim(),
        registro: medico.registro.trim(),
      ),
      prestador: PrestadorDto(
        codigoHabilitacion: prestador.codigoHabilitacion.trim(),
        modalidad: prestador.modalidad.trim(),
        entorno: prestador.entorno.trim(),
        cupsConsulta: prestador.cupsPara(h.tipoConsulta).trim(),
      ),
      encuentro: EncuentroDto(
        origen: Origen('datos', h.id),
        id: h.id,
        inicio: h.fechaAtencion,
        fin: finalizada,
        tipoConsulta: h.tipoConsulta,
        causaExterna: h.causaExterna,
      ),
      diagnosticos: [
        for (final d in h.diagnosticos)
          DiagnosticoDto(
            origen: Origen('datos.diagnosticos', d.id),
            codigoCie10: d.codigo.trim().toUpperCase().replaceAll('.', ''),
            principal: d.tipo == 'principal',
            caracter: d.caracter,
          ),
      ],
      textos: TextosLibresDto(
        alergias: [
          for (final a in h.antecedentes.alergias)
            if (a.trim().isNotEmpty) normalizarTexto(a),
        ],
        niegaAlergias: h.antecedentes.niegaAlergias,
        ocupacion: normalizarTexto(p.ocupacion),
        aseguradora: normalizarTexto(p.aseguradora),
        habitos: h.antecedentes.habitos.trim(),
        examenes: h.plan.examenesSolicitados.trim(),
        interconsultas: h.plan.interconsultas.trim(),
      ),
      pdf: pdf,
    );
  }
}
