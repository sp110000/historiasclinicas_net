import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/ficha_paciente.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/plantilla_procedimiento.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/procedimientos.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/valoracion.dart';
import 'package:historiasclinicas_net/core/consultorio/reglas/estetica.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/pacientes_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';
import 'ayudas_procedimientos.dart';
import 'documentos_test.dart' show textoPdf;

FichaPaciente _ficha({DateTime? nacimiento}) => FichaPaciente(
  id: 'p',
  clave: '',
  creado: DateTime(2026),
  actualizado: DateTime(2026),
  tipoDocumento: 'CC',
  numeroDocumento: '1',
  nombres: 'Ana',
  primerApellido: 'Prueba',
  fechaNacimiento: nacimiento,
);

RespuestaValoracion _r(EfectoItem e, bool? si, [String nota = '']) =>
    RespuestaValoracion(item: ItemValoracion('Ítem', e), si: si, nota: nota);

Future<(BancoConsultorio, String)> _paciente({bool aprobar = true}) async {
  final b = BancoConsultorio();
  await b.servicio.crear(fraseDePrueba);
  final r = await b.servicio.registrarHistoria(
    HistoriaPendiente(
      datos: historiaSintetica(),
      revision: 1,
      origen: OrigenArchivo.importado,
    ),
  );
  if (aprobar) await aprobarHidrolipoclasia(b);
  return (b, r!.pacienteId);
}

