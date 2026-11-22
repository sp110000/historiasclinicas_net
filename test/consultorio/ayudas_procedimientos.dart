import 'package:historiasclinicas_net/core/consultorio/procedimientos/plantilla_procedimiento.dart';

import 'ayudas_consultorio.dart';

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
