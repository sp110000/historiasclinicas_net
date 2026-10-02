import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/integridad/json_canonico.dart';

void main() {
  group('jsonCanonico', () {
    test('ordena las claves en todos los niveles y no deja espacios', () {
      expect(
        jsonCanonico({
          'b': 1,
          'a': {'z': true, 'm': null},
          'c': [3, 'x'],
        }),
        '{"a":{"m":null,"z":true},"b":1,"c":[3,"x"]}',
      );
    });

    test('el orden de inserción no cambia el resultado', () {
      expect(jsonCanonico({'x': 1, 'y': 2}), jsonCanonico({'y': 2, 'x': 1}));
    });

    test('escapa todo lo que no es ASCII', () {
      final salida = jsonCanonico({'nombre': 'Peña Muñoz 😀'});
      // `bs` evita escribir la secuencia literal en el código fuente.
      const bs = '\\';
      expect(
        salida,
        '{"nombre":"Pe${bs}u00f1a Mu${bs}u00f1oz ${bs}ud83d${bs}ude00"}',
      );
      expect(salida.codeUnits.every((c) => c < 0x80), isTrue);
    });

    test('escapa comillas, barras y caracteres de control', () {
      expect(jsonCanonico('a"b\\c\n\t\u0001'), r'"a\"b\\c\n\t\u0001"');
    });

    test('vuelve a decodificarse al mismo valor', () {
      final original = {
        'texto': 'José Ángel «ñ» — 38,5 °C\n"cita"',
        'lista': [1, 2.5, -3, true, null],
      };
      expect(jsonDecode(jsonCanonico(original)), original);
    });

    test('un double entero se escribe igual que un int (VM y navegador)', () {
      expect(jsonCanonico({'peso': 72.0}), jsonCanonico({'peso': 72}));
      expect(jsonCanonico({'t': 36.8}), '{"t":36.8}');
    });

    test('rechaza números no representables', () {
      expect(() => jsonCanonico(double.nan), throwsArgumentError);
      expect(() => jsonCanonico(double.infinity), throwsArgumentError);
    });
  });

  group('sha256Canonico', () {
    test('es estable e independiente del orden de las claves', () {
      expect(
        sha256Canonico({'a': 1, 'b': 'ñ'}),
        sha256Canonico({'b': 'ñ', 'a': 1}),
      );
      expect(sha256Canonico({'a': 1}), hasLength(64));
    });

    test('cambia si cambia un solo carácter', () {
      expect(
        sha256Canonico({'texto': 'Peña'}),
        isNot(sha256Canonico({'texto': 'Pena'})),
      );
    });
  });
}
