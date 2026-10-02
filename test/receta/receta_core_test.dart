import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/models/historia.dart';
import 'package:historiasclinicas_net/core/receta/alertas.dart';
import 'package:historiasclinicas_net/core/receta/cantidad.dart';
import 'package:historiasclinicas_net/core/receta/medicamentos.dart';
import 'package:historiasclinicas_net/core/receta/numero_letras.dart';
import 'package:historiasclinicas_net/core/receta/receta.dart';

import '../ejemplos.dart';

ItemReceta item(
  String medicamento, {
  String id = 'i1',
  String concentracion = '',
  String forma = '',
  String dosis = '',
  String via = '',
  String frecuencia = '',
  String duracion = '',
  int? cantidad,
  String unidad = '',
  String nota = '',
}) => ItemReceta(
  id: id,
  medicamento: medicamento,
  concentracion: concentracion,
  forma: forma,
  dosis: dosis,
  via: via,
  frecuencia: frecuencia,
  duracion: duracion,
  cantidad: cantidad,
  unidad: unidad,
  nota: nota,
);

final amoxicilina = item(
  'Amoxicilina',
  concentracion: '500 mg',
  forma: 'cápsula',
  dosis: '1 cápsula',
  via: 'oral',
  frecuencia: 'cada 8 horas',
  duracion: '7 días',
  cantidad: 21,
  unidad: 'cápsulas',
);

