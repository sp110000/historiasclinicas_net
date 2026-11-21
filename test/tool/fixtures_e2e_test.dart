// Genera los PDF sintéticos de la e2e del consultorio
// (tool/e2e/fixtures/consultorio/). Solo escribe si se pide:
//
//   GENERAR_FIXTURES_E2E=1 flutter test test/tool/fixtures_e2e_test.dart
//
// Sin la variable, comprueba que los archivos guardados se siguen leyendo
// como se espera (para que la e2e no se quede con fixtures viejos).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/integridad/cadena_hash.dart';
import 'package:historiasclinicas_net/core/models/evolucion.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/pdf/historia_pdf.dart';
import 'package:historiasclinicas_net/core/pdf/lector_adjunto.dart';
import 'package:pdf/widgets.dart' as pw;

import '../consultorio/ayudas_historias.dart';

const _dir = 'tool/e2e/fixtures/consultorio';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF sintéticos de la e2e del consultorio', () async {
    if (Platform.environment['GENERAR_FIXTURES_E2E'] != null) {
      final f = await FuentesPdf.cargar();
      Future<void> escribir(
        String nombre,
        Map<String, Object?> d,
        int r,
      ) async {
        final b = await generarPdfHistoria(
          datos: d,
          revision: r,
          fuentes: f,
          generadoEn: DateTime(2026, 11, 10, 10),
        );
        File('$_dir/$nombre').writeAsBytesSync(b);
      }

      await escribir(
        'Pena_1032456789_r2.pdf',
        sellarEvoluciones(historiaSintetica(id: 'e2e-pena'), [
          Evolucion(
            id: 'e1',
            fechaHora: DateTime(2026, 11, 10, 9),
            texto: 'Control de peso. Buena adherencia al plan.',
            proximoControl: DateTime(2026, 11, 15),
          ).aMapa(),
        ]),
        2,
      );
      await escribir(
        'Munoz_52222333_r1.pdf',
        historiaSintetica(
          id: 'e2e-munoz',
          numeroDocumento: '52222333',
          primerApellido: 'Muñoz',
          nombres: 'María José',
          fecha: DateTime(2026, 6, 1),
        ),
        1,
      );
      final alterada = historiaSintetica(
        id: 'e2e-gomez',
        numeroDocumento: '79333444',
        primerApellido: 'Gómez',
        nombres: 'Andrés',
        fecha: DateTime(2025, 1, 15),
      );
      (alterada['motivo']! as Map)['motivoConsulta'] = 'Cambiado al sellar';
      await escribir('Gomez_79333444_r1_alterada.pdf', alterada, 1);
      final ajeno = pw.Document()
        ..addPage(pw.Page(build: (_) => pw.Text('Factura')));
      File('$_dir/factura.pdf').writeAsBytesSync(await ajeno.save());
    }

    final pena = leerHistoriaDePdf(
      File('$_dir/Pena_1032456789_r2.pdf').readAsBytesSync(),
    );
    expect(pena.revision, 2);
    expect(verificarIntegridad(pena.datos).correcta, isTrue);
    final gomez = leerHistoriaDePdf(
      File('$_dir/Gomez_79333444_r1_alterada.pdf').readAsBytesSync(),
    );
    expect(verificarIntegridad(gomez.datos).correcta, isFalse);
    expect(
      () => leerHistoriaDePdf(File('$_dir/factura.pdf').readAsBytesSync()),
      throwsA(isA<LecturaHistoriaException>()),
    );
  });
}
