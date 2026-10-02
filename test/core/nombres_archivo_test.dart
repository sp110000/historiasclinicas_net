import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/utils/nombres_archivo.dart';
import 'package:historiasclinicas_net/core/utils/texto.dart';

void main() {
  test('sinTildes quita tildes, diéresis y la virgulilla', () {
    expect(sinTildes('Peña Güell Ángel ÑANDÚ'), 'Pena Guell Angel NANDU');
  });

  group('nombreArchivoHistoria', () {
    test('primera versión sin sufijo', () {
      expect(
        nombreArchivoHistoria(primerApellido: 'Peña', documento: '1032456789'),
        'Historia_PENA_1032456789.pdf',
      );
    });

    test('desde la revisión 2 lleva _vN', () {
      expect(
        nombreArchivoHistoria(
          primerApellido: 'Peña',
          documento: '1032456789',
          revision: 3,
        ),
        'Historia_PENA_1032456789_v3.pdf',
      );
    });

    test('apellidos compuestos y documentos con separadores', () {
      expect(
        nombreArchivoHistoria(
          primerApellido: ' De la Peña ',
          documento: '1.032.456.789',
        ),
        'Historia_DE-LA-PENA_1032456789.pdf',
      );
      expect(
        nombreArchivoHistoria(
          primerApellido: 'García',
          documento: '12345678-z',
        ),
        'Historia_GARCIA_12345678Z.pdf',
      );
    });

    test('campos vacíos no producen nombres rotos', () {
      expect(
        nombreArchivoHistoria(primerApellido: '  ', documento: ''),
        'Historia_SIN-APELLIDO_SIN-DOCUMENTO.pdf',
      );
    });
  });

  test('nombreArchivoReceta usa la fecha AAAA-MM-DD', () {
    expect(
      nombreArchivoReceta(
        primerApellido: 'Muñoz',
        fecha: DateTime(2026, 3, 7, 18, 5),
      ),
      'Receta_MUNOZ_2026-03-07.pdf',
    );
  });
}
