import 'package:historiasclinicas_net/core/consultorio/documentos/documento.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/plantillas.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/plantilla_procedimiento.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/valoracion.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';

import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

/// Protocolo sintético para las pruebas: valores inventados, solo para
/// poder aprobar la plantilla (no son una recomendación clínica).
DefinicionProcedimiento protocoloDePrueba(DefinicionProcedimiento base) =>
    base.copyWith(
      familia: 'Lipólisis por infiltración',
      componentes: const ['Componente A de prueba', 'Componente B de prueba'],
      volumenMaximoZonaMl: 500.0,
      volumenMaximoSesionMl: 1000.0,
      intervaloDias: 7,
      numeroSesiones: 4,
      anestesicos: const [
        AnestesicoProtocolo(
          nombre: 'Anestésico de prueba',
          concentracionMgMl: 20,
          maximoMgKg: 7,
        ),
      ],
      indicacionesPosteriores: 'Indicaciones de prueba.',
      diasControl: 7,
      riesgos: 'Riesgos de prueba.',
      alternativas: 'Alternativas de prueba.',
    );

/// Completa el protocolo de hidrolipoclasia y aprueba la plantilla.
Future<void> aprobarHidrolipoclasia(BancoConsultorio b) async {
  final p = b.servicio.procedimientos;
  await p.guardarBorrador(
    'hidrolipoclasia',
    protocoloDePrueba(p.plantilla('hidrolipoclasia')!.ultima.definicion),
  );
  await p.aprobar('hidrolipoclasia');
}

/// Sella una valoración «apto» de hidrolipoclasia en la ficha [id] (la
/// plantilla tiene que estar aprobada).
Future<void> valorarAptoDePrueba(BancoConsultorio b, String id) async {
  final p = b.servicio.procedimientos;
  final ficha = b.servicio.indice.ficha(id)!;
  final v = p.nuevaValoracion(ficha, 'hidrolipoclasia');
  await p.sellarValoracion(
    v.copyWith(
      zonas: const [
        ZonaValorada(zona: 'Abdomen inferior', pinzableCm: 3),
        ZonaValorada(zona: 'Flancos', pinzableCm: 2),
      ],
      expectativasRealistas: true,
      respuestas: [
        for (final r in v.respuestas)
          RespuestaValoracion(item: r.item, si: false),
      ],
      tamizajes: [
        for (final t in v.tamizajes)
          TamizajeAplicado(
            instrumento: t.instrumento,
            respuestas: List.filled(t.instrumento.numeroItems, 0),
          ),
      ],
      resultado: ResultadoValoracion.apto,
    ),
    ficha,
    medico: medicoCompleto(),
    pais: Pais.colombia,
  );
}

/// Aprueba la plantilla del consentimiento informado y firma uno con
/// [zonas] y [sesiones].
Future<DocumentoConsultorio> consentimientoDePrueba(
  BancoConsultorio b,
  String id, {
  List<String> zonas = const ['Abdomen inferior', 'Flancos'],
  int sesiones = 4,
}) async {
  final docs = b.servicio.documentos;
  if (!docs.plantilla(TipoPlantilla.consentimientoInformado).usable) {
    await docs.aprobar(TipoPlantilla.consentimientoInformado);
  }
  final p = b.servicio.procedimientos;
  final r = await p.firmarConsentimiento(
    ficha: b.servicio.indice.ficha(id)!,
    plan: p
        .planSugerido(id, 'hidrolipoclasia')
        .copyWith(zonas: zonas, sesiones: sesiones),
    firmaPng: firmaDePrueba,
    medico: medicoCompleto(),
    pais: Pais.colombia,
  );
  return r.documento;
}
