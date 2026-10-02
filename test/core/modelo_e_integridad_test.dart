import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/integridad/cadena_hash.dart';
import 'package:historiasclinicas_net/core/integridad/json_canonico.dart';
import 'package:historiasclinicas_net/core/models/historia.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';

import '../ejemplos.dart';

void main() {
  group('Modelo de historia', () {
    test('ida y vuelta completa por mapa sin perder nada', () {
      final h = historiaCompleta();
      final mapa = h.aMapa();
      final otra = HistoriaClinica.desdeMapa(mapa);
      expect(jsonCanonico(otra.aMapa()), jsonCanonico(mapa));
      expect(otra.paciente.nombreCompleto, 'PEÑA MUÑOZ, José Ángel');
      expect(otra.antecedentes.alergias, ['Penicilina', 'AINEs']);
      expect(otra.antecedentes.gineco.formula, 'G2 P1 C1');
      expect(otra.diagnosticos.map((d) => d.textoCorto), [
        'J02.9 Faringitis aguda',
        'R50.9 Fiebre',
      ]);
      expect(otra.signos.peso, 64.5);
      expect(otra.plan.proximoControl, DateTime(2026, 10, 9));
    });

    test('los campos vacíos no se escriben', () {
      final h = HistoriaClinica.nueva(
        pais: Pais.colombia,
        ahora: DateTime(2026, 10, 2, 9, 14, 33),
      );
      final m = h.aMapa();
      expect(m['paciente'], {'tipoDocumento': 'CC'});
      expect(m['atencion'], {'fechaHora': '2026-10-02T09:14'});
      expect(m['signosVitales'], isEmpty);
      expect(h.estaVacia, isTrue);
      expect(h.copyWith(motivoConsulta: 'Cefalea').estaVacia, isFalse);
    });

    test('edad exacta o aproximada', () {
      final h = historiaCompleta();
      expect(h.edadTexto, '36 años');
      expect(h.edadAnios, 36);
      final sinFecha = h.copyWith(
        paciente: h.paciente.copyWith(
          fechaNacimiento: null,
          edadAproximada: 60,
        ),
      );
      expect(sinFecha.edadTexto, '≈ 60 años');
      expect(sinFecha.edadAnios, 60);
    });

    test('revisión por sistemas y análisis viajan en el mapa', () {
      final h = HistoriaClinica.desdeMapa(historiaCompleta().aMapa());
      final r = h.revisionSistemas;
      expect(r.de('generales').detalle, 'Fiebre no cuantificada y astenia');
      expect(r.conEstado(EstadoSistema.niega).map((s) => s.codigo), [
        'respiratorio',
        'cardiovascular',
      ]);
      expect(r.registrados, 3);
      expect(r.completa, isFalse);
      expect(r.negarPendientes().completa, isTrue);
      expect(r.negarPendientes().de('generales').estado, EstadoSistema.refiere);
      expect(h.analisis, startsWith('Cuadro compatible'));
      expect(h.aMapa()['analisis'], {'texto': h.analisis});
    });

    test('una revisión vacía no ocupa espacio en el JSON', () {
      expect(const RevisionSistemas().aMapa(), isEmpty);
      expect(
        const RevisionSistemas(sistemas: {'piel': HallazgoSistema()}).aMapa(),
        isEmpty,
      );
    });

    test('rechaza mapas que no son historias clínicas', () {
      expect(
        () => HistoriaClinica.desdeMapa({'tipo': 'poc'}),
        throwsFormatException,
      );
    });

    test('perfil de España: documentos y etiquetas', () {
      final h = HistoriaClinica.nueva(pais: Pais.espana);
      expect(h.paciente.tipoDocumento, 'DNI');
      expect(h.perfil.etiquetaSignosVitales, 'Constantes vitales');
      expect(
        perfilEspana.etiquetaCaracter('confirmado_repetido'),
        'Confirmado repetido',
      );
    });
  });

  group('Cadena de hashes', () {
    Map<String, Object?> conEvoluciones(int n) {
      var datos = sellarBase(historiaCompleta().aMapa());
      for (var i = 1; i <= n; i++) {
        datos = sellarEvoluciones(datos, [
          Evolucion(
            id: 'e1',
            fechaHora: DateTime(2026, 10, 2 + i, 10, 30),
            texto: 'Evolución $i: paciente estable.',
          ).aMapa(),
        ]);
      }
      return datos;
    }

    test('una historia recién sellada se verifica', () {
      final r = verificarIntegridad(conEvoluciones(3));
      expect(r.correcta, isTrue);
      expect(r.sellos, 4);
      expect(r.descripcion, 'Integridad verificada (4 sellos encadenados)');
    });

    test('cada evolución encadena con la anterior', () {
      final datos = conEvoluciones(2);
      final ev = datos['evoluciones']! as List;
      final e1 = (ev[0] as Map).cast<String, Object?>();
      final e2 = (ev[1] as Map).cast<String, Object?>();
      expect(
        e1['hash'],
        calcularHashEvolucion(e1, datos['hashBase']! as String),
      );
      expect(e2['hash'], calcularHashEvolucion(e2, e1['hash']! as String));
      expect(
        huella(e1['hash']! as String),
        matches(RegExp(r'^[0-9a-f]{4}·[0-9a-f]{4}$')),
      );
    });

    test(
      'sellar varias evoluciones juntas equivale a hacerlo de una en una',
      () {
        final base = sellarBase(historiaCompleta().aMapa());
        final a = Evolucion(
          id: 'e2',
          fechaHora: DateTime(2026, 10, 3),
          texto: 'A',
        ).aMapa();
        final b = Evolucion(
          id: 'e3',
          fechaHora: DateTime(2026, 10, 4),
          texto: 'B',
        ).aMapa();
        expect(
          jsonCanonico(sellarEvoluciones(base, [a, b])),
          jsonCanonico(sellarEvoluciones(sellarEvoluciones(base, [a]), [b])),
        );
      },
    );

    test('detecta un cambio en la historia inicial', () {
      final datos = conEvoluciones(2);
      final paciente = Map.of(datos['paciente']! as Map)..['nombres'] = 'José';
      final r = verificarIntegridad({...datos, 'paciente': paciente});
      expect(r.correcta, isFalse);
      expect(r.primeraAlterada, 0);
      expect(r.descripcion, contains('historia inicial'));
    });

    test('detecta un cambio en la evolución 2 (y no culpa a la 1)', () {
      final datos = conEvoluciones(3);
      final ev = [
        for (final e in datos['evoluciones']! as List)
          Map<String, Object?>.from(e as Map),
      ];
      ev[1]['texto'] = 'Texto cambiado';
      final r = verificarIntegridad({...datos, 'evoluciones': ev});
      expect(r.primeraAlterada, 2);
      expect(r.descripcion, 'Se detectaron alteraciones desde la evolución 2');
    });

    test('detecta evoluciones borradas, reordenadas o sin hash', () {
      final datos = conEvoluciones(3);
      final ev = List.of(datos['evoluciones']! as List);

      final borrada = [ev[0], ev[2]];
      expect(
        verificarIntegridad({...datos, 'evoluciones': borrada}).primeraAlterada,
        2,
      );

      final reordenada = [ev[1], ev[0], ev[2]];
      expect(
        verificarIntegridad({
          ...datos,
          'evoluciones': reordenada,
        }).primeraAlterada,
        1,
      );

      final sinHash = Map<String, Object?>.from(ev[0] as Map)..remove('hash');
      expect(
        verificarIntegridad({
          ...datos,
          'evoluciones': [sinHash, ev[1], ev[2]],
        }).primeraAlterada,
        1,
      );
    });

    test('una historia sin hashBase no se considera verificada', () {
      final datos = Map.of(conEvoluciones(1))..remove('hashBase');
      expect(verificarIntegridad(datos).primeraAlterada, 0);
    });

    test('el orden de las claves no afecta al hash', () {
      final datos = conEvoluciones(1);
      final invertido = Map.fromEntries(datos.entries.toList().reversed);
      expect(verificarIntegridad(invertido).correcta, isTrue);
    });
  });
}
