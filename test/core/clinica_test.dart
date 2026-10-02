import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/clinica/edad.dart';
import 'package:historiasclinicas_net/core/clinica/gestacion.dart';
import 'package:historiasclinicas_net/core/clinica/imc.dart';
import 'package:historiasclinicas_net/core/clinica/rangos.dart';

void main() {
  group('calcularEdad', () {
    Edad? edad(String nac, String ref) =>
        calcularEdad(DateTime.parse(nac), DateTime.parse(ref));

    test('adulto: cumple el día exacto', () {
      expect(edad('1990-03-15', '2026-03-14'), const Edad(35, 11, 27));
      expect(edad('1990-03-15', '2026-03-15'), const Edad(36, 0, 0));
      expect(edad('1990-03-15', '2026-03-15')!.texto, '36 años');
    });

    test('ignora la hora de la atención', () {
      expect(
        calcularEdad(DateTime(2000, 1, 1, 23, 59), DateTime(2026, 1, 1, 0, 1)),
        const Edad(26, 0, 0),
      );
    });

    test('menor de 2 años: años, meses y días', () {
      final e = edad('2025-06-20', '2026-10-02')!;
      expect(e, const Edad(1, 3, 12));
      expect(e.texto, '1 año 3 meses 12 días');
      expect(edad('2026-09-01', '2026-10-02')!.texto, '1 mes 1 día');
      expect(edad('2026-09-25', '2026-10-02')!.texto, '7 días');
      expect(edad('2026-10-02', '2026-10-02')!.texto, '0 días');
    });

    test('de 2 a 17 años: años y meses', () {
      expect(edad('2019-01-10', '2026-10-02')!.texto, '7 años 8 meses');
      expect(edad('2019-10-02', '2026-10-02')!.texto, '7 años');
    });

    test('nacidos un 29 de febrero', () {
      expect(edad('2024-02-29', '2025-02-27'), const Edad(0, 11, 29));
      expect(edad('2024-02-29', '2025-02-28'), const Edad(1, 0, 0));
      expect(edad('2024-02-29', '2025-03-01'), const Edad(1, 0, 1));
      expect(edad('2024-02-29', '2028-02-29'), const Edad(4, 0, 0));
    });

    test('días que cruzan fin de mes y de año', () {
      expect(edad('2025-12-31', '2026-01-01'), const Edad(0, 0, 1));
      expect(edad('2026-01-31', '2026-02-28'), const Edad(0, 1, 0));
      expect(edad('2026-01-31', '2026-03-01'), const Edad(0, 1, 1));
      expect(edad('2026-01-31', '2026-03-31'), const Edad(0, 2, 0));
      expect(edad('2025-10-31', '2026-03-30'), const Edad(0, 4, 30));
    });

    test('fecha de nacimiento posterior a la atención', () {
      expect(edad('2027-01-01', '2026-10-02'), isNull);
    });
  });

  group('IMC', () {
    test('cálculo', () {
      expect(calcularImc(pesoKg: 72, tallaCm: 170), closeTo(24.91, 0.01));
      expect(calcularImc(pesoKg: 72, tallaCm: null), isNull);
      expect(calcularImc(pesoKg: 0, tallaCm: 170), isNull);
      expect(calcularImc(pesoKg: 72, tallaCm: 1.70), isNull); // metros
    });

    test('clasificación OMS en adultos (límites)', () {
      ClasificacionImc? c(double imc) =>
          interpretarImc(imc, edadAnios: 40).clasificacion;
      expect(c(18.49), ClasificacionImc.bajoPeso);
      expect(c(18.5), ClasificacionImc.normal);
      expect(c(24.99), ClasificacionImc.normal);
      expect(c(25), ClasificacionImc.sobrepeso);
      expect(c(30), ClasificacionImc.obesidad1);
      expect(c(35), ClasificacionImc.obesidad2);
      expect(c(40), ClasificacionImc.obesidad3);
    });

    test('menores de 18 años y gestantes no se clasifican', () {
      final nino = interpretarImc(17, edadAnios: 10);
      expect(nino.clasificacion, isNull);
      expect(nino.texto, contains('percentiles'));
      final gestante = interpretarImc(27, edadAnios: 30, gestante: true);
      expect(gestante.clasificacion, isNull);
      expect(gestante.texto, contains('gestantes'));
    });

    test('edad desconocida se interpreta como adulto', () {
      expect(
        interpretarImc(22, edadAnios: null).clasificacion,
        ClasificacionImc.normal,
      );
    });
  });

  group('Gestación', () {
    test('edad gestacional por FUM', () {
      final eg = edadGestacional(DateTime(2026, 3, 1), DateTime(2026, 8, 19))!;
      expect(eg.semanas, 24);
      expect(eg.dias, 3);
      expect(eg.texto, '24 semanas + 3 días');
      expect(
        edadGestacional(DateTime(2026, 10, 2), DateTime(2026, 9, 1)),
        isNull,
      );
      expect(
        edadGestacional(DateTime(2025, 1, 1), DateTime(2026, 9, 1)),
        isNull,
      );
    });

    test('fecha probable de parto (Naegele)', () {
      expect(fechaProbableParto(DateTime(2026, 3, 1)), DateTime(2026, 12, 6));
      // Cruza el cambio de horario sin desplazarse un día.
      expect(fechaProbableParto(DateTime(2026, 1, 10)), DateTime(2026, 10, 17));
    });
  });

  test('rangos de signos vitales', () {
    expect(Rangos.fc.esPlausible(78), isTrue);
    expect(Rangos.fc.esPlausible(780), isFalse);
    expect(Rangos.fc.esHabitual(120), isFalse);
    expect(Rangos.spo2.esHabitual(99), isTrue);
    expect(Rangos.spo2.esHabitual(90), isFalse);
    expect(Rangos.temperatura.esPlausible(368), isFalse);
    expect(Rangos.peso.esHabitual(300), isTrue); // sin rango habitual
  });
}