/// Una valoración completa con el resultado [resultado].
Valoracion _completa(
  Valoracion v, {
  ResultadoValoracion resultado = ResultadoValoracion.apto,
  String motivo = '',
  bool infeccion = false,
}) => v.copyWith(
  zonas: const [ZonaValorada(zona: 'Abdomen inferior', pinzableCm: 3)],
  expectativasRealistas: true,
  respuestas: [
    for (final r in v.respuestas)
      RespuestaValoracion(
        item: r.item,
        si: infeccion && r.item.texto == 'Infección en la zona',
      ),
  ],
  tamizajes: [
    for (final t in v.tamizajes)
      TamizajeAplicado(
        instrumento: t.instrumento,
        respuestas: List.filled(t.instrumento.numeroItems, 0),
      ),
  ],
  resultado: resultado,
  motivo: motivo,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FuentesPdf fuentes;
  setUpAll(() async => fuentes = await FuentesPdf.cargar());

  group('Reglas (por tabla)', () {
    final hoy = DateTime(2026, 11, 21);
    for (final c in [
      (
        caso: 'sin fecha de nacimiento',
        nacimiento: null as DateTime?,
        bloquea: 'Falta la fecha de nacimiento',
      ),
      (
        caso: 'menor de 18 (cumple mañana)',
        nacimiento: DateTime(2008, 11, 22),
        bloquea: 'menor de 18 años',
      ),
      (
        caso: '18 cumplidos hoy',
        nacimiento: DateTime(2008, 11, 21),
        bloquea: '',
      ),
      (caso: 'adulto', nacimiento: DateTime(1990, 3, 15), bloquea: ''),
    ]) {
      test('edad: ${c.caso}', () {
        final b = bloqueoPorEdad(_ficha(nacimiento: c.nacimiento), hoy);
        if (c.bloquea.isEmpty) {
          expect(b, isNull);
        } else {
          expect(b, contains(c.bloquea));
        }
      });
    }

    for (final c in [
      (
        caso: 'ninguna en sí',
        respuestas: [_r(EfectoItem.noApto, false)],
        minimo: ResultadoValoracion.apto,
      ),
      (
        caso: 'precaución en sí',
        respuestas: [_r(EfectoItem.precaucion, true, 'nota')],
        minimo: ResultadoValoracion.apto,
      ),
      (
        caso: 'diferir en sí',
        respuestas: [
          _r(EfectoItem.diferir, true),
          _r(EfectoItem.noApto, false),
        ],
        minimo: ResultadoValoracion.diferir,
      ),
      (
        caso: 'no apto gana a diferir',
        respuestas: [_r(EfectoItem.diferir, true), _r(EfectoItem.noApto, true)],
        minimo: ResultadoValoracion.noApto,
      ),
    ]) {
      test('resultado mínimo: ${c.caso}', () {
        expect(resultadoMinimo(c.respuestas), c.minimo);
      });
    }

    test('estado: vigente, vencida, no apto y diferir', () {
      final base = Valoracion(
        id: 'v',
        pacienteId: 'p',
        plantillaId: 'hidrolipoclasia',
        version: 1,
        fecha: DateTime(2026, 8, 1),
        creado: DateTime(2026, 8, 1),
        huellaEvolucion: 'h',
      );
      final apto = base.copyWith(
        resultado: ResultadoValoracion.apto,
        vigenteHasta: DateTime(2026, 10, 30),
      );
      expect(estadoValoracion(null, hoy), EstadoValoracion.falta);
      expect(
        estadoValoracion(apto, DateTime(2026, 10, 30, 20)),
        EstadoValoracion.vigente,
      );
      expect(
        estadoValoracion(apto, DateTime(2026, 10, 31)),
        EstadoValoracion.vencida,
      );
      expect(
        estadoValoracion(
          base.copyWith(resultado: ResultadoValoracion.noApto),
          hoy,
        ),
        EstadoValoracion.noApto,
      );
      expect(
        estadoValoracion(
          base.copyWith(resultado: ResultadoValoracion.diferir),
          hoy,
        ),
        EstadoValoracion.diferir,
      );
      // Manda la última sellada.
      final otra = base.copyWith(
        id: 'w',
        fecha: DateTime(2026, 9, 1),
        resultado: ResultadoValoracion.diferir,
      );
      expect(ultimaValoracion([apto, otra], 'hidrolipoclasia')!.id, 'w');
    });
  });

  group('Plantilla', () {
    test('la de fábrica no se aprueba sin el protocolo', () async {
      final (b, id) = await _paciente(aprobar: false);
      final p = b.servicio.procedimientos;
      final faltan = p
          .plantilla('hidrolipoclasia')!
          .ultima
          .definicion
          .faltantes;
      expect(faltan, contains('los componentes de la solución'));
      expect(
        faltan,
        contains('la concentración y el máximo en mg/kg de cada anestésico'),
      );
      expect(faltan, contains('las indicaciones posteriores'));
      expect(() => p.aprobar('hidrolipoclasia'), throwsStateError);
      expect(
        () =>
            p.nuevaValoracion(b.servicio.indice.ficha(id)!, 'hidrolipoclasia'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'mensaje',
            contains('no está aprobada'),
          ),
        ),
      );
      await aprobarHidrolipoclasia(b);
      expect(p.plantilla('hidrolipoclasia')!.vigente!.version, 1);
      // Editar la aprobada crea la v2 en borrador; la v1 sigue en uso.
      await p.guardarBorrador(
        'hidrolipoclasia',
        p.vigente('hidrolipoclasia').definicion.copyWith(vigenciaDias: 60),
      );
      expect(p.plantilla('hidrolipoclasia')!.borrador!.version, 2);
      expect(p.vigente('hidrolipoclasia').definicion.vigenciaDias, 90);
    });
  });

  group('Valoración', () {
    test('problemas: falta todo, resultado menos estricto y motivo', () async {
      final (b, id) = await _paciente();
      final v = b.servicio.procedimientos.nuevaValoracion(
        b.servicio.indice.ficha(id)!,
        'hidrolipoclasia',
      );
      expect(v.peso, 64.5, reason: 'de la última medición');
      expect(v.talla, 162);
      final p = problemasValoracion(v);
      expect(p, contains('Elige al menos una zona.'));
      expect(p, contains('Responde «Embarazo o lactancia».'));
      expect(p, contains('Elige el resultado.'));
      final conInfeccion = _completa(v, infeccion: true);
      expect(
        problemasValoracion(conInfeccion).single,
        contains('como mínimo es «Diferir»'),
      );
      expect(
        problemasValoracion(
          conInfeccion.copyWith(resultado: ResultadoValoracion.diferir),
        ).single,
        'Escribe el motivo de «Diferir».',
      );
      expect(
        problemasValoracion(
          conInfeccion.copyWith(
            resultado: ResultadoValoracion.diferir,
            motivo: 'Infección activa',
          ),
        ),
        isEmpty,
      );
    });

    test('se sella como evolución, con vigencia de 90 días', () async {
      final (b, id) = await _paciente();
      final s = b.servicio;
      final ficha = s.indice.ficha(id)!;
      final v = _completa(
        s.procedimientos.nuevaValoracion(ficha, 'hidrolipoclasia'),
        motivo: 'Grasa localizada',
      ).copyWith(recomendacion: 'Primero programa de peso');
      final (guardada, sellada) = await s.procedimientos.sellarValoracion(
        v,
        ficha,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      expect(sellada.revision, 2);
      expect(sellada.nombreArchivo, 'Historia_PENA_1032456789_v2.pdf');
      expect(guardada.vigenteHasta, DateTime(2027, 2, 19));
      expect(guardada.revision, 2);
      expect(
        estadoValoracion(
          ultimaValoracion(
            s.procedimientos.valoracionesDe(id),
            'hidrolipoclasia',
          ),
          s.reloj.ahora(),
        ),
        EstadoValoracion.vigente,
      );
      // La historia del índice quedó en la revisión 2 con la evolución.
      final h = s.indice.ultimaHistoria(id)!;
      expect(h.revision, 2);
      expect(h.evoluciones, hasLength(1));
      final texto = textoValoracion(
        guardada,
        s.procedimientos.vigente('hidrolipoclasia').definicion,
        version: 1,
      );
      expect(
        texto,
        startsWith(
          'Valoración para Hidrolipoclasia (plantilla v1). Edad 36 años. '
          'Peso 64,5 kg, talla 162 cm, IMC 24,6. Zonas: Abdomen inferior, '
          'grasa pinzable 3 cm, elasticidad buena, flacidez 0. Expectativas '
          'realistas. Contraindicaciones: ninguna. Tamizaje: SCOFF 0/5 · '
          'negativo; DCQ 0/21 · negativo. Resultado: APTO (vigente hasta el '
          '19/02/2027).',
        ),
      );
      final pdf = textoPdf(sellada.pdf);
      if (pdf != null) {
        expect(
          pdf.replaceAll(RegExp(r'\s+'), ' '),
          contains('Valoración para Hidrolipoclasia'),
        );
      }
      // Sellada no se vuelve a sellar, y cifrada en reposo.
      expect(
        () => s.procedimientos.sellarValoracion(
          guardada,
          ficha,
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        ),
        throwsStateError,
      );
      expect(contieneTexto(b.todosLosBytes, 'Grasa localizada'), isFalse);
      await s.bloquear();
      await s.desbloquear(fraseDePrueba);
      expect(
        s.procedimientos.valoracionesDe(id).single.motivo,
        'Grasa localizada',
      );
    });

    test('un menor de 18 no puede tener valoración', () async {
      final (b, id) = await _paciente();
      final s = b.servicio;
      final menor = s.indice
          .ficha(id)!
          .copyWith(fechaNacimiento: DateTime(2010, 1, 1));
      await s.indice.guardarFicha(menor);
      expect(
        () => s.procedimientos.nuevaValoracion(menor, 'hidrolipoclasia'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'mensaje',
            contains('menor de 18 años'),
          ),
        ),
      );
    });
  });

  group('Pantalla', () {
    Future<void> montar(
      WidgetTester t,
      BancoConsultorio b,
      String ruta, {
      Size tamano = const Size(1440, 1200),
      List<(String, int)>? descargas,
    }) async {
      t.view
        ..physicalSize = tamano
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          preferenciasProvider.overrideWithValue(prefs),
          rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
          servicioConsultorioProvider.overrideWithValue(b.servicio),
          descargarPdfProvider.overrideWithValue(
            (bytes, nombre) => descargas?.add((nombre, bytes.length)),
          ),
        ],
      );
      addTearDown(c.dispose);
      final router = crearRouterConsultorio(ubicacionInicial: ruta);
      addTearDown(router.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(
            theme: temaClaro(),
            routerConfig: router,
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    Future<void> pulsar(WidgetTester t, Finder f) async {
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
    }

    Future<void> escribir(WidgetTester t, String etiqueta, String v) async {
      final f = find.ancestor(
        of: find.text(etiqueta),
        matching: find.byType(TextField),
      );
      await t.ensureVisible(f.first);
      await t.enterText(f.first, v);
      await t.pump();
    }

    testWidgets('valorar y sellar en la historia desde la ficha', (t) async {
      final (b, id) = await _paciente();
      final descargas = <(String, int)>[];
      await montar(t, b, '/pacientes/$id', descargas: descargas);
      await pulsar(t, find.text('Estética'));
      expect(find.text('Sin valoración'), findsOneWidget);
      await pulsar(t, find.text('Nueva valoración'));
      expect(find.text('Valoración · Hidrolipoclasia'), findsOneWidget);

      await pulsar(t, find.text('Abdomen inferior'));
      await escribir(t, 'Pinzable (Abdomen inferior)', '3');
      await pulsar(t, find.text('Realistas'));
      // Todas las contraindicaciones en «No» y la infección en «Sí».
      final p = b.servicio.procedimientos;
      final items = p.vigente('hidrolipoclasia').definicion.items;
      // El primer «No» es el de la grasa pinzable de la zona.
      for (var i = 0; i < items.length; i++) {
        await pulsar(t, find.text('No').at(1 + i));
      }
      await pulsar(
        t,
        find
            .descendant(
              of: find
                  .ancestor(
                    of: find.textContaining('Infección en la zona'),
                    matching: find.byType(Column),
                  )
                  .first,
              matching: find.text('Sí'),
            )
            .first,
      );
      expect(
        find.text('Por las contraindicaciones, como mínimo: diferir.'),
        findsOneWidget,
      );
      // Tamizajes en 0 (el primer «0» es el de la flacidez).
      for (var i = 0; i < 5; i++) {
        await pulsar(t, find.text('No').at(1 + items.length + i));
      }
      for (var i = 0; i < 7; i++) {
        await pulsar(t, find.text('0').at(1 + i));
      }
      await pulsar(t, find.text('Sellar valoración en la historia'));
      expect(find.textContaining('Elige el resultado.'), findsOneWidget);
      expect(find.text('Apto'), findsNothing, reason: 'el mínimo es diferir');
      await pulsar(t, find.text('Diferir'));
      await pulsar(t, find.text('Sellar valoración en la historia'));
      expect(find.text('Escribe el motivo de «Diferir».'), findsOneWidget);
      await escribir(t, 'Motivo *', 'Infección activa en la zona');
      await pulsar(t, find.text('Sellar valoración en la historia'));

      expect(descargas.single.$1, 'Historia_PENA_1032456789_v2.pdf');
      expect(find.text('Ficha del paciente'), findsOneWidget);
      final v = p.valoracionesDe(id).single;
      expect(v.resultado, ResultadoValoracion.diferir);
      expect(v.motivo, 'Infección activa en la zona');
      await pulsar(t, find.text('Estética'));
      expect(find.text('Diferir'), findsWidgets);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('menor de edad: sin «Nueva valoración»', (t) async {
      final (b, id) = await _paciente();
      await b.servicio.indice.guardarFicha(
        b.servicio.indice
            .ficha(id)!
            .copyWith(fechaNacimiento: DateTime(2012, 5, 5)),
      );
      await montar(t, b, '/pacientes/$id');
      await pulsar(t, find.text('Estética'));
      expect(find.textContaining('menor de 18 años'), findsOneWidget);
      final boton = find.ancestor(
        of: find.text('Nueva valoración'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(t.widget<ButtonStyleButton>(boton).onPressed, isNull);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('Ajustes: el editor del protocolo y la aprobación', (t) async {
      final (b, _) = await _paciente(aprobar: false);
      await montar(t, b, '/ajustes');
      await t.scrollUntilVisible(
        find.text('Procedimientos'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Falta: la familia de técnicas'),
        findsNothing,
        reason: 'la de fábrica trae la familia',
      );
      expect(find.textContaining('Falta: los componentes'), findsOneWidget);
      await pulsar(t, find.text('Aprobar v1').last);
      await pulsar(t, find.widgetWithText(FilledButton, 'Aprobar'));
      expect(find.textContaining('Para aprobarla falta'), findsOneWidget);
      expect(
        b.servicio.procedimientos.plantilla('hidrolipoclasia')!.usable,
        isFalse,
      );
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('320 px: valoración sin desbordes', (t) async {
      final (b, id) = await _paciente();
      await montar(
        t,
        b,
        '/pacientes/$id/valoracion/hidrolipoclasia',
        tamano: const Size(320, 640),
      );
      expect(find.text('Sellar valoración en la historia'), findsOneWidget);
      await pulsar(t, find.text('Abdomen inferior'));
      expect(t.takeException(), isNull);
      await t.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 5));
    });
  });
}