void main() {
  group('Número en letras', () {
    test('casos de la receta', () {
      final casos = {
        0: 'cero',
        1: 'uno',
        15: 'quince',
        16: 'dieciséis',
        21: 'veintiuno',
        22: 'veintidós',
        30: 'treinta',
        31: 'treinta y uno',
        45: 'cuarenta y cinco',
        100: 'cien',
        101: 'ciento uno',
        115: 'ciento quince',
        200: 'doscientos',
        500: 'quinientos',
        777: 'setecientos setenta y siete',
        1000: 'mil',
        1001: 'mil uno',
        1500: 'mil quinientos',
        2021: 'dos mil veintiuno',
        21000: 'veintiún mil',
        31000: 'treinta y un mil',
        100000: 'cien mil',
        101000: 'ciento un mil',
        1000000: 'un millón',
        2500000: 'dos millones quinientos mil',
        21000000: 'veintiún millones',
      };
      for (final e in casos.entries) {
        expect(numeroALetras(e.key), e.value, reason: '${e.key}');
      }
      expect(() => numeroALetras(-1), throwsRangeError);
    });
  });

  group('Ítem de la receta', () {
    test('título, posología y cantidad para imprimir', () {
      expect(amoxicilina.titulo, 'AMOXICILINA 500 mg · cápsula');
      expect(
        amoxicilina.posologia,
        '1 cápsula vía oral cada 8 horas durante 7 días.',
      );
      expect(amoxicilina.textoCantidad, '21 (veintiuno) cápsulas');
      expect(amoxicilina.faltantes, isEmpty);
    });

    test('duraciones sin número y notas', () {
      final i = item(
        'Losartán',
        dosis: '1 tableta',
        via: 'oral',
        frecuencia: 'cada 24 horas',
        duracion: 'uso continuo',
        nota: 'En la mañana',
      );
      expect(
        i.posologia,
        '1 tableta vía oral cada 24 horas uso continuo. En la mañana.',
      );
      expect(i.faltantes, ['concentración', 'forma farmacéutica', 'cantidad']);
    });

    test('ida y vuelta por mapa', () {
      final r = Receta(
        id: 'r1',
        historiaId: 'h1',
        fecha: DateTime(2026, 10, 2, 9, 30),
        numero: 'R-000007',
        items: [amoxicilina],
        indicaciones: 'Líquidos abundantes.',
        incluirSello: false,
        ajustesPaciente: const {'edad': '36 años'},
        alertasVistas: const {'x'},
      );
      final otra = Receta.desdeMapa(r.aMapa());
      expect(otra.aMapa(), r.aMapa());
      expect(otra.items.single.textoCantidad, '21 (veintiuno) cápsulas');
      expect(otra.incluirSello, isFalse);
    });

    test('texto para registrar en la historia', () {
      final r = Receta(
        id: 'r1',
        historiaId: 'h1',
        fecha: DateTime(2026, 10, 2),
        numero: 'R-000007',
        items: [
          amoxicilina,
          const ItemReceta(id: 'vacio'),
        ],
        indicaciones: 'Control en 7 días.',
      );
      expect(
        r.textoParaHistoria(),
        'Se formuló (R-000007) el 02/10/2026:\n'
        '1. AMOXICILINA 500 mg · cápsula 1 cápsula vía oral cada 8 horas '
        'durante 7 días. Cantidad: 21 (veintiuno) cápsulas.\n'
        'Indicaciones: Control en 7 días.',
      );
    });

    test('unidad sugerida según la forma', () {
      expect(unidadSugerida('Cápsula'), 'cápsulas');
      expect(unidadSugerida('jarabe'), 'frascos');
      expect(unidadSugerida('crema'), 'tubos');
      expect(unidadSugerida('otra cosa'), '');
    });
  });

  group('Paciente de la receta', () {
    test('se precarga de la historia y admite correcciones', () {
      final p = PacienteReceta.deHistoria(historiaCompleta());
      expect(p.nombre, 'PEÑA MUÑOZ, José Ángel');
      expect(p.documento, 'CC 1032456789');
      expect(p.diagnostico, 'J02.9 Faringitis aguda; R50.9 Fiebre');
      expect(p.alergias, 'Penicilina, AINEs');
      expect(p.fechaNacimiento, '15/03/1990');
      final c = p.conAjustes({'nombre': 'Otro'});
      expect(c.nombre, 'Otro');
      expect(c.documento, p.documento);
    });

    test('sin alergias registradas queda vacío; "niega" se dice', () {
      final h = historiaCompleta();
      final sin = h.copyWith(antecedentes: const Antecedentes());
      expect(PacienteReceta.deHistoria(sin).alergias, '');
      final niega = h.copyWith(
        antecedentes: const Antecedentes(niegaAlergias: true),
      );
      expect(
        PacienteReceta.deHistoria(niega).alergias,
        'Niega alergias conocidas',
      );
      expect(alergiasDeTexto('Niega alergias conocidas'), isEmpty);
      expect(alergiasDeTexto('Penicilina, AINEs; látex y polen'), [
        'Penicilina',
        'AINEs',
        'látex',
        'polen',
      ]);
    });
  });

  group('Cantidad sugerida', () {
    test('unidades × tomas al día × días', () {
      expect(cantidadSugerida(amoxicilina), 21);
      expect(
        cantidadSugerida(
          item(
            'x',
            dosis: '1/2 tableta',
            frecuencia: 'cada 12 horas',
            duracion: '2 semanas',
          ),
        ),
        14,
      );
      expect(
        cantidadSugerida(
          item(
            'x',
            forma: 'sobre',
            dosis: '1',
            frecuencia: 'tres veces al día',
            duracion: '5 días',
          ),
        ),
        15,
      );
      expect(
        cantidadSugerida(
          item(
            'x',
            dosis: '2 comprimidos',
            frecuencia: 'una vez al día',
            duracion: '1 mes',
          ),
        ),
        60,
      );
      expect(
        cantidadSugerida(
          item('x', dosis: '2 sobres', frecuencia: 'dosis única'),
        ),
        2,
      );
    });

    test('no adivina con jarabes, gotas o "si hay dolor"', () {
      expect(
        cantidadSugerida(
          item(
            'x',
            dosis: '5 mL',
            frecuencia: 'cada 8 horas',
            duracion: '7 días',
          ),
        ),
        isNull,
      );
      expect(
        cantidadSugerida(
          item(
            'x',
            dosis: '1 tableta',
            frecuencia: 'si hay dolor',
            duracion: '3 días',
          ),
        ),
        isNull,
      );
      expect(
        cantidadSugerida(
          item(
            'x',
            forma: 'jarabe',
            dosis: '1',
            frecuencia: 'cada 8 horas',
            duracion: '7 días',
          ),
        ),
        isNull,
      );
    });
  });

  group('Alertas de alergia', () {
    List<AlertaAlergia> alertas(List<String> alergias, List<String> meds) =>
        alertasDeAlergia(
          alergias: alergias,
          items: [for (final (i, m) in meds.indexed) item(m, id: 'i$i')],
        );

    test('coincidencia directa sin tildes ni mayúsculas', () {
      final a = alertas(['PENICILINA'], ['Penicilina G benzatínica']).single;
      expect(a.gravedad, GravedadAlerta.alta);
      expect(a.numeroItem, 1);
      expect(a.texto, contains('coincide'));
      expect(
        alertas(['ácido clavulánico'], ['Amoxicilina + acido clavulanico']),
        hasLength(1),
      );
    });

    test('mismo grupo: penicilinas, AINE, sulfas, betalactámicos', () {
      final a = alertas(['Penicilina'], ['Amoxicilina']).single;
      expect(a.motivo, 'pertenece al grupo de las penicilinas');
      expect(
        alertas(['AINEs'], ['Ibuprofeno']).single.motivo,
        contains('AINE'),
      );
      expect(alertas(['aspirina'], ['Naproxeno']), hasLength(1));
      expect(
        alertas(['Sulfas'], ['Trimetoprim/sulfametoxazol']).single.motivo,
        contains('sulfonamidas'),
      );
      expect(
        alertas(['Betalactámicos'], ['Ceftriaxona']).single.gravedad,
        GravedadAlerta.alta,
      );
    });

    test('mismo principio activo con otro nombre', () {
      final a = alertas(['Acetaminofén'], ['Paracetamol']).single;
      expect(a.motivo, contains('mismo principio activo'));
      expect(alertas(['dipirona'], ['Metamizol']), hasLength(1));
    });

    test('reactividad cruzada: aviso de gravedad media', () {
      final a = alertas(['Penicilina'], ['Cefalexina']).single;
      expect(a.gravedad, GravedadAlerta.media);
      expect(a.motivo, contains('posible reactividad cruzada'));
      expect(
        alertas(['Dipirona'], ['Diclofenaco']).single.gravedad,
        GravedadAlerta.media,
      );
    });

    test('sin falsas alarmas', () {
      expect(alertas(['Penicilina'], ['Azitromicina', 'Loratadina']), isEmpty);
      expect(alertas(['Sulfas'], ['Sulfato ferroso']), isEmpty);
      expect(alertas(['Látex', 'Mariscos'], ['Ibuprofeno']), isEmpty);
      expect(alertas(['AINEs'], ['Paracetamol']), isEmpty);
    });

    test('cada alerta indica su ítem y tiene una clave estable', () {
      final a = alertas(['Penicilina'], ['Loratadina', 'Amoxicilina']);
      expect(a.single.numeroItem, 2);
      expect(
        a.single.clave,
        alertas(['penicilina'], ['Loratadina', 'Amoxicilina']).single.clave,
      );
    });
  });

  test('aviso de control especial', () {
    final avisos = avisosControlEspecial([
      item('Amoxicilina'),
      item('Clonazepam'),
      item('Morfina sulfato'),
    ]);
    expect(avisos.map((a) => a.numeroItem), [2, 3]);
    expect(avisos.first.texto, contains('VERIFICAR'));
  });

  group('Mis medicamentos', () {
    final p = PlantillaMedicamento.desdeItem(amoxicilina);

    test('guardar reemplaza la misma presentación y ordena', () {
      var lista = conPlantilla(
        const [],
        const PlantillaMedicamento(medicamento: 'Paracetamol'),
      );
      lista = conPlantilla(lista, p);
      lista = conPlantilla(
        lista,
        PlantillaMedicamento.desdeItem(
          amoxicilina.copyWith(medicamento: 'AMOXICILINA', dosis: '2 cápsulas'),
        ),
      );
      expect(lista.map((x) => x.etiqueta), [
        'AMOXICILINA 500 mg · cápsula',
        'Paracetamol',
      ]);
      expect(lista.first.dosis, '2 cápsulas');
      expect(buscarPlantillas(lista, 'amox').single.medicamento, 'AMOXICILINA');
      expect(buscarPlantillas(lista, '500'), hasLength(1));
      expect(buscarPlantillas(lista, 'xilina'), isEmpty);
    });

    test('aplicar una plantilla conserva el id y la cantidad', () {
      final i = p.aplicarA(const ItemReceta(id: 'z', cantidad: 3));
      expect(i.id, 'z');
      expect(i.cantidad, 3);
      expect(i.frecuencia, 'cada 8 horas');
    });

    test('exportar e importar (ida y vuelta)', () {
      final json = exportarMedicamentos([p], ahora: DateTime(2026, 10, 2));
      expect(json, contains('"tipo": "medicamentos"'));
      final r = importarMedicamentos(json, const []);
      expect(r.nuevos, 1);
      expect(r.lista.single.aMapa(), p.aMapa());
      final otra = importarMedicamentos(json, r.lista);
      expect(otra.nuevos, 0);
      expect(otra.actualizados, 1);
      expect(otra.resumen, '0 medicamentos nuevos y 1 actualizado');
    });

    test('acepta una lista simple y rechaza archivos ajenos', () {
      expect(
        importarMedicamentos(
          '[{"medicamento": "Loratadina", "concentracion": "10 mg"}]',
          const [],
        ).lista.single.etiqueta,
        'Loratadina 10 mg',
      );
      for (final malo in [
        'no es json',
        '{"tipo": "historia"}',
        '{"otra": 1}',
        '[{"concentracion": "10 mg"}]',
        '[{"medicamento": 3}]',
      ]) {
        expect(
          () => importarMedicamentos(malo, const []),
          throwsFormatException,
          reason: malo,
        );
      }
    });
  });
}
