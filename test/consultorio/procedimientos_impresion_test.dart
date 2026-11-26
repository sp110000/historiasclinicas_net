import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/plantillas.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/plantilla_procedimiento.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/protocolo_pdf.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';

import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';
import 'ayudas_procedimientos.dart';
import 'documentos_test.dart' show textoPdf;

/// El texto del PDF en una línea (o `null` sin pdftotext).
String? _plano(Uint8List pdf) => textoPdf(pdf)?.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Texto del protocolo', () {
    test('con solución y anestésico', () {
      final t = textoProtocolo(
        protocoloDePrueba(hidrolipoclasiaBase.ultima.definicion),
      );
      final secciones = t.split('\n\n').map((s) => s.split('\n').first);
      expect(secciones, [
        'VALORACIÓN',
        'SESIÓN',
        'LISTA DE VERIFICACIÓN PREVIA',
        'INDICACIONES POSTERIORES',
        'RIESGOS (CONSENTIMIENTO)',
        'ALTERNATIVAS (CONSENTIMIENTO)',
      ]);
      expect(t, contains('Zonas: Abdomen superior; Abdomen inferior;'));
      expect(
        t,
        contains(
          'Contraindicaciones que dan «no apto»: Anticoagulación o '
          'coagulopatía; Alergia a anestésicos locales.',
        ),
      );
      expect(
        t,
        contains(
          'Número de sesiones: 4. Intervalo: 7 días. Control: a los 7 días.',
        ),
      );
      expect(
        t,
        contains(
          'Componentes de la solución: Componente A de prueba; Componente B '
          'de prueba.',
        ),
      );
      expect(
        t,
        contains('Volumen máximo: 500 mL por zona y 1000 mL por sesión.'),
      );
      expect(
        t,
        contains(
          'Anestésico local: Anestésico de prueba, 20 mg/mL, máximo 7 mg/kg.',
        ),
      );
      expect(t, contains('- Consentimiento vigente\n- Valoración vigente'));
      expect(t, contains('RIESGOS (CONSENTIMIENTO)\nRiesgos de prueba.'));
    });

    test('sin anestésico ni solución, y lo que falta con «—»', () {
      final t = textoProtocolo(
        const DefinicionProcedimiento(
          nombre: 'Radiofrecuencia de prueba',
          usaAnestesico: false,
          usaSolucion: false,
        ),
      );
      expect(t, contains('Sin solución infiltrada'));
      expect(t, contains('Sin anestésico local.'));
      expect(t, isNot(contains('Volumen máximo')));
      expect(t, contains('Zonas: —.'));
      expect(t, contains('LISTA DE VERIFICACIÓN PREVIA\n—'));
      expect(t, contains('Número de sesiones: —.'));
    });
  });

  test('nombres de archivo sin tildes ni símbolos', () {
    expect(
      nombreArchivoProcedimiento('Protocolo', 'Hidrolipoclasia', version: 2),
      'Protocolo_Hidrolipoclasia_v2.pdf',
    );
    expect(
      nombreArchivoProcedimiento('Consentimiento_muestra', ' Láser – CO₂ '),
      'Consentimiento_muestra_Laser_CO.pdf',
    );
    expect(
      nombreArchivoProcedimiento('Protocolo', '***', version: 1),
      'Protocolo_Procedimiento_v1.pdf',
    );
  });

  group('En el consultorio', () {
    late BancoConsultorio b;
    late String id;
    late FuentesPdf fuentes;

    setUpAll(() async => fuentes = await FuentesPdf.cargar());

    setUp(() async {
      b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      final r = await b.servicio.registrarHistoria(
        HistoriaPendiente(
          datos: historiaSintetica(),
          revision: 1,
          origen: OrigenArchivo.importado,
        ),
      );
      id = r!.pacienteId;
    });

    test('protocolo en PDF: el borrador sale marcado; aprobado, con su fecha; '
        'una versión que no existe se rechaza', () async {
      final p = b.servicio.procedimientos;
      final borrador = await p.protocoloPdf(
        'hidrolipoclasia',
        version: 1,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      expect(borrador.sublist(0, 4), '%PDF'.codeUnits);
      final tb = _plano(borrador);
      if (tb != null) {
        expect(tb, contains('PROTOCOLO DE HIDROLIPOCLASIA'));
        expect(tb, contains('BORRADOR'));
      }
      await aprobarHidrolipoclasia(b);
      final aprobado = await p.protocoloPdf(
        'hidrolipoclasia',
        version: 1,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      final ta = _plano(aprobado);
      if (ta != null) {
        expect(ta, contains('aprobada el 21/11/2026'));
        expect(ta, isNot(contains('BORRADOR')));
        expect(ta, contains('Componente A de prueba'));
      }
      expect(
        () => p.protocoloPdf(
          'hidrolipoclasia',
          version: 9,
          medico: medicoCompleto(),
          pais: Pais.colombia,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('hoja de la lista de verificación con sus ítems', () async {
      await aprobarHidrolipoclasia(b);
      final pdf = await b.servicio.procedimientos.listaVerificacionPdf(
        'hidrolipoclasia',
        version: 1,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      expect(pdf.sublist(0, 4), '%PDF'.codeUnits);
      final t = _plano(pdf);
      if (t != null) {
        expect(t, contains('LISTA DE VERIFICACIÓN PREVIA'));
        expect(t, contains('Hidrolipoclasia · protocolo v1'));
        expect(t, contains('Embarazo descartado'));
        expect(t, contains('Verificó (nombre y firma)'));
        expect(t, isNot(contains('BORRADOR')));
      }
    });

    test('consentimiento de muestra: el procedimiento, sus riesgos y lo del '
        'paciente en blanco; sin aprobar, marcado', () async {
      await aprobarHidrolipoclasia(b);
      final p = b.servicio.procedimientos;
      final sinAprobar = await p.consentimientoMuestraPdf(
        'hidrolipoclasia',
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      final ts = _plano(sinAprobar);
      if (ts != null) {
        expect(ts, contains('MUESTRA'));
        expect(ts, contains('BORRADOR'));
      }
      await b.servicio.documentos.aprobar(
        TipoPlantilla.consentimientoInformado,
      );
      final pdf = await p.consentimientoMuestraPdf(
        'hidrolipoclasia',
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      final t = _plano(pdf);
      if (t != null) {
        expect(t, contains('MUESTRA'));
        expect(t, isNot(contains('BORRADOR')));
        expect(
          t,
          contains('Procedimiento y plan de tratamiento: Hidrolipoclasia'),
        );
        expect(t, contains('en 4 sesiones'));
        expect(t, contains('Riesgos de prueba.'));
        // Sin «..»: la plantilla ya pone el punto tras las alternativas.
        expect(t, contains('Alternativas de prueba. También puedo'));
        expect(t, isNot(contains('..')));
        expect(t, contains('Yo, ______'));
        expect(t, isNot(contains('PEÑA')));
      }
      // No se guarda ni gasta un número.
      expect(p.consentimientosFirmados, isEmpty);
    });

    test('los firmados de todos los pacientes, del más reciente al más '
        'viejo', () async {
      await aprobarHidrolipoclasia(b);
      await valorarAptoDePrueba(b, id);
      await consentimientoDePrueba(b, id, sesiones: 2);
      b.reloj.avanzar(const Duration(hours: 1));
      await consentimientoDePrueba(b, id, sesiones: 4);
      final firmados = b.servicio.procedimientos.consentimientosFirmados;
      expect(firmados.map((d) => d.numero), ['CI-000002', 'CI-000001']);
      expect(firmados.first.plan!.plantillaId, 'hidrolipoclasia');
      expect(firmados.first.plan!.sesiones, 4);
      // El firmado tampoco queda con «..» tras las alternativas.
      expect(
        firmados.first.contenido,
        contains('Alternativas de prueba. También puedo'),
      );
    });
  });
}
