import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/plantillas.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/medicion.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/plantilla_procedimiento.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/procedimientos.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/sesion.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/valoracion.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/features/consultorio/shell/contenedor_consultorio.dart';

import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

/// Protocolo sintético de un procedimiento sin anestésico ni solución
/// (valores inventados, solo para las pruebas).
DefinicionProcedimiento _sinInfiltracion(DefinicionProcedimiento d) =>
    d.copyWith(
      zonas: const ['Abdomen', 'Muslos'],
      intervaloDias: 7,
      numeroSesiones: 6,
      listaVerificacion: const ['Consentimiento vigente', 'Zona revisada'],
      indicacionesPosteriores: 'Indicaciones de prueba.',
      diasControl: 15,
      riesgos: 'Riesgos de prueba.',
      alternativas: 'Alternativas de prueba.',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('en el menú, Procedimientos va debajo de Historia y encima de Caja', () {
    final rutas = [for (final d in destinosConsultorio) d.etiqueta];
    final i = rutas.indexOf('Procedimientos');
    expect(rutas[i - 1], 'Historia');
    expect(rutas[i + 1], 'Caja');
  });

  group('Sin anestésico ni solución', () {
    test('lo guardado antes vale «sí»; sin ellos no se piden para aprobar', () {
      final antes = hidrolipoclasiaBase.ultima.definicion.aMapa();
      expect(antes.containsKey('usaAnestesico'), isFalse);
      final leida = DefinicionProcedimiento.desdeMapa(antes);
      expect(leida.usaAnestesico, isTrue);
      expect(leida.usaSolucion, isTrue);

      final d = _sinInfiltracion(
        const DefinicionProcedimiento(
          nombre: 'Radiofrecuencia de prueba',
          familia: 'Aparatología',
          usaAnestesico: false,
          usaSolucion: false,
        ),
      );
      expect(d.faltantes, isEmpty);
      final ida = DefinicionProcedimiento.desdeMapa(d.aMapa());
      expect(ida.usaAnestesico, isFalse);
      expect(ida.usaSolucion, isFalse);
      // Con anestésico, vuelve a pedir su máximo.
      expect(d.copyWith(usaAnestesico: true).faltantes, [
        'la concentración y el máximo en mg/kg de cada anestésico',
      ]);
      expect(d.copyWith(usaSolucion: true).faltantes, [
        'los componentes de la solución',
        'el volumen máximo por zona',
        'el volumen máximo por sesión',
      ]);
    });
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

    test('crear: con nombre y sin repetir; en blanco o copiando otro; '
        'cifrado y al reabrir', () async {
      final p = b.servicio.procedimientos;
      await expectLater(
        p.crearPlantilla(nombre: '  '),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        p.crearPlantilla(nombre: 'HIDROLIPOCLASIA'),
        throwsA(
          isA<StateError>().having((e) => e.message, 'm', contains('Ya hay')),
        ),
      );
      final blanco = await p.crearPlantilla(
        nombre: 'Radiofrecuencia de prueba',
        familia: 'Aparatología',
        usaAnestesico: false,
        usaSolucion: false,
      );
      expect(blanco.usable, isFalse);
      expect(blanco.borrador!.version, 1);
      expect(blanco.ultima.definicion.zonas, isEmpty);
      expect(p.plantillas.map((x) => x.nombre), [
        'Hidrolipoclasia',
        'Radiofrecuencia de prueba',
      ]);

      final copia = await p.crearPlantilla(
        nombre: 'Mesoterapia de prueba',
        usaAnestesico: false,
        copiarDe: 'hidrolipoclasia',
      );
      final d = copia.ultima.definicion;
      expect(d.zonas, hidrolipoclasiaBase.ultima.definicion.zonas);
      expect(d.familia, isEmpty, reason: 'la familia es la que se escribió');
      expect(d.usaAnestesico, isFalse);
      expect(d.usaSolucion, isTrue);
      expect(copia.vigente, isNull, reason: 'la copia no viene aprobada');

      expect(
        contieneTexto(b.todosLosBytes, 'Radiofrecuencia de prueba'),
        isFalse,
      );
      await b.servicio.bloquear();
      await b.servicio.desbloquear(fraseDePrueba);
      expect(
        b.servicio.procedimientos.plantilla(blanco.id)!.ultima.definicion,
        isA<DefinicionProcedimiento>()
            .having((x) => x.usaAnestesico, 'anestésico', isFalse)
            .having((x) => x.nombre, 'nombre', 'Radiofrecuencia de prueba'),
      );
      final acciones = (await leerBitacora(
        b.servicio.repositorio,
      )).map((e) => e.accion);
      expect(
        acciones.where((a) => a == AccionBitacora.crearProcedimiento),
        hasLength(2),
      );
    });

    test(
      'uno sin anestésico ni solución: se aprueba, se valora, se '
      'consiente y su sesión se sella sin peso, volúmenes ni anestésico',
      () async {
        final p = b.servicio.procedimientos;
        final nuevo = await p.crearPlantilla(
          nombre: 'Radiofrecuencia de prueba',
          familia: 'Aparatología',
          usaAnestesico: false,
          usaSolucion: false,
        );
        await p.guardarBorrador(
          nuevo.id,
          _sinInfiltracion(p.plantilla(nuevo.id)!.ultima.definicion),
        );
        await p.aprobar(nuevo.id);
        final ficha = b.servicio.indice.ficha(id)!;

        final v = p.nuevaValoracion(ficha, nuevo.id);
        await p.sellarValoracion(
          v.copyWith(
            zonas: const [ZonaValorada(zona: 'Abdomen', pinzableCm: 2)],
            expectativasRealistas: true,
            resultado: ResultadoValoracion.apto,
          ),
          ficha,
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        );
        await b.servicio.documentos.aprobar(
          TipoPlantilla.consentimientoInformado,
        );
        await p.firmarConsentimiento(
          ficha: ficha,
          // Sin solución, el plan no trae producto: se escribe el equipo.
          plan: p
              .planSugerido(id, nuevo.id)
              .copyWith(
                zonas: const ['Abdomen'],
                producto: 'Equipo de prueba, Invima PRUEBA-0003',
              ),
          firmaPng: firmaDePrueba,
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        );

        expect(p.planSugerido(id, nuevo.id).producto, isEmpty);
        final borrador = p.nuevaSesion(ficha, nuevo.id);
        expect(borrador.anestesico, isNull);
        expect(borrador.componentes, isEmpty);
        final lista = borrador.copyWith(
          verificacion: {for (final k in borrador.verificacion.keys) k: true},
          zonas: const [ZonaSesion(zona: 'Abdomen')],
          duracionMin: 30,
        );
        final e = p.evaluar(lista, ficha);
        expect(
          e.bloqueos,
          isEmpty,
          reason: 'sin volúmenes, anestésico ni peso reciente',
        );
        final (s, _) = await p.sellarSesion(
          lista,
          ficha,
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        );
        final texto = textoSesion(
          s,
          p.vigente(nuevo.id).definicion,
          version: 1,
        );
        expect(texto, startsWith('Sesión 1 de 6 de Radiofrecuencia de prueba'));
        expect(texto, contains('Zonas: Abdomen.'));
        expect(texto, isNot(contains('mL')));
        expect(texto, isNot(contains('Anestésico')));
        // El peso no hacía falta: no se registró ninguno nuevo.
        expect(
          b.servicio.seguimiento.medicionesDe(id).whereType<Medicion>(),
          isNot(contains(predicate<Medicion>((m) => m.fecha.day == 21))),
        );
      },
    );
  });
}
